"use client";

// The menu on the left. The current page is highlighted.
import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/overview", label: "Overview" },
  { href: "/users", label: "Users" },
  { href: "/community", label: "Community" },
  { href: "/alerts", label: "Alerts" },
  { href: "/orchards", label: "Orchards" },
  { href: "/sensors", label: "Sensors" },
  { href: "/subscriptions", label: "Subscriptions" },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex w-56 shrink-0 flex-col border-r border-slate-200 bg-white">
      <div className="px-6 py-5 text-xl font-bold text-emerald-800">Looz Admin</div>
      <nav className="flex flex-col gap-1 px-3">
        {LINKS.map((link) => {
          const active = pathname.startsWith(link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              className={
                "rounded-lg px-3 py-2 text-sm font-medium " +
                (active
                  ? "bg-emerald-50 text-emerald-800"
                  : "text-slate-600 hover:bg-slate-100 hover:text-slate-900")
              }
            >
              {link.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
