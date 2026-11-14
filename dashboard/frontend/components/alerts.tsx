"use client";

// Regional alerts: badges, the governorates of an alert, "Terminer", and the
// PREVIEW of what farmers see in the app (the regional alert screen, in
// Arabic and in French, same colours and words as the app).
import { useState } from "react";

import { endRegionalAlert, errorMessage } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { ALERT_KIND, ALERT_KIND_ICON, ALERT_STATUS, GOVERNORATES, PREVIEW_AR, PREVIEW_FR, SEVERITY, label } from "@/lib/labels";
import { Button, Dialog, ReasonField, reasonOk } from "./ui";

const SEVERITY_STYLE: Record<string, string> = {
  info: "bg-sky-50 text-sky-800 ring-sky-200",
  warning: "bg-amber-50 text-amber-900 ring-amber-300",
  danger: "bg-red-600 text-white ring-red-600",
};

export function SeverityBadge({ severity }: { severity: string }) {
  return (
    <span className={`whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ring-1 ${SEVERITY_STYLE[severity] ?? SEVERITY_STYLE.info}`}>
      {label(SEVERITY, severity)}
    </span>
  );
}

const STATUS_STYLE: Record<string, string> = {
  active: "bg-emerald-50 text-emerald-800",
  scheduled: "bg-sky-50 text-sky-800",
  expired: "bg-slate-100 text-slate-600",
  ended: "bg-slate-100 text-slate-600",
};

export function AlertStatusBadge({ status }: { status: string }) {
  return <span className={`whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-medium ${STATUS_STYLE[status] ?? STATUS_STYLE.ended}`}>{label(ALERT_STATUS, status)}</span>;
}

export function KindLabel({ kind }: { kind: string }) {
  return (
    <span className="whitespace-nowrap font-medium text-slate-900">
      <span aria-hidden className="mr-1">
        {ALERT_KIND_ICON[kind] ?? "⚠️"}
      </span>
      {label(ALERT_KIND, kind)}
    </span>
  );
}

/** "Toute la Tunisie (24 gouvernorats)" or "Sfax, Sousse et 3 autres". */
export function governoratesText(codes: string[], max = 5): string {
  if (codes.length >= 24) return "Toute la Tunisie (24 gouvernorats)";
  const names = codes.map((c) => label(GOVERNORATES, c));
  if (names.length <= max) return names.join(", ");
  return `${names.slice(0, max).join(", ")} et ${names.length - max} autres`;
}

/** "Du 12/11/2026 10:00 au 14/11/2026 18:00" / "Depuis le …, sans date de fin". */
export function periodText(startsAt: string, endsAt: string | null): string {
  return endsAt ? `Du ${dateTime(startsAt)} au ${dateTime(endsAt)}` : `Depuis le ${dateTime(startsAt)}, sans date de fin`;
}

