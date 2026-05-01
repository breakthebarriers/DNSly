package tunnel

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"sync/atomic"
	"time"

	"golang.org/x/crypto/ssh"
)

// sshWebSocketProxy implements SSH over WebSocket.
// Flow (ws):  TCP → WS upgrade → WS frames → SSH → SOCKS5
// Flow (wss): TCP → TLS → WS upgrade → WS frames → SSH → SOCKS5
type sshWebSocketProxy struct {
	client   *ssh.Client
	listener net.Listener
	cancel   context.CancelFunc
	stopped  atomic.Bool
}

func newSSHWebSocketProxy(cfg Config) (*sshWebSocketProxy, error) {
	host := cfg.SshHost
	if host == "" {
		host = cfg.Server
	}
	port := cfg.SshPort
	if port == 0 {
		if cfg.SshWsUseTls {
			port = 443
		} else {
			port = 80
		}
	}

	wsPath := cfg.SshWsPath
	if wsPath == "" {
		wsPath = "/ssh"
	}

	timeout := time.Duration(cfg.Timeout) * time.Second
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	// Dial base TCP connection.
	rawConn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", host, port), timeout)
	if err != nil {
		return nil, fmt.Errorf("dial: %w", err)
	}

	var baseConn net.Conn = rawConn

	if cfg.SshWsUseTls {
		sni := cfg.SshWsHost
		if sni == "" {
			sni = host
		}
		// tls.Client (not Server) — we are the client initiating the TLS handshake.
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

	// Perform WebSocket upgrade.
	ws, err := upgradeWebSocket(baseConn, host, wsPath, cfg.SshWsHost, timeout)
	if err != nil {
		baseConn.Close()
		return nil, fmt.Errorf("websocket upgrade: %w", err)
	}

	sshCfg := &ssh.ClientConfig{
		User:            cfg.SshUser,
		Auth:            buildSSHAuthMethods(cfg),
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), //nolint:gosec
		Timeout:         timeout,
	}

	sshConn, chans, reqs, err := ssh.NewClientConn(ws, fmt.Sprintf("%s:%d", host, port), sshCfg)
	if err != nil {
		ws.Close()
		return nil, fmt.Errorf("ssh handshake over websocket: %w", err)
	}
	client := ssh.NewClient(sshConn, chans, reqs)

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("local listen: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	p := &sshWebSocketProxy{client: client, listener: ln, cancel: cancel}
	go p.accept(ctx)
	return p, nil
}

// upgradeWebSocket sends an HTTP/1.1 WebSocket upgrade request and wraps the
// connection in a wsConn that frames reads/writes as binary WebSocket frames.
func upgradeWebSocket(conn net.Conn, host, path, customHost string, timeout time.Duration) (*wsConn, error) {
	conn.SetDeadline(time.Now().Add(timeout)) //nolint:errcheck
	defer conn.SetDeadline(time.Time{})       //nolint:errcheck

	key := make([]byte, 16)
	if _, err := rand.Read(key); err != nil {
		return nil, fmt.Errorf("generate key: %w", err)
	}
	keyStr := base64.StdEncoding.EncodeToString(key)

	hostHeader := customHost
	if hostHeader == "" {
		hostHeader = host
	}

	req := fmt.Sprintf(
		"GET %s HTTP/1.1\r\n"+
			"Host: %s\r\n"+
			"Upgrade: websocket\r\n"+
			"Connection: Upgrade\r\n"+
			"Sec-WebSocket-Key: %s\r\n"+
			"Sec-WebSocket-Version: 13\r\n"+
			"User-Agent: Mozilla/5.0\r\n"+
			"\r\n",
		path, hostHeader, keyStr,
	)
	if _, err := io.WriteString(conn, req); err != nil {
		return nil, fmt.Errorf("write upgrade request: %w", err)
	}

	reader := bufio.NewReader(conn)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		return nil, fmt.Errorf("read upgrade response: %w", err)
	}
	if resp.StatusCode != http.StatusSwitchingProtocols {
		return nil, fmt.Errorf("unexpected status: %d %s", resp.StatusCode, resp.Status)
	}

	return &wsConn{conn: conn, reader: reader}, nil
}

func (p *sshWebSocketProxy) localPort() int { return p.listener.Addr().(*net.TCPAddr).Port }

