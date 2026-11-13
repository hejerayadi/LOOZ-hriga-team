"use client";

// Accounts and community posts: the badges, the author line, and the admin
// actions (expert badge, block, hide / show again / delete, dismiss a
// report). Each action calls the backend, which calls ONE checked function
// of the database (migration 013): it checks the rules and writes the line
// of the admin action log. Texts in French.
import { useState } from "react";
import Link from "next/link";

import { dismissReport, errorMessage, moderate, setExpertVerified, setUserBlocked, type Moderation } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { GOVERNORATES, POST_TYPE, ROLE, label, personName } from "@/lib/labels";
import type { Author } from "@/lib/types";
import { useAdmin } from "./AdminGuard";
import { Button, DemoTag, Dialog, ReasonField, reasonOk } from "./ui";

/** busy / error around one call; onDone() after a success. */
function useCall<T>(onDone: (result: T) => void) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function run(call: () => Promise<T>) {
    setBusy(true);
    setError(null);
    try {
      onDone(await call());
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
    <div className="mt-5 flex flex-wrap justify-end gap-2">
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

// ---------- Badges ----------

/** "◆ Expert vérifié" (the app shows the same badge in Arabic or French). */
export function VerifiedBadge() {
  return (
    <span className="whitespace-nowrap rounded bg-emerald-50 px-1.5 py-0.5 text-[11px] font-semibold text-emerald-800 ring-1 ring-emerald-200">
      ◆ Expert vérifié
    </span>
  );
}

export function RoleBadge({ role }: { role: string | null }) {
  const tone = role === "admin" ? "bg-slate-800 text-white" : role === "expert" ? "bg-sky-50 text-sky-800" : "bg-slate-100 text-slate-700";
  return <span className={`whitespace-nowrap rounded px-1.5 py-0.5 text-[11px] font-medium ${tone}`}>{label(ROLE, role)}</span>;
}

/** A fake person of the community (seed): cannot log in. */
export function FakeTag() {
  return (
    <span
      className="whitespace-nowrap rounded bg-violet-50 px-1.5 py-0.5 text-[11px] font-medium text-violet-800 ring-1 ring-violet-200"
      title="Personne fictive de la communauté (données de démonstration) : ne peut pas se connecter."
    >
      fictif
    </span>
  );
}

export function HiddenTag({ text = "masquée" }: { text?: string }) {
  return <span className="whitespace-nowrap rounded bg-amber-100 px-1.5 py-0.5 text-[11px] font-semibold text-amber-900">{text}</span>;
}

export function TypeTag({ type }: { type: string }) {
  return (
    <span className={`whitespace-nowrap rounded px-1.5 py-0.5 text-[11px] font-medium ${type === "tip" ? "bg-lime-50 text-lime-800" : "bg-blue-50 text-blue-800"}`}>
      {label(POST_TYPE, type)}
    </span>
  );
}

/** Name (link to the account), role, badge, governorate, demo tags. */
export function AuthorLine({ author, when, link = true }: { author: Author; when?: string; link?: boolean }) {
  const name = personName(author.name, "Sans nom");
  return (
    <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
      {author.id && link ? (
        <Link href={`/users/${author.id}`} className="font-semibold text-slate-900 hover:text-emerald-800">
          {name}
        </Link>
      ) : (
        <span className="font-semibold text-slate-900">{name}</span>
      )}
      <RoleBadge role={author.role} />
      {author.verified && author.role === "expert" && <VerifiedBadge />}
      {author.governorate && <span className="text-xs text-slate-500">{label(GOVERNORATES, author.governorate)}</span>}
      {author.fake ? <FakeTag /> : author.demo && <DemoTag />}
      {when && <span className="text-xs text-slate-500">· {dateTime(when)}</span>}
    </div>
  );
}

/** A text written by a user (Arabic or French): its own direction, line breaks kept. */
export function UserText({ text, clamp = false }: { text: string; clamp?: boolean }) {
  return (
    <p dir="auto" className={`whitespace-pre-wrap text-start text-slate-800 ${clamp ? "line-clamp-3" : ""}`}>
      {text}
    </p>
  );
}

// ---------- Accounts ----------

export type UserTarget = { id: string; name: string; role: string; verified: boolean; blocked: boolean };

/** "Vérifier" (reason optional) / "Retirer la vérification" (reason required). */
export function VerifyDialog({ user, onClose, onDone }: { user: UserTarget; onClose: () => void; onDone: () => void }) {
  const verify = !user.verified;
  const [reason, setReason] = useState("");
  const { busy, error, run } = useCall(onDone);
  const ok = verify ? !reason.trim() || reasonOk(reason) : reasonOk(reason);
  return (
    <Dialog title={verify ? "Vérifier l'expert" : "Retirer la vérification"} onClose={onClose} busy={busy}>
      <p>
        Expert : <b>{personName(user.name, "Sans nom")}</b>
      </p>
      <p className="mt-2 text-slate-600">
        {verify
          ? "Le badge d'expert vérifié (◆) apparaît aussitôt dans l'application, à côté de son nom et de ses réponses."
          : "Le badge d'expert vérifié (◆) disparaît aussitôt de l'application."}
      </p>
      <ReasonField value={reason} onChange={setReason} required={!verify} placeholder={verify ? "Ex. : diplôme vérifié par téléphone" : "Expliquez en quelques mots"} />
      <DialogError error={error} />
      <Footer busy={busy} onClose={onClose}>
        <Button kind={verify ? "primary" : "danger"} disabled={busy || !ok} onClick={() => run(() => setExpertVerified(user.id, verify, reason.trim()))}>
          {busy ? "Enregistrement…" : verify ? "Vérifier" : "Retirer la vérification"}
        </Button>
      </Footer>
    </Dialog>
  );
}

/** "Bloquer" / "Débloquer" (reason required). */
export function BlockDialog({ user, onClose, onDone }: { user: UserTarget; onClose: () => void; onDone: () => void }) {
  const block = !user.blocked;
  const [reason, setReason] = useState("");
  const { busy, error, run } = useCall(onDone);
  return (
    <Dialog title={block ? "Bloquer le compte" : "Débloquer le compte"} onClose={onClose} busy={busy}>
      <p>
        Compte : <b>{personName(user.name, "Sans nom")}</b> ({label(ROLE, user.role)})
      </p>
      <p className="mt-2 text-slate-600">
        {block
          ? "Ce compte ne pourra plus se connecter. Sa session en cours s'arrête au plus tard dans une heure. Ses données sont gardées : vous pourrez le débloquer."
          : "Ce compte pourra de nouveau se connecter."}
      </p>
      <ReasonField value={reason} onChange={setReason} required />
      <DialogError error={error} />
      <Footer busy={busy} onClose={onClose}>
        <Button kind={block ? "danger" : "primary"} disabled={busy || !reasonOk(reason)} onClick={() => run(() => setUserBlocked(user.id, block, reason.trim()))}>
          {busy ? "Enregistrement…" : block ? "Bloquer" : "Débloquer"}
        </Button>
      </Footer>
    </Dialog>
  );
}

/** The buttons of an account: expert badge, block. The demo admin: badge only. */
export function UserButtons({ user, onChanged, small = true }: { user: UserTarget & { fake?: boolean }; onChanged: () => void; small?: boolean }) {
  const admin = useAdmin();
  const [open, setOpen] = useState<"verify" | "block" | null>(null);
  const canBlock = !admin.demo_admin && user.role !== "admin" && !user.fake && user.id !== admin.id;
  if (user.role !== "expert" && !canBlock) return null;
  return (
    <div className="flex flex-wrap gap-1.5">
      {user.role === "expert" && (
        <Button small={small} kind={user.verified ? "plain" : "primary"} onClick={() => setOpen("verify")}>
          {user.verified ? "Retirer la vérification" : "Vérifier"}
        </Button>
      )}
      {canBlock && (
        <Button small={small} kind={user.blocked ? "primary" : "plain"} onClick={() => setOpen("block")}>
          {user.blocked ? "Débloquer" : "Bloquer"}
        </Button>
      )}
      {open === "verify" && (
        <VerifyDialog
          user={user}
          onClose={() => setOpen(null)}
          onDone={() => {
            setOpen(null);
            onChanged();
          }}
        />
      )}
      {open === "block" && (
        <BlockDialog
          user={user}
          onClose={() => setOpen(null)}
          onDone={() => {
            setOpen(null);
            onChanged();
          }}
        />
      )}
    </div>
  );
}

// ---------- Posts and answers ----------

export type ModerationTarget = {
  kind: "post" | "comment";
  id: string;
  text: string;
  author: string;
  hidden: boolean;
  /** A post: its answers (deleted with it). */
  answers?: number;
  photo?: boolean;
};

const TITLES: Record<Moderation, Record<"post" | "comment", string>> = {
  hide: { post: "Masquer la publication", comment: "Masquer la réponse" },
  unhide: { post: "Afficher de nouveau la publication", comment: "Afficher de nouveau la réponse" },
  delete: { post: "Supprimer la publication", comment: "Supprimer la réponse" },
};

/**
 * Hide / show again / delete, with a reason. Delete = a second step: the
 * admin confirms that it cannot be undone.
 */
export function ModerateDialog({
  target,
  action,
  onClose,
  onDone,
}: {
  target: ModerationTarget;
  action: Moderation;
  onClose: () => void;
  onDone: (photoKept: boolean) => void;
}) {
  const [reason, setReason] = useState("");
  const [confirming, setConfirming] = useState(false);
  const { busy, error, run } = useCall<{ photo_removed: boolean | null }>((r) => onDone(r.photo_removed === false));
  const what = target.kind === "post" ? "publication" : "réponse";
  const effect: Record<Moderation, string> = {
    hide: `La ${what} disparaît aussitôt de l'application pour tout le monde (son auteur la voit encore). Vous pourrez l'afficher de nouveau.`,
    unhide: `La ${what} réapparaît aussitôt dans l'application.`,
    delete:
      target.kind === "post"
        ? `La publication${target.answers ? `, ses ${target.answers} réponse${target.answers > 1 ? "s" : ""}` : ""}${target.photo ? " et sa photo" : ""} seront effacées. Le journal garde une copie du texte.`
        : "La réponse sera effacée. Le journal garde une copie du texte.",
  };
  const go = () => run(() => moderate(target.kind, target.id, action, reason.trim()));

  return (
    <Dialog title={TITLES[action][target.kind]} onClose={onClose} busy={busy}>
      <p>
        De <b>{personName(target.author, "Sans nom")}</b> :
      </p>
      <blockquote dir="auto" className="mt-1 line-clamp-3 rounded-lg bg-slate-50 px-3 py-2 text-start text-slate-700">
        {target.text}
      </blockquote>
      <p className="mt-3 text-slate-600">{effect[action]}</p>
      {!confirming ? (
        <>
          <ReasonField value={reason} onChange={setReason} required placeholder={action === "unhide" ? "Ex. : vérifié, rien de grave" : "Ex. : publicité, insulte, conseil dangereux"} />
          <DialogError error={error} />
          <Footer busy={busy} onClose={onClose}>
            {action === "delete" ? (
              <Button kind="danger" disabled={!reasonOk(reason)} onClick={() => setConfirming(true)}>
                Continuer
              </Button>
            ) : (
              <Button kind={action === "hide" ? "danger" : "primary"} disabled={busy || !reasonOk(reason)} onClick={go}>
                {busy ? "Enregistrement…" : action === "hide" ? "Masquer" : "Afficher de nouveau"}
              </Button>
            )}
          </Footer>
        </>
      ) : (
        <>
          <p role="alert" className="mt-4 rounded-lg bg-rose-50 px-3 py-2 font-medium text-rose-800">
            Suppression définitive : elle ne peut pas être annulée. Pour pouvoir revenir en arrière, choisissez plutôt « Masquer ».
          </p>
          <p className="mt-2 text-slate-600">Motif : « {reason.trim()} »</p>
          <DialogError error={error} />
          <Footer busy={busy} onClose={onClose}>
            <Button kind="danger" disabled={busy} data-autofocus onClick={go}>
              {busy ? "Suppression…" : "Supprimer définitivement"}
            </Button>
          </Footer>
        </>
      )}
    </Dialog>
  );
}

/** The buttons of a post or an answer: Masquer / Afficher de nouveau, Supprimer. */
export function ModerationButtons({ target, onChanged, onDeleted }: { target: ModerationTarget; onChanged: () => void; onDeleted?: (photoKept: boolean) => void }) {
  const [action, setAction] = useState<Moderation | null>(null);
  return (
    <div className="flex flex-wrap gap-1.5">
      {target.hidden ? (
        <Button small kind="primary" onClick={() => setAction("unhide")}>
          Afficher de nouveau
        </Button>
      ) : (
        <Button small onClick={() => setAction("hide")}>
          Masquer
        </Button>
      )}
      <Button small className="text-rose-700" onClick={() => setAction("delete")}>
        Supprimer
      </Button>
      {action && (
        <ModerateDialog
          target={target}
          action={action}
          onClose={() => setAction(null)}
          onDone={(photoKept) => {
            const deleted = action === "delete";
            setAction(null);
            if (deleted && onDeleted) onDeleted(photoKept);
            else onChanged();
          }}
        />
      )}
    </div>
  );
}

/** "Classer" a report: nothing wrong (reason required). */
export function DismissButton({ reportId, onChanged }: { reportId: string; onChanged: () => void }) {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const { busy, error, run } = useCall(() => {
    setOpen(false);
    onChanged();
  });
  return (
    <>
      <Button small onClick={() => setOpen(true)}>
        Classer
      </Button>
      {open && (
        <Dialog title="Classer le signalement" onClose={() => setOpen(false)} busy={busy}>
          <p className="text-slate-600">Rien à corriger : le texte reste visible et le signalement est fermé.</p>
          <ReasonField value={reason} onChange={setReason} required placeholder="Ex. : le conseil est juste" />
          <DialogError error={error} />
          <Footer busy={busy} onClose={() => setOpen(false)}>
            <Button kind="primary" disabled={busy || !reasonOk(reason)} onClick={() => run(() => dismissReport(reportId, reason.trim()))}>
              {busy ? "Enregistrement…" : "Classer"}
            </Button>
          </Footer>
        </Dialog>
      )}
    </>
  );
}
