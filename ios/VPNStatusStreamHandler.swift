import Foundation
import Flutter

final class VPNStatusStreamHandler: NSObject, FlutterStreamHandler {
  private let manager = VPNManager.shared
  private var eventSink: FlutterEventSink?
  private var observationToken: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    emitCurrentStatus()

    observationToken = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emitCurrentStatus()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observationToken {
      NotificationCenter.default.removeObserver(observationToken)
      self.observationToken = nil
    }
    eventSink = nil
    return nil
  }

  private func emitCurrentStatus() {
    manager.status { [weak self] status, error in
      guard let self else { return }
      if let error {
        self.eventSink?(FlutterError(code: "status_stream_failed", message: error.localizedDescription, details: nil))
        return
      }
      self.manager.lastError { message, _ in
        self.eventSink?([
          "status": status,
          "lastError": message ?? "",
        ])
      }
    }
  }
}
