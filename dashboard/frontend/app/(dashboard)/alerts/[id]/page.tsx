// One regional alert. The view reads the id of the URL with useParams():
// with cacheComponents it must sit inside <Suspense>.
import { Suspense } from "react";

import { AlertView } from "./AlertView";

// Appears only after the admin check (AdminGuard, in the browser): no
// "instant navigation" check (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function AlertPage() {
  return (
    <Suspense fallback={<p className="text-slate-500">Chargement…</p>}>
      <AlertView />
    </Suspense>
  );
}
