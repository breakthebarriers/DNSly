# DNSly

<div align="right">

[🇮🇷 فارسی](README.fa.md)

</div>

![Visitors](https://visitor-badge.laobi.icu/badge?page_id=breakthebarriers.DNSly)

<p align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.25.56.png" alt="DNSly Logo" width="200">
</p>

A fast, modern anti-censorship VPN client for iOS featuring DNS tunneling with support for multiple protocols. Built with Flutter and a Go tunnel core bridged via gomobile.

> **DNSly is a legitimate anti-censorship tool** designed to help users in countries with internet censorship access the free internet. It is comparable to [Tor](https://www.torproject.org/), [Psiphon](https://psiphon.ca/), and [dnstt](https://www.bamsoftware.com/software/dnstt/). This project does not target, exploit, or attack any systems — it is a client-side privacy tool used voluntarily by end users.

## Community

Join us for updates, support, and discussions:

[![Telegram](https://img.shields.io/badge/Telegram-Break__The__Barriers-blue?logo=telegram)](https://t.me/Break_The_Barriers)
[![X (Twitter)](https://img.shields.io/badge/X-breakthebariers-black?logo=x)](https://x.com/breakthebariers)

## Donations

If DNSly has been useful to you, consider supporting development:

<div align="center">

| Bitcoin (BTC) | Tether (USDT — TRC20) |
|:---:|:---:|
| <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=bitcoin:bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx" width="150" alt="BTC QR Code"> | <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW" width="150" alt="USDT TRC20 QR Code"> |
| `bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx` | `TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW` |

</div>

## Tunnel Types

DNSly supports multiple tunnel types with optional chaining:

| Tunnel Type | Protocol | Description |
|-------------|----------|-------------|
| **VayDNS** | DNS/TXT | Optimized DNS tunneling — encodes TCP as DNS queries |
| **VayDNS + SSH** | DNS + SSH | VayDNS with SSH chaining for extra encryption |
| **VayDNS + SOCKS5** | DNS + SOCKS5 | VayDNS with upstream SOCKS5 relay |
| **SSH** | SSH | Standalone SSH dynamic port forwarding |
| **SOCKS5 Relay** | SOCKS5 | Transparent passthrough to an upstream proxy |

**DNS Transport Options:**

| Mode | Port | Protocol |
|------|------|----------|
| Classic UDP | 53 | Plain UDP |
| TCP | 53 | DNS over TCP |
| DoT | 853 | DNS-over-TLS (RFC 7858) |
| DoH | 443 | DNS-over-HTTPS POST (RFC 8484) |

## Features

- **iOS VPN Integration**: System-level packet interception via iOS NetworkExtension (PacketTunnel)
- **Multiple Tunnel Types**: VayDNS, SSH, SOCKS5, and hybrid combinations
- **DNS Transport Selection**: Choose UDP, TCP, DoT, or DoH for DNS resolution
- **SSH Tunneling**: Chain SSH through VayDNS or use standalone SSH dynamic port forwarding
- **SSH Key Auth**: Authenticate with password or PEM private key
- **SSH Cipher Selection**: Choose between AES-256-GCM, AES-128-GCM, and ChaCha20-Poly1305
- **Multiple Profiles**: Create and manage multiple server configurations
- **QR Import/Export**: Share profiles as QR codes — useful when internet is restricted
- **Encrypted Profiles**: Password-protect profiles with AES-256-CBC encryption
- **DNS Scanner**: Parallel resolver latency testing to find the fastest working DNS server
- **Real-time Stats**: Live bytes in/out, uptime, and latency tracking
- **Profile Server**: Built-in Go HTTP server for distributing profiles to devices
- **SlipNet Codec**: Compatible with `slipnet://` and `slipnet-enc://` URI formats
- **Dark Mode**: Full system-wide dark theme support
- **Cross-platform**: Flutter codebase targets iOS (primary), Android, macOS, Linux, Windows

## Screenshots

<p align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.25.56.png" alt="Home Screen" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.05.png" alt="Profiles" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.27.png" alt="Edit Profile" width="200">
</p>

<p align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.37.png" alt="Export QR" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.27.41.png" alt="DNS Scanner" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.28.14.png" alt="DNS Scanner Results" width="200">
</p>

## Architecture

Device traffic is captured by **Tun2Socks** via the iOS PacketTunnel extension and routed to a local SOCKS5 listener. The Go core handles the tunnel:

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

## VayDNS Wire Protocol

Each TCP connection is assigned a random 4-byte session ID. Data is chunked, Base32-encoded, and embedded in DNS QNAMEs:

```
Upload query QNAME:
  {base32(sid[4] ‖ seq[4] ‖ [isSyn:1] ‖ payload)}.d.{domain}.

Download poll QNAME:
  {base32(sid[4] ‖ recvSeq[4])}.r.{domain}.
```

| Field | Size | Description |
|-------|------|-------------|
| `sid` | 4 bytes | Random session ID per TCP connection |
| `seq` | 4 bytes | Big-endian uint32, increments per chunk |
| `isSyn` | 1 byte | `0x01` on first chunk only (carries target address) |
| `payload` | ≤120 bytes | Application data fragment |

**Download polling interval:** 80 ms

## Profile Format (SlipNet)

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

## Requirements

### iOS App
- iOS 15.0 or higher
- Xcode 15 or later
- Flutter SDK (stable channel)
- Go 1.21+ with gomobile (`go install golang.org/x/mobile/cmd/gomobile@latest`)

## Building

### 1. Build the Go tunnel framework

```bash
cd go
gomobile init
gomobile bind -target=ios -o ../ios/Frameworks/Tunnel.xcframework ./tunnel
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Run on simulator or device

```bash
flutter run --release
```

> **Note:** The iOS PacketTunnel extension requires a real device with a paid Apple Developer account for VPN entitlements. The simulator can run the UI but the actual tunnel requires a device.

### Building the Profile Server

```bash
cd server
go build -o dnsly-server .
./dnsly-server
```

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
    profile_repository.dart    # Hive persistence
    vpn_platform_service.dart  # MethodChannel / EventChannel iOS bridge
  utils/
    slipnet_codec.dart         # Encode/decode, AES-CBC, legacy v1 compat

ios/
  Runner/              # iOS app target
  DNSly/               # PacketTunnel network extension
  Frameworks/          # Built Go framework (Tunnel.xcframework)

test/
  slipnet_enc_upstream_test.dart
  upstream_slipnet_decoder_test.dart
```

## Tech Stack

### Tunnel Core (Go)
- `golang.org/x/crypto` — SSH, TLS, AEAD primitives
- `golang.org/x/net` — DNS packet handling
- `golang.org/x/mobile` — gomobile bind for iOS framework generation
- Transport: UDP 53 · TCP 53 · DoT 853 · DoH 443

### Mobile Client (Flutter / Dart 3)
- `flutter_bloc ^9.1.1` — BLoC state management
- `hive_flutter ^1.1.0` + `shared_preferences ^2.2.2` — local persistence
- `mobile_scanner ^7.2.0` + `qr_flutter ^4.1.0` — QR import/export
- `encrypt ^5.0.3` — AES-256-CBC profile encryption
- `crypto ^3.0.6` — SHA-256 key derivation
- `cryptography ^2.7.0` — additional cipher support
- `uuid ^4.2.1` — profile ID generation

### Profile Server (Go)
- Standard library only
- REST API + Bearer token auth
- iOS `NEVPNProtocol` config generation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is released under the MIT License. See [LICENSE](./LICENSE) for details.
