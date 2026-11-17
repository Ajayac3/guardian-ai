import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Owns the Android foreground service for a live emergency. Its persistent
/// notification is the visible recording indicator required by store policy and
/// the spec. The FGS keeps mic/camera/location alive while the screen is off.
abstract interface class ForegroundSession {
  Future<void> start({required String title, required String body});
  Future<void> stop();
}

class FlutterForegroundSession implements ForegroundSession {
  bool _inited = false;

  void _ensureInit() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'guardian_emergency',
        channelName: 'Emergency session',
        channelDescription: 'Shown while Guardian AI is recording/streaming.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
    _inited = true;
  }

  @override
  Future<void> start({required String title, required String body}) async {
    _ensureInit();
    await FlutterForegroundTask.startService(
      notificationTitle: title,
      notificationText: body,
    );
  }

  @override
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
