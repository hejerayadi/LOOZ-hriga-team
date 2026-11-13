"use client";

// "Alertes": the regional alerts (in progress, planned, finished), the
// sensor alerts of every orchard (with filters), and the log of the admin
// actions on the regional alerts. ?tab=sensors|log opens a tab.
import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { ActionList } from "@/components/actions";
import { AlertStatusBadge, EndAlertButton, KindLabel, SeverityBadge, governoratesText, periodText } from "@/components/alerts";
import { LevelBadge } from "@/components/iot";
import { DemoTag, Empty, ErrorBox, Tabs } from "@/components/ui";
import { errorMessage, getRegionalAlerts, getSensorAlerts } from "@/lib/api";
import { num, shortDateTime, timeAgo } from "@/lib/format";
import { FAULT, GOVERNORATES, LEVEL, REASON, label, personName } from "@/lib/labels";
import type { RegionalAlert, RegionalAlertsPage, SensorAlertsPage } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";

type Tab = "regional" | "sensors" | "log";
const TABS: Tab[] = ["regional", "sensors", "log"];
const SELECT = "rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100";
const TH = "px-3 py-2 font-medium";
const PAGE = 50; // sensor alert lines shown at a time
const HEAD = "border-y border-slate-200 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500";

function AlertCard({ a, onChanged }: { a: RegionalAlert; onChanged: () => void }) {
  const open = a.status !== "ended";
  return (
    <li className="rounded-xl border border-slate-200 bg-white px-4 py-3">
      <div className="flex flex-wrap items-center gap-2">
        <KindLabel kind={a.kind} />
        <SeverityBadge severity={a.severity} />
        <AlertStatusBadge status={a.status} />
        {a.is_demo && <DemoTag />}
        <span className="ml-auto text-xs text-slate-500">
          {a.seen_count} « Moi aussi »
        </span>
      </div>
      <div className="mt-2 font-semibold text-slate-900">{a.title_fr}</div>
      <div className="text-sm text-slate-600">
        <span dir="rtl" lang="ar">
          {a.title_ar}
        </span>
      </div>
      <div className="mt-2 text-sm text-slate-600">{governoratesText(a.governorates)}</div>
      <div className="text-xs text-slate-500">
        {periodText(a.starts_at, a.ends_at)}
        {a.ended_at && ` · terminée le ${shortDateTime(a.ended_at)}${a.ended_by_name ? ` par ${a.ended_by_name}` : ""}`}
        {a.created_by_name && ` · créée par ${a.created_by_name}`}
      </div>
      <div className="mt-3 flex flex-wrap gap-1.5">
        <Link href={`/alerts/${a.id}`} className="rounded-lg border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 hover:bg-slate-100">
          {open ? "Ouvrir et modifier" : "Ouvrir"}
        </Link>
        {open && <EndAlertButton alertId={a.id} title={a.title_fr} onDone={onChanged} />}
      </div>
    </li>
  );
}

function Regional({ page, onChanged }: { page: RegionalAlertsPage; onChanged: () => void }) {
  const groups: { title: string; alerts: RegionalAlert[]; empty: string }[] = [
    { title: "En cours", alerts: page.alerts.filter((a) => a.status === "active"), empty: "Aucune alerte en cours." },
    { title: "Programmées", alerts: page.alerts.filter((a) => a.status === "scheduled"), empty: "Aucune alerte programmée." },
    { title: "Terminées ou expirées", alerts: page.alerts.filter((a) => a.status === "ended" || a.status === "expired"), empty: "Aucune." },
  ];
  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-slate-600">
          Gel, chaleur, sécheresse, maladie, ravageurs, vent, pluie : en arabe et en français, pour un ou plusieurs gouvernorats.
          Seuls les agriculteurs de ces gouvernorats les voient.
        </p>
        <Link href="/alerts/new" className="rounded-lg bg-emerald-700 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-800">
          Nouvelle alerte
        </Link>
      </div>
      {groups.map((g) => (
        <section key={g.title} className="mt-5">
          <h3 className="font-semibold text-slate-900">
            {g.title} <span className="ml-1 rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">{g.alerts.length}</span>
          </h3>
          <div className="mt-2">
            {!g.alerts.length ? (
              <Empty>{g.empty}</Empty>
            ) : (
              <ul className="space-y-3">
                {g.alerts.map((a) => (
                  <AlertCard key={a.id} a={a} onChanged={onChanged} />
                ))}
              </ul>
            )}
          </div>
        </section>
      ))}
    </>
  );
}

