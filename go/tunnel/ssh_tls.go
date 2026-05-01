package tunnel

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"sync/atomic"
	"time"

	"golang.org/x/crypto/ssh"
)

// sshTLSProxy implements SSH over TLS with custom SNI (domain fronting).
// Flow: TCP → TLS(custom SNI) → SSH → SOCKS5
type sshTLSProxy struct {
	client   *ssh.Client
	listener net.Listener
	cancel   context.CancelFunc
	stopped  atomic.Bool
}

func newSSHTLSProxy(cfg Config) (*sshTLSProxy, error) {
	host := cfg.SshHost
	if host == "" {
		host = cfg.Server
	}
	port := cfg.SshPort
	if port == 0 {
		port = 443
	}

	sniDomain := cfg.SshTlsSni
	if sniDomain == "" {
		sniDomain = host
	}

	timeout := time.Duration(cfg.Timeout) * time.Second
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	// InsecureSkipVerify=true is intentional for domain fronting:
	// the real host cert won't match the custom SNI.
	tlsConn, err := tls.DialWithDialer(
		&net.Dialer{Timeout: timeout},
		"tcp",
		fmt.Sprintf("%s:%d", host, port),
		&tls.Config{
			ServerName:         sniDomain,
			InsecureSkipVerify: true, //nolint:gosec
		},
	)
	if err != nil {
		return nil, fmt.Errorf("tls dial: %w", err)
	}

	authMethods := buildSSHAuthMethods(cfg)
	sshCfg := &ssh.ClientConfig{
		User:            cfg.SshUser,
		Auth:            authMethods,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), //nolint:gosec
		Timeout:         timeout,
	}

	sshConn, chans, reqs, err := ssh.NewClientConn(tlsConn, fmt.Sprintf("%s:%d", host, port), sshCfg)
	if err != nil {
		tlsConn.Close()
		return nil, fmt.Errorf("ssh handshake over tls: %w", err)
	}
	client := ssh.NewClient(sshConn, chans, reqs)

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("local listen: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	p := &sshTLSProxy{client: client, listener: ln, cancel: cancel}
	go p.accept(ctx)
	return p, nil
}

func (p *sshTLSProxy) localPort() int { return p.listener.Addr().(*net.TCPAddr).Port }

func (p *sshTLSProxy) stop() {
	if p.stopped.Swap(true) {
		return
	}
	p.cancel()
	p.listener.Close()
	p.client.Close()
}

func (p *sshTLSProxy) accept(ctx context.Context) {
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

// buildSSHAuthMethods constructs SSH auth methods from config.
// Shared by all SSH transport variants.
func buildSSHAuthMethods(cfg Config) []ssh.AuthMethod {
	methods := []ssh.AuthMethod{}
	if cfg.SshKey != "" {
		signer, err := ssh.ParsePrivateKey([]byte(cfg.SshKey))
		if err == nil {
			methods = append(methods, ssh.PublicKeys(signer))
		}
	}
	if cfg.SshPassword != "" {
		methods = append(methods, ssh.Password(cfg.SshPassword))
	}
	if len(methods) == 0 {
		methods = append(methods, ssh.Password(""))
	}
	return methods
}
