// One farmer: his orchard, gateway, zones and sensor boxes (live).
// The view reads the id of the URL with useParams(): with cacheComponents
// it must sit inside <Suspense> (see node_modules/next/dist/docs, useParams).

import { Suspense } from "react";

import { FarmerView } from "./FarmerView";

// The page appears only after the admin check (AdminGuard, in the browser):
// Next.js cannot prerender it, so it does not check "instant navigation"
// here (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function FarmerPage() {
  return (
    <Suspense fallback={<p className="text-slate-500">Chargement…</p>}>
      <FarmerView />
    </Suspense>
  );
}
