"use client";

import { useAdmin } from "@/components/AdminGuard";
import { EmptyPage } from "@/components/EmptyPage";

export default function OverviewPage() {
  const admin = useAdmin();
  return (
    <EmptyPage
      title={`Welcome, ${admin.name}`}
      description="Key numbers of Looz will appear here."
    />
  );
}
