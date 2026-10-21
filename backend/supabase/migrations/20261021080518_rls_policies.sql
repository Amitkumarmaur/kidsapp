-- Row-level security for KidGuard.
--
-- Two kinds of signed-in callers, both with the Postgres role "authenticated":
--   * Guardian: a parent account. Reads and writes only rows of their own family.
--   * Device:   a child phone (anonymous Supabase user listed in public.device).
--               Reads its own child's profile, rules, geofences and time requests, and
--               writes only usage, location and time requests for its own child.
--               It may also update its own device row (battery, versions) as a heartbeat.
-- The "anon" role (no sign-in at all) gets nothing.
-- Billing, alerts and pairing are written by edge functions using the service role, which bypasses RLS.

-- ---------------------------------------------------------------------------
-- Helper functions (security definer so policies can look up guardian/device
-- without recursing into RLS). They only ever answer about the current caller.
-- ---------------------------------------------------------------------------

create function private.my_family_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select g.family_id from public.guardian g where g.auth_uid = (select auth.uid());
$$;

create function private.my_device_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select d.id from public.device d where d.auth_uid = (select auth.uid());
$$;

create function private.my_child_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select d.child_id from public.device d where d.auth_uid = (select auth.uid());
$$;

create function private.my_device_family_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select d.family_id from public.device d where d.auth_uid = (select auth.uid());
$$;

revoke all on all functions in schema private from public;
grant usage on schema private to authenticated, service_role;
grant execute on function
  private.my_family_ids(), private.my_device_id(), private.my_child_id(), private.my_device_family_id()
  to authenticated;

-- ---------------------------------------------------------------------------
-- Table privileges: start from nothing, then grant only what each caller needs.
-- RLS policies below decide WHICH rows; these grants decide WHICH columns.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select, update (name)                                                on public.family         to authenticated;
grant select, update (push_token)                                          on public.guardian       to authenticated;
grant select, insert, update (name, age_band, avatar), delete              on public.child          to authenticated;
grant select, update (battery, model, os_version, app_version), delete     on public.device         to authenticated;
grant select                                                               on public.pairing_code   to authenticated;
grant select, insert, update (type, params, active), delete                on public.rule           to authenticated;
grant select, insert, update (device_id, day, package, foreground_seconds) on public.app_usage      to authenticated;
grant select, insert                                                       on public.location_point to authenticated;
grant select, insert, update (name, lat, lng, radius_m), delete            on public.geofence       to authenticated;
grant select, update (read_at), delete                                     on public.alert          to authenticated;
grant select, insert, update (status)                                      on public.time_request   to authenticated;
grant select                                                               on public.subscription   to authenticated;
grant select                                                               on public.audit_log      to authenticated;

-- The service role (edge functions) needs the pairing-attempt log too.
grant select, insert, delete on private.pairing_attempt to service_role;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------

alter table public.family         enable row level security;
alter table public.guardian       enable row level security;
alter table public.child          enable row level security;
alter table public.device         enable row level security;
alter table public.pairing_code   enable row level security;
alter table public.rule           enable row level security;
alter table public.app_usage      enable row level security;
alter table public.location_point enable row level security;
alter table public.geofence       enable row level security;
alter table public.alert          enable row level security;
alter table public.time_request   enable row level security;
alter table public.subscription   enable row level security;
alter table public.audit_log      enable row level security;
alter table private.pairing_attempt enable row level security;  -- service role only; no policies

-- ---------------------------------------------------------------------------
-- Policies
-- (select ...) wrappers let Postgres evaluate each helper once per query, not once per row.
-- ---------------------------------------------------------------------------

-- family: guardians see and rename their own family. Plan and trial dates are not client-writable.
create policy "family: guardians read" on public.family
  for select to authenticated
  using (id in (select private.my_family_ids()));
create policy "family: guardians rename" on public.family
  for update to authenticated
  using (id in (select private.my_family_ids()))
  with check (id in (select private.my_family_ids()));

-- guardian: see the other guardians of your family; update only your own push token.
create policy "guardian: family reads" on public.guardian
  for select to authenticated
  using (family_id in (select private.my_family_ids()));
create policy "guardian: update own row" on public.guardian
  for update to authenticated
  using (auth_uid = (select auth.uid()))
  with check (auth_uid = (select auth.uid()));

-- child: guardians manage children in their family; a device can read its own child's profile.
create policy "child: read" on public.child
  for select to authenticated
  using (family_id in (select private.my_family_ids()) or id = (select private.my_child_id()));
create policy "child: guardians insert" on public.child
  for insert to authenticated
  with check (family_id in (select private.my_family_ids()));
