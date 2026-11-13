"use client";

// "Vergers": every orchard (owner, governorate, area, zones, trees, boxes,
// built or draft). Read only: the farmer draws his orchard in the app.
import { useCallback, useState } from "react";
import Link from "next/link";

import { PackText } from "@/components/iot";
import { DemoTag, Empty, ErrorBox } from "@/components/ui";
import { errorMessage, getOrchards } from "@/lib/api";
import { date, num, phone } from "@/lib/format";
import { GOVERNORATES, ORCHARD_STATUS, label, personName } from "@/lib/labels";
import type { OrchardsPage } from "@/lib/types";
import { usePolling } from "@/lib/usePolling";

type Show = "all" | "complete" | "draft";
const TH = "px-3 py-2 font-medium";
const HEAD = "border-y border-slate-200 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500";

export function OrchardsView() {
  const [show, setShow] = useState<Show>("all");
  const [typed, setTyped] = useState("");
  const load = useCallback(() => getOrchards(), []);
  const { data, error, reload } = usePolling<OrchardsPage>(load, 60000);

  const all = data?.orchards ?? [];
  const q = typed.trim().toLowerCase();
  const digits = q.replace(/\D/g, "");
  const orchards = all.filter(
    (o) =>
      (show === "all" || o.status === show) &&
      (!q || o.farmer_name.toLowerCase().includes(q) || label(GOVERNORATES, o.governorate).toLowerCase().includes(q) || (digits.length >= 3 && (o.farmer_phone ?? "").includes(digits))),
  );
  const area = all.reduce((s, o) => s + (o.area_ha ?? 0), 0);

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Vergers</h1>
      <p className="mt-1 text-slate-500">Les vergers dessinés par les agriculteurs dans l&apos;application (lecture seule).</p>
      {error !== null && (
        <div className="mt-4">
          <ErrorBox message={(data ? "Liste non mise à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      {!data && error === null && <p className="mt-6 text-slate-500">Chargement…</p>}
      {data && (
        <div className="mt-5 rounded-xl border border-slate-200 bg-white p-4">
          <div className="flex flex-wrap gap-2 text-sm">
            <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">{all.length} vergers</span>
            <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">{num(area, 2)} ha au total</span>
            <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">{all.reduce((s, o) => s + o.trees, 0)} arbres</span>
            <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">{all.reduce((s, o) => s + o.boxes, 0)} boîtiers</span>
          </div>
          <div className="mt-4 flex flex-wrap items-center gap-2">
            {(["all", "complete", "draft"] as Show[]).map((s) => (
              <button
                key={s}
                type="button"
                aria-pressed={show === s}
                onClick={() => setShow(s)}
                className={`rounded-full px-3 py-1 text-sm font-medium ${show === s ? "bg-emerald-700 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200"}`}
              >
                {s === "all" ? "Tous" : s === "complete" ? "Construits" : "Brouillons"} ({s === "all" ? all.length : all.filter((o) => o.status === s).length})
              </button>
            ))}
            <input
              type="search"
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              placeholder="Agriculteur, téléphone ou gouvernorat"
              aria-label="Rechercher un agriculteur, un téléphone ou un gouvernorat"
              className="ml-auto w-full max-w-xs rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
            />
          </div>
          <div className="mt-4">
            {!orchards.length ? (
              <Empty>{all.length ? "Aucun verger ne correspond." : "Aucun verger pour l'instant."}</Empty>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className={HEAD}>
                    <tr>
                      <th className={TH}>Verger de</th>
                      <th className={TH}>Taille</th>
                      <th className={TH}>Boîtiers</th>
                      <th className={TH}>Pack</th>
                      <th className={TH}>État</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {orchards.map((o) => (
                      <tr key={o.id} className="align-top">
                        <td className="px-3 py-2.5">
                          <Link href={`/orchards/${o.id}`} className="font-semibold text-slate-900 hover:text-emerald-800">
                            {personName(o.farmer_name, "Sans nom")}
                          </Link>
                          {o.demo && <span className="ml-1.5"><DemoTag /></span>}
                          <div className="whitespace-nowrap text-xs text-slate-500">
                            {[o.farmer_phone ? phone(o.farmer_phone) : null, label(GOVERNORATES, o.governorate)].filter(Boolean).join(" · ")}
                          </div>
                        </td>
                        <td className="whitespace-nowrap px-3 py-2.5 text-slate-700">
                          <div className="font-medium text-slate-900">{o.area_ha === null ? "—" : `${num(o.area_ha, 2)} ha`}</div>
                          <div className="text-xs text-slate-500">
                            {o.zones} zone{o.zones > 1 ? "s" : ""} · {o.trees} arbre{o.trees > 1 ? "s" : ""}
                          </div>
                        </td>
                        <td className="whitespace-nowrap px-3 py-2.5 text-slate-700">
                          {o.boxes_accepted} / {o.boxes} acceptés
                        </td>
                        <td className="px-3 py-2.5 text-xs">
                          <PackText pack={o.pack} compact />
                        </td>
                        <td className="whitespace-nowrap px-3 py-2.5">
                          <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${o.status === "complete" ? "bg-emerald-50 text-emerald-800" : "bg-amber-50 text-amber-800"}`}>
                            {label(ORCHARD_STATUS, o.status)}
                          </span>
                          <div className="mt-1 text-xs text-slate-500">
                            {o.completed_at ? `construit le ${date(o.completed_at)}` : `commencé le ${date(o.created_at)}`}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
