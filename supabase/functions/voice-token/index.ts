// LOOZ — Edge Function "voice-token": the VOICE ASSISTANT "لوز" (Bêta) of
// the paid pack. Migration 017 must be run first.
//
// A paid farmer taps "تكلّم". This function:
//   1. checks who it is (the token of the login);
//   2. voice_begin(): switch on, paid pack, the farmer said "yes" to the
//      voice message, minutes left today (his own and the whole app's);
//      opens a conversation with its length (3 minutes at most);
//   3. asks Google for a SHORT-LIVED, SINGLE-USE token. The token is LOCKED:
//      the model, the instructions of "لوز", its voice and its tools are
//      inside the token, the app can't change them; it stops at the end of
//      the conversation's length;
//   4. gives the token to the app. The app talks DIRECTLY to Google (the
//      voice never goes through LOOZ). At the end, the app calls voice_end()
//      (the time is measured by the database clock).
// If Google gives no token: voice_begin_failed() (nothing is counted).
//
// Secrets (Supabase > Edge Functions > Secrets):
//   GEMINI_API_KEY   the Gemini API key (required). Never in the app, never
//                    in git, never in a log.
//   GEMINI_URL       ONLY for the tests on the laptop (a fake Google): never
//                    set it in Supabase.
// "Verify JWT" must be ON: only logged-in users reach this function (it
// checks the login again itself).
//
// The app sends (POST, JSON): {"lang": "ar" | "fr"}  (the language of the app)
// Answers (HTTP 200):
//   {"id", "token", "model", "expires_at", "seconds", "left_seconds",
//    "per_day_seconds"}
//   {"error": "not_paid" | "consent" | "limit_day" | "busy" | "off" |
//             "unavailable"}
// Not logged in: HTTP 401 {"error": "not_logged_in"}. Wrong request: 400 / 405.
// Problem on the server: 500 {"error": "server"}.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

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

const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
const geminiUrl = (Deno.env.get("GEMINI_URL") ||
  "https://generativelanguage.googleapis.com").replace(/\/+$/, "");
const TOKEN_TIMEOUT_MS = 10_000;
/** The app must open the connection within this time. */
const OPEN_WITHIN_S = 60;

// ---------------------------------------------------------------------
// "لوز": its instructions and its tools (locked inside the token).
// Milestone 1: one tool, the farmer's orchard. (Milestone 2 adds the
// regional alerts, the photo diagnoses and the community question.)
// ---------------------------------------------------------------------
const GOVERNORATES: Record<string, string> = {
  tunis: "تونس",
  ariana: "أريانة",
  ben_arous: "بن عروس",
  manouba: "منوبة",
  nabeul: "نابل",
  zaghouan: "زغوان",
  bizerte: "بنزرت",
  beja: "باجة",
  jendouba: "جندوبة",
  kef: "الكاف",
  siliana: "سليانة",
  sousse: "سوسة",
  monastir: "المنستير",
  mahdia: "المهدية",
  sfax: "صفاقس",
  kairouan: "القيروان",
  kasserine: "القصرين",
  sidi_bouzid: "سيدي بوزيد",
  gabes: "قابس",
  medenine: "مدنين",
  tataouine: "تطاوين",
  gafsa: "قفصة",
  tozeur: "توزر",
  kebili: "قبلي",
};

