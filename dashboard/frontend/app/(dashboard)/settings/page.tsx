// "Réglages": the switches of LOOZ.
import { SettingsView } from "./SettingsView";

// Appears only after the admin check (AdminGuard, in the browser): no
// "instant navigation" check (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function SettingsPage() {
  return <SettingsView />;
}
