// create_pairing_code: a signed-in PARENT asks for a 6-digit code to pair a child's phone.
//
// Request:  POST /functions/v1/create_pairing_code
//           Authorization: Bearer <parent's access token>
//           body: { "child_id": "<uuid>" }
// Response: 200 { "code": "483920", "expires_at": "2026-10-21T10:10:00Z" }
//           400 bad input, 403 not a parent, 404 child not in your family
//
// The actual work (permission check, random code, 10-minute expiry, single live code per child)
// happens in the SQL function public.create_pairing_code, which only the service role may call.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default {
  // auth: "user" = the caller must send a valid Supabase user access token.
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return Response.json({ error: "method_not_allowed" }, { status: 405 });
    }

    // Child phones sign in anonymously; they must never be able to create codes.
    if (ctx.jwtClaims?.is_anonymous === true) {
      return Response.json({ error: "parents_only" }, { status: 403 });
    }

    const body = await req.json().catch(() => ({}));
    const childId = typeof body.child_id === "string" ? body.child_id : "";
    if (!UUID.test(childId)) {
      return Response.json({ error: "child_id must be a uuid" }, { status: 400 });
    }

    // Pass the VERIFIED user id from the token, never an id from the request body.
    const { data, error } = await ctx.supabaseAdmin.rpc("create_pairing_code", {
      p_guardian_uid: ctx.userClaims!.id,
      p_child_id: childId,
    });

    if (error) {
      console.error("create_pairing_code failed:", error.code, error.message); // no child data in logs
      return Response.json({ error: "server_error" }, { status: 500 });
    }
    if (!data.ok) {
      const status = data.error === "child_not_found" ? 404 : 500;
      return Response.json({ error: data.error }, { status });
    }

    return Response.json({ code: data.code, expires_at: data.expires_at });
  }),
};

/* Try it locally (after `supabase start` and `supabase functions serve`):

  1. Sign in as the seeded parent to get an access token:
     curl -s -X POST 'http://127.0.0.1:54321/auth/v1/token?grant_type=password' \
       -H "apikey: <publishable key from supabase status>" -H "Content-Type: application/json" \
       -d '{"email":"priya@example.com","password":"password123"}'

  2. Ask for a code for Meera (seeded, not yet paired):
     curl -s -X POST 'http://127.0.0.1:54321/functions/v1/create_pairing_code' \
       -H "Authorization: Bearer <access_token from step 1>" -H "Content-Type: application/json" \
       -d '{"child_id":"11111111-1111-4111-8111-1111111111c2"}'
*/
