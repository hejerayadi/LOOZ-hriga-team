// LOOZ — Edge Function "diagnose": the PHOTO DIAGNOSIS (Bêta) of the paid
// pack. Migrations 016 and 018 must be run first.
//
// A paid farmer sends the photo of an almond leaf (already made small and
// without its hidden GPS data by the app). This function:
//   1. checks who it is (the token of the login);
//   2. diagnosis_begin(): paid pack, switch on, limits of the day; makes a
//      "pending" diagnosis and the name of its photo;
//   3. saves the photo in the PRIVATE bucket "diagnoses" (folder = the
//      farmer's id), and deletes his oldest photos (30 are kept);
//   4. asks the model named in app_settings.diagnosis_model (see "THE
//      MODELS" below): Gemini (Google) or Roboflow;
//   5. diagnosis_finish(): saves the CODES only; the database decides the
//      verdict (likely / unsure / nothing) with the settings.
// It answers with codes only (never a sentence): the app writes the texts in
// Arabic or French.
//
// Secrets (Supabase > Edge Functions > Secrets), never in the app, never in
// git, never in a log:
//   GEMINI_VISION_API_KEY  the key of the Google project "looz-vision" (Gemini).
//   GEMINI_API_KEY2        optional: a BACKUP Gemini key (another Google
//                          project), tried once when the first one is refused.
//   GROQ_API_KEY           optional: Groq, the 3rd step (the model of the
//                          setting app_settings.diagnosis_groq_model).
//   ROBOFLOW_API_KEY       the PRIVATE key of the Roboflow workspace (Roboflow).
//   ROBOFLOW_MODEL         optional, default "almond-diseases-detection-l7tfx/2".
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
// THE MODELS. The setting app_settings.diagnosis_model chooses one:
//   "gemini:<model>"               Gemini vision (GEMINI_VISION_API_KEY)
//   "roboflow"                     Roboflow, the secret ROBOFLOW_MODEL
//   "roboflow:<project>/<version>"  another Roboflow model
// Changing it needs no new app and no new deployment.
// ---------------------------------------------------------------------
const CLASSES = ["shot_hole", "leaf_curl", "leaf_spot"];

type Box = [number, number, number, number];
type Detection = { class: string; confidence: number; box: Box | null };
type ModelError =
  | "model_error" // a wrong key, a wrong answer...: "unavailable"
  | "model_quota" // a limit (Roboflow credits, Gemini 429): "busy"
  | "model_busy" // Google busy (503) twice: "busy"
  | "model_timeout"; // too slow: "busy"
type ModelAnswer =
  | {
    ok: true;
    model: string;
    detections: Detection[];
    label?: string;
    plant?: string;
  }
  | { ok: false; error: ModelError };

const round = (v: number, digits: number) =>
  Math.round(v * 10 ** digits) / 10 ** digits;
const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

type Choice =
  | { kind: "gemini"; model: string }
  | { kind: "roboflow"; model: string };

/** The setting -> the model to ask (unknown or missing: Roboflow, as before). */
export function chooseModel(
  setting: unknown,
  roboflowSecret = "",
): Choice {
  const value = typeof setting === "string" ? setting.trim() : "";
  const gemini = /^gemini:([a-z0-9][a-z0-9.-]{0,60})$/.exec(value);
  if (gemini) return { kind: "gemini", model: gemini[1] };
  const roboflow = /^roboflow:([a-z0-9][a-z0-9-]{0,80}\/[0-9]{1,4})$/.exec(
    value,
  );
  if (roboflow) return { kind: "roboflow", model: roboflow[1] };
  return {
    kind: "roboflow",
    model: roboflowSecret.trim() || "almond-diseases-detection-l7tfx/2",
  };
}

