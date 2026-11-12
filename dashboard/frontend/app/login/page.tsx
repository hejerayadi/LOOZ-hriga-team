"use client";

// Login page: e-mail + password with Supabase Auth (texts in French).
// After login we ask the backend "who am I?" (GET /api/me):
// - OK      -> go to the dashboard
// - 401/403 -> log out and show "Access reserved to admins"
// "Connexion démo" (only when its switch is on in Supabase and the password
// is in backend/.env): the BACKEND logs the demo admin in and sends back
// only the session. The password never reaches the browser.
import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { demoLogin, demoLoginEnabled, errorMessage, getMe, isAccessDenied } from "@/lib/api";
import { supabase } from "@/lib/supabase";

const DENIED = "Accès réservé aux administrateurs.";

/** Supabase answers in English: the French message for the login page. */
function loginError(message: string): string {
  if (/invalid login credentials/i.test(message)) return "E-mail ou mot de passe incorrect.";
  if (/email not confirmed/i.test(message)) return "Cet e-mail n'est pas encore confirmé.";
  if (/fetch|network/i.test(message)) return "Impossible de joindre Supabase. Vérifiez la connexion.";
  return "Connexion impossible. Réessayez.";
}

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
  // Show "Connexion démo"? (asked once to the backend)
  const [demoOn, setDemoOn] = useState(false);

  useEffect(() => {
    let alive = true;
    demoLoginEnabled().then((on) => alive && setDemoOn(on));
    return () => {
      alive = false;
    };
  }, []);

  async function handleDemo() {
    setLoading(true);
    setError(null);
    try {
      // 1. The backend logs the demo admin in, 2. this browser keeps the session.
      const session = await demoLogin();
      const { error: setErr } = await supabase.auth.setSession({
        access_token: session.access_token,
        refresh_token: session.refresh_token,
      });
      if (setErr) throw setErr;
      await getMe();
      router.replace("/overview");
    } catch (e) {
      await supabase.auth.signOut();
      setError(errorMessage(e));
      setLoading(false);
    }
  }

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault(); // don't reload the page
    setLoading(true);
    setError(null);

    // 1. Log in with Supabase
    const { error: loginErr } = await supabase.auth.signInWithPassword({ email, password });
    if (loginErr) {
      setError(loginError(loginErr.message));
      setLoading(false);
      return;
    }

    // 2. Ask our backend if this user is an admin
    try {
      await getMe();
      router.replace("/overview");
    } catch (e) {
      await supabase.auth.signOut();
      setError(isAccessDenied(e) ? DENIED : errorMessage(e));
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm rounded-2xl border border-slate-200 bg-white p-8 shadow-sm"
      >
        <h1 className="text-2xl font-bold text-emerald-800">LOOZ · Administration</h1>
        <p className="mt-1 text-sm text-slate-500">Connectez-vous au tableau de bord</p>

        <label className="mt-6 block text-sm font-medium text-slate-700">
          E-mail
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
          Mot de passe
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
          {loading ? "Connexion…" : "Se connecter"}
        </button>

        {demoOn && (
          <div className="mt-6 border-t border-slate-200 pt-5">
            <button
              type="button"
              onClick={handleDemo}
              disabled={loading}
              className="w-full rounded-lg border border-violet-300 bg-violet-50 py-2.5 font-semibold text-violet-800 hover:bg-violet-100 disabled:opacity-60"
            >
              Connexion démo
            </button>
            <p className="mt-2 text-center text-xs text-slate-500">
              Compte de démonstration : seulement les données de démonstration, aucun réglage.
            </p>
          </div>
        )}
      </form>
    </main>
  );
}
