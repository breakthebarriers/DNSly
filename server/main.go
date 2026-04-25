package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

type appConfig struct {
	BindAddr          string `json:"bindAddr"`
	APIKey            string `json:"apiKey"`
	PublicServerHost  string `json:"publicServerHost"`
	PublicServerPort  int    `json:"publicServerPort"`
	TunnelDomain      string `json:"tunnelDomain"`
	DefaultDNS        string `json:"defaultDns"`
	DefaultSshHost    string `json:"defaultSshHost"`
	DefaultSshPort    int    `json:"defaultSshPort"`
	DefaultSocksHost  string `json:"defaultSocksHost"`
	DefaultSocksPort  int    `json:"defaultSocksPort"`
	DefaultMTU        int    `json:"defaultMtu"`
	DefaultTimeoutSec int    `json:"defaultTimeoutSec"`
	DefaultTunnelType string `json:"defaultTunnelType"`
	IOSBundleID       string `json:"iosBundleId"`
	IOSProviderBundle string `json:"iosProviderBundle"`
}

type storedProfile struct {
	ID               string    `json:"id"`
	Name             string    `json:"name"`
	Username         string    `json:"username"`
	Password         string    `json:"password"`
	TunnelType       string    `json:"tunnelType"`
	ConnectionMethod string    `json:"connectionMethod"`
	Server           string    `json:"server"`
	Port             int       `json:"port"`
	Domain           string    `json:"domain"`
	DNSResolver      string    `json:"dnsResolver"`
	DNSTransport     string    `json:"dnsTransport"`
	RecordType       string    `json:"recordType"`
	QueryLength      int       `json:"queryLength"`
	SSHHost          string    `json:"sshHost"`
	SSHPort          int       `json:"sshPort"`
	SSHAuthType      string    `json:"sshAuthType"`
	Compression      bool      `json:"compression"`
	SocksHost        string    `json:"socksHost"`
	SocksPort        int       `json:"socksPort"`
	SocksUser        string    `json:"socksUser"`
	SocksPassword    string    `json:"socksPassword"`
	MTU              int       `json:"mtu"`
	TimeoutSec       int       `json:"timeoutSec"`
	CreatedAt        time.Time `json:"createdAt"`
	ExpiresAt        time.Time `json:"expiresAt"`
	SlipnetURI       string    `json:"slipnetUri"`
}

type iosVPNConfig struct {
	BundleIdentifier         string            `json:"bundleIdentifier"`
	ProviderBundleIdentifier string            `json:"providerBundleIdentifier"`
	ServerAddress            string            `json:"serverAddress"`
	Username                 string            `json:"username"`
	Password                 string            `json:"password"`
	ProviderConfiguration    map[string]string `json:"providerConfiguration"`
}

type profileRequest struct {
	Name             string `json:"name"`
	TunnelType       string `json:"tunnelType"`
	ConnectionMethod string `json:"connectionMethod"`
	DaysValid        int    `json:"daysValid"`
}

type profileStore struct {
	mu       sync.Mutex
	path     string
	profiles []storedProfile
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	store, err := newProfileStore(filepath.Join("server", "data", "profiles.json"))
	if err != nil {
		log.Fatalf("open store: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{
			"ok":   true,
			"time": time.Now().UTC().Format(time.RFC3339),
		})
	})

	mux.HandleFunc("/v1/profiles", func(w http.ResponseWriter, r *http.Request) {
		if !authorized(r, cfg.APIKey) {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		switch r.Method {
		case http.MethodGet:
			items := store.list()
			writeJSON(w, http.StatusOK, map[string]any{"profiles": items})
		case http.MethodPost:
			req, err := decodeProfileRequest(r)
			if err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}

			p, err := buildProfile(cfg, req)
			if err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			if err := store.add(p); err != nil {
				http.Error(w, "failed to store profile", http.StatusInternalServerError)
				return
			}

			writeJSON(w, http.StatusCreated, map[string]any{
				"profile": p,
				"iosVpn":  buildIOSVPNConfig(cfg, p),
			})
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/v1/profiles/", func(w http.ResponseWriter, r *http.Request) {
		if !authorized(r, cfg.APIKey) {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		path := strings.TrimPrefix(r.URL.Path, "/v1/profiles/")
		parts := strings.Split(path, "/")
		if len(parts) != 2 || parts[1] != "ios-config" || strings.TrimSpace(parts[0]) == "" {
			http.NotFound(w, r)
			return
		}

		profileID := strings.TrimSpace(parts[0])
		p, ok := store.get(profileID)
		if !ok {
			http.NotFound(w, r)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"profileId": profileID,
			"iosVpn":    buildIOSVPNConfig(cfg, p),
		})
	})

	log.Printf("slipnet control API listening on %s", cfg.BindAddr)
	if err := http.ListenAndServe(cfg.BindAddr, mux); err != nil {
		log.Fatal(err)
	}
}

