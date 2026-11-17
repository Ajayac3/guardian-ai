import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';

import 'package:guardian_app/providers.dart';

class _FakeSession implements SessionService {
  bool created = false;

  @override
  Future<({EmergencySession session, SessionToken token})> create({
    required SessionKind kind,
    required ContactRef contact,
  }) async {
    created = true;
    return (
      session: EmergencySession(
        id: 's1',
        kind: kind,
        status: SessionStatus.starting,
        startedAt: DateTime.utc(2026),
      ),
      token: const SessionToken(
        sessionId: 's1',
        livekitUrl: 'ws://x',
        room: 'r',
        publisherJwt: 'jwt',
        viewerUrl: 'http://v/?session=s1&t=tok',
      ),
    );
  }

  @override
  Stream<EmergencySession> watch(String sessionId) => const Stream.empty();
  @override
  Future<void> heartbeat(
    String sessionId, {
    GeoPing? location,
    int? batteryPct,
  }) async {}
  @override
  Future<void> requestRecovery(String sessionId) async {}
  @override
  Future<void> cancelSoft(String sessionId) async {}
}

class _FakeStreaming implements StreamingService {
  bool connected = false;
  bool? audio;
  bool? video;

  @override
  Stream<PublishConnectionState> get connectionState => const Stream.empty();
  @override
  Future<void> connectPublisher(
    SessionToken token, {
    required bool audio,
    required bool video,
  }) async {
    connected = true;
    this.audio = audio;
    this.video = video;
  }

  @override
  Future<void> setAudioEnabled(bool enabled) async {}
  @override
  Future<void> setVideoEnabled(bool enabled) async {}
  @override
  Future<void> disconnect() async {}
}

void main() {
  test('start() creates a session and connects the publisher', () async {
    final streaming = _FakeStreaming();
    final container = ProviderContainer(
      overrides: [
        sessionServiceProvider.overrideWithValue(_FakeSession()),
        streamingServiceProvider.overrideWithValue(streaming),
        targetContactProvider.overrideWith(
          (_) async => const ContactRef(id: 'c1', name: 'Mum'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(emergencyControllerProvider.notifier)
        .start(SessionKind.full);

    final state = container.read(emergencyControllerProvider);
    expect(state.phase, EmergencyPhase.active);
    expect(state.viewerUrl, contains('session=s1'));
    expect(streaming.connected, isTrue);
    expect(streaming.video, isTrue);
  });

  test('start() errors when there is no verified contact', () async {
    final container = ProviderContainer(
      overrides: [
        sessionServiceProvider.overrideWithValue(_FakeSession()),
        streamingServiceProvider.overrideWithValue(_FakeStreaming()),
        targetContactProvider.overrideWith((_) async => null),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(emergencyControllerProvider.notifier)
        .start(SessionKind.full);

    expect(
      container.read(emergencyControllerProvider).phase,
      EmergencyPhase.error,
    );
  });
}
