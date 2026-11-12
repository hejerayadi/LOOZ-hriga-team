"use client";

// The admin actions on sensor boxes, gateways and installation visits.
// Each one calls the backend, which calls ONE checked function of the
// database (migration 013): it checks the rules and writes the line of
// the admin action log. Texts in French.
import { useState } from "react";

import { acceptNode, errorMessage, newGatewayKey, setGatewayEnabled, unacceptNode, updateVisit } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { ACTION, VISIT, label } from "@/lib/labels";
import type { ActionLine } from "@/lib/types";
import { useAdmin } from "./AdminGuard";
import { Button, DemoTag, Dialog, Empty, ReasonField, reasonOk } from "./ui";

/** busy / error around one call; onDone() after a success. */
function useCall(onDone: () => void) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function run(call: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await call();
      onDone();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return { busy, error, run };
}

function Footer({ busy, onClose, children }: { busy: boolean; onClose: () => void; children: React.ReactNode }) {
  return (
    <div className="mt-5 flex justify-end gap-2">
      <Button onClick={onClose} disabled={busy}>
        Annuler
      </Button>
      {children}
    </div>
  );
}

function DialogError({ error }: { error: string | null }) {
  return error ? <p className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">{error}</p> : null;
}

export type BoxTarget = {
  node_id: string;
  device_code: string | null;
  zone_letter: string | null;
  farmer_name?: string;
};

function boxName(b: BoxTarget): string {
  const zone = b.zone_letter ? `zone ${b.zone_letter}` : "";
  return [b.device_code ?? "boîtier sans code", zone, b.farmer_name].filter(Boolean).join(" · ");
}

// ---------- Boxes ----------

/** "Accepter l'installation": the box may send its data. */
export function AcceptDialog({ box, onClose, onDone }: { box: BoxTarget; onClose: () => void; onDone: () => void }) {
  const [code, setCode] = useState(box.device_code ?? "");
  const [reason, setReason] = useState("");
  const { busy, error, run } = useCall(onDone);
  const codeOk = /^[A-Z0-9][A-Z0-9_-]{1,39}$/.test(code.trim());
  const ok = codeOk && (!reason.trim() || reasonOk(reason));

  return (
    <Dialog title="Accepter l'installation" onClose={onClose} busy={busy}>
      <p>
        Boîtier : <b>{boxName(box)}</b>
      </p>
      <p className="mt-2 text-slate-600">
        Après l&apos;acceptation, ses données sont enregistrées. Quand tous les boîtiers du verger sont acceptés, la visite
        d&apos;installation passe à « installation faite ».
      </p>
      <label className="mt-4 block font-medium text-slate-700">
        Code imprimé sur le boîtier <span className="text-rose-700">(obligatoire)</span>
        <input
          value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          maxLength={40}
          placeholder="NODE-05"
          className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
        />
        {code && !codeOk && <span className="text-xs font-normal text-rose-700">2 à 40 caractères : A-Z, 0-9, - ou _</span>}
      </label>
      <ReasonField value={reason} onChange={setReason} required={false} />
      <DialogError error={error} />
      <Footer busy={busy} onClose={onClose}>
        <Button kind="primary" disabled={!ok || busy} onClick={() => run(() => acceptNode(box.node_id, code.trim(), reason.trim()))}>
          {busy ? "Acceptation…" : "Accepter"}
        </Button>
      </Footer>
    </Dialog>
  );
}

/** "Retirer l'acceptation": the readings of the box are refused again. */
export function UnacceptDialog({ box, onClose, onDone }: { box: BoxTarget; onClose: () => void; onDone: () => void }) {
  const [reason, setReason] = useState("");
  const { busy, error, run } = useCall(onDone);
  return (
    <Dialog title="Retirer l'acceptation" onClose={onClose} busy={busy}>
      <p>
        Boîtier : <b>{boxName(box)}</b>
      </p>
      <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-amber-900">
        Ses données seront <b>refusées</b> jusqu&apos;à une nouvelle acceptation. Les données déjà reçues restent.
      </p>
      <ReasonField value={reason} onChange={setReason} required placeholder="Ex. : boîtier déplacé, test du jury" />
      <DialogError error={error} />
      <Footer busy={busy} onClose={onClose}>
        <Button kind="danger" disabled={!reasonOk(reason) || busy} onClick={() => run(() => unacceptNode(box.node_id, reason.trim()))}>
          {busy ? "Retrait…" : "Retirer"}
        </Button>
      </Footer>
    </Dialog>
  );
}

