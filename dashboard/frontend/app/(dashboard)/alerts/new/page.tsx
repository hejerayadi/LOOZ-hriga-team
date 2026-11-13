// A new regional alert.
import Link from "next/link";

import { AlertEditor } from "../AlertEditor";

// Appears only after the admin check (AdminGuard, in the browser): no
// "instant navigation" check (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function NewAlertPage() {
  return (
    <div>
      <Link href="/alerts" className="text-sm font-medium text-emerald-800 hover:underline">
        ← Alertes
      </Link>
      <h1 className="mt-3 text-2xl font-bold text-slate-900">Nouvelle alerte régionale</h1>
      <p className="mb-5 mt-1 text-slate-500">En arabe simple et en français. L&apos;aperçu montre l&apos;écran des agriculteurs.</p>
      <AlertEditor />
    </div>
  );
}
