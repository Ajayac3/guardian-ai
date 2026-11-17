import 'dart:async';

import 'package:flutter/services.dart';
import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';

/// Receives activations from the iOS native surfaces — App Intent / Action
/// Button / Siri Shortcut / iOS 18 Control Center control / lock-screen widget —
/// over a [MethodChannel] and normalizes them into [TriggerEvent]s.
///
/// iOS has no compliant always-on wake-word (ADR D5), so these App-Intent-driven
/// surfaces are the activation path. The native side (GuardianIntents target)
/// invokes `trigger` with a `kind` of `emergency` | `soft` | `cancelSoft`, and
/// stashes any activation that launched the app cold under `consumePendingTrigger`.
class IosTriggerService implements TriggerService {
  IosTriggerService({MethodChannel? channel, Clock clock = const SystemClock()})
    : _channel = channel ?? const MethodChannel('guardian/triggers'),
      _clock = clock;

  static final _log = Log('trigger');
  final MethodChannel _channel;
  final Clock _clock;
  final _events = StreamController<TriggerEvent>.broadcast();
  bool _armed = false;

  @override
  Stream<TriggerEvent> get events => _events.stream;

  @override
  Future<void> arm(TriggerConfig config) async {
    if (_armed) return;
    _armed = true;
    _channel.setMethodCallHandler(_onCall);
    // Drain an activation that launched the app cold (e.g. Action Button while
    // locked) — the native side holds it until Dart is ready.
    final pending = await _channel.invokeMethod<String>(
      'consumePendingTrigger',
    );
    if (pending != null) _emit(pending);
  }

  @override
  Future<void> disarm() async {
    _armed = false;
    _channel.setMethodCallHandler(null);
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'trigger') {
      final args = call.arguments as Map?;
      _emit(args?['kind'] as String? ?? 'emergency');
    }
    return null;
  }

  void _emit(String name) {
    final kind = switch (name) {
      'soft' => TriggerKind.softAlert,
      'cancelSoft' => TriggerKind.cancelSoft,
      _ => TriggerKind.fullEmergency,
    };
    _log.i('ios trigger: $name');
    if (!_events.isClosed) {
      _events.add(
        TriggerEvent(
          kind: kind,
          source: TriggerSource.iosIntent,
          at: _clock.nowUtc(),
        ),
      );
    }
  }
}
