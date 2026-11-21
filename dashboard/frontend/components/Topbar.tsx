"use client";

// The bar at the top: where the page is in the menu, the admin's name and
// "Se déconnecter". With "Connexion démo": a violet tag "Compte de
// démonstration" (demo accounts only).
import { usePathname, useRouter } from "next/navigation";

import { personName } from "@/lib/labels";
import { supabase } from "@/lib/supabase";
import { useAdmin } from "./AdminGuard";
import { Icon } from "./Icon";
import { pagePlace } from "./Sidebar";

export function Topbar() {
  const admin = useAdmin();
  const router = useRouter();
  const pathname = usePathname();
  const [group, page] = pagePlace(pathname);

  async function logout() {
    await supabase.auth.signOut();
    router.replace("/login");
  }

  return (
    <header className="sticky top-0 z-20 flex h-16 shrink-0 items-center gap-4 border-b border-emerald-100 bg-looz-cream/90 px-4 backdrop-blur xl:px-8">
      <nav aria-label="Fil d'Ariane" className="flex min-w-0 items-center gap-2 text-sm">
        <span className="hidden truncate text-slate-500 md:inline">{group}</span>
        {page && <span className="hidden text-slate-300 md:inline">›</span>}
        <span className="truncate font-bold text-emerald-800">{page}</span>
      </nav>
      {admin.demo_admin && (
        <span
          className="whitespace-nowrap rounded-full bg-violet-50 px-3 py-1 text-xs font-semibold text-violet-800 ring-1 ring-violet-200"
          title="Seuls les comptes de démonstration sont affichés ; les actions touchent seulement les données de démonstration."
        >
          Compte de démonstration<span className="hidden xl:inline"> · données de démo uniquement</span>
        </span>
      )}
      <span className="ml-auto flex items-center gap-2 whitespace-nowrap text-sm text-slate-700">
        <span className="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 font-bold text-emerald-800">
          {personName(admin.name).slice(0, 1).toUpperCase()}
        </span>
        <span className="hidden sm:inline">
          <span className="font-semibold">{personName(admin.name)}</span>
          {admin.email && <span className="hidden text-slate-400 lg:inline"> · {admin.email}</span>}
        </span>
      </span>
      <button
        onClick={logout}
        className="flex items-center gap-1.5 whitespace-nowrap rounded-xl border border-emerald-200 bg-white px-3 py-1.5 text-sm font-semibold text-emerald-800 hover:bg-emerald-50"
      >
        <Icon name="logout" className="h-4 w-4" />
        <span className="hidden sm:inline">Se déconnecter</span>
      </button>
    </header>
  );
}
