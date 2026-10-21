-- KidGuard schema: tables from PRD section 9.
-- Every row carries family_id so row-level security (next migration) can keep families apart.
-- Children never log in. A child phone signs in as an anonymous Supabase user; its auth uid is
-- stored in device.auth_uid and acts as the "device token" tied to exactly one child profile.

-- Internal helpers (RLS helpers, triggers, cleanup) live here. This schema is NOT exposed by the Data API.
create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Families and the people in them
-- ---------------------------------------------------------------------------

create table public.family (
  id            uuid primary key default gen_random_uuid(),
  name          text not null default 'My family' check (char_length(name) between 1 and 80),
  plan          text not null default 'trial' check (plan in ('trial', 'free', 'premium')),
  trial_ends_at timestamptz,                -- set when the first child device is paired (PRD section 11)
  created_at    timestamptz not null default now()
);

create table public.guardian (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.family (id) on delete cascade,
  auth_uid   uuid not null references auth.users (id) on delete cascade,
  role       text not null default 'owner' check (role in ('owner', 'co_parent')),
  push_token text,                          -- FCM token for parent alerts
  created_at timestamptz not null default now(),
  unique (family_id, auth_uid)
);
create index guardian_auth_uid_idx on public.guardian (auth_uid);

-- No email or phone for the child (PRD section 9).
create table public.child (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.family (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 50),
  age_band   text not null check (age_band in ('6-9', '10-12', '13-17')),
  avatar     text,
  created_at timestamptz not null default now()
);
create index child_family_id_idx on public.child (family_id);

create table public.device (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.family (id) on delete cascade,
  child_id     uuid not null references public.child (id) on delete cascade,
  auth_uid     uuid not null unique references auth.users (id) on delete cascade,  -- the device token
  platform     text not null default 'android' check (platform in ('android', 'ios')),
  model        text check (char_length(model) <= 100),
  os_version   text check (char_length(os_version) <= 50),
  app_version  text check (char_length(app_version) <= 50),
  battery      smallint check (battery between 0 and 100),
  last_seen_at timestamptz,                 -- always server time, set by trigger
  paired_at    timestamptz not null default now()
);
create index device_family_id_idx on public.device (family_id);
create index device_child_id_idx on public.device (child_id);

-- 6-digit, 10-minute, single-use codes. Only the edge functions create and redeem them.
create table public.pairing_code (
  id         uuid primary key default gen_random_uuid(),
  code       text not null check (code ~ '^[0-9]{6}$'),
  family_id  uuid not null references public.family (id) on delete cascade,
  child_id   uuid not null references public.child (id) on delete cascade,
  created_by uuid references public.guardian (id) on delete set null,
  expires_at timestamptz not null default now() + interval '10 minutes',
  used_at    timestamptz,
  used_by    uuid,                          -- auth uid of the device that redeemed it
  created_at timestamptz not null default now()
);
-- A number can only be live once at a time (expired unused codes are deleted before new ones are made).
create unique index pairing_code_live_code_idx on public.pairing_code (code) where used_at is null;
create index pairing_code_family_id_idx on public.pairing_code (family_id);
create index pairing_code_child_id_idx on public.pairing_code (child_id);
create index pairing_code_created_by_idx on public.pairing_code (created_by);
create index pairing_code_expires_at_idx on public.pairing_code (expires_at);

-- Failed and successful redeem attempts, used to stop brute-forcing the 6-digit code space.
create table private.pairing_attempt (
  id           bigint generated always as identity primary key,
  auth_uid     uuid not null,
  success      boolean not null,
  attempted_at timestamptz not null default now()
);
create index pairing_attempt_uid_time_idx on private.pairing_attempt (auth_uid, attempted_at);

-- ---------------------------------------------------------------------------
-- Rules and enforcement
-- ---------------------------------------------------------------------------

