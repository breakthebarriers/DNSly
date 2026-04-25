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
	// "vayDnsSocks", "vaydns", "vayDns".
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
		t, err = newSSHProxy(cfg)
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
