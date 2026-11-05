// VISCERA — notification transactionnelle après approbation réelle par l'admin.
// Secrets BREVO_* et SUPABASE_SERVICE_ROLE_KEY exclusivement sur le serveur.
import { createClient } from "npm:@supabase/supabase-js@2.78.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const OWNER_ID = "4fa3bd1b-6ee1-4b87-97eb-d18527025bc6";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const reply = (data: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: cors });
const isUuid = (s: unknown) => typeof s === "string"
  && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
const escapeHtml = (s: string) => s.replace(/[&<>"']/g, (ch) =>
  ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"} as Record<string,string>)[ch]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return reply({ error: "server_not_configured" }, 503);
  }
  const bearer = req.headers.get("authorization") ?? "";
  const token = bearer.startsWith("Bearer ") ? bearer.substring(7) : "";
  if (!token) return reply({ error: "unauthorized" }, 401);
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    // Vérification du JWT côté serveur ET de l'approbation admin en base.
    const { data: auth, error: authError } = await admin.auth.getUser(token);
    if (authError || !auth.user || auth.user.id !== OWNER_ID) {
      return reply({ error: "forbidden" }, 403);
    }
    const { data: owner, error: ownerError } = await admin.from("doctor_profiles")
      .select("is_admin, approval_status, approved_role")
      .eq("user_id", auth.user.id).maybeSingle();
    if (ownerError || owner?.is_admin !== true ||
        owner?.approval_status !== "approved" ||
        !["junior","senior"].includes(owner?.approved_role)) {
      return reply({ error: "forbidden" }, 403);
    }
    const body = await req.json().catch(() => ({}));
    const targetId = (body as {target_id?: unknown}).target_id;
    if (!isUuid(targetId) || targetId === OWNER_ID) {
      return reply({ error: "invalid_target" }, 400);
    }
    const { data: target, error: targetError } = await admin.from("doctor_profiles")
      .select("display_name, approval_status, approved_role, is_admin")
      .eq("user_id", targetId).maybeSingle();
    if (targetError || !target || target.is_admin === true ||
        target.approval_status !== "approved" ||
        !["junior","senior"].includes(target.approved_role)) {
      return reply({ error: "target_not_approved" }, 409);
    }
    const { data: jobs, error: jobsError } = await admin
      .from("viscera_approval_email_jobs")
      .select("id, status, attempt_count, started_at")
      .eq("user_id", targetId).order("created_at", {ascending: false}).limit(10);
    if (jobsError) return reply({ error: "queue_unavailable" }, 503);
    let job = (jobs ?? []).find((j) => j.status === "pending");
    if (!job) {
      const stale = (jobs ?? []).find((j) => j.status === "sending" &&
        j.started_at && Date.now() - Date.parse(j.started_at) > 120000);
      if (stale) {
        const { error: resetError } = await admin.from("viscera_approval_email_jobs")
          .update({ status:"pending" }).eq("id", stale.id).eq("status","sending");
        if (resetError) return reply({ error:"queue_unavailable" }, 503);
        job = { ...stale, status:"pending" };
      }
    }
    if (!job) {
      const hasActive = (jobs ?? []).some((j) => j.status === "sending");
      return reply({ sent: false, already_sent: !hasActive, processing: hasActive });
    }

    const brevoKey = Deno.env.get("BREVO_API_KEY");
    const senderEmail = Deno.env.get("BREVO_SENDER_EMAIL");
    const senderName = Deno.env.get("BREVO_SENDER_NAME") || "VISCERA";
    if (!brevoKey || !senderEmail) {
      return reply({ error: "brevo_not_configured" }, 503);
    }

    const { data: claim, error: claimError } = await admin
      .from("viscera_approval_email_jobs")
      .update({ status:"sending", started_at:new Date().toISOString(),
        attempt_count:Number(job.attempt_count)+1, last_error:null })
      .eq("id",job.id).eq("status","pending").select("id").maybeSingle();
    if (claimError) return reply({error:"queue_unavailable"},503);
    if (!claim) return reply({ sent:false, processing:true }, 200);

    try {
      // Utile pour les comptes créés avant la désactivation de
      // Confirm Email : une approbation admin remplace le clic mail.
      const { data: userResult, error: userError } =
        await admin.auth.admin.getUserById(targetId as string);
      if (userError || !userResult.user?.email) throw Error("target_email_unavailable");
      if (!userResult.user.email_confirmed_at) {
        const { error: confirmError } = await admin.auth.admin
          .updateUserById(targetId as string, { email_confirm: true });
        if (confirmError) throw Error("admin_email_activation_failed");
      }
      const recipient = userResult.user.email;
      const doctorName = (target.display_name as string) || "Docteur";
      const safeName = escapeHtml(doctorName);
      const html = `<!doctype html><html lang="fr"><head><meta charset="UTF-8"></head>
      <body style="background:#f5fafb;font-family:Arial,sans-serif;padding:24px;color:#083b46">
      <div style="max-width:560px;margin:auto;background:white;padding:32px;border-radius:16px;border:1px solid #dce8eb">
      <h1 style="margin:0 0 20px;color:#083b46">VISCERA</h1>
      <p>Bonjour ${safeName},</p>
      <h2 style="font-size:22px">Votre compte a été validé.</h2>
      <p>Un administrateur a approuvé votre inscription à VISCERA.</p>
      <p>Vous pouvez maintenant vous connecter avec votre adresse e-mail et votre mot de passe habituels.</p>
      <p style="margin-top:24px"><a href="https://elghalimamac-tech.github.io/VISCERA/"
      style="display:inline-block;padding:13px 20px;background:#083b46;color:white;text-decoration:none;border-radius:9px">
      Accéder à VISCERA</a></p>
      <p style="margin-top:30px;color:#617a80;font-size:12px">VISCERA · Chirurgie viscérale · Accès professionnel</p>
      </div></body></html>`;
      const res = await fetch("https://api.brevo.com/v3/smtp/email", {
        method:"POST",
        headers: { "api-key":brevoKey, "accept":"application/json", "content-type":"application/json" },
        body: JSON.stringify({
          sender: { name:senderName,email:senderEmail },
          to:[{ email:recipient, name:doctorName }],
          subject:"VISCERA — Votre compte a été validé",
          htmlContent:html,
          tags:["viscera","approbation-admin"],
        }),
      });
      if (!res.ok) throw Error("brevo_http_"+res.status);
      const sent = await res.json();
      const { error: finishError } = await admin.from("viscera_approval_email_jobs")
        .update({status:"sent",sent_at:new Date().toISOString(),
          brevo_message_id:typeof sent.messageId === "string" ? sent.messageId : null,
          last_error:null}).eq("id",job.id).eq("status","sending");
      if (finishError) throw Error("queue_finish_failed");
      return reply({ sent:true });
    } catch (e) {
      const err = e instanceof Error ? e.message.slice(0,120) : "mail_error";
      await admin.from("viscera_approval_email_jobs")
        .update({ status:"pending",last_error:err,started_at:null })
        .eq("id",job.id).eq("status","sending");
      return reply({ error:"email_not_sent", retryable:true },502);
    }
  } catch (_) {
    return reply({ error:"internal_error" },500);
  }
});
