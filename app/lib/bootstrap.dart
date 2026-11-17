import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_services_crypto/guardian_services_crypto.dart';
import 'package:guardian_services_fcm/guardian_services_fcm.dart';
import 'package:guardian_services_livekit/guardian_services_livekit.dart';
import 'package:guardian_services_location_native/guardian_services_location_native.dart';
import 'package:guardian_services_offline_drift/guardian_services_offline_drift.dart';
import 'package:guardian_services_r2/guardian_services_r2.dart';
import 'package:guardian_services_supabase/guardian_services_supabase.dart';
import 'package:guardian_trigger/guardian_trigger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_api.dart';

/// The bound managed backend. `null` means the app runs in shell mode (no
/// `SUPABASE_ANON_KEY` configured) — the UI renders but cannot start a session.
class AppBackend {
  AppBackend({
    required this.session,
    required this.streaming,
    required this.location,
    required this.crypto,
    required this.storage,
    required this.foreground,
    required this.trigger,
    required this.offlineQueue,
    required this.push,
    required this.account,
    required this.contact,
  });
  final SessionService session;
  final StreamingService streaming;
  final LocationService location;
  final CryptoService crypto;
  final StorageService storage;
  final ForegroundSession foreground;
  final TriggerService trigger;
  final OfflineQueue? offlineQueue;
  final PushService push;
  final AccountApi account;
  final ContactRef? contact;
}

/// Initialises Supabase + LiveKit and resolves the default contact. This is the
/// single place that binds interfaces to managed implementations; a self-hosted
/// build swaps the implementations here and nothing else changes.
Future<AppBackend?> initBackend() async {
  if (Env.supabaseAnonKey.isEmpty) return null;

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  final client = Supabase.instance.client;

  // DEV ONLY: auto sign-in with the seeded owner so the streaming demo works
  // without the (M7) auth UI. Only against a local host.
  if (client.auth.currentSession == null && Env.isLocalHost) {
    try {
      await client.auth.signInWithPassword(
        email: 'owner@guardian.dev',
        password: 'guardianpass',
      );
    } catch (_) {
      // No seeded user — fall through; session creation will surface the error.
    }
  }

  ContactRef? contact;
  final rows = await client
      .from('emergency_contacts')
      .select('id,name,contact_email,contact_phone')
      .eq('status', 'verified')
      .limit(1);
  if (rows.isNotEmpty) {
    final r = rows.first;
    contact = ContactRef(
      id: r['id'] as String,
      name: r['name'] as String,
      email: r['contact_email'] as String?,
      phone: r['contact_phone'] as String?,
    );
  }

  final vault = SecureStorageKeyVault();
  final session = SupabaseSessionService(client);
  final storage = R2StorageService(client);

  // Buffer evidence + location locally when offline, drain when connectivity
  // returns. Tolerate a missing app-support dir (e.g. an unsupported host) by
  // running without the queue rather than failing startup.
  OfflineQueue? offlineQueue;
  try {
    offlineQueue = await FileOfflineQueue.openDefault(
      vault: vault,
      sendChunk: (chunk) async {
        final target = await storage.requestUpload(chunk.meta);
        await storage.upload(target, chunk);
        await storage.commitManifest(chunk.meta, target.r2Key);
      },
      sendGeo: (sessionId, ping) =>
          session.heartbeat(sessionId, location: ping),
    );
  } catch (_) {
    offlineQueue = null;
  }

  // Push registration. Without a configured Firebase app this returns a no-op so
  // the app still runs (and can register once Firebase is added).
  final push = await createPushService(client);

  return AppBackend(
    session: session,
    streaming: LivekitStreamingService(),
    location: GeolocatorLocationService(),
    crypto: CryptographyCryptoService(vault),
    storage: storage,
    foreground: FlutterForegroundSession(),
    // iOS activates via App Intents / Action Button / Control Center (ADR D5);
    // every other platform uses the shake/manual detector.
    trigger: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? IosTriggerService()
        : ShakeTriggerService(),
    offlineQueue: offlineQueue,
    push: push,
    account: AccountApi(client),
    contact: contact,
  );
}
