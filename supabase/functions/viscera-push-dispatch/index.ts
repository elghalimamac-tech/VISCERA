import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";
import { JWT } from "npm:google-auth-library@9.15.1";

// Worker serveur uniquement. Ne jamais exposer la clé Firebase dans Flutter.
// À invoquer par un ordonnanceur avec Authorization: Bearer <service_role>.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", {status:405});
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const projectUrl = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !projectUrl) return new Response("Server not configured", {status:503});
  if (req.headers.get("Authorization") !== "Bearer " + serviceKey) {
    return new Response("Forbidden", {status:403});
  }
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
