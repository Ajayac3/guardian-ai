import 'dart:developer' as developer;

enum LogLevel { debug, info, warn, error }

/// Lightweight logger. Never log evidence bytes, keys, tokens, or precise
/// location of a live session — see `docs/brain/security.md`.
class Log {
  const Log(this.tag);
  final String tag;

  void d(String message) => _emit(LogLevel.debug, message);
  void i(String message) => _emit(LogLevel.info, message);
  void w(String message) => _emit(LogLevel.warn, message);
  void e(String message, [Object? error, StackTrace? stack]) =>
      _emit(LogLevel.error, message, error, stack);

  void _emit(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    developer.log(
      message,
      name: 'guardian.$tag',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stack,
    );
  }
}
