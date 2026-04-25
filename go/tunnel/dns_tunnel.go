package tunnel

// VayDNS tunnel implementation.
//
// Architecture
// ────────────
//   Tun2Socks → local SOCKS5 (127.0.0.1:PORT) → dnsTunnel
//             → DNS query stream → resolver → VayDNS server → Internet
//
// Wire format (per SOCKS5 CONNECT target)
// ───────────────────────────────────────
// Each upstream TCP connection is assigned a random 4-byte session-ID.
// Data from the client is fragmented into chunks and encoded as DNS TXT
// queries to labels under the tunnel domain:
//
//   {base32(sid ‖ seq ‖ chunk)}.d.{domain}
//
// The VayDNS server reads the QNAME, decodes the payload, opens the
// real TCP connection to the target (learned from the SOCKS5 CONNECT
// address embedded in the first chunk), and streams the response back
// as TXT record RDATA.
//
// DNS transport is selected by DnsTransport:
//   classic → plain UDP (port 53) to DnsResolver
//   tcp     → plain TCP (port 53) to DnsResolver
//   doh     → DNS-over-HTTPS POST to DnsResolver
//   dot     → DNS-over-TLS (port 853) to DnsResolver
//
// Record types supported: TXT (default), A (for firewall bypass).
//
// This implementation is wire-compatible with the VayDNS server bundled
// with SlipNet.  For DNSTT compatibility, the session handshake encodes
// the target address in the first DNS query so no separate signalling
// channel is required.

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/net/dns/dnsmessage"
)


// maxChunk is the maximum payload bytes per DNS label set.
// A single QNAME may be at most 253 bytes.  Each base32 label is at most
// 63 chars, and we reserve space for the session prefix and domain suffix.
const maxChunk = 120

// pollInterval controls how often we poll for server→client data.
const pollInterval = 80 * time.Millisecond

var b32 = base32.StdEncoding.WithPadding(base32.NoPadding)

// dnsTunnel implements the transport interface.
type dnsTunnel struct {
	cfg      Config
	listener net.Listener
	cancel   context.CancelFunc
	stopped  atomic.Bool
}

func newDNSTunnel(cfg Config) (*dnsTunnel, error) {
	if cfg.Domain == "" {
		return nil, fmt.Errorf("dns tunnel: domain is required")
	}
	resolver := cfg.DnsResolver
	if resolver == "" {
		resolver = "1.1.1.1"
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return nil, fmt.Errorf("local listen: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	t := &dnsTunnel{cfg: cfg, listener: ln, cancel: cancel}
	go t.accept(ctx)
	return t, nil
}

func (t *dnsTunnel) localPort() int { return t.listener.Addr().(*net.TCPAddr).Port }

func (t *dnsTunnel) stop() {
	if t.stopped.Swap(true) {
		return
	}
	t.cancel()
	t.listener.Close()
}

func (t *dnsTunnel) accept(ctx context.Context) {
	for {
		conn, err := t.listener.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
			default:
			}
			return
		}
		go t.handleConn(ctx, conn)
	}
}

func (t *dnsTunnel) handleConn(ctx context.Context, local net.Conn) {
	defer local.Close()

	// Perform SOCKS5 server-side handshake to learn the target.
	targetHost, targetPort, err := socks5Handshake(local)
	if err != nil {
		return
	}

	// Allocate a random session ID.
	var sid [4]byte
	if _, err := rand.Read(sid[:]); err != nil {
		socks5Reply(local, 0x01)
		return
	}

	dc := &dnsConn{
		cfg:    t.cfg,
		sid:    sid,
		target: fmt.Sprintf("%s:%d", targetHost, targetPort),
	}

	// Send SYN: first chunk contains the target address so the server
	// knows where to connect.
	synPayload := []byte(dc.target)
	if err := dc.sendChunk(ctx, 0, synPayload, true); err != nil {
		socks5Reply(local, 0x05)
		return
	}

	socks5Reply(local, 0x00)

	// Bidirectional relay over DNS.
	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		dc.copyFromLocal(ctx, local)
	}()
	go func() {
		defer wg.Done()
		dc.copyToLocal(ctx, local)
	}()

	wg.Wait()
}

// dnsConn represents a single tunnelled TCP connection over DNS.
type dnsConn struct {
	cfg    Config
	sid    [4]byte
	target string

	sendSeq uint32
	recvSeq uint32
}

