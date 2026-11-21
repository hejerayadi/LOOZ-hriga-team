"use client";

// "Prédictions IA": what the 2 models say for every sensor box (frost
// tonight, stress of the trees), with the reasons (SHAP), the explanation of
// Groq (French + the farmer's Derja), the history of each box, the in-app
// notifications, and the last round of the ML worker. Read again every 15 s.
import Link from "next/link";
import { Fragment, useState } from "react";

import { HBars, Kpi } from "@/components/charts";
import { Certainty, Explanation, HistoryStrip, Reasons, StateChip } from "@/components/ml";
import { Card, Empty, ErrorBox, Tabs } from "@/components/ui";
import { errorMessage } from "@/lib/api";
import { dateTime, timeAgo } from "@/lib/format";
import { MODEL, STATE, STATE_COLOR, type MlPage, type Prediction, getMl } from "@/lib/insights";
import { useNow, usePolling } from "@/lib/usePolling";

function zoneName(z: { letter: string | null; name: string }) {
  return z.name || `Zone ${z.letter ?? "?"}`;
}

function Worker({ page, now }: { page: MlPage; now: number }) {
  const w = page.worker;
  if (!w) return null;
  const late = !w.last_seen_at || now - new Date(w.last_seen_at).getTime() > 5 * 60_000;
  return (
    <p className={`mt-1 text-sm ${late ? "text-amber-700" : "text-slate-600"}`}>
      Service de prédiction <span className="font-semibold">{w.code}</span> : dernier passage {timeAgo(w.last_seen_at, now)}
      {w.last_result && ` · ${w.last_result.saved ?? 0} prédiction(s) enregistrée(s), ${w.last_result.notified ?? 0} notification(s)`}
      {late && " · le service ne tourne peut-être pas (python -m ml.worker)"}
    </p>
  );
}

