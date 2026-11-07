// LOOZ — Edge Function "demo-auth": the DEMO LOGIN.
//
// While app_settings.demo_login_enabled = true (migration 010), ANY Tunisian
// number (+216 + 8 digits) and ANY 6-digit code log in, for sign in and for
// sign up: no SMS is sent. The app gets a normal Supabase session.
// !! Turn the switch OFF before a real launch (Table Editor > app_settings >
// demo_login_enabled = false): then the app uses the normal SMS code.
//
// The service_role key is given to this function by Supabase itself (a
// secret of the project): it is never in the app and never sent back.
// "Verify JWT" must be OFF for this function: the app calls it BEFORE the
// user is logged in. The function checks everything itself.
//
// The app sends (POST, JSON):
//   {"action": "start", "phone": "+21622123456", "signUp": true}
//     -> {"demo": false}             switch off: the app sends a real SMS code
//     -> {"demo": true}              no SMS: the app shows the code screen
//     -> {"error": "no_account"}     sign in with a number that has no account
//   {"action": "verify", "phone": "+21622123456", "code": "123456",
//    "signUp": true, "language": "ar"}
//     -> {"refresh_token": "...", "user_id": "..."}   logged in (the account
//                                    is made first for a new number + sign up)
//     -> {"error": "no_account" | "demo_off" | "not_allowed" | "too_many"}
//   Wrong request: HTTP 400 {"error": "bad_phone" | "bad_code" | "bad_request"}.
//   Problem on the server: HTTP 500 {"error": "server"}.

import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.45.4";

/** At most this many NEW accounts per hour by the demo login (whole app). */
const MAX_NEW_ACCOUNTS_PER_HOUR = 60;

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
const publicKey = projectKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS");
const noSession = { auth: { persistSession: false, autoRefreshToken: false } };

/** "+216 22 123 456" -> "+21622123456"; null = not a Tunisian number. */
function tunisianPhone(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const phone = value.replace(/[\s-]/g, "");
  return /^\+216[0-9]{8}$/.test(phone) ? phone : null;
}

/**
 * A long random password, set just before the login and never sent back:
 * the way for a server to open a phone account without an SMS. (Letters,
 * digits and a sign are added, for projects that ask for them.)
 */
function randomPassword(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)) + "aA1!";
}

type Check = {
  enabled: boolean;
  user_id: string | null;
  is_admin: boolean;
  new_accounts_last_hour: number;
};

/** What the database knows about this number (migration 010). */
async function checkPhone(
  admin: SupabaseClient,
  phone: string,
): Promise<Check | null> {
  const { data, error } = await admin.rpc("demo_login_check", {
    p_phone: phone,
  });
  if (error) {
    console.error("demo_login_check:", error.message);
    return null;
  }
  return ((Array.isArray(data) ? data[0] : data) as Check) ?? null;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  if (request.method !== "POST") return reply({ error: "bad_request" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return reply({ error: "bad_request" }, 400);
  }
  if (body.action !== "start" && body.action !== "verify") {
    return reply({ error: "bad_request" }, 400);
  }
  const phone = tunisianPhone(body.phone);
  if (!phone) return reply({ error: "bad_phone" }, 400);
  const signUp = body.signUp === true;
  const code = body.code;
  if (
    body.action === "verify" &&
    (typeof code !== "string" || !/^[0-9]{6}$/.test(code))
  ) {
    return reply({ error: "bad_code" }, 400);
  }

  const admin = createClient(url, serviceKey, noSession);
  const check = await checkPhone(admin, phone);
  if (!check) return reply({ error: "server" }, 500);

  // ----- The phone screen: "إرسال الرمز" -----
  if (body.action === "start") {
    // Switch off: nothing else is said (the app uses the SMS code).
    if (!check.enabled) return reply({ demo: false });
    if (!signUp && !check.user_id) return reply({ error: "no_account" });
    return reply({ demo: true });
  }

  // ----- The code screen: "تأكيد" (any 6 digits) -----
  if (!check.enabled) return reply({ error: "demo_off" });
  // Admins log in with their e-mail on the dashboard, never like this.
  if (check.is_admin) return reply({ error: "not_allowed" });

  let userId = check.user_id;
  if (!userId) {
    if (!signUp) return reply({ error: "no_account" });
    if (check.new_accounts_last_hour >= MAX_NEW_ACCOUNTS_PER_HOUR) {
      return reply({ error: "too_many" });
    }
    const created = await admin.auth.admin.createUser({
      phone,
      phone_confirm: true, // no SMS
      user_metadata: { language: body.language === "fr" ? "fr" : "ar" },
      app_metadata: { demo_login: true }, // counted by demo_login_check()
    });
    userId = created.data.user?.id ?? null;
    if (!userId) {
      // Made at the same moment by another call? Then it is there now.
      userId = (await checkPhone(admin, phone))?.user_id ?? null;
      if (!userId) {
        console.error("createUser:", created.error?.message);
        return reply({ error: "server" }, 500);
      }
    }
  }

  const password = randomPassword();
  const updated = await admin.auth.admin.updateUserById(userId, {
    password,
    phone_confirm: true,
  });
  if (updated.error) {
    console.error("updateUserById:", updated.error.message);
    return reply({ error: "server" }, 500);
  }

  // A normal login (with the public key, like the app): a normal session.
  const login = createClient(url, publicKey, noSession);
  const signedIn = await login.auth.signInWithPassword({ phone, password });
  const session = signedIn.data.session;
  if (signedIn.error || !session) {
    if (signedIn.error?.status === 429) return reply({ error: "too_many" });
    console.error("signInWithPassword:", signedIn.error?.message);
    return reply({ error: "server" }, 500);
  }
  return reply({
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_in: session.expires_in,
    user_id: session.user.id,
  });
});
