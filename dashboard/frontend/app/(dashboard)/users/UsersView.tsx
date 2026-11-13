"use client";

// "Utilisateurs": every account (farmers, experts, admins), with a search
// and filters, the expert badge and blocking. ?state=to_verify opens the
// experts waiting for their badge (link of "Vue d'ensemble").
import { useCallback, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { useAdmin } from "@/components/AdminGuard";
import { PackText } from "@/components/iot";
import { FakeTag, RoleBadge, UserButtons, VerifiedBadge } from "@/components/people";
import { DemoTag, Empty, ErrorBox } from "@/components/ui";
import { errorMessage, getUsers } from "@/lib/api";
import { date, phone, timeAgo } from "@/lib/format";
import { GOVERNORATES, label, personName } from "@/lib/labels";
import type { UserRow, UsersPage } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";

type Role = "all" | "farmer" | "expert" | "admin";
type PackFilter = "all" | "free" | "paid" | "expired";
type State = "all" | "to_verify" | "verified" | "blocked" | "demo";

const STATES: { id: State; label: string }[] = [
  { id: "all", label: "Tous les états" },
  { id: "to_verify", label: "Experts à vérifier" },
  { id: "verified", label: "Experts vérifiés" },
  { id: "blocked", label: "Comptes bloqués" },
  { id: "demo", label: "Comptes de démonstration" },
];

const TH = "px-3 py-2 font-medium";
const HEAD = "border-y border-slate-200 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500";
const SELECT = "rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100";

function matches(u: UserRow, q: string): boolean {
  if (!q) return true;
  const digits = q.replace(/\D/g, "");
  return (
    u.name.toLowerCase().includes(q) ||
    (u.email ?? "").toLowerCase().includes(q) ||
    (digits.length >= 3 && (u.phone ?? "").includes(digits))
  );
}

function packOf(u: UserRow): PackFilter {
  if (u.role !== "farmer" || u.pack.plan === "free" || !u.pack.plan) return "free";
  return u.pack.active ? "paid" : "expired";
}

function stateOk(u: UserRow, s: State): boolean {
  switch (s) {
    case "to_verify":
      return u.role === "expert" && !u.verified;
    case "verified":
      return u.role === "expert" && u.verified;
    case "blocked":
      return u.blocked && !u.fake;
    case "demo":
      return u.demo;
    default:
      return true;
  }
}

function Row({ u, now, onChanged }: { u: UserRow; now: number; onChanged: () => void }) {
  return (
    <tr className="align-top">
      <td className="px-3 py-2.5">
        <div className="flex flex-wrap items-center gap-1.5">
          <Link href={`/users/${u.id}`} className="font-semibold text-slate-900 hover:text-emerald-800">
            {personName(u.name, "Sans nom")}
          </Link>
          {u.fake ? <FakeTag /> : u.demo && <DemoTag />}
        </div>
        <div className="whitespace-nowrap text-xs text-slate-500">
          {[u.phone ? phone(u.phone) : null, u.email, u.governorate ? label(GOVERNORATES, u.governorate) : null].filter(Boolean).join(" · ") || "—"}
        </div>
      </td>
      <td className="px-3 py-2.5">
        <div className="flex flex-wrap items-center gap-1.5">
          <RoleBadge role={u.role} />
          {u.role === "expert" && u.verified && <VerifiedBadge />}
        </div>
        <div className="mt-1 text-xs">
          {u.role === "farmer" ? (
            <PackText pack={u.pack} compact />
          ) : u.role === "expert" ? (
            <span className="text-slate-500">{u.organisation || u.speciality || "—"}</span>
          ) : null}
        </div>
      </td>
      <td className="whitespace-nowrap px-3 py-2.5 text-xs text-slate-600">
        <div>Inscrit le {date(u.created_at)}</div>
        <div>{u.fake ? "ne se connecte pas" : u.last_sign_in_at ? `connecté ${timeAgo(u.last_sign_in_at, now)}` : "jamais connecté"}</div>
        {(u.posts > 0 || u.answers > 0) && (
          <div>
            {u.posts} publication{u.posts > 1 ? "s" : ""} · {u.answers} réponse{u.answers > 1 ? "s" : ""}
          </div>
        )}
      </td>
      <td className="px-3 py-2.5">
        {u.fake ? (
          <span className="rounded-full bg-violet-50 px-2.5 py-0.5 text-xs font-medium text-violet-800">Profil fictif</span>
        ) : u.blocked ? (
          <span className="rounded-full bg-rose-50 px-2.5 py-0.5 text-xs font-medium text-rose-800">Bloqué</span>
        ) : u.role === "expert" && !u.verified ? (
          <span className="rounded-full bg-sky-50 px-2.5 py-0.5 text-xs font-medium text-sky-800">À vérifier</span>
        ) : (
          <span className="rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-medium text-emerald-800">Actif</span>
        )}
        <div className="mt-2">
          <UserButtons user={u} onChanged={onChanged} />
        </div>
      </td>
    </tr>
  );
}

export function UsersView() {
  const admin = useAdmin();
  const params = useSearchParams();
  const firstState = params.get("state");
  const [typed, setTyped] = useState("");
  const [role, setRole] = useState<Role>(firstState === "to_verify" ? "expert" : "all");
  const [governorate, setGovernorate] = useState("all");
  const [pack, setPack] = useState<PackFilter>("all");
  const [state, setState] = useState<State>(STATES.some((s) => s.id === firstState) ? (firstState as State) : "all");
  const load = useCallback(() => getUsers(), []);
  const { data, error, receivedAt, reload } = usePolling<UsersPage>(load, 60000);
  const now = useNow();
  const serverNow = data && receivedAt ? new Date(data.server_time).getTime() + (now - receivedAt) : now;

  const q = typed.trim().toLowerCase();
  const users = (data?.users ?? []).filter(
    (u) =>
      matches(u, q) &&
      (role === "all" || u.role === role) &&
      (governorate === "all" || u.governorate === governorate) &&
      (pack === "all" || (u.role === "farmer" && packOf(u) === pack)) &&
      stateOk(u, state),
  );
  const all = data?.users ?? [];
  const waiting = all.filter((u) => u.role === "expert" && !u.verified).length;

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Utilisateurs</h1>
      <p className="mt-1 text-slate-500">
        Agriculteurs, experts et administrateurs. Le rôle d&apos;un compte se change seulement dans Supabase (SQL).
      </p>
      {error !== null && (
        <div className="mt-4">
          <ErrorBox message={(data ? "Liste non mise à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      {!data && error === null && <p className="mt-6 text-slate-500">Chargement…</p>}
      {data && (
        <div className="mt-5 rounded-xl border border-slate-200 bg-white p-4">
          <div className="flex flex-wrap gap-2 text-sm">
            <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">{all.length} comptes</span>
            <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">{all.filter((u) => u.role === "farmer").length} agriculteurs</span>
            <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">{all.filter((u) => u.role === "expert").length} experts</span>
            {waiting > 0 && (
              <button
                type="button"
                onClick={() => {
                  setRole("expert");
                  setState("to_verify");
                }}
                className="rounded-full bg-sky-50 px-3 py-1 font-medium text-sky-800 hover:bg-sky-100"
              >
                {waiting} expert{waiting > 1 ? "s" : ""} à vérifier
              </button>
            )}
          </div>
          <div className="mt-4 flex flex-wrap gap-2">
            <input
              type="search"
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              placeholder="Nom, téléphone ou e-mail"
              aria-label="Rechercher un nom, un téléphone ou un e-mail"
              className={`${SELECT} w-full max-w-xs`}
            />
            <select aria-label="Rôle" value={role} onChange={(e) => setRole(e.target.value as Role)} className={SELECT}>
              <option value="all">Tous les rôles</option>
              <option value="farmer">Agriculteurs</option>
              <option value="expert">Experts</option>
              <option value="admin">Administrateurs</option>
            </select>
            <select aria-label="Gouvernorat" value={governorate} onChange={(e) => setGovernorate(e.target.value)} className={SELECT}>
              <option value="all">Tous les gouvernorats</option>
              {Object.entries(GOVERNORATES).map(([code, name]) => (
                <option key={code} value={code}>
                  {name}
                </option>
              ))}
            </select>
            <select aria-label="Pack" value={pack} onChange={(e) => setPack(e.target.value as PackFilter)} className={SELECT}>
              <option value="all">Tous les packs</option>
              <option value="free">Gratuit</option>
              <option value="paid">Payant en cours</option>
              <option value="expired">Payant expiré</option>
            </select>
            <select aria-label="État" value={state} onChange={(e) => setState(e.target.value as State)} className={SELECT}>
              {STATES.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.label}
                </option>
              ))}
            </select>
          </div>
          {admin.demo_admin && (
            <p className="mt-3 text-xs text-slate-500">Bloquer un compte : pas avec le compte de démonstration.</p>
          )}
          <p className="mt-3 text-xs text-slate-500">
            {users.length === all.length ? `${all.length} comptes` : `${users.length} compte${users.length > 1 ? "s" : ""} sur ${all.length}`}
          </p>
          <div className="mt-2">
            {!users.length ? (
              <Empty>Aucun compte ne correspond à ces filtres.</Empty>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className={HEAD}>
                    <tr>
                      <th className={TH}>Utilisateur</th>
                      <th className={TH}>Rôle et pack</th>
                      <th className={TH}>Activité</th>
                      <th className={TH}>État</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {users.map((u) => (
                      <Row key={u.id} u={u} now={serverNow} onChanged={reload} />
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
