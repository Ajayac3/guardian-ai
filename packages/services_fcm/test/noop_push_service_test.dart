import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_services_fcm/guardian_services_fcm.dart';

void main() {
  test('NoopPushService registers no token and emits no messages', () async {
    const push = NoopPushService();
    expect(await push.registerToken(), isNull);
    expect(await push.messages.isEmpty, isTrue);
  });
}
