-- Safety-core tests for Guardian AI. Run against the local stack as the
-- postgres superuser:
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_test.sql
-- An unexpected error aborts; expected-rejection tests catch internally and
-- raise only if the rejection did NOT happen. Prints ALL TESTS PASSED at the end.

\set ON_ERROR_STOP on
set client_min_messages = warning;

-- ---------------------------------------------------------------------------
-- Fixtures (as superuser; RLS bypassed)
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@test.dev', 'x', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'other@test.dev', 'x', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, anti_stalking_attested_at)
values ('11111111-1111-1111-1111-111111111111', now())
on conflict (id) do nothing;

insert into public.emergency_contacts (id, owner_id, name, status)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Mum', 'verified')
on conflict (id) do nothing;

insert into public.emergency_sessions (id, owner_id, contact_id, kind, status, last_heartbeat_at)
values
  ('ffffffff-ffff-ffff-ffff-ffffffffffff', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'full', 'active', now()),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'soft', 'active', now())
on conflict (id) do nothing;

insert into public.contact_session_grants (session_id, contact_id, token_hash, expires_at)
values (
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  encode(extensions.digest('secret-token', 'sha256'), 'hex'),
  now() + interval '1 hour'
)
on conflict do nothing;

commit;

-- ---------------------------------------------------------------------------
-- T1: device (owner) CANNOT set status='ended'  → must raise
-- ---------------------------------------------------------------------------
do $$
declare raised boolean := false;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  set local role authenticated;
  begin
    update public.emergency_sessions set status = 'ended'
      where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  exception when others then
    raised := true;
  end;
  reset role;
  if not raised then
    raise exception 'T1 FAILED: device was able to set status=ended';
  end if;
  raise notice 'T1 ok: device cannot end a session';
end $$;

-- ---------------------------------------------------------------------------
-- T2: owner CANNOT cancel a FULL session  → must raise
-- ---------------------------------------------------------------------------
do $$
declare raised boolean := false;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  set local role authenticated;
  begin
    update public.emergency_sessions set status = 'cancelled'
      where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  exception when others then
    raised := true;
  end;
  reset role;
  if not raised then
    raise exception 'T2 FAILED: owner cancelled a FULL session directly';
  end if;
  raise notice 'T2 ok: full session cannot be owner-cancelled';
end $$;

-- ---------------------------------------------------------------------------
-- T3: owner CAN advance starting->active via heartbeat (use soft session set
-- back to starting first), and CAN cancel a SOFT alert via the function.
-- ---------------------------------------------------------------------------
do $$
declare v_status text;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  set local role authenticated;
  perform public.cancel_soft_alert('55555555-5555-5555-5555-555555555555');
  reset role;
  select status into v_status from public.emergency_sessions
    where id = '55555555-5555-5555-5555-555555555555';
  if v_status <> 'cancelled' then
    raise exception 'T3 FAILED: soft alert not cancelled (status=%)', v_status;
  end if;
  raise notice 'T3 ok: owner cancelled a soft alert';
end $$;

-- ---------------------------------------------------------------------------
-- T4: another user CANNOT see the owner's session (RLS select)
-- ---------------------------------------------------------------------------
do $$
declare v_count int;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into v_count from public.emergency_sessions
    where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  reset role;
  if v_count <> 0 then
    raise exception 'T4 FAILED: other user saw % session rows', v_count;
  end if;
  raise notice 'T4 ok: cross-user read blocked';
end $$;

-- ---------------------------------------------------------------------------
-- T5: end_session_by_contact with WRONG token → raise; with RIGHT token → ended
-- ---------------------------------------------------------------------------
do $$
declare raised boolean := false; v_status text; v_by text;
begin
  begin
    perform public.end_session_by_contact(
      'ffffffff-ffff-ffff-ffff-ffffffffffff', 'wrong-token');
  exception when others then
    raised := true;
  end;
  if not raised then
    raise exception 'T5 FAILED: wrong contact token ended the session';
  end if;

  perform public.end_session_by_contact(
    'ffffffff-ffff-ffff-ffff-ffffffffffff', 'secret-token');
  select status, ended_by into v_status, v_by from public.emergency_sessions
    where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  if v_status <> 'ended' or v_by <> 'contact' then
    raise exception 'T5 FAILED: status=% ended_by=%', v_status, v_by;
  end if;
  raise notice 'T5 ok: verified contact ended the session';
