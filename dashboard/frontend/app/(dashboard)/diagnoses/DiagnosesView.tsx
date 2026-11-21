"use client";

// "Diagnostics photo": every photo diagnosis of the app (Gemini, Groq or
// Roboflow; migrations 016 + 018). Codes only: the photos stay private in the
// farmers' folders. "Confirmer par un expert" comes later (Bientôt).
import Link from "next/link";

import { HBars, Kpi } from "@/components/charts";
import { Card, Empty, ErrorBox } from "@/components/ui";
import { errorMessage } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { DISEASE, VERDICT, getDiagnoses } from "@/lib/insights";
import { usePolling } from "@/lib/usePolling";

export function DiagnosesView() {
  const { data, error, reload } = usePolling(getDiagnoses, 60_000);
  if (error && !data) return <ErrorBox message={errorMessage(error)} onRetry={reload} />;
  if (!data) return <p className="text-slate-500">Chargement…</p>;
  const total = data.diagnoses.length;
  const found = (data.by_verdict.likely ?? 0) + (data.by_verdict.unsure ?? 0);
  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Diagnostics photo</h1>
      <p className="mt-1 max-w-3xl text-sm text-slate-600">
        Les photos de feuilles envoyées par les agriculteurs (pack payant). Les photos restent privées ; seuls les résultats sont
        affichés. Validation par un expert et entraînement de notre propre modèle : <b>Bientôt</b>.
      </p>
      <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Kpi label="Photos analysées" value={total} icon="camera" />
        <Kpi label="Maladie probable" value={data.by_verdict.likely ?? 0} icon="warning" />
        <Kpi label="Pas sûr" value={data.by_verdict.unsure ?? 0} icon="clock" />
        <Kpi label="Rien trouvé" value={data.by_verdict.nothing ?? 0} icon="check" hint={total ? `${Math.round(((total - found) / total) * 100)} % des photos` : undefined} />
      </div>
      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <Card title="Maladies reconnues">
          <HBars rows={Object.entries(data.by_class).map(([k, v]) => ({ label: DISEASE[k] ?? k, value: v }))} />
        </Card>
        <Card title="Modèle utilisé">
          <HBars rows={Object.entries(data.by_model).map(([k, v]) => ({ label: k || "—", value: v, color: "#72ae4f" }))} />
        </Card>
      </div>
      <Card title="Toutes les analyses" className="mt-6">
        {total ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-left text-sm">
              <thead><tr className="border-b border-emerald-100">
                <th className="py-2 pr-3">Date</th><th className="py-2 pr-3">Agriculteur</th><th className="py-2 pr-3">Résultat</th>
                <th className="py-2 pr-3">Maladie</th><th className="py-2 pr-3">Confiance</th><th className="py-2 pr-3">Modèle</th>
                <th className="py-2 pr-3">Question à un expert</th>
              </tr></thead>
              <tbody>
                {data.diagnoses.map((d) => (
                  <tr key={d.id} className="border-b border-slate-100">
                    <td className="py-2 pr-3 whitespace-nowrap">{dateTime(d.created_at)}</td>
                    <td className="py-2 pr-3"><Link className="font-semibold text-emerald-800 hover:underline" href={`/farmers/${d.farmer.id}`}>{d.farmer.name || "Sans nom"}</Link></td>
                    <td className="py-2 pr-3">{d.verdict ? VERDICT[d.verdict] ?? d.verdict : d.status === "failed" ? "Échec" : "En cours"}</td>
                    <td className="py-2 pr-3">{d.top_class ? DISEASE[d.top_class] ?? d.top_class : "—"}</td>
                    <td className="py-2 pr-3 tabular-nums">{d.top_confidence != null ? `${Math.round(d.top_confidence * 100)} %` : "—"}</td>
                    <td className="py-2 pr-3 text-slate-600">{d.model ?? "—"}</td>
                    <td className="py-2 pr-3">{d.post_id ? <Link className="text-emerald-800 underline" href={`/community/${d.post_id}`}>voir la question</Link> : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <Empty>Aucune photo analysée pour l&apos;instant.</Empty>}
      </Card>
    </div>
  );
}
