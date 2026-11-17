/// Indirection over the wall clock so time-dependent logic (heartbeat windows,
/// timeout grace periods) is testable without real delays.
abstract interface class Clock {
  DateTime nowUtc();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
