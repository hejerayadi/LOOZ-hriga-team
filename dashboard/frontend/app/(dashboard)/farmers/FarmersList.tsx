"use client";

// The farmers: pack, orchard, state of the sensor boxes, last data.
// Asked again every 30 s while the page is visible.
import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { LevelBadge, PackText } from "@/components/iot";
import { errorMessage, getFarmers } from "@/lib/api";
import { phone, timeAgo } from "@/lib/format";
import { GOVERNORATES, label, personName } from "@/lib/labels";
import type { BoxCounts, FarmerSummary } from "@/lib/types";
import { useNow, usePolling } from "@/lib/usePolling";

const COUNT_TEXT: [keyof BoxCounts, string, string][] = [
  ["online", "en ligne", "bg-emerald-50 text-emerald-800"],
  ["sensor_problem", "problème", "bg-amber-50 text-amber-800"],
  ["offline", "hors ligne", "bg-rose-50 text-rose-800"],
  ["waiting", "en attente", "bg-sky-50 text-sky-800"],
  ["installed", "sans données", "bg-slate-100 text-slate-700"],
];

function BoxesCell({ boxes }: { boxes: BoxCounts }) {
  if (!boxes.total) return <span className="text-slate-400">—</span>;
  return (
    <div className="flex flex-wrap gap-1">
      {COUNT_TEXT.filter(([key]) => boxes[key] > 0).map(([key, text, style]) => (
        <span key={key} className={`whitespace-nowrap rounded px-1.5 py-0.5 text-xs font-medium ${style}`}>
          {boxes[key]} {text}
        </span>
      ))}
    </div>
  );
}

function orchardText(f: FarmerSummary): string {
  if (!f.orchard_status) return "—";
  if (f.orchard_status === "draft") return "Brouillon";
  return `${f.zones} zone${f.zones > 1 ? "s" : ""}`;
}

export function FarmersList() {
  const router = useRouter();
  const [typed, setTyped] = useState("");
  const [search, setSearch] = useState("");
  const [onlyBoxes, setOnlyBoxes] = useState(false);
  const now = useNow();

  // Search 400 ms after the last key.
  useEffect(() => {
    const id = setTimeout(() => setSearch(typed), 400);
    return () => clearTimeout(id);
  }, [typed]);

  const load = useCallback(() => getFarmers(search), [search]);
  const { data, error, receivedAt, reload } = usePolling(load, 30000);
  const serverNow = data && receivedAt ? new Date(data.server_time).getTime() + (now - receivedAt) : now;
  const farmers = (data?.farmers ?? []).filter((f) => !onlyBoxes || f.boxes.total > 0);

  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">Agriculteurs</h1>
      <p className="mt-1 text-slate-500">
        Leur pack, leur verger et l&apos;état de leurs boîtiers de capteurs. Mise à jour automatique toutes les 30 s.
      </p>

      <div className="mt-5 flex flex-wrap items-center gap-4">
        <input
          type="search"
          value={typed}
          onChange={(e) => setTyped(e.target.value)}
          placeholder="Rechercher un nom ou un numéro"
          aria-label="Rechercher un nom ou un numéro"
          className="w-72 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
        />
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input type="checkbox" checked={onlyBoxes} onChange={(e) => setOnlyBoxes(e.target.checked)} className="h-4 w-4 accent-emerald-700" />
          Seulement les agriculteurs avec des boîtiers
        </label>
        {receivedAt && <span className="ml-auto text-xs text-slate-400">Mis à jour {timeAgo(new Date(receivedAt).toISOString(), now)}</span>}
      </div>

      {error !== null && (
        <div className="mt-4 flex items-center gap-3 rounded-lg bg-red-50 px-4 py-2 text-sm text-red-700">
          {errorMessage(error)}
          <button onClick={reload} className="font-medium underline">
            Réessayer
          </button>
        </div>
      )}

      <div className="mt-5 overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">Agriculteur</th>
              <th className="px-4 py-3 font-medium">Gouvernorat</th>
              <th className="px-4 py-3 font-medium">Pack</th>
              <th className="px-4 py-3 font-medium">Verger</th>
              <th className="px-4 py-3 font-medium">Boîtiers</th>
              <th className="px-4 py-3 font-medium">Niveau le plus haut</th>
              <th className="px-4 py-3 font-medium">Dernière donnée</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {!data && error === null && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-slate-400">
                  Chargement…
                </td>
              </tr>
            )}
            {data && farmers.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-slate-400">
                  Aucun agriculteur ne correspond.
                </td>
              </tr>
            )}
            {farmers.map((f) => (
              <tr key={f.id} onClick={() => router.push(`/farmers/${f.id}`)} className="cursor-pointer hover:bg-emerald-50/40">
                <td className="px-4 py-3">
                  <Link href={`/farmers/${f.id}`} className="font-semibold text-slate-900 hover:text-emerald-800" onClick={(e) => e.stopPropagation()}>
                    {personName(f.name, "Sans nom")}
                  </Link>
                  <div className="text-xs text-slate-500">{phone(f.phone)}</div>
                </td>
                <td className="px-4 py-3 text-slate-700">{label(GOVERNORATES, f.governorate)}</td>
                <td className="px-4 py-3">
                  <PackText pack={f.pack} compact />
                </td>
                <td className="px-4 py-3 text-slate-700">{orchardText(f)}</td>
                <td className="px-4 py-3">
                  <BoxesCell boxes={f.boxes} />
                </td>
                <td className="px-4 py-3">
                  <LevelBadge level={f.worst_level} />
                </td>
                <td className="px-4 py-3 text-slate-700">
                  {f.last_received_at ? timeAgo(f.last_received_at, serverNow) : <span className="text-slate-400">—</span>}
                  {f.demo_time && <div className="text-xs text-violet-700">horloge simulée</div>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