function Table({ rows }: { rows: Prediction[] }) {
  const [open, setOpen] = useState<string | null>(null);
  if (!rows.length) return <Empty>Aucune prédiction pour l&apos;instant : le service attend les mesures des boîtiers.</Empty>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[900px] text-left text-sm">
        <thead>
          <tr className="border-b border-emerald-100">
            <th className="py-2 pr-3">Agriculteur · zone</th>
            <th className="py-2 pr-3">Modèle</th>
            <th className="py-2 pr-3">État</th>
            <th className="py-2 pr-3">Certitude</th>
            <th className="py-2 pr-3">Raisons principales</th>
            <th className="py-2 pr-3">Mesure</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((p) => {
            const key = `${p.node_id}:${p.model}`;
            const expanded = open === key;
            return (
              <Fragment key={key}>
                <tr className="cursor-pointer border-b border-slate-100 align-top" onClick={() => setOpen(expanded ? null : key)}
                    aria-expanded={expanded}>
                  <td className="py-2.5 pr-3">
                    <Link href={`/farmers/${p.farmer.id}`} className="font-semibold text-emerald-800 hover:underline"
                          onClick={(e) => e.stopPropagation()}>
                      {p.farmer.name || "Sans nom"}
                    </Link>
                    <div className="text-xs text-slate-500">{zoneName(p.zone)} · {p.device_code}</div>
                  </td>
                  <td className="py-2.5 pr-3 text-slate-700">{MODEL[p.model]}</td>
                  <td className="py-2.5 pr-3"><StateChip state={p.state} status={p.status} /></td>
                  <td className="py-2.5 pr-3"><Certainty p={p} /></td>
                  <td className="py-2.5 pr-3"><Reasons factors={p.factors.slice(0, 3)} /></td>
                  <td className="py-2.5 pr-3 whitespace-nowrap text-slate-600">{dateTime(p.measured_at)}</td>
                </tr>
                {expanded && (
                  <tr className="border-b border-emerald-100 bg-emerald-50/40">
                    <td colSpan={6} className="px-3 py-4">
                      <div className="grid gap-6 lg:grid-cols-2">
                        <div>
                          <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-emerald-700">Ce que voit l&apos;agriculteur</h3>
                          <Explanation p={p} />
                        </div>
                        <div>
                          <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-emerald-700">Raisons (SHAP, vue technique)</h3>
                          <Reasons factors={p.factors} technical />
                          {p.threshold != null && (
                            <p className="mt-2 text-xs text-slate-500">Seuil d&apos;alerte du modèle gel : {p.threshold.toFixed(3)} (90 % des gels détectés)</p>
                          )}
                        </div>
                        <div className="lg:col-span-2">
                          <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-emerald-700">Historique de ce boîtier</h3>
                          <HistoryStrip nodeId={p.node_id} model={p.model} />
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </Fragment>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export function PredictionsView() {
  const now = useNow(10_000);
  const { data, error, reload } = usePolling(getMl, 15_000);
  const [tab, setTab] = useState<"boxes" | "notifications">("boxes");
  if (error && !data) return <ErrorBox message={errorMessage(error)} onRetry={reload} />;
  if (!data) return <p className="text-slate-500">Chargement…</p>;
  const stress = data.predictions.filter((p) => p.model === "stress");
  const frost = data.predictions.filter((p) => p.model === "frost");
  const frostRisk = frost.filter((p) => p.state === "frost_risk").length;
  const problems = stress.filter((p) => p.status === "ok" && p.state !== "none").length;
  const noData = data.predictions.filter((p) => p.status !== "ok").length;
  const countRows = (model: string) =>
    data.counts.filter((c) => c.model === model).map((c) => ({ label: STATE[c.state] ?? c.state, value: c.count, color: STATE_COLOR[c.state] }));
  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Prédictions IA</h1>
      <p className="mt-1 max-w-3xl text-sm text-slate-600">
        Deux modèles pour chaque boîtier, à chaque nouvelle mesure (toutes les 15 min) : le <b>gel de cette nuit</b>{" "}
        (régression logistique, entraînée pour 2 h après le coucher du soleil) et le <b>stress des arbres</b> (LightGBM, 6 classes).
        Seuls les agriculteurs avec le pack payant les voient dans l&apos;application.
      </p>
      <Worker page={data} now={now} />
      <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Kpi label="Boîtiers suivis" value={stress.length} icon="sensors" hint={`${data.predictions.length} prédictions à jour`} />
        <Kpi label="Risque de gel" value={frostRisk} icon="snow" tone={frostRisk ? "alert" : "default"} hint="boîtier(s), cette nuit" />
        <Kpi label="Stress détecté" value={problems} icon="drop" tone={problems ? "alert" : "default"} hint={`${data.open_problems} notification(s) ouvertes`} />
        <Kpi label="Sans prédiction" value={noData} icon="warning" hint="problème de capteur ou pas assez de données" />
      </div>
      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <Card title="Stress des arbres : états actuels"><HBars rows={countRows("stress")} /></Card>
        <Card title="Gel de cette nuit : états actuels"><HBars rows={countRows("frost")} /></Card>
      </div>
      <div className="mt-6">
        <Tabs tabs={[{ id: "boxes", label: "Par boîtier", count: data.predictions.length },
                     { id: "notifications", label: "Notifications dans l'application", count: data.notifications.length }]}
              current={tab} onChange={setTab} />
        <Card title={tab === "boxes" ? "Dernière prédiction de chaque boîtier (cliquez une ligne)" : "Notifications (in-app, sans push)"} className="mt-4">
          {tab === "boxes" ? (
            <Table rows={data.predictions} />
          ) : data.notifications.length ? (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[760px] text-left text-sm">
                <thead>
                  <tr className="border-b border-emerald-100">
                    <th className="py-2 pr-3">Créée</th><th className="py-2 pr-3">Agriculteur · zone</th>
                    <th className="py-2 pr-3">Problème</th><th className="py-2 pr-3">Gravité</th>
                    <th className="py-2 pr-3">Vue</th><th className="py-2 pr-3">Terminée</th>
                  </tr>
                </thead>
                <tbody>
                  {data.notifications.map((n) => (
                    <tr key={n.id} className="border-b border-slate-100">
                      <td className="py-2 pr-3 whitespace-nowrap">{dateTime(n.created_at)}</td>
                      <td className="py-2 pr-3">
                        <Link href={`/farmers/${n.farmer.id}`} className="font-semibold text-emerald-800 hover:underline">{n.farmer.name || "Sans nom"}</Link>
                        <div className="text-xs text-slate-500">{zoneName(n.zone)} · {n.device_code}</div>
                      </td>
                      <td className="py-2 pr-3"><StateChip state={n.state} /></td>
                      <td className="py-2 pr-3">{n.severity === "danger" ? "Danger" : "Attention"}</td>
                      <td className="py-2 pr-3">{n.read_at ? dateTime(n.read_at) : <span className="font-semibold text-amber-700">pas encore</span>}</td>
                      <td className="py-2 pr-3">{n.resolved_at ? dateTime(n.resolved_at) : <span className="font-semibold text-emerald-800">en cours</span>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <Empty>Aucune notification : aucun problème détecté.</Empty>
          )}
        </Card>
      </div>
    </div>
  );
}
