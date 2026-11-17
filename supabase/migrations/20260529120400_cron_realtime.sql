-- Schedule the timeout sweep and expose the live tables to Realtime.
-- Both are guarded so `db reset` succeeds even where the extension/publication
-- differ between local and hosted.

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    -- Sub-minute schedules require pg_cron >= 1.5 (Supabase ships it).
    perform cron.schedule(
      'guardian-expire-sessions',
      '30 seconds',
      $cron$ select public.expire_stale_sessions(); $cron$
    );
  else
    raise notice 'pg_cron unavailable; timeout sweep must be invoked externally';
  end if;
exception when others then
  raise notice 'pg_cron setup skipped: %', sqlerrm;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.emergency_sessions;
  alter publication supabase_realtime add table public.session_events;
exception when others then
  raise notice 'realtime publication not updated: %', sqlerrm;
end;
$$;
