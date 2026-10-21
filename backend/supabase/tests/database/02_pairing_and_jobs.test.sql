-- Proves pairing codes are 6 digits, single use, expire after 10 minutes and resist guessing,
-- and that the daily cleanup, geofence limit and rule versioning work.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- Fixtures: parent A with one child, parent B, and three child phones (anonymous users).
insert into auth.users (id, email, is_anonymous) values
  ('a0000000-0000-4000-8000-000000000001', 'parent.a@example.com', false),
  ('b0000000-0000-4000-8000-000000000001', 'parent.b@example.com', false);
insert into auth.users (id, is_anonymous) values
  ('a0000000-0000-4000-8000-0000000000d1', true),
  ('a0000000-0000-4000-8000-0000000000d2', true),
  ('a0000000-0000-4000-8000-0000000000d3', true);

create temp table ids as
select (select family_id from public.guardian where auth_uid = 'a0000000-0000-4000-8000-000000000001') as fam_a;

insert into public.child (id, family_id, name, age_band) values
  ('a0000000-0000-4000-8000-0000000000c1', (select fam_a from ids), 'Aarav', '10-12');

-- ---------------------------------------------------------------------------
-- Creating codes
-- ---------------------------------------------------------------------------
create temp table made as
select public.create_pairing_code('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1') as r;

select is((select r ->> 'ok' from made), 'true', 'Parent A can create a pairing code for their child');
select ok((select r ->> 'code' from made) ~ '^[0-9]{6}$', 'The code is exactly 6 digits');
select ok(
  (select (r ->> 'expires_at')::timestamptz from made) between now() + interval '9 minutes' and now() + interval '11 minutes',
  'The code expires in 10 minutes');
select is(
  (select public.create_pairing_code('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1') ->> 'error'),
  'child_not_found',
  'Parent B cannot create a code for family A''s child');

-- ---------------------------------------------------------------------------
-- Redeeming codes
-- ---------------------------------------------------------------------------
create temp table redeemed as
select public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d1', (select r ->> 'code' from made), 'Redmi Note 13', '14', '0.1.0') as r;

select is((select r ->> 'ok' from redeemed), 'true', 'A child phone can redeem the code');
select is((select r ->> 'child_name' from redeemed), 'Aarav', 'Redeeming tells the phone which child it belongs to');
select is(
  (select child_id from public.device where auth_uid = 'a0000000-0000-4000-8000-0000000000d1'),
  'a0000000-0000-4000-8000-0000000000c1'::uuid,
  'The phone is now a device of that child');
select ok((select trial_ends_at is not null from public.family where id = (select fam_a from ids)), 'The 3-day trial starts at first pairing');

