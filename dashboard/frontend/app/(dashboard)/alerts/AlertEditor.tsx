"use client";

// Create or change a regional alert: type, gravity, governorates, title /
// text / advice in Arabic AND French, start and end, and the preview of what
// farmers see. The same checks as the database (migration 013,
// regional_alert_problem): the database checks again when saving.
import { useState } from "react";
import { useRouter } from "next/navigation";

import { useAdmin } from "@/components/AdminGuard";
import { AlertPreview } from "@/components/alerts";
import { Button, Card } from "@/components/ui";
import { errorMessage, saveRegionalAlert } from "@/lib/api";
import { ALERT_KIND, ALERT_KIND_ICON, GOVERNORATES, SEVERITY } from "@/lib/labels";
import type { AlertInput, RegionalAlert } from "@/lib/types";

const ALL = Object.keys(GOVERNORATES);
const ARABIC = /[ء-ي]/;
const LATIN = /[A-Za-z]/;
const INPUT = "mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 font-normal outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100";

/** "2026-11-14T18:00" in this computer's time (the <input type="datetime-local">). */
function toLocalInput(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function fromLocalInput(value: string): string | null {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function textProblem(value: string, max: number, arabic: boolean): string | null {
  const v = value.trim();
  if (!v) return "obligatoire";
  if (v.length > max) return `${max} caractères au plus`;
  if (/[<>]/.test(v)) return "sans < ni >";
  if (arabic && !ARABIC.test(v)) return "en lettres arabes";
  if (!arabic && !LATIN.test(v)) return "en français";
  return null;
}

/** The app shows each line as a numbered step of "ماذا أفعل؟ / Que faire ?". */
const ADVICE_HINT = "Une étape par ligne, courte et simple (l'application les numérote).";

function Field({
  label,
  value,
  onChange,
  max,
  arabic,
  rows = 1,
  problem,
  hint,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  max: number;
  arabic: boolean;
  rows?: number;
  problem: string | null;
  hint?: string;
}) {
  const shown = problem && value.trim() ? problem : null;
  const props = {
    value,
    onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => onChange(e.target.value),
    maxLength: max,
    dir: arabic ? "rtl" : "ltr",
    lang: arabic ? "ar" : "fr",
    className: `${INPUT} ${shown ? "border-rose-400" : ""}`,
  } as const;
  return (
    <label className="block text-sm font-medium text-slate-700">
      {label}
      {hint && <span className="block text-xs font-normal text-slate-500">{hint}</span>}
      {rows > 1 ? <textarea rows={rows} {...props} /> : <input type="text" {...props} />}
      <span className="flex justify-between text-xs font-normal">
        <span className="text-rose-700">{shown}</span>
        <span className="text-slate-400">
          {value.trim().length} / {max}
        </span>
      </span>
    </label>
  );
}

export function AlertEditor({ alert, onSaved }: { alert?: RegionalAlert; onSaved?: (saved: RegionalAlert) => void }) {
  const router = useRouter();
  const admin = useAdmin();
  const editing = !!alert;
  const [kind, setKind] = useState(alert?.kind ?? "");
  const [severity, setSeverity] = useState(alert?.severity ?? "");
  const [govs, setGovs] = useState<string[]>(alert?.governorates ?? []);
  const [titleAr, setTitleAr] = useState(alert?.title_ar ?? "");
  const [titleFr, setTitleFr] = useState(alert?.title_fr ?? "");
  const [bodyAr, setBodyAr] = useState(alert?.body_ar ?? "");
  const [bodyFr, setBodyFr] = useState(alert?.body_fr ?? "");
  const [withAdvice, setWithAdvice] = useState(!!(alert?.advice_ar || alert?.advice_fr));
  const [adviceAr, setAdviceAr] = useState(alert?.advice_ar ?? "");
  const [adviceFr, setAdviceFr] = useState(alert?.advice_fr ?? "");
  const startedAlready = !!alert && alert.status !== "scheduled";
  const [startLater, setStartLater] = useState(alert?.status === "scheduled");
  const [start, setStart] = useState(toLocalInput(alert?.starts_at ?? null));
  const [withEnd, setWithEnd] = useState(!!alert?.ends_at);
  const [end, setEnd] = useState(toLocalInput(alert?.ends_at ?? null));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const problems = {
    titleAr: textProblem(titleAr, 80, true),
    titleFr: textProblem(titleFr, 80, false),
    bodyAr: textProblem(bodyAr, 600, true),
    bodyFr: textProblem(bodyFr, 600, false),
    adviceAr: withAdvice ? textProblem(adviceAr, 400, true) : null,
    adviceFr: withAdvice ? textProblem(adviceFr, 400, false) : null,
  };
  const startIso = startLater ? fromLocalInput(start) : null;
  const endIso = withEnd ? fromLocalInput(end) : null;
  const startsAtFor = startIso ?? (startedAlready && alert ? alert.starts_at : new Date().toISOString());
  const missing: string[] = [];
  if (!kind) missing.push("le type");
  if (!severity) missing.push("la gravité");
  if (!govs.length) missing.push("au moins un gouvernorat");
  if (problems.titleAr || problems.bodyAr || problems.adviceAr) missing.push("les textes en arabe");
  if (problems.titleFr || problems.bodyFr || problems.adviceFr) missing.push("les textes en français");
  if (startLater && !startIso) missing.push("la date de début");
  if (withEnd && !endIso) missing.push("la date de fin");
  if (endIso && new Date(endIso) <= new Date(startsAtFor)) missing.push("une fin après le début");
  const ok = missing.length === 0;

  function toggle(code: string) {
    setGovs((g) => (g.includes(code) ? g.filter((x) => x !== code) : [...g, code].sort((a, b) => ALL.indexOf(a) - ALL.indexOf(b))));
  }

  async function save() {
    setBusy(true);
    setError(null);
    const input: AlertInput = {
      kind,
      severity,
      governorates: govs.length === ALL.length ? ["all"] : govs,
      title_ar: titleAr.trim(),
      title_fr: titleFr.trim(),
      body_ar: bodyAr.trim(),
      body_fr: bodyFr.trim(),
      advice_ar: withAdvice ? adviceAr.trim() : null,
      advice_fr: withAdvice ? adviceFr.trim() : null,
      // Not given: a new alert starts now; a started alert keeps its start.
      // A planned alert switched to "Maintenant" starts now.
      starts_at: startLater ? startIso : editing && !startedAlready ? new Date().toISOString() : null,
      ends_at: endIso,
    };
    try {
      const saved = await saveRegionalAlert(alert?.id ?? null, input);
      if (onSaved) {
        onSaved(saved);
        setBusy(false);
      } else router.push(`/alerts/${saved.id}?saved=1`);
    } catch (e) {
      setError(errorMessage(e));
      setBusy(false);
    }
  }

  return (
    <div className="grid gap-6 2xl:grid-cols-[minmax(0,1fr)_640px]">
      <div className="space-y-6">
        <Card title="Type et gravité">
          <fieldset>
            <legend className="text-sm font-medium text-slate-700">Type</legend>
            <div className="mt-2 flex flex-wrap gap-2">
              {Object.entries(ALERT_KIND).map(([code, name]) => (
                <button
                  key={code}
                  type="button"
                  aria-pressed={kind === code}
                  onClick={() => setKind(code)}
                  className={`rounded-full border px-3 py-1.5 text-sm ${kind === code ? "border-emerald-700 bg-emerald-700 text-white" : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"}`}
                >
                  <span aria-hidden className="mr-1">
                    {ALERT_KIND_ICON[code]}
                  </span>
                  {name}
                </button>
              ))}
            </div>
          </fieldset>
          <fieldset className="mt-4">
            <legend className="text-sm font-medium text-slate-700">Gravité</legend>
            <div className="mt-2 flex flex-wrap gap-2">
              {Object.entries(SEVERITY).map(([code, name]) => (
                <button
                  key={code}
                  type="button"
                  aria-pressed={severity === code}
                  onClick={() => setSeverity(code)}
                  className={`rounded-full border px-3 py-1.5 text-sm ${severity === code ? "border-emerald-700 bg-emerald-700 text-white" : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"}`}
                >
                  {name}
                </button>
              ))}
            </div>
          </fieldset>
        </Card>

        <Card
          title={`Gouvernorats (${govs.length} / 24)`}
          action={
            <div className="flex gap-3 text-sm">
              <button type="button" onClick={() => setGovs(ALL)} className="font-medium text-emerald-800 hover:underline">
                Toute la Tunisie
              </button>
              <button type="button" onClick={() => setGovs([])} className="font-medium text-slate-600 hover:underline">
                Aucun
              </button>
            </div>
          }
        >
          <p className="-mt-1 mb-2 text-xs text-slate-500">Seuls les agriculteurs de ces gouvernorats voient l&apos;alerte.</p>
          <div className="grid grid-cols-2 gap-x-4 gap-y-1 sm:grid-cols-3 xl:grid-cols-4">
            {ALL.map((code) => (
              <label key={code} className="flex items-center gap-2 text-sm text-slate-700">
                <input type="checkbox" checked={govs.includes(code)} onChange={() => toggle(code)} className="h-4 w-4 accent-emerald-700" />
                {GOVERNORATES[code]}
              </label>
            ))}
          </div>
        </Card>

        <Card title="Textes (arabe simple et français)">
          <div className="grid gap-4 lg:grid-cols-2">
            <div className="space-y-3">
              <Field label="Titre en arabe" value={titleAr} onChange={setTitleAr} max={80} arabic problem={problems.titleAr} />
              <Field label="Texte en arabe" value={bodyAr} onChange={setBodyAr} max={600} arabic rows={4} problem={problems.bodyAr} />
            </div>
            <div className="space-y-3">
              <Field label="Titre en français" value={titleFr} onChange={setTitleFr} max={80} arabic={false} problem={problems.titleFr} />
              <Field label="Texte en français" value={bodyFr} onChange={setBodyFr} max={600} arabic={false} rows={4} problem={problems.bodyFr} />
            </div>
          </div>
          <label className="mt-4 flex items-center gap-2 text-sm font-medium text-slate-700">
            <input type="checkbox" checked={withAdvice} onChange={(e) => setWithAdvice(e.target.checked)} className="h-4 w-4 accent-emerald-700" />
            Ajouter un conseil (dans les deux langues)
          </label>
          {withAdvice && (
            <div className="mt-3 grid gap-4 lg:grid-cols-2">
              <Field label="Conseil en arabe" hint={ADVICE_HINT} value={adviceAr} onChange={setAdviceAr} max={400} arabic rows={4} problem={problems.adviceAr} />
              <Field label="Conseil en français" hint={ADVICE_HINT} value={adviceFr} onChange={setAdviceFr} max={400} arabic={false} rows={4} problem={problems.adviceFr} />
            </div>
          )}
        </Card>

        <Card title="Dates">
          <div className="grid gap-4 md:grid-cols-2">
            <fieldset className="text-sm text-slate-700">
              <legend className="font-medium">Début</legend>
              {startedAlready ? (
                <p className="mt-2 text-slate-600">Déjà commencée : la date de début ne change plus.</p>
              ) : (
                <>
                  <label className="mt-2 flex items-center gap-2">
                    <input type="radio" checked={!startLater} onChange={() => setStartLater(false)} className="accent-emerald-700" />
                    Maintenant
                  </label>
                  <label className="mt-1 flex items-center gap-2">
                    <input type="radio" checked={startLater} onChange={() => setStartLater(true)} className="accent-emerald-700" />
                    Plus tard
                  </label>
                  {startLater && <input type="datetime-local" value={start} onChange={(e) => setStart(e.target.value)} aria-label="Date de début" className={INPUT} />}
                </>
              )}
            </fieldset>
            <fieldset className="text-sm text-slate-700">
              <legend className="font-medium">Fin</legend>
              <label className="mt-2 flex items-center gap-2">
                <input type="radio" checked={!withEnd} onChange={() => setWithEnd(false)} className="accent-emerald-700" />
                Jusqu&apos;à ce qu&apos;un administrateur la termine
              </label>
              <label className="mt-1 flex items-center gap-2">
                <input type="radio" checked={withEnd} onChange={() => setWithEnd(true)} className="accent-emerald-700" />
                À une date
              </label>
              {withEnd && <input type="datetime-local" value={end} onChange={(e) => setEnd(e.target.value)} aria-label="Date de fin" className={INPUT} />}
            </fieldset>
          </div>
          <p className="mt-3 text-xs text-slate-500">Heure de cet ordinateur (heure de Tunisie).</p>
        </Card>

        <div className="rounded-xl border border-slate-200 bg-white p-4">
          {admin.demo_admin && (
            <p className="mb-3 text-sm text-violet-800">Compte de démonstration : l&apos;alerte est marquée « démo ».</p>
          )}
          {!ok && <p className="mb-3 text-sm text-slate-600">À compléter : {missing.join(", ")}.</p>}
          {error && <p className="mb-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}
          <div className="flex flex-wrap gap-2">
            <Button kind="primary" disabled={!ok || busy} onClick={save}>
              {busy ? "Enregistrement…" : editing ? "Enregistrer les modifications" : "Publier l'alerte"}
            </Button>
            <Button onClick={() => router.push(editing && alert ? `/alerts/${alert.id}` : "/alerts")} disabled={busy}>
              Annuler
            </Button>
          </div>
          {!editing && <p className="mt-2 text-xs text-slate-500">Publiée, elle apparaît aussitôt dans l&apos;application des agriculteurs concernés (à la date de début).</p>}
        </div>
      </div>

      <div className="2xl:sticky 2xl:top-4 2xl:self-start">
        <Card title="Aperçu : ce que voient les agriculteurs">
          <AlertPreview
            alert={{
              kind,
              severity,
              governorates: govs,
              title_ar: titleAr,
              title_fr: titleFr,
              body_ar: bodyAr,
              body_fr: bodyFr,
              advice_ar: withAdvice ? adviceAr : null,
              advice_fr: withAdvice ? adviceFr : null,
              ends_at: endIso,
            }}
            seen={alert?.seen_count ?? 0}
          />
        </Card>
      </div>
    </div>
  );
}