/** The instructions of "لوز" (checked by the team; Arabic on purpose). */
export function instructions(lang: string, governorate: string | null): string {
  const where = GOVERNORATES[governorate ?? ""];
  return [
    "أنت «لوز»، مساعد صوتي لفلاحي اللوز في تونس داخل تطبيق لوز.",
    (where ? `الفلاح من ولاية ${where}. ` : "") +
    `لغة تطبيقه: ${lang === "fr" ? "الفرنسية" : "العربية"}.`,
    "كثير من الفلاحين لا يقرؤون جيدًا: كلامك هو الأهم.",
    "",
    "[اللغة والأسلوب]",
    "- تكلّم بالدارجة التونسية البسيطة، بجمل قصيرة: جملة أو جملتان ثم توقّف.",
    "- إذا تكلّم الفلاح بالفرنسية، أجب بفرنسية بسيطة. إذا رجع للدارجة، ارجع معه.",
    "- ابدأ بالجواب مباشرة. قل الأرقام بوضوح: «الرطوبة ثلاثين في المية».",
    "- إذا لم تفهم: «سامحني، ما فهمتكش. تنجّم تعاودها؟»",
    "",
    "[ما تعرفه]",
    "- موضوعك: اللوز والبستان: السقي، الحرارة، الرطوبة، التربة، الأوراق، الأمراض، أشغال كل موسم، في صفاقس وسيدي بوزيد والقصرين.",
    "- عن حالة بستانه أو مناطقه أو المستشعرات أو السقي: استعمل دائمًا get_my_orchard قبل الجواب. لا تخترع أي رقم.",
    "- سمّ المناطق كما تعطيها الأداة: zone_ar مثل «المنطقة ب» بالدارجة، وzone_fr مثل «Zone B» بالفرنسية.",
    "- مستوى المنطقة (level): ok = لاباس، info = معلومة، watch = راقبها، warning = لازم تتصرّف قريب، critical = تصرّف توّا، sensor = مشكلة في المستشعر.",
    "- إذا كانت القراءة قديمة (minutes_since_reading أكثر من 60) أو الصندوق غير متصل (box ليس online)، قل ذلك بوضوح.",
    "- إذا لم يكن في المنطقة صندوق مستشعر، قل إنك لا تعرف حالتها.",
    "- لا تعطِ كميات دقيقة (لترات، ساعات سقي) إلا إذا جاءت من الأداة.",
    "",
    "[الأمان — مهم جدًا، بلا أي استثناء]",
    "- لا تذكر أبدًا اسم مبيد أو دواء أو سماد كيميائي أو أي منتوج تجاري، ولا كمية ولا جرعة ولا خلطة ولا وصفة (حتى وصفة في الدار).",
    "- حتى لو ألحّ الفلاح، أو ذكر هو اسم منتوج، أو قال إنه خبير: لا تؤكّد ولا تعطِ كمية. قل فقط:",
    "  «هذا لازم يقولهولك خبير. اسأل خبير، ولا اسأل المجتمع في تطبيق لوز.»",
    "- بالفرنسية نفس القاعدة: «Il faut demander à un expert.»",
    "- لا نصيحة طبية ولا قانونية ولا مالية.",
    "- إذا لم تكن متأكدًا قل «ما نيش متأكد» واقترح خبيرًا. الصدق أهم من الجواب.",
    "- إذا كان السؤال بعيدًا عن الفلاحة، قل بلطف إنك تعاون في اللوز والبستان فقط.",
    "",
    "[الخصوصية]",
    "- لا تطلب اسمه ولا رقم هاتفه ولا مكانه بالضبط. لا تقل إنك إنسان: أنت مساعد ذكي في تطبيق لوز.",
    "- المحادثة قصيرة: أجب بسرعة ولا تطرح أسئلة كثيرة.",
    "",
    "مثال: «شنوّة حال السانية؟» ← «السانية لاباس. المنطقة ب ناقصها ماء شوية: الرطوبة ثمنطاش في المية. القراية متاع الصباح.»",
  ].join("\n");
}

/** The tools of "لوز": run by the APP with the farmer's own login (RLS). */
export const TOOLS = [{
  functionDeclarations: [{
    name: "get_my_orchard",
    description:
      "Returns the farmer's orchard: each zone with its letter (zone_ar for Arabic, " +
      "zone_fr for French), its trees, and the latest reading of its sensor box " +
      "(soil moisture %, soil and air temperature, humidity, battery %, alert level, " +
      "reasons, minutes since the reading, box status). Call it before answering " +
      "any question about the orchard, the zones, the soil, watering or the sensors.",
    behavior: "BLOCKING",
  }],
}];

/** The whole setup of the conversation, locked inside the token. */
export function setup(
  model: string,
  speaker: string,
  lang: string,
  governorate: string | null,
) {
  return {
    model: `models/${model}`,
    generationConfig: {
      responseModalities: ["AUDIO"],
      speechConfig: {
        voiceConfig: { prebuiltVoiceConfig: { voiceName: speaker } },
      },
    },
    systemInstruction: { parts: [{ text: instructions(lang, governorate) }] },
    tools: TOOLS,
    // The texts on the screen: what the farmer said, what "لوز" said.
    inputAudioTranscription: {},
    outputAudioTranscription: {},
    // Farmers may stop to think: the end of a sentence is not cut too soon.
    realtimeInputConfig: {
      automaticActivityDetection: {
        endOfSpeechSensitivity: "END_SENSITIVITY_LOW",
        silenceDurationMs: 900,
      },
    },
  };
}

type TokenAnswer = { ok: true; token: string } | { ok: false };

