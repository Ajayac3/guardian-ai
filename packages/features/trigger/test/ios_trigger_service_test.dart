import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_trigger/guardian_trigger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('guardian/triggers');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<TriggerEvent> firstEventFor(String pending) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'consumePendingTrigger' ? pending : null;
    });
    final service = IosTriggerService();
    final first = service.events.first;
    await service.arm(const TriggerConfig());
    return first;
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'replays a cold-launch emergency activation as a full emergency',
    () async {
      final event = await firstEventFor('emergency');
      expect(event.kind, TriggerKind.fullEmergency);
      expect(event.source, TriggerSource.iosIntent);
    },
  );

  test('maps a soft activation to a soft alert', () async {
    final event = await firstEventFor('soft');
    expect(event.kind, TriggerKind.softAlert);
  });
}