function Sensors() {
  const [level, setLevel] = useState("");
  const [governorate, setGovernorate] = useState("");
  const [farmer, setFarmer] = useState("");
  const [days, setDays] = useState(7);
  const [shown, setShown] = useState(PAGE);
  const load = useCallback(
    () => getSensorAlerts({ level, governorate, farmer_id: farmer, days }),
    [level, governorate, farmer, days],
  );
  const { data, error, receivedAt, reload } = usePolling<SensorAlertsPage>(load, 30000);
  const now = useNow();
  // A filter changed: ask again at once (not when the page opens: usePolling asks then).
  const opened = useRef(false);
  useEffect(() => {
    if (opened.current) {
      reload();
      setShown(PAGE);
    }
    opened.current = true;
  }, [load, reload]);
  const serverNow = data && receivedAt ? new Date(data.server_time).getTime() + (now - receivedAt) : now;

  return (
    <>
      <div className="flex flex-wrap gap-2">
        <select aria-label="Niveau" value={level} onChange={(e) => setLevel(e.target.value)} className={SELECT}>
          <option value="">Tous les niveaux</option>
          {["critical", "warning", "watch", "info", "sensor", "ok"].map((l) => (
            <option key={l} value={l}>
              {label(LEVEL, l)}
            </option>
          ))}
        </select>
        <select aria-label="Gouvernorat" value={governorate} onChange={(e) => setGovernorate(e.target.value)} className={SELECT}>
          <option value="">Tous les gouvernorats</option>
          {Object.entries(GOVERNORATES).map(([code, name]) => (
            <option key={code} value={code}>
              {name}
            </option>
          ))}
        </select>
        <select aria-label="Agriculteur" value={farmer} onChange={(e) => setFarmer(e.target.value)} className={SELECT}>
          <option value="">Tous les agriculteurs</option>
          {(data?.farmers ?? []).map((f) => (
            <option key={f.id} value={f.id}>
              {personName(f.name, "Sans nom")}
            </option>
          ))}
        </select>
        <select aria-label="Période" value={days} onChange={(e) => setDays(Number(e.target.value))} className={SELECT}>
          <option value={1}>Dernières 24 h</option>
          <option value={7}>7 derniers jours</option>
          <option value={30}>30 derniers jours</option>
          <option value={90}>90 derniers jours</option>
        </select>
      </div>
      <p className="mt-2 text-xs text-slate-500">
        Chaque ligne = un changement de niveau d&apos;un boîtier (reçu pendant la période). Les {data?.limit ?? 300} plus récents au plus.
        {receivedAt ? ` Mise à jour ${timeAgo(new Date(receivedAt).toISOString(), now)}.` : ""}
      </p>
      {error !== null && (
        <div className="mt-3">
          <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      {!data && error === null && <p className="mt-4 text-slate-500">Chargement…</p>}
      {data && (
        <div className="mt-3">
          {!data.events.length ? (
            <Empty>Aucune alerte de capteur pour ces filtres.</Empty>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className={HEAD}>
                  <tr>
                    <th className={TH}>Mesure</th>
                    <th className={TH}>Boîtier et agriculteur</th>
                    <th className={TH}>Niveau</th>
                    <th className={TH}>Pourquoi</th>
                    <th className={TH}>Stress · sol · air</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {data.events.slice(0, shown).map((e) => (
                    <tr key={e.id} className="align-top">
                      <td className="whitespace-nowrap px-3 py-2 text-slate-700">
                        {shortDateTime(e.measured_at)}
                        <div className="text-xs text-slate-500">reçue {timeAgo(e.received_at, serverNow)}</div>
                      </td>
                      <td className="px-3 py-2">
                        <div className="whitespace-nowrap">
                          <span className="font-mono font-semibold text-slate-900">{e.device_code ?? "—"}</span>
                          <span className="text-xs text-slate-500"> · zone {e.zone_letter ?? "?"}</span>
                        </div>
                        {e.farmer_id ? (
                          <Link href={`/farmers/${e.farmer_id}`} className="font-medium text-slate-900 hover:text-emerald-800">
                            {personName(e.farmer_name, "Sans nom")}
                          </Link>
                        ) : (
                          personName(e.farmer_name, "Sans nom")
                        )}
                        {e.demo && <span className="ml-1.5"><DemoTag /></span>}
                        <div className="text-xs text-slate-500">{label(GOVERNORATES, e.governorate)}</div>
                      </td>
                      <td className="whitespace-nowrap px-3 py-2">
                        {e.previous_level && (
                          <>
                            <LevelBadge level={e.previous_level} /> <span className="text-slate-400">→</span>{" "}
                          </>
                        )}
                        <LevelBadge level={e.level} />
                      </td>
                      <td className="min-w-36 px-3 py-2 text-xs text-slate-600">
                        {[...e.reasons.map((r) => label(REASON, r)), ...e.faults.map((f) => label(FAULT, f))].join(", ") || "—"}
                      </td>
                      <td className="whitespace-nowrap px-3 py-2 text-xs tabular-nums text-slate-700">
                        <div>
                          hydrique {e.water_stress ?? "—"} · thermique {e.heat_stress ?? "—"}
                        </div>
                        <div>
                          sol {e.soil_moisture_pct === null ? "—" : `${num(e.soil_moisture_pct)} %`} · air{" "}
                          {e.air_temp_c === null ? "—" : `${num(e.air_temp_c)} °C`}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {data.events.length > shown && (
                <div className="mt-3 flex items-center gap-3 text-sm">
                  <button type="button" onClick={() => setShown((n) => n + PAGE)} className="font-medium text-emerald-800 hover:underline">
                    Voir {Math.min(PAGE, data.events.length - shown)} de plus
                  </button>
                  <span className="text-xs text-slate-500">
                    {shown} lignes sur {data.events.length}
                  </span>
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </>
  );
}

export function AlertsView() {
  const params = useSearchParams();
  const first = params.get("tab");
  const [tab, setTab] = useState<Tab>(TABS.includes(first as Tab) ? (first as Tab) : "regional");
  const load = useCallback(() => getRegionalAlerts(), []);
  const { data, error, reload } = usePolling<RegionalAlertsPage>(load, 30000);

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Alertes</h1>
      <p className="mt-1 text-slate-500">Les alertes régionales envoyées aux agriculteurs, et les alertes des capteurs de tous les vergers.</p>
      {error !== null && (
        <div className="mt-4">
          <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      <div className="mt-5 rounded-xl border border-slate-200 bg-white p-4">
        <Tabs
          tabs={[
            { id: "regional", label: "Alertes régionales", count: data ? data.alerts.filter((a) => a.status === "active").length : undefined },
            { id: "sensors", label: "Alertes des capteurs" },
            { id: "log", label: "Journal" },
          ]}
          current={tab}
          onChange={setTab}
        />
        <div className="mt-4">
          {tab === "regional" && (data ? <Regional page={data} onChanged={reload} /> : error === null && <p className="text-slate-500">Chargement…</p>)}
          {tab === "sensors" && <Sensors />}
          {tab === "log" && (data ? <ActionList actions={data.actions} empty="Aucune action sur les alertes régionales." /> : null)}
        </div>
      </div>
    </div>
  );
}
