import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";

/**
 * Propose UNIQUEMENT une révision de sortie. Aucune décision, aucun transfert
 * et aucun changement de dossier ne sont exécutés par ce service.
 * Auth : service role (appel serveur uniquement, jamais navigateur/APK).
 * Messages : sans nom, identifiant ou donnée clinique de patient.
 */
const zone = "Africa/Casablanca";
type Stay = { procedure: string; clinical: Record<string, unknown> };
function localDay(value: Date): string {
  const parts = new Intl.DateTimeFormat("en-GB",{
    timeZone:zone,year:"numeric",month:"2-digit",day:"2-digit",
  }).formatToParts(value);
  const get = (name:string)=>parts.find((p)=>p.type===name)?.value || "";
  return get("year")+"-"+get("month")+"-"+get("day");
}
function admissionDay(raw:string): string {
  // Flutter conserve parfois les heures locales en ISO sans fuseau.
  // Ne pas interpréter de façon arbitraire un 23h30 local comme de l'UTC.
  if (/^\d{4}-\d{2}-\d{2}T/.test(raw) &&
      !/(Z|[+\-]\d{2}:?\d{2})$/i.test(raw)) {
    return raw.slice(0,10);
  }
  return localDay(new Date(raw));
}
function epochDay(date: string): number {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!m) return Number.NaN;
  return Math.floor(Date.UTC(+m[1],+m[2]-1,+m[3]) / 86400000);
}
function normalized(raw: string): string {
  return raw.toLowerCase().normalize("NFD")
    .replace(/[\u0300-\u036f]/g,"").replaceAll("œ","oe")
    .replace(/[^a-z0-9]+/g," ").trim().replace(/\s+/g," ");
}
function standardDays(intervention: string): number {
  const text = normalized(intervention);
  const complex = /\b(perfor\w*|periton\w*|abces|complic\w*|gangren\w*|sepsis|septique|strangul\w*|occlus\w*|resection|colectom\w*|hepatectom\w*|pancreat\w*|hemicolectom\w*|anastomos\w*|laparotom\w*|conversion|spleno\w*|exerese|dpc|tumeur|cancer|neoplas\w*|carcinom\w*|fistul\w*|reprise|ischem\w*|necros\w*)\b/.test(text);
  const combined = /[+&]/.test(intervention) || text.includes(" et ");
  if (complex || combined) return 4;
  if (/\b(appendicite|appendicectomie|appendicecto|lv|lithiase vesiculaire|cholecystectomie|cholecystecto|hid|hig|hernie|herniorraphie|hernioplastie)\b/.test(text)) return 1;
  if (/\blook\b.*\b(coelio|coelioscopie|laparoscop)/.test(text)) return 1;
  return 4;
}
function reviewDue(stay: Stay, nowDay: string): boolean {
  const clinical = stay.clinical;
  if (!["postoperative","dischargeReady"].includes(String(clinical.stage||""))) return false;
  if (clinical.dischargeAt) return false;
  const admitted = clinical.admittedAt;
  if (typeof admitted !== "string") return false;
  const admittedDate = new Date(admitted);
  if (!Number.isFinite(admittedDate.getTime())) return false;
  const room = String(clinical.afterUnit || "").toUpperCase();
  if (room.startsWith("REA") || room.includes("RÉANIMATION")) return false;
  const days = Math.max(standardDays(stay.procedure),
    Number.isInteger(clinical.expectedDays) ? Math.max(0,Number(clinical.expectedDays)) : 0);
  const elapsed = epochDay(nowDay) - epochDay(admissionDay(admitted));
  // Pas de sortie automatique. Rappel du jour de seuil, puis une fois/jour si non traité.
  return Number.isFinite(elapsed) && elapsed >= days && elapsed >= 0;
}

Deno.serve(async (request:Request) => {
  if (request.method !== "POST") return new Response("Method not allowed",{status:405});
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return new Response("Not configured",{status:503});
  if (request.headers.get("Authorization") !== "Bearer " + key) {
    return new Response("Forbidden",{status:403});
  }
  const supabase = createClient(url,key,{
    auth:{autoRefreshToken:false,persistSession:false},
  });
  const now = localDay(new Date());
  const stays:Stay[] = [];
  for (let page=0;page<20;page++) {
    const {data,error} = await supabase.from("manual_patient_records")
      .select("procedure_name,clinical_data")
      .range(page*500,page*500+499);
    if (error) return new Response("Read unavailable",{status:503});
    for (const record of data||[]) {
      if (record.clinical_data && typeof record.clinical_data === "object") {
        stays.push({procedure:record.procedure_name,clinical:record.clinical_data});
      }
    }
    if ((data||[]).length<500) break;
  }
  for (let page=0;page<20;page++) {
    const {data,error} = await supabase.from("bloc_patient_records")
      .select("clinical_data,bloc_program_entries!inner(procedure_name)")
      .range(page*500,page*500+499);
    if (error) return new Response("Read unavailable",{status:503});
    for (const record of data||[]) {
      const entry = record.bloc_program_entries;
      const source = Array.isArray(entry) ? entry[0] : entry;
      if (source?.procedure_name &&
          record.clinical_data && typeof record.clinical_data === "object") {
        stays.push({procedure:source.procedure_name,clinical:record.clinical_data});
      }
    }
    if ((data||[]).length<500) break;
  }
  if (!stays.some((s)=>reviewDue(s,now))) {
    return Response.json({date:now,queued:0});
  }
  const {data:doctors,error:doctorsError} = await supabase.from("doctor_profiles")
    .select("user_id")
    .eq("approval_status","approved").in("approved_role",["junior","senior"]);
  if (doctorsError) return new Response("Staff unavailable",{status:503});
  const ids=(doctors||[]).map((x)=>x.user_id);
  if (ids.length===0) return Response.json({date:now,queued:0});
  const {data:prefs,error:prefsError} = await supabase
    .from("viscera_notification_preferences")
    .select("user_id,discharge_review").in("user_id",ids);
  if (prefsError) return new Response("Settings unavailable",{status:503});
  const muted = new Set((prefs||[])
    .filter((row)=>row.discharge_review===false).map((row)=>row.user_id));
  const rows=ids.filter((id)=>!muted.has(id)).map((id)=>({
    user_id:id,kind:"discharge_review",event_key:"discharge-review:"+now,
    title:"VISCERA · Sorties à réévaluer",
    body:"Des dossiers hospitalisés ont atteint leur seuil indicatif de sortie. Vérification clinique nécessaire.",
  }));
  if (!rows.length) return Response.json({date:now,queued:0});
  const {error:writeError} = await supabase
    .from("viscera_notifications").upsert(rows,{onConflict:"user_id,event_key",
      ignoreDuplicates:true});
  if (writeError) return new Response("Queue unavailable",{status:503});
  return Response.json({date:now,queued:rows.length});
});
