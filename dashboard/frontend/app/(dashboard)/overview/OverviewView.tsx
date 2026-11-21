"use client";

// "Vue d'ensemble": the key numbers of LOOZ and the "À faire" list, each
// with a link to the page where it is done. One call (admin_overview() of
// migration 013), again every 30 s while the page is visible.
import Link from "next/link";

import { useAdmin } from "@/components/AdminGuard";
import { DayBars, Kpi } from "@/components/charts";
import { Card } from "@/components/ui";
import { STATE, getMl, getTrends } from "@/lib/insights";
import { Empty, ErrorBox } from "@/components/ui";
import { errorMessage, getOverview } from "@/lib/api";
import { date, money, timeAgo } from "@/lib/format";
import { FAULT, GOVERNORATES, LEVEL, label, personName } from "@/lib/labels";
import type { Overview, TodoBox } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";

function plural(n: number, one: string, many: string): string {
  return `${n} ${n > 1 ? many : one}`;
}

function Tile({
  title,
  value,
  href,
  children,
}: {
  title: string;
  value: React.ReactNode;
  href: string;
  children?: React.ReactNode;
}) {
  return (
    <Link href={href} className="group rounded-2xl border border-emerald-100 bg-white p-4 shadow-[0_8px_24px_rgba(15,61,43,0.06)] transition hover:-translate-y-0.5 hover:border-emerald-300">
      <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wide text-emerald-700">
        {title}
      </div>
      <div className="mt-1 text-3xl font-extrabold tabular-nums text-emerald-900">{value}</div>
      <div className="mt-1 text-sm text-slate-600">{children}</div>
    </Link>
  );
}

function Chip({ n, text, tone }: { n: number; text: string; tone: string }) {
  if (!n) return null;
  return <span className={`mr-1 mt-1 inline-block rounded px-1.5 py-0.5 text-xs font-medium ${tone}`}>{`${n} ${text}`}</span>;
}

function Tiles({ o }: { o: Overview }) {
  const b = o.boxes;
  return (
    <div className="mt-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <Tile title="Agriculteurs" value={o.farmers.total} href="/farmers">
        {plural(o.farmers.paid, "pack payant actif", "packs payants actifs")} · {o.farmers.demo} démo
      </Tile>
      <Tile title="Boîtiers de capteurs" value={b.total} href="/sensors">
        <Chip n={b.online} text="en ligne" tone="bg-emerald-50 text-emerald-800" />
        <Chip n={b.sensor_problem} text="problème" tone="bg-amber-50 text-amber-800" />
        <Chip n={b.offline} text="hors ligne" tone="bg-rose-50 text-rose-800" />
        <Chip n={b.waiting} text="en attente" tone="bg-sky-50 text-sky-800" />
        <Chip n={b.installed} text="sans données" tone="bg-slate-100 text-slate-700" />
        {b.critical > 0 && <Chip n={b.critical} text={label(LEVEL, "critical").toLowerCase()} tone="bg-red-600 text-white" />}
      </Tile>
      <Tile title="Experts" value={o.experts.verified + o.experts.waiting} href={o.experts.waiting ? "/users?state=to_verify" : "/users"}>
        {o.experts.verified} vérifié{o.experts.verified > 1 ? "s" : ""} · {o.experts.waiting} à vérifier
      </Tile>
      <Tile title="Vergers" value={o.orchards.complete + o.orchards.draft} href="/orchards">
        {o.orchards.complete} construit{o.orchards.complete > 1 ? "s" : ""} · {o.orchards.draft} brouillon{o.orchards.draft > 1 ? "s" : ""}
      </Tile>
      <Tile title="Alertes régionales" value={o.regional_alerts.active} href="/alerts">
        {o.regional_alerts.active ? `actives · dont ${o.regional_alerts.danger} danger` : "aucune alerte en cours"}
      </Tile>
      <Tile title="Communauté (7 jours)" value={o.community.posts_week} href="/community">
        publications · {plural(o.community.answers_week, "réponse", "réponses")} · {o.community.hidden} masquée
        {o.community.hidden > 1 ? "s" : ""} · {plural(o.community.reports_open, "signalement", "signalements")}
      </Tile>
      <Tile title="Paiements démo (ce mois)" value={money(o.demo_payments_month.millimes)} href="/subscriptions?tab=payments">
        {plural(o.demo_payments_month.count, "paiement", "paiements")} de démonstration (aucun argent réel)
      </Tile>
      <Tile title="Visites d'installation" value={o.visits_open} href="/sensors?tab=visits">
        à planifier ou en cours
      </Tile>
    </div>
  );
}

