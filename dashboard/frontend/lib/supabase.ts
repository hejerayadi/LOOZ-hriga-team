// Supabase in the browser. Used ONLY for login / logout.
// All the data goes through our backend (see lib/api.ts).
import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  throw new Error(
    "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY in .env.local",
  );
}

// Remembers the session in the browser, and renews the token by itself.
export const supabase = createClient(url, anonKey);