func loadConfig() (appConfig, error) {
	cfgPath := os.Getenv("SERVER_CONFIG")
	if cfgPath == "" {
		cfgPath = filepath.Join("server", "config.json")
	}

	data, err := os.ReadFile(cfgPath)
	if err != nil {
		return appConfig{}, err
	}

	var cfg appConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return appConfig{}, err
	}

	if cfg.BindAddr == "" {
		cfg.BindAddr = ":8080"
	}
	if cfg.PublicServerPort == 0 {
		cfg.PublicServerPort = 53
	}
	if cfg.DefaultSshPort == 0 {
		cfg.DefaultSshPort = 22
	}
	if cfg.DefaultSocksPort == 0 {
		cfg.DefaultSocksPort = 1080
	}
	if cfg.DefaultDNS == "" {
		cfg.DefaultDNS = "1.1.1.1"
	}
	if cfg.DefaultTunnelType == "" {
		cfg.DefaultTunnelType = "vayDnsSsh"
	}
	if cfg.DefaultMTU == 0 {
		cfg.DefaultMTU = 1400
	}
	if cfg.DefaultTimeoutSec == 0 {
		cfg.DefaultTimeoutSec = 60
	}
	if cfg.DefaultSshHost == "" {
		cfg.DefaultSshHost = cfg.PublicServerHost
	}
	if cfg.DefaultSocksHost == "" {
		cfg.DefaultSocksHost = cfg.PublicServerHost
	}
	if cfg.APIKey == "" || cfg.PublicServerHost == "" || cfg.TunnelDomain == "" {
		return appConfig{}, errors.New("config requires apiKey, publicServerHost, and tunnelDomain")
	}
	return cfg, nil
}

func decodeProfileRequest(r *http.Request) (profileRequest, error) {
	var req profileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return req, fmt.Errorf("invalid json body")
	}
	if strings.TrimSpace(req.Name) == "" {
		return req, fmt.Errorf("name is required")
	}
	if req.DaysValid <= 0 {
		req.DaysValid = 30
	}
	return req, nil
}

func buildProfile(cfg appConfig, req profileRequest) (storedProfile, error) {
	id, err := randomHex(12)
	if err != nil {
		return storedProfile{}, err
	}
	user, err := randomAlphaNum(10)
	if err != nil {
		return storedProfile{}, err
	}
	pass, err := randomHex(16)
	if err != nil {
		return storedProfile{}, err
	}

	tunnelType := strings.TrimSpace(req.TunnelType)
	if tunnelType == "" {
		tunnelType = cfg.DefaultTunnelType
	}
	connectionMethod := strings.TrimSpace(req.ConnectionMethod)
	if connectionMethod == "" {
		connectionMethod = "ssh"
	}

	now := time.Now().UTC()
	expires := now.Add(time.Duration(req.DaysValid) * 24 * time.Hour)

	slipnetURI := buildSlipnetURI(cfg, req.Name, tunnelType, connectionMethod, user)

	return storedProfile{
		ID:               id,
		Name:             req.Name,
		Username:         user,
		Password:         pass,
		TunnelType:       tunnelType,
		ConnectionMethod: connectionMethod,
		Server:           cfg.PublicServerHost,
		Port:             cfg.PublicServerPort,
		Domain:           cfg.TunnelDomain,
		DNSResolver:      cfg.DefaultDNS,
		DNSTransport:     "classic",
		RecordType:       "TXT",
		QueryLength:      101,
		SSHHost:          cfg.DefaultSshHost,
		SSHPort:          cfg.DefaultSshPort,
		SSHAuthType:      "password",
		Compression:      false,
		SocksHost:        cfg.DefaultSocksHost,
		SocksPort:        cfg.DefaultSocksPort,
		SocksUser:        user,
		SocksPassword:    pass,
		MTU:              cfg.DefaultMTU,
		TimeoutSec:       cfg.DefaultTimeoutSec,
		CreatedAt:        now,
		ExpiresAt:        expires,
		SlipnetURI:       slipnetURI,
	}, nil
}

