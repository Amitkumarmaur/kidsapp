# KidGuard backend (Supabase)

Step 1 of the build plan: database schema, row-level security, pairing, and the daily cleanup job.

## What's here

| Path | What it does |
| --- | --- |
| `supabase/migrations/…_schema.sql` | The 13 tables from PRD section 9, plus foreign keys, indexes and triggers |
| `supabase/migrations/…_rls_policies.sql` | Row-level security: each family sees only its own rows; a child phone writes only its own child's usage, location and time requests |
| `supabase/migrations/…_pairing_functions.sql` | SQL behind pairing: 6-digit codes, 10-minute expiry, single use, brute-force lockout |
| `supabase/migrations/…_daily_cleanup.sql` | `pg_cron` job at 03:00 UTC that deletes location points older than 30 days and usage older than 12 months |
| `supabase/functions/create_pairing_code` | Edge function: a parent gets a code for a child |
| `supabase/functions/redeem_pairing_code` | Edge function: the child's phone enters the code and becomes that child's device |
| `supabase/seed.sql` | Demo data for local development only (2 families, 3 children, 2 paired phones) |
| `supabase/tests/database/*.test.sql` | pgTAP tests (62 checks), including "family A cannot read family B" |
| `scripts/test-offline.mjs` | Runs the same tests without Docker, using in-memory Postgres |

## How it works (short version)

- **Parents** sign up with Supabase Auth. A trigger creates their family automatically, with them as owner.
- **Child phones** never get a login. The child app calls `signInAnonymously()`, then sends the 6-digit code to `redeem_pairing_code`. On success, that anonymous user is linked to exactly one child in the `device` table. This session is the "device token" from PRD section 8.
- **Unpair** means deleting the `device` row. From then on, the phone's session can't read or write anything.
- **RLS helpers** (`private.my_family_ids()`, `private.my_device_id()`, and so on) answer "who is calling?". They live in the `private` schema, which the API doesn't expose.
- **Clients never send `family_id`** for rules, usage, location or time requests. A trigger copies it from the child or device, so a client can't put a wrong one in.
- **Columns clients may never write:** a family's plan and trial dates, alerts and subscriptions. Only the backend (service role) can write these.
- **Brute-force protection:** a phone that enters 5 wrong codes within 10 minutes is locked out of pairing. Wrong, used and expired codes all return the same error.
- **Trial:** it starts when the first child phone is paired, not when the app is installed (PRD section 11).

## Option A: test right now, without Docker

```powershell
cd "D:\app for kids\backend\scripts"
npm install
npm test
```
You should see `All tests passed` (38 isolation checks and 24 pairing and job checks).

## Option B: run Supabase locally (needs Docker Desktop)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and start it.
2. Run:
   ```powershell
   cd "D:\app for kids\backend"
   supabase start          # first run downloads images, ~5-10 min
   supabase db reset       # applies migrations + seed.sql
   supabase test db        # runs the pgTAP tests -> should end with "Result: PASS"
   ```
3. Open Studio at http://127.0.0.1:54323 to browse the tables. Run `supabase status` to see the API URL and keys.
4. Try the edge functions:
   ```powershell
   supabase functions serve
   ```
   Then follow the `curl` steps at the bottom of each `index.ts`:
   - sign in as `priya@example.com` / `password123`
   - create a code for Meera (`11111111-1111-4111-8111-1111111111c2`)
   - sign in anonymously
   - redeem the code

## Option C: apply to your cloud project

```powershell
cd "D:\app for kids\backend"
supabase login
supabase link --project-ref mzhpsunicbgerqyztgcf
supabase db push --dry-run          # check which migrations will run
supabase db push                    # apply them (seed.sql is NOT applied to the cloud)
supabase functions deploy create_pairing_code redeem_pairing_code --use-api
```

Then, in the Supabase dashboard:
- **Authentication → Sign In / Providers → Allow anonymous sign-ins: ON.** This is required for child phones.
- Optional but recommended before launch: under **Authentication → Attack Protection**, turn on CAPTCHA to slow down mass anonymous sign-ups.
- **Integrations → Cron:** check that the job `kidguard-daily-cleanup` is listed.

To run the tests against the cloud database, use `supabase test db --linked`. The tests run inside a transaction and roll back, so they leave no data behind.

## What "done" looks like (from the build plan)

- [x] SQL tests prove family A can't read family B's data (`01_family_isolation.test.sql`)
- [x] A pairing code works once and expires (`02_pairing_and_jobs.test.sql`)

## Not in this step

Push notifications, Realtime for rule sync, alert creation and billing webhooks come in Steps 4–7.
