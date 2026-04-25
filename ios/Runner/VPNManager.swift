import Foundation
import NetworkExtension

struct VPNRuntimeStats {
  let bytesIn: Int
  let bytesOut: Int
  let packetsIn: Int
  let packetsOut: Int
  let uptimeSec: Int
}

final class VPNManager {
  static let shared = VPNManager()
  private init() {}

  func installProfile(
    name: String,
    serverAddress: String,
    username: String,
    password: String,
    providerBundleIdentifier: String,
    providerConfiguration: [String: String],
    completion: @escaping (Error?) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, loadError in
      if let loadError {
        completion(loadError)
        return
      }

      let manager = managers?.first ?? NETunnelProviderManager()
      let proto = NETunnelProviderProtocol()
      proto.providerBundleIdentifier = providerBundleIdentifier
      proto.serverAddress = serverAddress
      proto.username = username
      proto.providerConfiguration = providerConfiguration
      proto.disconnectOnSleep = false
      manager.protocolConfiguration = proto
      manager.localizedDescription = name
      manager.isEnabled = true

      manager.saveToPreferences { saveError in
        guard saveError == nil else {
          completion(saveError)
          return
        }
        manager.loadFromPreferences { reloadError in
          guard reloadError == nil else {
            completion(reloadError)
            return
          }

          // Password is stored in keychain by tunnel implementation in production.
          // Keeping it in providerConfiguration is easier for initial bootstrap.
          manager.protocolConfiguration?.providerConfiguration?["sshPassword"] = password
          manager.saveToPreferences(completionHandler: completion)
        }
      }
    }
  }

  func start(completion: @escaping (Error?) -> Void) {
    loadManager { manager, error in
      if let error {
        completion(error)
        return
      }
      guard let manager else {
        completion(NSError(domain: "VPNManager", code: 2, userInfo: [
          NSLocalizedDescriptionKey: "VPN profile is not installed",
        ]))
        return
      }
      do {
        try manager.connection.startVPNTunnel()
        completion(nil)
      } catch {
        completion(error)
      }
    }
  }

  func stop(completion: @escaping (Error?) -> Void) {
    loadManager { manager, error in
      if let error {
        completion(error)
        return
      }
      guard let manager else {
        completion(nil)
        return
      }
      manager.connection.stopVPNTunnel()
      completion(nil)
    }
  }

  func status(completion: @escaping (String, Error?) -> Void) {
    loadManager { manager, error in
      if let error {
        completion("error", error)
        return
      }
      guard let manager else {
        completion("disconnected", nil)
        return
      }
      completion(Self.statusString(for: manager.connection.status), nil)
    }
  }

  func stats(completion: @escaping (VPNRuntimeStats?, Error?) -> Void) {
    loadManager { manager, error in
      if let error {
        completion(nil, error)
        return
      }
      guard
        let manager,
        let session = manager.connection as? NETunnelProviderSession
      else {
        completion(nil, nil)
        return
      }
      let payload: [String: Any] = ["action": "stats"]
      guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
        completion(nil, NSError(domain: "VPNManager", code: 3, userInfo: [
          NSLocalizedDescriptionKey: "Failed to encode stats request",
        ]))
        return
      }

      do {
        try session.sendProviderMessage(data) { reply in
          guard let reply else {
            completion(nil, nil)
            return
          }
          do {
            let raw = try JSONSerialization.jsonObject(with: reply)
            guard let map = raw as? [String: Any] else {
              completion(nil, nil)
              return
            }
            let stats = VPNRuntimeStats(
              bytesIn: map["bytesIn"] as? Int ?? 0,
              bytesOut: map["bytesOut"] as? Int ?? 0,
              packetsIn: map["packetsIn"] as? Int ?? 0,
              packetsOut: map["packetsOut"] as? Int ?? 0,
              uptimeSec: map["uptimeSec"] as? Int ?? 0
            )
            completion(stats, nil)
          } catch {
            completion(nil, error)
          }
        }
      } catch {
        completion(nil, error)
      }
    }
  }

  func lastError(completion: @escaping (String?, Error?) -> Void) {
    withProviderReply(action: "last_error") { payload, error in
      if let error {
        completion(nil, error)
        return
      }
      completion(payload?["message"] as? String, nil)
    }
  }

  private func loadManager(completion: @escaping (NETunnelProviderManager?, Error?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        completion(nil, error)
        return
      }
      completion(managers?.first, nil)
    }
  }

  private func withProviderReply(
    action: String,
    completion: @escaping ([String: Any]?, Error?) -> Void
  ) {
    loadManager { manager, error in
      if let error {
        completion(nil, error)
        return
      }
      guard
        let manager,
        let session = manager.connection as? NETunnelProviderSession
      else {
        completion(nil, nil)
        return
      }

      let payload: [String: Any] = ["action": action]
      guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
        completion(nil, NSError(domain: "VPNManager", code: 4, userInfo: [
          NSLocalizedDescriptionKey: "Failed to encode provider message",
        ]))
        return
      }

      do {
        try session.sendProviderMessage(data) { reply in
          guard let reply else {
            completion(nil, nil)
            return
          }
          do {
            let raw = try JSONSerialization.jsonObject(with: reply)
            completion(raw as? [String: Any], nil)
          } catch {
            completion(nil, error)
          }
        }
      } catch {
        completion(nil, error)
      }
    }
  }

  private static func statusString(for status: NEVPNStatus) -> String {
    switch status {
    case .invalid:
      return "invalid"
    case .disconnected:
      return "disconnected"
    case .connecting:
      return "connecting"
    case .connected:
      return "connected"
    case .reasserting:
      return "reasserting"
    case .disconnecting:
      return "disconnecting"
    @unknown default:
      return "unknown"
    }
  }
}