function BoxItem({ b, now, problem }: { b: TodoBox; now: number; problem: boolean }) {
  const href = b.farmer_id ? `/farmers/${b.farmer_id}` : "/sensors";
  return (
    <li>
      <Link href={href} className="flex flex-wrap items-baseline gap-x-2 rounded-lg px-2 py-1.5 hover:bg-slate-50">
        <span className="font-mono font-semibold text-slate-900">{b.device_code ?? "sans code"}</span>
        <span className="text-xs text-slate-500">zone {b.zone_letter ?? "?"}</span>
        <span className="text-slate-700">{personName(b.farmer_name, "Sans nom")}</span>
        {problem ? (
          <span className="text-xs text-amber-800">{b.faults.map((f) => label(FAULT, f)).join(", ") || label(LEVEL, b.level)}</span>
        ) : (
          <span className="text-xs text-slate-500">{b.refused_at ? `envoie des données refusées (${timeAgo(b.refused_at, now)})` : "pas encore de données"}</span>
        )}
      </Link>
    </li>
  );
}

function TodoGroup({
  title,
  count,
  shown,
  href,
  linkText,
  children,
}: {
  title: string;
  count: number;
  shown?: number;
  href: string;
  linkText: string;
  children: React.ReactNode;
}) {
  if (!count) return null;
  const more = shown === undefined ? 0 : count - shown;
  return (
    <div className="py-3">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h3 className="font-semibold text-slate-900">
          {title} <span className="ml-1 rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">{count}</span>
        </h3>
        <Link href={href} className="text-sm font-medium text-emerald-800 hover:underline">
          {linkText} →
        </Link>
      </div>
      <ul className="mt-1 text-sm">{children}</ul>
      {more > 0 && (
        <p className="px-2 text-xs text-slate-500">
          {more > 1 ? `et ${more} autres` : "et 1 autre"}
        </p>
      )}
    </div>
  );
}

function Todo({ o, now }: { o: Overview; now: number }) {
  const t = o.todo;
  const total = t.boxes_waiting.length + t.sensor_problems.length + t.experts.length + t.reports.length + o.visits_open;
  return (
    <section className="mt-6 rounded-2xl border border-emerald-100 bg-white p-5 shadow-[0_8px_24px_rgba(15,61,43,0.06)]">
      <h2 className="text-sm font-bold uppercase tracking-wide text-emerald-700">À faire</h2>
      {total === 0 ? (
        <div className="mt-3">
          <Empty>Rien à faire pour l&apos;instant.</Empty>
        </div>
      ) : (
        <div className="divide-y divide-slate-100">
          <TodoGroup title="Boîtiers à accepter" count={o.boxes.waiting} shown={t.boxes_waiting.length} href="/sensors?tab=waiting" linkText="Ouvrir la liste">
            {t.boxes_waiting.map((b) => (
              <BoxItem key={b.node_id} b={b} now={now} problem={false} />
            ))}
          </TodoGroup>
          <TodoGroup title="Problèmes de capteurs" count={o.boxes.sensor_problem} shown={t.sensor_problems.length} href="/sensors" linkText="Tous les boîtiers">
            {t.sensor_problems.map((b) => (
              <BoxItem key={b.node_id} b={b} now={now} problem />
            ))}
          </TodoGroup>
          <TodoGroup title="Visites d'installation à suivre" count={o.visits_open} href="/sensors?tab=visits" linkText="Ouvrir les visites">
            <li className="px-2 py-1.5 text-slate-600">Appeler l&apos;agriculteur, puis poser et accepter ses boîtiers.</li>
          </TodoGroup>
          <TodoGroup title="Experts à vérifier" count={o.experts.waiting} shown={t.experts.length} href="/users?state=to_verify" linkText="Vérifier les experts">
            {t.experts.map((e) => (
              <li key={e.id}>
                <Link href={`/users/${e.id}`} className="flex flex-wrap items-baseline gap-x-2 rounded-lg px-2 py-1.5 hover:bg-slate-50">
                  <span className="text-slate-900">{personName(e.name, "Sans nom")}</span>
                  <span className="text-xs text-slate-500">
                    {label(GOVERNORATES, e.governorate)} · inscrit le {date(e.created_at)}
                  </span>
                </Link>
              </li>
            ))}
          </TodoGroup>
          <TodoGroup title="Signalements de la communauté" count={o.community.reports_open} shown={t.reports.length} href="/community?tab=reports" linkText="Ouvrir les signalements">
            {t.reports.map((r) => (
              <li key={r.id}>
                <Link href={r.post_id ? `/community/${r.post_id}` : "/community?tab=reports"} className="block rounded-lg px-2 py-1.5 text-slate-700 hover:bg-slate-50">
                  {r.comment_id ? "Une réponse" : "Une publication"} signalée · {date(r.created_at)}
                </Link>
              </li>
            ))}
          </TodoGroup>
        </div>
      )}
    </section>
  );
}

