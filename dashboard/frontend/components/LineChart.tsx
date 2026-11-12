"use client";

// A line chart in SVG (no library): one line per sensor box, one measure.
// - one y axis only (one measure per chart);
// - colours: the 4 first slots of a colour-blind-checked palette, in a
//   fixed order (zone A, B, C, D...), never by rank;
// - a legend, and the last value written at the end of each line;
// - the line breaks where data is missing (box removed, gateway off...);
// - hover: a vertical line snaps to the nearest measure, a box lists the
//   value of every line at that time.
import { useEffect, useMemo, useRef, useState } from "react";

import { shortDateTime } from "@/lib/format";

/** Fixed order: zone A, B, C, D, then the next ones. */
export const SERIES_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"];

export type ChartSeries = {
  id: string;
  name: string;
  color: string;
  points: { t: number; v: number | null }[];
};

const TZ_OFFSET_MS = 60 * 60 * 1000; // Tunisia: UTC+1 all year
const HOUR = 60 * 60 * 1000;
const MARGIN = { left: 44, right: 104, top: 14, bottom: 30 };

function niceStep(range: number, count: number): number {
  const raw = range / Math.max(count, 1);
  const power = 10 ** Math.floor(Math.log10(raw));
  const unit = raw / power;
  return (unit <= 1 ? 1 : unit <= 2 ? 2 : unit <= 5 ? 5 : 10) * power;
}

function niceDomain(min: number, max: number): { d0: number; d1: number; ticks: number[] } {
  if (min === max) {
    min -= 1;
    max += 1;
  }
  const step = niceStep(max - min, 4);
  const d0 = Math.floor(min / step) * step;
  const d1 = Math.ceil(max / step) * step;
  const ticks: number[] = [];
  for (let v = d0; v <= d1 + step / 2; v += step) ticks.push(Math.round(v * 1000) / 1000);
  return { d0, d1, ticks };
}

/** Ticks of the time axis at midnight and noon, Tunisia time. */
function timeTicks(start: number, end: number): number[] {
  const ticks: number[] = [];
  const firstLocal = Math.ceil((start + TZ_OFFSET_MS) / (12 * HOUR)) * 12 * HOUR;
  for (let local = firstLocal; local - TZ_OFFSET_MS <= end; local += 12 * HOUR) ticks.push(local - TZ_OFFSET_MS);
  return ticks;
}

