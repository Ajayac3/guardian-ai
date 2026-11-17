import 'models/session_token.dart';

enum PublishConnectionState {
  connecting,
  connected,
  reconnecting,
  disconnected,
}

/// Publishes the device's encrypted audio/video to the media room.
abstract interface class StreamingService {
  Future<void> connectPublisher(
    SessionToken token, {
    required bool audio,
    required bool video,
  });

  Stream<PublishConnectionState> get connectionState;

  Future<void> setVideoEnabled(bool enabled);

  Future<void> setAudioEnabled(bool enabled);

  /// Closes the local media transport only. This does NOT end the server
  /// session — see [SessionService].
  Future<void> disconnect();
}