func (p *sshWebSocketProxy) stop() {
	if p.stopped.Swap(true) {
		return
	}
	p.cancel()
	p.listener.Close()
	p.client.Close()
}

func (p *sshWebSocketProxy) accept(ctx context.Context) {
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

// ── wsConn: minimal WebSocket binary framing over net.Conn ───────────────────

// wsConn wraps a net.Conn and speaks WebSocket binary frames (RFC 6455).
// Client→server frames are masked; server→client frames are not.
type wsConn struct {
	conn    net.Conn
	reader  *bufio.Reader
	readBuf []byte
	readPos int
}

func (wc *wsConn) Read(p []byte) (int, error) {
	// Drain buffered payload first.
	if wc.readPos < len(wc.readBuf) {
		n := copy(p, wc.readBuf[wc.readPos:])
		wc.readPos += n
		if wc.readPos >= len(wc.readBuf) {
			wc.readBuf = nil
			wc.readPos = 0
		}
		return n, nil
	}

	frame, err := wc.readFrame()
	if err != nil {
		return 0, err
	}
	wc.readBuf = frame
	wc.readPos = 0
	return wc.Read(p)
}

func (wc *wsConn) readFrame() ([]byte, error) {
	header := make([]byte, 2)
	if _, err := io.ReadFull(wc.reader, header); err != nil {
		return nil, fmt.Errorf("ws frame header: %w", err)
	}

	opcode := header[0] & 0x0f
	masked := (header[1] & 0x80) != 0
	payloadLen := int64(header[1] & 0x7f)

	switch payloadLen {
	case 126:
		ext := make([]byte, 2)
		if _, err := io.ReadFull(wc.reader, ext); err != nil {
			return nil, err
		}
		payloadLen = int64(binary.BigEndian.Uint16(ext))
	case 127:
		ext := make([]byte, 8)
		if _, err := io.ReadFull(wc.reader, ext); err != nil {
			return nil, err
		}
		payloadLen = int64(binary.BigEndian.Uint64(ext))
	}

	var maskKey [4]byte
	if masked {
		if _, err := io.ReadFull(wc.reader, maskKey[:]); err != nil {
			return nil, err
		}
	}

	payload := make([]byte, payloadLen)
	if _, err := io.ReadFull(wc.reader, payload); err != nil {
		return nil, err
	}
	if masked {
		for i := range payload {
			payload[i] ^= maskKey[i%4]
		}
	}

	if opcode == 0x8 { // Close frame
		return nil, io.EOF
	}
	return payload, nil
}

func (wc *wsConn) Write(p []byte) (int, error) {
	frame := wc.buildFrame(p)
	if _, err := wc.conn.Write(frame); err != nil {
		return 0, err
	}
	return len(p), nil
}

// buildFrame creates a masked binary WebSocket frame (opcode 0x2).
func (wc *wsConn) buildFrame(data []byte) []byte {
	maskKey := make([]byte, 4)
	rand.Read(maskKey) //nolint:errcheck

	n := len(data)
	var header []byte
	header = append(header, 0x82) // FIN + binary opcode

	switch {
	case n < 126:
		header = append(header, byte(n)|0x80)
	case n < 65536:
		header = append(header, 0xfe, byte(n>>8), byte(n))
	default:
		header = append(header, 0xff,
			byte(n>>56), byte(n>>48), byte(n>>40), byte(n>>32),
			byte(n>>24), byte(n>>16), byte(n>>8), byte(n))
	}
	header = append(header, maskKey...)

	masked := make([]byte, n)
	for i := range data {
		masked[i] = data[i] ^ maskKey[i%4]
	}
	return append(header, masked...)
}

func (wc *wsConn) Close() error                       { return wc.conn.Close() }
func (wc *wsConn) LocalAddr() net.Addr                { return wc.conn.LocalAddr() }
func (wc *wsConn) RemoteAddr() net.Addr               { return wc.conn.RemoteAddr() }
func (wc *wsConn) SetDeadline(t time.Time) error      { return wc.conn.SetDeadline(t) }
func (wc *wsConn) SetReadDeadline(t time.Time) error  { return wc.conn.SetReadDeadline(t) }
func (wc *wsConn) SetWriteDeadline(t time.Time) error { return wc.conn.SetWriteDeadline(t) }
