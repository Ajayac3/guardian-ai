import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_offline/guardian_offline.dart';

void main() {
  test(
    'low-battery monitor fires once when level crosses the threshold',
    () async {
      var level = 90;
      var fired = 0;
      int? reported;

      final monitor =
          LowBatteryMonitor(
            readLevel: () async => level,
            threshold: 15,
            interval: const Duration(milliseconds: 10),
          )..start((pct) async {
            fired++;
            reported = pct;
          });

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fired, 0, reason: 'above threshold');

      level = 9;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fired, 1);
      expect(reported, 9);

      // Does not re-fire on subsequent ticks.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fired, 1);

      monitor.stop();
    },
  );

  test('SMS fallback is disabled by default and never sends', () async {
    final sms = SmsFallback();
    expect(await sms.trySend(phone: '+10000000000', message: 'x'), isFalse);
  });
}