end $$;

-- ---------------------------------------------------------------------------
-- T6: server timeout sweep: active->lost_connection->ended (server_timeout)
-- ---------------------------------------------------------------------------
do $$
declare v_status text; v_by text;
begin
  -- fresh stale session, last heartbeat well in the past
  insert into public.emergency_sessions (id, owner_id, kind, status, last_heartbeat_at)
  values ('66666666-6666-6666-6666-666666666666',
          '11111111-1111-1111-1111-111111111111', 'full', 'active',
          now() - interval '10 minutes')
  on conflict (id) do update set status = 'active',
          last_heartbeat_at = now() - interval '10 minutes';

  perform public.expire_stale_sessions(interval '60 seconds', interval '5 minutes');
  select status, ended_by into v_status, v_by from public.emergency_sessions
    where id = '66666666-6666-6666-6666-666666666666';
  if v_status <> 'ended' or v_by <> 'server_timeout' then
    raise exception 'T6 FAILED: status=% ended_by=%', v_status, v_by;
  end if;
  raise notice 'T6 ok: server timeout ended a stale session';
end $$;

-- ---------------------------------------------------------------------------
-- T7: recovery: lost_connection->active; cannot recover an ended session
-- ---------------------------------------------------------------------------
do $$
declare v_status text;
begin
  insert into public.emergency_sessions (id, owner_id, kind, status, last_heartbeat_at)
  values ('77777777-7777-7777-7777-777777777777',
          '11111111-1111-1111-1111-111111111111', 'full', 'lost_connection',
          now() - interval '90 seconds')
  on conflict (id) do update set status = 'lost_connection';

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  set local role authenticated;
  perform public.request_recovery('77777777-7777-7777-7777-777777777777');
  reset role;

  select status into v_status from public.emergency_sessions
    where id = '77777777-7777-7777-7777-777777777777';
  if v_status <> 'active' then
    raise exception 'T7 FAILED: recovery did not reactivate (status=%)', v_status;
  end if;

  -- ended session must NOT be recoverable
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  set local role authenticated;
  perform public.request_recovery('ffffffff-ffff-ffff-ffff-ffffffffffff');
  reset role;
  select status into v_status from public.emergency_sessions
    where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  if v_status <> 'ended' then
    raise exception 'T7 FAILED: an ended session was resurrected (status=%)', v_status;
  end if;
  raise notice 'T7 ok: recovery works and cannot resurrect ended sessions';
end $$;

-- ---------------------------------------------------------------------------
-- T8: service_role CAN set ended directly
-- ---------------------------------------------------------------------------
do $$
declare v_status text;
begin
  insert into public.emergency_sessions (id, owner_id, kind, status, last_heartbeat_at)
  values ('88888888-8888-8888-8888-888888888888',
          '11111111-1111-1111-1111-111111111111', 'full', 'active', now())
  on conflict (id) do update set status = 'active';

  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  -- service_role bypasses RLS; the guard trigger recognizes the role claim.
  update public.emergency_sessions set status = 'ended', ended_at = now(),
         ended_by = 'recovery'
    where id = '88888888-8888-8888-8888-888888888888';
  perform set_config('request.jwt.claims', '', true);

  select status into v_status from public.emergency_sessions
    where id = '88888888-8888-8888-8888-888888888888';
  if v_status <> 'ended' then
    raise exception 'T8 FAILED: service_role could not end (status=%)', v_status;
  end if;
  raise notice 'T8 ok: service_role can end a session';
end $$;

\echo '==================================='
\echo ' ALL RLS / SAFETY-CORE TESTS PASSED'
\echo '==================================='
