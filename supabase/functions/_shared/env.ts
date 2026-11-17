// Edge-function configuration. SUPABASE_* are injected by the platform; the
// LiveKit and viewer values default to the local dev stack so nothing has to be
// configured to run the M2 demo. JWT secret defaults to the standard local one.
export const env = {
  supabaseUrl: Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321',
  anonKey: Deno.env.get('SUPABASE_ANON_KEY') ?? '',
  serviceRoleKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  jwtSecret:
    Deno.env.get('SUPABASE_JWT_SECRET') ??
    'super-secret-jwt-token-with-at-least-32-characters-long',
  livekitUrl: Deno.env.get('LIVEKIT_URL') ?? 'ws://127.0.0.1:7880',
  livekitApiKey: Deno.env.get('LIVEKIT_API_KEY') ?? 'devkey',
  livekitApiSecret: Deno.env.get('LIVEKIT_API_SECRET') ?? 'secret',
  viewerBaseUrl: Deno.env.get('VIEWER_BASE_URL') ?? 'http://127.0.0.1:5173',

  // Evidence object storage (S3-compatible). Defaults to the LOCAL Supabase
  // Storage S3 endpoint so the pipeline works without R2 creds; set the R2_*
  // values in production. The endpoint must be the PUBLIC host (presigned URLs
  // are host-bound and the client uses this host).
  s3Endpoint:
    Deno.env.get('R2_ENDPOINT') ?? 'http://127.0.0.1:54321/storage/v1/s3',
  s3Region: Deno.env.get('R2_REGION') ?? 'local',
  s3AccessKey:
    Deno.env.get('R2_ACCESS_KEY_ID') ??
    '625729a08b95bf1b7ff351a663f3a23c',
  s3Secret:
    Deno.env.get('R2_SECRET_ACCESS_KEY') ??
    '850181e4652dd023b7a98c58ae0d2d34bd487ee0cc3254aed6eda37307425907',
  s3Bucket: Deno.env.get('R2_BUCKET') ?? 'evidence',
};
