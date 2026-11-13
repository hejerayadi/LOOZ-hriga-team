"use client";

// The menu on the left. The current page is highlighted.
import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/overview", label: "Vue d'ensemble" },
  { href: "/farmers", label: "Agriculteurs" },
  { href: "/users", label: "Utilisateurs" },
  { href: "/community", label: "Communauté" },
  { href: "/alerts", label: "Alertes" },
  { href: "/orchards", label: "Vergers" },
  { href: "/sensors", label: "Capteurs" },
  { href: "/subscriptions", label: "Abonnements" },
  { href: "/settings", label: "Réglages" },
  { href: "/journal", label: "Journal des actions" },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex w-44 shrink-0 flex-col border-r border-slate-200 bg-white xl:w-56">
      <div className="px-5 py-5 text-xl font-bold text-emerald-800 xl:px-6">LOOZ Admin</div>
      <nav className="flex flex-col gap-1 px-2 xl:px-3">
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
