// "Utilisateurs": the view reads ?state= with useSearchParams(): with
// cacheComponents it must sit inside <Suspense>.
import { Suspense } from "react";

import { UsersView } from "./UsersView";

// The page appears only after the admin check (AdminGuard, in the browser):
// Next.js cannot prerender it, so it does not check "instant navigation"
// here (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function UsersPage() {
  return (
    <Suspense fallback={<p className="text-slate-500">Chargement…</p>}>
      <UsersView />
    </Suspense>
  );
}
