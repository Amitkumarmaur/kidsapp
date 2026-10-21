-- Daily data retention job (PRD section 10.3):
--   * location points older than 30 days
--   * app usage older than 12 months
--   * old pairing codes and pairing attempts (after 1 day)

create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

create function private.daily_cleanup()
returns void
language sql
set search_path = ''
as $$
  delete from public.location_point where recorded_at < now() - interval '30 days';
  delete from public.app_usage where day < (now() - interval '12 months')::date;
  delete from public.pairing_code where expires_at < now() - interval '1 day';
  delete from private.pairing_attempt where attempted_at < now() - interval '1 day';
$$;

revoke all on function private.daily_cleanup() from public;

-- Every day at 03:00 UTC (08:30 in India). cron.schedule with a name replaces any job with the same name.
select cron.schedule('kidguard-daily-cleanup', '0 3 * * *', 'select private.daily_cleanup()');
