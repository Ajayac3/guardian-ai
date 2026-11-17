import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:guardian_core/guardian_core.dart';

/// Watches the battery during a live session and fires a single final ping when
/// the level first drops below [threshold], so the contact still receives a
/// last-known location and battery state before the device powers off.
class LowBatteryMonitor {
  LowBatteryMonitor({
    Future<int> Function()? readLevel,
    this.threshold = 15,
    Duration? interval,
  }) : _readLevel = readLevel ?? _defaultReader(),
       _interval = interval ?? const Duration(seconds: 30);

  final Future<int> Function() _readLevel;
  final int threshold;
  final Duration _interval;
  static final _log = Log('offline');

  Timer? _timer;
  bool _fired = false;

  static Future<int> Function() _defaultReader() {
    final battery = Battery();
    return () => battery.batteryLevel;
  }

  /// [onLowBattery] is invoked once, with the current percent, when the level
  /// first crosses below [threshold].
  void start(Future<void> Function(int batteryPct) onLowBattery) {
    _timer ??= Timer.periodic(_interval, (_) => _check(onLowBattery));
  }

  Future<void> _check(Future<void> Function(int) onLowBattery) async {
    if (_fired) return;
    try {
      final level = await _readLevel();
      if (level <= threshold) {
        _fired = true;
        _log.w('low battery ($level%): sending final ping');
        await onLowBattery(level);
      }
    } catch (e) {
      _log.w('battery read failed: $e');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _fired = false;
  }
}