select is(
  (select public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d2', (select r ->> 'code' from made)) ->> 'error'),
  'invalid_or_expired',
  'A code works only once');
select is(
  (select public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d1', '000000') ->> 'error'),
  'already_paired',
  'An already paired phone cannot pair again');
select is(
  (select public.redeem_pairing_code('a0000000-0000-4000-8000-000000000001', '000000') ->> 'error'),
  'not_a_child_device',
  'A parent account cannot become a child device');

-- An expired code is refused.
insert into public.pairing_code (code, family_id, child_id, expires_at)
values ('424242', (select fam_a from ids), 'a0000000-0000-4000-8000-0000000000c1', now() - interval '1 minute');
select is(
  (select public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d2', '424242') ->> 'error'),
  'invalid_or_expired',
  'An expired code is refused');

-- Guessing: after 5 wrong codes (one was the expired code above) even a correct code is refused for a while.
do $$
begin
  perform public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d2', '111111');
  perform public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d2', '222222');
  perform public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d2', '333333');
  perform public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d2', '444444');
end $$;
create temp table fresh as
select public.create_pairing_code('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1') as r;
select is(
  (select public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d2', (select r ->> 'code' from fresh)) ->> 'error'),
  'too_many_attempts',
  'After 5 wrong guesses the phone is locked out');
select is(
  (select public.redeem_pairing_code('a0000000-0000-4000-8000-0000000000d3', (select r ->> 'code' from fresh)) ->> 'ok'),
  'true',
  'A different phone can still use the valid code');

-- Making a new code replaces the child's previous unused one.
do $$
begin
  perform public.create_pairing_code('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1');
  perform public.create_pairing_code('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1');
end $$;
select is(
  (select count(*)::int from public.pairing_code where child_id = 'a0000000-0000-4000-8000-0000000000c1' and used_at is null),
  1,
  'Only one live code per child');

-- Apps cannot call the pairing functions directly; only the edge functions (service role) can.
set local role authenticated;
set local request.jwt.claims to '{"sub": "a0000000-0000-4000-8000-000000000001", "role": "authenticated"}';
select throws_ok(
  $$ select public.create_pairing_code('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1') $$,
  '42501', null, 'Signed-in apps cannot call create_pairing_code directly');
select throws_ok(
  $$ select public.redeem_pairing_code('a0000000-0000-4000-8000-000000000001', '123456') $$,
  '42501', null, 'Signed-in apps cannot call redeem_pairing_code directly');

-- The parent can see their child's codes (to show them on screen).
select ok((select count(*) from public.pairing_code) >= 1, 'Parent A can read their own pairing codes');
reset role;

-- ---------------------------------------------------------------------------
-- Daily cleanup: location older than 30 days is deleted
-- ---------------------------------------------------------------------------
insert into public.location_point (device_id, lat, lng, recorded_at)
select d.id, 19.07, 72.87, now() - interval '31 days' from public.device d where d.auth_uid = 'a0000000-0000-4000-8000-0000000000d1';
insert into public.location_point (device_id, lat, lng, recorded_at)
select d.id, 19.07, 72.87, now() - interval '29 days' from public.device d where d.auth_uid = 'a0000000-0000-4000-8000-0000000000d1';

select private.daily_cleanup();

select is(
  (select count(*)::int from public.location_point where recorded_at < now() - interval '30 days'),
  0, 'Location points older than 30 days are deleted');
select is(
  (select count(*)::int from public.location_point lp join public.device d on d.id = lp.device_id where d.auth_uid = 'a0000000-0000-4000-8000-0000000000d1' and lp.recorded_at >= now() - interval '30 days'),
  1, 'Newer location points are kept');

-- ---------------------------------------------------------------------------
-- Geofence limit and rule versioning
-- ---------------------------------------------------------------------------
insert into public.geofence (family_id, name, lat, lng, radius_m)
select (select fam_a from ids), 'Place ' || n, 19.0 + n * 0.01, 72.8, 100 from generate_series(1, 10) n;
select throws_ok(
  $$ insert into public.geofence (family_id, name, lat, lng, radius_m) values ((select fam_a from ids), 'Place 11', 19.2, 72.8, 100) $$,
  '23514', null, 'A family cannot have more than 10 places');

insert into public.rule (id, child_id, type, params)
values ('a0000000-0000-4000-8000-0000000000f1', 'a0000000-0000-4000-8000-0000000000c1', 'daily_limit', '{"weekday_minutes": 120}');
update public.rule set params = '{"weekday_minutes": 90}' where id = 'a0000000-0000-4000-8000-0000000000f1';
select is((select version from public.rule where id = 'a0000000-0000-4000-8000-0000000000f1'), 2, 'Changing a rule bumps its version');
select is(
  (select count(*)::int from public.audit_log where target like '%a0000000-0000-4000-8000-0000000000f1'),
  2, 'Creating and changing the rule are both in the audit log');

-- Deleting the child removes everything that belonged to them.
delete from public.child where id = 'a0000000-0000-4000-8000-0000000000c1';
select is((select count(*)::int from public.device where family_id = (select fam_a from ids)), 0, 'Deleting a child removes their devices');

select * from finish();
rollback;