// ----- Roboflow -----
/** Weak guesses are kept too (the database decides with its thresholds). */
const ASK_CONFIDENCE = 0.25;
const ROBOFLOW_TIMEOUT_MS = 25_000;
const roboflowKey = Deno.env.get("ROBOFLOW_API_KEY") ?? "";
const roboflowSecretModel = Deno.env.get("ROBOFLOW_MODEL") ?? "";
// Only for the tests on the laptop (a fake Roboflow): never set it in Supabase.
const roboflowUrl = (Deno.env.get("ROBOFLOW_URL") ||
  "https://serverless.roboflow.com").replace(/\/+$/, "");

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
    const box: Box = [
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

async function askRoboflow(
  model: string,
  base64: string,
): Promise<ModelAnswer> {
  if (!roboflowKey || !/^[a-z0-9-]+\/[0-9]+$/.test(model)) {
    console.error("diagnose: ROBOFLOW_API_KEY or the Roboflow model missing");
    return { ok: false, error: "model_error" };
  }
  const endpoint = `${roboflowUrl}/${model}?confidence=${ASK_CONFIDENCE}` +
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
        signal: AbortSignal.timeout(ROBOFLOW_TIMEOUT_MS),
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
      return { ok: true, model: `roboflow:${model}`, detections };
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
      error: res.status === 402 || res.status === 423
        ? "model_quota"
        : "model_error",
    };
  }
  return { ok: false, error: "model_error" };
}

// ----- Gemini (Google), then Groq -----
// The steps (keys never printed; the logs say only "gemini-primary",
// "gemini-backup" or "groq-qwen"):
//   1. GEMINI_VISION_API_KEY  the primary key (project "looz-vision");
//   2. GEMINI_API_KEY2        optional BACKUP key: tried ONCE when the primary
//                             one gets a limit (429), Google busy (5xx), too
//                             slow, a network problem or a key error (401 /
//                             403 / invalid key);
//   3. GROQ_API_KEY           optional 3rd step: the model of the setting
//                             app_settings.diagnosis_groq_model on Groq
//                             (qwen/qwen3.8-27b; empty = no Groq step), tried
//                             ONCE when Gemini gave no answer.
// A step that is not set is skipped: without GROQ_API_KEY (and without
// GEMINI_API_KEY2) everything works as without them.
const geminiKey = (Deno.env.get("GEMINI_VISION_API_KEY") ?? "").trim();
const geminiBackupKey = (Deno.env.get("GEMINI_API_KEY2") ?? "").trim();
const groqKey = (Deno.env.get("GROQ_API_KEY") ?? "").trim();
// Only for the tests on the laptop (a fake Google / Groq): never set them in Supabase.
const geminiUrl = (Deno.env.get("GEMINI_VISION_URL") ||
  "https://generativelanguage.googleapis.com").replace(/\/+$/, "");
const groqUrl = (Deno.env.get("GROQ_URL") ||
  "https://api.groq.com/openai/v1").replace(/\/+$/, "");
/** The first try may wait long (the free tier is sometimes slow); a second
 *  try only after a quick "busy" (503) or a network problem. The app waits 70 s. */
const GEMINI_FIRST_TIMEOUT_MS = 40_000;
const GEMINI_RETRY_TIMEOUT_MS = 22_000;
const GEMINI_RETRY_AFTER_MS = 2_000;
/** All the steps together stay under the app's 70 s: each step keeps 15 s
 *  for each step after it, and gets at least 10 s. */
const GEMINI_ALL_TRIES_MS = 62_000;
const GEMINI_BACKUP_MIN_MS = 10_000;
const STEP_RESERVE_MS = 15_000;
/** A Groq model name of the setting (lower case, like qwen/qwen3.8-27b). */
const GROQ_MODEL_NAME =
  /^([a-z0-9][a-z0-9._-]{0,40}\/)?[a-z0-9][a-z0-9._:-]{0,60}$/;

const LABELS = [...CLASSES, "none", "not_a_leaf"];
const PLANTS = ["almond", "olive", "other", "unknown"];

/** What Gemini is asked: the same text as dashboard/backend/tools/diagnosis_eval.py
 *  (the test set was checked with it). */
