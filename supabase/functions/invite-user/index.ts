// Invites a staff member (admin only).
//
// The service-role key never leaves the server: the app calls this function
// with the signed-in user's JWT, the function checks that the caller is an
// active administrator (via the `is_admin()` SQL function) and only then uses
// the service role to create the account.
//
// Body: { email: string, full_name: string, role?: "staff" | "admin", password?: string }
//   - without `password`: sends an invitation e-mail (requires SMTP).
//   - with `password`: creates a confirmed account with that temporary password
//     (useful for local development or when e-mail is not configured).
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json(401, { error: "unauthorized" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1. Who is calling? Use their own JWT so RLS / is_admin() apply.
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: isAdmin, error: adminError } = await caller.rpc("is_admin");
  if (adminError) return json(401, { error: "unauthorized" });
  if (!isAdmin) return json(403, { error: "forbidden" });

  // 2. Validate input.
  let body: { email?: string; full_name?: string; role?: string; password?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const email = (body.email ?? "").trim().toLowerCase();
  const fullName = (body.full_name ?? "").trim();
  const role = body.role === "admin" ? "admin" : "staff";
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || fullName.length === 0 || fullName.length > 120) {
    return json(400, { error: "invalid_input" });
  }
  if (body.password !== undefined && body.password.length < 8) {
    return json(400, { error: "weak_password" });
  }

  // 3. Create the account with the service role.
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const result = body.password
    ? await admin.auth.admin.createUser({
      email,
      password: body.password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    })
    : await admin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName },
      redirectTo: Deno.env.get("SANAD_AUTH_REDIRECT_URL") ?? undefined,
    });

  if (result.error || !result.data.user) {
    const message = result.error?.message?.toLowerCase() ?? "";
    if (message.includes("already") || result.error?.status === 422) return json(409, { error: "already_exists" });
    // Never echo internal error details to the client.
    console.error("invite-user failed", result.error?.status);
    return json(500, { error: "invite_failed" });
  }

  // The profile row is created by the on_auth_user_created trigger as staff.
  if (role === "admin") {
    const { error } = await admin.from("profiles").update({ role: "admin" }).eq("id", result.data.user.id);
    if (error) return json(500, { error: "role_update_failed" });
  }

  return json(200, { id: result.data.user.id, email, role });
});
