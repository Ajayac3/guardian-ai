# Architecture

Guardian AI is a Flutter (Android now, iOS later) + web monorepo that streams
encrypted audio/optional-video/live-GPS from a device owner to a verified
emergency contact who watches in a plain browser via a shared link.

## Layout
- `app/` — runnable Flutter app shell; DI wiring in `lib/bootstrap.dart`.
- `packages/services` — pure-Dart **interfaces** (no SDK imports). The swap seam.
- `packages/services_*` — managed implementations (LiveKit, Supabase, R2, FCM,
  sodium, geolocator, Drift). Self-hosting later = add a package + rebind.
- `packages/features/*` — feature-first UI + controllers (presentation/domain/data).
- `packages/core` — config, env, Result, logging, clock, session status enums.
- `packages/shared` — shared widgets/theme, incl. the visible recording indicator.
- `viewer/` — separate Vite + TypeScript web app for the emergency contact.
- `supabase/` — migrations (tables + RLS + end-session trigger) and Edge Functions.

## Load-bearing invariant
The device can never end an emergency session. Termination authority is
server-side only (verified contact / server timeout / verified recovery),
enforced by Supabase RLS + a BEFORE UPDATE trigger. See `security.md`.
