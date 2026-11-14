// LOOZ — Edge Function "diagnose": the PHOTO DIAGNOSIS (Bêta) of the paid
// pack. Migration 016 must be run first.
//
// A paid farmer sends the photo of an almond leaf (already made small and
// without its hidden GPS data by the app). This function:
//   1. checks who it is (the token of the login);
//   2. diagnosis_begin(): paid pack, switch on, limits of the day; makes a
//      "pending" diagnosis and the name of its photo;
//   3. saves the photo in the PRIVATE bucket "diagnoses" (folder = the
//      farmer's id), and deletes his oldest photos (30 are kept);
//   4. asks the model (Roboflow, see "THE MODEL" below);
//   5. diagnosis_finish(): saves the CODES only; the database decides the
//      verdict (likely / unsure / nothing) with the thresholds of app_settings.
// It answers with codes only (never a sentence): the app writes the texts in
// Arabic or French.
//
// Secrets (Supabase > Edge Functions > Secrets):
//   ROBOFLOW_API_KEY   the PRIVATE key of the Roboflow workspace (required).
//                      Never in the app, never in git, never in a log.
//   ROBOFLOW_MODEL     optional, default "almond-diseases-detection-l7tfx/2".
// "Verify JWT" must be ON: only logged-in users reach this function (it
// checks the login again itself).
//
// The app sends (POST, JSON): {"image": "<JPEG in base64>"}
// Answers (HTTP 200):
//   {"id", "verdict": "likely" | "unsure" | "nothing", "top_class":
//    "shot_hole" | "leaf_curl" | "leaf_spot" | null, "top_confidence",
//    "marked": [[x0, y0, x1, y1], ...]  (boxes to draw, fractions of the photo),
//    "photo_path", "used_today", "per_day", "created_at"}
//   {"error": "not_paid" | "limit_day" | "busy" | "off" | "unavailable" |
//             "bad_image", "per_day"?}
// Not logged in: HTTP 401 {"error": "not_logged_in"}. Wrong request: 400.
// Problem on the server: 500 {"error": "server"}.

import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.45.4";

/** The biggest photo accepted (the app sends about 0.2 to 0.6 MB). */
const MAX_PHOTO_BYTES = 3 * 1024 * 1024;
const BUCKET = "diagnoses";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/** A key of the project: the classic one, else the first of the new keys. */
function projectKey(classic: string, newKeys: string): string {
  const key = Deno.env.get(classic);
  if (key) return key;
  try {
    const keys = JSON.parse(Deno.env.get(newKeys) ?? "{}") as Record<
      string,
      string
    >;
    return keys["default"] ?? Object.values(keys)[0] ?? "";
  } catch {
    return "";
  }
}

const url = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = projectKey(
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_SECRET_KEYS",
);
const noSession = { auth: { persistSession: false, autoRefreshToken: false } };
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------
// THE MODEL. Only this part changes for another model (a newer Roboflow
// version: the secret ROBOFLOW_MODEL; another provider: this function).
// ---------------------------------------------------------------------
const CLASSES = ["shot_hole", "leaf_curl", "leaf_spot"];
/** Weak guesses are kept too (the database decides with its thresholds). */
const ASK_CONFIDENCE = 0.25;
const MODEL_TIMEOUT_MS = 25_000;
const roboflowKey = Deno.env.get("ROBOFLOW_API_KEY") ?? "";
const roboflowModel = (Deno.env.get("ROBOFLOW_MODEL") ||
  "almond-diseases-detection-l7tfx/2").trim();
// Only for the tests on the laptop (a fake Roboflow): never set it in Supabase.
const roboflowUrl = (Deno.env.get("ROBOFLOW_URL") ||
  "https://serverless.roboflow.com").replace(/\/+$/, "");

type Detection = {
  class: string;
  confidence: number;
  box: [number, number, number, number];
};
type ModelAnswer =
  | { ok: true; model: string; detections: Detection[] }
  | { ok: false; error: "model_error" | "model_quota" | "model_timeout" };

const round = (v: number, digits: number) =>
  Math.round(v * 10 ** digits) / 10 ** digits;
const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

