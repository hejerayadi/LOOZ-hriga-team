"use client";

// The bar at the top: admin name + Logout button.
import { useRouter } from "next/navigation";

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
      <span className="text-sm text-slate-700">
        <span className="font-semibold">{admin.name}</span>
        {admin.email && <span className="text-slate-400"> · {admin.email}</span>}
      </span>
      <button
        onClick={logout}
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-100"
      >
        Logout
      </button>
    </header>
  );
}
