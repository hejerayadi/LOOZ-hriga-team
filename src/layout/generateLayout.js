import * as turf from '@turf/turf'
import { toClosedRing, pointInRings, localBounds } from '../geo/projection.js'
import { mockHealthScore } from './mockHealth.js'

export const DEFAULT_PARAMS = {
  treeSpacing: 6,        // metres between trees along a row
  rowSpacing: 7,         // metres between rows
  pollinizerEveryNRows: 4, // every Nth row is the pollinizer variety (0 = none)
  setback: 3,            // keep trees this far inside the boundary
  rowAngle: 0,           // degrees clockwise from east/west rows
  autoOrient: true,      // let the engine pick the angle + lattice phase
  stagger: false,        // offset alternate rows (quincunx planting)
}

/**
 * Shrink the plot by the setback so nothing is planted on the fence line.
 * turf.buffer is geodesic, so this has to happen in lng/lat before we
 * project — a negative buffer in metres is exactly the agronomic headland.
 * Returns rings in local metres (a concave plot can split into several).
 */
export function buildPlantingArea(boundaryPoints, projection, setback) {
  const ring = toClosedRing(boundaryPoints)
  if (ring.length < 4) return { rings: [], areaM2: 0 }
  const poly = turf.polygon([ring])

  let planting = poly
  if (setback > 0) {
    let shrunk = null
    try {
      shrunk = turf.buffer(poly, -setback, { units: 'meters' })
    } catch {
      shrunk = null
    }
    // A setback larger than the plot's half-width erases it entirely; in that
    // case fall back to the raw boundary rather than silently planting nothing.
    if (shrunk && shrunk.geometry && turf.area(shrunk) > 1) planting = shrunk
  }

  const geom = planting.geometry
  const polys = geom.type === 'MultiPolygon' ? geom.coordinates : [geom.coordinates]
  const rings = []
  for (const p of polys) {
    for (const r of p) rings.push(r.map(([lng, lat]) => projection.toLocal({ lat, lng })))
  }
  return { rings, areaM2: turf.area(planting) }
}

function rotate(x, z, cos, sin) {
  return { u: x * cos + z * sin, v: -x * sin + z * cos }
}

function unrotate(u, v, cos, sin) {
  return { x: u * cos - v * sin, z: u * sin + v * cos }
}

/**
 * Core lattice fill: lay a rotated grid over the planting rings and keep the
 * nodes that land inside. `phaseU` / `phaseV` slide the whole lattice, which
 * is what lets the optimiser squeeze an extra row or column out of an
 * awkwardly shaped plot.
 */
function fillLattice(rings, params, angleDeg, phaseU, phaseV, collect) {
  const { treeSpacing, rowSpacing, stagger } = params
  const rad = (angleDeg * Math.PI) / 180
  const cos = Math.cos(rad)
  const sin = Math.sin(rad)

  const all = rings.flat()
  if (!all.length) return 0
  let minU = Infinity, maxU = -Infinity, minV = Infinity, maxV = -Infinity
  for (const p of all) {
    const { u, v } = rotate(p.x, p.z, cos, sin)
    if (u < minU) minU = u
    if (u > maxU) maxU = u
    if (v < minV) minV = v
    if (v > maxV) maxV = v
  }

  let count = 0
  let row = 0
  const startV = minV + phaseV * rowSpacing
  for (let v = startV; v <= maxV + 1e-6; v += rowSpacing, row++) {
    const offset = stagger && row % 2 === 1 ? treeSpacing / 2 : 0
    let col = 0
    for (let u = minU + phaseU * treeSpacing + offset; u <= maxU + 1e-6; u += treeSpacing, col++) {
      const { x, z } = unrotate(u, v, cos, sin)
      if (!pointInRings(x, z, rings)) continue
      count++
      if (collect) collect(x, z, row, col)
    }
  }
  return count
}

/**
 * Search for the orientation and lattice phase that fit the most trees.
 *
 * Angle and phase interact — a grid that looks bad at phase 0 can be the best
 * one once it is nudged half a spacing — so ranking angles at a single phase
 * picks losers. We score every angle as the better of two phases, keep a
 * shortlist, then run the full phase search on the finalists.
 * Row direction is symmetric, so 0-180 degrees covers every distinct layout.
 */
const norm180 = (a) => ((a % 180) + 180) % 180

/** Smallest angle between two row directions (rows are symmetric, so mod 180). */
function angleGap(a, b) {
  const d = Math.abs(norm180(a) - norm180(b))
  return Math.min(d, 180 - d)
}

/** Direction of the plot's longest edge - the way rows would naturally run. */
export function dominantEdgeAngle(ring) {
  let best = 0
  let bestLen = -1
  for (let i = 0; i < ring.length; i++) {
    const a = ring[i]
    const b = ring[(i + 1) % ring.length]
    const len = Math.hypot(b.x - a.x, b.z - a.z)
    if (len > bestLen) {
      bestLen = len
      best = norm180((Math.atan2(b.z - a.z, b.x - a.x) * 180) / Math.PI)
    }
  }
  return best
}

