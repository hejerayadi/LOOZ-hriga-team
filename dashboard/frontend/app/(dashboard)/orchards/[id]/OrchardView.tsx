"use client";

// One orchard (read only): the plan seen from above (zones, trees, boxes),
// its zones, and what the farmer pays for one period at the current price.
import { useCallback } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";

import { OrchardPlan, PackText, StatusBadge } from "@/components/iot";
import { Card, DemoTag, Empty, ErrorBox, Fact } from "@/components/ui";
import { errorMessage, getOrchard } from "@/lib/api";
import { age, date, money, num, phone } from "@/lib/format";
import { GOVERNORATES, ORCHARD_STATUS, ZONE_TYPE, label, personName, zoneName } from "@/lib/labels";
import type { OrchardDetail } from "@/lib/types";
import { usePolling } from "@/lib/usePolling";

const TH = "px-3 py-2 font-medium";
const HEAD = "border-y border-slate-200 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500";

function Details({ d }: { d: OrchardDetail }) {
  const o = d.orchard;
  const boxOf = (zoneId: string) => d.boxes.find((b) => b.zone_id === zoneId);
  return (
    <>
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="text-2xl font-bold text-slate-900">Verger de {personName(o.farmer_name, "Sans nom")}</h1>
        <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${o.status === "complete" ? "bg-emerald-50 text-emerald-800" : "bg-amber-50 text-amber-800"}`}>
          {label(ORCHARD_STATUS, o.status)}
        </span>
        {o.demo && <DemoTag />}
      </div>
      <p className="mt-1 text-sm text-slate-500">
        {[o.farmer_phone ? phone(o.farmer_phone) : null, label(GOVERNORATES, o.governorate)].filter(Boolean).join(" · ")} ·{" "}
        <Link href={`/farmers/${o.farmer_id}`} className="font-medium text-emerald-800 hover:underline">
          page de l&apos;agriculteur
        </Link>{" "}
        ·{" "}
        <Link href={`/users/${o.farmer_id}`} className="font-medium text-emerald-800 hover:underline">
          compte
        </Link>
      </p>
      {o.status === "draft" && (
        <p className="mt-3 rounded-lg bg-amber-50 px-4 py-2 text-sm text-amber-900">
          Brouillon : l&apos;agriculteur n&apos;a pas encore terminé son dessin
          {d.draft_zones ? ` (${d.draft_zones} zone${d.draft_zones > 1 ? "s" : ""} dessinée${d.draft_zones > 1 ? "s" : ""})` : ""}. Le plan montre son dessin actuel.
        </p>
      )}

      <div className="mt-6 grid gap-6 xl:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
        <Card title="Plan (vu du dessus)">
          {d.outline.length || d.zones.length ? (
            <OrchardPlan outline={d.outline} zones={d.zones} trees={d.trees} boxes={d.boxes} className="h-96 w-full" />
          ) : (
            <Empty>Pas encore de plan.</Empty>
          )}
          {d.trees.length === 0 && o.trees > 0 && <p className="mt-2 text-xs text-slate-500">Trop d&apos;arbres pour les dessiner un par un : seules les zones sont montrées.</p>}
        </Card>
        <div className="space-y-6">
          <Card title="Verger">
            <div className="grid grid-cols-2 gap-4">
              <Fact name="Surface" value={o.area_ha === null ? "—" : `${num(o.area_ha, 2)} ha`} />
              <Fact name="Zones" value={o.zones} />
              <Fact name="Arbres" value={o.trees} />
              <Fact name="Boîtiers acceptés" value={`${o.boxes_accepted} / ${o.boxes}`} />
              <Fact name="Dessiné avec" value={o.draw_mode === "map" ? "la carte" : "la grille"} />
              <Fact name={o.completed_at ? "Construit le" : "Commencé le"} value={date(o.completed_at ?? o.created_at)} />
            </div>
          </Card>
          <Card title="Pack et facture">
            <div className="grid grid-cols-2 gap-4">
              <Fact name="Pack" value={<PackText pack={o.pack} />} />
              <Fact name="Boîtiers payés" value={o.pack.nodes ?? "—"} />
            </div>
            {d.bill ? (
              <div className="mt-4 rounded-lg bg-slate-50 px-4 py-3 text-sm text-slate-700">
                <div className="font-semibold text-slate-900">
                  Une période ({d.bill.period_days} jours) au prix actuel : {money(d.bill.amount_millimes)}
                </div>
                <div className="mt-1">
                  {d.bill.billed_nodes} boîtier{d.bill.billed_nodes > 1 ? "s" : ""} facturé{d.bill.billed_nodes > 1 ? "s" : ""} × {money(d.bill.price_millimes)}
                </div>
                <div className="mt-1 text-xs text-slate-500">
                  Boîtiers facturés = les zones ({o.zones}), au moins {d.bill.min_nodes_by_area} pour la surface (règle « hectares par boîtier »), jamais moins de 1.
                </div>
              </div>
            ) : (
              <p className="mt-4 text-sm text-slate-500">Facture : quand le verger sera construit.</p>
            )}
          </Card>
        </div>
      </div>

      <div className="mt-6">
        <Card title="Zones">
          {!d.zones.length ? (
            <Empty>Aucune zone.</Empty>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className={HEAD}>
                  <tr>
                    <th className={TH}>Zone</th>
                    <th className={TH}>Type</th>
                    <th className={TH}>Variété et âge</th>
                    <th className={TH}>Arbres</th>
                    <th className={TH}>Boîtier</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {d.zones.map((z) => {
                    const box = boxOf(z.id);
                    return (
                      <tr key={z.id}>
                        <td className="px-3 py-2 font-medium text-slate-900">
                          <span className="mr-2 inline-block h-3 w-3 rounded-sm align-middle" style={{ background: z.color ?? "#cbd5e1" }} />
                          {zoneName(z.letter, z.name)}
                        </td>
                        <td className="px-3 py-2 text-slate-700">{label(ZONE_TYPE, z.zone_type)}</td>
                        <td className="px-3 py-2 text-slate-700">{[z.cultivar, age(z.planted_year)].filter(Boolean).join(" · ") || "—"}</td>
                        <td className="px-3 py-2 tabular-nums text-slate-700">{z.tree_count ?? "—"}</td>
                        <td className="px-3 py-2">
                          {box ? (
                            <span className="flex flex-wrap items-center gap-2">
                              <span className="font-mono text-slate-900">{box.device_code ?? "sans code"}</span>
                              <StatusBadge status={box.status} />
                            </span>
                          ) : (
                            <span className="text-slate-400">—</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </>
  );
}

export function OrchardView() {
  const { id } = useParams<{ id: string }>();
  const load = useCallback(() => getOrchard(id), [id]);
  const { data, error, reload } = usePolling<OrchardDetail>(load, 60000);
  return (
    <div>
      <Link href="/orchards" className="text-sm font-medium text-emerald-800 hover:underline">
        ← Vergers
      </Link>
      <div className="mt-3">
        {error !== null && <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />}
        {!data && error === null && <p className="text-slate-500">Chargement…</p>}
        {data && <Details d={data} />}
      </div>
    </div>
  );
}
