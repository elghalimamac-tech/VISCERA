import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createRemoteJWKSet, jwtVerify } from "jsr:@panva/jose@6";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";
import { JWT } from "npm:google-auth-library@9.15.1";

// Worker serveur uniquement. Ne jamais exposer la clé Firebase dans Flutter.
// À invoquer par un ordonnanceur avec Authorization: Bearer <service_role>.
/**
 * Autorise exclusivement une clé de service du projet, jamais une clé
 * publishable ni un JWT utilisateur. Supabase expose les nouvelles clés
 * secrètes dans SUPABASE_SECRET_KEYS (objet JSON nommé).
 * Compatible avec l'ancien service_role pendant la transition.
 */

/**
 * Authentifie uniquement le workflow GitHub officiel sur la branche main.
 * Le jeton OIDC a une courte durée de vie ; aucun secret Supabase dans GitHub.
 */
const GITHUB_OIDC_AUDIENCE = "viscera:notifications:qkupckqgczdqiwxozxko";
const githubKeys = createRemoteJWKSet(
  new URL("https://token.actions.githubusercontent.com/.well-known/jwks"),
);

async function verifiedGithubWorkflow(req: Request): Promise<boolean> {
  const auth = req.headers.get("Authorization");
  const token = auth?.match(/^Bearer\s+([^\s]+)$/i)?.[1];
  if (!token || token.length > 8192) return false;
  try {
    const { payload } = await jwtVerify(token, githubKeys, {
      issuer: "https://token.actions.githubusercontent.com",
      audience: GITHUB_OIDC_AUDIENCE,
      algorithms: ["RS256"],
      clockTolerance: "20s",
    });
    return payload.sub ===
        "repo:elghalimamac-tech/VISCERA:ref:refs/heads/main" &&
      payload.repository === "elghalimamac-tech/VISCERA" &&
      String(payload.repository_id) === "1440712478" &&
      payload.ref === "refs/heads/main" &&
      payload.workflow_ref ===
        "elghalimamac-tech/VISCERA/.github/workflows/viscera-daily-discharge-push.yml@refs/heads/main" &&
      ["schedule", "workflow_dispatch", "push"].includes(
        String(payload.event_name),
      );
  } catch {
    return false;
  }
}

/**
 * Choisit exclusivement une clé serveur, depuis l'environnement SUPABASE.
 * Compatible service_role legacy, secret sb_secret_, ou un jeton signé GitHub.
 */
async function trustedServiceKey(request: Request): Promise<string | null> {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  let namedSecret: string | undefined;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    if (typeof keys?.default === "string") namedSecret = keys.default;
  } catch (_) {
    // Les anciens projets restent compatibles avec SUPABASE_SERVICE_ROLE_KEY.
  }
  const fromApiKey = request.headers.get("apikey");
  const fromBearer = request.headers.get("Authorization")
    ?.match(/^Bearer\s+([^\s]+)$/i)?.[1];
  const received = fromApiKey || fromBearer;
  if (legacy && received === legacy) return legacy;
  if (namedSecret && received === namedSecret) return namedSecret;
  if (await verifiedGithubWorkflow(request)) return namedSecret || legacy || null;
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", {status:405});
  const serviceKey = await trustedServiceKey(req);
  if (!serviceKey) return new Response("Forbidden", {status:403});
  const projectUrl = Deno.env.get("SUPABASE_URL");
  if (!projectUrl) return new Response("Server not configured", {status:503});
  const serviceAccountText = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountText) return new Response(
    JSON.stringify({error:"firebase_admin_secret_missing"}), {status:503,
      headers:{"content-type":"application/json"}});
  let serviceAccount: {client_email:string;private_key:string;project_id:string};
  try {
    serviceAccount = JSON.parse(serviceAccountText);
    if (!serviceAccount.client_email || !serviceAccount.private_key || !serviceAccount.project_id) {
      throw new Error("Missing fields");
    }
  } catch (_) {
    return new Response("Invalid Firebase server configuration", {status:503});
  }

  const admin = createClient(projectUrl, serviceKey, {
    auth: {autoRefreshToken:false, persistSession:false},
  });
  const now = new Date().toISOString();
  // Un worker interrompu ne doit pas bloquer définitivement une alerte.
  await admin.from("viscera_notifications").update({dispatch_status:"retry"})
    .eq("dispatch_status","sending").lt("next_attempt_at",now);
  const {data:items,error} = await admin.from("viscera_notifications")
    .select("id,user_id,kind,title,body,dispatch_status,attempts")
    .in("dispatch_status",["pending","retry","waiting_device"])
    .is("dismissed_at",null)
    .lte("next_attempt_at",now)
    .order("created_at",{ascending:true}).limit(40);
  if (error) return new Response("Queue unavailable", {status:503});

  const jwt = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes:["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const accessToken = (await jwt.getAccessToken()).token;
  if (!accessToken) return new Response("FCM authorization unavailable", {status:503});

  let sent = 0;
  let retried = 0;
  for (const item of items || []) {
    const due = new Date(Date.now() + 5*60000).toISOString();
    const {data:claimed,error:claimError} = await admin.from("viscera_notifications")
      .update({dispatch_status:"sending",next_attempt_at:due,attempts:item.attempts+1})
      .eq("id",item.id).eq("dispatch_status",item.dispatch_status)
      .is("dismissed_at",null)
      .select("id");
    if (claimError || !claimed || claimed.length !== 1) continue;

    const {data:devices} = await admin.from("push_devices")
      .select("token").eq("user_id",item.user_id);
    if (!devices || devices.length === 0) {
      // Le message reste dans la boîte, et sera envoyé si le médecin active FCM.
      await admin.from("viscera_notifications").update({
        dispatch_status:"waiting_device",
        next_attempt_at:new Date(Date.now()+60*60000).toISOString(),
        attempts:item.attempts,
      }).eq("id",item.id);
      continue;
    }

    let allOk = true;
    for (const device of devices) {
      try {
        const response = await fetch(
          "https://fcm.googleapis.com/v1/projects/" + serviceAccount.project_id + "/messages:send",
          {method:"POST",headers:{"authorization":"Bearer "+accessToken,
            "content-type":"application/json"},body:JSON.stringify({message:{
              token:device.token,
              notification:{title:item.title,body:item.body},
              data:{kind:item.kind,notification_id:item.id},
              android:{priority:item.kind==="urgent_admissions"?"high":"normal"},
            }})},
        );
        if (!response.ok) allOk = false;
      } catch (_) {
        allOk = false;
      }
    }
    if (allOk) {
      sent++;
      await admin.from("viscera_notifications").update({
        dispatch_status:"sent",delivered_at:new Date().toISOString(),
      }).eq("id",item.id);
    } else {
      retried++;
      await admin.from("viscera_notifications").update({
        dispatch_status:item.attempts >= 4 ? "failed" : "retry",
        next_attempt_at:new Date(Date.now() + 15*60000).toISOString(),
      }).eq("id",item.id);
    }
  }
  return Response.json({processed:(items || []).length,sent,retried});
});
