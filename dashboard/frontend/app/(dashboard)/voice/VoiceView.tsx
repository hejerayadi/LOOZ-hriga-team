"use client";

// "Assistant vocal": how "لوز" is used — minutes, conversations, questions,
// tool calls, per day and per farmer. LOOZ never saves the words: no
// transcript exists, only these counts (migration 017).
import Link from "next/link";
import { useState } from "react";

import { DayBars, Kpi } from "@/components/charts";
import { Card, Empty, ErrorBox, Tabs } from "@/components/ui";
import { errorMessage } from "@/lib/api";
import { dateTime, num } from "@/lib/format";
import { VOICE_END, getVoice } from "@/lib/insights";
import { usePolling } from "@/lib/usePolling";

export function VoiceView() {
  const [days, setDays] = useState<"7" | "30" | "90">("30");
  const { data, error, reload } = usePolling(() => getVoice(Number(days)), 60_000);
  if (error && !data) return <ErrorBox message={errorMessage(error)} onRetry={reload} />;
  if (!data) return <p className="text-slate-500">Chargement…</p>;
  const d = data.days.map((x) => x.day);
  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Assistant vocal « لوز »</h1>
      <p className="mt-1 max-w-3xl text-sm text-slate-600">
        Utilisation de l&apos;assistant vocal (pack payant). Aucune parole n&apos;est enregistrée : seulement la durée, le nombre de
        questions et d&apos;outils utilisés (lecture du verger).
      </p>
      <div className="mt-4">
        <Tabs tabs={[{ id: "7", label: "7 jours" }, { id: "30", label: "30 jours" }, { id: "90", label: "90 jours" }]}
              current={days} onChange={setDays} />
      </div>
      <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Kpi label="Minutes" value={num(data.totals.minutes)} icon="voice" trend={data.days.map((x) => x.minutes)} />
        <Kpi label="Conversations" value={data.totals.sessions} icon="community" trend={data.days.map((x) => x.sessions)} />
        <Kpi label="Questions" value={data.totals.questions} icon="clock" />
        <Kpi label="Outils (verger lu)" value={data.totals.tool_calls} icon="orchards" />
      </div>
      <div className="mt-6 grid gap-4 xl:grid-cols-2">
        <Card title="Minutes par jour"><DayBars days={d} values={data.days.map((x) => x.minutes)} unit=" min" label="Minutes par jour" /></Card>
        <Card title="Questions par jour"><DayBars days={d} values={data.days.map((x) => x.questions)} label="Questions par jour" color="#72ae4f" /></Card>
      </div>
      <Card title="Par agriculteur" className="mt-6">
        {data.by_farmer.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead><tr className="border-b border-emerald-100">
                <th className="py-2 pr-3">Agriculteur</th><th className="py-2 pr-3">Conversations</th><th className="py-2 pr-3">Minutes</th>
                <th className="py-2 pr-3">Questions</th><th className="py-2 pr-3">Outils</th><th className="py-2 pr-3">Dernière</th>
              </tr></thead>
              <tbody>
                {data.by_farmer.map((r) => (
                  <tr key={r.farmer.id ?? "?"} className="border-b border-slate-100">
                    <td className="py-2 pr-3"><Link className="font-semibold text-emerald-800 hover:underline" href={`/farmers/${r.farmer.id}`}>{r.farmer.name || "Sans nom"}</Link></td>
                    <td className="py-2 pr-3 tabular-nums">{r.sessions}</td>
                    <td className="py-2 pr-3 tabular-nums">{num(r.minutes)}</td>
                    <td className="py-2 pr-3 tabular-nums">{r.questions}</td>
                    <td className="py-2 pr-3 tabular-nums">{r.tool_calls}</td>
                    <td className="py-2 pr-3 whitespace-nowrap">{dateTime(r.last)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <Empty>Aucune conversation sur la période.</Empty>}
      </Card>
      <Card title="Dernières conversations" className="mt-6">
        {data.sessions.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead><tr className="border-b border-emerald-100">
                <th className="py-2 pr-3">Début</th><th className="py-2 pr-3">Agriculteur</th><th className="py-2 pr-3">Durée</th>
                <th className="py-2 pr-3">Questions · outils</th><th className="py-2 pr-3">Fin</th>
              </tr></thead>
              <tbody>
                {data.sessions.map((s) => (
                  <tr key={s.id} className="border-b border-slate-100">
                    <td className="py-2 pr-3 whitespace-nowrap">{dateTime(s.started_at)}</td>
                    <td className="py-2 pr-3">{s.farmer.name || "Sans nom"}</td>
                    <td className="py-2 pr-3 tabular-nums">{s.charged_seconds != null ? `${Math.round(s.charged_seconds)} s` : "en cours"}</td>
                    <td className="py-2 pr-3 tabular-nums">{s.questions ?? 0} · {s.tool_calls ?? 0}</td>
                    <td className="py-2 pr-3">{s.end_reason ? VOICE_END[s.end_reason] ?? s.end_reason : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <Empty>Aucune conversation.</Empty>}
      </Card>
    </div>
  );
}