export const GEMINI_PROMPT =
  `You check ONE photo sent by an almond farmer in Tunisia through a farming app.
Choose exactly ONE label:
- shot_hole: leaves with small round holes and/or small round red-brown or purple spots, often with a lighter or reddish ring, that dry and fall out ("shot hole", Wilsonomyces carpophilus).
- leaf_curl: leaves thickened, puckered, blistered, curled or twisted, often red, pink, yellow or pale green ("leaf curl", Taphrina deformans).
- leaf_spot: leaves with spots or blotches (red, orange, yellow, brown or black) WITHOUT holes and WITHOUT curling (for example "red leaf blotch", Polystigma).
- none: leaves (almond or another plant) without a visible sign of these diseases. Normal autumn yellowing, dry old leaves, insect bites, hail or mechanical damage: none.
- not_a_leaf: the photo does not show leaves well enough to judge: flowers, fruits or nuts, bark, soil, an object, or a photo too blurry, too dark or too far.
Rules:
- Judge only what you SEE. Do not guess a disease from the season or the place.
- Be conservative: when the signs are weak, unclear or could be something else, lower the confidence; when you see no clear sign, answer none or not_a_leaf.
- confidence: from 0 to 1, how sure you are that the label is right.
- reason: at most 15 words, English.
- plant: almond, olive, other or unknown (what the leaves look like).
- boxes: up to 5 boxes around the clearest disease signs (empty for none and not_a_leaf). Each box_2d is [ymin, xmin, ymax, xmax] normalized to 0-1000.`;

export const GEMINI_SCHEMA = {
  type: "object",
  properties: {
    label: { type: "string", enum: LABELS },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    reason: { type: "string" },
    plant: { type: "string", enum: PLANTS },
    boxes: {
      type: "array",
      maxItems: 5,
      items: {
        type: "object",
        properties: {
          box_2d: {
            type: "array",
            items: { type: "integer" },
            minItems: 4,
            maxItems: 4,
          },
        },
        required: ["box_2d"],
      },
    },
  },
  required: ["label", "confidence", "reason", "plant", "boxes"],
};

type GeminiResult = {
  label: string;
  confidence: number;
  plant: string;
  detections: Detection[];
};

/** What Qwen (on Groq) is asked: the same text, only the boxes in Qwen's own
 *  format (the same as QWEN_PROMPT in tools/diagnosis_eval.py). */
export const QWEN_PROMPT = GEMINI_PROMPT.replace(
  "Each box_2d is [ymin, xmin, ymax, xmax] normalized to 0-1000.",
  "Each bbox_2d is [x1, y1, x2, y2] (left, top, right, bottom) with coordinates normalized to 0-1000.",
) + "\nAnswer with the JSON object only.";
export const QWEN_SCHEMA = JSON.parse(
  JSON.stringify(GEMINI_SCHEMA).replaceAll('"box_2d"', '"bbox_2d"'),
);

/** The JSON object of a model -> codes and numbers (its "reason" sentence is
 *  dropped). Boxes: Gemini "box_2d" [ymin, xmin, ymax, xmax], Qwen "bbox_2d"
 *  [x1, y1, x2, y2], both on 0..1000 -> ours [x0, y0, x1, y1] on 0..1.
 *  null = not the answer asked for. */
function toResult(
  out: unknown,
  format: "gemini" | "qwen",
): GeminiResult | null {
  if (!out || typeof out !== "object" || Array.isArray(out)) return null;
  const o = out as Record<string, unknown>;
  const label = String(o.label ?? "");
  const confidence = typeof o.confidence === "number" ? o.confidence : NaN;
  if (!LABELS.includes(label) || !Number.isFinite(confidence)) return null;
  const plant = PLANTS.includes(String(o.plant)) ? String(o.plant) : "unknown";
  const conf = round(clamp01(confidence), 3);
  const boxes: Box[] = [];
  const key = format === "gemini" ? "box_2d" : "bbox_2d";
  for (const b of Array.isArray(o.boxes) ? o.boxes.slice(0, 5) : []) {
    const v = (b as Record<string, unknown>)?.[key];
    if (!Array.isArray(v) || v.length !== 4) continue;
    const n = v.map(Number);
    if (!n.every(Number.isFinite)) continue;
    const [x0, y0, x1, y1] = format === "gemini"
      ? [n[1], n[0], n[3], n[2]]
      : [n[0], n[1], n[2], n[3]];
    const box: Box = [
      round(clamp01(x0 / 1000), 4),
      round(clamp01(y0 / 1000), 4),
      round(clamp01(x1 / 1000), 4),
      round(clamp01(y1 / 1000), 4),
    ];
    if (box[0] >= box[2] || box[1] >= box[3]) continue;
    boxes.push(box);
  }
  const detections: Detection[] = !CLASSES.includes(label)
    ? []
    : boxes.length
    ? boxes.map((box) => ({ class: label, confidence: conf, box }))
    : [{ class: label, confidence: conf, box: null }];
  return { label, confidence: conf, plant, detections };
}

