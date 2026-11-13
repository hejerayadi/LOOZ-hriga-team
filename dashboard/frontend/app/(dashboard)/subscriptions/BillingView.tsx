"use client";

// "Abonnements": every farmer's pack with the bill of one period at the
// current price, the payments (demo payments marked "démo"), the price of
// a box and "hectares par boîtier" (reason + confirmation; never with the
// demo account), and the log of their changes. ?tab=payments|price|log.
import { useCallback, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { ActionList } from "@/components/actions";
import { useAdmin } from "@/components/AdminGuard";
import { PackText } from "@/components/iot";
import { Button, Card, DemoTag, Dialog, Empty, ErrorBox, Fact, ReasonField, Tabs, reasonOk } from "@/components/ui";
import { errorMessage, getBilling, setPrice, setSetting } from "@/lib/api";
import { date, dateTime, money, num, phone } from "@/lib/format";
import { GOVERNORATES, PAYMENT_KIND, PAYMENT_STATUS, label, personName } from "@/lib/labels";
import type { BillingPage, SubscriptionRow } from "@/lib/types";
import { usePolling } from "@/lib/usePolling";

type Tab = "subscriptions" | "payments" | "price" | "log";
const TABS: Tab[] = ["subscriptions", "payments", "price", "log"];
type Show = "paid" | "expired" | "free" | "all";
const TH = "px-3 py-2 font-medium";
const HEAD = "border-y border-slate-200 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500";
const INPUT = "mt-1 w-40 rounded-lg border border-slate-300 bg-white px-3 py-2 font-normal outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100";

function kindOf(s: SubscriptionRow): Show {
  if (s.plan === "free" || !s.plan) return "free";
  return s.active ? "paid" : "expired";
}

function Subscriptions({ subs }: { subs: SubscriptionRow[] }) {
  const [show, setShow] = useState<Show>("paid");
  const shown = subs.filter((s) => show === "all" || kindOf(s) === show);
  const CHOICES: { id: Show; label: string }[] = [
    { id: "paid", label: "Payants en cours" },
    { id: "expired", label: "Payants expirés" },
    { id: "free", label: "Gratuits" },
    { id: "all", label: "Tous" },
  ];
  return (
    <>
      <div className="flex flex-wrap gap-2">
        {CHOICES.map((c) => (
          <button
            key={c.id}
            type="button"
            aria-pressed={show === c.id}
            onClick={() => setShow(c.id)}
            className={`rounded-full px-3 py-1 text-sm font-medium ${show === c.id ? "bg-emerald-700 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200"}`}
          >
            {c.label} ({c.id === "all" ? subs.length : subs.filter((s) => kindOf(s) === c.id).length})
          </button>
        ))}
      </div>
      <div className="mt-4">
        {!shown.length ? (
          <Empty>Aucun abonnement dans cette liste.</Empty>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className={HEAD}>
                <tr>
                  <th className={TH}>Agriculteur</th>
                  <th className={TH}>Pack</th>
                  <th className={TH}>Boîtiers</th>
                  <th className={TH}>Une période au prix actuel</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {shown.map((s) => (
                  <tr key={s.user_id} className="align-top">
                    <td className="px-3 py-2.5">
                      <Link href={`/farmers/${s.user_id}`} className="font-semibold text-slate-900 hover:text-emerald-800">
                        {personName(s.farmer_name, "Sans nom")}
                      </Link>
                      {s.demo && <span className="ml-1.5"><DemoTag /></span>}
                      <div className="whitespace-nowrap text-xs text-slate-500">
                        {[s.farmer_phone ? phone(s.farmer_phone) : null, label(GOVERNORATES, s.governorate)].filter(Boolean).join(" · ")}
                      </div>
                    </td>
                    <td className="px-3 py-2.5">
                      <PackText pack={{ plan: s.plan, active: s.active, ends_at: s.ends_at, nodes: null }} compact />
                      {s.started_at && s.plan !== "free" && <div className="text-xs text-slate-500">depuis le {date(s.started_at)}</div>}
                    </td>
                    <td className="whitespace-nowrap px-3 py-2.5 text-slate-700">
                      {s.nodes ?? "—"} payé{(s.nodes ?? 0) > 1 ? "s" : ""}
                      {s.bill && <div className="text-xs text-slate-500">{s.bill.billed_nodes} facturé{s.bill.billed_nodes > 1 ? "s" : ""}</div>}
                    </td>
                    <td className="whitespace-nowrap px-3 py-2.5">
                      {s.bill ? (
                        <>
                          <div className="font-semibold text-slate-900">{money(s.bill.amount_millimes)}</div>
                          <div className="text-xs text-slate-500">
                            {s.bill.billed_nodes} × {money(s.bill.price_millimes)} · {s.bill.period_days} jours
                          </div>
                        </>
                      ) : (
                        <span className="text-xs text-slate-500">{s.orchard_status === "draft" ? "verger en brouillon" : "pas de verger"}</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

function Payments({ page }: { page: BillingPage }) {
  if (!page.payments.length) return <Empty>Aucun paiement pour l&apos;instant.</Empty>;
  return (
    <>
      <p className="mb-3 text-sm text-slate-600">Paiements de démonstration : aucun argent réel (pas encore de vrai moyen de paiement).</p>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className={HEAD}>
            <tr>
              <th className={TH}>Date</th>
              <th className={TH}>Agriculteur</th>
              <th className={TH}>Montant</th>
              <th className={TH}>Détail</th>
              <th className={TH}>État</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {page.payments.map((p) => (
              <tr key={p.id} className="align-top">
                <td className="whitespace-nowrap px-3 py-2.5 text-slate-700">{dateTime(p.paid_at ?? p.created_at)}</td>
                <td className="px-3 py-2.5">
                  {p.user_id ? (
                    <Link href={`/farmers/${p.user_id}`} className="font-medium text-slate-900 hover:text-emerald-800">
                      {personName(p.farmer_name, "Sans nom")}
                    </Link>
                  ) : (
                    <span className="text-slate-500">Compte supprimé</span>
                  )}
                </td>
                <td className="whitespace-nowrap px-3 py-2.5 font-semibold tabular-nums text-slate-900">{money(p.amount_millimes)}</td>
                <td className="whitespace-nowrap px-3 py-2.5 text-xs text-slate-600">
                  {label(PAYMENT_KIND, p.kind)}
                  {p.nodes ? ` · ${p.nodes} boîtier${p.nodes > 1 ? "s" : ""}` : ""}
                  {p.period_days ? ` · ${p.period_days} jours` : ""}
                </td>
                <td className="whitespace-nowrap px-3 py-2.5">
                  <span
                    className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${p.status.startsWith("paid") ? "bg-emerald-50 text-emerald-800" : p.status.startsWith("failed") ? "bg-rose-50 text-rose-800" : "bg-slate-100 text-slate-700"}`}
                  >
                    {label(PAYMENT_STATUS, p.status)}
                  </span>
                  {p.demo && <span className="ml-1.5"><DemoTag /></span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

/** "8,5" or "8.5" -> 8500 millimes (null: not a price). */
function toMillimes(text: string): number | null {
  const v = Number(text.trim().replace(",", "."));
  if (!text.trim() || !Number.isFinite(v)) return null;
  const m = Math.round(v * 1000);
  return m >= 1000 && m <= 1_000_000 ? m : null;
}

function PriceDialog({ page, onClose, onDone }: { page: BillingPage; onClose: () => void; onDone: () => void }) {
  const current = page.price.price_millimes;
  const [typed, setTyped] = useState(num(current / 1000, 2));
  const [reason, setReason] = useState("");
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const next = toMillimes(typed);
  const paid = page.subscriptions.filter((s) => s.active && s.plan !== "free" && s.bill);
  const before = paid.reduce((sum, s) => sum + (s.bill?.amount_millimes ?? 0), 0);
  const after = next === null ? 0 : paid.reduce((sum, s) => sum + (s.bill?.billed_nodes ?? 0) * next, 0);
  async function save() {
    if (next === null) return;
    setBusy(true);
    setError(null);
    try {
      await setPrice(next, reason.trim());
      onDone();
    } catch (e) {
      setError(errorMessage(e));
      setBusy(false);
    }
  }
  return (
    <Dialog title="Changer le prix d'un boîtier" onClose={onClose} busy={busy}>
      {!confirming ? (
        <>
          <p>
            Prix actuel : <b>{money(current)}</b> par boîtier et par {page.price.period_days} jours.
          </p>
          <label className="mt-4 block font-medium text-slate-700">
            Nouveau prix (DT)
            <input inputMode="decimal" value={typed} onChange={(e) => setTyped(e.target.value)} className={`${INPUT} block`} aria-describedby="price-help" />
            <span id="price-help" className="mt-1 block text-xs font-normal text-slate-500">
              Entre 1 et 1000 DT (ex. : 8 ou 8,5).
            </span>
          </label>
          {next !== null && next !== current && (
            <p className="mt-3 rounded-lg bg-slate-50 px-3 py-2 text-slate-700">
              {paid.length} pack{paid.length > 1 ? "s" : ""} payant{paid.length > 1 ? "s" : ""} en cours : {money(before)} → <b>{money(after)}</b> par période, à leur prochain
              renouvellement.
            </p>
          )}
          <ReasonField value={reason} onChange={setReason} required placeholder="Ex. : nouveau tarif décidé par l'équipe" />
          <div className="mt-5 flex justify-end gap-2">
            <Button onClick={onClose}>Annuler</Button>
            <Button kind="primary" disabled={next === null || next === current || !reasonOk(reason)} onClick={() => setConfirming(true)}>
              Continuer
            </Button>
          </div>
        </>
      ) : (
        <>
          <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 font-medium text-amber-900">
            Le prix passe de {money(current)} à {money(next)} par boîtier et par {page.price.period_days} jours. Il s&apos;applique aux nouveaux
            paiements et aux renouvellements ; les périodes déjà payées ne changent pas.
          </p>
          <p className="mt-2 text-slate-600">Motif : « {reason.trim()} »</p>
          {error && <p className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">{error}</p>}
          <div className="mt-5 flex justify-end gap-2">
            <Button onClick={onClose} disabled={busy}>
              Annuler
            </Button>
            <Button kind="primary" disabled={busy} onClick={save}>
              {busy ? "Enregistrement…" : "Changer le prix"}
            </Button>
          </div>
        </>
      )}
    </Dialog>
  );
}

function HectaresDialog({ value, onClose, onDone }: { value: number | null; onClose: () => void; onDone: () => void }) {
  const [typed, setTyped] = useState(value === null ? "" : num(value, 2));
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const v = typed.trim().replace(",", ".");
  const ok = v === "" || (/^\d+(\.\d{1,2})?$/.test(v) && Number(v) >= 0.1 && Number(v) <= 1000);
  async function save() {
    setBusy(true);
    setError(null);
    try {
      await setSetting("hectares_per_node", v, reason.trim());
      onDone();
    } catch (e) {
      setError(errorMessage(e));
      setBusy(false);
    }
  }
  return (
    <Dialog title="Hectares par boîtier" onClose={onClose} busy={busy}>
      <p className="text-slate-600">
        Un verger paie au moins 1 boîtier par tranche de ce nombre d&apos;hectares (même s&apos;il a moins de zones). Vide : seules les zones dessinées
        comptent.
      </p>
      <label className="mt-4 block font-medium text-slate-700">
        Hectares par boîtier
        <input inputMode="decimal" value={typed} onChange={(e) => setTyped(e.target.value)} className={`${INPUT} block`} />
        <span className="mt-1 block text-xs font-normal text-slate-500">Entre 0,10 et 1000, ou vide.</span>
      </label>
      <ReasonField value={reason} onChange={setReason} required />
      {error && <p className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">{error}</p>}
      <div className="mt-5 flex justify-end gap-2">
        <Button onClick={onClose} disabled={busy}>
          Annuler
        </Button>
        <Button kind="primary" disabled={busy || !ok || !reasonOk(reason)} onClick={save}>
          {busy ? "Enregistrement…" : "Enregistrer"}
        </Button>
      </div>
    </Dialog>
  );
}

function PriceTab({ page, onChanged }: { page: BillingPage; onChanged: () => void }) {
  const admin = useAdmin();
  const [open, setOpen] = useState<"price" | "hectares" | null>(null);
  const done = () => {
    setOpen(null);
    onChanged();
  };
  return (
    <div className="grid gap-6 xl:grid-cols-2">
      <Card
        title="Prix du pack payant"
        action={
          !admin.demo_admin && (
            <Button small kind="primary" onClick={() => setOpen("price")}>
              Changer le prix
            </Button>
          )
        }
      >
        <div className="grid grid-cols-2 gap-4">
          <Fact name="Par boîtier" value={money(page.price.price_millimes)} />
          <Fact name="Période" value={`${page.price.period_days} jours`} />
        </div>
        {page.price.updated_at && <p className="mt-3 text-xs text-slate-500">Dernier changement : {dateTime(page.price.updated_at)}</p>}
      </Card>
      <Card
        title="Hectares par boîtier"
        action={
          !admin.demo_admin && (
            <Button small onClick={() => setOpen("hectares")}>
              Modifier
            </Button>
          )
        }
      >
        <Fact name="Au moins 1 boîtier facturé par" value={page.hectares_per_node === null ? "— (les zones seulement)" : `${num(page.hectares_per_node, 2)} ha`} />
        <p className="mt-3 text-xs text-slate-500">Boîtiers facturés = les zones dessinées, au moins 1 par tranche de cette surface, jamais moins de 1.</p>
      </Card>
      {admin.demo_admin && <p className="text-sm text-slate-500 xl:col-span-2">Prix et réglages : pas avec le compte de démonstration.</p>}
      {open === "price" && <PriceDialog page={page} onClose={() => setOpen(null)} onDone={done} />}
      {open === "hectares" && <HectaresDialog value={page.hectares_per_node} onClose={() => setOpen(null)} onDone={done} />}
    </div>
  );
}

export function BillingView() {
  const params = useSearchParams();
  const first = params.get("tab");
  const [tab, setTab] = useState<Tab>(TABS.includes(first as Tab) ? (first as Tab) : "subscriptions");
  const load = useCallback(() => getBilling(), []);
  const { data, error, reload } = usePolling<BillingPage>(load, 60000);
  const paid = data?.subscriptions.filter((s) => s.active && s.plan !== "free") ?? [];
  const perPeriod = paid.reduce((sum, s) => sum + (s.bill?.amount_millimes ?? 0), 0);

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Abonnements</h1>
      <p className="mt-1 text-slate-500">Les packs des agriculteurs, les paiements et le prix d&apos;un boîtier.</p>
      {error !== null && (
        <div className="mt-4">
          <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      {!data && error === null && <p className="mt-6 text-slate-500">Chargement…</p>}
      {data && (
        <>
          <div className="mt-5 grid gap-4 sm:grid-cols-3">
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-slate-500">Packs payants en cours</div>
              <div className="mt-1 text-3xl font-bold tabular-nums text-slate-900">{paid.length}</div>
            </div>
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-slate-500">Une période, au prix actuel</div>
              <div className="mt-1 text-3xl font-bold tabular-nums text-slate-900">{money(perPeriod)}</div>
              <div className="text-sm text-slate-600">pour ces packs ({data.price.period_days} jours)</div>
            </div>
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-slate-500">Prix d&apos;un boîtier</div>
              <div className="mt-1 text-3xl font-bold tabular-nums text-slate-900">{money(data.price.price_millimes)}</div>
              <div className="text-sm text-slate-600">par {data.price.period_days} jours</div>
            </div>
          </div>
          <div className="mt-5 rounded-xl border border-slate-200 bg-white p-4">
            <Tabs
              tabs={[
                { id: "subscriptions", label: "Abonnements", count: data.subscriptions.length },
                { id: "payments", label: "Paiements", count: data.payments.length },
                { id: "price", label: "Prix" },
                { id: "log", label: "Journal" },
              ]}
              current={tab}
              onChange={setTab}
            />
            <div className="mt-4">
              {tab === "subscriptions" && <Subscriptions subs={data.subscriptions} />}
              {tab === "payments" && <Payments page={data} />}
              {tab === "price" && <PriceTab page={data} onChanged={reload} />}
              {tab === "log" && <ActionList actions={data.actions} empty="Aucun changement de prix pour l'instant." />}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
