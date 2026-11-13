"use client";

// One account: who it is, its pack, its login, its latest posts and answers,
// the expert badge and blocking, and every admin action on it.
import { useCallback } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";

import { ActionList } from "@/components/actions";
import { PackText } from "@/components/iot";
import { FakeTag, HiddenTag, RoleBadge, TypeTag, UserButtons, UserText, VerifiedBadge } from "@/components/people";
import { Card, DemoTag, Empty, ErrorBox, Fact } from "@/components/ui";
import { errorMessage, getUser } from "@/lib/api";
import { date, dateTime, phone, timeAgo } from "@/lib/format";
import { GOVERNORATES, LANGUAGE, label, personName } from "@/lib/labels";
import type { UserDetail } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";

function Details({ d, now, onChanged }: { d: UserDetail; now: number; onChanged: () => void }) {
  const u = d.user;
  const orchard = u.orchard_status === "complete" ? "construit" : u.orchard_status === "draft" ? "brouillon" : "aucun";
  return (
    <>
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="text-2xl font-bold text-slate-900">{personName(u.name, "Sans nom")}</h1>
        <RoleBadge role={u.role} />
        {u.role === "expert" && u.verified && <VerifiedBadge />}
        {u.fake ? <FakeTag /> : u.demo && <DemoTag />}
        {u.blocked && !u.fake && <span className="rounded-full bg-rose-50 px-2.5 py-0.5 text-xs font-medium text-rose-800">Bloqué</span>}
      </div>
      {u.fake && (
        <p className="mt-2 text-sm text-violet-800">
          Personne fictive de la communauté (données de démonstration) : elle ne peut pas se connecter.
        </p>
      )}
      <div className="mt-4">
        <UserButtons user={u} onChanged={onChanged} small={false} />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <Card title="Compte">
          <div className="grid grid-cols-2 gap-4">
            <Fact name="Téléphone" value={u.phone ? phone(u.phone) : "—"} />
            {u.role === "admin" && <Fact name="E-mail" value={<span className="break-all text-base">{u.email ?? "—"}</span>} />}
            <Fact name="Gouvernorat" value={label(GOVERNORATES, u.governorate)} />
            <Fact name="Langue de l'application" value={label(LANGUAGE, u.language)} />
            <Fact name="Inscrit le" value={date(u.created_at)} />
            <Fact
              name="Dernière connexion"
              value={u.fake ? "—" : u.last_sign_in_at ? <span title={dateTime(u.last_sign_in_at)}>{timeAgo(u.last_sign_in_at, now)}</span> : "jamais"}
            />
          </div>
          {u.demo_login && (
            <p className="mt-3 text-xs text-slate-500">Compte créé avec la connexion de démonstration (n&apos;importe quel numéro, n&apos;importe quel code).</p>
          )}
        </Card>
        {u.role === "farmer" && (
          <Card
            title="Pack et verger"
            action={
              <Link href={`/farmers/${u.id}`} className="text-sm font-medium text-emerald-800 hover:underline">
                Page de l&apos;agriculteur →
              </Link>
            }
          >
            <div className="grid grid-cols-2 gap-4">
              <Fact name="Pack" value={<PackText pack={u.pack} />} />
              <Fact name="Verger" value={orchard} />
            </div>
          </Card>
        )}
        {u.role === "expert" && (
          <Card title="Expert">
            <div className="grid grid-cols-2 gap-4">
              <Fact name="Badge d'expert vérifié (◆)" value={u.verified ? "oui" : "à vérifier"} />
              <Fact name="Organisme" value={<span dir="auto">{u.organisation || "—"}</span>} />
              <Fact name="Spécialité" value={<span dir="auto">{u.speciality || "—"}</span>} />
            </div>
          </Card>
        )}
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <Card title={`Publications (${u.posts})`}>
          {!d.posts.length ? (
            <Empty>Aucune publication.</Empty>
          ) : (
            <ul className="divide-y divide-slate-100">
              {d.posts.map((p) => (
                <li key={p.id} className="py-2">
                  <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500">
                    <TypeTag type={p.type} />
                    {p.hidden && <HiddenTag />}
                    <span>{dateTime(p.created_at)}</span>
                    <span>
                      · {p.answers} réponse{p.answers > 1 ? "s" : ""}
                    </span>
                    <Link href={`/community/${p.id}`} className="ml-auto font-medium text-emerald-800 hover:underline">
                      Ouvrir →
                    </Link>
                  </div>
                  <div className="mt-1 text-sm">
                    <UserText text={p.text} clamp />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
        <Card title={`Réponses (${u.answers})`}>
          {!d.answers.length ? (
            <Empty>Aucune réponse.</Empty>
          ) : (
            <ul className="divide-y divide-slate-100">
              {d.answers.map((a) => (
                <li key={a.id} className="py-2">
                  <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500">
                    {a.hidden && <HiddenTag />}
                    <span>{dateTime(a.created_at)}</span>
                    <Link href={`/community/${a.post_id}`} className="ml-auto font-medium text-emerald-800 hover:underline">
                      Voir la publication →
                    </Link>
                  </div>
                  <div className="mt-1 text-sm">
                    <UserText text={a.text} clamp />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <div className="mt-6">
        <Card title="Actions des administrateurs">
          <ActionList actions={d.actions} empty="Aucune action d'administrateur sur ce compte." />
        </Card>
      </div>
    </>
  );
}

export function UserView() {
  const { id } = useParams<{ id: string }>();
  const load = useCallback(() => getUser(id), [id]);
  const { data, error, receivedAt, reload } = usePolling<UserDetail>(load, 60000);
  const now = useNow();
  const serverNow = data && receivedAt ? new Date(data.server_time).getTime() + (now - receivedAt) : now;

  return (
    <div>
      <Link href="/users" className="text-sm font-medium text-emerald-800 hover:underline">
        ← Utilisateurs
      </Link>
      <div className="mt-3">
        {error !== null && <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />}
        {!data && error === null && <p className="text-slate-500">Chargement…</p>}
        {data && <Details d={data} now={serverNow} onChanged={reload} />}
      </div>
    </div>
  );
}
