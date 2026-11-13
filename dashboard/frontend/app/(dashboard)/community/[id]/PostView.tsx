"use client";

// One post: its text and photo, EVERY answer (the hidden ones too), its
// reports and the admin actions on it. Masquer / Afficher de nouveau /
// Supprimer on the post and on each answer (reason required; delete asks
// a second time).
import { useCallback, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";

import { ActionList } from "@/components/actions";
import { AuthorLine, HiddenTag, ModerationButtons, TypeTag, UserText } from "@/components/people";
import { Card, Empty, ErrorBox } from "@/components/ui";
import { errorMessage, getPost } from "@/lib/api";
import type { PostDetail } from "@/lib/types";
import { usePolling } from "@/lib/usePolling";
import { DEMO_PICTURES, Reports } from "../CommunityView";

function Photo({ d }: { d: PostDetail }) {
  const p = d.post;
  if (!p.photo_kind) return null;
  if (p.photo_kind === "demo") {
    return p.photo_demo && DEMO_PICTURES.has(p.photo_demo) ? (
      <figure className="mt-4">
        {/* eslint-disable-next-line @next/next/no-img-element -- a small local picture of the demo */}
        <img src={`/community-demo/${p.photo_demo}.jpg`} alt="Photo de la publication" className="max-h-80 rounded-xl object-contain" />
        <figcaption className="mt-1 text-xs text-slate-500">Image de démonstration livrée avec l&apos;application.</figcaption>
      </figure>
    ) : (
      <p className="mt-4 text-sm text-slate-500">Image de démonstration de l&apos;application.</p>
    );
  }
  return d.photo_url ? (
    <figure className="mt-4">
      {/* eslint-disable-next-line @next/next/no-img-element -- a private photo: a link valid 5 minutes */}
      <img src={d.photo_url} alt="Photo de la publication" className="max-h-80 rounded-xl object-contain" />
      <figcaption className="mt-1 text-xs text-slate-500">Photo privée : lien valable 5 minutes (rechargez la page pour un nouveau lien).</figcaption>
    </figure>
  ) : (
    <p className="mt-4 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900">La photo n&apos;a pas pu être chargée (fichier absent du stockage ?).</p>
  );
}

function Details({ d, onChanged, onDeleted }: { d: PostDetail; onChanged: () => void; onDeleted: (photoKept: boolean) => void }) {
  const p = d.post;
  return (
    <>
      <section className={`rounded-xl border p-5 ${p.hidden ? "border-amber-200 bg-amber-50/40" : "border-slate-200 bg-white"}`}>
        <div className="flex flex-wrap items-center gap-2">
          <TypeTag type={p.type} />
          {p.hidden && <HiddenTag text="masquée : invisible dans l'application" />}
        </div>
        <div className="mt-2">
          <AuthorLine author={p.author} when={p.created_at} />
        </div>
        <div className="mt-3 text-base">
          <UserText text={p.text} />
        </div>
        <Photo d={d} />
        <div className="mt-4">
          <ModerationButtons
            target={{ kind: "post", id: p.id, text: p.text, author: p.author.name, hidden: p.hidden, answers: p.answers, photo: p.photo_kind === "storage" }}
            onChanged={onChanged}
            onDeleted={onDeleted}
          />
        </div>
      </section>

      <div className="mt-6">
        <Card title={`Réponses (${d.answers.length})`}>
          {!d.answers.length ? (
            <Empty>Aucune réponse.</Empty>
          ) : (
            <ul className="divide-y divide-slate-100">
              {d.answers.map((a) => (
                <li key={a.id} className={`py-3 ${a.hidden ? "rounded-lg bg-amber-50/50 px-2" : ""}`}>
                  <div className="flex flex-wrap items-center gap-2">
                    <AuthorLine author={a.author} when={a.created_at} />
                    {a.hidden && <HiddenTag />}
                    {a.reports_open > 0 && (
                      <span className="rounded bg-rose-50 px-1.5 py-0.5 text-[11px] font-semibold text-rose-800">
                        {a.reports_open} signalement{a.reports_open > 1 ? "s" : ""}
                      </span>
                    )}
                  </div>
                  <div className="mt-1 text-sm">
                    <UserText text={a.text} />
                  </div>
                  <div className="mt-2">
                    <ModerationButtons target={{ kind: "comment", id: a.id, text: a.text, author: a.author.name, hidden: a.hidden }} onChanged={onChanged} />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <Card title="Signalements">
          <Reports reports={d.reports} onChanged={onChanged} />
        </Card>
        <Card title="Actions des administrateurs">
          <ActionList actions={d.actions} empty="Aucune action d'administrateur sur cette publication." />
        </Card>
      </div>
    </>
  );
}

export function PostView() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [deleted, setDeleted] = useState<{ photoKept: boolean } | null>(null);
  const load = useCallback(() => getPost(id), [id]);
  const { data, error, reload } = usePolling<PostDetail>(load, 30000);

  if (deleted) {
    return (
      <div>
        <p className="rounded-lg bg-emerald-50 px-4 py-3 text-emerald-900">
          Publication supprimée. Le journal garde une copie du texte.
          {deleted.photoKept && " Sa photo n'a pas pu être effacée du stockage : supprimez-la dans Supabase › Storage › community."}
        </p>
        <button type="button" onClick={() => router.push("/community")} className="mt-4 text-sm font-medium text-emerald-800 hover:underline">
          ← Retour à la communauté
        </button>
      </div>
    );
  }

  return (
    <div>
      <Link href="/community" className="text-sm font-medium text-emerald-800 hover:underline">
        ← Communauté
      </Link>
      <h1 className="mt-3 text-2xl font-bold text-slate-900">Publication</h1>
      <div className="mt-4">
        {error !== null && <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />}
        {!data && error === null && <p className="text-slate-500">Chargement…</p>}
        {data && <Details d={data} onChanged={reload} onDeleted={(photoKept) => setDeleted({ photoKept })} />}
      </div>
    </div>
  );
}
