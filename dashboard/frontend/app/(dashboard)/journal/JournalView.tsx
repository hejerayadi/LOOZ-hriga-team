"use client";

// "Journal des actions": every action of every admin (who, what, when, on
// what, why), newest first, 100 at a time, with a filter by kind. Nobody can
// change or delete a line (migration 013). The demo account: its own lines.
import { useCallback, useEffect, useState } from "react";

import { ActionList } from "@/components/actions";
import { useAdmin } from "@/components/AdminGuard";
import { Button, ErrorBox } from "@/components/ui";
import { errorMessage, getActions } from "@/lib/api";
import { ACTION_GROUPS } from "@/lib/labels";
import type { ActionLine } from "@/lib/types";

export function JournalView() {
  const admin = useAdmin();
  const [group, setGroup] = useState("all");
  const [lines, setLines] = useState<ActionLine[]>([]);
  const [more, setMore] = useState(false);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const codes = ACTION_GROUPS.find((g) => g.id === group)?.actions;

  const load = useCallback(
    async (before?: number) => {
      setBusy(true);
      setError(null);
      try {
        const page = await getActions(before, codes);
        setLines((old) => (before ? [...old, ...page.actions] : page.actions));
        setMore(page.more);
      } catch (e) {
        setError(e);
      } finally {
        setBusy(false);
      }
    },
    [codes],
  );

  useEffect(() => {
    // The first page, again when the filter changes (an async load, not a render).
    // eslint-disable-next-line react-hooks/set-state-in-effect
    load();
  }, [load]);

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Journal des actions</h1>
      <p className="mt-1 text-slate-500">
        Qui a fait quoi, quand, sur quoi et pourquoi. Personne ne peut modifier ni effacer une ligne.
        {admin.demo_admin ? " Compte de démonstration : seulement ses propres actions." : ""}
      </p>
      <div className="mt-5 rounded-xl border border-slate-200 bg-white p-4">
        <div className="flex flex-wrap items-center gap-2">
          {[{ id: "all", label: "Toutes" }, ...ACTION_GROUPS].map((g) => (
            <button
              key={g.id}
              type="button"
              aria-pressed={group === g.id}
              onClick={() => setGroup(g.id)}
              className={`rounded-full px-3 py-1 text-sm font-medium ${group === g.id ? "bg-emerald-700 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200"}`}
            >
              {g.label}
            </button>
          ))}
          <button type="button" onClick={() => load()} className="ml-auto text-sm font-medium text-emerald-800 hover:underline">
            Actualiser
          </button>
        </div>
        <div className="mt-4">
          {error !== null && <ErrorBox message={errorMessage(error)} onRetry={() => load()} />}
          {busy && !lines.length && error === null && <p className="text-slate-500">Chargement…</p>}
          {!busy || lines.length ? <ActionList actions={lines} links empty="Aucune action de ce type pour l'instant." /> : null}
          {more && (
            <div className="mt-3">
              <Button small disabled={busy} onClick={() => load(lines[lines.length - 1]?.id)}>
                {busy ? "Chargement…" : "Voir les actions plus anciennes"}
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
