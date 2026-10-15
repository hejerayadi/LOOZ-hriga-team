/**
 * Headless check of the geo + layout core (no browser, no Mapbox needed).
 * Run: npm run smoke
 */
import { makeProjection, plotAreaM2, projectBoundary, localBounds } from '../src/geo/projection.js'
import { generateLayout, DEFAULT_PARAMS } from '../src/layout/generateLayout.js'

let failures = 0
const check = (name, cond, detail = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`)
  if (!cond) failures++
}

// A ~300 m x 200 m rectangle near Kairouan, Tunisia.
const lat0 = 35.68, lng0 = 10.1
const mPerDegLat = 110946, mPerDegLng = 90430
const dLat = 200 / mPerDegLat, dLng = 300 / mPerDegLng
const rect = [
  { lat: lat0, lng: lng0 },
  { lat: lat0, lng: lng0 + dLng },
  { lat: lat0 + dLat, lng: lng0 + dLng },
  { lat: lat0 + dLat, lng: lng0 },
]

const proj = makeProjection(rect)
const area = plotAreaM2(rect)
check('area ~ 6 ha', Math.abs(area - 60000) / 60000 < 0.02, `got ${(area / 10000).toFixed(3)} ha`)

const local = projectBoundary(rect, proj)
const b = localBounds(local)
check('projected width ~300 m', Math.abs(b.width - 300) < 2, `got ${b.width.toFixed(1)} m`)
check('projected depth ~200 m', Math.abs(b.depth - 200) < 2, `got ${b.depth.toFixed(1)} m`)

// Round trip a corner through the projection.
const rt = proj.toLatLng(proj.toLocal(rect[2]))
check('round trip < 1 cm', Math.abs(rt.lat - rect[2].lat) * mPerDegLat < 0.01)

// Axis-aligned layout on a rectangle: the count should match hand arithmetic.
const params = { ...DEFAULT_PARAMS, treeSpacing: 6, rowSpacing: 7, setback: 3, autoOrient: false, rowAngle: 0 }
const { trees, meta } = generateLayout(rect, proj, params)
const usable = { w: 300 - 6, d: 200 - 6 } // 3 m setback each side
const expectRows = Math.floor(usable.d / 7) + 1
const expectCols = Math.floor(usable.w / 6) + 1
check('row count matches arithmetic', Math.abs(meta.rows - expectRows) <= 1, `got ${meta.rows}, expected ~${expectRows}`)
check('tree count matches arithmetic', Math.abs(trees.length - expectRows * expectCols) <= expectRows + expectCols,
  `got ${trees.length}, expected ~${expectRows * expectCols}`)

// Every tree must sit inside the setback envelope.
const inset = trees.every((t) => t.x > b.minX + 2.9 && t.x < b.maxX - 2.9 && t.z > b.minZ + 2.9 && t.z < b.maxZ - 2.9)
check('all trees respect the 3 m setback', inset)

// Nearest-neighbour distance must never beat the tighter of the two spacings.
let minD = Infinity
const sorted = [...trees].sort((a, c) => a.x - c.x)
for (let i = 0; i < sorted.length; i++) {
  for (let j = i + 1; j < sorted.length && sorted[j].x - sorted[i].x < 7; j++) {
    const d = Math.hypot(sorted[i].x - sorted[j].x, sorted[i].z - sorted[j].z)
    if (d < minD) minD = d
  }
}
check('no two trees closer than 6 m', minD > 5.99, `min spacing ${minD.toFixed(2)} m`)

// Pollinizer rule: every 4th row, and those rows are whole.
const polRows = new Set(trees.filter((t) => t.variety === 'pollinizer').map((t) => t.row))
check('pollinizer rows are every 4th', [...polRows].every((r) => (r + 1) % 4 === 0), `rows ${[...polRows].join(',')}`)
const pollinizerShare = trees.filter((t) => t.variety === 'pollinizer').length / trees.length
check('pollinizer share ~25%', Math.abs(pollinizerShare - 0.25) < 0.06, `got ${(pollinizerShare * 100).toFixed(1)}%`)

// Health scores are in range and spatially smooth (neighbours should correlate).
check('health scores in [0,1]', trees.every((t) => t.healthScore >= 0 && t.healthScore <= 1))

// The optimiser must never do worse than a fixed axis-aligned grid.
const auto = generateLayout(rect, proj, { ...params, autoOrient: true })
check('auto-orient >= fixed grid', auto.trees.length >= trees.length,
  `auto ${auto.trees.length} @ ${auto.meta.rowAngle.toFixed(1)}deg vs fixed ${trees.length}`)

// A diagonal plot is where orientation search should really pay off.
const diamond = [
  { lat: lat0, lng: lng0 },
  { lat: lat0 + dLat / 2, lng: lng0 + dLng },
  { lat: lat0 + dLat, lng: lng0 },
  { lat: lat0 + dLat / 2, lng: lng0 - dLng },
]
const dProj = makeProjection(diamond)
const dFixed = generateLayout(diamond, dProj, { ...params, autoOrient: false })
const dAuto = generateLayout(diamond, dProj, { ...params, autoOrient: true })
check('diamond: auto-orient >= fixed', dAuto.trees.length >= dFixed.trees.length,
  `auto ${dAuto.trees.length} @ ${dAuto.meta.rowAngle.toFixed(1)}deg vs fixed ${dFixed.trees.length}`)

// Degenerate input must not throw.
check('empty boundary returns nothing', generateLayout([], proj, params).trees.length === 0)
check('oversized setback still plants', generateLayout(rect, proj, { ...params, setback: 500 }).trees.length > 0)

const t0 = Date.now()
generateLayout(rect, proj, { ...params, autoOrient: true })
const ms = Date.now() - t0
check('auto-orient under 1.5 s', ms < 1500, `took ${ms} ms`)

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll checks passed')
process.exit(failures ? 1 : 0)
