import { createClient } from "npm:@supabase/supabase-js@2.49.10";
import { unzipSync, strFromU8 } from "npm:fflate@0.8.2";
import { XMLParser } from "npm:fast-xml-parser@4.5.3";

type Row = Record<number, string>;
const parser = new XMLParser({
  ignoreAttributes: false, attributeNamePrefix: "@", parseTagValue: false, trimValues: false,
});
const asList = (v: unknown): any[] => v == null ? [] : Array.isArray(v) ? v : [v];
const normal = (s: string) => s.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  .toUpperCase().replace(/\s+/g, " ").trim();
const surgeons = (Deno.env.get("VISCERA_BLOC_SURGEONS") ||
  "GHADDOU,BENSAAD,LAABOULI,LAFKIH,FAHSI").split(",").map(normal).filter(Boolean);

function readXlsx(bytes: Uint8Array): Row[] {
  const zip = unzipSync(bytes);
  const worksheet = Object.keys(zip).filter((k) => /^xl\/worksheets\/sheet\d+\.xml$/.test(k))
    .sort((a, b) => Number(a.match(/sheet(\d+)/)?.[1] ?? 0) - Number(b.match(/sheet(\d+)/)?.[1] ?? 0))[0];
  if (!worksheet) throw Error("Invalid workbook");
  let shared: string[] = [];
  const textFromRuns = (part: any): string => {
    if (part == null) return "";
    if (typeof part === "string") return part;
    if (typeof part === "number") return String(part);
    if (Array.isArray(part)) return part.map(textFromRuns).join("");
    if (typeof part === "object") {
      if (part["#text"] != null) return String(part["#text"]);
      if (part.t != null) return textFromRuns(part.t);
      if (part.r != null) return asList(part.r).map((run) => textFromRuns(run.t)).join("");
    }
    return "";
  };
  if (zip["xl/sharedStrings.xml"]) {
    const xml = parser.parse(strFromU8(zip["xl/sharedStrings.xml"]));
    shared = asList(xml.sst?.si).map(textFromRuns);
  }
  const sheet = parser.parse(strFromU8(zip[worksheet]));
  const rows: Row[] = [];
  for (const xmlRow of asList(sheet.worksheet?.sheetData?.row)) {
    const row: Row = {};
    for (const cell of asList(xmlRow.c)) {
      const letters = String(cell["@r"] ?? "").match(/^([A-Z]+)\d+$/)?.[1];
      if (!letters) continue;
      let index = 0;
      for (const letter of letters) index = index * 26 + letter.charCodeAt(0) - 64;
      index--;
      let value = "";
      if (cell["@t"] === "s") value = shared[Number(cell.v)] ?? "";
      else if (cell["@t"] === "inlineStr") value = textFromRuns(cell.is);
      else value = textFromRuns(cell.v);
      row[index] = value.trim();
    }
    rows.push(row);
  }
  return rows;
}

