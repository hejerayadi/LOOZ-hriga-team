// "Alertes": the view reads ?tab= with useSearchParams(): with
// cacheComponents it must sit inside <Suspense>.
import { Suspense } from "react";

import { AlertsView } from "./AlertsView";

// Appears only after the admin check (AdminGuard, in the browser): no
// "instant navigation" check (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function AlertsPage() {
  return (
    <Suspense fallback={<p className="text-slate-500">Chargement…</p>}>
      <AlertsView />
    </Suspense>
  );
}
