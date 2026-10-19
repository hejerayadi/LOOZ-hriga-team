"use client";

// Login page: e-mail + password with Supabase Auth.
// After login we ask the backend "who am I?" (GET /api/me):
// - OK      -> go to the dashboard
// - 401/403 -> log out and show "Access reserved to admins"
import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { getMe, isAccessDenied } from "@/lib/api";
import { supabase } from "@/lib/supabase";

const DENIED = "Access reserved to admins";

export default function LoginPage() {
  // useSearchParams() needs a <Suspense> around it.
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const router = useRouter();
  // "/login?denied=1" = we were sent here because the user is not an admin.
  const deniedFromUrl = useSearchParams().get("denied") === "1";

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(deniedFromUrl ? DENIED : null);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault(); // don't reload the page
    setLoading(true);
    setError(null);

    // 1. Log in with Supabase
    const { error: loginError } = await supabase.auth.signInWithPassword({ email, password });
    if (loginError) {
      setError(loginError.message);
      setLoading(false);
      return;
    }

    // 2. Ask our backend if this user is an admin
    try {
      await getMe();
      router.replace("/overview");
    } catch (e) {
      await supabase.auth.signOut();
      setError(isAccessDenied(e) ? DENIED : e instanceof Error ? e.message : "Unknown error");
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm rounded-2xl border border-slate-200 bg-white p-8 shadow-sm"
      >
        <h1 className="text-2xl font-bold text-emerald-800">Looz Admin</h1>
        <p className="mt-1 text-sm text-slate-500">Log in to the dashboard</p>

        <label className="mt-6 block text-sm font-medium text-slate-700">
          Email
          <input
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="mt-4 block text-sm font-medium text-slate-700">
          Password
          <input
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        {error && (
          <p className="mt-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="mt-6 w-full rounded-lg bg-emerald-700 py-2.5 font-semibold text-white hover:bg-emerald-800 disabled:opacity-60"
        >
          {loading ? "Logging in…" : "Log in"}
        </button>
      </form>
    </main>
  );
}
