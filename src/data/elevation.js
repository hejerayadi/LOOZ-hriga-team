/**
 * Real elevation for the plot, as an n x n grid of metres.
 *
 * Two providers, tried in order:
 *  1. Mapbox Terrain-RGB tiles - needs the token we already have, ~5 m/px,
 *     CORS-friendly, and fast because it is just a couple of PNGs.
 *  2. open-elevation.com - no key, but rate limited and often slow, so it is
 *     the fallback and we ask it for a coarser grid.
 * If both fail the caller gets an error and the ground stays flat.
 */

const TERRAIN_TILESETS = ['mapbox.mapbox-terrain-dem-v1', 'mapbox.terrain-rgb']

function lngToTileX(lng, z) {
  return ((lng + 180) / 360) * Math.pow(2, z)
}

function latToTileY(lat, z) {
  const r = (lat * Math.PI) / 180
  return ((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * Math.pow(2, z)
}

function decodeTerrainRGB(r, g, b) {
  return -10000 + (r * 256 * 256 + g * 256 + b) * 0.1
}

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = 'anonymous'
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error('tile request failed'))
    img.src = url
  })
}

/** Stitch the terrain tiles covering bbox into one canvas we can sample. */
async function loadTerrainMosaic(bbox, token, tileset) {
  const [minLng, minLat, maxLng, maxLat] = bbox
  // Zoom 15 is the max Mapbox serves for terrain; drop down if the plot spans
  // too many tiles to be worth fetching.
  let z = 15
  let x0, x1, y0, y1
  for (; z >= 10; z--) {
    x0 = Math.floor(lngToTileX(minLng, z))
    x1 = Math.floor(lngToTileX(maxLng, z))
    y0 = Math.floor(latToTileY(maxLat, z))
    y1 = Math.floor(latToTileY(minLat, z))
    if ((x1 - x0 + 1) * (y1 - y0 + 1) <= 9) break
  }

  const TILE = 512
  const cols = x1 - x0 + 1
  const rows = y1 - y0 + 1
  const canvas = document.createElement('canvas')
  canvas.width = cols * TILE
  canvas.height = rows * TILE
  const ctx = canvas.getContext('2d', { willReadFrequently: true })

  const jobs = []
  for (let tx = x0; tx <= x1; tx++) {
    for (let ty = y0; ty <= y1; ty++) {
      const url = `https://api.mapbox.com/v4/${tileset}/${z}/${tx}/${ty}@2x.pngraw?access_token=${token}`
      jobs.push(
        loadImage(url).then((img) => ctx.drawImage(img, (tx - x0) * TILE, (ty - y0) * TILE, TILE, TILE)),
      )
    }
  }
  await Promise.all(jobs)

  const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data
  return {
    sample(lng, lat) {
      const px = (lngToTileX(lng, z) - x0) * TILE
      const py = (latToTileY(lat, z) - y0) * TILE
      const ix = Math.max(0, Math.min(canvas.width - 1, Math.round(px)))
      const iy = Math.max(0, Math.min(canvas.height - 1, Math.round(py)))
      const o = (iy * canvas.width + ix) * 4
      return decodeTerrainRGB(data[o], data[o + 1], data[o + 2])
    },
  }
}

function gridPoints(bbox, n) {
  const [minLng, minLat, maxLng, maxLat] = bbox
  const pts = []
  for (let row = 0; row < n; row++) {
    // Row 0 is the north edge, matching the north = -z convention of the scene.
    const lat = maxLat - ((maxLat - minLat) * row) / (n - 1)
    for (let col = 0; col < n; col++) {
      const lng = minLng + ((maxLng - minLng) * col) / (n - 1)
      pts.push({ lat, lng })
    }
  }
  return pts
}

