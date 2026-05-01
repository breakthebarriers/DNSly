// Package tunnel is the mobile tunnel engine for dnsly.
// It exposes a minimal API compatible with gomobile bind for iOS (xcframework)
// and Android (aar). The caller starts the tunnel, receives a local SOCKS5
// port, and points Tun2Socks at that port. All three transport modes are
// supported: SSH dynamic port-forwarding, direct SOCKS5 relay, and VayDNS
// DNS tunneling.
package tunnel

import (
	"encoding/json"
	"sync"
)

// Config is the tunnel configuration. All fields are plain strings/ints so
// gomobile can pass them without reflection issues.
type Config struct {
	// TunnelType selects the transport: "ssh", "vayDnsSsh", "socks5",
	// "vayDnsSocks", "vaydns", "vayDns", "sshTls", "sshWebsocket",
	// "sshHttpConnect", "sshPayloadInjection".
	TunnelType string `json:"tunnelType"`

	// Server / Port are the upstream SOCKS5 server (socks5 mode) or the
	// VayDNS server (dns mode).
	Server string `json:"server"`
	Port   int    `json:"port"`

	// Domain is the DNS tunnel domain (vaydns mode).
	Domain string `json:"domain"`

	// DnsResolver is the upstream resolver IP used in dns tunnel mode.
	DnsResolver  string `json:"dnsResolver"`
	DnsTransport string `json:"dnsTransport"` // classic | tcp | doh | dot
	RecordType   string `json:"recordType"`
	QueryLength  int    `json:"queryLength"`

	// SSH credentials.
	SshHost     string `json:"sshHost"`
	SshPort     int    `json:"sshPort"`
	SshUser     string `json:"sshUser"`
	SshPassword string `json:"sshPassword"`
	SshKey      string `json:"sshKey"`

	// DPI Bypass options - SSH over TLS/WebSocket/HTTP
	SshTlsEnabled      bool   `json:"sshTlsEnabled"`      // Wrap SSH in TLS
	SshTlsSni          string `json:"sshTlsSni"`          // Custom SNI for domain fronting
	SshWsEnabled       bool   `json:"sshWsEnabled"`       // Use WebSocket transport
	SshWsPath          string `json:"sshWsPath"`          // WebSocket path (e.g., "/ws")
	SshWsUseTls        bool   `json:"sshWsUseTls"`        // Use wss:// (TLS over WebSocket)
	SshWsHost          string `json:"sshWsHost"`          // Custom Host header for WebSocket
	SshHttpProxyHost   string `json:"sshHttpProxyHost"`   // HTTP CONNECT proxy host
	SshHttpProxyPort   int    `json:"sshHttpProxyPort"`   // HTTP CONNECT proxy port
	SshHttpProxyHostHdr string `json:"sshHttpProxyHostHdr"` // Custom Host header for CONNECT
	SshPayload         string `json:"sshPayload"`         // Raw payload to inject before SSH

	// SOCKS5 upstream credentials (socks5 mode).
	SocksUser     string `json:"socksUser"`
	SocksPassword string `json:"socksPassword"`

	Mtu     int `json:"mtu"`
	Timeout int `json:"timeout"`
}

// transport is implemented by each tunnel mode.
type transport interface {
	localPort() int
	stop()
}

var (
	mu      sync.Mutex
	active  transport
)

// Start parses configJSON, launches the appropriate transport, and returns the
// local SOCKS5 port that Tun2Socks should connect to.
// Returns -1 on error.
func Start(configJSON string) int {
	mu.Lock()
	defer mu.Unlock()

	if active != nil {
		active.stop()
		active = nil
	}

	var cfg Config
	if err := json.Unmarshal([]byte(configJSON), &cfg); err != nil {
		return -1
	}

	var (
		t   transport
		err error
	)

	switch cfg.TunnelType {
	case "ssh", "vayDnsSsh":
		// Determine SSH transport based on config
		if cfg.SshHttpProxyHost != "" {
			t, err = newSSHHTTPConnectProxy(cfg)
		} else if cfg.SshWsEnabled {
			t, err = newSSHWebSocketProxy(cfg)
		} else if cfg.SshPayload != "" {
			t, err = newSSHPayloadInjectionProxy(cfg)
		} else if cfg.SshTlsEnabled {
			t, err = newSSHTLSProxy(cfg)
		} else {
			t, err = newSSHProxy(cfg)
		}
	case "sshTls":
		t, err = newSSHTLSProxy(cfg)
	case "sshWebsocket":
		t, err = newSSHWebSocketProxy(cfg)
	case "sshHttpConnect":
		t, err = newSSHHTTPConnectProxy(cfg)
	case "sshPayloadInjection":
		t, err = newSSHPayloadInjectionProxy(cfg)
	case "vaydns", "vayDns":
		t, err = newDNSTunnel(cfg)
	default: // socks5, vayDnsSocks, anything else
		t, err = newSOCKSRelay(cfg)
	}
	if err != nil {
		return -1
	}

	active = t
	return t.localPort()
}

// Stop shuts down the active tunnel.
func Stop() {
	mu.Lock()
	defer mu.Unlock()
	if active != nil {
		active.stop()
		active = nil
	}
}

// IsRunning reports whether a tunnel is currently active.
func IsRunning() bool {
	mu.Lock()
	defer mu.Unlock()
	return active != nil
}

// LastError returns the last tunnel error as a string (empty if none).
// Reserved for future use; currently always returns "".
func LastError() string {
	return ""
}
