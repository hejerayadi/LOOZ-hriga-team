import { create } from 'zustand'
import {
  makeProjection,
  projectBoundary,
  plotAreaM2,
  plotPerimeterM,
  boundaryBBox,
  localBounds,
} from '../geo/projection.js'
import { generateLayout, DEFAULT_PARAMS } from '../layout/generateLayout.js'
import { mockHealthScore } from '../layout/mockHealth.js'
import { fetchElevationGrid } from '../data/elevation.js'
import { staticImageUrl } from '../data/satellite.js'

const TOKEN_KEY = 'orchard.mapboxToken'

export function storedToken() {
  const fromEnv = import.meta.env?.VITE_MAPBOX_TOKEN
  if (fromEnv && fromEnv.startsWith('pk.')) return fromEnv
  try {
    return localStorage.getItem(TOKEN_KEY) || ''
  } catch {
    return ''
  }
}

/** A demo plot in the almond country north of Kairouan, Tunisia (~4.5 ha). */
export const DEMO_PLOT = [
  { lat: 35.6999, lng: 10.09515 },
  { lat: 35.69985, lng: 10.09785 },
  { lat: 35.69865, lng: 10.098 },
  { lat: 35.6981, lng: 10.096 },
  { lat: 35.6989, lng: 10.0949 },
]

let manualCounter = 0

const EMPTY_PLOT = {
  projection: null,
  localBoundary: [],
  bounds: null,
  areaM2: 0,
  perimeterM: 0,
  bbox: null,
  groundBBox: null,
  groundBounds: null,
}

/** Grow a [minLng,minLat,maxLng,maxLat] box by a fraction of its own size. */
function padBBox(bbox, fraction) {
  const [minLng, minLat, maxLng, maxLat] = bbox
  const dx = (maxLng - minLng) * fraction
  const dy = (maxLat - minLat) * fraction
  return [minLng - dx, minLat - dy, maxLng + dx, maxLat + dy]
}

function derivePlot(boundary) {
  if (!boundary || boundary.length < 3) return { ...EMPTY_PLOT }

  const projection = makeProjection(boundary)
  const localBoundary = projectBoundary(boundary, projection)
  const bbox = boundaryBBox(boundary)

  // One padded box drives the ground mesh, the satellite texture and the
  // elevation grid. If they were derived separately the photo would drift out
  // of register with the terrain and the plot outline.
  const groundBBox = padBBox(bbox, 0.06)
  const [gMinLng, gMinLat, gMaxLng, gMaxLat] = groundBBox
  const groundCorners = [
    { lat: gMinLat, lng: gMinLng },
    { lat: gMinLat, lng: gMaxLng },
    { lat: gMaxLat, lng: gMaxLng },
    { lat: gMaxLat, lng: gMinLng },
  ].map((p) => projection.toLocal(p))

  return {
    projection,
    localBoundary,
    bounds: localBounds(localBoundary, 0),
    areaM2: plotAreaM2(boundary),
    perimeterM: plotPerimeterM(boundary),
    bbox,
    groundBBox,
    groundBounds: localBounds(groundCorners, 0),
  }
}