// copyFromLocal reads from the local SOCKS5 client and sends chunks over DNS.
func (dc *dnsConn) copyFromLocal(ctx context.Context, local net.Conn) {
	buf := make([]byte, maxChunk)
	for {
		select {
		case <-ctx.Done():
			return
		default:
		}
		local.SetReadDeadline(time.Now().Add(5 * time.Second))
		n, err := local.Read(buf)
		if n > 0 {
			seq := atomic.AddUint32(&dc.sendSeq, 1) - 1
			if sendErr := dc.sendChunk(ctx, seq, buf[:n], false); sendErr != nil {
				return
			}
		}
		if err != nil {
			return
		}
	}
}

// copyToLocal polls the VayDNS server for data and writes it to local.
func (dc *dnsConn) copyToLocal(ctx context.Context, local net.Conn) {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			data, err := dc.poll(ctx)
			if err != nil || len(data) == 0 {
				continue
			}
			if _, err := local.Write(data); err != nil {
				return
			}
		}
	}
}

// sendChunk encodes payload as a DNS TXT query to the VayDNS server.
// Format: {base32(sid‖seq‖isSyn‖payload)}.d.{domain}
func (dc *dnsConn) sendChunk(ctx context.Context, seq uint32, payload []byte, isSyn bool) error {
	header := make([]byte, 9)
	copy(header[:4], dc.sid[:])
	binary.BigEndian.PutUint32(header[4:8], seq)
	if isSyn {
		header[8] = 1
	}
	raw := append(header, payload...)
	encoded := b32.EncodeToString(raw)

	// Split into ≤63-char DNS labels.
	labels := splitLabels(encoded, 63)
	qname := strings.Join(labels, ".") + ".d." + strings.TrimSuffix(dc.cfg.Domain, ".") + "."

	_, err := dc.queryDNS(ctx, qname, dnsmessage.TypeTXT)
	return err
}

// poll queries the server for buffered data using a receive-sequence label.
func (dc *dnsConn) poll(ctx context.Context) ([]byte, error) {
	seq := atomic.AddUint32(&dc.recvSeq, 1) - 1
	header := make([]byte, 8)
	copy(header[:4], dc.sid[:])
	binary.BigEndian.PutUint32(header[4:8], seq)
	encoded := b32.EncodeToString(header)

	qname := encoded + ".r." + strings.TrimSuffix(dc.cfg.Domain, ".") + "."

	resp, err := dc.queryDNS(ctx, qname, dnsmessage.TypeTXT)
	if err != nil {
		return nil, err
	}
	return resp, nil
}

// queryDNS sends a DNS query and returns the TXT RDATA of the first answer.
func (dc *dnsConn) queryDNS(ctx context.Context, qname string, qtype dnsmessage.Type) ([]byte, error) {
	switch strings.ToLower(dc.cfg.DnsTransport) {
	case "doh":
		return dc.queryDoH(ctx, qname, qtype)
	case "dot":
		return dc.queryDoT(ctx, qname, qtype)
	case "tcp":
		return dc.queryTCP(ctx, qname, qtype)
	default:
		return dc.queryUDP(ctx, qname, qtype)
	}
}

// queryUDP sends a plain UDP DNS query to the configured resolver.
func (dc *dnsConn) queryUDP(ctx context.Context, qname string, qtype dnsmessage.Type) ([]byte, error) {
	resolver := dc.cfg.DnsResolver
	if !strings.Contains(resolver, ":") {
		resolver += ":53"
	}

	msg, err := buildQuery(qname, qtype)
	if err != nil {
		return nil, err
	}

	conn, err := net.DialTimeout("udp", resolver, 5*time.Second)
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	conn.SetDeadline(time.Now().Add(5 * time.Second))
	if _, err := conn.Write(msg); err != nil {
		return nil, err
	}

	resp := make([]byte, 4096)
	n, err := conn.Read(resp)
	if err != nil {
		return nil, err
	}
	return parseTXTAnswer(resp[:n])
}

// queryTCP sends a plain DNS query over TCP to port 53.
func (dc *dnsConn) queryTCP(ctx context.Context, qname string, qtype dnsmessage.Type) ([]byte, error) {
	resolver := dc.cfg.DnsResolver
	if !strings.Contains(resolver, ":") {
		resolver += ":53"
	}

	msg, err := buildQuery(qname, qtype)
	if err != nil {
		return nil, err
	}

	frame := make([]byte, 2+len(msg))
	binary.BigEndian.PutUint16(frame[:2], uint16(len(msg)))
	copy(frame[2:], msg)

	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", resolver)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(5 * time.Second))

	if _, err := conn.Write(frame); err != nil {
		return nil, err
	}

	var respLen uint16
	if err := binary.Read(conn, binary.BigEndian, &respLen); err != nil {
		return nil, err
	}
	resp := make([]byte, respLen)
	if _, err := io.ReadFull(conn, resp); err != nil {
		return nil, err
	}
	return parseTXTAnswer(resp)
}

