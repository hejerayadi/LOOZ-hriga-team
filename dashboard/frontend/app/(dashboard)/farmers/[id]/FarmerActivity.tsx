"use client";

// "Activité dans l'application": EVERYTHING one farmer did and got in the
// app, on his page — a timeline, the ML predictions of his boxes (reasons,
// Groq texts, notifications), his photo diagnoses, his voice conversations
// (counts only), his questions / answers / reports / "Moi aussi", his
// payments and the admin actions on him.
import Link from "next/link";
import { useCallback, useState } from "react";

import { Kpi } from "@/components/charts";
import { Certainty, Explanation, Reasons, StateChip } from "@/components/ml";
import { Empty, ErrorBox, Tabs } from "@/components/ui";
import { errorMessage } from "@/lib/api";
import { dateTime, money, num } from "@/lib/format";
import { DISEASE, MODEL, TIMELINE, VERDICT, VOICE_END, getFarmerActivity, STATE } from "@/lib/insights";
import { usePolling } from "@/lib/usePolling";

type Tab = "timeline" | "ml" | "diagnoses" | "voice" | "community" | "payments" | "actions";

function Table({ head, rows }: { head: string[]; rows: React.ReactNode[][] }) {
  if (!rows.length) return <Empty>Rien pour l&apos;instant.</Empty>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[600px] text-left text-sm">
        <thead><tr className="border-b border-emerald-100">{head.map((h) => <th key={h} className="py-2 pr-3">{h}</th>)}</tr></thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className="border-b border-slate-100 align-top">{r.map((c, j) => <td key={j} className="py-2 pr-3">{c}</td>)}</tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function FarmerActivity({ farmerId }: { farmerId: string }) {
  const load = useCallback(() => getFarmerActivity(farmerId), [farmerId]);
  const { data, error, reload } = usePolling(load, 30_000);
  const [tab, setTab] = useState<Tab>("timeline");
  if (error && !data) return <div className="mt-6"><ErrorBox message={errorMessage(error)} onRetry={reload} /></div>;
  if (!data) return <p className="mt-6 text-slate-500">Chargement de l&apos;activité…</p>;
  const ml = data.ml;
  const c = data.community;
  return (
    <section className="mt-8">
      <h2 className="text-lg font-extrabold text-emerald-800">Activité dans l&apos;application</h2>
      <div className="mt-3 grid gap-4 sm:grid-cols-3 xl:grid-cols-6">
        <Kpi label="Problèmes ouverts (IA)" value={ml.open_problems} icon="predictions" tone={ml.open_problems ? "alert" : "default"} />
        <Kpi label="Diagnostics photo" value={data.diagnoses.diagnoses.length} icon="camera" />
        <Kpi label="Minutes de voix" value={num(data.voice.totals.minutes)} icon="voice" hint="90 derniers jours" />
        <Kpi label="Questions" value={c.posts.length} icon="community" />
        <Kpi label="Réponses" value={c.answers.length} icon="community" />
        <Kpi label="« Moi aussi »" value={c.me_too} icon="alerts" />
      </div>
      <div className="mt-5">
        <Tabs<Tab>
          tabs={[
            { id: "timeline", label: "Chronologie", count: data.timeline.length },
            { id: "ml", label: "Prédictions IA", count: ml.predictions.length },
            { id: "diagnoses", label: "Diagnostics photo", count: data.diagnoses.diagnoses.length },
            { id: "voice", label: "Assistant vocal", count: data.voice.totals.sessions },
            { id: "community", label: "Communauté", count: c.posts.length + c.answers.length + c.reports.length },
            { id: "payments", label: "Paiements", count: data.payments.length },
            { id: "actions", label: "Actions admin", count: data.admin_actions.length },
          ]}
          current={tab}
          onChange={setTab}
        />
      </div>
      <div className="mt-4 rounded-2xl border border-emerald-100 bg-white p-5 shadow-[0_8px_24px_rgba(15,61,43,0.06)]">
        {tab === "timeline" && (
          <Table head={["Quand", "Quoi", "Détail"]} rows={data.timeline.map((e) => [
            <span key="t" className="whitespace-nowrap">{dateTime(e.at)}</span>,
            <span key="k" className="font-semibold text-emerald-800">{TIMELINE[e.kind] ?? e.kind}</span>,
            <span key="d" className="text-slate-600">
              {e.kind === "notification" ? `${STATE[e.label ?? ""] ?? e.label} · zone ${e.detail}`
                : e.kind === "diagnosis" ? `${VERDICT[e.label ?? ""] ?? e.label}${e.detail ? ` · ${DISEASE[String(e.detail)] ?? e.detail}` : ""}`
                : e.kind === "voice" ? `${e.detail} min · ${VOICE_END[e.label ?? ""] ?? e.label ?? "en cours"}`
                : e.kind === "payment" ? `${e.label === "paid_demo" ? "payé (démo)" : "refusé (démo)"} · ${e.detail} DT`
                : String(e.detail ?? e.label ?? "")}
            </span>,
          ])} />
        )}
        {tab === "ml" && (
          <div className="space-y-6">
            <Table head={["Zone · boîtier", "Modèle", "État", "Certitude", "Raisons", "Explication (ce que voit l'agriculteur)"]}
                   rows={ml.predictions.map((p) => [
                     <span key="z">{p.zone.name || `Zone ${p.zone.letter}`}<div className="text-xs text-slate-500">{p.device_code}</div></span>,
                     MODEL[p.model], <StateChip key="s" state={p.state} status={p.status} />, <Certainty key="c" p={p} />,
                     <Reasons key="r" factors={p.factors.slice(0, 3)} />, <div key="e" className="max-w-md"><Explanation p={p} /></div>,
                   ])} />
            <div>
              <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-emerald-700">Notifications dans l&apos;application</h3>
              <Table head={["Créée", "Zone", "Problème", "Vue", "Terminée"]} rows={ml.notifications.map((n) => [
                dateTime(n.created_at), n.zone.name || `Zone ${n.zone.letter}`, <StateChip key="s" state={n.state} />,
                n.read_at ? dateTime(n.read_at) : "pas encore", n.resolved_at ? dateTime(n.resolved_at) : "en cours",
              ])} />
            </div>
          </div>
        )}
        {tab === "diagnoses" && (
          <Table head={["Date", "Résultat", "Maladie", "Confiance", "Modèle"]} rows={data.diagnoses.diagnoses.map((d) => [
            dateTime(d.created_at), d.verdict ? VERDICT[d.verdict] ?? d.verdict : d.status,
            d.top_class ? DISEASE[d.top_class] ?? d.top_class : "—",
            d.top_confidence != null ? `${Math.round(d.top_confidence * 100)} %` : "—", d.model ?? "—",
          ])} />
        )}
        {tab === "voice" && (
          <>
            <p className="mb-3 text-sm text-slate-500">Aucune parole n&apos;est enregistrée : seulement la durée et les nombres.</p>
            <Table head={["Début", "Durée", "Questions", "Outils", "Fin"]} rows={data.voice.sessions.map((s) => [
              dateTime(s.started_at), s.charged_seconds != null ? `${Math.round(s.charged_seconds)} s` : "en cours",
              s.questions ?? 0, s.tool_calls ?? 0, s.end_reason ? VOICE_END[s.end_reason] ?? s.end_reason : "—",
            ])} />
          </>
        )}
        {tab === "community" && (
          <div className="space-y-6">
            <Table head={["Date", "Question", "État"]} rows={c.posts.map((p) => [
              dateTime(p.date), <Link key="l" href={`/community/${p.id}`} className="text-emerald-800 hover:underline">{p.text.slice(0, 120)}</Link>,
              p.hidden ? "masquée" : "visible",
            ])} />
            <Table head={["Date", "Réponse", "État"]} rows={c.answers.map((a) => [
              dateTime(a.created_at), <Link key="l" href={`/community/${a.post_id}`} className="text-emerald-800 hover:underline">{a.text.slice(0, 120)}</Link>,
              a.hidden ? "masquée" : "visible",
            ])} />
            <Table head={["Date", "Signalement fait", "Statut"]} rows={c.reports.map((r) => [dateTime(r.created_at), r.reason, r.status])} />
          </div>
        )}
        {tab === "payments" && (
          <div className="space-y-6">
            <Table head={["Début", "Fin", "Pack", "Boîtiers", "État"]} rows={data.subscriptions.map((s) => [
              dateTime(s.started_at), dateTime(s.ends_at), s.plan === "free" ? "Gratuit" : "Premium", s.nodes ?? "—", s.status,
            ])} />
            <Table head={["Date", "Montant", "Boîtiers", "Résultat (démo, aucun argent réel)"]} rows={data.payments.map((p) => [
              dateTime(p.created_at), money(p.amount_millimes), p.nodes ?? "—", p.status === "paid_demo" ? "payé" : p.status === "failed_demo" ? "refusé" : p.status,
            ])} />
          </div>
        )}
        {tab === "actions" && (
          <Table head={["Date", "Admin", "Action", "Raison"]} rows={data.admin_actions.map((a) => [
            dateTime(a.created_at), a.admin_name, a.action, a.reason ?? "—",
          ])} />
        )}
      </div>
    </section>
  );
}
