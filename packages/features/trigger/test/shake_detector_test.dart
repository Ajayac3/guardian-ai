import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_trigger/guardian_trigger.dart';

void main() {
  test('fires after required strong jolts within the window', () {
    final d = ShakeDetector(
      threshold: 25,
      requiredShakes: 3,
      window: const Duration(milliseconds: 1500),
    );
    expect(d.addSample(0, 0, 9.8, 0), isFalse); // gravity at rest — ignored
    expect(d.addSample(30, 0, 0, 150), isFalse); // jolt 1
    expect(d.addSample(0, 30, 0, 350), isFalse); // jolt 2
    expect(d.addSample(0, 0, 30, 600), isTrue); // jolt 3 -> fire
  });

  test('jolts outside the window do not accumulate', () {
    final d = ShakeDetector(
      threshold: 25,
      requiredShakes: 3,
      window: const Duration(milliseconds: 1000),
    );
    d.addSample(30, 0, 0, 0);
    d.addSample(30, 0, 0, 200);
    expect(d.addSample(30, 0, 0, 2000), isFalse); // earlier jolts expired
  });

  test('debounces jolts that are too close together', () {
    final d = ShakeDetector(
      threshold: 25,
      requiredShakes: 2,
      minGapMs: 80,
      window: const Duration(seconds: 2),
    );
    expect(d.addSample(40, 0, 0, 0), isFalse);
    expect(
      d.addSample(40, 0, 0, 30),
      isFalse,
    ); // within 80ms -> ignored, not counted
    expect(d.addSample(40, 0, 0, 200), isTrue); // second valid jolt -> fire
  });
}