/** "Terminer l'alerte" (reason required): it disappears from the app at once. */
export function EndAlertButton({ alertId, title, onDone, small = true }: { alertId: string; title: string; onDone: () => void; small?: boolean }) {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function end() {
    setBusy(true);
    setError(null);
    try {
      await endRegionalAlert(alertId, reason.trim());
      setOpen(false);
      onDone();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <Button small={small} kind="danger" onClick={() => setOpen(true)}>
        Terminer
      </Button>
      {open && (
        <Dialog title="Terminer l'alerte" onClose={() => setOpen(false)} busy={busy}>
          <p>
            Alerte : <b>{title}</b>
          </p>
          <p className="mt-2 text-slate-600">Elle disparaît aussitôt de l&apos;application. Elle reste dans l&apos;historique, et ne peut plus être modifiée.</p>
          <ReasonField value={reason} onChange={setReason} required placeholder="Ex. : la vague de chaleur est passée" />
          {error && <p className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">{error}</p>}
          <div className="mt-5 flex justify-end gap-2">
            <Button onClick={() => setOpen(false)} disabled={busy}>
              Annuler
            </Button>
            <Button kind="danger" disabled={busy || !reasonOk(reason)} onClick={end}>
              {busy ? "Enregistrement…" : "Terminer l'alerte"}
            </Button>
          </div>
        </Dialog>
      )}
    </>
  );
}

// ---------- Preview: the app's regional alert screen ----------

export type PreviewAlert = {
  kind: string;
  severity: string;
  governorates: string[];
  title_ar: string;
  title_fr: string;
  body_ar: string;
  body_fr: string;
  advice_ar: string | null;
  advice_fr: string | null;
  ends_at: string | null;
};

// The colours of the app (mobile_app/lib/core/theme/app_colors.dart).
const APP = { green: "#0F3D2B", yellow: "#E5F3DA", peach: "#DFF1D5", mint: "#C8EFD9", cream: "#FAF8F3", softGreen: "#D8EFC9", lightGreen: "#B8DF9B" };
// The severity pill of the app: dark green, medium green, blue (white text).
const PILL: Record<string, string> = { info: "#6E9FC4", warning: "#69A66F", danger: "#28664A" };

const dayMonth = new Intl.DateTimeFormat("fr-FR", { timeZone: "Africa/Tunis", day: "numeric", month: "numeric" });
const hourMinute = new Intl.DateTimeFormat("fr-FR", { timeZone: "Africa/Tunis", hour: "2-digit", minute: "2-digit" });

/** Like the app: one step per line; a single line is cut after each sentence. */
export function adviceSteps(advice: string | null): string[] {
  let steps = (advice ?? "").split("\n").map((l) => l.trim()).filter(Boolean);
  if (steps.length === 1) steps = steps[0].split(/(?<=[.!?؟؛])\s+/).map((l) => l.trim()).filter(Boolean);
  return steps;
}

function Phone({ lang, a, seen }: { lang: "ar" | "fr"; a: PreviewAlert; seen: number }) {
  const ar = lang === "ar";
  const t = ar ? PREVIEW_AR : PREVIEW_FR;
  const title = (ar ? a.title_ar : a.title_fr).trim();
  const body = (ar ? a.body_ar : a.body_fr).trim();
  const steps = adviceSteps(ar ? a.advice_ar : a.advice_fr);
  const kind = ar ? PREVIEW_AR.kind[a.kind] ?? "" : label(ALERT_KIND, a.kind);
  const severity = ar ? PREVIEW_AR.severity[a.severity] ?? "" : label(SEVERITY, a.severity);
  const region = a.governorates[0];
  const regionName = region ? (ar ? PREVIEW_AR.governorates[region] : label(GOVERNORATES, region)) : "";
  const end = a.ends_at ? new Date(a.ends_at) : null;
  const validity = end ? t.validUntil(dayMonth.format(end), hourMinute.format(end)) : t.noEnd;
  return (
    <figure className="w-full max-w-[300px]">
      <figcaption className="mb-2 text-center text-xs font-semibold uppercase tracking-wide text-slate-500">{ar ? "Écran en arabe" : "Écran en français"}</figcaption>
      <div dir={ar ? "rtl" : "ltr"} lang={lang} className="rounded-[34px] border-[6px] border-slate-800 p-4" style={{ background: APP.cream, color: APP.green }}>
        <div className="text-lg font-bold">{t.screenTitle}</div>
        {regionName && <div className="text-xs opacity-70">{regionName}</div>}
        <div className="mt-3 flex flex-col items-center rounded-[28px] px-4 py-5 text-center" style={{ background: `linear-gradient(145deg, ${APP.yellow}, ${APP.peach})` }}>
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-white/70 text-3xl" aria-hidden>
            {ALERT_KIND_ICON[a.kind] ?? "⚠️"}
          </div>
          <div className="mt-2 flex flex-wrap justify-center gap-1.5 text-[11px] font-semibold">
            <span className="rounded-full px-2 py-0.5 text-white" style={{ background: PILL[a.severity] ?? PILL.info }}>
              {severity}
            </span>
            {kind && <span className="rounded-full bg-white/70 px-2 py-0.5">{kind}</span>}
          </div>
          <div className="mt-2 text-xl font-bold leading-snug">{title || "…"}</div>
          <div className="mt-2 whitespace-pre-wrap text-sm leading-relaxed">{body || "…"}</div>
        </div>
        {steps.length > 0 && (
          <div className="mt-3 rounded-2xl bg-white px-3 py-3 text-start text-sm shadow-sm">
            <div className="mb-2 font-bold">{t.whatToDo}</div>
            <ol className="space-y-1.5">
              {steps.map((step, i) => (
                <li key={i} className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[11px] font-bold" style={{ background: APP.mint }}>
                    {i + 1}
                  </span>
                  <span>{step}</span>
                </li>
              ))}
            </ol>
          </div>
        )}
        <div className="mt-3 text-xs">🕒 {validity}</div>
        <div className="mt-1 text-sm font-semibold">👥 {t.meTooText(seen)}</div>
        <div className="mt-3 rounded-full py-2.5 text-center font-bold" style={{ background: APP.lightGreen }}>
          {t.meToo}
        </div>
        {steps.length > 0 && (
          <div className="mt-2 rounded-full py-2.5 text-center font-bold" style={{ background: APP.softGreen }}>
            {t.done}
          </div>
        )}
      </div>
    </figure>
  );
}

/** How farmers see the alert: the app's screen in Arabic and in French. */
export function AlertPreview({ alert, seen = 0 }: { alert: PreviewAlert; seen?: number }) {
  return (
    <div>
      <div className="flex flex-wrap justify-center gap-6">
        <Phone lang="ar" a={alert} seen={seen} />
        <Phone lang="fr" a={alert} seen={seen} />
      </div>
      <p className="mt-3 text-center text-xs text-slate-500">
        Aperçu de l&apos;écran de l&apos;application (onglet « التنبيهات / Alertes »). Les agriculteurs des gouvernorats choisis
        voient l&apos;alerte dans la minute (ou en tirant la liste vers le bas). Notifications push : bientôt.
      </p>
    </div>
  );
}
