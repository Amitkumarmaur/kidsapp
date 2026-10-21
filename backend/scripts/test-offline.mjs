// Offline test runner: checks the migrations, seed and pgTAP tests WITHOUT Docker.
//
// It runs real Postgres (PGlite, Postgres compiled to WebAssembly) in memory and adds small
// stand-ins for the Supabase pieces PGlite lacks: the auth schema and roles, pg_cron, and the
// handful of pgTAP functions our tests use. It is a fast safety net, not a replacement for
// `supabase test db`, which runs the same test files on a real Supabase database.
//
// Usage (from the backend/scripts folder):
//   npm install
//   npm test

import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const supabaseDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'supabase');
const migrationsDir = path.join(supabaseDir, 'migrations');
const testsDir = path.join(supabaseDir, 'tests', 'database');
const seedFile = path.join(supabaseDir, 'seed.sql');

// Stand-ins for what a Supabase database already has.
const SUPABASE_SHIM = `
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users (
  id uuid primary key, instance_id uuid, aud text, role text, email text, encrypted_password text,
  email_confirmed_at timestamptz, raw_app_meta_data jsonb default '{}', raw_user_meta_data jsonb default '{}',
  is_anonymous boolean not null default false, confirmation_token text, recovery_token text,
  email_change_token_new text, email_change text, created_at timestamptz default now(), updated_at timestamptz default now()
);
create table auth.identities (
  id uuid primary key, user_id uuid references auth.users (id), provider_id text, identity_data jsonb,
  provider text, last_sign_in_at timestamptz, created_at timestamptz, updated_at timestamptz
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid $$;
grant usage on schema auth, extensions, public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create schema cron;
create table cron.job (jobname text primary key, schedule text, command text);
create function cron.schedule(text, text, text) returns bigint language sql as $$
  insert into cron.job values ($1, $2, $3)
  on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command;
  select 1::bigint $$;

-- Minimal pgTAP: plan, ok, is, is_empty, lives_ok, throws_ok, finish.
create table extensions.tap_result (n serial primary key, ok boolean, description text, detail text);
create table extensions.tap_plan (planned int);
create function extensions.tap_record(boolean, text, text default null) returns text
language plpgsql security definer as $$
begin
  insert into extensions.tap_result (ok, description, detail) values (coalesce($1, false), $2, $3);
  return $2;
end $$;
create function extensions.plan(int) returns text language plpgsql security definer as $$
begin insert into extensions.tap_plan values ($1); return '1..' || $1; end $$;
create function extensions.ok(boolean, text) returns text language sql as $$ select extensions.tap_record($1, $2) $$;
create function extensions.is(anyelement, anyelement, text) returns text language sql as $$
  select extensions.tap_record($1 is not distinct from $2, $3,
    'got ' || coalesce($1::text, 'NULL') || ', expected ' || coalesce($2::text, 'NULL')) $$;
create function extensions.is_empty(text, text) returns text language plpgsql as $$
declare r record; n int := 0;
begin
  for r in execute $1 loop n := n + 1; end loop;
  return extensions.tap_record(n = 0, $2, n || ' row(s) returned');
end $$;
create function extensions.lives_ok(text, text) returns text language plpgsql as $$
begin
  execute $1;
  return extensions.tap_record(true, $2);
exception when others then
  return extensions.tap_record(false, $2, sqlstate || ' ' || sqlerrm);
end $$;
create function extensions.throws_ok(text, text, text, text) returns text language plpgsql as $$
begin
  execute $1;
  return extensions.tap_record(false, $4, 'no error was raised');
exception when others then
  return extensions.tap_record(sqlstate = $2, $4, 'got ' || sqlstate || ' ' || sqlerrm);
end $$;
create function extensions.finish() returns setof text language sql as $$ select 'done'::text $$;
grant all on all tables in schema extensions to public;
grant all on all sequences in schema extensions to public;
`;

// Remove statements that only work on a real Supabase database.
function adapt(sql) {
  return sql
    .replace(/create extension if not exists pg_cron[^;]*;/gi, '')
    .replace(/grant usage on schema cron to postgres;/gi, '')
    .replace(/grant all privileges on all tables in schema cron to postgres;/gi, '')
    .replace(/create extension if not exists pgtap[^;]*;/gi, '');
}

const sqlFiles = (dir) => fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();

// A fresh database with all migrations and the seed applied, like `supabase db reset`.
async function freshDatabase() {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec('create schema extensions; create extension pgcrypto with schema extensions;');
  await db.exec(SUPABASE_SHIM);
  await db.exec('set search_path = public, extensions');
  for (const file of sqlFiles(migrationsDir)) {
    try {
      await db.exec(adapt(fs.readFileSync(path.join(migrationsDir, file), 'utf8')));
    } catch (e) {
      throw new Error(`migration ${file} failed: ${e.message}`);
    }
  }
  try {
    await db.exec(fs.readFileSync(seedFile, 'utf8'));
  } catch (e) {
    throw new Error(`seed.sql failed: ${e.message}`);
  }
  return db;
}

let failures = 0;
console.log(`Migrations: ${sqlFiles(migrationsDir).join(', ')}`);

for (const file of sqlFiles(testsDir)) {
  console.log(`\n${file}`);
  const db = await freshDatabase();
  // Keep the test's transaction open so we can read the results before rolling back.
  const testSql = adapt(fs.readFileSync(path.join(testsDir, file), 'utf8')).replace(/rollback;\s*$/i, '');
  try {
    await db.exec(testSql);
  } catch (e) {
    console.log(`  ERROR while running the file: ${e.message}`);
    failures++;
  }
  await db.exec('reset role');
  const results = (await db.query('select n, ok, description, detail from extensions.tap_result order by n')).rows;
  const planned = (await db.query('select planned from extensions.tap_plan')).rows[0]?.planned;
  for (const r of results) {
    console.log(`  ${r.ok ? 'ok    ' : 'FAILED'} ${r.n} - ${r.description}${r.ok ? '' : `  (${r.detail})`}`);
    if (!r.ok) failures++;
  }
  if (planned !== results.length) {
    console.log(`  PLAN MISMATCH: plan(${planned}) but ${results.length} tests ran`);
    failures++;
  }
  await db.close();
}

console.log(failures ? `\n${failures} problem(s) found` : '\nAll tests passed');
process.exit(failures ? 1 : 0);
