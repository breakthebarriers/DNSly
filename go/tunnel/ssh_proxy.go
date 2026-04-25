package tunnel

import (
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"sync/atomic"
	"time"

	"golang.org/x/crypto/ssh"
)

// sshProxy dials an SSH server, creates a SOCKS5 listener on localhost, and
// satisfies each incoming SOCKS5 CONNECT by forwarding through the SSH
// connection (equivalent to `ssh -D`).
type sshProxy struct {
	client   *ssh.Client
	listener net.Listener
	cancel   context.CancelFunc
	stopped  atomic.Bool
}

func newSSHProxy(cfg Config) (*sshProxy, error) {
	host := cfg.SshHost
	if host == "" {
		host = cfg.Server
	}
	port := cfg.SshPort
	if port == 0 {
		port = 22
	}

	authMethods := []ssh.AuthMethod{ssh.Password(cfg.SshPassword)}
	if cfg.SshKey != "" {
		signer, err := ssh.ParsePrivateKey([]byte(cfg.SshKey))
		if err == nil {
			authMethods = append([]ssh.AuthMethod{ssh.PublicKeys(signer)}, authMethods...)
		}
	}

	timeout := time.Duration(cfg.Timeout) * time.Second
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	sshCfg := &ssh.ClientConfig{
		User:            cfg.SshUser,
		Auth:            authMethods,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         timeout,
	}

	client, err := ssh.Dial("tcp", fmt.Sprintf("%s:%d", host, port), sshCfg)
	if err != nil {
		return nil, fmt.Errorf("ssh dial %s:%d: %w", host, port, err)
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("local listen: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	p := &sshProxy{client: client, listener: ln, cancel: cancel}
	go p.accept(ctx)
	return p, nil
}

func (p *sshProxy) localPort() int { return p.listener.Addr().(*net.TCPAddr).Port }

func (p *sshProxy) stop() {
	if p.stopped.Swap(true) {
		return
	}
	p.cancel()
	p.listener.Close()
	p.client.Close()
}

func (p *sshProxy) accept(ctx context.Context) {
	for {
		conn, err := p.listener.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
			default:
			}
			return
		}
		go p.handle(conn)
	}
}

func (p *sshProxy) handle(local net.Conn) {
	defer local.Close()

	host, port, err := socks5Handshake(local)
	if err != nil {
		return
	}

	remote, err := p.client.Dial("tcp", fmt.Sprintf("%s:%d", host, port))
	if err != nil {
		socks5Reply(local, 0x05) // connection refused
		return
	}
	defer remote.Close()

	socks5Reply(local, 0x00) // success
	relay(local, remote)
}

// ── shared SOCKS5 helpers ────────────────────────────────────────────────────

// socks5Handshake performs a no-auth SOCKS5 server handshake and returns the
// requested target address. It does NOT write the reply — the caller does that
// after dialling the upstream.
func socks5Handshake(c net.Conn) (host string, port int, err error) {
	buf := make([]byte, 512)

	// VER NMETHODS [METHODS…]
	if _, err = io.ReadFull(c, buf[:2]); err != nil || buf[0] != 0x05 {
		err = fmt.Errorf("socks5: bad greeting")
		return
	}
	nMethods := int(buf[1])
	if _, err = io.ReadFull(c, buf[:nMethods]); err != nil {
		return
	}

	// No-auth reply: {0x05, 0x00}
	if _, err = c.Write([]byte{0x05, 0x00}); err != nil {
		return
	}

	// VER CMD RSV ATYP
	if _, err = io.ReadFull(c, buf[:4]); err != nil {
		return
	}
	if buf[0] != 0x05 || buf[1] != 0x01 { // must be CONNECT
		err = fmt.Errorf("socks5: unsupported command %d", buf[1])
		return
	}

	switch buf[3] {
	case 0x01: // IPv4
		if _, err = io.ReadFull(c, buf[:6]); err != nil {
			return
		}
		host = net.IP(buf[:4]).String()
		port = int(binary.BigEndian.Uint16(buf[4:6]))

	case 0x03: // domain
		if _, err = io.ReadFull(c, buf[:1]); err != nil {
			return
		}
		dlen := int(buf[0])
		if _, err = io.ReadFull(c, buf[:dlen+2]); err != nil {
			return
		}
		host = string(buf[:dlen])
		port = int(binary.BigEndian.Uint16(buf[dlen : dlen+2]))

	case 0x04: // IPv6
		if _, err = io.ReadFull(c, buf[:18]); err != nil {
			return
		}
		host = net.IP(buf[:16]).String()
		port = int(binary.BigEndian.Uint16(buf[16:18]))

	default:
		socks5Reply(c, 0x08) // address type not supported
		err = fmt.Errorf("socks5: unknown ATYP %d", buf[3])
	}
	return
}

// socks5Reply sends a SOCKS5 reply with the given REP byte.
// BND.ADDR and BND.PORT are zeroed — sufficient for tunnelling.
func socks5Reply(c net.Conn, rep byte) {
	c.Write([]byte{0x05, rep, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
}

// relay copies bidirectionally between a and b until either side closes.
func relay(a, b net.Conn) {
	done := make(chan struct{}, 2)
	go func() { io.Copy(a, b); done <- struct{}{} }() //nolint:errcheck
	go func() { io.Copy(b, a); done <- struct{}{} }() //nolint:errcheck
	<-done
}
