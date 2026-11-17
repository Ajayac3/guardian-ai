/// Viewer runtime configuration, assembled from the link query params
/// (?session=&t=) and Vite build-time env (VITE_*), with local-dev defaults.

export interface ViewerConfig {
  sessionId: string | null;
  /** Magic contact token; exchanged for a scoped Supabase grant + LiveKit JWT. */
  contactToken: string | null;
  supabaseUrl: string;
  supabaseAnonKey: string;
  livekitUrl: string;
  osmTileUrl: string;
}

export function readConfig(search: string = window.location.search): ViewerConfig {
  const params = new URLSearchParams(search);
  const env = import.meta.env;
  return {
    sessionId: params.get('session'),
    contactToken: params.get('t'),
    supabaseUrl: env.VITE_SUPABASE_URL ?? 'http://127.0.0.1:54321',
    supabaseAnonKey: env.VITE_SUPABASE_ANON_KEY ?? '',
    livekitUrl: env.VITE_LIVEKIT_URL ?? 'ws://127.0.0.1:7880',
    osmTileUrl:
      env.VITE_OSM_TILE_URL ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  };
}

export function hasSession(cfg: ViewerConfig): boolean {
  return cfg.sessionId !== null && cfg.contactToken !== null;
}
