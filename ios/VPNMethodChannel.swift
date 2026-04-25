import Foundation
import Flutter

final class VPNMethodChannel: NSObject, FlutterPlugin {
  private let manager = VPNManager.shared
  private static var statusStreamHandler: VPNStatusStreamHandler?
  
  private func flutterError(code: String, from error: Error) -> FlutterError {
    let nsError = error as NSError
    return FlutterError(
      code: code,
      message: nsError.localizedDescription,
      details: [
        "domain": nsError.domain,
        "code": nsError.code,
        "description": nsError.localizedDescription,
      ]
    )
  }

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
          result(self.flutterError(code: "install_failed", from: error))
          return
        }
        result(true)
      }

    case "start":
      manager.start { error in
        if let error {
          result(self.flutterError(code: "start_failed", from: error))
          return
        }
        result(true)
      }

    case "stop":
      manager.stop { error in
        if let error {
          result(self.flutterError(code: "stop_failed", from: error))
          return
        }
        result(true)
      }

    case "status":
      manager.status { status, error in
        if let error {
          result(self.flutterError(code: "status_failed", from: error))
          return
        }
        result(status)
      }

    case "stats":
      manager.stats { stats, error in
        if let error {
          result(self.flutterError(code: "stats_failed", from: error))
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

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
