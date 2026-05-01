package tunnel

import (
	"context"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"net"
	"strings"
	"sync/atomic"
	"time"

	"golang.org/x/crypto/ssh"
)

// sshPayloadInjectionProxy sends raw bytes before the SSH handshake to
// disguise traffic. Useful for bypassing DPI that inspects the first bytes.
// Flow: TCP → [TLS] → payload bytes → SSH → SOCKS5
type sshPayloadInjectionProxy struct {
	client   *ssh.Client
	listener net.Listener
	cancel   context.CancelFunc
	stopped  atomic.Bool
}

func newSSHPayloadInjectionProxy(cfg Config) (*sshPayloadInjectionProxy, error) {
	host := cfg.SshHost
	if host == "" {
		host = cfg.Server
	}
	port := cfg.SshPort
	if port == 0 {
		port = 22
	}

	timeout := time.Duration(cfg.Timeout) * time.Second
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	rawConn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", host, port), timeout)
	if err != nil {
		return nil, fmt.Errorf("dial: %w", err)
	}

	var baseConn net.Conn = rawConn
	if cfg.SshTlsEnabled {
		sni := cfg.SshTlsSni
		if sni == "" {
			sni = host
		}
		// tls.Client — we are the TLS client.
		tlsConn := tls.Client(rawConn, &tls.Config{
			ServerName:         sni,
			InsecureSkipVerify: true, //nolint:gosec
		})
		if err := tlsConn.HandshakeContext(context.Background()); err != nil {
			rawConn.Close()
			return nil, fmt.Errorf("tls handshake: %w", err)
		}
		baseConn = tlsConn
	}

	// Expand and inject payload before SSH handshake.
	if cfg.SshPayload != "" {
		payload, err := expandPayload(cfg.SshPayload, host, port)
		if err != nil {
			baseConn.Close()
			return nil, fmt.Errorf("expand payload: %w", err)
		}
		if _, err := baseConn.Write(payload); err != nil {
			baseConn.Close()
			return nil, fmt.Errorf("write payload: %w", err)
		}
	}

	sshCfg := &ssh.ClientConfig{
		User:            cfg.SshUser,
		Auth:            buildSSHAuthMethods(cfg),
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), //nolint:gosec
		Timeout:         timeout,
	}

	sshConn, chans, reqs, err := ssh.NewClientConn(baseConn, fmt.Sprintf("%s:%d", host, port), sshCfg)
	if err != nil {
		baseConn.Close()
		return nil, fmt.Errorf("ssh handshake with payload: %w", err)
	}
	client := ssh.NewClient(sshConn, chans, reqs)

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("local listen: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	p := &sshPayloadInjectionProxy{client: client, listener: ln, cancel: cancel}
	go p.accept(ctx)
	return p, nil
}

// expandPayload resolves template placeholders and optionally decodes base64.
// Supported placeholders: [host] [port] [crlf] [lf] [cr] [space]
// Prefix "base64:" for raw binary payloads (no placeholder expansion).
func expandPayload(template, host string, port int) ([]byte, error) {
	if strings.HasPrefix(template, "base64:") {
		return base64.StdEncoding.DecodeString(template[7:])
	}
	s := template
	s = strings.ReplaceAll(s, "[host]", host)
	s = strings.ReplaceAll(s, "[port]", fmt.Sprintf("%d", port))
	s = strings.ReplaceAll(s, "[crlf]", "\r\n")
	s = strings.ReplaceAll(s, "[cr]", "\r")
	s = strings.ReplaceAll(s, "[lf]", "\n")
	s = strings.ReplaceAll(s, "[space]", " ")
	return []byte(s), nil
}

func (p *sshPayloadInjectionProxy) localPort() int { return p.listener.Addr().(*net.TCPAddr).Port }

func (p *sshPayloadInjectionProxy) stop() {
	if p.stopped.Swap(true) {
		return
	}
	p.cancel()
	p.listener.Close()
	p.client.Close()
}

func (p *sshPayloadInjectionProxy) accept(ctx context.Context) {
	for {
		conn, err := p.listener.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
			default:
			}
			return
		}
		go handleSOCKS5Connection(ctx, conn, p.client)
	}
}
