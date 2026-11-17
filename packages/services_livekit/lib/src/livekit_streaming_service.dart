import 'dart:async';

import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// Publishes the device owner's audio/video to a LiveKit room.
///
/// [disconnect] tears down the local media transport only — it never ends the
/// server session (that authority is server-side; see SessionService).
class LivekitStreamingService implements StreamingService {
  LivekitStreamingService();

  static final _log = Log('livekit');
  lk.Room? _room;
  final _stateController = StreamController<PublishConnectionState>.broadcast();

  @override
  Stream<PublishConnectionState> get connectionState => _stateController.stream;

  @override
  Future<void> connectPublisher(
    SessionToken token, {
    required bool audio,
    required bool video,
  }) async {
    await _room?.dispose();
    final room = lk.Room();
    _room = room;
    room.addListener(_onRoomChanged);
    _emit(PublishConnectionState.connecting);

    await room.connect(token.livekitUrl, token.publisherJwt);
    final me = room.localParticipant;
    if (me != null) {
      if (audio) await me.setMicrophoneEnabled(true);
      if (video) await me.setCameraEnabled(true);
    }
    _emit(PublishConnectionState.connected);
  }

  @override
  Future<void> setAudioEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      await room.disconnect();
      await room.dispose();
    }
    _emit(PublishConnectionState.disconnected);
  }

  void _onRoomChanged() {
    final state = _room?.connectionState;
    switch (state) {
      case lk.ConnectionState.connected:
        _emit(PublishConnectionState.connected);
      case lk.ConnectionState.reconnecting:
        _emit(PublishConnectionState.reconnecting);
      case lk.ConnectionState.connecting:
        _emit(PublishConnectionState.connecting);
      case lk.ConnectionState.disconnected:
        _emit(PublishConnectionState.disconnected);
      case null:
        break;
    }
  }

  void _emit(PublishConnectionState state) {
    _log.d('publisher state: $state');
    if (!_stateController.isClosed) _stateController.add(state);
  }
}
