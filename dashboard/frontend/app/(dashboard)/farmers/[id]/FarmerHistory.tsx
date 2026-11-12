"use client";

// The last 3 days of a farmer's orchard: one chart per measure (every box
// on it), the table of the same values, the alert log, the sensor
// problems and the admin actions.
import { useState } from "react";

import { ActionList } from "@/components/actions";
import { LevelBadge } from "@/components/iot";
import { LineChart, SERIES_COLORS, type ChartSeries } from "@/components/LineChart";
import { Card, Empty, Tabs } from "@/components/ui";
import { dateTime, num, shortDateTime } from "@/lib/format";
import { FAULT, REASON, label } from "@/lib/labels";
import type { BoxSeries, FarmerHistory as History, SeriesPoint } from "@/lib/types";

type Metric = "soil" | "air" | "water" | "heat" | "battery";

const METRICS: { id: Metric; label: string; unit: string; digits: 1 | 2; domain?: [number, number] }[] = [
  { id: "soil", label: "Humidité du sol", unit: "%", digits: 1 },
  { id: "air", label: "Température de l'air", unit: "°C", digits: 1 },
  { id: "water", label: "Stress hydrique", unit: "", digits: 1, domain: [0, 100] },
  { id: "heat", label: "Stress thermique", unit: "", digits: 1, domain: [0, 100] },
  { id: "battery", label: "Batterie", unit: "%", digits: 1, domain: [0, 100] },
];

function seriesName(s: BoxSeries): string {
  return `${s.zone_letter ?? "?"} · ${s.device_code ?? "sans code"}`;
}

function stats(points: SeriesPoint[], metric: Metric) {
  const values = points.map((p) => p[metric]).filter((v): v is number => v !== null);
  if (!values.length) return null;
  return {
    last: values[values.length - 1],
    min: Math.min(...values),
    max: Math.max(...values),
    mean: values.reduce((a, b) => a + b, 0) / values.length,
    n: values.length,
  };
}

