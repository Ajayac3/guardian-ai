import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds the push service, initialising Firebase when it's configured and
/// registering the device token. Falls back to [NoopPushService] when Firebase
/// is absent (no `google-services.json` / `GoogleService-Info.plist`) so the app
/// still compiles and runs.
Future<PushService> createPushService(SupabaseClient client) async {
  try {
    await Firebase.initializeApp();
    final fcm = FcmPushService(client);
    await fcm.registerToken();
    return fcm;
  } catch (_) {
    return const NoopPushService();
  }
}

/// FCM-backed [PushService]. Registers the device token (persisted to
/// `push_tokens` for server-side fan-out) and surfaces inbound messages — used
/// for server-driven session-state changes (e.g. a contact ended the session).
///
/// Requires a configured Firebase app; [Firebase.initializeApp] must succeed
/// before this is constructed. When Firebase is absent (no `google-services.json`
/// / `GoogleService-Info.plist`) the app binds [NoopPushService] instead.
class FcmPushService implements PushService {
  FcmPushService(this._client);

  final SupabaseClient _client;
  final _messaging = FirebaseMessaging.instance;
  final _messages = StreamController<PushMessage>.broadcast();
  static final _log = Log('push');
  StreamSubscription<RemoteMessage>? _sub;

  @override
  Future<String?> registerToken() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token == null) return null;

    final ownerId = _client.auth.currentUser?.id;
    if (ownerId != null) {
      try {
        // Keyed on fcm_token, so re-registering the same token is idempotent.
        // When FCM rotates the token a new row is inserted; pruning stale rows
        // is a server-side fan-out concern (FCM just rejects dead tokens), so
        // it's deferred until fan-out lands.
        await _client.from('push_tokens').upsert({
          'owner_id': ownerId,
          'fcm_token': token,
        }, onConflict: 'fcm_token');
      } catch (e) {
        _log.w('push token persist failed: $e');
      }
    }

    _sub ??= FirebaseMessaging.onMessage.listen((m) {
      _messages.add(
        PushMessage(
          data: m.data.map((k, v) => MapEntry(k, v.toString())),
          title: m.notification?.title,
          body: m.notification?.body,
        ),
      );
    });
    return token;
  }

  @override
  Stream<PushMessage> get messages => _messages.stream;
}

/// Bound when Firebase is not configured: registration is a no-op and no
/// messages ever arrive, so the rest of the app runs unchanged.
class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<String?> registerToken() async => null;

  @override
  Stream<PushMessage> get messages => const Stream.empty();
}
