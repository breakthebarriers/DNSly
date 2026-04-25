# iOS VPN Extension Setup

This project now includes Packet Tunnel source files and entitlements, but you still need to wire them in Xcode once:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Add target: **File > New > Target > Network Extension > Packet Tunnel**.
3. Name it `PacketTunnel` (your current project already has this as `DNSly`; either name is fine).
4. Replace generated files with:
   - `PacketTunnel/PacketTunnelProvider.swift`
   - `PacketTunnel/Info.plist`
   - `PacketTunnel/PacketTunnel.entitlements`
5. In `Runner` target:
   - Build Settings > `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`
6. In extension target (`PacketTunnel` or `DNSly` in your project):
   - Build Settings > `CODE_SIGN_ENTITLEMENTS = DNSly/DNSly.entitlements` (or your extension entitlements path)
   - Build Settings > `INFOPLIST_FILE = DNSly/Info.plist` (or your extension Info.plist path)
   - Build Settings > `GENERATE_INFOPLIST_FILE = NO` (important to avoid duplicate Info.plist build errors)
7. Ensure `<YourExtension>.appex` is embedded in `Runner`:
   - Runner target > General > Frameworks, Libraries, and Embedded Content
8. Set bundle IDs:
   - Runner: `com.yourcompany.dnsly`
   - PacketTunnel: `com.yourcompany.dnsly.PacketTunnel`
9. Match those IDs in `server/config.json`:
   - `iosBundleId`
   - `iosProviderBundle`
10. Add Swift Package dependency to `PacketTunnel` target:
    - URL: `https://github.com/EbrahimTahernejad/Tun2SocksKit`
    - Add package product `Tun2SocksKit` to the `PacketTunnel` target

## If "Network Extensions" capability is missing in Xcode UI

This is common when Apple Developer account/capability state is not fully available in the UI. You can still proceed with manual settings:

- Keep `CODE_SIGN_ENTITLEMENTS` set on both Runner and extension targets
- Ensure entitlements file contains:
  - `com.apple.developer.networking.networkextension` = `packet-tunnel-provider`
- Use a real Apple Developer Team and unique bundle IDs
- Build once on a real device profile after signing refresh

## Runtime flow

- Backend creates profile: `POST /v1/profiles`
- iOS app fetches `iosVpn` payload from create response (or from `GET /v1/profiles/{id}/ios-config`)
- iOS app installs `NETunnelProviderManager` profile
- Extension starts and reads `protocolConfiguration.providerConfiguration`
- Extension routes by `connectionMethod` (`ssh` or `socks`)
- Extension performs real upstream validation:
  - SSH: TCP + SSH banner probe
  - SOCKS: SOCKS5 greeting/auth handshake probe
- Extension starts tun2socks engine (`Tun2SocksKit`) to forward packet flow
- Runner queries extension live stats using `sendProviderMessage`
- Flutter reads native stats via `MethodChannel` (`dnsly/vpn` -> `stats`)
- Runner publishes `NEVPNStatusDidChange` through `EventChannel` (`dnsly/vpn_status`)
- `ConnectionBloc` listens native status stream for immediate UI state transitions
- Status stream payload includes `lastError` fetched from extension (`handleAppMessage: last_error`)
- For `ssh` method, run your SSH dynamic port forward backend so `socksHost:socksPort` is reachable by the extension
