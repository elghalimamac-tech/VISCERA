// VISCERA — gestion sensible des comptes. Appels réservés au propriétaire.
import { createClient } from "npm:@supabase/supabase-js@2.78.0";

const OWNER_ID = "4fa3bd1b-6ee1-4b87-97eb-d18527025bc6";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};
const reply = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: cors });
const isUuid = (v: unknown): v is string =>
  typeof v === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply({ error: "server_not_configured" }, 503);
  const authorization = req.headers.get("authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  if (!token) return reply({ error: "unauthorized" }, 401);

  const server = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    const { data: session, error: sessionError } = await server.auth.getUser(token);
    if (sessionError || session.user?.id !== OWNER_ID) {
      return reply({ error: "forbidden" }, 403);
    }
    const { data: principal, error: principalError } = await server
      .from("doctor_profiles")
      .select("is_admin,approval_status,approved_role")
      .eq("user_id", OWNER_ID).maybeSingle();
    if (principalError || principal?.is_admin !== true ||
        principal.approval_status !== "approved" ||
        !["junior", "senior"].includes(principal.approved_role)) {
      return reply({ error: "forbidden" }, 403);
    }

    const body: Record<string, unknown> = await req.json().catch(() => ({}));
    const targetId = body.target_id;
    const action = body.action;
    if (!isUuid(targetId) || targetId === OWNER_ID) {
      return reply({ error: "protected_or_invalid_account" }, 403);
    }
    if (!["delete", "set_password", "set_admin"].includes(String(action))) {
      return reply({ error: "unknown_action" }, 400);
    }
    const { data: found, error: foundError } = await server.auth.admin.getUserById(targetId);
    if (foundError || !found.user) return reply({ error: "account_not_found" }, 404);

    if (action === "set_admin") {
      if (typeof body.is_admin !== "boolean") {
        return reply({ error: "invalid_admin_value" }, 400);
      }
      const { data: profile, error: profileError } = await server
        .from("doctor_profiles")
        .select("approval_status,approved_role,is_admin")
        .eq("user_id", targetId).maybeSingle();
      if (profileError || !profile ||
          (body.is_admin && (profile.approval_status !== "approved" ||
            !["junior", "senior"].includes(profile.approved_role)))) {
        return reply({ error: "approve_doctor_before_admin_grant" }, 409);
      }
      const { data: changed, error: updateError } = await server
        .from("doctor_profiles").update({ is_admin: body.is_admin })
        .eq("user_id", targetId).select("user_id").maybeSingle();
      if (updateError || !changed) return reply({ error: "admin_update_failed" }, 503);
      return reply({ success: true, is_admin: body.is_admin });
    }

    if (action === "set_password") {
      const password = body.password;
      if (typeof password !== "string" || password.length < 12 ||
          password.length > 128 || password.trim() !== password) {
        return reply({ error: "password_policy", minimum: 12 }, 400);
      }
      const { error } = await server.auth.admin.updateUserById(
        targetId, { password },
      );
      if (error) return reply({ error: "password_update_failed" }, 503);
      return reply({ success: true });
    }

    // Suppression physique des comptes Auth (sessions et profils cascades).
    // Ne jamais effacer les dossiers patients liés pour faciliter cette action.
    if (body.confirmation !== "SUPPRIMER") {
      return reply({ error: "confirmation_required" }, 400);
    }
    const checks = [
      server.from("bloc_patient_records").select("*", { head: true, count: "exact" })
        .eq("updated_by", targetId),
      server.from("manual_patient_records").select("*", { head: true, count: "exact" })
        .or("created_by.eq." + targetId + ",updated_by.eq." + targetId),
      server.from("manual_bloc_links").select("*", { head: true, count: "exact" })
        .eq("linked_by", targetId),
    ];
    const results = await Promise.all(checks);
    if (results.some((r) => r.error)) {
      return reply({ error: "clinical_dependency_check_failed" }, 503);
    }
    if (results.some((r) => (r.count ?? 0) > 0)) {
      return reply({ error: "clinical_history_protected" }, 409);
    }
    const { error: deleteError } = await server.auth.admin.deleteUser(targetId, false);
    if (deleteError) return reply({ error: "delete_blocked_by_dependencies" }, 409);
    return reply({ success: true, deleted: true });
  } catch {
    return reply({ error: "internal_error" }, 500);
  }
});
