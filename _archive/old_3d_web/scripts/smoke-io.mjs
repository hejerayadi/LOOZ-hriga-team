/**
 * Headless check of save / load / export.
 * Run: npm run smoke
 */
import { makeProjection } from '../src/geo/projection.js'
import { generateLayout, DEFAULT_PARAMS } from '../src/layout/generateLayout.js'
import { toProjectJSON, fromProjectJSON, toGeoJSON, toCSV } from '../src/io/project.js'

let failures = 0
const check = (name, cond, detail = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`)
  if (!cond) failures++
}

const boundary = [
  { lat: 35.7012, lng: 10.0938 },
  { lat: 35.7009, lng: 10.0997 },
  { lat: 35.6975, lng: 10.1002 },
  { lat: 35.6966, lng: 10.0961 },
  { lat: 35.6988, lng: 10.0932 },
]
const projection = makeProjection(boundary)
const { trees, meta } = generateLayout(boundary, projection, DEFAULT_PARAMS)
const state = { boundary, projection, trees, params: DEFAULT_PARAMS, mode: 'ai', view: { showHealth: true } }

check('demo plot plants trees', trees.length > 100, `${trees.length} trees, ${meta.rows} rows`)

// --- project save / load -------------------------------------------------
const saved = JSON.parse(JSON.stringify(toProjectJSON(state)))
check('save produces the documented shape', Array.isArray(saved.plot.boundaryPoints) && Array.isArray(saved.trees))
check('plot carries soilZones', Array.isArray(saved.plot.soilZones))

const loaded = fromProjectJSON(saved)
check('boundary survives the round trip', loaded.boundary.length === boundary.length)
check('tree count survives', loaded.trees.length === trees.length)
const worstDrift = Math.max(
  ...loaded.trees.map((t, i) => Math.max(Math.abs(t.x - trees[i].x), Math.abs(t.z - trees[i].z))),
)
check('positions survive to 1 cm', worstDrift <= 0.01, `worst drift ${worstDrift.toFixed(4)} m`)
check('varieties survive', loaded.trees.every((t, i) => t.variety === trees[i].variety))
check('health survives', loaded.trees.every((t, i) => Math.abs(t.healthScore - trees[i].healthScore) < 0.001))

// --- bad input -----------------------------------------------------------
const rejects = (label, input) => {
  let threw = false
  try {
    fromProjectJSON(input)
  } catch {
    threw = true
  }
  check(`rejects ${label}`, threw)
}
rejects('null', null)
rejects('an empty object', {})
rejects('a 2-point boundary', { plot: { boundaryPoints: [{ lat: 1, lng: 1 }, { lat: 2, lng: 2 }] } })
rejects('non-numeric coordinates', { plot: { boundaryPoints: [{ lat: 'a', lng: 1 }, { lat: 2, lng: 2 }, { lat: 3, lng: 3 }] } })
rejects('trees without positions', { plot: { boundaryPoints: boundary }, trees: [{ id: 'x' }] })

// --- GeoJSON -------------------------------------------------------------
const gj = toGeoJSON(state)
check('GeoJSON is a FeatureCollection', gj.type === 'FeatureCollection')
check('one boundary + one point per tree', gj.features.length === trees.length + 1)
check('first feature is the plot polygon', gj.features[0].geometry.type === 'Polygon')
check('plot ring is closed', (() => {
  const r = gj.features[0].geometry.coordinates[0]
  return r[0][0] === r[r.length - 1][0] && r[0][1] === r[r.length - 1][1]
})())

const treeFeatures = gj.features.slice(1)
check('all trees are Points', treeFeatures.every((f) => f.geometry.type === 'Point'))
check('coordinates are lng,lat in range', treeFeatures.every((f) => {
  const [lng, lat] = f.geometry.coordinates
  return lng > 10.09 && lng < 10.101 && lat > 35.696 && lat < 35.702
}))
check('varieties are carried as properties', treeFeatures.some((f) => f.properties.variety === 'pollinizer'))

// Reproject the exported points and confirm they land back on the same trees.
const backDrift = Math.max(
  ...treeFeatures.map((f, i) => {
    const [lng, lat] = f.geometry.coordinates
    const p = projection.toLocal({ lat, lng })
    return Math.max(Math.abs(p.x - trees[i].x), Math.abs(p.z - trees[i].z))
  }),
)
check('exported lng/lat reprojects to within 2 cm', backDrift < 0.02, `worst ${backDrift.toFixed(4)} m`)

// --- CSV -----------------------------------------------------------------
const csv = toCSV(state).split('\n')
check('CSV has a header plus a row per tree', csv.length === trees.length + 1)
check('CSV header is the documented one', csv[0] === 'id,variety,lat,lng,x_m,z_m,row,health')
check('CSV rows have 8 columns', csv.slice(1).every((r) => r.split(',').length === 8))

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll checks passed')
process.exit(failures ? 1 : 0)
