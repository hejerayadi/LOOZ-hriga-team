/**
 * Mock health scores — a stand-in for the monitoring pillar.
 *
 * Real scores will come from sensors / NDVI. Until then we synthesise
 * something that *looks* like a real field: smooth stress patches (a dry
 * corner, a waterlogged dip) rather than salt-and-pepper noise, so the
 * health preview reads like a map instead of confetti.
 */

function hash2(ix, iz, seed) {
  let h = ix * 374761393 + iz * 668265263 + seed * 2147483647
  h = (h ^ (h >> 13)) * 1274126177
  return ((h ^ (h >> 16)) >>> 0) / 4294967295
}

function smooth(t) {
  return t * t * (3 - 2 * t)
}

/** Value noise in [0,1] at world position (x,z) with the given feature size. */
function valueNoise(x, z, scale, seed) {
  const px = x / scale
  const pz = z / scale
  const ix = Math.floor(px)
  const iz = Math.floor(pz)
  const fx = smooth(px - ix)
  const fz = smooth(pz - iz)
  const a = hash2(ix, iz, seed)
  const b = hash2(ix + 1, iz, seed)
  const c = hash2(ix, iz + 1, seed)
  const d = hash2(ix + 1, iz + 1, seed)
  return a * (1 - fx) * (1 - fz) + b * fx * (1 - fz) + c * (1 - fx) * fz + d * fx * fz
}

/** Health score in [0,1]. 1 = thriving, 0 = failing. */
export function mockHealthScore(x, z, seed = 1337) {
  const broad = valueNoise(x, z, 55, seed)
  const fine = valueNoise(x, z, 18, seed + 7)
  const speckle = hash2(Math.round(x * 13), Math.round(z * 13), seed + 99)
  let v = broad * 0.6 + fine * 0.28 + speckle * 0.12
  // Skew towards healthy: most of a well-run orchard is fine.
  v = Math.pow(v, 0.62)
  return Math.max(0, Math.min(1, v))
}

export function healthBand(score) {
  if (score >= 0.66) return 'healthy'
  if (score >= 0.4) return 'stressed'
  return 'critical'
}

export const HEALTH_COLORS = {
  healthy: '#3fa34d',
  stressed: '#e0a527',
  critical: '#cc3d33',
}
