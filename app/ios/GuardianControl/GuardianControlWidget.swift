import AppIntents
import SwiftUI
import WidgetKit

// This file belongs to a Widget Extension target (a separate process from the
// app), so its control intent can't call GuardianTriggerBridge directly. It hands
// the activation off through the shared App Group, then opens the app, whose
// AppDelegate replays it to Flutter on launch.

/// iOS 18 Control Center control to start an emergency without unlocking.
@available(iOS 18.0, *)
struct GuardianControlWidget: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(
      kind: "com.guardianai.guardian.control.emergency"
    ) {
      ControlWidgetButton(action: TriggerEmergencyControlIntent()) {
        Label("Emergency", systemImage: "exclamationmark.shield.fill")
      }
    }
    .displayName("Guardian Emergency")
    .description("Start a Guardian AI emergency from Control Center.")
  }
}

/// Control-Center / lock-screen intent. Stages the activation in the shared App
/// Group and opens the app to complete it.
@available(iOS 18.0, *)
struct TriggerEmergencyControlIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Guardian Emergency"
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    let group = UserDefaults(suiteName: "group.com.guardianai.guardian")
    group?.set("emergency", forKey: "pendingTrigger")
    return .result()
  }
}

// The lock-screen quick action reuses the same hand-off: an accessory WidgetKit
// widget whose button runs TriggerEmergencyControlIntent. Add it to this same
// extension target alongside the control above.
