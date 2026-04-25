import Foundation
import Network
import NetworkExtension
#if canImport(Tun2SocksKit)
import Tun2SocksKit
#endif
// The Go mobile xcframework is built from go/ with `make ios`.
// After building, add Tunnel.xcframework to the DNSly extension target.
#if canImport(Tunnel)
import Tunnel
#endif

final class PacketTunnelProvider: NEPacketTunnelProvider {

  private let ioQueue = DispatchQueue(label: "dnsly.tunnel.io", qos: .userInitiated)
  private var startedAt = Date()
  private var lastErrorMessage: String?

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    startedAt = Date()
    lastErrorMessage = nil

    guard
      let proto = protocolConfiguration as? NETunnelProviderProtocol,
      let raw = proto.providerConfiguration as? [String: String]
    else {
      finish(NSError(domain: "PacketTunnel", code: 1,
                     info: "Missing provider configuration"), completionHandler)
      return
    }

    // ── Network settings ────────────────────────────────────────────────────
    let server = raw["server"] ?? "127.0.0.1"
    let mtu    = Int(raw["mtu"] ?? "1400") ?? 1400

    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: server)
    settings.mtu = NSNumber(value: mtu)

    let ipv4 = NEIPv4Settings(addresses: ["10.7.0.2"], subnetMasks: ["255.255.255.0"])
    ipv4.includedRoutes = [NEIPv4Route.default()]
    settings.ipv4Settings = ipv4

    let resolvers = (raw["dnsResolver"] ?? "1.1.1.1")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let dns = NEDNSSettings(servers: resolvers.isEmpty ? ["1.1.1.1"] : resolvers)
    dns.matchDomains = [""]
    settings.dnsSettings = dns

    setTunnelNetworkSettings(settings) { [weak self] error in
      if let error {
        self?.finish(error, completionHandler)
        return
      }
      self?.startTransport(raw: raw, mtu: mtu, completionHandler: completionHandler)
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    stopGoTunnel()
    completionHandler()
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)? = nil
  ) {
    guard
      let obj = try? JSONSerialization.jsonObject(with: messageData),
      let req = obj as? [String: Any],
      let action = req["action"] as? String
    else { completionHandler?(nil); return }

    switch action {
    case "stats":
      let data = try? JSONSerialization.data(withJSONObject: statsPayload())
      completionHandler?(data)
    case "last_error":
      let data = try? JSONSerialization.data(withJSONObject: [
        "message": lastErrorMessage ?? "",
      ])
      completionHandler?(data)
    default:
      completionHandler?(nil)
    }
  }

  // ── Transport selection ────────────────────────────────────────────────────

  private func startTransport(
    raw: [String: String],
    mtu: Int,
    completionHandler: @escaping (Error?) -> Void
  ) {
    let tunnelType = (raw["tunnelType"] ?? "socks5").lowercased()
    let method     = (raw["connectionMethod"] ?? "socks").lowercased()

    // Determine which mode to use.
    // Priority: tunnelType field (from profile) → connectionMethod legacy field.
    let useSSH = tunnelType.contains("ssh") || method == "ssh"
    let useDNS = tunnelType == "vaydns" || tunnelType == "vayDns".lowercased()

    if useDNS {
      startViaGoTunnel(raw: raw, mtu: mtu, completionHandler: completionHandler)
    } else if useSSH {
      startViaGoTunnel(raw: raw, mtu: mtu, completionHandler: completionHandler)
    } else {
      // Direct SOCKS5 – Go relay OR legacy path if Go is not linked.
      startViaGoTunnel(raw: raw, mtu: mtu, completionHandler: completionHandler)
    }
  }

  // ── Go mobile tunnel ───────────────────────────────────────────────────────

  /// Starts the Go tunnel library, receives the local SOCKS5 port, then
  /// connects Tun2Socks to 127.0.0.1:<port>.
  private func startViaGoTunnel(
    raw: [String: String],
    mtu: Int,
    completionHandler: @escaping (Error?) -> Void
  ) {
    #if canImport(Tunnel)
    ioQueue.async { [weak self] in
      guard let self else { return }

      let configJSON = self.buildGoConfig(raw: raw)
      NSLog("[DNSly] Starting Go tunnel, type=\(raw["tunnelType"] ?? "?")")

      let port = TunnelStart(configJSON)
      guard port > 0 else {
        let err = NSError(domain: "PacketTunnel", code: 10,
                          info: "Go tunnel failed to start (port=\(port))")
        self.finish(err, completionHandler)
        return
      }

      NSLog("[DNSly] Go tunnel listening on 127.0.0.1:\(port)")
      self.startTun2Socks(
        socksHost: "127.0.0.1",
        socksPort: port,
        username:  "",
        password:  "",
        mtu:       mtu,
        dnsServer: (raw["dnsResolver"] ?? "1.1.1.1")
          .split(separator: ",").first.map(String.init) ?? "1.1.1.1",
        completionHandler: completionHandler
      )
    }
    #else
    // Go xcframework not yet linked – fall back to legacy SOCKS5 direct path.
    NSLog("[DNSly] Tunnel.xcframework not linked, using legacy SOCKS5 path")
    startLegacySocks(raw: raw, mtu: mtu, completionHandler: completionHandler)
    #endif
  }

  private func stopGoTunnel() {
    #if canImport(Tunnel)
    TunnelStop()
    #endif
  }

  /// Serialises the providerConfiguration into JSON for the Go library.
  private func buildGoConfig(raw: [String: String]) -> String {
    var dict: [String: Any] = [:]
    let copy: [(String, Any?)] = [
      ("tunnelType",    raw["tunnelType"]),
      ("server",        raw["server"]),
      ("port",          raw["port"].flatMap(Int.init)),
      ("domain",        raw["domain"]),
      ("dnsResolver",   raw["dnsResolver"]),
      ("dnsTransport",  raw["dnsTransport"]),
      ("recordType",    raw["recordType"]),
      ("queryLength",   raw["queryLength"].flatMap(Int.init)),
      ("sshHost",       raw["sshHost"]),
      ("sshPort",       raw["sshPort"].flatMap(Int.init)),
      ("sshUser",       raw["sshUser"]),
      ("sshPassword",   raw["sshPassword"]),
      ("sshKey",        raw["sshKey"]),
      ("socksUser",     raw["socksUser"]),
      ("socksPassword", raw["socksPassword"]),
      ("mtu",           raw["mtu"].flatMap(Int.init)),
      ("timeout",       raw["timeout"].flatMap(Int.init)),
    ]
    for (k, v) in copy {
      if let v { dict[k] = v }
    }
    let data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    return String(data: data, encoding: .utf8) ?? "{}"
  }

  // ── Tun2Socks ─────────────────────────────────────────────────────────────

  private func startTun2Socks(
    socksHost: String,
    socksPort: Int,
    username: String,
    password: String,
    mtu: Int,
    dnsServer: String,
    completionHandler: @escaping (Error?) -> Void
  ) {
    #if canImport(Tun2SocksKit)
    let yaml = Tun2SocksConfigBuilder.make(
      socksHost: socksHost,
      socksPort: socksPort,
      username:  username,
      password:  password,
      mtu:       mtu,
      dnsServer: dnsServer
    )
    ioQueue.async {
      _ = Socks5Tunnel.run(withConfig: .string(content: yaml))
    }
    completionHandler(nil)
    #else
    finish(NSError(domain: "PacketTunnel", code: 20,
                   info: "Tun2SocksKit not linked"), completionHandler)
    #endif
  }

  // ── Legacy SOCKS5 path (no Go framework) ──────────────────────────────────

  private func startLegacySocks(
    raw: [String: String],
    mtu: Int,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard let host = raw["socksHost"] ?? raw["server"], !host.isEmpty else {
      finish(NSError(domain: "PacketTunnel", code: 5,
                     info: "Missing SOCKS server"), completionHandler)
      return
    }
    let port = Int(raw["socksPort"] ?? raw["port"] ?? "1080") ?? 1080
    let user = raw["socksUser"] ?? ""
    let pass = raw["socksPassword"] ?? ""
    let dns  = (raw["dnsResolver"] ?? "1.1.1.1")
      .split(separator: ",").first.map(String.init) ?? "1.1.1.1"

    ioQueue.async { [weak self] in
      guard let self else { return }
      do {
        try Socks5Probe.verify(host: host, port: port,
                               username: user, password: pass, timeout: 8)
        self.startTun2Socks(socksHost: host, socksPort: port,
                            username: user, password: pass,
                            mtu: mtu, dnsServer: dns,
                            completionHandler: completionHandler)
      } catch {
        self.finish(error, completionHandler)
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private func finish(_ error: Error, _ handler: @escaping (Error?) -> Void) {
    lastErrorMessage = (error as NSError).localizedDescription
    handler(error)
  }

  private func setLastError(_ error: Error) {
    lastErrorMessage = (error as NSError).localizedDescription
  }
}

// ── Stats ──────────────────────────────────────────────────────────────────

extension PacketTunnelProvider {
  private func statsPayload() -> [String: Any] {
    let uptime = Int(Date().timeIntervalSince(startedAt))
    #if canImport(Tun2SocksKit)
    let s = Socks5Tunnel.stats
    return [
      "bytesIn":    Int(s.down.bytes),
      "bytesOut":   Int(s.up.bytes),
      "packetsIn":  Int(s.down.packets),
      "packetsOut": Int(s.up.packets),
      "uptimeSec":  uptime,
      "source":     "tun2socks",
    ]
    #else
    return [
      "bytesIn": 0, "bytesOut": 0,
      "packetsIn": 0, "packetsOut": 0,
      "uptimeSec": uptime, "source": "none",
    ]
    #endif
  }
}

// ── Tun2SocksConfigBuilder ────────────────────────────────────────────────

private enum Tun2SocksConfigBuilder {
  static func make(
    socksHost: String,
    socksPort: Int,
    username: String,
    password: String,
    mtu: Int,
    dnsServer: String
  ) -> String {
    let authBlock = username.isEmpty ? "" : """
      username: "\(esc(username))"
      password: "\(esc(password))"
      """
    return """
    tunnel:
      mtu: \(mtu)
    socks5:
      address: "\(esc(socksHost))"
      port: \(socksPort)
    \(authBlock)
    dns:
      - "\(esc(dnsServer))"
    """
  }

  private static func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "\"", with: "\\\"")
  }
}

