/// Runtime configuration, read from `--dart-define` values with safe local
/// defaults so the app builds and runs with no real credentials.
///
/// Real secrets are injected at build time (CI) or via a local `.env` fed into
/// `--dart-define-from-file`; they are never committed.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'ws://127.0.0.1:7880',
  );

  static const viewerBaseUrl = String.fromEnvironment(
    'VIEWER_BASE_URL',
    defaultValue: 'http://127.0.0.1:5173',
  );

  static const osmTileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// True when no remote backend is configured — the app runs against the
  /// local dev stack (`supabase start` + `livekit-server --dev`).
  static bool get isLocal => supabaseAnonKey.isEmpty;

  /// True when pointing at a local/dev host (loopback or the Android emulator
  /// host alias). Gates dev-only conveniences like auto sign-in.
  static bool get isLocalHost =>
      supabaseUrl.contains('127.0.0.1') ||
      supabaseUrl.contains('10.0.2.2') ||
      supabaseUrl.contains('localhost');
}
