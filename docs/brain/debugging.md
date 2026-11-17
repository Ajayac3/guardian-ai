# Debugging notes
- First end-to-end demo needs NO cloud creds: `livekit-server --dev` +
  `supabase start`, app on AVD/chrome, viewer in host Chrome.
- Android FGS only runs on a device/emulator, not the Linux desktop target.
- Supabase free project pauses after 7 days idle — local stack avoids this in dev.

## Local stack on rootless Podman (this box)
- Supabase runs on rootless Podman: `export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock`
  before any `supabase` command.
- **SELinux gotcha (Fedora):** the edge runtime can't read bind-mounted functions
  → "failed to determine entrypoint / BOOT_ERROR". Fix (no sudo):
  `chcon -Rt container_file_t ./supabase`. Re-run if you
  add functions and they 404.
- Edge functions must use Deno-friendly deps: LiveKit tokens are minted with
  `jose` (HS256), NOT `npm:livekit-server-sdk` (Node deps broke the worker).

## GoTrue / auth.users when seeding manually
- Manually-inserted `auth.users` rows need non-null `raw_app_meta_data` /
  `raw_user_meta_data` AND empty-string token columns (`confirmation_token`,
  `recovery_token`, `email_change*`, `phone_change*`, `reauthentication_token`),
  else password grant 500s with "Database error querying schema" /
  "converting NULL to string is unsupported". seed.sql sets these.

## Contact live updates: polling, not Realtime postgres_changes
- Local Realtime delivers postgres_changes to the OWNER (policy is
  `owner_id = auth.uid()`), but NOT to the account-less contact whose policy is a
  function-based grant lookup (`has_contact_grant()` / custom claim). The token
  is accepted (no JWT error) — local Realtime just won't evaluate that policy for
  postgres_changes. REST honours it fine.
- So the viewer **polls** `emergency_sessions` (status + last_lat/lng) every 3s
  with the grant JWT. Reliable and account-less. Revisit Realtime Broadcast or
  anonymous-auth for push on hosted Realtime in M10 hardening.

## Running the Flutter app against the local stack (device/emulator)
- The AVD reaches the host via `10.0.2.2`, not `127.0.0.1`. Run with:
  `flutter run -d <android> --dart-define=SUPABASE_URL=http://10.0.2.2:54321 \
   --dart-define=SUPABASE_ANON_KEY=<anon> --dart-define=LIVEKIT_URL=ws://10.0.2.2:7880 \
   --dart-define=VIEWER_BASE_URL=http://<host-ip>:5173`
- Without SUPABASE_ANON_KEY the app runs in shell mode (UI only, SOS demo toggle).
- Dev auto-sign-in uses owner@guardian.dev / guardianpass (local hosts only).