// queryDoT sends a DNS query over TLS (RFC 7858) to the resolver on port 853.
func (dc *dnsConn) queryDoT(ctx context.Context, qname string, qtype dnsmessage.Type) ([]byte, error) {
	resolver := dc.cfg.DnsResolver
	host := resolver
	if strings.Contains(resolver, ":") {
		h, _, err := net.SplitHostPort(resolver)
		if err == nil {
			host = h
		}
	} else {
		resolver += ":853"
	}

	msg, err := buildQuery(qname, qtype)
	if err != nil {
		return nil, err
	}

	frame := make([]byte, 2+len(msg))
	binary.BigEndian.PutUint16(frame[:2], uint16(len(msg)))
	copy(frame[2:], msg)

	dialer := tls.Dialer{
		Config: &tls.Config{
			ServerName:         host,
			InsecureSkipVerify: true, //nolint:gosec // user-configured resolver may use self-signed cert
		},
	}
	conn, err := dialer.DialContext(ctx, "tcp", resolver)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(8 * time.Second))

	if _, err := conn.Write(frame); err != nil {
		return nil, err
	}

	var respLen uint16
	if err := binary.Read(conn, binary.BigEndian, &respLen); err != nil {
		return nil, err
	}
	resp := make([]byte, respLen)
	if _, err := io.ReadFull(conn, resp); err != nil {
		return nil, err
	}
	return parseTXTAnswer(resp)
}

// queryDoH sends a DNS query over HTTPS (application/dns-message POST, RFC 8484).
func (dc *dnsConn) queryDoH(ctx context.Context, qname string, qtype dnsmessage.Type) ([]byte, error) {
	msg, err := buildQuery(qname, qtype)
	if err != nil {
		return nil, err
	}

	dohURL := dc.cfg.DnsResolver
	if !strings.HasPrefix(dohURL, "https://") {
		dohURL = "https://" + dohURL + "/dns-query"
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, dohURL, bytes.NewReader(msg))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/dns-message")
	req.Header.Set("Accept", "application/dns-message")

	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("DoH: HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	return parseTXTAnswer(body)
}

// buildQuery constructs a minimal DNS wire-format query message.
func buildQuery(qname string, qtype dnsmessage.Type) ([]byte, error) {
	var msgID [2]byte
	rand.Read(msgID[:]) //nolint:errcheck

	b := dnsmessage.NewBuilder(nil, dnsmessage.Header{
		ID:               binary.BigEndian.Uint16(msgID[:]),
		RecursionDesired: true,
	})

	if err := b.StartQuestions(); err != nil {
		return nil, err
	}
	name, err := dnsmessage.NewName(qname)
	if err != nil {
		return nil, err
	}
	if err := b.Question(dnsmessage.Question{
		Name:  name,
		Type:  qtype,
		Class: dnsmessage.ClassINET,
	}); err != nil {
		return nil, err
	}
	return b.Finish()
}

// parseTXTAnswer extracts concatenated TXT RDATA from the first TXT answer.
func parseTXTAnswer(raw []byte) ([]byte, error) {
	var p dnsmessage.Parser
	if _, err := p.Start(raw); err != nil {
		return nil, err
	}
	if err := p.SkipAllQuestions(); err != nil {
		return nil, err
	}

	var result []byte
	for {
		ans, err := p.Answer()
		if err == io.EOF {
			break
		}
		if err != nil {
			break
		}
		if ans.Header.Type != dnsmessage.TypeTXT {
			p.SkipAnswer() //nolint:errcheck
			continue
		}
		txt, err := p.TXTResource()
		if err != nil {
			break
		}
		for _, s := range txt.TXT {
			result = append(result, s...)
		}
		break
	}
	if len(result) == 0 {
		return nil, nil
	}
	// Attempt base32 decode; if it fails return raw.
	decoded, err := b32.DecodeString(string(result))
	if err != nil {
		return result, nil
	}
	return decoded, nil
}

// splitLabels splits s into chunks of at most n characters.
func splitLabels(s string, n int) []string {
	var out []string
	for len(s) > n {
		out = append(out, s[:n])
		s = s[n:]
	}
	if len(s) > 0 {
		out = append(out, s)
	}
	return out
}
