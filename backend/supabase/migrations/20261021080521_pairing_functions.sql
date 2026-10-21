-- Pairing: 6-digit codes, 10-minute expiry, single use (ACC-3).
--
-- These functions are called ONLY by the edge functions create_pairing_code and
-- redeem_pairing_code, using the service role. Apps cannot call them directly
-- (execute is revoked from anon and authenticated), so the edge functions stay the only door.
-- The edge function passes in the caller's verified auth uid.

-- Make a fresh code for a child. Any older unused code for the same child is replaced.
create function public.create_pairing_code(p_guardian_uid uuid, p_child_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_guardian_id uuid;
  v_family_id   uuid;
  v_code        text;
  v_expires_at  timestamptz;
begin
  -- The caller must be a guardian in the child's family.
  select g.id, c.family_id into v_guardian_id, v_family_id
  from public.child c
  join public.guardian g on g.family_id = c.family_id
  where c.id = p_child_id and g.auth_uid = p_guardian_uid;

  if v_guardian_id is null then
    return jsonb_build_object('ok', false, 'error', 'child_not_found');
  end if;

  -- Free up numbers held by expired codes, and drop this child's previous unused code.
  delete from public.pairing_code pc
  where pc.used_at is null
    and (pc.expires_at < now() or pc.child_id = p_child_id);

  -- Pick a random 6-digit number. gen_random_uuid() uses a cryptographically strong
  -- random source; we take 31 random bits from it. Retry if the number is already live.
  for attempt in 1..10 loop
    v_code := lpad(
      ((('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::int & 2147483647) % 1000000)::text,
      6, '0');
    begin
      insert into public.pairing_code (code, family_id, child_id, created_by)
      values (v_code, v_family_id, p_child_id, v_guardian_id)
      returning expires_at into v_expires_at;

      return jsonb_build_object('ok', true, 'code', v_code, 'expires_at', v_expires_at);
    exception when unique_violation then
      -- Another family holds this number right now; try a different one.
    end;
  end loop;

  return jsonb_build_object('ok', false, 'error', 'could_not_generate_code');
end;
$$;

-- Redeem a code from a child phone. On success the phone's anonymous auth user
-- becomes a device of that child.
create function public.redeem_pairing_code(
  p_device_uid  uuid,
  p_code        text,
  p_model       text default null,
  p_os_version  text default null,
  p_app_version text default null
)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_failed     integer;
  v_family_id  uuid;
  v_child_id   uuid;
  v_device_id  uuid;
  v_child_name text;
begin
  -- Brute-force guard: 5 wrong codes within 10 minutes blocks this phone for a while.
  select count(*) into v_failed
  from private.pairing_attempt a
  where a.auth_uid = p_device_uid
    and not a.success
    and a.attempted_at > now() - interval '10 minutes';

  if v_failed >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;

  -- A parent account can never be turned into a child device.
  if exists (select 1 from public.guardian g where g.auth_uid = p_device_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_a_child_device');
  end if;

  if exists (select 1 from public.device d where d.auth_uid = p_device_uid) then
    return jsonb_build_object('ok', false, 'error', 'already_paired');
  end if;

  -- Claim the code in one statement. If two phones race, only one UPDATE matches the row.
  update public.pairing_code pc
  set used_at = now(), used_by = p_device_uid
  where pc.code = p_code
    and pc.used_at is null
    and pc.expires_at > now()
  returning pc.family_id, pc.child_id into v_family_id, v_child_id;

  if v_child_id is null then
    insert into private.pairing_attempt (auth_uid, success) values (p_device_uid, false);
    -- Same answer for wrong, used and expired codes, so attackers learn nothing.
    return jsonb_build_object('ok', false, 'error', 'invalid_or_expired');
  end if;

  insert into public.device (family_id, child_id, auth_uid, model, os_version, app_version, last_seen_at)
  values (v_family_id, v_child_id, p_device_uid, p_model, p_os_version, p_app_version, now())
  returning id into v_device_id;

  insert into private.pairing_attempt (auth_uid, success) values (p_device_uid, true);

  -- The free trial starts at the first pairing, not at install (PRD section 11).
  update public.family f
  set trial_ends_at = now() + interval '3 days'
  where f.id = v_family_id and f.trial_ends_at is null;

  select c.name into v_child_name from public.child c where c.id = v_child_id;

  return jsonb_build_object(
    'ok', true,
    'device_id', v_device_id,
    'child_id', v_child_id,
    'child_name', v_child_name
  );
end;
$$;

-- Only the service role (edge functions) may call these.
revoke all on function public.create_pairing_code(uuid, uuid) from public, anon, authenticated;
revoke all on function public.redeem_pairing_code(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.create_pairing_code(uuid, uuid) to service_role;
grant execute on function public.redeem_pairing_code(uuid, text, text, text, text) to service_role;