/** The last 30 days: the activity of the app, and what the predictions say now. */
function Trends() {
  const trends = usePolling(() => getTrends(30), 120_000);
  const ml = usePolling(getMl, 30_000);
  const t = trends.data;
  if (!t) return trends.error ? null : <p className="mt-6 text-slate-500">Chargement des tendances…</p>;
  const sum = (k: keyof typeof t.series) => t.series[k].reduce((a, b) => a + b, 0);
  const preds = ml.data?.predictions ?? [];
  const frostRisk = preds.filter((p) => p.state === "frost_risk").length;
  const stressed = preds.filter((p) => p.model === "stress" && p.status === "ok" && p.state !== "none");
  return (
    <>
      <h2 className="mt-8 text-lg font-extrabold text-emerald-800">Les 30 derniers jours</h2>
      <div className="mt-3 grid gap-4 sm:grid-cols-2 xl:grid-cols-6">
        <Kpi label="Inscriptions" value={sum("signups")} icon="userPlus" trend={t.series.signups} href="/users" />
        <Kpi label="Paiements démo" value={`${sum("payments_dt")} DT`} icon="subscriptions" trend={t.series.payments_dt} href="/subscriptions?tab=payments" />
        <Kpi label="Problèmes (IA)" value={sum("problems")} icon="predictions" trend={t.series.problems} href="/predictions" />
        <Kpi label="Diagnostics photo" value={sum("diagnoses")} icon="camera" trend={t.series.diagnoses} href="/diagnoses" />
        <Kpi label="Minutes de voix" value={Math.round(sum("voice_minutes"))} icon="voice" trend={t.series.voice_minutes} href="/voice" />
        <Kpi label="Questions publiées" value={sum("posts")} icon="community" trend={t.series.posts} href="/community" />
      </div>
      <div className="mt-4 grid gap-4 xl:grid-cols-2">
        <Card title="Inscriptions par jour">
          <DayBars days={t.days} values={t.series.signups} label="Inscriptions par jour" />
        </Card>
        <Card title="Prédictions IA en ce moment" action={<Link href="/predictions" className="text-sm font-semibold text-emerald-800 hover:underline">Ouvrir →</Link>}>
          {preds.length === 0 ? (
            <p className="text-sm text-slate-500">Aucune prédiction pour l&apos;instant.</p>
          ) : (
            <ul className="space-y-2 text-sm">
              <li className="flex justify-between"><span>Risque de gel cette nuit</span><b className="tabular-nums">{frostRisk}</b></li>
              <li className="flex justify-between"><span>Zones avec un stress</span><b className="tabular-nums">{stressed.length}</b></li>
              {stressed.slice(0, 4).map((p) => (
                <li key={p.node_id} className="truncate text-xs text-slate-600">
                  {p.farmer.name} · zone {p.zone.letter} : {STATE[p.state ?? ""] ?? p.state}
                </li>
              ))}
              <li className="flex justify-between"><span>Notifications ouvertes</span><b className="tabular-nums">{ml.data?.open_problems ?? 0}</b></li>
            </ul>
          )}
        </Card>
        <Card title="Problèmes détectés par jour (IA)">
          <DayBars days={t.days} values={t.series.problems} label="Problèmes détectés par jour" color="#69a66f" />
        </Card>
        <Card title="Minutes de l'assistant vocal">
          <DayBars days={t.days} values={t.series.voice_minutes} unit=" min" label="Minutes de voix par jour" color="#72ae4f" />
        </Card>
      </div>
    </>
  );
}

export function OverviewView() {
  const admin = useAdmin();
  const { data, error, receivedAt, reload } = usePolling(getOverview, 30000);
  const now = useNow();
  const serverNow = data && receivedAt ? new Date(data.server_time).getTime() + (now - receivedAt) : now;

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Bienvenue, {personName(admin.name)}</h1>
      <p className="mt-1 text-slate-500">
        Vue d&apos;ensemble de LOOZ · mise à jour automatique toutes les 30 s
        {receivedAt ? ` · dernière ${timeAgo(new Date(receivedAt).toISOString(), now)}` : ""}
      </p>
      {error !== null && (
        <div className="mt-4">
          <ErrorBox message={(data ? "Chiffres non mis à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      {!data && error === null && <p className="mt-6 text-slate-500">Chargement…</p>}
      {data && (
        <>
          <Tiles o={data} />
          <Trends />
          <Todo o={data} now={serverNow} />
        </>
      )}
    </div>
  );
}
