import { toClosedRing } from '../geo/projection.js'

export const PROJECT_FORMAT = 'almond-orchard-planner/v1'

/** Full project snapshot -> plain JSON, reopenable later. */
export function toProjectJSON(state) {
  return {
    format: PROJECT_FORMAT,
    savedAt: new Date().toISOString(),
    plot: {
      boundaryPoints: state.boundary,
      soilZones: state.soilZones || [],
    },
    params: state.params,
    mode: state.mode,
    view: state.view,
    trees: state.trees.map((t) => ({
      id: t.id,
      x: round(t.x),
      z: round(t.z),
      variety: t.variety,
      healthScore: t.healthScore != null ? round(t.healthScore, 3) : undefined,
      row: t.row,
      col: t.col,
    })),
  }
}

export function fromProjectJSON(json) {
  if (!json || typeof json !== 'object') throw new Error('Not a project file.')
  const boundary = json.plot?.boundaryPoints ?? json.boundary
  if (!Array.isArray(boundary) || boundary.length < 3) {
    throw new Error('No plot boundary in this file.')
  }
  if (!boundary.every((p) => Number.isFinite(p?.lat) && Number.isFinite(p?.lng))) {
    throw new Error('Boundary points must have numeric lat/lng.')
  }
  const trees = Array.isArray(json.trees) ? json.trees : []
  if (!trees.every((t) => Number.isFinite(t?.x) && Number.isFinite(t?.z))) {
    throw new Error('Tree positions must have numeric x/z.')
  }
  return {
    boundary,
    params: json.params || {},
    mode: json.mode === 'ai' ? 'ai' : 'manual',
    view: json.view || {},
    trees: trees.map((t, i) => ({
      id: t.id || `t-${i}`,
      x: t.x,
      z: t.z,
      variety: t.variety === 'pollinizer' ? 'pollinizer' : 'main',
      healthScore: t.healthScore,
      row: t.row,
      col: t.col,
    })),
  }
}

/**
 * GeoJSON for the field team: the plot polygon plus a Point per tree in real
 * WGS84 lng/lat, so it drops straight into QGIS or a GPS planting app.
 */
export function toGeoJSON(state) {
  const { boundary, projection, trees, params } = state
  if (!projection || boundary.length < 3) throw new Error('Draw a plot first.')

  const features = [
    {
      type: 'Feature',
      properties: {
        kind: 'plot-boundary',
        treeSpacing_m: params.treeSpacing,
        rowSpacing_m: params.rowSpacing,
        setback_m: params.setback,
        treeCount: trees.length,
      },
      geometry: { type: 'Polygon', coordinates: [toClosedRing(boundary)] },
    },
    ...trees.map((t) => {
      const { lat, lng } = projection.toLatLng({ x: t.x, z: t.z })
      return {
        type: 'Feature',
        properties: {
          kind: 'tree',
          id: t.id,
          variety: t.variety,
          healthScore: t.healthScore != null ? round(t.healthScore, 3) : null,
          row: t.row ?? null,
          col: t.col ?? null,
        },
        geometry: { type: 'Point', coordinates: [round(lng, 7), round(lat, 7)] },
      }
    }),
  ]

  return { type: 'FeatureCollection', features }
}

/** Planting list for whoever is holding the clipboard in the field. */
export function toCSV(state) {
  const { projection, trees } = state
  if (!projection) throw new Error('Draw a plot first.')
  const rows = [['id', 'variety', 'lat', 'lng', 'x_m', 'z_m', 'row', 'health']]
  for (const t of trees) {
    const { lat, lng } = projection.toLatLng({ x: t.x, z: t.z })
    rows.push([
      t.id,
      t.variety,
      round(lat, 7),
      round(lng, 7),
      round(t.x, 2),
      round(t.z, 2),
      t.row ?? '',
      t.healthScore != null ? round(t.healthScore, 3) : '',
    ])
  }
  return rows.map((r) => r.join(',')).join('\n')
}

export function download(filename, text, type = 'application/json') {
  const blob = new Blob([text], { type })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

function round(v, digits = 2) {
  const f = Math.pow(10, digits)
  return Math.round(v * f) / f
}
