import AppIntents

/// Donates the Guardian intents as Siri phrases + Shortcuts. Assigning the
/// emergency shortcut to the Action Button is then a one-tap Settings step.
@available(iOS 16.0, *)
struct GuardianShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: TriggerEmergencyIntent(),
      phrases: [
        "Start \(.applicationName) emergency",
        "\(.applicationName) help me",
      ],
      shortTitle: "Emergency",
      systemImageName: "exclamationmark.shield.fill"
    )
    AppShortcut(
      intent: SoftAlertIntent(),
      phrases: ["Start a \(.applicationName) check-in"],
      shortTitle: "Check-in",
      systemImageName: "shield.lefthalf.filled"
    )
  }
}
