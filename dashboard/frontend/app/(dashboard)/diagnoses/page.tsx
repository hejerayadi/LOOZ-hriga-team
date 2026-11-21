// "Diagnostics photo" (read only).
import { DiagnosesView } from "./DiagnosesView";

// The page appears only after the admin check (AdminGuard, in the browser):
// Next.js cannot prerender it, so it does not check "instant navigation"
// here (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function DiagnosesPage() {
  return <DiagnosesView />;
}
