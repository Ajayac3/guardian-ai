import 'dart:async';

import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'shake_detector.dart';

/// Detects activation gestures and normalizes them into [TriggerEvent]s.
///
/// M6 covers the shake gesture (full emergency) + a manual entry point. The
/// always-on wake-word and the volume-button pattern are the documented next
/// trigger sources; they plug into the same [events] stream.
class ShakeTriggerService implements TriggerService {
  ShakeTriggerService({
    ShakeDetector? detector,
    Clock clock = const SystemClock(),
  }) : _detector = detector ?? ShakeDetector(),
       _clock = clock;

  static final _log = Log('trigger');
  final ShakeDetector _detector;
  final Clock _clock;

  final _events = StreamController<TriggerEvent>.broadcast();
  StreamSubscription<AccelerometerEvent>? _accelSub;
  bool _armed = false;

  @override
  Stream<TriggerEvent> get events => _events.stream;

  @override
  Future<void> arm(TriggerConfig config) async {
    if (_armed) return;
    _armed = true;
    if (config.shakeEnabled) {
      _detector.reset();
      _accelSub = accelerometerEventStream().listen((e) {
        final ms = _clock.nowUtc().millisecondsSinceEpoch;
        if (_detector.addSample(e.x, e.y, e.z, ms)) {
          _log.i('shake trigger fired');
          _emit(TriggerKind.fullEmergency, TriggerSource.shake);
        }
      });
    }
  }

  @override
  Future<void> disarm() async {
    _armed = false;
    await _accelSub?.cancel();
    _accelSub = null;
  }

  /// Manual activation from the UI (SOS button / lock-screen action).
  void manual(TriggerKind kind) => _emit(kind, TriggerSource.manual);

  void _emit(TriggerKind kind, TriggerSource source) {
    if (!_events.isClosed) {
      _events.add(
        TriggerEvent(kind: kind, source: source, at: _clock.nowUtc()),
      );
    }
  }
}
