import Foundation
import Flutter

final class VPNMethodChannel: NSObject, FlutterPlugin {
  private let manager = VPNManager.shared
  private static var statusStreamHandler: VPNStatusStreamHandler?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dnsly/vpn",
      binaryMessenger: registrar.messenger()
    )
    let statusChannel = FlutterEventChannel(
      name: "dnsly/vpn_status",
      binaryMessenger: registrar.messenger()
    )
    let instance = VPNMethodChannel()
    let statusStream = VPNStatusStreamHandler()
    VPNMethodChannel.statusStreamHandler = statusStream
    registrar.addMethodCallDelegate(instance, channel: channel)
    statusChannel.setStreamHandler(statusStream)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
    switch call.method {
    case "installProfile", "start", "stop":
      result(FlutterError(
        code: "simulator_unsupported",
        message: "VPN is not supported on the iOS Simulator. Please test on a physical iPhone.",
        details: nil
      ))
      return
    case "status":
      result("disconnected")
      return
    case "stats":
      result(nil)
      return
    default:
      break
    }
    #endif

    switch call.method {
    case "installProfile":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing args", details: nil))
        return
      }

      guard
        let name = args["name"] as? String,
        let serverAddress = args["serverAddress"] as? String,
        let username = args["username"] as? String,
        let password = args["password"] as? String,
        let providerBundleIdentifier = args["providerBundleIdentifier"] as? String,
        let providerConfiguration = args["providerConfiguration"] as? [String: String]
      else {
        result(FlutterError(code: "bad_args", message: "Invalid install args", details: nil))
        return
      }

      manager.installProfile(
        name: name,
        serverAddress: serverAddress,
        username: username,
        password: password,
        providerBundleIdentifier: providerBundleIdentifier,
        providerConfiguration: providerConfiguration
      ) { error in
        if let error {
          result(FlutterError(code: "install_failed", message: error.localizedDescription, details: nil))
          return
        }
        result(true)
      }

    case "start":
      manager.start { error in
        if let error {
          result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
          return
        }
        result(true)
      }

    case "stop":
      manager.stop { error in
        if let error {
          result(FlutterError(code: "stop_failed", message: error.localizedDescription, details: nil))
          return
        }
        result(true)
      }

    case "status":
      manager.status { status, error in
        if let error {
          result(FlutterError(code: "status_failed", message: error.localizedDescription, details: nil))
          return
        }
        result(status)
      }

    case "stats":
      manager.stats { stats, error in
        if let error {
          result(FlutterError(code: "stats_failed", message: error.localizedDescription, details: nil))
          return
        }
        guard let stats else {
          result(nil)
          return
        }
        result([
          "bytesIn": stats.bytesIn,
          "bytesOut": stats.bytesOut,
          "packetsIn": stats.packetsIn,
          "packetsOut": stats.packetsOut,
          "uptimeSec": stats.uptimeSec,
        ])
      }

    // ── Advanced DNS Scanner ──────────────────────────────────────────────────

    case "scanResolver":
      guard
        let args = call.arguments as? [String: Any],
        let resolver = args["resolver"] as? String,
        let domain = args["domain"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "resolver and domain required", details: nil))
        return
      }
      let timeoutSec = Int64(args["timeoutSec"] as? Int ?? 5)
      DispatchQueue.global(qos: .userInitiated).async {
        let json = TunnelScanResolver(resolver, domain, timeoutSec)
        DispatchQueue.main.async { result(json) }
      }

    case "verifyPrismServer":
      guard
        let args = call.arguments as? [String: Any],
        let resolver = args["resolver"] as? String,
        let domain = args["domain"] as? String,
        let secret = args["sharedSecret"] as? String,
        let serverID = args["serverID"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "resolver, domain, sharedSecret, serverID required", details: nil))
        return
      }
      let timeoutSec = Int64(args["timeoutSec"] as? Int ?? 5)
      DispatchQueue.global(qos: .userInitiated).async {
        let ok = TunnelVerifyPrismServer(resolver, domain, secret, serverID, timeoutSec)
        DispatchQueue.main.async { result(ok) }
      }

    case "filterByCountry":
      guard
        let args = call.arguments as? [String: Any],
        let resolversCSV = args["resolvers"] as? String,
        let country = args["country"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "resolvers and country required", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let filtered = TunnelFilterResolversByCountry(resolversCSV, country)
        DispatchQueue.main.async { result(filtered) }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
