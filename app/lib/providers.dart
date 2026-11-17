import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_offline/guardian_offline.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_trigger/guardian_trigger.dart';

import 'account_api.dart';

/// Service seams. Bound to managed implementations in `bootstrap.dart`; tests
/// override them with fakes.
final sessionServiceProvider = Provider<SessionService>(
  (_) => throw UnimplementedError('SessionService not bound'),
);
final streamingServiceProvider = Provider<StreamingService>(
  (_) => throw UnimplementedError('StreamingService not bound'),
);
final locationServiceProvider = Provider<LocationService>(
  (_) => throw UnimplementedError('LocationService not bound'),
);
final cryptoServiceProvider = Provider<CryptoService>(
  (_) => throw UnimplementedError('CryptoService not bound'),
);
final storageServiceProvider = Provider<StorageService>(
  (_) => throw UnimplementedError('StorageService not bound'),
);

/// Foreground service (recording indicator) + trigger detection. Null in shell
/// mode / tests (platform plugins unavailable) — wiring is then skipped.
final foregroundSessionProvider = Provider<ForegroundSession?>((_) => null);
final triggerServiceProvider = Provider<TriggerService?>((_) => null);

/// Durable offline buffer for evidence + location. Null in shell mode / tests
/// (no app-support dir) — telemetry then runs without buffering.
final offlineQueueProvider = Provider<OfflineQueue?>((_) => null);

/// Push registration + inbound messages. Null in shell mode / when Firebase
/// isn't configured (no google-services.json).
final pushServiceProvider = Provider<PushService?>((_) => null);

/// Owner account operations (onboarding, contacts, settings). Null in shell mode.
final accountApiProvider = Provider<AccountApi?>((_) => null);

/// The contact a new session streams to. Overridden with a Supabase-backed
/// lookup in the app; null until a verified contact exists.
final targetContactProvider = FutureProvider<ContactRef?>((_) async => null);

/// True once the backend is configured (Supabase initialised + bound).
final backendConfiguredProvider = Provider<bool>((_) => false);

/// How often the device proves liveness to the server while a session is live.
const heartbeatInterval = Duration(seconds: 10);

enum EmergencyPhase { idle, starting, active, error }

class EmergencyState {
  const EmergencyState({
    this.phase = EmergencyPhase.idle,
    this.viewerUrl,
    this.error,
  });

  final EmergencyPhase phase;
  final String? viewerUrl;
  final String? error;

  bool get isActive => phase == EmergencyPhase.active;
}

/// Orchestrates an emergency: create the server session, start publishing, and
/// run the heartbeat + GPS telemetry loop. It never ends the session — that
/// authority is server-side.
class EmergencyController extends Notifier<EmergencyState> {
  static final _log = Log('emergency');

  Timer? _heartbeat;
  StreamSubscription<GeoPing>? _locSub;
  GeoPing? _lastPing;
  ConnectivityDrainer? _drainer;
  LowBatteryMonitor? _battery;

  @override
  EmergencyState build() {
    ref.onDispose(_stopTelemetry);
    return const EmergencyState();
  }

  Future<void> start(SessionKind kind) async {
    // Ignore re-triggers while a session is already starting or live — otherwise
    // we'd create a duplicate server session and leak telemetry listeners.
    if (state.phase == EmergencyPhase.starting ||
        state.phase == EmergencyPhase.active) {
      return;
    }
    state = const EmergencyState(phase: EmergencyPhase.starting);
    try {
      final sessions = ref.read(sessionServiceProvider);
      final streaming = ref.read(streamingServiceProvider);

      final contact = await ref.read(targetContactProvider.future);
      if (contact == null) {
        throw StateError('Add and verify an emergency contact first.');
      }

      final created = await sessions.create(kind: kind, contact: contact);
      await streaming.connectPublisher(
        created.token,
        audio: true,
        video: kind == SessionKind.full,
      );
      _log.i('emergency active: ${created.session.id}');
      state = EmergencyState(
        phase: EmergencyPhase.active,
        viewerUrl: created.token.viewerUrl,
      );
      // Visible recording indicator + keep mic/cam/location alive (Android FGS).
      try {
        await ref
            .read(foregroundSessionProvider)
            ?.start(
              title: 'Guardian AI — emergency active',
              body: 'Recording and streaming to your emergency contact.',
            );
      } catch (e) {
        _log.w('foreground service start failed: $e');
      }
      _startTelemetry(created.session.id);
    } catch (e, st) {
      _log.e('emergency start failed', e, st);
      state = EmergencyState(phase: EmergencyPhase.error, error: e.toString());
    }
  }

  /// Closes the local media transport and stops telemetry. Does NOT end the
  /// server session — it stays alive for the contact/server to resolve.
  Future<void> stopLocalStream() async {
    _stopTelemetry();
    try {
      await ref.read(foregroundSessionProvider)?.stop();
    } catch (_) {}
    await ref.read(streamingServiceProvider).disconnect();
    state = const EmergencyState();
  }

  /// Heartbeat + GPS. Best-effort: if location isn't available the session still
  /// runs (the server timeout protects against a silently dead device).
  void _startTelemetry(String sessionId) {
    // Tear down any previous telemetry first so re-arming never leaks the old
    // drainer subscription or battery timer.
    _stopTelemetry();
    try {
      final location = ref.read(locationServiceProvider);
      final sessions = ref.read(sessionServiceProvider);
      final queue = ref.read(offlineQueueProvider);

      _locSub?.cancel();
      _locSub = location.watch().listen(
        (ping) => _lastPing = ping,
        onError: (Object e) => _log.w('location error: $e'),
      );

      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(heartbeatInterval, (_) async {
        try {
          await sessions.heartbeat(sessionId, location: _lastPing);
        } catch (e) {
          _log.w('heartbeat failed: $e');
          await _bufferPing(queue, sessionId);
        }
      });

      if (queue != null) {
        // Drain the buffer whenever connectivity returns.
        _drainer = ConnectivityDrainer(queue)..start();
        // Send one final location + battery reading before the device dies.
        _battery = LowBatteryMonitor()
          ..start((pct) async {
            try {
              await sessions.heartbeat(
                sessionId,
                location: _lastPing,
                batteryPct: pct,
              );
            } catch (_) {
              await _bufferPing(queue, sessionId);
            }
          });
      }
    } catch (e) {
      _log.w('telemetry unavailable: $e');
    }
  }

  Future<void> _bufferPing(OfflineQueue? queue, String sessionId) async {
    final ping = _lastPing;
    if (queue == null || ping == null) return;
    try {
      await queue.enqueue(QueuedGeo(sessionId, ping));
    } catch (_) {}
  }

  void _stopTelemetry() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _locSub?.cancel();
    _locSub = null;
    _battery?.stop();
    _battery = null;
    unawaited(_drainer?.dispose());
    _drainer = null;
    _lastPing = null;
  }
}

final emergencyControllerProvider =
    NotifierProvider<EmergencyController, EmergencyState>(
      EmergencyController.new,
    );
