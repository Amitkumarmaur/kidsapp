-- Proves row-level security keeps families apart, and limits what a child device can do.
-- Run with: supabase test db   (everything runs inside a transaction and is rolled back)

begin;
create extension if not exists pgtap with schema extensions;
select plan(38);

-- ---------------------------------------------------------------------------
-- Fixtures (as the postgres superuser, which bypasses RLS)
-- ---------------------------------------------------------------------------

-- Two parents. The sign-up trigger creates a family for each.
insert into auth.users (id, email, is_anonymous) values
  ('a0000000-0000-4000-8000-000000000001', 'parent.a@example.com', false),
  ('b0000000-0000-4000-8000-000000000001', 'parent.b@example.com', false);
-- Two child phones (anonymous users), one per family.
insert into auth.users (id, is_anonymous) values
  ('a0000000-0000-4000-8000-0000000000d1', true),
  ('b0000000-0000-4000-8000-0000000000d1', true);

-- Family ids are generated, so keep them in a temp table the test roles can read.
create temp table ids as
select
  (select family_id from public.guardian where auth_uid = 'a0000000-0000-4000-8000-000000000001') as fam_a,
  (select family_id from public.guardian where auth_uid = 'b0000000-0000-4000-8000-000000000001') as fam_b;
grant select on ids to authenticated, anon;

insert into public.child (id, family_id, name, age_band) values
  ('a0000000-0000-4000-8000-0000000000c1', (select fam_a from ids), 'Aarav', '10-12'),
  ('b0000000-0000-4000-8000-0000000000c1', (select fam_b from ids), 'Bela',  '6-9');

insert into public.device (id, family_id, child_id, auth_uid) values
  ('a0000000-0000-4000-8000-0000000000e1', (select fam_a from ids), 'a0000000-0000-4000-8000-0000000000c1', 'a0000000-0000-4000-8000-0000000000d1'),
  ('b0000000-0000-4000-8000-0000000000e1', (select fam_b from ids), 'b0000000-0000-4000-8000-0000000000c1', 'b0000000-0000-4000-8000-0000000000d1');

insert into public.rule (id, child_id, type, params) values
  ('a0000000-0000-4000-8000-0000000000f1', 'a0000000-0000-4000-8000-0000000000c1', 'daily_limit', '{"weekday_minutes": 120, "weekend_minutes": 180}'),
  ('b0000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-0000000000c1', 'daily_limit', '{"weekday_minutes": 90, "weekend_minutes": 120}');

insert into public.geofence (family_id, name, lat, lng, radius_m) values
  ((select fam_a from ids), 'Home A', 19.0760, 72.8777, 150),
  ((select fam_b from ids), 'Home B', 28.6139, 77.2090, 150);

insert into public.location_point (device_id, lat, lng, accuracy_m, recorded_at) values
  ('a0000000-0000-4000-8000-0000000000e1', 19.0760, 72.8777, 10, now()),
  ('b0000000-0000-4000-8000-0000000000e1', 28.6139, 77.2090, 10, now());

insert into public.app_usage (device_id, package, day, foreground_seconds) values
  ('a0000000-0000-4000-8000-0000000000e1', 'com.example.game', current_date, 600),
  ('b0000000-0000-4000-8000-0000000000e1', 'com.example.game', current_date, 900);

insert into public.alert (family_id, child_id, type) values
  ((select fam_a from ids), 'a0000000-0000-4000-8000-0000000000c1', 'low_battery'),
  ((select fam_b from ids), 'b0000000-0000-4000-8000-0000000000c1', 'low_battery');

insert into public.time_request (id, child_id, device_id, minutes) values
  ('a0000000-0000-4000-8000-0000000000a1', 'a0000000-0000-4000-8000-0000000000c1', 'a0000000-0000-4000-8000-0000000000e1', 15),
  ('b0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-0000000000c1', 'b0000000-0000-4000-8000-0000000000e1', 15);

insert into public.subscription (family_id, store, product_id, status) values
  ((select fam_b from ids), 'google_play', 'kidguard_monthly', 'active');

-- ---------------------------------------------------------------------------
-- Parent A
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub": "a0000000-0000-4000-8000-000000000001", "role": "authenticated"}';

select is((select count(*)::int from public.family), 1, 'Parent A sees exactly one family');
select is((select id from public.family), (select fam_a from ids), 'and it is family A');
select is((select count(*)::int from public.guardian), 1, 'Parent A sees only the guardians of family A');
select is((select count(*)::int from public.child), 1, 'Parent A sees only their own child');
select is((select count(*)::int from public.device), 1, 'Parent A sees only their own device');
select is((select count(*)::int from public.rule), 1, 'Parent A sees only their own rules');
select is((select count(*)::int from public.geofence), 1, 'Parent A sees only their own places');
select is((select count(*)::int from public.location_point), 1, 'Parent A sees only their own child''s location');
select is((select count(*)::int from public.app_usage), 1, 'Parent A sees only their own child''s usage');
select is((select count(*)::int from public.alert), 1, 'Parent A sees only their own alerts');
select is((select count(*)::int from public.time_request), 1, 'Parent A sees only their own time requests');
select is_empty($$ select 1 from public.subscription $$, 'Parent A cannot see family B''s subscription');
select is_empty($$ select 1 from public.location_point where device_id = 'b0000000-0000-4000-8000-0000000000e1' $$,
  'Parent A cannot read family B location points even by id');

