import { EmptyPage } from "@/components/EmptyPage";

// Not built yet. "instant = false": the page appears only after the admin
// check (AdminGuard, in the browser), so Next.js does not check "instant
// navigation" here (node_modules/next/dist/docs/01-app/02-guides/instant-navigation.md).
export const instant = false;

export default function CommunityPage() {
  return <EmptyPage title="Communauté" description="Questions et réponses, modération." />;
}
