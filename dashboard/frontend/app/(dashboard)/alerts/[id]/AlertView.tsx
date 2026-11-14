"use client";

// One regional alert: its state, the editor (while it is not ended), the
// preview of what farmers see, and the admin actions on it.
import { useCallback, useState } from "react";
import Link from "next/link";
import { useParams, useSearchParams } from "next/navigation";

import { ActionList } from "@/components/actions";
import { AlertPreview, AlertStatusBadge, EndAlertButton, KindLabel, SeverityBadge, governoratesText, periodText } from "@/components/alerts";
import { Card, DemoTag, ErrorBox } from "@/components/ui";
import { errorMessage, getRegionalAlert } from "@/lib/api";
import { shortDateTime } from "@/lib/format";
import type { RegionalAlertDetail } from "@/lib/types";
import { usePolling } from "@/lib/usePolling";
import { AlertEditor } from "../AlertEditor";

function Header({ d, onChanged }: { d: RegionalAlertDetail; onChanged: () => void }) {
  const a = d.alert;
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5">
      <div className="flex flex-wrap items-center gap-2">
        <KindLabel kind={a.kind} />
        <SeverityBadge severity={a.severity} />
        <AlertStatusBadge status={a.status} />
        {a.is_demo && <DemoTag />}
        {a.status !== "ended" && (
          <span className="ml-auto">
            <EndAlertButton alertId={a.id} title={a.title_fr} onDone={onChanged} small={false} />
          </span>
        )}
      </div>
      <div className="mt-3 text-lg font-semibold text-slate-900">{a.title_fr}</div>
      <div className="mt-1 text-sm text-slate-600">{governoratesText(a.governorates, 24)}</div>
      <div className="text-sm text-slate-500">
        {periodText(a.starts_at, a.ends_at)}
        {a.ended_at && ` · terminée le ${shortDateTime(a.ended_at)}${a.ended_by_name ? ` par ${a.ended_by_name}` : ""}`}
      </div>
      <div className="text-sm text-slate-500">
        {a.seen_count} agriculteur{a.seen_count > 1 ? "s ont" : " a"} répondu « Moi aussi »{a.created_by_name ? ` · créée par ${a.created_by_name}` : ""}
      </div>
      <div className="text-sm text-slate-500">
        Ouverte par {a.opened_count} agriculteur{a.opened_count > 1 ? "s" : ""} dans l&apos;application · « Fait » : {a.done_count}
      </div>
    </div>
  );
}

export function AlertView() {
  const { id } = useParams<{ id: string }>();
  const params = useSearchParams();
  const [saved, setSaved] = useState(params.get("saved") === "1");
  const load = useCallback(() => getRegionalAlert(id), [id]);
  const { data, error, reload } = usePolling<RegionalAlertDetail>(load, 30000);
  // The editor starts again from the saved alert (key = its last change).
  const editorKey = data ? `${data.alert.id}-${data.alert.updated_at}` : "";

  return (
    <div>
      <Link href="/alerts" className="text-sm font-medium text-emerald-800 hover:underline">
        ← Alertes
      </Link>
      <h1 className="mt-3 text-2xl font-bold text-slate-900">Alerte régionale</h1>
      {saved && (
        <p role="status" className="mt-3 rounded-lg bg-emerald-50 px-4 py-2 text-sm text-emerald-900">
          Alerte enregistrée : les agriculteurs concernés la voient dans l&apos;application (à partir de sa date de début).
        </p>
      )}
      <div className="mt-4 space-y-6">
        {error !== null && <ErrorBox message={(data ? "Données non mises à jour : " : "") + errorMessage(error)} onRetry={reload} />}
        {!data && error === null && <p className="text-slate-500">Chargement…</p>}
        {data && (
          <>
            <Header d={data} onChanged={reload} />
            {data.alert.status === "ended" ? (
              <Card title="Ce que voyaient les agriculteurs">
                <AlertPreview alert={data.alert} seen={data.alert.seen_count} />
              </Card>
            ) : (
              <div>
                <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">Modifier</h2>
                <AlertEditor
                  key={editorKey}
                  alert={data.alert}
                  onSaved={() => {
                    setSaved(true);
                    reload();
                  }}
                />
              </div>
            )}
            <Card title="Actions des administrateurs">
              <ActionList actions={data.actions} empty="Aucune action sur cette alerte." />
            </Card>
          </>
        )}
      </div>
    </div>
  );
}
