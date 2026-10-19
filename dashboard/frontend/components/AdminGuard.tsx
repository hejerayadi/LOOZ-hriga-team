"use client";

// Protects every dashboard page:
// - not logged in          -> go to /login
// - logged in, not admin   -> log out, go to /login with "Access reserved to admins"
// - admin                  -> show the page, and share the admin's profile
//                             with every component (useAdmin()).
//
// Note: the REAL protection is the backend (it refuses non-admins).
// This guard only avoids showing an empty dashboard to the wrong people.
import { createContext, useContext, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { getMe, isAccessDenied } from "@/lib/api";
import { supabase } from "@/lib/supabase";
import type { Profile } from "@/lib/types";

const AdminContext = createContext<Profile | null>(null);

/** The logged-in admin (only inside dashboard pages). */
export function useAdmin(): Profile {
  const admin = useContext(AdminContext);
  if (!admin) throw new Error("useAdmin must be used inside <AdminGuard>");
  return admin;
}

export function AdminGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [admin, setAdmin] = useState<Profile | null>(null);
  const [error, setError] = useState<string | null>(null);
  // +1 on "Retry": runs the check again.
  const [attempt, setAttempt] = useState(0);
  // true once we are sending the user away (avoids 2 redirects at once).
  const leaving = useRef(false);

  // Ask the backend who we are.
  useEffect(() => {
    async function check() {
      const { data } = await supabase.auth.getSession();
      if (!data.session) {
        router.replace("/login");
        return;
      }
      try {
        setAdmin(await getMe());
      } catch (e) {
        if (isAccessDenied(e)) {
          leaving.current = true;
          await supabase.auth.signOut();
          router.replace("/login?denied=1");
        } else {
          setError(e instanceof Error ? e.message : "Unknown error");
        }
      }
    }
    check();
  }, [attempt, router]);

  // Logged out (button, or in another tab) -> back to the login page.
  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_OUT" && !leaving.current) router.replace("/login");
    });
    return () => data.subscription.unsubscribe();
  }, [router]);

  if (error) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
        <p className="text-red-600">{error}</p>
        <button
          onClick={() => {
            setError(null);
            setAttempt((n) => n + 1);
          }}
          className="rounded-lg bg-emerald-700 px-4 py-2 font-medium text-white hover:bg-emerald-800"
        >
          Retry
        </button>
      </div>
    );
  }

  if (!admin) {
    return (
      <div className="flex min-h-screen items-center justify-center text-slate-500">
        Loading…
      </div>
    );
  }

  return <AdminContext.Provider value={admin}>{children}</AdminContext.Provider>;
}
