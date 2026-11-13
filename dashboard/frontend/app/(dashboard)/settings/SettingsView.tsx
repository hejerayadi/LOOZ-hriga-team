"use client";

// "Réglages": the switches of LOOZ (app_settings), each with what it does,
// a clear warning and a confirmation (reason required). Never with the demo
// account. Every change is in the log at the bottom.
import { useCallback, useState } from "react";
import Link from "next/link";

import { ActionList } from "@/components/actions";
import { useAdmin } from "@/components/AdminGuard";
import { Button, Card, Dialog, ErrorBox, ReasonField, reasonOk } from "@/components/ui";
import { errorMessage, getSettings, setSetting, type SettingName } from "@/lib/api";
import { dateTime, num } from "@/lib/format";
import { SETTING } from "@/lib/labels";
import type { Settings, SettingsPage } from "@/lib/types";
import { usePolling } from "@/lib/usePolling";

type Switch = {
  name: Exclude<SettingName, "hectares_per_node" | "iot_history_days">;
  what: string;
  onText: string;
  offText: string;
  /** Turning it ON is the dangerous way (red). */
  dangerOn?: boolean;
  /** Turning it OFF needs this box ticked first. */
  offCheck?: string;
};

const SWITCHES: Switch[] = [
  {
    name: "demo_login_enabled",
    what: "Dans l'application, n'importe quel numéro et n'importe quel code permettent de se connecter (aucun SMS n'est envoyé). Pour la démonstration seulement.",
    onText: "Danger : n'importe qui pourra entrer dans n'importe quel compte avec son seul numéro. À n'utiliser que pour une démonstration.",
    offText:
      "À faire SEULEMENT après avoir branché un vrai fournisseur de SMS. Sinon, plus personne ne pourra se connecter à l'application (les codes ne seront pas envoyés).",
    dangerOn: true,
    offCheck: "Un vrai fournisseur de SMS est branché et testé.",
  },
  {
    name: "demo_payments_enabled",
    what: "Les agriculteurs obtiennent leur pack payant avec un paiement de démonstration (aucun argent réel). Il n'y a pas encore de vrai moyen de paiement.",
    onText: "Les packs s'obtiennent de nouveau sans argent réel (paiements marqués « démo »).",
    offText: "Plus personne ne pourra acheter ou renouveler un pack tant qu'un vrai moyen de paiement n'est pas branché.",
  },
  {
    name: "iot_ingest_enabled",
    what: "Les passerelles (Node-RED) envoient les mesures des boîtiers acceptés à Supabase.",
    onText: "Les mesures des boîtiers acceptés sont de nouveau enregistrées.",
    offText: "Toutes les mesures envoyées par les passerelles seront refusées (rien n'est enregistré) jusqu'à la réactivation.",
  },
  {
    name: "demo_admin_login_enabled",
    what: "Le bouton « Connexion démo » de la page de connexion du tableau de bord : un compte qui voit et touche seulement les données de démonstration, sur cet ordinateur seulement (127.0.0.1).",
    onText: "Le bouton « Connexion démo » apparaît sur la page de connexion (sur cet ordinateur seulement).",
    offText: "Le bouton « Connexion démo » disparaît. À faire après la présentation au jury.",
  },
];

