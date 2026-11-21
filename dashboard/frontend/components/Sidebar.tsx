"use client";

// The menu on the left, in groups, with the LOOZ logo and the app's dark
// green. On a tablet (narrower than 1280 px) it shows the icons only (the
// name appears on hover); the button at the top opens it in full.
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import { Icon } from "./Icon";

export const NAV = [
  { group: "Pilotage", links: [{ href: "/overview", label: "Vue d'ensemble", icon: "overview" }] },
  {
    group: "Agriculteurs et vergers",
    links: [
      { href: "/farmers", label: "Agriculteurs", icon: "farmers" },
      { href: "/orchards", label: "Vergers", icon: "orchards" },
      { href: "/sensors", label: "Capteurs", icon: "sensors" },
      { href: "/predictions", label: "Prédictions IA", icon: "predictions" },
    ],
  },
  {
    group: "Services de l'application",
    links: [
      { href: "/alerts", label: "Alertes", icon: "alerts" },
      { href: "/diagnoses", label: "Diagnostics photo", icon: "camera" },
      { href: "/voice", label: "Assistant vocal", icon: "voice" },
      { href: "/community", label: "Communauté", icon: "community" },
    ],
  },
  {
    group: "Comptes et ventes",
    links: [
      { href: "/users", label: "Utilisateurs", icon: "users" },
      { href: "/subscriptions", label: "Abonnements", icon: "subscriptions" },
    ],
  },
  {
    group: "Administration",
    links: [
      { href: "/settings", label: "Réglages", icon: "settings" },
      { href: "/journal", label: "Journal des actions", icon: "journal" },
    ],
  },
];

/** Where this page is in the menu (the top bar): [group, page]. */
export function pagePlace(pathname: string): [string, string] {
  for (const g of NAV) for (const l of g.links) if (pathname.startsWith(l.href)) return [g.group, l.label];
  return ["LOOZ", ""];
}

export function Sidebar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);   // tablet: the full menu

  return (
    <aside
      className={`shrink-0 self-stretch bg-emerald-800 text-emerald-50 transition-[width] ${
        open ? "w-60" : "w-16 xl:w-60"
      }`}
    >
      <div className="sticky top-0 flex h-screen flex-col">
      <div className="flex items-center gap-3 px-3 pb-3 pt-4 xl:px-5">
        <button
          type="button"
          onClick={() => setOpen(!open)}
          className="rounded-lg p-2 text-emerald-100 hover:bg-white/10 xl:hidden"
          aria-label={open ? "Réduire le menu" : "Ouvrir le menu"}
        >
          <Icon name="menu" />
        </button>
        <Link href="/overview" className={`items-center gap-3 ${open ? "flex" : "hidden xl:flex"}`}>
          <Image src="/looz_logo_white.png" alt="LOOZ" width={34} height={56} priority />
          <span className="leading-tight">
            <span className="block text-lg font-extrabold tracking-wide text-white">LOOZ</span>
            <span className="block text-xs text-emerald-200">Administration</span>
          </span>
        </Link>
      </div>
      <nav className="flex-1 overflow-y-auto px-2 pb-6 xl:px-3" aria-label="Menu principal">
        {NAV.map((g) => (
          <div key={g.group} className="mt-4 first:mt-1">
            <div className={`px-3 pb-1 text-[11px] font-semibold uppercase tracking-wider text-emerald-300/80 ${open ? "block" : "hidden xl:block"}`}>
              {g.group}
            </div>
            {g.links.map((link) => {
              const active = pathname.startsWith(link.href);
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  title={link.label}
                  aria-current={active ? "page" : undefined}
                  className={`group relative flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-semibold ${
                    active ? "bg-white/12 text-white" : "text-emerald-100/85 hover:bg-white/8 hover:text-white"
                  }`}
                >
                  {active && <span className="absolute inset-y-1.5 left-0 w-1 rounded-full bg-looz-leaf" />}
                  <Icon name={link.icon} className={`h-5 w-5 shrink-0 ${active ? "text-looz-leaf" : ""}`} />
                  <span className={open ? "inline" : "hidden xl:inline"}>{link.label}</span>
                </Link>
              );
            })}
          </div>
        ))}
      </nav>
      </div>
    </aside>
  );
}
