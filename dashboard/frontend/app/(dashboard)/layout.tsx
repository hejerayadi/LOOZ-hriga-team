// The frame of every dashboard page: sidebar on the left, top bar, content.
// "(dashboard)" in parentheses = a folder that groups pages without
// changing the URL (the page is /users, not /dashboard/users).
import { AdminGuard } from "@/components/AdminGuard";
import { Sidebar } from "@/components/Sidebar";
import { Topbar } from "@/components/Topbar";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <AdminGuard>
      <div className="flex min-h-screen">
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col">
          <Topbar />
          <main className="flex-1 p-6">{children}</main>
        </div>
      </div>
    </AdminGuard>
  );
}
