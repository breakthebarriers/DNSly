# Server Side (SlipNet-style Control Plane)

This directory adds a SlipNet-style provisioning backend:

- Provision VPN/tunnel profiles through HTTP API
- Generate app-compatible `slipnet://` links
- Generate iOS `NETunnelProvider` payloads for Packet Tunnel setup
- Persist issued profiles in `server/data/profiles.json`

It is intentionally a **control plane**. For real traffic tunneling, deploy data-plane services (DNSTT/NoizDNS/VayDNS + SSH/SOCKS) and point this API at those hosts.

## 1) Configure

```bash
cp server/config.example.json server/config.json
```

Edit `server/config.json`:

- `apiKey`: bearer token required by API
- `publicServerHost`: public host clients connect to
- `tunnelDomain`: delegated DNS tunnel domain
- `defaultSshHost/defaultSshPort`: your SSH endpoint
- `defaultSocksHost/defaultSocksPort`: SOCKS endpoint for tun2socks data plane

## 2) Run

```bash
go run ./server
```

Health check:

```bash
curl http://127.0.0.1:8080/health
```

## 3) Create Profiles

```bash
curl -X POST http://127.0.0.1:8080/v1/profiles \
  -H 'Authorization: Bearer change-me-long-random-token' \
  -H 'Content-Type: application/json' \
  -d '{
    "name":"User One",
    "tunnelType":"vayDnsSsh",
    "connectionMethod":"ssh",
    "daysValid":30
  }'
```

Response includes:

- `username` / `password` (issue these to your SSH/SOCKS layer)
- `slipnetUri` (import directly into the app)
- `iosVpn` (directly usable fields for `NETunnelProviderManager`)

List issued profiles:

```bash
curl http://127.0.0.1:8080/v1/profiles \
  -H 'Authorization: Bearer change-me-long-random-token'
```

Fetch iOS config for one profile:

```bash
curl http://127.0.0.1:8080/v1/profiles/<PROFILE_ID>/ios-config \
  -H 'Authorization: Bearer change-me-long-random-token'
```

## iOS Target Setup

This repo now includes:

- `ios/PacketTunnel/PacketTunnelProvider.swift`
- `ios/PacketTunnel/Info.plist`
- `ios/PacketTunnel/PacketTunnel.entitlements`
- `ios/Runner/Runner.entitlements`
- `ios/Runner/VPNManager.swift`

In Xcode, add a **Network Extension > Packet Tunnel** target named `PacketTunnel` and point it to those files.
Then set:

- Runner target `Signing & Capabilities`: add `Network Extensions` with `packet-tunnel-provider`
- PacketTunnel target `Signing & Capabilities`: add `Network Extensions` with `packet-tunnel-provider`
- Runner build settings `CODE_SIGN_ENTITLEMENTS`: `Runner/Runner.entitlements`
- PacketTunnel build settings `CODE_SIGN_ENTITLEMENTS`: `PacketTunnel/PacketTunnel.entitlements`
- PacketTunnel target `Info.plist File`: `PacketTunnel/Info.plist`

Finally, set your bundle IDs to match `iosBundleId` and `iosProviderBundle` in `server/config.json`.

## 4) Real VPN Data Plane

To make this a real VPN stack, deploy at least one tunnel backend:

- DNSTT/NoizDNS/VayDNS server for DNS transport
- SSH server and/or authenticated SOCKS5 backend
- DNS zone delegation for `tunnelDomain` to tunnel server

This API now acts as a provisioning + iOS runtime configuration endpoint that your app/extension can consume while you wire the tunnel worker in `PacketTunnelProvider.beginTunnelLoop`.