-- params examples:
--   daily_limit : {"weekday_minutes": 120, "weekend_minutes": 180}
--   app_limit   : {"package": "com.example.game", "minutes": 30}
--   downtime    : {"start": "21:00", "end": "07:00", "days": [1,2,3,4,5,6,7]}
--   block       : {"package": "com.example.game"}
--   always_allow: {"package": "com.android.dialer"}
--   lock        : {"until": "2026-10-21T18:00:00Z"}
create table public.rule (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.family (id) on delete cascade,
  child_id   uuid not null references public.child (id) on delete cascade,
  type       text not null check (type in ('daily_limit', 'app_limit', 'downtime', 'block', 'always_allow', 'lock')),
  params     jsonb not null default '{}' check (jsonb_typeof(params) = 'object'),
  active     boolean not null default true,
  version    integer not null default 1,   -- bumped on every update; the device pulls the latest
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index rule_family_id_idx on public.rule (family_id);
create index rule_child_id_idx on public.rule (child_id);

-- Aggregated per app per day, not per tap (PRD section 9).
create table public.app_usage (
  device_id          uuid not null references public.device (id) on delete cascade,
  family_id          uuid not null references public.family (id) on delete cascade,
  package            text not null check (char_length(package) <= 255),
  day                date not null,
  foreground_seconds integer not null default 0 check (foreground_seconds between 0 and 86400),
  updated_at         timestamptz not null default now(),
  primary key (device_id, day, package)
);
create index app_usage_family_id_idx on public.app_usage (family_id);
create index app_usage_day_idx on public.app_usage (day);

-- Auto-deleted after 30 days by private.daily_cleanup().
create table public.location_point (
  id          bigint generated always as identity primary key,
  device_id   uuid not null references public.device (id) on delete cascade,
  family_id   uuid not null references public.family (id) on delete cascade,
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  accuracy_m  real check (accuracy_m >= 0),
  recorded_at timestamptz not null,
  created_at  timestamptz not null default now()
);
create index location_point_device_time_idx on public.location_point (device_id, recorded_at desc);
create index location_point_family_id_idx on public.location_point (family_id);
create index location_point_recorded_at_idx on public.location_point (recorded_at);

-- Up to 10 per family (enforced by trigger below).
create table public.geofence (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.family (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 50),
  lat        double precision not null check (lat between -90 and 90),
  lng        double precision not null check (lng between -180 and 180),
  radius_m   integer not null check (radius_m between 50 and 5000),
  created_at timestamptz not null default now()
);
create index geofence_family_id_idx on public.geofence (family_id);

-- ---------------------------------------------------------------------------
-- Alerts, requests, billing, audit
-- ---------------------------------------------------------------------------

-- Written by the backend (edge functions / service role); parents read and mark them read.
create table public.alert (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.family (id) on delete cascade,
  child_id   uuid references public.child (id) on delete cascade,
  type       text not null check (type in (
               'limit_reached', 'new_app', 'permission_revoked', 'uninstall_attempt',
               'geofence_enter', 'geofence_exit', 'low_battery', 'device_offline', 'time_request')),
  payload    jsonb not null default '{}',
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index alert_family_created_idx on public.alert (family_id, created_at desc);
create index alert_child_id_idx on public.alert (child_id);

-- Request-more-time flow (SCR-6). The child device creates it, a guardian approves or denies.
create table public.time_request (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.family (id) on delete cascade,
  child_id     uuid not null references public.child (id) on delete cascade,
  device_id    uuid not null references public.device (id) on delete cascade,
  app          text check (char_length(app) <= 255),   -- package name; null means the daily limit
  minutes      integer not null check (minutes between 1 and 240),
  status       text not null default 'pending' check (status in ('pending', 'approved', 'denied')),
  decided_by   uuid references public.guardian (id) on delete set null,
  requested_at timestamptz not null default now(),
  decided_at   timestamptz
);
create index time_request_family_id_idx on public.time_request (family_id);
create index time_request_child_id_idx on public.time_request (child_id);
create index time_request_device_id_idx on public.time_request (device_id);
create index time_request_decided_by_idx on public.time_request (decided_by);

-- One subscription per family, written only by the billing edge function (Step 7).
create table public.subscription (
  family_id  uuid primary key references public.family (id) on delete cascade,
  store      text not null check (store in ('google_play', 'app_store')),
  product_id text not null,
  status     text not null check (status in ('active', 'in_grace', 'expired', 'canceled')),
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Who changed which rule; visible to every guardian in the family.
create table public.audit_log (
  id        bigint generated always as identity primary key,
  family_id uuid not null references public.family (id) on delete cascade,
  actor     uuid,                           -- auth uid of whoever made the change (null = system)
  action    text not null,
  target    text not null,
  at        timestamptz not null default now()
);
create index audit_log_family_at_idx on public.audit_log (family_id, at desc);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- New parent account -> new family with that parent as owner.
-- Anonymous users are child devices, so they are skipped.
-- The family name from sign-up metadata is only a display label, never used for authorization.
create function private.handle_new_parent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id uuid;
begin
  insert into public.family (name)
  values (coalesce(nullif(trim(new.raw_user_meta_data ->> 'family_name'), ''), 'My family'))
  returning id into v_family_id;

  insert into public.guardian (family_id, auth_uid, role)
  values (v_family_id, new.id, 'owner');
  return new;
end;
$$;

create trigger on_auth_user_created_create_family
  after insert on auth.users
  for each row
  when (new.is_anonymous is not true)
  execute function private.handle_new_parent();

-- Copy family_id from the child row, so clients never send it and can never get it wrong.
create function private.set_family_from_child()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.family_id := (select c.family_id from public.child c where c.id = new.child_id);
  return new;
end;
$$;

-- Same idea for rows that hang off a device.
create function private.set_family_from_device()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.family_id := (select d.family_id from public.device d where d.id = new.device_id);
  return new;
end;
$$;

create trigger rule_set_family before insert on public.rule
  for each row execute function private.set_family_from_child();
create trigger time_request_set_family before insert on public.time_request
  for each row execute function private.set_family_from_child();
create trigger app_usage_set_family before insert on public.app_usage
  for each row execute function private.set_family_from_device();
create trigger location_point_set_family before insert on public.location_point
  for each row execute function private.set_family_from_device();

-- Rules are versioned: every change bumps version so the child app knows to re-sync.
create function private.bump_rule_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.version := old.version + 1;
  new.updated_at := now();
  return new;
end;
$$;

create trigger rule_bump_version before update on public.rule
  for each row execute function private.bump_rule_version();

-- Audit every rule change (PRD: "who changed which rule, visible to both parents").
create function private.audit_rule_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.rule;
begin
  r := coalesce(new, old);
  -- Rules removed because their child (or the whole family) was deleted need no audit row.
  if tg_op = 'DELETE' and not exists (select 1 from public.child c where c.id = r.child_id) then
    return null;
  end if;
  insert into public.audit_log (family_id, actor, action, target)
  values (r.family_id, auth.uid(), 'rule_' || lower(tg_op), r.type || ':' || r.id);
  return null;
end;
$$;

create trigger rule_audit after insert or update or delete on public.rule
  for each row execute function private.audit_rule_change();

-- Last-seen time always comes from the server clock, never the phone's.
create function private.touch_device()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.last_seen_at := now();
  return new;
end;
$$;

create trigger device_touch before update on public.device
  for each row execute function private.touch_device();

create function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger app_usage_touch before update on public.app_usage
  for each row execute function private.touch_updated_at();

-- Max 10 geofences per family (LOC-3). The advisory lock stops two inserts racing past the limit.
create function private.check_geofence_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('geofence:' || new.family_id::text));
  if (select count(*) from public.geofence g where g.family_id = new.family_id) >= 10 then
    raise exception 'A family can have at most 10 places' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger geofence_limit before insert on public.geofence
  for each row execute function private.check_geofence_limit();

-- When a guardian decides a time request, stamp who and when. A decision cannot be changed later.
create function private.stamp_time_request_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if old.status <> 'pending' then
      raise exception 'This request was already decided' using errcode = 'check_violation';
    end if;
    new.decided_at := now();
    new.decided_by := (
      select g.id from public.guardian g
      where g.auth_uid = auth.uid() and g.family_id = new.family_id
    );
  end if;
  return new;
end;
$$;

create trigger time_request_decision before update on public.time_request
  for each row execute function private.stamp_time_request_decision();
