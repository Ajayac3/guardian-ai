-- Row Level Security. Default-deny everywhere; the policies below are the only
-- ways in. Anything with no policy is service-role-only (service_role bypasses
-- RLS). `contact_*` access is keyed on a JWT claim minted by the
-- issue-viewer-token Edge function (see M2/M4).

alter table public.profiles enable row level security;
create policy profiles_self on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

alter table public.emergency_contacts enable row level security;
create policy contacts_owner on public.emergency_contacts
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- OTP material: service-role only (no policies).
alter table public.contact_verifications enable row level security;

alter table public.emergency_sessions enable row level security;

create policy sessions_owner_select on public.emergency_sessions
  for select using (owner_id = auth.uid());

-- Owner may only ever create a session in 'starting'.
create policy sessions_owner_insert on public.emergency_sessions
  for insert with check (owner_id = auth.uid() and status = 'starting');

-- Owner may update own live sessions but the WITH CHECK forbids the 'ended'
-- value; the BEFORE UPDATE trigger (next migration) is the real backstop.
create policy sessions_owner_update on public.emergency_sessions
  for update
  using (owner_id = auth.uid() and status not in ('ended', 'cancelled'))
  with check (owner_id = auth.uid() and status <> 'ended');

-- Account-less verified contact reads exactly the one granted session.
create policy sessions_contact_select on public.emergency_sessions
  for select using (id = (auth.jwt() ->> 'session_grant')::uuid);

alter table public.session_events enable row level security;

create policy events_owner_select on public.session_events
  for select using (
    exists (
      select 1 from public.emergency_sessions s
      where s.id = session_id and s.owner_id = auth.uid()
    )
  );

create policy events_owner_insert on public.session_events
  for insert with check (
    exists (
      select 1 from public.emergency_sessions s
      where s.id = session_id and s.owner_id = auth.uid()
    )
  );

create policy events_contact_select on public.session_events
  for select using (session_id = (auth.jwt() ->> 'session_grant')::uuid);

alter table public.evidence_manifest enable row level security;
create policy evidence_owner on public.evidence_manifest
  for all
  using (
    exists (
      select 1 from public.emergency_sessions s
      where s.id = session_id and s.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.emergency_sessions s
      where s.id = session_id and s.owner_id = auth.uid()
    )
  );

alter table public.devices enable row level security;
create policy devices_owner on public.devices
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

alter table public.push_tokens enable row level security;
create policy push_owner on public.push_tokens
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Grants are minted server-side only.
alter table public.contact_session_grants enable row level security;
