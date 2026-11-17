-- Realtime honours auth.uid() (a standard claim) in postgres_changes RLS, but
-- not custom JWT claims. So contact access is keyed on auth.uid() matched
-- against the grant row, via a SECURITY DEFINER helper (the policy itself can't
-- read contact_session_grants, which is service-role-only).

alter table public.contact_session_grants add column if not exists contact_uid uuid;
create index if not exists idx_contact_grants_uid
  on public.contact_session_grants (contact_uid);

create or replace function public.has_contact_grant(p_session_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.contact_session_grants g
    where g.session_id = p_session_id
      and g.contact_uid = auth.uid()
      and g.revoked_at is null
      and g.expires_at > now()
  );
$$;
grant execute on function public.has_contact_grant(uuid) to anon, authenticated;

drop policy if exists sessions_contact_select on public.emergency_sessions;
create policy sessions_contact_select on public.emergency_sessions
  for select using (public.has_contact_grant(id));

drop policy if exists events_contact_select on public.session_events;
create policy events_contact_select on public.session_events
  for select using (public.has_contact_grant(session_id));
