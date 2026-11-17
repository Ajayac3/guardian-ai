-- Guardian AI — core schema.
-- gen_random_uuid() is core in PG13+. pgcrypto (digest/hmac) lives in the
-- `extensions` schema on Supabase; functions that hash tokens set search_path
-- to include it.
create extension if not exists pgcrypto with schema extensions;

-- One row per app user (1:1 with auth.users).
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  region_code text,
  -- Session creation is gated on this being set (anti-stalking attestation).
  anti_stalking_attested_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  contact_email text,
  contact_phone text,
  relationship text,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'revoked')),
  created_at timestamptz not null default now()
);
create index on public.emergency_contacts (owner_id);

-- OTP verifications. Only the hash is stored; service-role access only.
create table public.contact_verifications (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references public.emergency_contacts (id) on delete cascade,
  code_hash text not null,
  channel text not null check (channel in ('email', 'sms')),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  attempts int not null default 0,
  created_at timestamptz not null default now()
);

-- The core table. `status` is server-authoritative: the device can advance it
-- but can never reach 'ended' (enforced in 20260529120300_session_guard.sql).
create table public.emergency_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  contact_id uuid references public.emergency_contacts (id) on delete set null,
  kind text not null default 'full' check (kind in ('full', 'soft')),
  status text not null default 'starting'
    check (status in ('starting', 'active', 'lost_connection', 'ending', 'ended', 'cancelled')),
  livekit_room text,
  viewer_token_jti text,
  last_heartbeat_at timestamptz,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by text check (ended_by in ('contact', 'server_timeout', 'recovery', 'owner_cancel_soft')),
  last_lat double precision,
  last_lng double precision,
  last_loc_at timestamptz,
  battery_pct int
);
create index on public.emergency_sessions (status, last_heartbeat_at);
create index on public.emergency_sessions (owner_id);
create index on public.emergency_sessions (contact_id);

-- Append-only event log. Realtime publishes inserts to the viewer.
create table public.session_events (
  id bigserial primary key,
  session_id uuid not null references public.emergency_sessions (id) on delete cascade,
  type text not null check (type in ('geo', 'state', 'battery', 'connection', 'note')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index on public.session_events (session_id, id);

-- One row per uploaded encrypted evidence chunk.
create table public.evidence_manifest (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.emergency_sessions (id) on delete cascade,
  seq int not null,
  media text not null check (media in ('audio', 'video')),
  r2_key text not null,
  sha256_hmac text not null,
  bytes int not null,
  enc_key_id text not null,
  tsa_token bytea,
  uploaded_at timestamptz not null default now(),
  unique (session_id, media, seq)
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  platform text,
  model text,
  device_pubkey text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  device_id uuid references public.devices (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  fcm_token text,
  apns_token text,
  updated_at timestamptz not null default now()
);

-- Account-less contact access: a magic token (hashed) grants scoped read + the
-- end-session RPC for exactly one session.
create table public.contact_session_grants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.emergency_sessions (id) on delete cascade,
  contact_id uuid references public.emergency_contacts (id) on delete set null,
  token_hash text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index on public.contact_session_grants (session_id);
