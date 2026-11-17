import 'models/trigger_event.dart';

class TriggerConfig {
  const TriggerConfig({
    this.wakeWordEnabled = true,
    this.sosHoldEnabled = true,
    this.volumePatternEnabled = true,
    this.shakeEnabled = true,
  });

  final bool wakeWordEnabled;
  final bool sosHoldEnabled;
  final bool volumePatternEnabled;
  final bool shakeEnabled;
}

/// Normalizes every activation path (wake-word, SOS hold, volume pattern, shake,
/// manual, iOS App Intent) into a single [TriggerEvent] stream.
abstract interface class TriggerService {
  Future<void> arm(TriggerConfig config);

  Future<void> disarm();

  Stream<TriggerEvent> get events;
}