function tickText(t: number): string {
  const d = new Date(t + TZ_OFFSET_MS);
  if (d.getUTCHours() === 12) return "12 h";
  return `${String(d.getUTCDate()).padStart(2, "0")}/${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

export function LineChart({
  series,
  start,
  end,
  format,
  fixedDomain,
  gapMs,
  height = 260,
  ariaLabel,
}: {
  series: ChartSeries[];
  start: number;
  end: number;
  /** 23.4 -> "23,4 %" */
  format: (v: number) => string;
  fixedDomain?: [number, number];
  /** More time than this between 2 measures: the line breaks. */
  gapMs: number;
  height?: number;
  ariaLabel: string;
}) {
  const wrap = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(720);
  const [hoverT, setHoverT] = useState<number | null>(null);

  useEffect(() => {
    const el = wrap.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => setWidth(Math.max(320, Math.round(entry.contentRect.width))));
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const innerW = width - MARGIN.left - MARGIN.right;
  const innerH = height - MARGIN.top - MARGIN.bottom;

  const { d0, d1, ticks } = useMemo(() => {
    const values = series.flatMap((s) => s.points.map((p) => p.v)).filter((v): v is number => v !== null);
    if (fixedDomain) {
      const lo = Math.min(fixedDomain[0], ...values);
      const hi = Math.max(fixedDomain[1], ...values);
      return niceDomain(lo, hi);
    }
    if (!values.length) return niceDomain(0, 1);
    return niceDomain(Math.min(...values), Math.max(...values));
  }, [series, fixedDomain]);

  const x = (t: number) => MARGIN.left + ((t - start) / Math.max(end - start, 1)) * innerW;
  const y = (v: number) => MARGIN.top + (1 - (v - d0) / (d1 - d0 || 1)) * innerH;

  const times = useMemo(
    () => Array.from(new Set(series.flatMap((s) => s.points.filter((p) => p.v !== null).map((p) => p.t)))).sort((a, b) => a - b),
    [series],
  );

  /** The pieces of a line (it breaks on a missing value or a long gap). */
  function segments(points: ChartSeries["points"]): { t: number; v: number }[][] {
    const parts: { t: number; v: number }[][] = [];
    let current: { t: number; v: number }[] = [];
    for (const p of points) {
      if (p.v === null || p.t < start || p.t > end) {
        if (current.length) parts.push(current);
        current = [];
        continue;
      }
      const last = current[current.length - 1];
      if (last && p.t - last.t > gapMs) {
        parts.push(current);
        current = [];
      }
      current.push({ t: p.t, v: p.v });
    }
    if (current.length) parts.push(current);
    return parts;
  }

  function path(part: { t: number; v: number }[]): string {
    return part.map((p, i) => `${i ? "L" : "M"}${x(p.t).toFixed(1)},${y(p.v).toFixed(1)}`).join("");
  }

  // The last value of each line, written at its end (labels pushed apart).
  const ends = series
    .map((s) => {
      const last = [...s.points].reverse().find((p) => p.v !== null && p.t >= start && p.t <= end);
      return last ? { s, last, y: y(last.v as number), labelY: y(last.v as number) } : null;
    })
    .filter((e): e is NonNullable<typeof e> => e !== null)
    .sort((a, b) => a.y - b.y);
  for (let i = 1; i < ends.length; i++) ends[i].labelY = Math.max(ends[i].labelY, ends[i - 1].labelY + 14);
  const overflow = ends.length ? ends[ends.length - 1].labelY - (MARGIN.top + innerH) : 0;
  if (overflow > 0) for (const e of ends) e.labelY -= overflow;

  function nearest(t: number): number | null {
    if (!times.length) return null;
    let lo = 0;
    let hi = times.length - 1;
    while (hi - lo > 1) {
      const mid = (lo + hi) >> 1;
      if (times[mid] < t) lo = mid;
      else hi = mid;
    }
    return Math.abs(times[lo] - t) <= Math.abs(times[hi] - t) ? times[lo] : times[hi];
  }

  function valueAt(s: ChartSeries, t: number): number | null {
    let best: { d: number; v: number | null } | null = null;
    for (const p of s.points) {
      const d = Math.abs(p.t - t);
      if (d <= gapMs / 2 && (!best || d < best.d)) best = { d, v: p.v };
    }
    return best?.v ?? null;
  }

  function onMove(e: React.PointerEvent<SVGSVGElement>) {
    const box = e.currentTarget.getBoundingClientRect();
    const px = ((e.clientX - box.left) / box.width) * width;
    if (px < MARGIN.left - 8 || px > MARGIN.left + innerW + 8) {
      setHoverT(null);
      return;
    }
    setHoverT(nearest(start + ((px - MARGIN.left) / innerW) * (end - start)));
  }

  const hoverX = hoverT === null ? null : x(hoverT);

  return (
    <div>
      <ul className="mb-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-slate-700" aria-label="Légende">
        {series.map((s) => (
          <li key={s.id} className="flex items-center gap-1.5">
            <span className="inline-block h-0.5 w-4 rounded" style={{ background: s.color }} />
            {s.name}
          </li>
        ))}
      </ul>
      <div ref={wrap} className="relative w-full">
        <svg
          width={width}
          height={height}
          viewBox={`0 0 ${width} ${height}`}
          role="img"
          aria-label={ariaLabel}
          className="block touch-none select-none"
          onPointerMove={onMove}
          onPointerLeave={() => setHoverT(null)}
        >
          {ticks.map((v) => (
            <g key={v}>
              <line x1={MARGIN.left} x2={MARGIN.left + innerW} y1={y(v)} y2={y(v)} stroke="#e2e8f0" strokeWidth={1} />
              <text x={MARGIN.left - 6} y={y(v) + 4} textAnchor="end" fontSize={11} fill="#64748b">
                {format(v)}
              </text>
            </g>
          ))}
          {timeTicks(start, end).map((t) => (
            <g key={t}>
              <line x1={x(t)} x2={x(t)} y1={MARGIN.top + innerH} y2={MARGIN.top + innerH + 4} stroke="#94a3b8" strokeWidth={1} />
              <text x={x(t)} y={MARGIN.top + innerH + 17} textAnchor="middle" fontSize={11} fill="#64748b">
                {tickText(t)}
              </text>
            </g>
          ))}
          <line x1={MARGIN.left} x2={MARGIN.left + innerW} y1={MARGIN.top + innerH} y2={MARGIN.top + innerH} stroke="#94a3b8" strokeWidth={1} />

          {series.map((s) => (
            <g key={s.id}>
              {segments(s.points).map((part) =>
                part.length === 1 ? (
                  <circle key={part[0].t} cx={x(part[0].t)} cy={y(part[0].v)} r={2} fill={s.color} />
                ) : (
                  <path key={part[0].t} d={path(part)} fill="none" stroke={s.color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
                ),
              )}
            </g>
          ))}

          {ends.map((e) => (
            <g key={e.s.id}>
              <line x1={x(e.last.t) + 3} y1={e.y} x2={MARGIN.left + innerW + 10} y2={e.labelY} stroke={e.s.color} strokeWidth={1} />
              <text x={MARGIN.left + innerW + 13} y={e.labelY + 4} fontSize={11} fill="#334155">
                {e.s.name.split(" ")[0]} · {format(e.last.v as number)}
              </text>
            </g>
          ))}

          {hoverX !== null && hoverT !== null && (
            <g>
              <line x1={hoverX} x2={hoverX} y1={MARGIN.top} y2={MARGIN.top + innerH} stroke="#334155" strokeWidth={1} />
              {series.map((s) => {
                const v = valueAt(s, hoverT);
                return v === null ? null : <circle key={s.id} cx={hoverX} cy={y(v)} r={4.5} fill={s.color} stroke="#fff" strokeWidth={2} />;
              })}
            </g>
          )}
        </svg>

        {hoverX !== null && hoverT !== null && (
          <div
            className="pointer-events-none absolute top-2 z-10 min-w-40 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs shadow-md"
            style={hoverX > width / 2 ? { right: width - hoverX + 10 } : { left: hoverX + 10 }}
          >
            <div className="font-semibold text-slate-900">{shortDateTime(new Date(hoverT).toISOString())}</div>
            {series.map((s) => {
              const v = valueAt(s, hoverT);
              return (
                <div key={s.id} className="mt-0.5 flex items-center justify-between gap-3 text-slate-700">
                  <span className="flex items-center gap-1.5">
                    <span className="inline-block h-0.5 w-3 rounded" style={{ background: s.color }} />
                    {s.name}
                  </span>
                  <span className="font-medium tabular-nums text-slate-900">{v === null ? "—" : format(v)}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
