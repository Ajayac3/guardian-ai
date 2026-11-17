import 'package:permission_handler/permission_handler.dart';

/// Requests the runtime permissions an active emergency needs. Returns true if
/// the essentials (mic + foreground location) are granted; camera/background are
/// best-effort. Owner-initiated only — requested at the moment of activation.
Future<bool> ensureTriggerPermissions({bool video = true}) async {
  final wanted = <Permission>[
    Permission.microphone,
    Permission.location,
    Permission.notification,
    if (video) Permission.camera,
  ];
  final results = await wanted.request();

  final micOk = results[Permission.microphone]?.isGranted ?? false;
  final locOk = results[Permission.location]?.isGranted ?? false;
  return micOk && locOk;
}

/// Background location is a separate, second-step grant on Android 11+.
Future<bool> ensureBackgroundLocation() async {
  final status = await Permission.locationAlways.request();
  return status.isGranted;
}