func buildSlipnetURI(cfg appConfig, name, tunnelType, method, sshUser string) string {
	params := map[string]string{
		"name":             name,
		"domain":           cfg.TunnelDomain,
		"dnsResolver":      cfg.DefaultDNS,
		"dnsTransport":     "classic",
		"recordType":       "TXT",
		"queryLength":      "101",
		"connectionMethod": method,
		"sshHost":          cfg.DefaultSshHost,
		"sshPort":          fmt.Sprintf("%d", cfg.DefaultSshPort),
		"sshUser":          sshUser,
		"sshAuthType":      "password",
		"socksUser":        sshUser,
		"compression":      "0",
	}

	var keys []string
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var parts []string
	for _, k := range keys {
		v := params[k]
		parts = append(parts, fmt.Sprintf("%s=%s", k, urlQueryEscape(v)))
	}

	return fmt.Sprintf(
		"slipnet://%s@%s:%d?%s",
		tunnelType,
		cfg.PublicServerHost,
		cfg.PublicServerPort,
		strings.Join(parts, "&"),
	)
}

func urlQueryEscape(v string) string {
	return url.QueryEscape(v)
}

func authorized(r *http.Request, apiKey string) bool {
	h := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if !strings.HasPrefix(h, prefix) {
		return false
	}
	return strings.TrimSpace(strings.TrimPrefix(h, prefix)) == apiKey
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func newProfileStore(path string) (*profileStore, error) {
	s := &profileStore{path: path}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return s, nil
		}
		return nil, err
	}
	if len(data) == 0 {
		return s, nil
	}
	if err := json.Unmarshal(data, &s.profiles); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *profileStore) list() []storedProfile {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]storedProfile, len(s.profiles))
	copy(out, s.profiles)
	return out
}

func (s *profileStore) add(p storedProfile) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.profiles = append(s.profiles, p)
	raw, err := json.MarshalIndent(s.profiles, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, raw, 0o644)
}

func (s *profileStore) get(id string) (storedProfile, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, p := range s.profiles {
		if p.ID == id {
			return p, true
		}
	}
	return storedProfile{}, false
}

func buildIOSVPNConfig(cfg appConfig, p storedProfile) iosVPNConfig {
	providerBundleID := cfg.IOSProviderBundle
	if providerBundleID == "" && cfg.IOSBundleID != "" {
		providerBundleID = cfg.IOSBundleID + ".PacketTunnel"
	}

	return iosVPNConfig{
		BundleIdentifier:         cfg.IOSBundleID,
		ProviderBundleIdentifier: providerBundleID,
		ServerAddress:            p.Server,
		Username:                 p.Username,
		Password:                 p.Password,
		ProviderConfiguration: map[string]string{
			"profileId":        p.ID,
			"server":           p.Server,
			"port":             strconv.Itoa(p.Port),
			"domain":           p.Domain,
			"dnsResolver":      p.DNSResolver,
			"dnsTransport":     p.DNSTransport,
			"recordType":       p.RecordType,
			"queryLength":      strconv.Itoa(p.QueryLength),
			"connectionMethod": p.ConnectionMethod,
			"sshHost":          p.SSHHost,
			"sshPort":          strconv.Itoa(p.SSHPort),
			"sshUser":          p.Username,
			"sshPassword":      p.Password,
			"sshAuthType":      p.SSHAuthType,
			"socksHost":        p.SocksHost,
			"socksPort":        strconv.Itoa(p.SocksPort),
			"socksUser":        p.SocksUser,
			"socksPassword":    p.SocksPassword,
			"compression":      boolAsIntString(p.Compression),
			"mtu":              strconv.Itoa(p.MTU),
			"timeout":          strconv.Itoa(p.TimeoutSec),
		},
	}
}

func boolAsIntString(v bool) string {
	if v {
		return "1"
	}
	return "0"
}

func randomHex(bytesLen int) (string, error) {
	b := make([]byte, bytesLen)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func randomAlphaNum(n int) (string, error) {
	raw := make([]byte, n+8)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	s := base64.RawURLEncoding.EncodeToString(raw)
	if len(s) < n {
		return "", fmt.Errorf("failed to generate random string")
	}
	return s[:n], nil
}
