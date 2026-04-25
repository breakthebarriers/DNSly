package tunnel

import (
	"context"
	"fmt"
	"io"
	"net"
	"sync/atomic"
)

// socksRelay opens a local SOCKS5 listener and forwards every raw TCP
// connection to the upstream SOCKS5 server (server:port). The upstream must
// speak SOCKS5 natively; we forward the SOCKS5 stream byte-for-byte.
type socksRelay struct {
	upstream string
	auth     string // "user:pass" or ""
	listener net.Listener
	cancel   context.CancelFunc
	stopped  atomic.Bool
}

func newSOCKSRelay(cfg Config) (*socksRelay, error) {
	upstream := fmt.Sprintf("%s:%d", cfg.Server, cfg.Port)

	var auth string
	if cfg.SocksUser != "" {
		auth = cfg.SocksUser + ":" + cfg.SocksPassword
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return nil, fmt.Errorf("local listen: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	r := &socksRelay{upstream: upstream, auth: auth, listener: ln, cancel: cancel}
	go r.accept(ctx)
	return r, nil
}

func (r *socksRelay) localPort() int { return r.listener.Addr().(*net.TCPAddr).Port }

func (r *socksRelay) stop() {
	if r.stopped.Swap(true) {
		return
	}
	r.cancel()
	r.listener.Close()
}

func (r *socksRelay) accept(ctx context.Context) {
	for {
		conn, err := r.listener.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
			default:
			}
			return
		}
		go r.pipe(conn)
	}
}

// pipe connects the local SOCKS5 client (from Tun2Socks) directly to the
// upstream SOCKS5 server by relaying the raw stream. The upstream SOCKS5
// server sees the original SOCKS5 handshake and handles it itself.
func (r *socksRelay) pipe(local net.Conn) {
	defer local.Close()

	upstream, err := net.Dial("tcp", r.upstream)
	if err != nil {
		return
	}
	defer upstream.Close()

	go io.Copy(upstream, local) //nolint:errcheck
	io.Copy(local, upstream)    //nolint:errcheck
}