/** Gemini's answer -> codes and numbers. null = not the answer asked for. */
export function fromGemini(answer: unknown): GeminiResult | null {
  const parts = (answer as {
    candidates?: {
      content?: { parts?: { text?: unknown; thought?: unknown }[] };
    }[];
  })?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return null;
  const text = parts
    .filter((p) => typeof p?.text === "string" && p?.thought !== true)
    .map((p) => p.text as string)
    .join("");
  try {
    return toResult(JSON.parse(text), "gemini");
  } catch {
    return null;
  }
}

/** Qwen's answer on Groq (OpenAI chat format) -> codes and numbers. Not
 *  valid JSON (or not the answer asked for) -> null ("unavailable"). Only a
 *  ```json fence or a <think> part around the JSON is taken away. */
export function fromQwen(answer: unknown): GeminiResult | null {
  const content = (answer as {
    choices?: { message?: { content?: unknown } }[];
  })?.choices?.[0]?.message?.content;
  if (typeof content !== "string") return null;
  let text = content.trim();
  if (text.includes("</think>")) text = text.split("</think>").pop()!.trim();
  const fenced = /^```(?:json)?\s*([\s\S]*?)\s*```$/.exec(text);
  if (fenced) text = fenced[1];
  try {
    return toResult(JSON.parse(text), "qwen");
  } catch {
    return null;
  }
}

/** How ONE call (one step) went. */
type Who = "gemini-primary" | "gemini-backup" | "groq-qwen";
type Kind = "limit" | "busy" | "timeout" | "network" | "key" | "bad";
type GeminiTry =
  | { ok: true; result: GeminiResult; model: string }
  | {
    ok: false;
    // limit (429), busy (5xx), timeout, network, key (401 / 403 / invalid
    // key), bad (a wrong request or answer: another key would not help).
    kind: Kind;
    who: Who;
  };

const TRY_ERROR: Record<Kind, ModelError> = {
  limit: "model_quota",
  busy: "model_busy",
  timeout: "model_timeout",
  network: "model_error",
  key: "model_error",
  bad: "model_error",
};