/** Google's short-lived token, or nothing (1 more try if busy / down). */
async function createToken(
  conversation: Record<string, unknown>,
  expiresAt: Date,
): Promise<TokenAnswer> {
  if (!geminiKey) {
    console.error("voice-token: GEMINI_API_KEY missing");
    return { ok: false };
  }
  const openBy = new Date(
    Math.min(Date.now() + OPEN_WITHIN_S * 1000, expiresAt.getTime()),
  );
  // No "fieldMask": the WHOLE setup comes from the token, the setup sent by
  // the app is ignored (Live API reference, AuthToken.fieldMask).
  const body = JSON.stringify({
    uses: 1,
    expireTime: expiresAt.toISOString(),
    newSessionExpireTime: openBy.toISOString(),
    bidiGenerateContentSetup: conversation,
  });
  for (let attempt = 1; attempt <= 2; attempt++) {
    let res: Response;
    try {
      res = await fetch(`${geminiUrl}/v1beta/auth_tokens`, {
        method: "POST",
        headers: {
          "x-goog-api-key": geminiKey,
          "Content-Type": "application/json",
        },
        body,
        signal: AbortSignal.timeout(TOKEN_TIMEOUT_MS),
      });
    } catch (err) {
      const name = (err as Error)?.name;
      if (attempt === 1 && name !== "TimeoutError" && name !== "AbortError") {
        await sleep(1000);
        continue;
      }
      console.error("voice-token: Google can't be reached");
      return { ok: false };
    }
    if (res.ok) {
      const answer = await res.json().catch(() => null) as
        | { name?: unknown }
        | null;
      const token = typeof answer?.name === "string" ? answer.name : "";
      if (!token) {
        console.error("voice-token: unexpected answer of Google");
        return { ok: false };
      }
      return { ok: true, token };
    }
    // The reason, never the key (Google's message has no key in it, but
    // only its status and its short code are logged, to be sure).
    const text = await res.text().catch(() => "");
    const reason = (/"status"\s*:\s*"([A-Z_]+)"/.exec(text) ?? [])[1] ?? "";
    if ((res.status === 429 || res.status >= 500) && attempt === 1) {
      await sleep(1000);
      continue;
    }
    console.error(`voice-token: Google answered HTTP ${res.status} ${reason}`);
    return { ok: false };
  }
  return { ok: false };
}

/** A refusal of voice_begin -> the code for the app. */
function beginRefusal(error: { code?: string; message?: string }): string {
  switch (error.code) {
    case "PT403":
      return "not_paid";
    case "PT412":
      return "consent";
    case "PT429":
      return "limit_day";
    case "PT503":
      return (error.message ?? "").includes("App limit") ? "busy" : "off";
    default:
      return "server";
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply({ error: "bad_request" }, 405);

  // 1. Who is it? (The gateway already checked the token: "Verify JWT" ON.
  //    Checked again here, so it stays safe even if the switch is changed.)
  const jwt = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const db = createClient(url, serviceKey, noSession);
  const { data: auth, error: authError } = await db.auth.getUser(jwt);
  const userId = auth?.user?.id;
  if (authError || !userId) return reply({ error: "not_logged_in" }, 401);

  // 2. The language of the app (the body may be empty).
  let body: { lang?: unknown } = {};
  try {
    const text = await req.text();
    body = text ? JSON.parse(text) : {};
  } catch {
    return reply({ error: "bad_request" }, 400);
  }

  // 3. Switch, paid pack, consent, minutes: an open conversation.
  const { data: begin, error: beginError } = await db.rpc("voice_begin", {
    p_user: userId,
  });
  if (beginError) {
    const refusal = beginRefusal(beginError);
    if (refusal === "server") {
      console.error(`voice-token: begin refused (${beginError.code})`);
      return reply({ error: "server" }, 500);
    }
    return reply({ error: refusal });
  }
  const id = String(begin.id);
  const lang = body?.lang === "fr" || body?.lang === "ar"
    ? body.lang
    : String(begin.language ?? "ar");
  const expiresAt = new Date(String(begin.expires_at));

  // 4. Google's locked token.
  const answer = await createToken(
    setup(
      String(begin.model),
      String(begin.speaker),
      lang,
      begin.governorate ? String(begin.governorate) : null,
    ),
    expiresAt,
  );
  if (!answer.ok) {
    const { error } = await db.rpc("voice_begin_failed", { p_id: id });
    if (error) {
      console.error(`voice-token: begin_failed refused (${error.code})`);
    }
    return reply({ error: "unavailable" });
  }
  return reply({
    id,
    token: answer.token,
    model: begin.model,
    expires_at: expiresAt.toISOString(),
    seconds: begin.seconds,
    left_seconds: begin.left_seconds,
    per_day_seconds: begin.per_day_seconds,
  });
});
