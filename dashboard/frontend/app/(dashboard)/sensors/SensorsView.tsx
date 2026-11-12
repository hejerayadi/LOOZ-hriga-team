"use client";

// "Capteurs": every sensor box (the waiting ones first), the installation
// visits, the gateways, and the latest admin actions on them. Again every
// 30 s while the page is visible. ?tab=waiting|visits|gateways|log opens a tab.
import { useCallback, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { ActionList, BoxActionButton, GatewayButtons, VisitDialog, type VisitTarget } from "@/components/actions";
import { LevelBadge, StatusBadge } from "@/components/iot";
import { Button, DemoTag, Empty, ErrorBox, Tabs } from "@/components/ui";
import { errorMessage, getSensors } from "@/lib/api";
import { date, dateTime, num, phone, signal, timeAgo } from "@/lib/format";
import { FAULT, GOVERNORATES, REFUSAL, VISIT, label, personName } from "@/lib/labels";
import type { GatewayRow, SensorBox, SensorsPage, VisitRow } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";

type Tab = "all" | "waiting" | "visits" | "gateways" | "log";
const TABS: Tab[] = ["all", "waiting", "visits", "gateways", "log"];

const TH = "px-3 py-2 font-medium";
const HEAD = "border-y border-slate-200 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500";

function Farmer({ name, id, phoneNumber, governorate, demo }: { name: string; id: string | null; phoneNumber?: string | null; governorate?: string | null; demo: boolean }) {
  return (
    <div>
      {id ? (
        <Link href={`/farmers/${id}`} className="whitespace-nowrap font-semibold text-slate-900 hover:text-emerald-800">
          {personName(name, "Sans nom")}
        </Link>
      ) : (
        <span className="whitespace-nowrap font-semibold text-slate-900">{personName(name, "Sans nom")}</span>
      )}
      {demo && <span className="ml-1.5"><DemoTag /></span>}
      {(phoneNumber || governorate) && (
        <div className="whitespace-nowrap text-xs text-slate-500">
          {[phoneNumber ? phone(phoneNumber) : null, governorate ? label(GOVERNORATES, governorate) : null].filter(Boolean).join(" · ")}
        </div>
      )}
    </div>
  );
}

function BoxTable({ boxes, now, onChanged, empty }: { boxes: SensorBox[]; now: number; onChanged: () => void; empty: string }) {
  if (!boxes.length) return <Empty>{empty}</Empty>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className={HEAD}>
          <tr>
            <th className={TH}>Boîtier</th>
            <th className={TH}>Agriculteur</th>
            <th className={TH}>État</th>
            <th className={TH}>Dernière donnée</th>
            <th className={TH}>Niveau</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {boxes.map((b) => {
            const refused = b.last_refused_at && (!b.received_at || b.last_refused_at > b.received_at);
            return (
              <tr key={b.node_id} className="align-top">
                <td className="whitespace-nowrap px-3 py-2.5">
                  <div className="font-mono font-semibold text-slate-900">{b.device_code ?? "sans code"}</div>
                  <div className="text-xs text-slate-500">zone {b.zone_letter ?? "?"}</div>
                  {b.battery_pct !== null && (
                    <div className={`text-xs ${b.battery_pct < 20 ? "font-semibold text-rose-700" : "text-slate-500"}`}>
                      Batterie {num(b.battery_pct, 1)} %
                    </div>
                  )}
                  {b.rssi_dbm !== null && <div className="text-xs text-slate-500">Signal {signal(b.rssi_dbm)}</div>}
                </td>
                <td className="px-3 py-2.5">
                  <Farmer name={b.farmer_name} id={b.farmer_id} phoneNumber={b.farmer_phone} governorate={b.governorate} demo={b.demo} />
                </td>
                <td className="px-3 py-2.5">
                  <StatusBadge status={b.status} />
                  {b.faults.length > 0 && <div className="mt-1 text-xs text-amber-800">{b.faults.map((f) => label(FAULT, f)).join(", ")}</div>}
                  {refused && (
                    <div className="mt-1 text-xs text-sky-800">
                      Données refusées ({label(REFUSAL, b.last_refused_reason)}) {timeAgo(b.last_refused_at, now)}
                    </div>
                  )}
                  <div className="mt-2">
                    <BoxActionButton
                      box={{ node_id: b.node_id, device_code: b.device_code, zone_letter: b.zone_letter, farmer_name: personName(b.farmer_name, "Sans nom") }}
                      waiting={b.status === "waiting"}
                      onChanged={onChanged}
                    />
                  </div>
                </td>
                <td className="whitespace-nowrap px-3 py-2.5 text-slate-700">
                  {b.received_at ? timeAgo(b.received_at, now) : <span className="text-slate-400">aucune</span>}
                  {b.time_mode === "demo" && <div className="text-xs text-violet-700">horloge simulée</div>}
                </td>
                <td className="px-3 py-2.5">
                  <LevelBadge level={b.status === "waiting" ? null : b.level} />
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function Visits({ visits, onChanged }: { visits: VisitRow[]; onChanged: () => void }) {
  const [editing, setEditing] = useState<VisitTarget | null>(null);
  if (!visits.length) return <Empty>Aucune demande de visite d&apos;installation.</Empty>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className={HEAD}>
          <tr>
            <th className={TH}>Agriculteur</th>
            <th className={TH}>Demandée le</th>
            <th className={TH}>Verger</th>
            <th className={TH}>Boîtiers acceptés</th>
            <th className={TH}>État</th>
            <th className={TH}>Note</th>
            <th className={TH}>Action</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {visits.map((v) => (
            <tr key={v.id} className="align-top">
              <td className="px-3 py-2.5">
                <Farmer name={v.farmer_name} id={v.user_id} phoneNumber={v.phone} governorate={v.governorate} demo={v.demo} />
              </td>
              <td className="whitespace-nowrap px-3 py-2.5 text-slate-700">{date(v.created_at)}</td>
              <td className="px-3 py-2.5 text-xs text-slate-600">
                {v.almond_trees ? `${v.almond_trees} amandiers` : "—"}
                {v.orchard_area_ha ? ` · ${num(v.orchard_area_ha, 2)} ha` : ""}
                {v.nodes ? <div>{v.nodes} boîtier{v.nodes > 1 ? "s" : ""} prévu{v.nodes > 1 ? "s" : ""}</div> : null}
              </td>
              <td className="whitespace-nowrap px-3 py-2.5 tabular-nums text-slate-700">
                {v.boxes_total ? `${v.boxes_accepted} / ${v.boxes_total}` : "—"}
              </td>
              <td className="whitespace-nowrap px-3 py-2.5">
                <span
                  className={
                    "rounded-full px-2.5 py-0.5 text-xs font-medium " +
                    (v.status === "new"
                      ? "bg-sky-50 text-sky-800"
                      : v.status === "contacted"
                        ? "bg-amber-50 text-amber-800"
                        : v.status === "installed"
                          ? "bg-emerald-50 text-emerald-800"
                          : "bg-slate-100 text-slate-600")
                  }
                >
                  {label(VISIT, v.status)}
                </span>
                {v.installed_at && <div className="mt-1 text-xs text-slate-500">le {date(v.installed_at)}</div>}
              </td>
              <td className="max-w-56 px-3 py-2.5 text-xs text-slate-600">{v.admin_note ?? "—"}</td>
              <td className="px-3 py-2.5">
                <Button small onClick={() => setEditing({ id: v.id, status: v.status, admin_note: v.admin_note, farmer_name: personName(v.farmer_name, "Sans nom") })}>
                  Modifier
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {editing && (
        <VisitDialog
          visit={editing}
          onClose={() => setEditing(null)}
          onDone={() => {
            setEditing(null);
            onChanged();
          }}
        />
      )}
    </div>
  );
}

function Gateways({ gateways, now, onChanged }: { gateways: GatewayRow[]; now: number; onChanged: () => void }) {
  if (!gateways.length) return <Empty>Aucune passerelle.</Empty>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className={HEAD}>
          <tr>
            <th className={TH}>Passerelle</th>
            <th className={TH}>Agriculteur</th>
            <th className={TH}>État</th>
            <th className={TH}>Dernier lot</th>
            <th className={TH}>Résultat</th>
            <th className={TH}>Actions</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {gateways.map((g) => {
            const r = g.last_result ?? {};
            const refused = Object.values(r.refused ?? {}).reduce((a, b) => a + b, 0);
            return (
              <tr key={g.code} className="align-top">
                <td className="whitespace-nowrap px-3 py-2.5">
                  <div className="font-mono font-semibold text-slate-900">{g.code}</div>
                  <div className="text-xs text-slate-500">{g.time_mode === "demo" ? "mode démo (horloge simulée)" : "temps réel"}</div>
                </td>
                <td className="px-3 py-2.5">
                  <Farmer name={g.farmer_name} id={g.farmer_id} demo={g.demo} />
                </td>
                <td className="whitespace-nowrap px-3 py-2.5">
                  {g.enabled ? (
                    <span className="rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-medium text-emerald-800">Activée</span>
                  ) : (
                    <span className="rounded-full bg-rose-50 px-2.5 py-0.5 text-xs font-medium text-rose-800">Désactivée</span>
                  )}
                </td>
                <td className="whitespace-nowrap px-3 py-2.5 text-slate-700">
                  {g.last_seen_at ? timeAgo(g.last_seen_at, now) : "jamais"}
                  {g.last_seen_at && <div className="text-xs text-slate-500">{dateTime(g.last_seen_at)}</div>}
                </td>
                <td className="px-3 py-2.5 text-xs text-slate-600">
                  {g.last_seen_at ? (
                    <>
                      {r.accepted ?? 0} acceptée{(r.accepted ?? 0) > 1 ? "s" : ""}
                      {refused > 0 && <span className="text-amber-800"> · {refused} refusée{refused > 1 ? "s" : ""}</span>}
                    </>
                  ) : (
                    "—"
                  )}
                </td>
                <td className="px-3 py-2.5">
                  <GatewayButtons code={g.code} enabled={g.enabled} onChanged={onChanged} />
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export function SensorsView() {
  const params = useSearchParams();
  const first = params.get("tab");
  const [tab, setTab] = useState<Tab>(TABS.includes(first as Tab) ? (first as Tab) : "all");
  const [typed, setTyped] = useState("");
  const load = useCallback(() => getSensors(), []);
  const { data, error, receivedAt, reload } = usePolling<SensorsPage>(load, 30000);
  const now = useNow();
  const serverNow = data && receivedAt ? new Date(data.server_time).getTime() + (now - receivedAt) : now;

  const q = typed.trim().toLowerCase();
  const boxes = (data?.boxes ?? []).filter(
    (b) => !q || (b.device_code ?? "").toLowerCase().includes(q) || b.farmer_name.toLowerCase().includes(q),
  );
  const waiting = boxes.filter((b) => b.status === "waiting");

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Capteurs</h1>
      <p className="mt-1 text-slate-500">
        Les boîtiers de capteurs, les visites d&apos;installation et les passerelles. Mise à jour automatique toutes les 30 s
        {receivedAt ? ` · dernière ${timeAgo(new Date(receivedAt).toISOString(), now)}` : ""}.
      </p>

      {error !== null && (
        <div className="mt-4">
          <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      {!data && error === null && <p className="mt-6 text-slate-500">Chargement…</p>}
      {data && (
        <div className="mt-5 rounded-xl border border-slate-200 bg-white p-4">
          <Tabs
            tabs={[
              { id: "all", label: "Tous les boîtiers", count: data.boxes.length },
              { id: "waiting", label: "En attente", count: data.boxes.filter((b) => b.status === "waiting").length },
              { id: "visits", label: "Visites d'installation", count: data.visits.length },
              { id: "gateways", label: "Passerelles", count: data.gateways.length },
              { id: "log", label: "Journal" },
            ]}
            current={tab}
            onChange={setTab}
          />
          <div className="mt-4">
            {(tab === "all" || tab === "waiting") && (
              <input
                type="search"
                value={typed}
                onChange={(e) => setTyped(e.target.value)}
                placeholder="Rechercher un code de boîtier ou un agriculteur"
                aria-label="Rechercher un code de boîtier ou un agriculteur"
                className="mb-3 w-full max-w-sm rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
              />
            )}
            {tab === "all" && <BoxTable boxes={boxes} now={serverNow} onChanged={reload} empty="Aucun boîtier ne correspond." />}
            {tab === "waiting" && (
              <>
                <p className="mb-3 text-sm text-slate-600">
                  Un boîtier en attente peut déjà envoyer des données : elles sont <b>refusées</b> tant que son installation n&apos;est pas acceptée.
                </p>
                <BoxTable boxes={waiting} now={serverNow} onChanged={reload} empty="Aucun boîtier en attente d'acceptation." />
              </>
            )}
            {tab === "visits" && <Visits visits={data.visits} onChanged={reload} />}
            {tab === "gateways" && <Gateways gateways={data.gateways} now={serverNow} onChanged={reload} />}
            {tab === "log" && <ActionList actions={data.actions} empty="Aucune action sur les boîtiers, les visites ou les passerelles." />}
          </div>
        </div>
      )}
    </div>
  );
}