/** Roboflow's answer -> detections of the 3 known classes, boxes 0..1. */
export function toDetections(answer: unknown): Detection[] | null {
  const a = answer as {
    image?: { width?: number; height?: number };
    predictions?: unknown[];
  };
  const w = Number(a?.image?.width);
  const h = Number(a?.image?.height);
  if (!(w > 0) || !(h > 0) || !Array.isArray(a?.predictions)) return null;
  const out: Detection[] = [];
  for (const p of a.predictions as Record<string, unknown>[]) {
    const [x, y, pw, ph, c] = [p?.x, p?.y, p?.width, p?.height, p?.confidence]
      .map(Number);
    const cls = String(p?.class ?? "");
    if (!CLASSES.includes(cls)) continue; // an unknown class is ignored
    if (![x, y, pw, ph, c].every(Number.isFinite) || pw <= 0 || ph <= 0) {
      continue;
    }
    // Roboflow gives the CENTRE of the box, in pixels.
    const box: Detection["box"] = [
      round(clamp01((x - pw / 2) / w), 4),
      round(clamp01((y - ph / 2) / h), 4),
      round(clamp01((x + pw / 2) / w), 4),
      round(clamp01((y + ph / 2) / h), 4),
    ];
    if (box[0] >= box[2] || box[1] >= box[3]) continue;
    out.push({ class: cls, confidence: round(clamp01(c), 3), box });
  }
  out.sort((p, q) => q.confidence - p.confidence);
  return out.slice(0, 50);
}

async function detect(base64: string): Promise<ModelAnswer> {
  if (!roboflowKey || !/^[a-z0-9-]+\/[0-9]+$/.test(roboflowModel)) {
    console.error("diagnose: ROBOFLOW_API_KEY or ROBOFLOW_MODEL missing");
    return { ok: false, error: "model_error" };
  }
  const endpoint = `${roboflowUrl}/${roboflowModel}?confidence=${ASK_CONFIDENCE}` +
    "&overlap=0.3&max_detections=100&disable_active_learning=true";
  for (let attempt = 1; attempt <= 2; attempt++) {
    let res: Response;
    try {
      res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${roboflowKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: base64,
        signal: AbortSignal.timeout(MODEL_TIMEOUT_MS),
      });
    } catch (err) {
      const name = (err as Error)?.name;
      if (name === "TimeoutError" || name === "AbortError") {
        return { ok: false, error: "model_timeout" };
      }
      if (attempt === 1) {
        await sleep(1500);
        continue;
      }
      console.error("diagnose: the model can't be reached");
      return { ok: false, error: "model_error" };
    }
    if (res.ok) {
      const detections = toDetections(await res.json().catch(() => null));
      if (detections === null) {
        console.error("diagnose: unexpected answer of the model");
        return { ok: false, error: "model_error" };
      }
      return { ok: true, model: `roboflow:${roboflowModel}`, detections };
    }
    await res.body?.cancel();
    // Busy (429) or a problem on their side (5xx): one more try.
    if ((res.status === 429 || res.status >= 500) && attempt === 1) {
      await sleep(1500);
      continue;
    }
    console.error(`diagnose: the model answered HTTP ${res.status}`);
    // 402 / 423: no credits left (Free Tier: 10 a month).
    return {
      ok: false,
      error: res.status === 402 || res.status === 423 ? "model_quota" : "model_error",
    };
  }
  return { ok: false, error: "model_error" };
}