export const useStore = create((set, get) => ({
  token: storedToken(),
  setToken(token) {
    try {
      if (token) localStorage.setItem(TOKEN_KEY, token)
      else localStorage.removeItem(TOKEN_KEY)
    } catch {
      /* private browsing - keep it in memory only */
    }
    set({ token })
  },

  // --- plot -----------------------------------------------------------
  boundary: [],
  ...EMPTY_PLOT,

  // --- layout ---------------------------------------------------------
  params: { ...DEFAULT_PARAMS },
  trees: [],
  layoutMeta: null,
  mode: 'ai',
  brushVariety: 'main',
  manualEdits: 0,
  generating: false,

  // --- view -----------------------------------------------------------
  view: {
    showHealth: false,
    showSatellite: true,
    showTerrain: true,
    exaggeration: 1.5,
    showBoundary: true,
    showSetback: true,
    shadows: true,
    sunHour: 15,
  },
  terrain: { grid: null, status: 'idle', source: null, error: null },
  satellite: { url: null, status: 'idle' },

  setBoundary(boundary) {
    const plot = derivePlot(boundary)
    set({ boundary, ...plot, terrain: { grid: null, status: 'idle', source: null, error: null } })
    get().refreshSatellite()
    if (get().mode === 'ai') get().regenerate()
    else set({ trees: [], manualEdits: 0 })
  },

  setParam(key, value) {
    set((s) => ({ params: { ...s.params, [key]: value } }))
    if (get().mode === 'ai') get().regenerate()
  },

  setMode(mode) {
    set({ mode })
    if (mode === 'ai' && get().trees.length === 0) get().regenerate()
  },

  setBrushVariety(brushVariety) {
    set({ brushVariety })
  },

  regenerate() {
    const { boundary, projection, params } = get()
    if (!projection || boundary.length < 3) {
      set({ trees: [], layoutMeta: null, manualEdits: 0 })
      return
    }
    set({ generating: true })
    const { trees, meta } = generateLayout(boundary, projection, params)
    set({ trees, layoutMeta: meta, manualEdits: 0, generating: false })
  },

  addTreeAt(x, z, variety) {
    const v = variety || get().brushVariety
    const tree = {
      id: `m-${Date.now().toString(36)}-${manualCounter++}`,
      x,
      z,
      variety: v,
      healthScore: mockHealthScore(x, z),
    }
    set((s) => ({ trees: [...s.trees, tree], manualEdits: s.manualEdits + 1 }))
  },

  removeTree(id) {
    set((s) => ({ trees: s.trees.filter((t) => t.id !== id), manualEdits: s.manualEdits + 1 }))
  },

  clearTrees() {
    set((s) => ({ trees: [], manualEdits: s.manualEdits + 1 }))
  },

  setView(patch) {
    set((s) => ({ view: { ...s.view, ...patch } }))
  },

  refreshSatellite() {
    const { groundBBox, token } = get()
    if (!groundBBox || !token) {
      set({ satellite: { url: null, status: token ? 'idle' : 'no-token' } })
      return
    }
    // groundBBox is already padded; asking for more here would break alignment.
    const img = staticImageUrl(groundBBox, token, { padding: 0 })
    set({ satellite: { url: img?.url || null, status: img ? 'ready' : 'error', meta: img } })
  },

  async loadTerrain() {
    const { groundBBox, token, terrain } = get()
    if (!groundBBox || terrain.status === 'loading') return
    set({ terrain: { ...terrain, status: 'loading', error: null } })
    try {
      const grid = await fetchElevationGrid({ bbox: groundBBox, token, n: 64 })
      set({ terrain: { grid, status: 'ready', source: grid.source, error: null } })
    } catch (e) {
      set({ terrain: { grid: null, status: 'error', source: null, error: e.message || String(e) } })
    }
  },

  /** Replace the whole project (used by Load JSON). */
  loadProject({ boundary, params, trees, mode, view }) {
    const plot = derivePlot(boundary)
    set({
      boundary,
      ...plot,
      params: { ...DEFAULT_PARAMS, ...(params || {}) },
      trees: trees || [],
      mode: mode || 'manual',
      view: { ...get().view, ...(view || {}) },
      manualEdits: 0,
      layoutMeta: null,
      terrain: { grid: null, status: 'idle', source: null, error: null },
    })
    get().refreshSatellite()
  },

  reset() {
    set({
      boundary: [],
      ...EMPTY_PLOT,
      trees: [],
      layoutMeta: null,
      manualEdits: 0,
      terrain: { grid: null, status: 'idle', source: null, error: null },
      satellite: { url: null, status: 'idle' },
    })
  },
}))

/** Derived stats for the panel. */
export function selectStats(s) {
  const main = s.trees.filter((t) => t.variety === 'main').length
  const pollinizer = s.trees.length - main
  const { treeSpacing, rowSpacing } = s.params
  const footprint = s.trees.length * treeSpacing * rowSpacing
  const ha = s.areaM2 / 10000
  return {
    total: s.trees.length,
    main,
    pollinizer,
    pollinizerPct: s.trees.length ? (pollinizer / s.trees.length) * 100 : 0,
    areaHa: ha,
    areaM2: s.areaM2,
    perimeterM: s.perimeterM,
    plantingAreaM2: s.layoutMeta?.plantingAreaM2 ?? 0,
    densityPerHa: ha > 0 ? s.trees.length / ha : 0,
    coveragePct: s.areaM2 > 0 ? Math.min(100, (footprint / s.areaM2) * 100) : 0,
    rows: s.layoutMeta?.rows ?? 0,
    rowAngle: s.layoutMeta?.rowAngle ?? s.params.rowAngle,
  }
}