/** The button of a box: "Accepter l'installation" or "Retirer". */
export function BoxActionButton({ box, waiting, onChanged }: { box: BoxTarget; waiting: boolean; onChanged: () => void }) {
  const [open, setOpen] = useState(false);
  const done = () => {
    setOpen(false);
    onChanged();
  };
  return (
    <>
      {waiting ? (
        <Button kind="primary" small onClick={() => setOpen(true)}>
          Accepter l&apos;installation
        </Button>
      ) : (
        <Button small onClick={() => setOpen(true)}>
          Retirer
        </Button>
      )}
      {open &&
        (waiting ? (
          <AcceptDialog box={box} onClose={() => setOpen(false)} onDone={done} />
        ) : (
          <UnacceptDialog box={box} onClose={() => setOpen(false)} onDone={done} />
        ))}
    </>
  );
}

// ---------- Gateways ----------

/** "Nouvelle clé": confirm, then the key is shown ONCE (never kept). */
export function NewKeyDialog({ code, onClose, onDone }: { code: string; onClose: () => void; onDone: () => void }) {
  const [key, setKey] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const { busy, error, run } = useCall(() => {});

  async function make() {
    await run(async () => setKey((await newGatewayKey(code)).key));
  }
  async function copy() {
    if (!key) return;
    try {
      await navigator.clipboard.writeText(key);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }
  function close() {
    const made = key !== null;
    setKey(null); // the key leaves the page
    if (made) onDone();
    onClose();
  }

  return (
    <Dialog title={`Nouvelle clé pour ${code}`} onClose={close} busy={busy} wide={key !== null}>
      {key === null ? (
        <>
          <p className="rounded-lg bg-amber-50 px-3 py-2 text-amber-900">
            L&apos;ancienne clé <b>arrête de marcher tout de suite</b> : la passerelle est refusée jusqu&apos;à ce que la
            nouvelle clé soit collée dans son fichier <span className="font-mono">iot/node-red/.env</span> (ligne{" "}
            <span className="font-mono">LOOZ_GATEWAY_KEY=</span>) et que Node-RED soit relancé.
          </p>
          <p className="mt-2 text-slate-600">La clé sera affichée une seule fois. Elle n&apos;est jamais enregistrée en clair.</p>
          <DialogError error={error} />
          <Footer busy={busy} onClose={close}>
            <Button kind="danger" disabled={busy} onClick={make}>
              {busy ? "Création…" : "Créer une nouvelle clé"}
            </Button>
          </Footer>
        </>
      ) : (
        <>
          <p>Copiez cette clé maintenant : elle ne sera plus jamais affichée.</p>
          <div className="mt-3 break-all rounded-lg border border-slate-300 bg-slate-50 px-3 py-2 font-mono text-sm text-slate-900">{key}</div>
          <ol className="mt-3 list-decimal space-y-1 pl-5 text-slate-600">
            <li>
              Collez-la dans <span className="font-mono">iot/node-red/.env</span> après{" "}
              <span className="font-mono">LOOZ_GATEWAY_KEY=</span> (remplacez l&apos;ancienne).
            </li>
            <li>Relancez Node-RED.</li>
          </ol>
          <div className="mt-5 flex justify-end gap-2">
            <Button onClick={copy} data-autofocus>
              {copied ? "Copiée ✓" : "Copier"}
            </Button>
            <Button kind="primary" onClick={close}>
              J&apos;ai copié la clé
            </Button>
          </div>
        </>
      )}
    </Dialog>
  );
}

/** Turn a gateway on or off (reason required). */
export function GatewayToggleDialog({
  code,
  enabled,
  onClose,
  onDone,
}: {
  code: string;
  enabled: boolean;
  onClose: () => void;
  onDone: () => void;
}) {
  const [reason, setReason] = useState("");
  const { busy, error, run } = useCall(onDone);
  return (
    <Dialog title={enabled ? `Désactiver ${code}` : `Activer ${code}`} onClose={onClose} busy={busy}>
      <p className={enabled ? "rounded-lg bg-amber-50 px-3 py-2 text-amber-900" : ""}>
        {enabled
          ? "Toutes les données envoyées par cette passerelle seront refusées jusqu'à sa réactivation."
          : "La passerelle pourra de nouveau envoyer les données de ses boîtiers."}
      </p>
      <ReasonField value={reason} onChange={setReason} required />
      <DialogError error={error} />
      <Footer busy={busy} onClose={onClose}>
        <Button
          kind={enabled ? "danger" : "primary"}
          disabled={!reasonOk(reason) || busy}
          onClick={() => run(() => setGatewayEnabled(code, !enabled, reason.trim()))}
        >
          {enabled ? "Désactiver" : "Activer"}
        </Button>
      </Footer>
    </Dialog>
  );
}

/** The buttons of a gateway (not with the demo admin account). */
export function GatewayButtons({ code, enabled, onChanged }: { code: string; enabled: boolean; onChanged: () => void }) {
  const admin = useAdmin();
  const [open, setOpen] = useState<"key" | "toggle" | null>(null);
  if (admin.demo_admin) {
    return <p className="text-xs text-slate-500">Clé et activation : pas avec le compte de démonstration.</p>;
  }
  const done = () => {
    setOpen(null);
    onChanged();
  };
  return (
    <div className="flex flex-wrap gap-2">
      <Button small onClick={() => setOpen("key")}>
        Nouvelle clé
      </Button>
      <Button small onClick={() => setOpen("toggle")}>
        {enabled ? "Désactiver" : "Activer"}
      </Button>
      {open === "key" && <NewKeyDialog code={code} onClose={() => setOpen(null)} onDone={onChanged} />}
      {open === "toggle" && <GatewayToggleDialog code={code} enabled={enabled} onClose={() => setOpen(null)} onDone={done} />}
    </div>
  );
}

// ---------- Installation visits ----------

export type VisitTarget = { id: string; status: string; admin_note: string | null; farmer_name: string };

const VISIT_CHOICES = ["new", "contacted", "cancelled"] as const;

/** Status (à planifier / contacté / annulée) and note of a visit. */
export function VisitDialog({ visit, onClose, onDone }: { visit: VisitTarget; onClose: () => void; onDone: () => void }) {
  const closed = visit.status === "installed" || visit.status === "cancelled";
  const [status, setStatus] = useState(visit.status);
  const [note, setNote] = useState(visit.admin_note ?? "");
  const { busy, error, run } = useCall(onDone);
  const noteChanged = note.trim() !== (visit.admin_note ?? "").trim();
  const statusChanged = status !== visit.status;

  return (
    <Dialog title="Visite d'installation" onClose={onClose} busy={busy}>
      <p>
        Agriculteur : <b>{visit.farmer_name || "Sans nom"}</b> · état actuel : <b>{label(VISIT, visit.status)}</b>
      </p>
      {closed ? (
        <p className="mt-2 text-slate-600">Cette visite est terminée : seule la note peut changer.</p>
      ) : (
        <label className="mt-4 block font-medium text-slate-700">
          État
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 font-normal outline-none focus:border-emerald-600"
          >
            {VISIT_CHOICES.map((s) => (
              <option key={s} value={s}>
                {label(VISIT, s)}
              </option>
            ))}
          </select>
          <span className="mt-1 block text-xs font-normal text-slate-500">
            « Installation faite » vient tout seul quand tous les boîtiers du verger sont acceptés.
          </span>
        </label>
      )}
      <label className="mt-4 block font-medium text-slate-700">
        Note interne <span className="font-normal text-slate-500">(facultatif, 500 caractères au plus)</span>
        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          maxLength={500}
          rows={3}
          className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-normal outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
        />
      </label>
      <DialogError error={error} />
      <Footer busy={busy} onClose={onClose}>
        <Button
          kind="primary"
          disabled={busy || (!noteChanged && !statusChanged)}
          onClick={() => run(() => updateVisit(visit.id, statusChanged ? status : null, noteChanged ? note.trim() : null))}
        >
          Enregistrer
        </Button>
      </Footer>
    </Dialog>
  );
}

// ---------- The admin action log ----------

/** Who did what, when, on what, why (newest first). */
export function ActionList({ actions, empty = "Aucune action d'administrateur pour l'instant." }: { actions: ActionLine[]; empty?: string }) {
  if (!actions.length) return <Empty>{empty}</Empty>;
  return (
    <ul className="divide-y divide-slate-100 text-sm">
      {actions.map((a) => (
        <li key={a.id} className="flex flex-wrap items-baseline gap-x-3 gap-y-0.5 py-2">
          <span className="w-32 shrink-0 text-xs text-slate-500">{dateTime(a.created_at)}</span>
          <span className="font-medium text-slate-900">{label(ACTION, a.action)}</span>
          {a.target_label && <span className="font-mono text-xs text-slate-600">{a.target_label}</span>}
          <span className="text-slate-500">par {a.admin_name}</span>
          {a.is_demo && <DemoTag />}
          {a.reason && <span className="basis-full pl-0 text-slate-600 sm:pl-35">Motif : « {a.reason} »</span>}
        </li>
      ))}
    </ul>
  );
}