// ---------------------------------------------------------------------
// The request
// ---------------------------------------------------------------------
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** base64 -> bytes; null = not base64. */
function fromBase64(text: string): Uint8Array | null {
  try {
    const raw = atob(text.replace(/^data:image\/jpeg;base64,/, ""));
    const bytes = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

/** A refusal of diagnosis_begin -> the code for the app. */
function beginRefusal(error: { code?: string; message?: string }): string {
  switch (error.code) {
    case "PT403":
      return "not_paid";
    case "PT429":
      return "limit_day";
    case "PT503":
      return (error.message ?? "").includes("App limit") ? "busy" : "off";
    case "22023":
      return "bad_zone";
    default:
      return "server";
  }
}

async function finish(
  db: SupabaseClient,
  id: string,
  result: Record<string, unknown>,
) {
  const { data, error } = await db.rpc("diagnosis_finish", {
    p_id: id,
    p_result: result,
  });
  if (error) console.error(`diagnose: finish refused (${error.code})`);
  return error ? null : data as Record<string, unknown>;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply({ error: "bad_request" }, 405);

  // 1. Who is it? (The gateway already checked the token: "Verify JWT" ON.
  //    Checked again here, so it stays safe even if the switch is changed.)
  const token = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const db = createClient(url, serviceKey, noSession);
  const { data: auth, error: authError } = await db.auth.getUser(token);
  const userId = auth?.user?.id;
  if (authError || !userId) return reply({ error: "not_logged_in" }, 401);

  // 2. The photo: a JPEG, not too big.
  let body: { image?: unknown; zone_id?: unknown };
  try {
    body = await req.json();
  } catch {
    return reply({ error: "bad_request" }, 400);
  }
  if (typeof body?.image !== "string") {
    return reply({ error: "bad_request" }, 400);
  }
  const zone = typeof body.zone_id === "string" && UUID.test(body.zone_id)
    ? body.zone_id
    : null;
  if (body.image.length > Math.ceil(MAX_PHOTO_BYTES / 3) * 4 + 64) {
    return reply({ error: "bad_image" });
  }
  const bytes = fromBase64(body.image);
  if (
    !bytes || bytes.length < 100 || bytes.length > MAX_PHOTO_BYTES ||
    bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff
  ) {
    return reply({ error: "bad_image" });
  }

  // 3. The settings (the limit for the message, the threshold of the marks).
  const { data: settings } = await db.from("app_settings")
    .select("diagnosis_per_day, diagnosis_unsure").eq("id", true).single();
  const perDay = Number(settings?.diagnosis_per_day ?? 10);
  const unsure = Number(settings?.diagnosis_unsure ?? 0.4);

  // 4. Paid pack, switch, limits: a pending diagnosis.
  const { data: begin, error: beginError } = await db.rpc("diagnosis_begin", {
    p_user: userId,
    p_zone: zone,
  });
  if (beginError) {
    const refusal = beginRefusal(beginError);
    if (refusal === "server") {
      console.error(`diagnose: begin refused (${beginError.code})`);
      return reply({ error: "server" }, 500);
    }
    return reply({ error: refusal, per_day: perDay });
  }
  const id = String(begin.id);
  const photoPath = String(begin.photo_path);

  // 5. The photo in the private bucket; the oldest photos deleted.
  const { error: uploadError } = await db.storage.from(BUCKET).upload(
    photoPath,
    bytes,
    { contentType: "image/jpeg", upsert: false },
  );
  if (uploadError) {
    console.error("diagnose: the photo was not saved");
    await finish(db, id, { status: "failed", error: "storage" });
    return reply({ error: "unavailable" });
  }
  const old = Array.isArray(begin.remove) ? begin.remove as string[] : [];
  if (old.length) {
    const { error } = await db.storage.from(BUCKET).remove(old);
    if (error) console.error("diagnose: old photos not deleted");
  }

  // 6. The model.
  const answer = await detect(body.image.replace(/^data:image\/jpeg;base64,/, ""));
  if (!answer.ok) {
    await finish(db, id, { status: "failed", error: answer.error });
    return reply({
      error: answer.error === "model_quota" ? "busy" : "unavailable",
    });
  }

  // 7. The codes saved; the database decides the verdict.
  const row = await finish(db, id, {
    status: "done",
    model: answer.model,
    detections: answer.detections,
  });
  if (!row) return reply({ error: "server" }, 500);
  const verdict = String(row.verdict);
  const detections = (row.detections ?? []) as Detection[];
  const marked = verdict === "nothing" ? [] : detections
    .filter((d) => d.class === row.top_class && d.confidence >= unsure)
    .map((d) => d.box);
  return reply({
    id,
    verdict,
    top_class: verdict === "nothing" ? null : row.top_class,
    top_confidence: verdict === "nothing" ? null : row.top_confidence,
    marked,
    photo_path: row.photo_path,
    used_today: begin.used_today,
    per_day: begin.per_day,
    created_at: row.created_at,
  });
});