-- Writes into family B are refused or silently match nothing.
select throws_ok(
  $$ insert into public.child (family_id, name, age_band) values ((select fam_b from ids), 'Intruder', '6-9') $$,
  '42501', null, 'Parent A cannot add a child to family B');
select throws_ok(
  $$ insert into public.rule (child_id, type, params) values ('b0000000-0000-4000-8000-0000000000c1', 'block', '{"package": "com.whatsapp"}') $$,
  '42501', null, 'Parent A cannot add a rule for family B''s child');
select is_empty(
  $$ update public.rule set active = false where id = 'b0000000-0000-4000-8000-0000000000f1' returning id $$,
  'Parent A cannot change family B''s rule');
select is_empty(
  $$ delete from public.child where id = 'b0000000-0000-4000-8000-0000000000c1' returning id $$,
  'Parent A cannot delete family B''s child');
select is_empty(
  $$ delete from public.device where id = 'b0000000-0000-4000-8000-0000000000e1' returning id $$,
  'Parent A cannot unpair family B''s device');
select is_empty(
  $$ update public.time_request set status = 'approved' where id = 'b0000000-0000-4000-8000-0000000000a1' returning id $$,
  'Parent A cannot decide family B''s time request');
select throws_ok(
  $$ update public.family set plan = 'premium' $$,
  '42501', null, 'Parents cannot give themselves a paid plan');
select throws_ok(
  $$ insert into public.alert (family_id, type) values ((select fam_a from ids), 'low_battery') $$,
  '42501', null, 'Parents cannot create alerts (backend only)');

-- Parent A decides their own child's request: who and when are stamped automatically.
select lives_ok(
  $$ update public.time_request set status = 'approved' where id = 'a0000000-0000-4000-8000-0000000000a1' $$,
  'Parent A can approve their own child''s request');
select is(
  (select decided_by from public.time_request where id = 'a0000000-0000-4000-8000-0000000000a1'),
  (select id from public.guardian where auth_uid = 'a0000000-0000-4000-8000-000000000001'),
  'The decision records which parent approved it');

-- ---------------------------------------------------------------------------
-- Child device A (anonymous user paired to child A)
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"sub": "a0000000-0000-4000-8000-0000000000d1", "role": "authenticated", "is_anonymous": true}';

select is((select count(*)::int from public.child), 1, 'Device A sees only its own child');
select is((select count(*)::int from public.rule), 1, 'Device A reads only its own child''s rules');
select is((select count(*)::int from public.geofence), 1, 'Device A reads only its own family''s places');
select is_empty($$ select 1 from public.guardian $$, 'Device A cannot see parent accounts');
select is_empty($$ select 1 from public.location_point $$, 'Device A cannot read location history (parents only)');

select lives_ok(
  $$ insert into public.location_point (device_id, lat, lng, recorded_at) values ('a0000000-0000-4000-8000-0000000000e1', 19.07, 72.87, now()) $$,
  'Device A can upload its own location');
select throws_ok(
  $$ insert into public.location_point (device_id, lat, lng, recorded_at) values ('b0000000-0000-4000-8000-0000000000e1', 0, 0, now()) $$,
  '42501', null, 'Device A cannot write location for family B''s device');
select lives_ok(
  $$ insert into public.app_usage (device_id, package, day, foreground_seconds)
     values ('a0000000-0000-4000-8000-0000000000e1', 'com.example.game', current_date, 1200)
     on conflict (device_id, day, package) do update set foreground_seconds = excluded.foreground_seconds $$,
  'Device A can upsert its own daily usage');
select lives_ok(
  $$ insert into public.time_request (child_id, device_id, minutes) values ('a0000000-0000-4000-8000-0000000000c1', 'a0000000-0000-4000-8000-0000000000e1', 30) $$,
  'Device A can ask for more time');
select throws_ok(
  $$ insert into public.time_request (child_id, device_id, minutes, status) values ('a0000000-0000-4000-8000-0000000000c1', 'a0000000-0000-4000-8000-0000000000e1', 30, 'approved') $$,
  '42501', null, 'Device A cannot approve its own request');
select throws_ok(
  $$ insert into public.rule (child_id, type) values ('a0000000-0000-4000-8000-0000000000c1', 'always_allow') $$,
  '42501', null, 'Device A cannot create rules');

-- ---------------------------------------------------------------------------
-- After unpairing, the old device token is useless
-- ---------------------------------------------------------------------------
reset role;
delete from public.device where id = 'a0000000-0000-4000-8000-0000000000e1';
set local role authenticated;
set local request.jwt.claims to '{"sub": "a0000000-0000-4000-8000-0000000000d1", "role": "authenticated", "is_anonymous": true}';

select is_empty($$ select 1 from public.rule $$, 'An unpaired device can no longer read rules');

-- ---------------------------------------------------------------------------
-- No sign-in at all
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok($$ select 1 from public.child $$, '42501', null, 'Signed-out callers cannot read any table');

-- ---------------------------------------------------------------------------
-- Family B's data is untouched by everything above
-- ---------------------------------------------------------------------------
reset role;
select is((select active from public.rule where id = 'b0000000-0000-4000-8000-0000000000f1'), true, 'Family B''s rule is unchanged');
select is((select status from public.time_request where id = 'b0000000-0000-4000-8000-0000000000a1'), 'pending', 'Family B''s request is still pending');

select * from finish();
rollback;
