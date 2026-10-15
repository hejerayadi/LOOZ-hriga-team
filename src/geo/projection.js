import * as turf from '@turf/turf'

/**
 * Local tangent-plane projection.
 *
 * We anchor a flat x/z metre grid at the centroid of the drawn plot:
 *   +x = east, -z = north  (so the default three.js camera, looking down -z,
 *   is looking north across the field).
 *
 * Over a field-sized area (< ~2 km) an equirectangular approximation is
 * accurate to a few centimetres, which is well under a tree's canopy radius.
 * The metres-per-degree scale factors are measured with turf at the plot's
 * own latitude rather than hard-coded, so the grid stays true anywhere.
 */
export function makeProjection(boundaryPoints) {
  const ring = toClosedRing(boundaryPoints)
  const poly = turf.polygon([ring])
  const [lng0, lat0] = turf.centroid(poly).geometry.coordinates

  // Measure the local scale with turf: 0.01 deg baseline, converted to m/deg.
  const mPerDegLat =
    turf.distance([lng0, lat0 - 0.005], [lng0, lat0 + 0.005], { units: 'meters' }) / 0.01
  const mPerDegLng =
    turf.distance([lng0 - 0.005, lat0], [lng0 + 0.005, lat0], { units: 'meters' }) / 0.01

  return {
    origin: { lat: lat0, lng: lng0 },
    mPerDegLat,
    mPerDegLng,
    toLocal({ lat, lng }) {
      return { x: (lng - lng0) * mPerDegLng, z: -(lat - lat0) * mPerDegLat }
    },
    toLatLng({ x, z }) {
      return { lat: lat0 - z / mPerDegLat, lng: lng0 + x / mPerDegLng }
    },
  }
}

/** Boundary points -> array of {x,z} in metres. */
export function projectBoundary(boundaryPoints, projection) {
  return boundaryPoints.map((p) => projection.toLocal(p))
}

/** GeoJSON ring [[lng,lat],...] closed. Accepts {lat,lng} objects. */
export function toClosedRing(points) {
  const ring = points.map((p) => [p.lng, p.lat])
  const first = ring[0]
  const last = ring[ring.length - 1]
  if (!first) return ring
  if (first[0] !== last[0] || first[1] !== last[1]) ring.push([first[0], first[1]])
  return ring
}

/** Plot area in square metres (geodesic, via turf). */
export function plotAreaM2(boundaryPoints) {
  if (!boundaryPoints || boundaryPoints.length < 3) return 0
  return turf.area(turf.polygon([toClosedRing(boundaryPoints)]))
}

/** Plot perimeter in metres. */
export function plotPerimeterM(boundaryPoints) {
  if (!boundaryPoints || boundaryPoints.length < 3) return 0
  return turf.length(turf.lineString(toClosedRing(boundaryPoints)), { units: 'meters' })
}

/** [minLng, minLat, maxLng, maxLat] */
export function boundaryBBox(boundaryPoints) {
  return turf.bbox(turf.polygon([toClosedRing(boundaryPoints)]))
}

/** Axis-aligned bounds of projected points, padded by `pad` metres. */
export function localBounds(localPoints, pad = 0) {
  let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity
  for (const p of localPoints) {
    if (p.x < minX) minX = p.x
    if (p.x > maxX) maxX = p.x
    if (p.z < minZ) minZ = p.z
    if (p.z > maxZ) maxZ = p.z
  }
  return {
    minX: minX - pad,
    maxX: maxX + pad,
    minZ: minZ - pad,
    maxZ: maxZ + pad,
    width: maxX - minX + pad * 2,
    depth: maxZ - minZ + pad * 2,
    centerX: (minX + maxX) / 2,
    centerZ: (minZ + maxZ) / 2,
  }
}

/**
 * Planar even-odd point-in-polygon over local metre rings.
 * Used instead of turf here because turf's predicate expects lng/lat degrees;
 * once we are in metres a plain ray cast is both correct and much faster
 * (it runs once per candidate tree, which can be tens of thousands).
 */
export function pointInRings(x, z, rings) {
  let inside = false
  for (const ring of rings) {
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      const xi = ring[i].x, zi = ring[i].z
      const xj = ring[j].x, zj = ring[j].z
      if (zi > z !== zj > z && x < ((xj - xi) * (z - zi)) / (zj - zi) + xi) inside = !inside
    }
  }
  return inside
}
