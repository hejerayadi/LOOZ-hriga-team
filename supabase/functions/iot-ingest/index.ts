// LOOZ — Edge Function "iot-ingest": receives the readings of a farm gateway.
//
// The gateway (Node-RED on the farm, iot/node-red) sends about once a minute:
//   POST, header  x-looz-gateway-key: lgw_<64 letters/digits>   (its secret key)
//         body    {"gateway": "GW-01", "sent_at": "...", "readings": [ ... ]}
// The function hashes the key (sha256) and gives the batch to the database:
// iot_ingest() of migration 012 checks EVERYTHING (the key, each box in the
// gateway's own orchard, the admin's acceptance, the paid pack, the values)
// and saves the readings. Answers:
//   200 {"accepted", "history", "events", "old", "restarts", "refused", "refused_devices"}
//   400 {"error": "bad_json" | "bad_batch"}       401 {"error": "bad_key"}
//   405 not a POST    413 {"error": "too_big"}    503 {"error": "ingest_off"}
//   500 {"error": "server"}
//
// - The key is never written in the logs and never sent back. Supabase keeps
//   only its hash (gateways.key_hash).
// - The service_role key is given to this function by Supabase itself (a
//   secret of the project): it never leaves Supabase.
// - "Verify JWT" must be OFF: the gateway has no Supabase login, the key is
//   checked here and in the database.
// - Not for browsers: no CORS headers.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

/** A batch is at most this big (about 500 readings). */
const MAX_BYTES = 256 * 1024;

function reply(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
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

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  projectKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS"),
  { auth: { persistSession: false, autoRefreshToken: false } },
);

/** sha256 of the key, in hexadecimal (what gateways.key_hash keeps). */
async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply({ error: "bad_request" }, 405);

  // 1. The key: checked before reading anything else.
  const key = request.headers.get("x-looz-gateway-key") ?? "";
  if (!/^lgw_[0-9a-f]{64}$/.test(key)) return reply({ error: "bad_key" }, 401);

  // 2. The batch: small, JSON, an object.
  if (Number(request.headers.get("content-length") ?? "0") > MAX_BYTES) {
    return reply({ error: "too_big" }, 413);
  }
  let text: string;
  try {
    text = await request.text();
  } catch {
    return reply({ error: "bad_json" }, 400);
  }
  if (new TextEncoder().encode(text).length > MAX_BYTES) {
    return reply({ error: "too_big" }, 413);
  }
  let batch: unknown;
  try {
    batch = JSON.parse(text);
  } catch {
    return reply({ error: "bad_json" }, 400);
  }
  if (!batch || typeof batch !== "object" || Array.isArray(batch)) {
    return reply({ error: "bad_batch" }, 400);
  }

  // 3. The database checks and saves (one call).
  const { data, error } = await admin.rpc("iot_ingest", {
    p_key_hash: await sha256Hex(key),
    p_batch: batch,
  });
  if (error) {
    if (error.code === "PT401") return reply({ error: "bad_key" }, 401);
    if (error.code === "PT503") return reply({ error: "ingest_off" }, 503);
    if (error.code === "22023") {
      return reply({ error: "bad_batch", detail: error.message }, 400);
    }
    console.error("iot_ingest:", error.code, error.message);
    return reply({ error: "server" }, 500);
  }

  const result = (data ?? {}) as Record<string, unknown>;
  const gateway = String((batch as Record<string, unknown>).gateway ?? "?")
    .slice(0, 32)
    .replace(/[^A-Za-z0-9_-]/g, "?");
  console.log(
    `${gateway}: ${result.accepted} accepted, ${result.old} old, refused ${
      JSON.stringify(result.refused ?? {})
    }`,
  );
  return reply(result, 200);
});