function extractRows(sheet: Row[], isoDate: string) {
  const heading = sheet.findIndex((r) => Object.values(r).some((x) => normal(x) === "SALLE") &&
    Object.values(r).some((x) => normal(x) === "CHIRURGIEN") &&
    Object.values(r).some((x) => normal(x).includes("INTERVENTION")));
  if (heading < 0) throw Error("Unrecognized operating program layout");
  const header = sheet[heading];
  const getCol = (label: string): number => Number(Object.keys(header)
    .find((k) => normal(header[Number(k)]) === label) ?? -1);
  const roomCol = getCol("SALLE"), surgeonCol = getCol("CHIRURGIEN"),
    patientCol = getCol("IDENTITE DU PATIENT"), procedureCol = getCol("INTERVENTION");
  if ([roomCol, surgeonCol, patientCol, procedureCol].some((v) => v < 0))
    throw Error("Missing required program columns");
  const col = (row: Row, index: number) => index < 0 ? "" : (row[index] ?? "").trim();
  const wanted = (name: string) => surgeons.some((s) =>
    new RegExp("(^|[^A-Z])" + s.replace(/[.*+?^$()|[\]{}\\]/g, "\\$&") + "($|[^A-Z])").test(normal(name)));
  const out: Record<string, string>[] = [];
  for (const row of sheet.slice(heading + 1)) {
    const surgeon = col(row, surgeonCol);
    const patient = col(row, patientCol);
    const procedure = col(row, procedureCol);
    if (!wanted(surgeon) || !patient || patient === "*" || !procedure || procedure === "*") continue;
    out.push({
      room: col(row, roomCol).slice(0, 30),
      scheduled_time: col(row, getCol("HEURE")).slice(0, 32),
      hospital_arrival: col(row, getCol("HEURE D'ARRIVEE DU PATIENT A L'HOPITAL")).slice(0, 32),
      theatre_arrival: col(row, getCol("HEURE D'ARRIVEE AU BLOC")).slice(0, 32),
      source_service: col(row, getCol("SERVICE")).slice(0, 60),
      patient_name: patient.slice(0, 200),
      procedure_name: procedure.slice(0, 400),
      surgeon: surgeon.slice(0, 160),
      assistant: col(row, getCol("AIDE OPERATOIRE")).slice(0, 160),
      nurse: col(row, getCol("PANSEUSE")).slice(0, 160),
      anaesthetist: col(row, getCol("REANIMATEUR")).slice(0, 160),
      iar: col(row, getCol("IAR")).slice(0, 160),
      source_status: col(row, getCol("STATUT")).slice(0, 80),
    });
  }
  if (out.length > 200) throw Error("Too many entries");
  const slashDate = isoDate.substring(8, 10) + "/" + isoDate.substring(5, 7) + "/" + isoDate.substring(0, 4);
  const fileTitle = sheet.slice(0, heading).flatMap((row) => Object.values(row)).join(" ");
  if (!fileTitle.includes(slashDate)) throw Error("Date mismatch between workbook and filename");
  return out;
}

function json(status: number, data: Record<string, unknown>): Response {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });
  const secret = Deno.env.get("VISCERA_BLOC_INGEST_KEY");
  if (!secret || secret.length < 32) return json(503, { error: "Ingestion is not configured" });
  const supplied = req.headers.get("x-viscera-ingest-key") || "";
  const toHash = (x: string) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(x));
  const [expectedHash, suppliedHash] = await Promise.all([toHash(secret), toHash(supplied)]);
  let diff = 0;
  const expected = new Uint8Array(expectedHash), actual = new Uint8Array(suppliedHash);
  for (let i = 0; i < expected.length; i++) diff |= expected[i] ^ actual[i];
  if (diff !== 0) return json(401, { error: "Unauthorized" });

  try {
    if (Number(req.headers.get("content-length") || 0) > 1_600_000)
      return json(413, { error: "Attachment too large" });
    const body = await req.json();
    const filename = String(body.filename || "");
    const match = filename.match(/^PROGRAMME PREVU DU (\d{2})-(\d{2})-(\d{4})\.xlsx$/i);
    if (!match || !/^[A-Za-z0-9_-]{8,180}$/.test(String(body.message_id || "")))
      return json(400, { error: "Invalid source metadata" });
    const programDate = match[3] + "-" + match[2] + "-" + match[1];
    if (new Date(programDate + "T12:00:00Z").toISOString().slice(0, 10) !== programDate)
      return json(400, { error: "Invalid program date" });
    const receivedAt = String(body.received_at || "");
    if (!receivedAt || isNaN(Date.parse(receivedAt))) return json(400, { error: "Invalid email date" });
    const encoded = String(body.base64 || "");
    if (encoded.length > 1_500_000 || !/^[A-Za-z0-9+/=]+$/.test(encoded))
      return json(400, { error: "Invalid attachment" });
    const raw = atob(encoded);
    const bytes = Uint8Array.from(raw, (x) => x.charCodeAt(0));
    const sha = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)))
      .map((x) => x.toString(16).padStart(2, "0")).join("");
    const extracted = extractRows(readXlsx(bytes), programDate);
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEY");
    if (!url || !key) return json(503, { error: "Database is not configured" });
    const supabase = createClient(url, key, { auth: { persistSession: false } });
    const { data, error } = await supabase.rpc("viscera_ingest_bloc_program", {
      p_date: programDate,
      p_message_id: body.message_id,
      p_filename: filename,
      p_received_at: receivedAt,
      p_checksum: sha,
      p_rows: extracted,
    });
    if (error) { console.error("Bloc import failed", error.code); return json(500, { error: "Database write failed" }); }
    return json(200, { status: data?.status || "unknown", count: data?.count ?? 0, date: programDate });
  } catch (_error) {
    return json(422, { error: "The operating program could not be read" });
  }
});
