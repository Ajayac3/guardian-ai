import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // APNs registration. When Firebase is configured, firebase_messaging maps the
    // APNs token to an FCM token automatically; this still registers the device.
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { granted, _ in
      if granted {
        DispatchQueue.main.async { application.registerForRemoteNotifications() }
      }
    }

    // An activation stored by a widget/Control Center control in the shared
    // container while the app was not running.
    if let group = UserDefaults(suiteName: GuardianTriggerBridge.appGroup),
      let stored = group.string(forKey: "pendingTrigger") {
      group.removeObject(forKey: "pendingTrigger")
      GuardianTriggerBridge.shared.fire(stored)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "GuardianTriggers")?.messenger() {
      GuardianTriggerBridge.shared.attach(messenger: messenger)
    }
  }
}
