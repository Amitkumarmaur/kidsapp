-- Demo data for LOCAL development only (loaded by `supabase start` and `supabase db reset`).
-- Never run this on the production project.
--
-- Two families you can sign in as (email + password, local only):
--   priya@example.com / password123   -> "Sharma family": Aarav (10-12, phone paired), Meera (13-17, not paired)
--   ravi@example.com  / password123   -> "Verma family":  Kabir (6-9, phone paired)

-- ---------------------------------------------------------------------------
-- Auth users. The sign-up trigger creates each parent's family automatically.
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, is_anonymous, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated',
   'priya@example.com', extensions.crypt('password123', extensions.gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}', '{"family_name": "Sharma family"}', false, now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated',
   'ravi@example.com', extensions.crypt('password123', extensions.gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}', '{"family_name": "Verma family"}', false, now(), now(), '', '', '', '');

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111',
   '{"sub": "11111111-1111-4111-8111-111111111111", "email": "priya@example.com", "email_verified": true}', 'email', now(), now(), now()),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222',
   '{"sub": "22222222-2222-4222-8222-222222222222", "email": "ravi@example.com", "email_verified": true}', 'email', now(), now(), now());

-- Child phones are anonymous users (no email, no password).
insert into auth.users (instance_id, id, aud, role, is_anonymous, raw_app_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-4111-8111-1111111111d1', 'authenticated', 'authenticated', true, '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-4222-8222-2222222222d1', 'authenticated', 'authenticated', true, '{}', now(), now());

-- ---------------------------------------------------------------------------
-- Children and paired devices
-- ---------------------------------------------------------------------------
insert into public.child (id, family_id, name, age_band, avatar) values
  ('11111111-1111-4111-8111-1111111111c1',
   (select family_id from public.guardian where auth_uid = '11111111-1111-4111-8111-111111111111'), 'Aarav', '10-12', 'lion'),
  ('11111111-1111-4111-8111-1111111111c2',
   (select family_id from public.guardian where auth_uid = '11111111-1111-4111-8111-111111111111'), 'Meera', '13-17', 'owl'),
  ('22222222-2222-4222-8222-2222222222c1',
   (select family_id from public.guardian where auth_uid = '22222222-2222-4222-8222-222222222222'), 'Kabir', '6-9', 'panda');

insert into public.device (id, family_id, child_id, auth_uid, model, os_version, app_version, battery, last_seen_at) values
  ('11111111-1111-4111-8111-1111111111e1',
   (select family_id from public.child where id = '11111111-1111-4111-8111-1111111111c1'),
   '11111111-1111-4111-8111-1111111111c1', '11111111-1111-4111-8111-1111111111d1', 'Redmi Note 13', '14', '0.1.0', 76, now()),
  ('22222222-2222-4222-8222-2222222222e1',
   (select family_id from public.child where id = '22222222-2222-4222-8222-2222222222c1'),
   '22222222-2222-4222-8222-2222222222c1', '22222222-2222-4222-8222-2222222222d1', 'Samsung Galaxy A15', '14', '0.1.0', 41, now());

-- Both families have paired a phone, so their trials have started.
update public.family set trial_ends_at = now() + interval '3 days';

-- ---------------------------------------------------------------------------
-- Rules (family_id is filled in by trigger)
-- ---------------------------------------------------------------------------
insert into public.rule (child_id, type, params) values
  ('11111111-1111-4111-8111-1111111111c1', 'daily_limit',  '{"weekday_minutes": 120, "weekend_minutes": 180}'),
  ('11111111-1111-4111-8111-1111111111c1', 'app_limit',    '{"package": "com.supercell.clashroyale", "minutes": 30}'),
  ('11111111-1111-4111-8111-1111111111c1', 'downtime',     '{"start": "21:00", "end": "07:00", "days": [1, 2, 3, 4, 5, 6, 7]}'),
  ('11111111-1111-4111-8111-1111111111c1', 'always_allow', '{"package": "com.google.android.dialer"}'),
  ('11111111-1111-4111-8111-1111111111c2', 'daily_limit',  '{"weekday_minutes": 180, "weekend_minutes": 240}'),
  ('22222222-2222-4222-8222-2222222222c1', 'daily_limit',  '{"weekday_minutes": 90, "weekend_minutes": 120}'),
  ('22222222-2222-4222-8222-2222222222c1', 'block',        '{"package": "com.instagram.android"}');

-- ---------------------------------------------------------------------------
-- Places, location history, usage
-- ---------------------------------------------------------------------------
insert into public.geofence (family_id, name, lat, lng, radius_m) values
  ((select family_id from public.child where id = '11111111-1111-4111-8111-1111111111c1'), 'Home',   19.0760, 72.8777, 150),
  ((select family_id from public.child where id = '11111111-1111-4111-8111-1111111111c1'), 'School', 19.0896, 72.8656, 200),
  ((select family_id from public.child where id = '22222222-2222-4222-8222-2222222222c1'), 'Home',   28.6139, 77.2090, 150);

-- Aarav: a walk to school this morning, plus one 35-day-old point the daily cleanup will delete.
insert into public.location_point (device_id, lat, lng, accuracy_m, recorded_at) values
  ('11111111-1111-4111-8111-1111111111e1', 19.0760, 72.8777, 12, now() - interval '3 hours'),
  ('11111111-1111-4111-8111-1111111111e1', 19.0810, 72.8730, 15, now() - interval '2 hours 50 minutes'),
  ('11111111-1111-4111-8111-1111111111e1', 19.0896, 72.8656, 10, now() - interval '2 hours 40 minutes'),
  ('11111111-1111-4111-8111-1111111111e1', 19.0760, 72.8777, 20, now() - interval '35 days'),
  ('22222222-2222-4222-8222-2222222222e1', 28.6139, 77.2090, 18, now() - interval '20 minutes');

insert into public.app_usage (device_id, package, day, foreground_seconds) values
  ('11111111-1111-4111-8111-1111111111e1', 'com.supercell.clashroyale', current_date, 1500),
  ('11111111-1111-4111-8111-1111111111e1', 'com.google.android.youtube', current_date, 2400),
  ('11111111-1111-4111-8111-1111111111e1', 'com.google.android.youtube', current_date - 1, 3600),
  ('22222222-2222-4222-8222-2222222222e1', 'com.google.android.apps.youtube.kids', current_date, 1800);

-- ---------------------------------------------------------------------------
-- Alerts and a pending request for more time
-- ---------------------------------------------------------------------------
insert into public.alert (family_id, child_id, type, payload) values
  ((select family_id from public.child where id = '11111111-1111-4111-8111-1111111111c1'),
   '11111111-1111-4111-8111-1111111111c1', 'geofence_enter', '{"place": "School"}'),
  ((select family_id from public.child where id = '22222222-2222-4222-8222-2222222222c1'),
   '22222222-2222-4222-8222-2222222222c1', 'low_battery', '{"battery": 14}');

insert into public.time_request (child_id, device_id, app, minutes) values
  ('11111111-1111-4111-8111-1111111111c1', '11111111-1111-4111-8111-1111111111e1', 'com.supercell.clashroyale', 15);
