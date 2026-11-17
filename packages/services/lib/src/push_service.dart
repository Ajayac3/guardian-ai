import 'models/push_message.dart';

/// Device push registration + inbound messages (e.g. server-side session state
/// changes the contact triggers).
abstract interface class PushService {
  Future<String?> registerToken();

  Stream<PushMessage> get messages;
}
