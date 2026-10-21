// redeem_pairing_code: the CHILD's phone enters the 6-digit code shown on the parent's phone.
//
// Before calling, the child app signs in anonymously (supabase.auth.signInAnonymously()).
// That anonymous session is the phone's "device token": after a successful redeem, the
// phone's auth user is linked to exactly one child, and RLS lets it read that child's rules
// and write that child's usage, location and time requests. Unpairing deletes the device row,
// which cuts off that access immediately.
//
// Request:  POST /functions/v1/redeem_pairing_code
//           Authorization: Bearer <phone's anonymous access token>
//           body: { "code": "483920", "model": "Redmi Note 13", "os_version": "14", "app_version": "0.1.0" }
// Response: 200 { "device_id": "...", "child_id": "...", "child_name": "Aarav" }
//           400 bad input / wrong or expired code, 403 not an anonymous phone session,
//           409 already paired, 429 too many wrong codes

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// Map SQL error codes to HTTP status codes.
const STATUS: Record<string, number> = {
  invalid_or_expired: 400,
  not_a_child_device: 403,
  already_paired: 409,
  too_many_attempts: 429,
};

// Keep optional device details short and printable.
function clean(value: unknown, max: number): string | null {
  return typeof value === "string" ? value.replace(/[^\x20-\x7E]/g, "").slice(0, max) || null : null;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return Response.json({ error: "method_not_allowed" }, { status: 405 });
    }

    // Only anonymous phone sessions can become child devices; parent accounts cannot.
    if (ctx.jwtClaims?.is_anonymous !== true) {
      return Response.json({ error: "not_a_child_device" }, { status: 403 });
    }

    const body = await req.json().catch(() => ({}));
    const code = typeof body.code === "string" ? body.code.trim() : "";
    if (!/^[0-9]{6}$/.test(code)) {
      return Response.json({ error: "code must be 6 digits" }, { status: 400 });
    }

    const { data, error } = await ctx.supabaseAdmin.rpc("redeem_pairing_code", {
      p_device_uid: ctx.userClaims!.id,
      p_code: code,
      p_model: clean(body.model, 100),
      p_os_version: clean(body.os_version, 50),
      p_app_version: clean(body.app_version, 50),
    });

    if (error) {
      console.error("redeem_pairing_code failed:", error.code, error.message); // no child data in logs
      return Response.json({ error: "server_error" }, { status: 500 });
    }
    if (!data.ok) {
      return Response.json({ error: data.error }, { status: STATUS[data.error] ?? 500 });
    }

    return Response.json({
      device_id: data.device_id,
      child_id: data.child_id,
      child_name: data.child_name,
    });
  }),
};

/* Try it locally (after `supabase start` and `supabase functions serve`):

  1. Sign in anonymously, as the child app will:
     curl -s -X POST 'http://127.0.0.1:54321/auth/v1/signup' \
       -H "apikey: <publishable key from supabase status>" -H "Content-Type: application/json" -d '{}'

  2. Redeem the code the parent got from create_pairing_code:
     curl -s -X POST 'http://127.0.0.1:54321/functions/v1/redeem_pairing_code' \
       -H "Authorization: Bearer <access_token from step 1>" -H "Content-Type: application/json" \
       -d '{"code":"483920","model":"Redmi Note 13","os_version":"14","app_version":"0.1.0"}'
*/
