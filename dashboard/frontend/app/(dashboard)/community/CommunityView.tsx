"use client";

// "Communauté": every post (newest first, the hidden ones too), the reports
// of the app's future "Signaler" button, and the moderation log. Open a post
// to hide, show again or delete it (or one of its answers).
import { useCallback, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { ActionList } from "@/components/actions";
import { AuthorLine, DismissButton, HiddenTag, TypeTag, UserText } from "@/components/people";
import { DemoTag, Empty, ErrorBox, Tabs } from "@/components/ui";
import { errorMessage, getCommunity } from "@/lib/api";
import { dateTime, timeAgo } from "@/lib/format";
import { REPORT_REASON, REPORT_STATUS, label } from "@/lib/labels";
import type { CommunityPage, PostRow, ReportRow } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";

type Tab = "posts" | "reports" | "log";
const TABS: Tab[] = ["posts", "reports", "log"];
type Show = "all" | "visible" | "hidden" | "reported";

/** The pictures shipped in the app ("demo:almond_blossoms"), copied in public/community-demo. */
export const DEMO_PICTURES = new Set(["almond_blossoms"]);

function PhotoNote({ p }: { p: PostRow }) {
  if (!p.photo_kind) return null;
  if (p.photo_kind === "demo" && p.photo_demo && DEMO_PICTURES.has(p.photo_demo)) {
    // eslint-disable-next-line @next/next/no-img-element -- a small local picture of the demo
    return <img src={`/community-demo/${p.photo_demo}.jpg`} alt="Photo de démonstration de la publication" className="h-16 w-16 shrink-0 rounded-lg object-cover" />;
  }
  return <span className="shrink-0 rounded bg-slate-100 px-2 py-1 text-xs text-slate-600">{p.photo_kind === "demo" ? "Image de démonstration" : "Photo"}</span>;
}

function PostCard({ p }: { p: PostRow }) {
  return (
    <li>
      <Link
        href={`/community/${p.id}`}
        className={`block rounded-xl border px-4 py-3 hover:border-emerald-300 hover:shadow-sm ${p.hidden ? "border-amber-200 bg-amber-50/40" : "border-slate-200 bg-white"}`}
      >
        <div className="flex flex-wrap items-center gap-2">
          <TypeTag type={p.type} />
          {p.hidden && <HiddenTag />}
          {p.reports_open > 0 && (
            <span className="rounded bg-rose-50 px-1.5 py-0.5 text-[11px] font-semibold text-rose-800">
              {p.reports_open} signalement{p.reports_open > 1 ? "s" : ""}
            </span>
          )}
        </div>
        <div className="mt-2 flex gap-3">
          <div className="min-w-0 flex-1 text-sm">
            <UserText text={p.text} clamp />
          </div>
          <PhotoNote p={p} />
        </div>
        <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
          <AuthorLine author={p.author} when={p.created_at} link={false} />
          <span className="text-xs text-slate-500">
            {p.answers} réponse{p.answers > 1 ? "s" : ""}
            {p.answers_hidden > 0 ? ` (dont ${p.answers_hidden} masquée${p.answers_hidden > 1 ? "s" : ""})` : ""}
          </span>
        </div>
      </Link>
    </li>
  );
}

function Posts({ posts }: { posts: PostRow[] }) {
  const [show, setShow] = useState<Show>("all");
  const [typed, setTyped] = useState("");
  const q = typed.trim().toLowerCase();
  const counts = {
    all: posts.length,
    visible: posts.filter((p) => !p.hidden).length,
    hidden: posts.filter((p) => p.hidden).length,
    reported: posts.filter((p) => p.reports_open > 0).length,
  };
  const shown = posts.filter(
    (p) =>
      (show === "all" || (show === "visible" && !p.hidden) || (show === "hidden" && p.hidden) || (show === "reported" && p.reports_open > 0)) &&
      (!q || p.text.toLowerCase().includes(q) || p.author.name.toLowerCase().includes(q)),
  );
  const CHOICES: { id: Show; label: string }[] = [
    { id: "all", label: "Toutes" },
    { id: "visible", label: "Visibles" },
    { id: "hidden", label: "Masquées" },
    { id: "reported", label: "Signalées" },
  ];
  return (
    <>
      <div className="flex flex-wrap items-center gap-2">
        {CHOICES.map((c) => (
          <button
            key={c.id}
            type="button"
            aria-pressed={show === c.id}
            onClick={() => setShow(c.id)}
            className={`rounded-full px-3 py-1 text-sm font-medium ${show === c.id ? "bg-emerald-700 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200"}`}
          >
            {c.label} ({counts[c.id]})
          </button>
        ))}
        <input
          type="search"
          value={typed}
          onChange={(e) => setTyped(e.target.value)}
          placeholder="Rechercher un texte ou un auteur"
          aria-label="Rechercher un texte ou un auteur"
          className="ml-auto w-full max-w-xs rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
        />
      </div>
      <div className="mt-4">
        {!shown.length ? (
          <Empty>{posts.length ? "Aucune publication ne correspond." : "Aucune publication pour l'instant."}</Empty>
        ) : (
          <ul className="space-y-3">
            {shown.map((p) => (
              <PostCard key={p.id} p={p} />
            ))}
          </ul>
        )}
      </div>
    </>
  );
}

export function Reports({ reports, onChanged }: { reports: ReportRow[]; onChanged: () => void }) {
  const open = reports.filter((r) => r.status === "open");
  const closed = reports.filter((r) => r.status !== "open");
  return (
    <>
      <p className="mb-3 rounded-lg bg-sky-50 px-3 py-2 text-sm text-sky-900">
        Le bouton « Signaler » de l&apos;application arrive <b>bientôt</b> (module de l&apos;application après celui-ci). Les signalements
        des agriculteurs apparaîtront ici : masquez le texte, ou classez le signalement si rien n&apos;est à corriger.
      </p>
      {!reports.length ? (
        <Empty>Aucun signalement pour l&apos;instant.</Empty>
      ) : (
        <ul className="divide-y divide-slate-100 text-sm">
          {[...open, ...closed].map((r) => (
            <li key={r.id} className="flex flex-wrap items-start gap-3 py-2.5">
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-medium text-slate-900">{label(REPORT_REASON, r.reason)}</span>
                  <span className={`rounded px-1.5 py-0.5 text-[11px] font-medium ${r.status === "open" ? "bg-rose-50 text-rose-800" : "bg-slate-100 text-slate-600"}`}>
                    {label(REPORT_STATUS, r.status)}
                  </span>
                  <span className="text-xs text-slate-500">
                    {r.comment_id ? "une réponse" : "une publication"} · par {r.reporter_name || "un utilisateur"} · {dateTime(r.created_at)}
                  </span>
                  {r.demo && <DemoTag />}
                </div>
                {r.note && <p className="mt-0.5 text-slate-600">Note : « {r.note} »</p>}
                <blockquote dir="auto" className="mt-1 line-clamp-2 text-start text-slate-600">
                  {r.target_text || "(texte supprimé)"}
                </blockquote>
              </div>
              <div className="flex gap-1.5">
                {r.target_post_id && (
                  <Link href={`/community/${r.target_post_id}`} className="rounded-lg border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 hover:bg-slate-100">
                    Ouvrir
                  </Link>
                )}
                {r.status === "open" && <DismissButton reportId={r.id} onChanged={onChanged} />}
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}

export function CommunityView() {
  const params = useSearchParams();
  const first = params.get("tab");
  const [tab, setTab] = useState<Tab>(TABS.includes(first as Tab) ? (first as Tab) : "posts");
  const load = useCallback(() => getCommunity(), []);
  const { data, error, receivedAt, reload } = usePolling<CommunityPage>(load, 30000);
  const now = useNow();

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Communauté</h1>
      <p className="mt-1 text-slate-500">
        Les publications et les réponses de l&apos;application (les masquées aussi). Mise à jour automatique toutes les 30 s
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
              { id: "posts", label: "Publications", count: data.posts.length },
              { id: "reports", label: "Signalements", count: data.reports.filter((r) => r.status === "open").length },
              { id: "log", label: "Journal" },
            ]}
            current={tab}
            onChange={setTab}
          />
          <div className="mt-4">
            {tab === "posts" && <Posts posts={data.posts} />}
            {tab === "reports" && <Reports reports={data.reports} onChanged={reload} />}
            {tab === "log" && <ActionList actions={data.actions} empty="Aucune action de modération pour l'instant." />}
          </div>
        </div>
      )}
    </div>
  );
}
