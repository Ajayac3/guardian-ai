import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed session lifecycle. Creation goes through the create-session
/// Edge function; live status comes from Realtime; the mutating operations are
/// server-authoritative RPCs. There is deliberately no way here to set 'ended'.
class SupabaseSessionService implements SessionService {
  SupabaseSessionService(this._client);

  final SupabaseClient _client;
  static final _log = Log('session');

  @override
  Future<({EmergencySession session, SessionToken token})> create({
    required SessionKind kind,
    required ContactRef contact,
  }) async {
    final res = await _client.functions.invoke(
      'create-session',
      body: {'kind': kind.wire, 'contact_id': contact.id},
    );
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError('create-session failed: ${data['error']}');
    }
    final session = EmergencySession.fromRow(
      data['session'] as Map<String, dynamic>,
    );
    final t = data['token'] as Map<String, dynamic>;
    _log.i('session ${session.id} created (${kind.wire})');
    return (
      session: session,
      token: SessionToken(
        sessionId: t['sessionId'] as String,
        livekitUrl: t['livekitUrl'] as String,
        room: t['room'] as String,
        publisherJwt: t['publisherJwt'] as String,
        viewerUrl: t['viewerUrl'] as String,
      ),
    );
  }

  @override
  Stream<EmergencySession> watch(String sessionId) {
    return _client
        .from('emergency_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .where((rows) => rows.isNotEmpty)
        .map((rows) => EmergencySession.fromRow(rows.first));
  }

  @override
  Future<void> heartbeat(
    String sessionId, {
    GeoPing? location,
    int? batteryPct,
  }) async {
    await _client.rpc<void>(
      'session_heartbeat',
      params: {
        'p_session_id': sessionId,
        'p_lat': location?.lat,
        'p_lng': location?.lng,
        'p_battery': batteryPct,
      },
    );
  }

  @override
  Future<void> requestRecovery(String sessionId) async {
    await _client.rpc<void>(
      'request_recovery',
      params: {'p_session_id': sessionId},
    );
  }

  @override
  Future<void> cancelSoft(String sessionId) async {
    await _client.rpc<void>(
      'cancel_soft_alert',
      params: {'p_session_id': sessionId},
    );
  }
}
