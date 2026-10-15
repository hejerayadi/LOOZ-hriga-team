/**
 * Mapbox Static Images API -> a satellite photo of exactly the plot's bbox,
 * ready to use as the ground texture.
 *
 * The API fits the requested bbox *inside* the image, letterboxing if the
 * aspect ratios disagree. Web Mercator stretches latitude, so we compute the
 * bbox aspect in mercator space and size the image to match; otherwise the
 * photo ends up padded and the ground texture is offset from the real field.
 */
const MAX_PX = 1280

function mercatorY(lat) {
  const clamped = Math.max(-85.05, Math.min(85.05, lat))
  return (Math.log(Math.tan(Math.PI / 4 + (clamped * Math.PI) / 360)) * 180) / Math.PI
}

export function staticImageUrl(bbox, token, { style = 'satellite-v9', padding = 0 } = {}) {
  if (!token || !bbox) return null
  let [minLng, minLat, maxLng, maxLat] = bbox

  if (padding > 0) {
    const padLng = (maxLng - minLng) * padding
    const padLat = (maxLat - minLat) * padding
    minLng -= padLng; maxLng += padLng; minLat -= padLat; maxLat += padLat
  }

  const dx = maxLng - minLng
  const dy = mercatorY(maxLat) - mercatorY(minLat)
  if (dx <= 0 || dy <= 0) return null

  const aspect = dx / dy
  let width = MAX_PX
  let height = Math.round(width / aspect)
  if (height > MAX_PX) {
    height = MAX_PX
    width = Math.round(height * aspect)
  }
  width = Math.max(1, Math.min(MAX_PX, width))
  height = Math.max(1, Math.min(MAX_PX, height))

  const bboxStr = [minLng, minLat, maxLng, maxLat].map((v) => v.toFixed(6)).join(',')
  const url =
    `https://api.mapbox.com/styles/v1/mapbox/${style}/static/[${bboxStr}]/${width}x${height}` +
    `?access_token=${token}&attribution=false&logo=false`

  return { url, width, height, bbox: [minLng, minLat, maxLng, maxLat] }
}
