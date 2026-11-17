import 'dart:math' as math;

/// Pure shake-detection logic (no plugins) so it's unit-testable. Feed
/// accelerometer samples; returns true when [requiredShakes] strong jolts occur
/// within [window]. Accelerometer magnitude includes gravity (~9.8 m/s²) so the
/// threshold is set well above that.
class ShakeDetector {
  ShakeDetector({
    this.threshold = 25.0,
    this.requiredShakes = 3,
    this.window = const Duration(milliseconds: 1500),
    this.minGapMs = 80,
  });

  final double threshold;
  final int requiredShakes;
  final Duration window;
  final int minGapMs;

  final _hits = <int>[];

  bool addSample(double x, double y, double z, int tMillis) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return false;
    if (_hits.isNotEmpty && tMillis - _hits.last < minGapMs) return false;

    _hits.add(tMillis);
    _hits.removeWhere((t) => tMillis - t > window.inMilliseconds);
    if (_hits.length >= requiredShakes) {
      _hits.clear();
      return true;
    }
    return false;
  }

  void reset() => _hits.clear();
}
