import 'dart:io';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:guardian_core/guardian_core.dart';

/// Last-resort SMS to the emergency contact when the device has cellular signal
/// but no data path (so the live stream and heartbeat can't reach the server).
///
/// DISABLED by default. SEND_SMS is a restricted, store-review-sensitive
/// permission, and Guardian is owner-initiated/anti-stalking by design, so this
/// only ever sends when the owner has explicitly opted in.
class SmsFallback {
  SmsFallback({this.enabled = false, Telephony? telephony})
    : _telephony = telephony;

  final bool enabled;
  final Telephony? _telephony;
  static final _log = Log('offline');

  // Resolved lazily so the disabled / non-Android path never touches the plugin.
  Telephony get _tel => _telephony ?? Telephony.instance;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Attempts to text [message] to [phone]. Returns true only if a send was
  /// actually dispatched (enabled, on Android, permission granted).
  Future<bool> trySend({required String phone, required String message}) async {
    if (!enabled || !isSupported) return false;
    try {
      final granted = await _tel.requestSmsPermissions ?? false;
      if (!granted) return false;
      await _tel.sendSms(to: phone, message: message);
      return true;
    } catch (e) {
      _log.w('sms fallback failed: $e');
      return false;
    }
  }
}