/**
 * Search for the orientation and lattice phase that fit the most trees.
 *
 * Angle and phase interact - a grid that looks bad at phase 0 can be the best
 * one once it is nudged half a spacing - so ranking angles at a single phase
 * picks losers. We score every angle as the better of two phases, keep a
 * shortlist, then run the full phase search on the finalists.
 * Row direction is symmetric, so 0-180 degrees covers every distinct layout.
 *
 * Maximum tree count is not the only thing that matters: skewed rows mean
 * awkward headlands and more turning for the tractor. So counts within
 * TIE_TOLERANCE of the best are treated as a tie and settled in favour of the
 * angle closest to the plot's longest edge. Rows only rotate when it actually
 * buys trees.
 */
const TIE_TOLERANCE = 0.01

function optimiseOrientation(rings, params, preferredAngle) {
  const score = (angle, phaseU, phaseV) => ({
    angle,
    phaseU,
    phaseV,
    count: fillLattice(rings, params, angle, phaseU, phaseV, null),
  })
  const bestOf = (angle) => {
    const a = score(angle, 0, 0)
    const b = score(angle, 0.5, 0.5)
    return a.count >= b.count ? a : b
  }
  const topN = (list, n) => [...list].sort((x, y) => y.count - x.count).slice(0, n)

  const coarse = []
  for (let a = 0; a < 180; a += 6) coarse.push(bestOf(a))

  const refined = []
  for (const c of topN(coarse, 5)) {
    for (let a = c.angle - 5; a <= c.angle + 5; a += 1.5) refined.push(bestOf(norm180(a)))
  }

  // Always keep the longest-edge direction, the unrotated grid and the user's
  // own angle in the running, so "auto" can never be worse than what they
  // would have picked by hand.
  const finalists = topN([...coarse, ...refined], 3)
  finalists.push(bestOf(preferredAngle), bestOf(0), bestOf(norm180(params.rowAngle)))

  const evaluated = []
  for (const f of finalists) {
    for (let pu = 0; pu < 1; pu += 0.25) {
      for (let pv = 0; pv < 1; pv += 0.25) evaluated.push(score(f.angle, pu, pv))
    }
  }

  const maxCount = Math.max(...evaluated.map((e) => e.count))
  const threshold = maxCount * (1 - TIE_TOLERANCE)
  let best = null
  for (const e of evaluated) {
    if (e.count < threshold) continue
    if (!best) {
      best = e
      continue
    }
    const gap = angleGap(e.angle, preferredAngle)
    const bestGap = angleGap(best.angle, preferredAngle)
    if (gap < bestGap - 0.001 || (Math.abs(gap - bestGap) <= 0.001 && e.count > best.count)) best = e
  }
  return best || { angle: preferredAngle, phaseU: 0.5, phaseV: 0.5, count: 0 }
}

/**
 * Generate the orchard layout.
 * Returns { trees, meta } where a tree is { id, x, z, variety, healthScore, row, col }.
 */
export function generateLayout(boundaryPoints, projection, params = DEFAULT_PARAMS) {
  const p = { ...DEFAULT_PARAMS, ...params }
  const empty = { trees: [], meta: { rows: 0, rowAngle: p.rowAngle, plantingAreaM2: 0, rings: [] } }
  if (!boundaryPoints || boundaryPoints.length < 3) return empty
  if (p.treeSpacing <= 0 || p.rowSpacing <= 0) return empty

  const { rings, areaM2 } = buildPlantingArea(boundaryPoints, projection, p.setback)
  if (!rings.length) return empty

  const preferredAngle = dominantEdgeAngle(rings[0])
  const chosen = p.autoOrient
    ? optimiseOrientation(rings, p, preferredAngle)
    : { angle: p.rowAngle, phaseU: 0.5, phaseV: 0.5 }

  const trees = []
  const rowsSeen = new Set()
  fillLattice(rings, p, chosen.angle, chosen.phaseU, chosen.phaseV, (x, z, row, col) => {
    rowsSeen.add(row)
    const n = p.pollinizerEveryNRows
    // Every Nth row carries the pollinizer variety. Offsetting by 1 keeps the
    // first row (usually the headland edge) as the main cash variety.
    const isPollinizer = n > 0 && (row + 1) % n === 0
    trees.push({
      id: `ai-${row}-${col}`,
      x,
      z,
      variety: isPollinizer ? 'pollinizer' : 'main',
      healthScore: mockHealthScore(x, z),
      row,
      col,
    })
  })

  return {
    trees,
    meta: {
      rows: rowsSeen.size,
      rowAngle: chosen.angle,
      plantingAreaM2: areaM2,
      rings,
      bounds: localBounds(rings.flat()),
    },
  }
}
