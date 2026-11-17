/// Offline resilience: drain the queue on reconnect, fire a low-battery final
/// ping, and (opt-in, Android) fall back to SMS when there's no data path.
library;

export 'src/connectivity_drainer.dart';
export 'src/low_battery_monitor.dart';
export 'src/sms_fallback.dart';
