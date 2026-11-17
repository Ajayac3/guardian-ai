import 'package:guardian_core/guardian_core.dart';

import 'models/contact_ref.dart';
import 'models/emergency_session.dart';
import 'models/geo_ping.dart';
import 'models/session_token.dart';

/// Owns the server-authoritative session lifecycle.
///
/// Deliberately exposes no `end()` / `terminate()`: the device cannot end a
/// session. Termination authority lives server-side (verified contact, server
/// timeout, verified recovery). The only owner-side exit is [cancelSoft], valid
/// for soft alerts only and still validated by the server.
abstract interface class SessionService {
  /// Creates a session in `starting` and returns the publisher token + the
  /// shareable viewer link.
  Future<({EmergencySession session, SessionToken token})> create({
    required SessionKind kind,
    required ContactRef contact,
  });

  /// Live status of a session, sourced from Supabase Realtime.
  Stream<EmergencySession> watch(String sessionId);

  /// Keeps a session `active`. The first heartbeat flips `starting -> active`.
  /// Optionally piggybacks the latest location + battery.
  Future<void> heartbeat(
    String sessionId, {
    GeoPing? location,
    int? batteryPct,
  });

  /// Asks the server to move a `lost_connection` session back to `active`.
  /// Never resurrects an already-`ended` session.
  Future<void> requestRecovery(String sessionId);

  /// Ends a soft alert ("Guardian I'm okay"). Server rejects this for full
  /// emergencies.
  Future<void> cancelSoft(String sessionId);
}
