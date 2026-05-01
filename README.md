# DNSly App

<div align="right">

[🇮🇷 فارسی](README.fa.md)

</div>

![Visitors](https://visitor-badge.laobi.icu/badge?page_id=breakthebarriers.DNSly)

**DNSly** is a Flutter-based anti-censorship mobile client focused on managing and using DNS/tunnel profiles. The tunnel core is written in Go, bridged to iOS via gomobile, and supports multiple transport protocols.

---

## Screenshots

<div align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.25.56.png" width="200" alt="Home Screen">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.05.png" width="200" alt="Profiles List">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.27.png" width="200" alt="Edit Profile">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.37.png" width="200" alt="Export QR">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.27.41.png" width="200" alt="DNS Scanner">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.28.14.png" width="200" alt="DNS Scanner">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.28.45.png" width="200" alt="DNS Scanner">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.29.41.png" width="200" alt="DNS Scanner">
</div>

---

## Architecture

Device traffic is captured by **Tun2Socks** via the iOS PacketTunnel extension and routed to a local SOCKS5 listener. The Go core handles the rest:

```
iOS PacketTunnel Extension
        ↓
   Tun2Socks (userspace)
        ↓
Local SOCKS5 (127.0.0.1:PORT)  ← Go tunnel engine
        ↓
   ┌────┴────────────────────┐
   │  TunnelType selector    │
   └────┬──────┬──────┬──────┘
        │      │      │
   VayDNS   SSH    SOCKS5
  Tunnel   Proxy   Relay
```

**Tunnel modes:**
- **VayDNS** — encapsulates TCP payloads as DNS TXT queries over UDP / TCP / DoH / DoT.
- **SSH Proxy** — dynamic SSH port forwarding equivalent to `ssh -D`.
- **SOCKS5 Relay** — transparent passthrough to an upstream SOCKS5 proxy.
- **Hybrid** — VayDNS combined with SSH or SOCKS5 as fallback.

---

## VayDNS Wire Protocol

Each TCP connection is assigned a random 4-byte session ID. Data is chunked, Base32-encoded, and embedded in DNS QNAMEs:

```
Upload query QNAME:
  {base32(sid[4] ‖ seq[4] ‖ [isSyn:1] ‖ payload)}.d.{domain}.

Download poll QNAME:
  {base32(sid[4] ‖ recvSeq[4])}.r.{domain}.

Example:
  AEBAGBAF3DFQQ.d.tunnel.example.com.   → TXT query (upload chunk)
  AEBAGBAF.r.tunnel.example.com.        → TXT query (poll for reply)
```

| Field | Size | Description |
|---|---|---|
| `sid` | 4 bytes | Random session ID per TCP connection |
| `seq` | 4 bytes | Big-endian uint32, increments per chunk |
| `isSyn` | 1 byte | `0x01` on first chunk only (carries target address) |
| `payload` | ≤120 bytes | Application data fragment |

**Download polling interval:** 80 ms

**DNS transports:**

| Mode | Port | Protocol |
|---|---|---|
| `classic` | 53 | Plain UDP |
| `tcp` | 53 | DNS over TCP (length-prefixed) |
| `dot` | 853 | DNS-over-TLS (RFC 7858) |
| `doh` | 443 | DNS-over-HTTPS POST (RFC 8484) |

---

## Profile & SlipNet Codec

Profiles are exported in two formats:

**Plain:**
```
slipnet://tunnelType@host:port?name=...&domain=...&dnsTransport=...&...
```

**Encrypted (AES-256-CBC):**
```
slipnet-enc://base64(envelope)

envelope = {
  "v": 2,
  "iv": "<base64 16-byte random IV>",
  "ct": "<base64 AES-256-CBC ciphertext>",
  "meta": { name, server, domain, ... }   ← plaintext preview fields
}

Key derivation: SHA256(password) → 32-byte AES key
```

The `meta` field allows import preview without the password. Full decryption requires the correct password.

**Legacy v1 format (upstream Slipnet compatibility):**
```
0x01 | 12-byte GCM IV | AES-256-GCM(profile) | 16-byte tag
Key: raw 64-char hex string (no derivation)
```

---

## Data Model

The core `Profile` model covers all tunnel variants:

```dart
class Profile {
  String id                  // UUID v4
  String name
  TunnelType tunnelType      // vayDns | vayDnsSsh | vayDnsSocks | ssh | socks5
  String server              // Upstream server hostname/IP
  int port
  String domain              // DNS tunnel domain

  // DNS
  String dnsResolver         // Default: 1.1.1.1
  DnsTransport dnsTransport  // classic | tcp | doh | dot
  DnsRecordType recordType   // TXT (default) | A (firewall bypass)
  int queryLength            // Max payload bytes, default 101

  // SSH
  String? sshHost
  int? sshPort               // Default: 22
  String? sshUser
  String? sshPassword
  String? sshKey             // PEM private key
  SshCipher? sshCipher       // aes256Gcm | aes128Gcm | chacha20Poly1305
  SshAuthType sshAuthType    // password | key

  // SOCKS5
  String? socksUser
  String? socksPassword

  // Network
  bool compression           // SSH compression
  int? mtu                   // Default: 1400
  int? timeout               // Seconds

  // Encrypted import state
  bool isLocked
  String? encryptedUri
}
```

---

## State Management (BLoC)

The app uses three BLoCs:

### ConnectionBloc

```dart
Events:
  ConnectionStarted(Profile)
  ConnectionStopped()
  ConnectionStatsUpdated(bytesIn, bytesOut, uptime, latencyMs)
  ConnectionErrorOccurred(String message)
  ConnectionNativeStatusChanged(String status, String? error)

State:
  ConnectionStatus   // disconnected | connecting | connected | stopping | error
  Profile? activeProfile
  int bytesIn / bytesOut
  Duration uptime
  int latencyMs
  List<String> logs  // timestamped event log
```

### ProfileBloc

```dart
Events:
  ProfilesLoaded()
  ProfileAdded(Profile)
  ProfileUpdated(Profile)
  ProfileDeleted(String id)
  ProfileActivated(Profile)
  ProfileImported(String uris)           // space/comma/newline-separated
  ProfileImportedEncrypted(uri, password)
  EncryptedProfileUnlockRequested(uri, password)

State:
  ProfileStatus           // initial | loading | loaded | error
  List<Profile> profiles
  Profile? activeProfile
  String? pendingEncryptedPayload
  String? importError
```

### DnsScannerBloc

```dart
Events:
  DnsScanStarted(List<String> resolvers)
  DnsScanReset()

States:
  DnsScannerInitial | DnsScannerLoading
  DnsScannerSuccess(fastestResolver, latencyMs)
  DnsScannerFailure(message)
```

The DNS scanner probes port 53 on all resolvers in parallel and selects the fastest.

---

## Go Tunnel API

Public API of the Go tunnel engine (gomobile-bindable):

```go
// Config passed as JSON string — avoids reflection for gomobile compatibility
Start(configJSON string) int   // returns local SOCKS5 port, -1 on error
Stop()
IsRunning() bool
LastError() string
```

**Config JSON fields:**

```json
{
  "tunnelType":    "vayDnsSsh",
  "server":        "vpn.example.com",
  "port":          53,
  "domain":        "tunnel.example.com",
  "dnsResolver":   "1.1.1.1",
  "dnsTransport":  "classic",
  "recordType":    "TXT",
  "queryLength":   101,
  "sshHost":       "vpn.example.com",
  "sshPort":       22,
  "sshUser":       "user",
  "sshPassword":   "pass",
  "sshKey":        "-----BEGIN RSA PRIVATE KEY-----\n...",
  "socksUser":     "",
  "socksPassword": "",
  "mtu":           1400,
  "timeout":       60
}
```

---

## Profile Server API

A minimal Go HTTP server for profile distribution (zero external dependencies):

```
GET  /health                           → { "ok": true, "time": "..." }
GET  /v1/profiles                      → { "profiles": [...] }
POST /v1/profiles                      → { "profile": {...}, "iosVpn": {...} }
GET  /v1/profiles/{id}/ios-config      → { "profileId": "...", "iosVpn": {...} }
```

All `/v1/` routes require `Authorization: Bearer {apiKey}`.

**iOS VPN config** returned on profile creation maps all tunnel params as string key-value pairs into the `NEVPNProtocolConfiguration.providerConfiguration` dictionary for the PacketTunnel extension.

**Storage:** file-based JSON at `server/data/profiles.json`, mutex-protected.

---

## Tech Stack

**Core (Go)**
- `golang.org/x/crypto` — SSH, TLS, AEAD primitives
- `golang.org/x/net` — DNS packet handling
- `golang.org/x/mobile` — gomobile bind for iOS framework generation
- Transport: UDP 53 · TCP 53 · DoT 853 · DoH 443

**Mobile client (Flutter / Dart 3)**
- `flutter_bloc ^9.1.1` — state management
- `hive_flutter ^1.1.0` + `shared_preferences ^2.2.2` — local persistence
- `mobile_scanner ^7.2.0` + `qr_flutter ^4.1.0` — QR import/export
- `encrypt ^5.0.3` — AES-256-CBC profile encryption
- `crypto ^3.0.6` — SHA-256 key derivation
- `cryptography ^2.7.0` — additional cipher support
- `uuid ^4.2.1` — profile ID generation

**Profile server (Go)**
- Standard library only
- REST + Bearer token auth
- iOS `NEVPNProtocol` config generation

---

## Support the Project

If DNSly has been useful to you, consider supporting development:

<div align="center">

| Bitcoin (BTC) | Tether (USDT — TRC20) |
|:---:|:---:|
| <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=bitcoin:bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx" width="150" alt="BTC QR Code"> | <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW" width="150" alt="USDT TRC20 QR Code"> |
| `bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx` | `TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW` |

</div>

---

## Project Structure

```
go/
  tunnel/
    tunnel.go          # Transport selector, gomobile public API
    dns_tunnel.go      # VayDNS: UDP/TCP/DoH/DoT, chunking, polling
    ssh_proxy.go       # SSH dynamic port forwarding (-D equivalent)
    socks_relay.go     # SOCKS5 transparent relay
  go.mod

server/
  main.go              # REST API, profile storage, iOS VPN config gen
  go.mod

lib/
  app.dart             # Root widget, BLoC providers
  models/
    profile.dart       # Core data model (all tunnel variants)
  blocs/
    connection/        # Connection lifecycle, stats, native bridge
    profile/           # CRUD, import (plain + encrypted), activation
    dns_scanner/       # Parallel resolver latency probe
  screens/
    home/              # Connection status, connect/disconnect
    profiles/          # Profile list and management
    dns_scanner/       # Resolver benchmark UI
    settings/          # App settings
  services/
    profile_repository.dart    # SharedPreferences persistence
    vpn_platform_service.dart  # MethodChannel / EventChannel iOS bridge
  utils/
    slipnet_codec.dart         # Encode/decode, AES-CBC, legacy v1 compat

test/
  slipnet_enc_upstream_test.dart
  upstream_slipnet_decoder_test.dart
```
