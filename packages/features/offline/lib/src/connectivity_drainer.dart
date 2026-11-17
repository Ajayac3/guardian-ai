import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';

/// Drains the [OfflineQueue] whenever connectivity is restored, so evidence and
/// location buffered during a dead spot reach the server the moment the radio
/// comes back.
class ConnectivityDrainer {
  ConnectivityDrainer(this._queue, {Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final OfflineQueue _queue;
  final Connectivity _connectivity;
  static final _log = Log('offline');

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _draining = false;

  void start() {
    _sub ??= _connectivity.onConnectivityChanged.listen(_onChange);
    // Flush anything already buffered (e.g. left over from a prior offline
    // session) — no connectivity-change event fires for the already-online state.
    unawaited(drainNow());
  }

  Future<void> _onChange(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) await drainNow();
  }

  /// Drains immediately. Re-entrant calls while a drain is in flight are no-ops.
  Future<void> drainNow() async {
    if (_draining) return;
    _draining = true;
    try {
      await for (final p in _queue.drain()) {
        _log.i('drained ${p.sent}, ${p.remaining} remaining');
      }
    } catch (e) {
      _log.w('drain failed: $e');
    } finally {
      _draining = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