function Charts({ history, gapMinutes }: { history: History; gapMinutes: number }) {
  const [metric, setMetric] = useState<Metric>("soil");
  const m = METRICS.find((x) => x.id === metric) ?? METRICS[0];
  const demo = history.time_mode === "demo";
  const hasData = history.series.some((s) => s.points.length > 0);
  const format = (v: number) => `${num(v, m.digits)}${m.unit ? ` ${m.unit}` : ""}`;

  if (!history.window_start || !history.window_end || !hasData) {
    return (
      <Card title="Les 3 derniers jours">
        <Empty>Aucune mesure enregistrée pour l&apos;instant.</Empty>
      </Card>
    );
  }
  const series: ChartSeries[] = history.series.map((s, i) => ({
    id: s.node_id,
    name: seriesName(s),
    color: SERIES_COLORS[i % SERIES_COLORS.length],
    points: s.points.map((p) => ({ t: new Date(p.t).getTime(), v: p[metric] })),
  }));

  return (
    <Card title="Les 3 derniers jours">
      <p className="-mt-1 mb-3 text-xs text-slate-500">
        Du {dateTime(history.window_start)} au {dateTime(history.window_end)}
        {demo ? " · heure simulée (5 s = 15 min)" : ""} · la ligne s&apos;interrompt quand un boîtier n&apos;a rien envoyé ou
        qu&apos;un capteur est en panne (valeur fausse non dessinée).
      </p>
      <Tabs tabs={METRICS.map((x) => ({ id: x.id, label: x.label }))} current={metric} onChange={setMetric} />
      <div className="mt-4">
        <LineChart
          series={series}
          start={new Date(history.window_start).getTime()}
          end={new Date(history.window_end).getTime()}
          format={format}
          fixedDomain={m.domain}
          gapMs={Math.max(gapMinutes, 1) * 60 * 1000 * 2.5}
          ariaLabel={`${m.label} des 3 derniers jours, un trait par boîtier`}
        />
      </div>
      <div className="mt-4 overflow-x-auto">
        <table className="w-full text-left text-sm">
          <caption className="sr-only">{m.label} : valeurs des 3 derniers jours</caption>
          <thead className="border-y border-slate-200 bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
            <tr>
              <th className="px-3 py-2 font-medium">Boîtier</th>
              <th className="px-3 py-2 font-medium">Dernière</th>
              <th className="px-3 py-2 font-medium">Minimum</th>
              <th className="px-3 py-2 font-medium">Maximum</th>
              <th className="px-3 py-2 font-medium">Moyenne</th>
              <th className="px-3 py-2 font-medium">Mesures</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 tabular-nums">
            {history.series.map((s, i) => {
              const st = stats(s.points, metric);
              return (
                <tr key={s.node_id}>
                  <td className="px-3 py-2">
                    <span className="mr-2 inline-block h-0.5 w-4 rounded align-middle" style={{ background: SERIES_COLORS[i % SERIES_COLORS.length] }} />
                    {seriesName(s)}
                  </td>
                  <td className="px-3 py-2 font-medium text-slate-900">{st ? format(st.last) : "—"}</td>
                  <td className="px-3 py-2">{st ? format(st.min) : "—"}</td>
                  <td className="px-3 py-2">{st ? format(st.max) : "—"}</td>
                  <td className="px-3 py-2">{st ? format(st.mean) : "—"}</td>
                  <td className="px-3 py-2 text-slate-500">{st ? st.n : 0}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

function AlertLog({ history }: { history: History }) {
  const [all, setAll] = useState(false);
  const shown = all ? history.alerts : history.alerts.slice(0, 10);
  return (
    <Card
      title="Journal des alertes"
      action={
        history.alerts.length > 10 && (
          <button type="button" onClick={() => setAll(!all)} className="text-sm font-medium text-emerald-800 hover:underline">
            {all ? "Voir moins" : `Voir les ${history.alerts.length}`}
          </button>
        )
      }
    >
      {!history.alerts.length ? (
        <Empty>Aucun changement de niveau pour l&apos;instant.</Empty>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-y border-slate-200 bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
              <tr>
                <th className="px-3 py-2 font-medium">Mesure</th>
                <th className="px-3 py-2 font-medium">Boîtier</th>
                <th className="px-3 py-2 font-medium">Niveau</th>
                <th className="px-3 py-2 font-medium">Pourquoi</th>
                <th className="px-3 py-2 font-medium">Stress</th>
                <th className="px-3 py-2 font-medium">Sol · air</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {shown.map((e) => (
                <tr key={e.id}>
                  <td className="whitespace-nowrap px-3 py-2 text-slate-700">{shortDateTime(e.measured_at)}</td>
                  <td className="whitespace-nowrap px-3 py-2">
                    <span className="font-mono text-slate-900">{e.device_code ?? "—"}</span>
                    <span className="text-xs text-slate-500"> · zone {e.zone_letter ?? "?"}</span>
                  </td>
                  <td className="whitespace-nowrap px-3 py-2">
                    {e.previous_level && (
                      <>
                        <LevelBadge level={e.previous_level} /> <span className="text-slate-400">→</span>{" "}
                      </>
                    )}
                    <LevelBadge level={e.level} />
                  </td>
                  <td className="min-w-44 px-3 py-2 text-xs text-slate-600">
                    {[...e.reasons.map((r) => label(REASON, r)), ...e.faults.map((f) => label(FAULT, f))].join(", ") || "—"}
                  </td>
                  <td className="whitespace-nowrap px-3 py-2 text-xs tabular-nums text-slate-700">
                    hydrique {e.water_stress ?? "—"} · thermique {e.heat_stress ?? "—"}
                  </td>
                  <td className="whitespace-nowrap px-3 py-2 text-xs tabular-nums text-slate-700">
                    {e.soil_moisture_pct === null ? "—" : `${num(e.soil_moisture_pct)} %`} ·{" "}
                    {e.air_temp_c === null ? "—" : `${num(e.air_temp_c)} °C`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}

function Faults({ history }: { history: History }) {
  return (
    <Card title="Problèmes de capteurs (14 derniers jours)">
      {!history.faults.length ? (
        <Empty>Aucun problème de capteur.</Empty>
      ) : (
        <ul className="divide-y divide-slate-100 text-sm">
          {history.faults.map((f) => (
            <li key={`${f.node_id}-${f.code}`} className="flex flex-wrap items-baseline gap-x-3 py-2">
              <span className="font-mono font-semibold text-slate-900">{f.device_code ?? "—"}</span>
              <span className="text-xs text-slate-500">zone {f.zone_letter ?? "?"}</span>
              <span className="font-medium text-amber-800">{label(FAULT, f.code)}</span>
              <span className="text-slate-600">
                {f.days} jour{f.days > 1 ? "s" : ""} · {f.count} mesure{f.count > 1 ? "s" : ""}
              </span>
              <span className="text-xs text-slate-500">dernière fois {shortDateTime(f.last_at)}</span>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

export function FarmerHistorySection({ history, gapMinutes }: { history: History; gapMinutes: number }) {
  return (
    <div className="mt-6 space-y-6">
      <Charts history={history} gapMinutes={gapMinutes} />
      <AlertLog history={history} />
      <div className="grid gap-6 xl:grid-cols-2">
        <Faults history={history} />
        <Card title="Actions des administrateurs">
          <ActionList actions={history.actions} />
        </Card>
      </div>
    </div>
  );
}
