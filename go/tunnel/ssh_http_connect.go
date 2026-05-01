package tunnel

import (
	"bufio"
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"net/http"
	"sync/atomic"
	"time"

	"golang.org/x/crypto/ssh"
)

// sshHTTPConnectProxy implements SSH over HTTP CONNECT proxy.
// Flow: TCP → HTTP CONNECT → [TLS] → SSH → SOCKS5
type sshHTTPConnectProxy struct {
	client   *ssh.Client
	listener net.Listener
	cancel   context.CancelFunc
	stopped  atomic.Bool
}

func newSSHHTTPConnectProxy(cfg Config) (*sshHTTPConnectProxy, error) {
	sshHost := cfg.SshHost
	if sshHost == "" {
		sshHost = cfg.Server
	}
	sshPort := cfg.SshPort
	if sshPort == 0 {
		sshPort = 22
	}

	proxyHost := cfg.SshHttpProxyHost
	proxyPort := cfg.SshHttpProxyPort
	if proxyPort == 0 {
		proxyPort = 8080
	}

	hostHeader := cfg.SshHttpProxyHostHdr
	if hostHeader == "" {
		hostHeader = fmt.Sprintf("%s:%d", sshHost, sshPort)
	}

	timeout := time.Duration(cfg.Timeout) * time.Second
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	// Connect to HTTP proxy.
	proxyConn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", proxyHost, proxyPort), timeout)
	if err != nil {
		return nil, fmt.Errorf("dial proxy: %w", err)
	}

	// Send HTTP CONNECT.
	targetAddr := fmt.Sprintf("%s:%d", sshHost, sshPort)
	connectReq := fmt.Sprintf(
		"CONNECT %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: Mozilla/5.0\r\n\r\n",
		targetAddr, hostHeader,
	)
	proxyConn.SetDeadline(time.Now().Add(timeout)) //nolint:errcheck
	if _, err := io.WriteString(proxyConn, connectReq); err != nil {
		proxyConn.Close()
		return nil, fmt.Errorf("write CONNECT: %w", err)
	}

	reader := bufio.NewReader(proxyConn)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		proxyConn.Close()
		return nil, fmt.Errorf("read CONNECT response: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		proxyConn.Close()
		return nil, fmt.Errorf("proxy returned %d %s", resp.StatusCode, resp.Status)
	}
	proxyConn.SetDeadline(time.Time{}) //nolint:errcheck

	// The tunnel is now established. Optionally wrap in TLS.
	var tunnelConn net.Conn = proxyConn
	if cfg.SshTlsEnabled {
		sni := cfg.SshTlsSni
		if sni == "" {
			sni = sshHost
		}
		// tls.Client — we are the client on this tunneled connection.
		tlsConn := tls.Client(proxyConn, &tls.Config{
			ServerName:         sni,
			InsecureSkipVerify: true, //nolint:gosec
		})
		if err := tlsConn.HandshakeContext(context.Background()); err != nil {
			proxyConn.Close()
			return nil, fmt.Errorf("tls handshake: %w", err)
		}
		tunnelConn = tlsConn
	}

	sshCfg := &ssh.ClientConfig{
		User:            cfg.SshUser,
		Auth:            buildSSHAuthMethods(cfg),
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), //nolint:gosec
		Timeout:         timeout,
	}

	sshConn, chans, reqs, err := ssh.NewClientConn(tunnelConn, targetAddr, sshCfg)
	if err != nil {
		tunnelConn.Close()
		return nil, fmt.Errorf("ssh handshake over http connect: %w", err)
	}
	client := ssh.NewClient(sshConn, chans, reqs)

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("local listen: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	p := &sshHTTPConnectProxy{client: client, listener: ln, cancel: cancel}
	go p.accept(ctx)
	return p, nil
}

func (p *sshHTTPConnectProxy) localPort() int { return p.listener.Addr().(*net.TCPAddr).Port }

func (p *sshHTTPConnectProxy) stop() {
	if p.stopped.Swap(true) {
		return
	}
	p.cancel()
	p.listener.Close()
	p.client.Close()
}

func (p *sshHTTPConnectProxy) accept(ctx context.Context) {
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