async function fromMapbox(bbox, token, n) {
  let lastErr
  for (const tileset of TERRAIN_TILESETS) {
    try {
      const mosaic = await loadTerrainMosaic(bbox, token, tileset)
      const values = new Float32Array(n * n)
      gridPoints(bbox, n).forEach((p, i) => {
        values[i] = mosaic.sample(p.lng, p.lat)
      })
      const label = tileset.includes('dem') ? 'Mapbox Terrain DEM' : 'Mapbox Terrain-RGB'
      return { values, source: label }
    } catch (e) {
      lastErr = e
    }
  }
  throw lastErr || new Error('no terrain tileset available')
}

async function fromOpenElevation(bbox, n, signal) {
  const locations = gridPoints(bbox, n).map((p) => ({ latitude: p.lat, longitude: p.lng }))
  const res = await fetch('https://api.open-elevation.com/api/v1/lookup', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ locations }),
    signal,
  })
  if (!res.ok) throw new Error('open-elevation returned ' + res.status)
  const json = await res.json()
  const values = new Float32Array(n * n)
  json.results.forEach((r, i) => {
    values[i] = r.elevation
  })
  return { values, source: 'open-elevation.com' }
}

/** Bilinear resample of an n x n grid up to m x m. */
function resample(values, n, m) {
  const out = new Float32Array(m * m)
  for (let r = 0; r < m; r++) {
    const fy = (r / (m - 1)) * (n - 1)
    const y0 = Math.floor(fy)
    const y1 = Math.min(n - 1, y0 + 1)
    const ty = fy - y0
    for (let c = 0; c < m; c++) {
      const fx = (c / (m - 1)) * (n - 1)
      const x0 = Math.floor(fx)
      const x1 = Math.min(n - 1, x0 + 1)
      const tx = fx - x0
      const a = values[y0 * n + x0] * (1 - tx) + values[y0 * n + x1] * tx
      const b = values[y1 * n + x0] * (1 - tx) + values[y1 * n + x1] * tx
      out[r * m + c] = a * (1 - ty) + b * ty
    }
  }
  return out
}

export async function fetchElevationGrid({ bbox, token, n = 48, signal }) {
  let result = null
  if (token) {
    try {
      result = await fromMapbox(bbox, token, n)
    } catch {
      result = null
    }
  }
  if (!result) {
    // open-elevation is slower and rate limited, so ask for less and interpolate.
    const coarse = 16
    const r = await fromOpenElevation(bbox, coarse, signal)
    result = { values: resample(r.values, coarse, n), source: r.source }
  }

  const { values, source } = result
  let min = Infinity
  let max = -Infinity
  let sum = 0
  for (const v of values) {
    if (v < min) min = v
    if (v > max) max = v
    sum += v
  }
  const mean = sum / values.length
  // Store heights relative to the mean so the scene sits around y = 0 whatever
  // the plot's real altitude is.
  const relative = new Float32Array(values.length)
  for (let i = 0; i < values.length; i++) relative[i] = values[i] - mean

  return { n, values: relative, min, max, mean, relief: max - min, source }
}

/** Bilinear height lookup in local metres. Grid row 0 is the north (min z) edge. */
export function sampleElevation(grid, bounds, x, z) {
  if (!grid) return 0
  const { n, values } = grid
  const fx = ((x - bounds.minX) / bounds.width) * (n - 1)
  const fz = ((z - bounds.minZ) / bounds.depth) * (n - 1)
  const cx = Math.max(0, Math.min(n - 1, fx))
  const cz = Math.max(0, Math.min(n - 1, fz))
  const x0 = Math.floor(cx)
  const z0 = Math.floor(cz)
  const x1 = Math.min(n - 1, x0 + 1)
  const z1 = Math.min(n - 1, z0 + 1)
  const tx = cx - x0
  const tz = cz - z0
  const a = values[z0 * n + x0] * (1 - tx) + values[z0 * n + x1] * tx
  const b = values[z1 * n + x0] * (1 - tx) + values[z1 * n + x1] * tx
  return a * (1 - tz) + b * tz
}
