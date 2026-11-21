"use client";

// Pieces of the ML predictions, shared by "Prédictions IA" and a farmer's
// page: the state chip, the reasons (SHAP) as bars, the explanation (French
// + the farmer's Derja), the history of a box as a strip of states.
import { useEffect, useState } from "react";

import { dateTime, shortDateTime } from "@/lib/format";
import {
  FACTOR,
  type Factor,
  type HistoryPoint,
  type Prediction,
  STATE,
  STATE_COLOR,
  factorLabel,
  getMlHistory,
} from "@/lib/insights";

export function StateChip({ state, status }: { state: string | null; status?: string }) {
  const code = status && status !== "ok" ? status : state ?? "not_enough_data";
  return (
    <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-bold text-white"
          style={{ background: STATE_COLOR[code] ?? "#9aa8a0" }}>
      {STATE[code] ?? code}
    </span>
  );
}

export function Certainty({ p }: { p: Pick<Prediction, "certainty" | "confidence" | "model" | "state"> }) {
  if (!p.certainty) return <span className="text-slate-400">—</span>;
  // Frost: the % is the probability of frost (also when "no frost" is predicted).
  const pct = p.confidence == null ? "" : ` · ${p.model === "frost" ? "gel " : ""}${Math.round(p.confidence * 100)} %`;
  return (
    <span className={p.certainty === "likely" ? "font-semibold text-emerald-800" : "text-amber-700"}>
      {p.certainty === "likely" ? "Probable" : "Pas sûr"}
      <span className="text-slate-500">{pct}</span>
    </span>
  );
}

/** The main reasons: farmer words + a bar; `technical` adds the feature, its value and its SHAP value. */
export function Reasons({ factors, technical = false }: { factors: Factor[]; technical?: boolean }) {
  if (!factors.length) return <span className="text-slate-400">—</span>;
  return (
    <ul className="space-y-1.5">
      {factors.map((f) => (
        <li key={f.code + (f.feature ?? "")} className="min-w-[180px]">
          <div className="flex items-baseline justify-between gap-2 text-xs">
            <span className="font-semibold text-slate-700">{factorLabel(f)}</span>
            {f.share != null && <span className="tabular-nums text-slate-500">{Math.round(f.share * 100)} %</span>}
          </div>
          <div className="mt-0.5 h-1.5 w-full rounded-full bg-emerald-50">
            <div className="h-1.5 rounded-full bg-emerald-500" style={{ width: `${Math.max(6, (f.share ?? 0) * 100)}%` }} />
          </div>
          {technical && (
            <div className="mt-0.5 font-mono text-[11px] text-slate-500">
              {f.feature} = {f.value ?? "—"} · SHAP {f.shap ?? "—"} · code {f.code}
              {FACTOR[f.code] ? "" : " (inconnu)"}
            </div>
          )}
        </li>
      ))}
    </ul>
  );
}

export function Explanation({ p }: { p: Prediction }) {
  const groq = p.explanation_source?.startsWith("groq:");
  return (
    <div className="space-y-2 text-sm">
      {p.explanation_fr ? (
        <>
          <p className="text-slate-800">{p.explanation_fr}</p>
          {p.action_fr && <p className="rounded-lg bg-emerald-50 px-3 py-1.5 font-semibold text-emerald-900">À faire : {p.action_fr}</p>}
          {p.explanation_ar && (
            <p dir="rtl" lang="ar" className="text-slate-700">
              {p.explanation_ar} <span className="font-semibold">{p.action_ar}</span>
            </p>
          )}
        </>
      ) : (
        <p className="text-slate-500">Texte simple écrit par l&apos;application à partir des codes (pas de texte de Groq).</p>
      )}
      <p className="text-xs text-slate-400">
        {groq ? `Texte : ${p.explanation_source?.slice(5)} (Groq)` : "Texte : modèle de l'application"} · modèle {p.model_version ?? "—"}
      </p>
    </div>
  );
}

/** The history of one box: a strip of states (one block per point) + the dates. */
export function HistoryStrip({ nodeId, model }: { nodeId: string; model: string }) {
  const [points, setPoints] = useState<HistoryPoint[] | null>(null);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    let live = true;
    getMlHistory(nodeId)
      .then((r) => live && setPoints(r.points.filter((p) => p.model === model)))
      .catch(() => live && setFailed(true));
    return () => {
      live = false;
    };
  }, [nodeId, model]);
  if (failed) return <p className="text-sm text-rose-700">Historique indisponible.</p>;
  if (!points) return <p className="text-sm text-slate-400">Chargement de l&apos;historique…</p>;
  if (!points.length) return <p className="text-sm text-slate-400">Pas encore d&apos;historique.</p>;
  const shown = points.slice(-96);
  return (
    <div>
      <div className="flex h-7 w-full overflow-hidden rounded-lg ring-1 ring-emerald-100" role="img"
           aria-label={`Historique : ${shown.length} points, du ${dateTime(shown[0].measured_at)} au ${dateTime(shown[shown.length - 1].measured_at)}`}>
        {shown.map((p) => {
          const code = p.status !== "ok" ? p.status : p.state ?? "not_enough_data";
          return (
            <div key={p.measured_at} className="h-full flex-1" style={{ background: STATE_COLOR[code] ?? "#9aa8a0" }}
                 title={`${shortDateTime(p.measured_at)} · ${STATE[code] ?? code}${p.confidence != null ? ` · ${Math.round(p.confidence * 100)} %` : ""}`} />
          );
        })}
      </div>
      <div className="mt-1 flex justify-between text-xs text-slate-500">
        <span>{shortDateTime(shown[0].measured_at)}</span>
        <span>{shown.filter((p) => p.changed).length} changement(s)</span>
        <span>{shortDateTime(shown[shown.length - 1].measured_at)}</span>
      </div>
    </div>
  );
}
