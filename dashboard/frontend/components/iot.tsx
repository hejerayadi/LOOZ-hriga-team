// Small pieces of the sensor pages: state of a box, level, stress bar,
// pack, plan of the orchard. Texts in French (lib/labels.ts).
import { BOX_STATUS, LEVEL, label } from "@/lib/labels";
import { date } from "@/lib/format";
import type { Box, Pack, Point, Tree, Zone } from "@/lib/types";

const STATUS_STYLE: Record<string, { chip: string; dot: string }> = {
  online: { chip: "bg-emerald-50 text-emerald-800 ring-emerald-200", dot: "bg-emerald-500" },
  sensor_problem: { chip: "bg-amber-50 text-amber-800 ring-amber-200", dot: "bg-amber-500" },
  offline: { chip: "bg-rose-50 text-rose-800 ring-rose-200", dot: "bg-rose-500" },
  waiting: { chip: "bg-sky-50 text-sky-800 ring-sky-200", dot: "bg-sky-500" },
  installed: { chip: "bg-slate-100 text-slate-700 ring-slate-200", dot: "bg-slate-400" },
};

/** Fill colour of a box on the plan (same meaning as the chips). */
export const STATUS_COLOR: Record<string, string> = {
  online: "#10b981",
  sensor_problem: "#f59e0b",
  offline: "#f43f5e",
  waiting: "#0ea5e9",
  installed: "#94a3b8",
};

export function StatusBadge({ status }: { status: string }) {
  const style = STATUS_STYLE[status] ?? STATUS_STYLE.installed;
  return (
    <span className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ${style.chip}`}>
      <span className={`h-2 w-2 rounded-full ${style.dot}`} />
      {label(BOX_STATUS, status)}
    </span>
  );
}

const LEVEL_STYLE: Record<string, string> = {
  ok: "bg-emerald-100 text-emerald-800",
  info: "bg-blue-100 text-blue-800",
  watch: "bg-yellow-100 text-yellow-800",
  warning: "bg-orange-100 text-orange-800",
  critical: "bg-red-600 text-white",
  sensor: "bg-slate-200 text-slate-800",
};

export function LevelBadge({ level }: { level: string | null }) {
  if (!level) return <span className="text-slate-400">—</span>;
  return (
    <span className={`inline-block whitespace-nowrap rounded-md px-2 py-0.5 text-xs font-semibold ${LEVEL_STYLE[level] ?? LEVEL_STYLE.sensor}`}>
      {label(LEVEL, level)}
    </span>
  );
}

/** A stress index 0–100 as a number and a coloured bar. */
export function StressBar({ value, suspended }: { value: number | null; suspended?: boolean }) {
  if (value === null) {
    return <span className="text-xs text-slate-400">{suspended ? "suspendu" : "—"}</span>;
  }
  const colour = value >= 80 ? "bg-red-600" : value >= 60 ? "bg-orange-500" : value >= 40 ? "bg-yellow-400" : "bg-emerald-500";
  return (
    <div className="flex items-center gap-2">
      <span className="w-7 text-right text-sm font-semibold tabular-nums text-slate-900">{value}</span>
      <div className="h-2 w-16 rounded-full bg-slate-100">
        <div className={`h-2 rounded-full ${colour}`} style={{ width: `${Math.max(3, Math.min(100, value))}%` }} />
      </div>
    </div>
  );
}

/** "Payant · 4 boîtiers" + end date, or "Gratuit", or "Payant, expiré". */
export function PackText({ pack, compact = false }: { pack: Pack; compact?: boolean }) {
  if (pack.plan === "free" || !pack.plan) return <span className="text-slate-600">Gratuit</span>;
  const boxes = pack.nodes ? ` · ${pack.nodes} boîtier${pack.nodes > 1 ? "s" : ""}` : "";
  if (!pack.active) {
    return (
      <span className="text-rose-700">
        Payant, expiré{pack.ends_at ? ` le ${date(pack.ends_at)}` : ""}
      </span>
    );
  }
  return (
    <span>
      <span className="font-medium text-emerald-800">Payant{boxes}</span>
      {pack.ends_at && (
        <span className={compact ? "block text-xs text-slate-500" : "text-slate-500"}>
          {compact ? "" : " · "}jusqu&apos;au {date(pack.ends_at)}
        </span>
      )}
    </span>
  );
}

function bounds(points: Point[]) {
  const xs = points.map((p) => p.x);
  const zs = points.map((p) => p.z);
  return { minX: Math.min(...xs), maxX: Math.max(...xs), minZ: Math.min(...zs), maxZ: Math.max(...zs) };
}

const path = (pts: Point[]) => pts.map((p) => `${p.x},${p.z}`).join(" ");

/**
 * The plan of the orchard seen from above, north at the top (x = east,
 * z = south, in metres): outline, zones with their letter, trees, boxes
 * coloured by their state.
 */
export function OrchardPlan({ outline, zones, trees, boxes }: { outline: Point[]; zones: Zone[]; trees: Tree[]; boxes: Box[] }) {
  const all = [...outline, ...zones.flatMap((z) => z.boundary)];
  if (all.length < 3) return <p className="text-sm text-slate-400">Pas de plan.</p>;
  const b = bounds(all);
  const size = Math.max(b.maxX - b.minX, b.maxZ - b.minZ, 10);
  const pad = size * 0.08;
  const font = size / 16;
  const treeR = Math.max(size / 140, 0.6);
  const boxR = Math.max(size / 55, 1.4);
  return (
    <svg
      viewBox={`${b.minX - pad} ${b.minZ - pad - font} ${b.maxX - b.minX + 2 * pad} ${b.maxZ - b.minZ + 2 * pad + font}`}
      className="h-56 w-full"
      role="img"
      aria-label="Plan du verger"
    >
      <text x={b.minX - pad / 2} y={b.minZ - pad / 2} fontSize={font * 0.7} fill="#64748b">
        Nord ↑
      </text>
      {zones.map((z) => {
        const zb = bounds(z.boundary.length ? z.boundary : outline);
        return (
          <g key={z.id}>
            <polygon points={path(z.boundary)} fill={z.color ?? "#cbd5e1"} fillOpacity={0.35} stroke={z.color ?? "#94a3b8"} strokeWidth={size / 300} />
            <text x={(zb.minX + zb.maxX) / 2} y={zb.minZ + font * 1.05} fontSize={font} fontWeight={700} textAnchor="middle" fill="#334155">
              {z.letter}
            </text>
          </g>
        );
      })}
      <polygon points={path(outline)} fill="none" stroke="#334155" strokeWidth={size / 200} />
      {trees.map((t) => (
        <circle key={t.code} cx={t.x} cy={t.z} r={treeR} fill="#15803d" />
      ))}
      {boxes
        .filter((x) => x.position_x !== null && x.position_z !== null)
        .map((x) => (
          <g key={x.node_id}>
            <rect
              x={(x.position_x as number) - boxR}
              y={(x.position_z as number) - boxR}
              width={boxR * 2}
              height={boxR * 2}
              rx={boxR / 3}
              fill={STATUS_COLOR[x.status] ?? "#94a3b8"}
              stroke="#fff"
              strokeWidth={boxR / 4}
            />
            <text x={x.position_x as number} y={(x.position_z as number) + boxR + font * 0.75} fontSize={font * 0.55} textAnchor="middle" fill="#334155">
              {x.device_code}
            </text>
          </g>
        ))}
    </svg>
  );
}
