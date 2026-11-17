import AppIntents

/// The emergency-activation App Intent. Assignable to the iPhone 15/16 Action
/// Button, invokable by Siri, and surfaced in Shortcuts + Spotlight. Lives in the
/// main app target so it can hand off to `GuardianTriggerBridge` directly.
@available(iOS 16.0, *)
struct TriggerEmergencyIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Guardian Emergency"
  static var description = IntentDescription(
    "Immediately starts a Guardian AI emergency: live audio, video and location "
      + "stream to your verified emergency contact.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    GuardianTriggerBridge.shared.fire("emergency")
    return .result()
  }
}

/// A softer "watch me" check-in that the owner can cancel ("Guardian I'm okay").
@available(iOS 16.0, *)
struct SoftAlertIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Guardian Check-in"
  static var description = IntentDescription(
    "Starts a Guardian AI check-in you can cancel when you're safe.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    GuardianTriggerBridge.shared.fire("soft")
    return .result()
  }
}