create policy "child: guardians update" on public.child
  for update to authenticated
  using (family_id in (select private.my_family_ids()))
  with check (family_id in (select private.my_family_ids()));
create policy "child: guardians delete" on public.child
  for delete to authenticated
  using (family_id in (select private.my_family_ids()));

-- device: guardians see and unpair (delete) devices; a device sees and heartbeats its own row.
-- Devices are created only by the redeem_pairing_code edge function.
create policy "device: read" on public.device
  for select to authenticated
  using (family_id in (select private.my_family_ids()) or auth_uid = (select auth.uid()));
create policy "device: own heartbeat" on public.device
  for update to authenticated
  using (auth_uid = (select auth.uid()))
  with check (auth_uid = (select auth.uid()));
create policy "device: guardians unpair" on public.device
  for delete to authenticated
  using (family_id in (select private.my_family_ids()));

-- pairing_code: guardians can see their family's codes. Created/redeemed only by edge functions.
create policy "pairing_code: guardians read" on public.pairing_code
  for select to authenticated
  using (family_id in (select private.my_family_ids()));

-- rule: guardians manage; the device reads its own child's rules to enforce them offline.
create policy "rule: read" on public.rule
  for select to authenticated
  using (family_id in (select private.my_family_ids()) or child_id = (select private.my_child_id()));
create policy "rule: guardians insert" on public.rule
  for insert to authenticated
  with check (family_id in (select private.my_family_ids()));
create policy "rule: guardians update" on public.rule
  for update to authenticated
  using (family_id in (select private.my_family_ids()))
  with check (family_id in (select private.my_family_ids()));
create policy "rule: guardians delete" on public.rule
  for delete to authenticated
  using (family_id in (select private.my_family_ids()));

-- app_usage: the device writes (upserts) its own rows; guardians read.
create policy "app_usage: read" on public.app_usage
  for select to authenticated
  using (family_id in (select private.my_family_ids()) or device_id = (select private.my_device_id()));
create policy "app_usage: device insert" on public.app_usage
  for insert to authenticated
  with check (device_id = (select private.my_device_id()));
create policy "app_usage: device update" on public.app_usage
  for update to authenticated
  using (device_id = (select private.my_device_id()))
  with check (device_id = (select private.my_device_id()));

-- location_point: the device inserts its own points; only guardians read them.
create policy "location_point: guardians read" on public.location_point
  for select to authenticated
  using (family_id in (select private.my_family_ids()));
create policy "location_point: device insert" on public.location_point
  for insert to authenticated
  with check (device_id = (select private.my_device_id()));

-- geofence: guardians manage; the device reads its family's places to register them on the phone.
create policy "geofence: read" on public.geofence
  for select to authenticated
  using (family_id in (select private.my_family_ids()) or family_id = (select private.my_device_family_id()));
create policy "geofence: guardians insert" on public.geofence
  for insert to authenticated
  with check (family_id in (select private.my_family_ids()));
create policy "geofence: guardians update" on public.geofence
  for update to authenticated
  using (family_id in (select private.my_family_ids()))
  with check (family_id in (select private.my_family_ids()));
create policy "geofence: guardians delete" on public.geofence
  for delete to authenticated
  using (family_id in (select private.my_family_ids()));

-- alert: guardians read, mark read and delete. Created by the backend only.
create policy "alert: guardians read" on public.alert
  for select to authenticated
  using (family_id in (select private.my_family_ids()));
create policy "alert: guardians mark read" on public.alert
  for update to authenticated
  using (family_id in (select private.my_family_ids()))
  with check (family_id in (select private.my_family_ids()));
create policy "alert: guardians delete" on public.alert
  for delete to authenticated
  using (family_id in (select private.my_family_ids()));

-- time_request: the device asks (only as pending, only for itself); guardians decide.
create policy "time_request: read" on public.time_request
  for select to authenticated
  using (family_id in (select private.my_family_ids()) or child_id = (select private.my_child_id()));
create policy "time_request: device asks" on public.time_request
  for insert to authenticated
  with check (
    device_id = (select private.my_device_id())
    and child_id = (select private.my_child_id())
    and status = 'pending'
    and decided_by is null
    and decided_at is null
  );
create policy "time_request: guardians decide" on public.time_request
  for update to authenticated
  using (family_id in (select private.my_family_ids()))
  with check (family_id in (select private.my_family_ids()));

-- subscription and audit_log: guardians read only.
create policy "subscription: guardians read" on public.subscription
  for select to authenticated
  using (family_id in (select private.my_family_ids()));
create policy "audit_log: guardians read" on public.audit_log
  for select to authenticated
  using (family_id in (select private.my_family_ids()));
