import Flutter
import Foundation

/// Bridges the iOS activation surfaces (App Intent / Action Button / Siri /
/// Control Center / lock-screen widget) to the Flutter `guardian/triggers`
/// MethodChannel that `IosTriggerService` listens on.
///
/// An activation can arrive before the Flutter engine is attached (e.g. the
/// Action Button launches the app cold). In that case the kind is stashed and
/// replayed when Dart calls `consumePendingTrigger`.
final class GuardianTriggerBridge {
  static let shared = GuardianTriggerBridge()
  private init() {}

  static let appGroup = "group.com.guardianai.guardian"
  private static let pendingKey = "pendingTrigger"

  private var channel: FlutterMethodChannel?
  private var pending: String?

  /// Wire up the channel once the engine's messenger is available.
  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "guardian/triggers", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "consumePendingTrigger" {
        result(self?.takePending())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    // Flush anything a widget/intent stored in the shared container.
    if let group = UserDefaults(suiteName: Self.appGroup),
      let stored = group.string(forKey: Self.pendingKey) {
      group.removeObject(forKey: Self.pendingKey)
      fire(stored)
    }
  }

  /// `kind` is `emergency` | `soft` | `cancelSoft`.
  func fire(_ kind: String) {
    if let channel = channel {
      channel.invokeMethod("trigger", arguments: ["kind": kind])
    } else {
      pending = kind
    }
  }

  private func takePending() -> String? {
    defer { pending = nil }
    return pending
  }
}
