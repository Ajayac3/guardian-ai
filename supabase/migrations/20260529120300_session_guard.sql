-- The server-authoritative termination guarantee.
--
-- A device (any non-privileged caller) can advance a session but can NEVER set
-- status='ended'. The only ways to 'ended' are the SECURITY DEFINER functions
-- below, which set a transaction-local GUC the trigger recognizes, plus the
-- service_role. Soft alerts may be 'cancelled' by their owner only.

create or replace function public.guard_session_termination()
returns trigger
language plpgsql
as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_role text := '';
  v_allow text := current_setting('guardian.allow_end', true);
begin
  if v_claims is not null and v_claims <> '' then
    v_role := coalesce((v_claims::jsonb) ->> 'role', '');
  end if;

  -- Privileged paths: the service role, or a definer function that set the flag.
  if v_role = 'service_role' or coalesce(v_allow, '') <> '' then
    return new;
  end if;

  if new.status = 'ended' then
    raise exception
      'guardian: device cannot end a session (termination is server-authoritative)';
  end if;

  if new.status = 'cancelled' and old.kind <> 'soft' then
    raise exception
      'guardian: only soft alerts can be cancelled by the owner';
  end if;

  return new;
end;
$$;

create trigger trg_guard_session_termination
  before update on public.emergency_sessions
  for each row execute function public.guard_session_termination();

-- Device heartbeat: keeps a session live, advances starting->active, and
-- recovers lost_connection->active. Optionally records location + battery.
create or replace function public.session_heartbeat(
  p_session_id uuid,
  p_lat double precision default null,
  p_lng double precision default null,
  p_battery int default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  update public.emergency_sessions
     set last_heartbeat_at = now(),
         status = case when status = 'starting' then 'active' else status end,
         last_lat = coalesce(p_lat, last_lat),
         last_lng = coalesce(p_lng, last_lng),
         last_loc_at = case when p_lat is not null then now() else last_loc_at end,
         battery_pct = coalesce(p_battery, battery_pct)
   where id = p_session_id
     and owner_id = auth.uid()
     and status in ('starting', 'active', 'lost_connection');

  if p_lat is not null then
    insert into public.session_events (session_id, type, payload)
    values (
      p_session_id, 'geo',
      jsonb_build_object('lat', p_lat, 'lng', p_lng, 'at', now())
    );
  end if;
end;
$$;
grant execute on function
  public.session_heartbeat(uuid, double precision, double precision, int)
  to authenticated;

-- Owner-initiated recovery from lost_connection (never from ended).
create or replace function public.request_recovery(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  update public.emergency_sessions
     set status = 'active', last_heartbeat_at = now()
   where id = p_session_id
     and owner_id = auth.uid()
     and status = 'lost_connection';
end;
$$;
grant execute on function public.request_recovery(uuid) to authenticated;

-- Owner cancels a SOFT alert ("Guardian I'm okay"). Server rejects this for
-- full emergencies via the guard trigger.
create or replace function public.cancel_soft_alert(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  update public.emergency_sessions
     set status = 'cancelled', ended_at = now(), ended_by = 'owner_cancel_soft'
   where id = p_session_id
     and owner_id = auth.uid()
     and kind = 'soft'
     and status not in ('ended', 'cancelled');
end;
$$;
grant execute on function public.cancel_soft_alert(uuid) to authenticated;

-- The verified contact ends the session. Authorized by the magic token, not by
-- any device identity. This is the primary termination authority.
create or replace function public.end_session_by_contact(
  p_session_id uuid,
  p_contact_token text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ok boolean;
begin
  select exists (
    select 1 from public.contact_session_grants g
    where g.session_id = p_session_id
      and g.token_hash = encode(digest(p_contact_token, 'sha256'), 'hex')
      and g.revoked_at is null
      and g.expires_at > now()
  ) into v_ok;

  if not v_ok then
    raise exception 'guardian: invalid or expired contact grant';
  end if;

  perform set_config('guardian.allow_end', 'contact', true);
  update public.emergency_sessions
     set status = 'ended', ended_at = now(), ended_by = 'contact'
   where id = p_session_id and status not in ('ended', 'cancelled');
end;
$$;
grant execute on function public.end_session_by_contact(uuid, text)
  to anon, authenticated;

-- Server-side timeout sweep (invoked by pg_cron — see next migration). Flips
-- active->lost_connection after the heartbeat window, then lost_connection->
-- ended after the grace window.
create or replace function public.expire_stale_sessions(
  p_lost_after interval default interval '60 seconds',
  p_end_after interval default interval '5 minutes'
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform set_config('guardian.allow_end', 'server_timeout', true);

  with newly_lost as (
    update public.emergency_sessions
       set status = 'lost_connection'
     where status = 'active'
       and last_heartbeat_at is not null
       and last_heartbeat_at < now() - p_lost_after
    returning id
  )
  insert into public.session_events (session_id, type, payload)
  select id, 'connection', jsonb_build_object('state', 'lost') from newly_lost;

  update public.emergency_sessions
     set status = 'ended', ended_at = now(), ended_by = 'server_timeout'
   where status = 'lost_connection'
     and last_heartbeat_at is not null
     and last_heartbeat_at < now() - p_end_after;
end;
$$;
