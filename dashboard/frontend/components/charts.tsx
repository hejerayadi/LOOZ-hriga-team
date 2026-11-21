"use client";

// Small charts in SVG (no library), in the app's colours:
// - Kpi: a big number, its label, an optional sparkline of the last days;
// - DayBars: one bar per day, the value on hover, the axis with a few dates;
// - HBars: horizontal bars with their labels and values (counts per state);
// - Sparkline: a tiny line (trend).
// Every chart has a text alternative (aria-label) and shows "Aucune donnée"
// when everything is zero.
import Link from "next/link";
import { useState } from "react";

import { Icon } from "./Icon";

export const CHART = {
  main: "#28664a",   // the app's dark green
  soft: "#b8df9b",   // the app's light green
  leaf: "#8ed04a",
  info: "#6e9fc4",
  grid: "#e7efe9",
  text: "#5b6b63",
};

function dayLabel(iso: string): string {
  const [, m, d] = iso.split("-");
  return `${d}/${m}`;
}

export function Sparkline({ values, color = CHART.main, height = 32 }: { values: number[]; color?: string; height?: number }) {
  const max = Math.max(...values, 1);
  const w = 120;
  const pts = values.map((v, i) => `${(i / Math.max(values.length - 1, 1)) * w},${height - 2 - (v / max) * (height - 4)}`);
  return (
    <svg viewBox={`0 0 ${w} ${height}`} className="h-8 w-full" preserveAspectRatio="none" aria-hidden="true">
      <polyline points={pts.join(" ")} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

export function Kpi({
  label,
  value,
  hint,
  icon,
  href,
  trend,
  tone = "default",
}: {
  label: string;
  value: React.ReactNode;
  hint?: React.ReactNode;
  icon?: string;
  href?: string;
  trend?: number[];
  tone?: "default" | "alert";
}) {
  const body = (
    <div
      className={`h-full rounded-2xl border bg-white p-4 shadow-[0_8px_24px_rgba(15,61,43,0.06)] transition ${
        tone === "alert" ? "border-amber-200" : "border-emerald-100"
      } ${href ? "hover:-translate-y-0.5 hover:border-emerald-300" : ""}`}
    >
      <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-emerald-700">
        {icon && (
          <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-emerald-50 text-emerald-700">
            <Icon name={icon} className="h-4 w-4" />
          </span>
        )}
        {label}
      </div>
      <div className="mt-2 text-3xl font-extrabold tabular-nums text-emerald-900">{value}</div>
      {hint && <div className="mt-0.5 text-sm text-slate-600">{hint}</div>}
      {trend && trend.some((v) => v > 0) && (
        <div className="mt-2">
          <Sparkline values={trend} />
        </div>
      )}
    </div>
  );
  return href ? (
    <Link href={href} className="block h-full">
      {body}
    </Link>
  ) : (
    body
  );
}

export function DayBars({
  days,
  values,
  unit = "",
  color = CHART.main,
  height = 150,
  label,
}: {
  days: string[];
  values: number[];
  unit?: string;
  color?: string;
  height?: number;
  label: string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const max = Math.max(...values, 0);
  const total = values.reduce((a, b) => a + b, 0);
  if (!max) return <div className="flex h-24 items-center justify-center text-sm text-slate-400">Aucune donnée sur la période</div>;
  const W = 600;
  const H = height;
  const pad = { l: 4, r: 4, t: 18, b: 22 };
  const bw = (W - pad.l - pad.r) / values.length;
  const y = (v: number) => H - pad.b - (v / max) * (H - pad.t - pad.b);
  const step = Math.ceil(values.length / 6);
  const fmt = (v: number) => (Number.isInteger(v) ? String(v) : v.toFixed(1)) + unit;
  return (
    <figure>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img"
           aria-label={`${label} : ${fmt(total)} au total, maximum ${fmt(max)} par jour`}
           onMouseLeave={() => setHover(null)}>
        <line x1={0} x2={W} y1={H - pad.b} y2={H - pad.b} stroke={CHART.grid} />
        {values.map((v, i) => (
          <g key={days[i]} onMouseEnter={() => setHover(i)}>
            <rect x={pad.l + i * bw} y={pad.t} width={bw} height={H - pad.t - pad.b} fill="transparent" />
            <rect x={pad.l + i * bw + bw * 0.15} y={y(v)} width={bw * 0.7} height={Math.max(H - pad.b - y(v), v ? 1.5 : 0)}
                  rx={2} fill={hover === i ? CHART.leaf : color} />
            {i % step === 0 && (
              <text x={pad.l + i * bw + bw / 2} y={H - 6} textAnchor="middle" fontSize={11} fill={CHART.text}>{dayLabel(days[i])}</text>
            )}
          </g>
        ))}
        {hover !== null && (
          <text x={Math.min(Math.max(pad.l + hover * bw + bw / 2, 40), W - 40)} y={12} textAnchor="middle" fontSize={12}
                fontWeight={700} fill="#0f3d2b">
            {dayLabel(days[hover])} : {fmt(values[hover])}
          </text>
        )}
      </svg>
      <figcaption className="sr-only">{label}</figcaption>
    </figure>
  );
}

export function HBars({ rows }: { rows: { label: string; value: number; color?: string; hint?: string }[] }) {
  const max = Math.max(...rows.map((r) => r.value), 0);
  if (!max) return <div className="py-6 text-center text-sm text-slate-400">Aucune donnée</div>;
  return (
    <ul className="space-y-2">
      {rows.map((r) => (
        <li key={r.label}>
          <div className="flex items-baseline justify-between gap-2 text-sm">
            <span className="font-semibold text-slate-700">{r.label}</span>
            <span className="tabular-nums font-bold text-emerald-900">{r.value}</span>
          </div>
          <div className="mt-1 h-2.5 w-full rounded-full bg-emerald-50">
            <div className="h-2.5 rounded-full" style={{ width: `${(r.value / max) * 100}%`, background: r.color ?? CHART.main }} />
          </div>
          {r.hint && <div className="mt-0.5 text-xs text-slate-500">{r.hint}</div>}
        </li>
      ))}
    </ul>
  );
}
