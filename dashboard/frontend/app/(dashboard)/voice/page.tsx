// "Assistant vocal" (read only).
import { VoiceView } from "./VoiceView";

// The page appears only after the admin check (AdminGuard, in the browser):
// Next.js cannot prerender it, so it does not check "instant navigation"
// here (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function VoicePage() {
  return <VoiceView />;
}