/** fetch with a time limit; a timeout or a network problem -> its kind. */
async function post(
  url: string,
  headers: Record<string, string>,
  body: string,
  timeoutMs: number,
  who: Who,
): Promise<Response | { ok: false; kind: Kind; who: Who }> {
  try {
    return await fetch(url, {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (err) {
    const name = (err as Error)?.name;
    if (name === "TimeoutError" || name === "AbortError") {
      console.error(`diagnose: ${who} too slow`);
      return { ok: false, kind: "timeout", who };
    }
    console.error(`diagnose: ${who} can't be reached`);
    return { ok: false, kind: "network", who };
  }
}

/** A refusal (HTTP status) -> its kind. Only the status is logged. */
async function refusal(res: Response, who: Who): Promise<GeminiTry> {
  // Read to know if it is a key problem (never printed).
  const text = await res.text().catch(() => "");
  console.error(`diagnose: ${who} answered HTTP ${res.status}`);
  // 413 = Groq: more tokens than its limit of the minute.
  if (res.status === 429 || res.status === 413) {
    return { ok: false, kind: "limit", who };
  }
  if (res.status >= 500) return { ok: false, kind: "busy", who };
  if (
    res.status === 401 || res.status === 403 ||
    (res.status === 400 && /API_KEY_INVALID|API key not valid/i.test(text))
  ) {
    return { ok: false, kind: "key", who };
  }
  // 400 / 404: a wrong request or a wrong model name.
  return { ok: false, kind: "bad", who };
}

/** One call to Gemini with one key. [who] goes in the logs, never the key. */
async function callGemini(
  model: string,
  body: string,
  key: string,
  timeoutMs: number,
  who: "gemini-primary" | "gemini-backup",
): Promise<GeminiTry> {
  const res = await post(
    `${geminiUrl}/v1beta/models/${model}:generateContent`,
    { "x-goog-api-key": key },
    body,
    timeoutMs,
    who,
  );
  if (!(res instanceof Response)) return res;
  if (!res.ok) return refusal(res, who);
  const result = fromGemini(await res.json().catch(() => null));
  if (result === null) {
    console.error(`diagnose: unexpected answer of ${who}`);
    return { ok: false, kind: "bad", who };
  }
  console.log(`diagnose: model used: ${who}`);
  return { ok: true, result, model: `gemini:${model}` };
}

/** One call to the Groq model (OpenAI-compatible). Not valid JSON -> "bad". */
async function callGroq(
  model: string,
  base64: string,
  timeoutMs: number,
): Promise<GeminiTry> {
  const who = "groq-qwen";
  const body = JSON.stringify({
    model,
    messages: [{
      role: "user",
      content: [
        {
          type: "image_url",
          image_url: { url: `data:image/jpeg;base64,${base64}` },
        },
        { type: "text", text: QWEN_PROMPT },
      ],
    }],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "leaf_diagnosis",
        schema: QWEN_SCHEMA,
        strict: false,
      },
    },
    max_tokens: 600,
    temperature: 0,
  });
  const res = await post(
    `${groqUrl}/chat/completions`,
    { Authorization: `Bearer ${groqKey}` },
    body,
    timeoutMs,
    who,
  );
  if (!(res instanceof Response)) return res;
  if (!res.ok) return refusal(res, who);
  const result = fromQwen(await res.json().catch(() => null));
  if (result === null) {
    console.error(`diagnose: unexpected answer of ${who} (not the JSON asked)`);
    return { ok: false, kind: "bad", who };
  }
  console.log(`diagnose: model used: ${who}`);
  return { ok: true, result, model: `groq:${model}` };
}

/** Gemini (primary key, backup key), then Groq: the first answer wins. */
async function askGemini(
  model: string,
  base64: string,
  groqModel = "",
): Promise<ModelAnswer> {
  const groqOn = Boolean(groqKey && GROQ_MODEL_NAME.test(groqModel));
  if (!geminiKey && !geminiBackupKey && !groqOn) {
    console.error("diagnose: GEMINI_VISION_API_KEY missing");
    return { ok: false, error: "model_error" };
  }
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { inlineData: { mimeType: "image/jpeg", data: base64 } },
        { text: GEMINI_PROMPT },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: GEMINI_SCHEMA,
      thinkingConfig: { thinkingLevel: "LOW" },
    },
  });
  const done = (t: GeminiTry): ModelAnswer =>
    t.ok
      ? {
        ok: true,
        model: t.model,
        detections: t.result.detections,
        label: t.result.label,
        plant: t.result.plant,
      }
      : { ok: false, error: TRY_ERROR[t.kind] };
  const started = Date.now();
  /** The time of a step: what is left, minus 15 s for each step after it. */
  const timeFor = (stepsAfter: number) =>
    Math.min(
      GEMINI_FIRST_TIMEOUT_MS,
      Math.max(
        GEMINI_BACKUP_MIN_MS,
        GEMINI_ALL_TRIES_MS - (Date.now() - started) -
          STEP_RESERVE_MS * stepsAfter,
      ),
    );
  const failed: (GeminiTry & { ok: false })[] = [];

  // 1. The primary key (missing = like a key error: on to the next step).
  if (geminiKey) {
    const later = (geminiBackupKey ? 1 : 0) + (groqOn ? 1 : 0);
    const t = await callGemini(
      model,
      body,
      geminiKey,
      timeFor(later),
      "gemini-primary",
    );
    if (t.ok) return done(t);
    failed.push(t);
  } else {
    console.error("diagnose: GEMINI_VISION_API_KEY missing");
    failed.push({ ok: false, kind: "key", who: "gemini-primary" });
  }

  // 2a. No backup key and no Groq: as before — one more try with the same
  //     key after a quick "busy" (5xx) or a network problem; else the error.
  if (!geminiBackupKey && !groqOn) {
    const first = failed[0];
    if (first.kind !== "busy" && first.kind !== "network") return done(first);
    await sleep(GEMINI_RETRY_AFTER_MS);
    return done(
      await callGemini(
        model,
        body,
        geminiKey,
        GEMINI_RETRY_TIMEOUT_MS,
        "gemini-primary",
      ),
    );
  }

  // 2b. The backup key, ONCE: after a limit, busy, too slow, network or a key
  //     error. A wrong request or answer: another key would not help.
  if (geminiBackupKey && failed[0].kind !== "bad") {
    console.log("diagnose: trying gemini-backup");
    const t = await callGemini(
      model,
      body,
      geminiBackupKey,
      timeFor(groqOn ? 1 : 0),
      "gemini-backup",
    );
    if (t.ok) return done(t);
    failed.push(t);
  }

  // 3. Groq, ONCE, with the time left (another model: also after a wrong
  //    answer of Gemini).
  if (groqOn) {
    console.log("diagnose: trying groq-qwen");
    const t = await callGroq(groqModel, base64, timeFor(0));
    if (t.ok) return done(t);
    failed.push(t);
  }

  // Nobody answered. Groq's answer not valid JSON: "unavailable". Else
  // "busy" if a step met a limit, busy or too slow (it may work later);
  // "unavailable" if all were key / network / wrong answers.
  const last = failed[failed.length - 1];
  if (last.who === "groq-qwen" && last.kind === "bad") return done(last);
  const waitable = (t: { kind: Kind }) =>
    t.kind === "limit" || t.kind === "busy" || t.kind === "timeout";
  if (waitable(last)) return done(last);
  const earlier = [...failed].reverse().find(waitable);
  return done(earlier ?? last);
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

  // 3. The settings: the model, the limit for the message, the thresholds
  //    of the marks. ("*": still works before migration 018 is run.)
  const { data: settings } = await db.from("app_settings")
    .select("*").eq("id", true).single();
  const perDay = Number(settings?.diagnosis_per_day ?? 10);
  const choice = chooseModel(settings?.diagnosis_model, roboflowSecretModel);
  const unsure = choice.kind === "gemini"
    ? Number(settings?.diagnosis_gemini_unsure ?? 0.7)
    : Number(settings?.diagnosis_unsure ?? 0.4);

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
  const base64 = body.image.replace(/^data:image\/jpeg;base64,/, "");
  // The Groq step: only once migration 018 has its setting (else no step).
  const groqModel = typeof settings?.diagnosis_groq_model === "string"
    ? settings.diagnosis_groq_model.trim()
    : "";
  const answer = choice.kind === "gemini"
    ? await askGemini(choice.model, base64, groqModel)
    : await askRoboflow(choice.model, base64);
  if (!answer.ok) {
    await finish(db, id, { status: "failed", error: answer.error });
    // A limit, Google busy or too slow: "الفحص مشغول…"; else "غير متوفر".
    return reply({
      error: answer.error === "model_error" ? "unavailable" : "busy",
    });
  }

  // 7. The codes saved; the database decides the verdict.
  const row = await finish(db, id, {
    status: "done",
    model: answer.model,
    detections: answer.detections,
    ...(answer.label ? { label: answer.label, plant: answer.plant } : {}),
  });
  if (!row) return reply({ error: "server" }, 500);
  const verdict = String(row.verdict);
  const detections = (row.detections ?? []) as Detection[];
  const marked = verdict === "nothing" ? [] : detections
    .filter((d) =>
      d.class === row.top_class && Array.isArray(d.box) &&
      d.confidence >= unsure
    )
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
