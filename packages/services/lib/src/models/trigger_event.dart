import 'package:meta/meta.dart';

/// What the user intends when a trigger fires.
enum TriggerKind { fullEmergency, softAlert, cancelSoft }

/// Where the trigger came from. All sources normalize into one stream so
/// feature code is platform-agnostic.
enum TriggerSource {
  wakeWord,
  sosHold,
  volumePattern,
  shake,
  manual,
  iosIntent,
}

@immutable
class TriggerEvent {
  const TriggerEvent({
    required this.kind,
    required this.source,
    required this.at,
    this.phraseId,
    this.confidence,
  });

  final TriggerKind kind;
  final TriggerSource source;
  final DateTime at;
  final String? phraseId;
  final double? confidence;
}
