"use client";

// The bar at the top: admin name + "Se déconnecter". With "Connexion démo":
// a violet tag "Compte de démonstration" (demo accounts only).
import { useRouter } from "next/navigation";

import { personName } from "@/lib/labels";
import { supabase } from "@/lib/supabase";
import { useAdmin } from "./AdminGuard";

export function Topbar() {
  const admin = useAdmin();
  const router = useRouter();

  async function logout() {
    await supabase.auth.signOut();
    router.replace("/login");
  }

  return (
    <header className="flex h-16 shrink-0 items-center justify-end gap-4 border-b border-slate-200 bg-white px-6">
      {admin.demo_admin && (
        <span
          className="mr-auto whitespace-nowrap rounded-full bg-violet-50 px-3 py-1 text-xs font-medium text-violet-800 ring-1 ring-violet-200"
          title="Seuls les comptes de démonstration sont affichés ; les actions touchent seulement les données de démonstration."
        >
          Compte de démonstration<span className="hidden xl:inline"> · données de démo uniquement</span>
        </span>
      )}
      <span className="whitespace-nowrap text-sm text-slate-700">
        <span className="font-semibold">{personName(admin.name)}</span>
        {admin.email && <span className="hidden text-slate-400 lg:inline"> · {admin.email}</span>}
      </span>
      <button
        onClick={logout}
        className="whitespace-nowrap rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-100"
      >
        Se déconnecter
      </button>
    </header>
  );
}
