"use client";

// One farmer, live: pack, orchard plan, gateway (Node-RED), and every zone
// with its sensor box (state, last data, battery, signal, readings, stress
// indices, level, problems), with the admin actions (accept / remove a box,
// new gateway key, installation visit). Asked again every 15 s while
// visible; the 3 days (charts, alert log...) every 30 s.
import { useCallback, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";

import { FarmerActivity } from "./FarmerActivity";

import { BoxActionButton, GatewayButtons, VisitDialog } from "@/components/actions";
import { LevelBadge, OrchardPlan, PackText, StatusBadge, StressBar } from "@/components/iot";
import { Button, Card, DemoTag, ErrorBox, Fact } from "@/components/ui";
import { errorMessage, getFarmer, getFarmerHistory } from "@/lib/api";
import { age, date, dateTime, num, phone, shortDateTime, signal, timeAgo } from "@/lib/format";
import { FAULT, GOVERNORATES, REASON, REFUSAL, VISIT, ZONE_TYPE, label, personName, zoneName } from "@/lib/labels";
import type { Box, FarmerDetail, Gateway, Zone } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";
import { FarmerHistorySection } from "./FarmerHistory";

const EVERY_MS = 15000;
const HISTORY_EVERY_MS = 30000;

// The reasons of a level, the most important first.
const REASON_ORDER = ["wilting_point", "water_stress", "heat_stress", "unusual_drying", "sensor_fault", "other"];
function sortReasons(reasons: string[]): string[] {
  return [...reasons].sort((a, b) => REASON_ORDER.indexOf(a) - REASON_ORDER.indexOf(b));
}

function GatewayCard({ gateways, boxes, now, onChanged }: { gateways: Gateway[]; boxes: Box[]; now: number; onChanged: () => void }) {
  if (!gateways.length) {
    return (
      <Card title="Passerelle de la ferme">
        <p className="text-sm text-slate-500">Aucune passerelle : les boîtiers de ce verger ne peuvent pas encore envoyer de données.</p>
      </Card>
    );
  }
  const latestMeasure = boxes.map((b) => b.measured_at).filter(Boolean).sort().pop() ?? null;
  return (
    <Card title="Passerelle de la ferme">
      {gateways.map((g) => {
        const r = g.last_result ?? {};
        const refused = Object.entries(r.refused ?? {});
        const devices = Object.entries(r.refused_devices ?? {});
        return (
          <div key={g.code} className="space-y-2 text-sm">
            <div className="flex flex-wrap items-center gap-2">
              <span className="font-mono text-base font-semibold text-slate-900">{g.code}</span>
              {g.time_mode === "demo" ? (
                <span className="rounded-full bg-violet-50 px-2.5 py-0.5 text-xs font-medium text-violet-800 ring-1 ring-violet-200">
                  Mode démo : horloge simulée (5 s = 15 min)
                </span>
              ) : (
                <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-700">Temps réel</span>
              )}
              {!g.enabled && <span className="rounded-full bg-rose-50 px-2.5 py-0.5 text-xs font-medium text-rose-800">Désactivée</span>}
            </div>
            <div className="text-slate-700">
              Dernier lot reçu : <b>{g.last_seen_at ? timeAgo(g.last_seen_at, now) : "jamais"}</b>
              {g.last_seen_at && <span className="text-slate-500"> ({dateTime(g.last_seen_at)})</span>}
            </div>
            {g.last_seen_at && (
              <div className="text-slate-700">
                {r.accepted ?? 0} mesure{(r.accepted ?? 0) > 1 ? "s" : ""} acceptée{(r.accepted ?? 0) > 1 ? "s" : ""}
                {r.old ? ` · ${r.old} déjà reçue${r.old > 1 ? "s" : ""}` : ""}
                {refused.length === 0 ? " · aucune refusée" : ""}
              </div>
            )}
            {refused.length > 0 && (
              <div className="rounded-lg bg-amber-50 px-3 py-2 text-amber-900">
                Refusées : {refused.map(([why, n]) => `${n} (${label(REFUSAL, why)})`).join(", ")}
                {devices.length > 0 && <div className="text-xs">Boîtiers : {devices.map(([d, why]) => `${d} : ${label(REFUSAL, why)}`).join(" · ")}</div>}
              </div>
            )}
            {g.time_mode === "demo" && latestMeasure && (
              <div className="text-slate-700">
                Heure simulée : <b>{dateTime(latestMeasure)}</b>
              </div>
            )}
            <div className="text-xs text-slate-500">
              Historique : un point toutes les {g.history_minutes} min {g.time_mode === "demo" ? "d'heure simulée" : ""} · hors ligne après{" "}
              {g.offline_after_minutes} min sans données.
            </div>
            <div className="pt-1">
              <GatewayButtons code={g.code} enabled={g.enabled} onChanged={onChanged} />
            </div>
          </div>
        );
      })}
    </Card>
  );
}

function ZoneCell({ zone }: { zone: Zone | undefined; }) {
  if (!zone) return <span className="text-slate-400">—</span>;
  const facts = [zone.cultivar, age(zone.planted_year), zone.zone_type ? label(ZONE_TYPE, zone.zone_type) : null].filter(Boolean);
  const trees = zone.tree_count ?? zone.tree_codes.length;
  return (
    <div className="w-40 xl:w-48">
      <div className="flex items-center gap-2 font-semibold text-slate-900">
        <span className="h-3 w-3 rounded-sm" style={{ background: zone.color ?? "#cbd5e1" }} />
        {zoneName(zone.letter, zone.name)}
      </div>
      {facts.length > 0 && <div className="text-xs text-slate-600">{facts.join(" · ")}</div>}
      <div className="text-xs text-slate-500">
        {trees} arbre{trees > 1 ? "s" : ""}
        {zone.tree_codes.length > 0 && ` : ${zone.tree_codes.join(", ")}`}
      </div>
    </div>
  );
}

function BoxRows({ box, zone, now, onChanged }: { box: Box; zone: Zone | undefined; now: number; onChanged: () => void }) {
  const demo = box.time_mode === "demo";
  const lowBattery = box.battery_pct !== null && box.battery_pct < 20;
  const refusedLately = box.last_refused_at && (!box.received_at || box.last_refused_at > box.received_at);
  const soilFault = box.faults.some((f) => f.startsWith("soil_"));
  const notes: React.ReactNode[] = [];
  if (box.faults.length) {
    notes.push(
      <span key="f" className="text-amber-800">
        Problème : {box.faults.map((f) => label(FAULT, f)).join(", ")}
        {box.packets_lost ? ` (${box.packets_lost})` : ""}
      </span>,
    );
  }
  if (refusedLately) {
    notes.push(
      <span key="r" className="text-sky-800">
        Le boîtier envoie des données, mais elles sont refusées ({label(REFUSAL, box.last_refused_reason)}) — {timeAgo(box.last_refused_at, now)}
      </span>,
    );
  } else if (box.status === "waiting") {
    notes.push(
      <span key="w" className="text-sky-800">
        L&apos;installation de ce boîtier n&apos;est pas encore acceptée : ses données sont refusées.
      </span>,
    );
  }
  return (
    <>
      <tr className={notes.length ? "" : "border-b border-slate-100"}>
        <td className="px-2.5 py-3 align-top">
          <ZoneCell zone={zone} />
        </td>
        <td className="px-2.5 py-3 align-top whitespace-nowrap">
          <div className="font-mono font-semibold text-slate-900">{box.device_code ?? "—"}</div>
          <div className={`text-xs ${lowBattery ? "font-semibold text-rose-700" : "text-slate-600"}`}>
            Batterie {box.battery_pct === null ? "—" : `${num(box.battery_pct, 1)} %`}
          </div>
          <div className="text-xs text-slate-600">Signal {signal(box.rssi_dbm)}</div>
          {box.installed_at && <div className="text-xs text-slate-400">accepté le {date(box.installed_at)}</div>}
        </td>
        <td className="px-2.5 py-3 align-top">
          <StatusBadge status={box.status} />
          <div className="mt-2">
            <BoxActionButton
              box={{ node_id: box.node_id, device_code: box.device_code, zone_letter: box.zone_letter }}
              waiting={box.status === "waiting"}
              onChanged={onChanged}
            />
          </div>
        </td>
        <td className="px-2.5 py-3 align-top whitespace-nowrap">
          <div className="text-slate-900">{box.received_at ? timeAgo(box.received_at, now) : "aucune donnée"}</div>
          {box.measured_at && (
            <div className="text-xs text-slate-500">
              mesure {shortDateTime(box.measured_at)}
              {demo && <span className="block text-violet-700">heure simulée</span>}
            </div>
          )}
        </td>
        <td className="px-2.5 py-3 align-top whitespace-nowrap">
          <div className="grid grid-cols-[2rem_auto] gap-x-1">
            <span className="text-xs leading-5 text-slate-500">Sol</span>
            <span className={soilFault ? "font-semibold text-amber-800" : "text-slate-900"}>
              {box.soil_moisture_pct === null ? "—" : `${num(box.soil_moisture_pct)} %`}
              {box.soil_temp_c !== null && <span className="text-xs font-normal text-slate-500"> · {num(box.soil_temp_c)} °C</span>}
            </span>
            <span className="text-xs leading-5 text-slate-500">Air</span>
            <span className="text-slate-900">
              {box.air_temp_c === null ? "—" : `${num(box.air_temp_c)} °C`}
              {box.humidity_pct !== null && <span className="text-xs text-slate-500"> · {num(box.humidity_pct, 1)} %</span>}
            </span>
          </div>
        </td>
        <td className="px-2.5 py-3 align-top">
          <div className="grid grid-cols-[4.5rem_1fr] items-center gap-x-2 gap-y-1 text-xs">
            <span className="text-slate-500">hydrique</span>
            <StressBar value={box.water_stress} suspended={soilFault || box.level === "sensor"} />
            <span className="text-slate-500">thermique</span>
            <StressBar value={box.heat_stress} />
          </div>
        </td>
        <td className="w-36 px-2.5 py-3 align-top">
          <LevelBadge level={box.level} />
          {box.reasons.length > 0 && <div className="mt-1 text-xs text-slate-600">{sortReasons(box.reasons).map((r) => label(REASON, r)).join(", ")}</div>}
          {box.confidence !== null && box.level && box.level !== "ok" && (
            <div className="whitespace-nowrap text-xs text-slate-400">confiance {Math.round(box.confidence * 100)} %</div>
          )}
        </td>
      </tr>
      {notes.length > 0 && (
        <tr className="border-b border-slate-100">
          <td />
          <td colSpan={6} className="px-3 pb-3 text-xs">
            <div className="flex flex-col gap-1">{notes}</div>
          </td>
        </tr>
      )}
    </>
  );
}

function VisitLine({ d, onChanged }: { d: FarmerDetail; onChanged: () => void }) {
  const [open, setOpen] = useState(false);
  const visit = d.visit;
  if (!visit) return null;
  return (
    <div className="mt-3 flex flex-wrap items-center gap-2 text-sm text-slate-600">
      <span>
        Visite d&apos;installation : <b className="text-slate-800">{label(VISIT, visit.status)}</b>
        {visit.nodes ? ` (${visit.nodes} boîtier${visit.nodes > 1 ? "s" : ""})` : ""}
      </span>
      {visit.id && (
        <Button small onClick={() => setOpen(true)}>
          Modifier
        </Button>
      )}
      {visit.admin_note && <span className="basis-full text-xs text-slate-500">Note : {visit.admin_note}</span>}
      {open && visit.id && (
        <VisitDialog
          visit={{ id: visit.id, status: visit.status, admin_note: visit.admin_note, farmer_name: personName(d.farmer.name, "Sans nom") }}
          onClose={() => setOpen(false)}
          onDone={() => {
            setOpen(false);
            onChanged();
          }}
        />
      )}
    </div>
  );
}

function Details({ d, now, onChanged }: { d: FarmerDetail; now: number; onChanged: () => void }) {
  const zoneOf = new Map(d.zones.map((z) => [z.id, z]));
  return (
    <>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold text-slate-900">
            {personName(d.farmer.name, "Sans nom")}
            {d.orchard?.is_demo && <DemoTag />}
          </h1>
          <p className="mt-1 text-slate-500">
            {phone(d.farmer.phone)} · {label(GOVERNORATES, d.farmer.governorate)} · inscrit le {date(d.farmer.created_at)}
          </p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm">
          <div className="text-xs text-slate-500">Pack</div>
          <PackText pack={d.pack} />
        </div>
      </div>

      {!d.orchard ? (
        <div className="mt-6 rounded-xl border border-dashed border-slate-300 bg-white p-10 text-center text-slate-500">
          Cet agriculteur n&apos;a pas encore de verger.
        </div>
      ) : (
        <>
          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            <Card title={d.orchard.is_demo ? "Verger (démonstration)" : "Verger"}>
              <OrchardPlan outline={d.orchard.outline} zones={d.zones} trees={d.trees} boxes={d.boxes} />
              <div className="mt-3 grid grid-cols-4 gap-3">
                <Fact name="Surface" value={d.orchard.area_ha === null ? "—" : `${num(d.orchard.area_ha, 2)} ha`} />
                <Fact name="Zones" value={d.zones.length} />
                <Fact name="Arbres" value={d.zones.reduce((n, z) => n + (z.tree_count ?? 0), 0)} />
                <Fact name="Boîtiers" value={d.boxes.length} />
              </div>
              {d.orchard.status === "draft" && <p className="mt-2 text-sm text-amber-700">Brouillon : le verger n&apos;est pas encore construit.</p>}
              <VisitLine d={d} onChanged={onChanged} />
            </Card>
            <GatewayCard gateways={d.gateways} boxes={d.boxes} now={now} onChanged={onChanged} />
          </div>

          <section className="mt-6 rounded-xl border border-slate-200 bg-white">
            <div className="flex flex-wrap items-baseline justify-between gap-2 px-5 pt-5">
              <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">Zones et boîtiers</h2>
              <p className="text-xs text-slate-500">
                Stress (0 à 100) : moins de 40 normal · 40 à 59 à surveiller · 60 à 79 élevé · 80 et plus critique
              </p>
            </div>
            <div className="mt-3 overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-y border-slate-200 bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-2.5 py-2 font-medium">Zone</th>
                    <th className="px-2.5 py-2 font-medium">Boîtier</th>
                    <th className="px-2.5 py-2 font-medium">État</th>
                    <th className="px-2.5 py-2 font-medium">Dernière donnée</th>
                    <th className="px-2.5 py-2 font-medium">Mesures</th>
                    <th className="px-2.5 py-2 font-medium">Indices de stress</th>
                    <th className="px-2.5 py-2 font-medium">Niveau</th>
                  </tr>
                </thead>
                <tbody>
                  {d.boxes.length === 0 && (
                    <tr>
                      <td colSpan={7} className="px-3 py-8 text-center text-slate-400">
                        Aucun boîtier dans ce verger.
                      </td>
                    </tr>
                  )}
                  {d.boxes.map((b) => (
                    <BoxRows key={b.node_id} box={b} zone={zoneOf.get(b.zone_id)} now={now} onChanged={onChanged} />
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </>
  );
}

export function FarmerView() {
  const { id } = useParams<{ id: string }>();
  const load = useCallback(() => getFarmer(id), [id]);
  const { data, error, receivedAt, reload } = usePolling(load, EVERY_MS);
  const loadHistory = useCallback(() => getFarmerHistory(id), [id]);
  const history = usePolling(loadHistory, HISTORY_EVERY_MS);
  const now = useNow();
  // "Il y a…" measured with the server's clock.
  const serverNow = data && receivedAt ? new Date(data.server_time).getTime() + (now - receivedAt) : now;
  // After an action: ask again at once (state of the boxes, log).
  const reloadHistory = history.reload;
  const onChanged = useCallback(() => {
    reload();
    reloadHistory();
  }, [reload, reloadHistory]);
  const gapMinutes = data?.gateways[0]?.history_minutes ?? 15;

  return (
    <div>
      <Link href="/farmers" className="text-sm font-medium text-emerald-800 hover:underline">
        ← Tous les agriculteurs
      </Link>

      <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-slate-500">
        <span className="flex items-center gap-1.5">
          <span className={`h-2 w-2 rounded-full ${error ? "bg-rose-500" : "animate-pulse bg-emerald-500"}`} />
          Mise à jour automatique toutes les 15 s
        </span>
        {receivedAt && <span>· dernière {timeAgo(new Date(receivedAt).toISOString(), now)}</span>}
      </div>

      {error !== null && (
        <div className="mt-3">
          <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}

      {!data && error === null && <p className="mt-6 text-slate-500">Chargement…</p>}
      {data && (
        <div className="mt-4">
          <Details d={data} now={serverNow} onChanged={onChanged} />
        </div>
      )}
      {data?.orchard && (
        <>
          {history.error !== null && (
            <div className="mt-6">
              <ErrorBox message={"Historique non mis à jour : " + errorMessage(history.error)} onRetry={history.reload} />
            </div>
          )}
          {!history.data && history.error === null && <p className="mt-6 text-slate-500">Chargement de l&apos;historique…</p>}
          {history.data && <FarmerHistorySection history={history.data} gapMinutes={gapMinutes} />}
        </>
      )}
      {data && <FarmerActivity farmerId={id} />}
    </div>
  );
}