function SwitchDialog({ s, on, onClose, onDone }: { s: Switch; on: boolean; onClose: () => void; onDone: () => void }) {
  const turnOn = !on;
  const [reason, setReason] = useState("");
  const [checked, setChecked] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const danger = turnOn ? !!s.dangerOn : !s.dangerOn;
  const needCheck = !turnOn && !!s.offCheck;
  async function save() {
    setBusy(true);
    setError(null);
    try {
      await setSetting(s.name, turnOn ? "true" : "false", reason.trim());
      onDone();
    } catch (e) {
      setError(errorMessage(e));
      setBusy(false);
    }
  }
  return (
    <Dialog title={`${turnOn ? "Activer" : "Désactiver"} : ${SETTING[s.name]}`} onClose={onClose} busy={busy}>
      <p role="alert" className={`rounded-lg px-3 py-2 font-medium ${danger ? "bg-rose-50 text-rose-800" : "bg-amber-50 text-amber-900"}`}>
        {turnOn ? s.onText : s.offText}
      </p>
      {needCheck && (
        <label className="mt-3 flex items-start gap-2 text-slate-700">
          <input type="checkbox" checked={checked} onChange={(e) => setChecked(e.target.checked)} className="mt-0.5 h-4 w-4 accent-emerald-700" />
          {s.offCheck}
        </label>
      )}
      <ReasonField value={reason} onChange={setReason} required />
      {error && <p className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">{error}</p>}
      <div className="mt-5 flex justify-end gap-2">
        <Button onClick={onClose} disabled={busy}>
          Annuler
        </Button>
        <Button kind={danger ? "danger" : "primary"} disabled={busy || !reasonOk(reason) || (needCheck && !checked)} onClick={save}>
          {busy ? "Enregistrement…" : turnOn ? "Activer" : "Désactiver"}
        </Button>
      </div>
    </Dialog>
  );
}

function HistoryDialog({ days, onClose, onDone }: { days: number; onClose: () => void; onDone: () => void }) {
  const [typed, setTyped] = useState(String(days));
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const n = Number(typed.trim());
  const ok = /^\d{1,4}$/.test(typed.trim()) && n >= 1 && n <= 3650 && n !== days;
  async function save() {
    setBusy(true);
    setError(null);
    try {
      await setSetting("iot_history_days", String(n), reason.trim());
      onDone();
    } catch (e) {
      setError(errorMessage(e));
      setBusy(false);
    }
  }
  return (
    <Dialog title={SETTING.iot_history_days} onClose={onClose} busy={busy}>
      <p className="text-slate-600">Pour chaque boîtier, les mesures des graphiques, le journal des alertes des capteurs et les problèmes de capteurs plus anciens que ce nombre de jours sont effacés (à chaque envoi du boîtier). La dernière mesure reste.</p>
      {n < days && ok && (
        <p role="alert" className="mt-3 rounded-lg bg-amber-50 px-3 py-2 font-medium text-amber-900">
          Plus court : tout ce qui a plus de {n} jours sera effacé au prochain envoi de chaque boîtier.
        </p>
      )}
      <label className="mt-4 block font-medium text-slate-700">
        Nombre de jours
        <input inputMode="numeric" value={typed} onChange={(e) => setTyped(e.target.value)} className="mt-1 block w-32 rounded-lg border border-slate-300 px-3 py-2 font-normal outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100" />
        <span className="mt-1 block text-xs font-normal text-slate-500">Entre 1 et 3650.</span>
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

function StatePill({ on }: { on: boolean }) {
  return on ? (
    <span className="rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-semibold text-emerald-800">Activé</span>
  ) : (
    <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-semibold text-slate-600">Désactivé</span>
  );
}

function Switches({ settings, onChanged }: { settings: Settings; onChanged: () => void }) {
  const admin = useAdmin();
  const [open, setOpen] = useState<Switch | "history" | null>(null);
  const done = () => {
    setOpen(null);
    onChanged();
  };
  return (
    <div className="grid gap-4 xl:grid-cols-2">
      {SWITCHES.map((s) => {
        const on = settings[s.name];
        const risky = s.dangerOn ? on : !on;
        return (
          <section key={s.name} className={`rounded-xl border bg-white p-5 ${risky && s.dangerOn ? "border-rose-200" : "border-slate-200"}`}>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="font-semibold text-slate-900">{SETTING[s.name]}</h2>
              <StatePill on={on} />
              {!admin.demo_admin && (
                <span className="ml-auto">
                  <Button small kind={on ? "plain" : "primary"} onClick={() => setOpen(s)}>
                    {on ? "Désactiver" : "Activer"}
                  </Button>
                </span>
              )}
            </div>
            <p className="mt-2 text-sm text-slate-600">{s.what}</p>
            {s.name === "demo_login_enabled" && on && (
              <p className="mt-2 text-sm font-medium text-rose-700">À éteindre avant un vrai lancement, une fois les vrais SMS branchés.</p>
            )}
          </section>
        );
      })}
      <section className="rounded-xl border border-slate-200 bg-white p-5">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="font-semibold text-slate-900">{SETTING.iot_history_days}</h2>
          <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-semibold text-slate-700">{settings.iot_history_days} jours</span>
          {!admin.demo_admin && (
            <span className="ml-auto">
              <Button small onClick={() => setOpen("history")}>
                Modifier
              </Button>
            </span>
          )}
        </div>
        <p className="mt-2 text-sm text-slate-600">Les mesures, alertes et problèmes des capteurs sont gardés ce nombre de jours (le stockage gratuit de Supabase est limité).</p>
      </section>
      <section className="rounded-xl border border-slate-200 bg-white p-5">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="font-semibold text-slate-900">{SETTING.hectares_per_node}</h2>
          <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-semibold text-slate-700">
            {settings.hectares_per_node === null ? "les zones seulement" : `${num(settings.hectares_per_node, 2)} ha`}
          </span>
          <Link href="/subscriptions?tab=price" className="ml-auto text-sm font-medium text-emerald-800 hover:underline">
            Abonnements › Prix →
          </Link>
        </div>
        <p className="mt-2 text-sm text-slate-600">Un verger paie au moins 1 boîtier par tranche de cette surface. Se modifie avec le prix.</p>
      </section>
      {admin.demo_admin && <p className="text-sm text-slate-500 xl:col-span-2">Réglages : lecture seule avec le compte de démonstration.</p>}
      {open && open !== "history" && <SwitchDialog s={open} on={settings[open.name]} onClose={() => setOpen(null)} onDone={done} />}
      {open === "history" && <HistoryDialog days={settings.iot_history_days} onClose={() => setOpen(null)} onDone={done} />}
    </div>
  );
}

export function SettingsView() {
  const load = useCallback(() => getSettings(), []);
  const { data, error, reload } = usePolling<SettingsPage>(load, 60000);
  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Réglages</h1>
      <p className="mt-1 text-slate-500">
        Les interrupteurs de LOOZ. Chaque changement demande un motif et une confirmation, et s&apos;inscrit dans le journal.
        {data?.settings.updated_at ? ` Dernier changement : ${dateTime(data.settings.updated_at)}.` : ""}
      </p>
      {error !== null && (
        <div className="mt-4">
          <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />
        </div>
      )}
      {!data && error === null && <p className="mt-6 text-slate-500">Chargement…</p>}
      {data && (
        <div className="mt-5 space-y-6">
          <Switches settings={data.settings} onChanged={reload} />
          <Card title="Journal des réglages">
            <ActionList actions={data.actions} empty="Aucun changement de réglage pour l'instant." />
          </Card>
        </div>
      )}
    </div>
  );
}