// ── Socks5Probe ──────────────────────────────────────────────────────────

private enum Socks5Probe {
  static func verify(
    host: String, port: Int,
    username: String, password: String,
    timeout: TimeInterval
  ) throws {
    guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
      throw nse(25, "Invalid SOCKS port")
    }
    let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
    let sem  = DispatchSemaphore(value: 0)
    var verifyError: Error?

    conn.stateUpdateHandler = { state in
      switch state {
      case .ready:
        runHandshake(conn, username: username, password: password) { err in
          verifyError = err; sem.signal(); conn.cancel()
        }
      case .failed(let e):
        verifyError = e; sem.signal()
      default: break
      }
    }
    conn.start(queue: .global(qos: .utility))
    if sem.wait(timeout: .now() + timeout) == .timedOut {
      conn.cancel(); throw nse(20, "SOCKS probe timeout")
    }
    if let e = verifyError { throw e }
  }

  private static func runHandshake(
    _ c: NWConnection, username: String, password: String,
    completion: @escaping (Error?) -> Void
  ) {
    let wantsAuth = !username.isEmpty
    let methods: [UInt8] = wantsAuth ? [0x02, 0x00] : [0x00]
    var greeting = Data([0x05, UInt8(methods.count)]); greeting.append(contentsOf: methods)

    send(c, greeting) { err in
      guard err == nil else { completion(err); return }
      recv(c, n: 2) { data, err in
        guard err == nil, let data, data.count == 2, data[0] == 0x05 else {
          completion(err ?? nse(21, "Bad SOCKS greeting")); return
        }
        if data[1] == 0x00 { completion(nil); return }
        guard data[1] == 0x02, wantsAuth else {
          completion(nse(22, "SOCKS auth method mismatch")); return
        }
        let u = Array(username.utf8), p = Array(password.utf8)
        var auth = Data([0x01, UInt8(u.count)]); auth.append(contentsOf: u)
        auth.append(UInt8(p.count)); auth.append(contentsOf: p)
        send(c, auth) { err in
          guard err == nil else { completion(err); return }
          recv(c, n: 2) { data, err in
            guard err == nil, let data, data.count == 2,
                  data[0] == 0x01, data[1] == 0x00
            else { completion(err ?? nse(24, "SOCKS auth failed")); return }
            completion(nil)
          }
        }
      }
    }
  }

  private static func send(_ c: NWConnection, _ d: Data, _ cb: @escaping (Error?) -> Void) {
    c.send(content: d, completion: .contentProcessed { cb($0) })
  }
  private static func recv(_ c: NWConnection, n: Int, _ cb: @escaping (Data?, Error?) -> Void) {
    c.receive(minimumIncompleteLength: n, maximumLength: n) { data, _, _, err in cb(data, err) }
  }
}

// ── Convenience ──────────────────────────────────────────────────────────

private func nse(_ code: Int, _ msg: String) -> NSError {
  NSError(domain: "PacketTunnel", code: code,
          userInfo: [NSLocalizedDescriptionKey: msg])
}

extension NSError {
  convenience init(domain: String, code: Int, info: String) {
    self.init(domain: domain, code: code,
              userInfo: [NSLocalizedDescriptionKey: info])
  }
}
