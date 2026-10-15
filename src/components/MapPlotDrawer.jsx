import { useEffect, useRef, useState } from 'react'
import mapboxgl from 'mapbox-gl'
import MapboxDraw from '@mapbox/mapbox-gl-draw'
import 'mapbox-gl/dist/mapbox-gl.css'
import '@mapbox/mapbox-gl-draw/dist/mapbox-gl-draw.css'
import { useStore, DEMO_PLOT } from '../state/store.js'
import { toClosedRing } from '../geo/projection.js'

/** Draw ring -> the {lat,lng} list the store wants (closing point dropped). */
function ringToBoundary(ring) {
  const pts = ring.map(([lng, lat]) => ({ lat, lng }))
  const a = pts[0]
  const b = pts[pts.length - 1]
  if (pts.length > 1 && a.lat === b.lat && a.lng === b.lng) pts.pop()
  return pts
}

export default function MapPlotDrawer() {
  const token = useStore((s) => s.token)
  const boundary = useStore((s) => s.boundary)
  const areaM2 = useStore((s) => s.areaM2)
  const setBoundary = useStore((s) => s.setBoundary)

  const containerRef = useRef(null)
  const mapRef = useRef(null)
  const drawRef = useRef(null)
  const [ready, setReady] = useState(false)

  // Keep the newest boundary reachable from map callbacks without re-running
  // the map setup effect (which would tear the whole map down on every edit).
  const boundaryRef = useRef(boundary)
  boundaryRef.current = boundary

  useEffect(() => {
    if (!token || !containerRef.current) return

    mapboxgl.accessToken = token
    const start = boundary.length
      ? boundary[0]
      : { lat: DEMO_PLOT[0].lat, lng: DEMO_PLOT[0].lng }

    const map = new mapboxgl.Map({
      container: containerRef.current,
      style: 'mapbox://styles/mapbox/satellite-streets-v12',
      center: [start.lng, start.lat],
      zoom: 15.5,
      attributionControl: true,
    })
    mapRef.current = map

    const draw = new MapboxDraw({
      displayControlsDefault: false,
      controls: { polygon: true, trash: true },
      defaultMode: 'simple_select',
    })
    drawRef.current = draw

    map.addControl(new mapboxgl.NavigationControl({ visualizePitch: false }), 'top-right')
    map.addControl(draw, 'top-right')
    map.addControl(new mapboxgl.ScaleControl({ maxWidth: 120, unit: 'metric' }), 'bottom-right')

    // Only ever one plot: drop anything drawn earlier.
    const syncFromDraw = () => {
      const features = draw.getAll().features.filter((f) => f.geometry?.type === 'Polygon')
      if (!features.length) return
      const newest = features[features.length - 1]
      for (const f of features) if (f.id !== newest.id) draw.delete(f.id)
      const pts = ringToBoundary(newest.geometry.coordinates[0])
      if (pts.length >= 3) setBoundary(pts)
    }

    const onDelete = () => {
      if (!draw.getAll().features.length) setBoundary([])
    }

    map.on('draw.create', syncFromDraw)
    map.on('draw.update', syncFromDraw)
    map.on('draw.delete', onDelete)

    map.on('load', () => {
      setReady(true)
      const current = boundaryRef.current
      if (current.length >= 3) {
        draw.add({
          type: 'Feature',
          properties: {},
          geometry: { type: 'Polygon', coordinates: [toClosedRing(current)] },
        })
        fitTo(map, current)
      }
    })

    return () => {
      setReady(false)
      mapRef.current = null
      drawRef.current = null
      map.remove()
    }
    // Rebuilding the map on every boundary change would fight the draw tool,
    // so this intentionally only depends on the token.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token])

  const loadDemo = () => {
    setBoundary(DEMO_PLOT)
    const draw = drawRef.current
    const map = mapRef.current
    if (draw && map) {
      draw.deleteAll()
      draw.add({
        type: 'Feature',
        properties: {},
        geometry: { type: 'Polygon', coordinates: [toClosedRing(DEMO_PLOT)] },
      })
      fitTo(map, DEMO_PLOT)
    }
  }

  const clear = () => {
    drawRef.current?.deleteAll()
    setBoundary([])
  }

  const startDrawing = () => {
    drawRef.current?.changeMode('draw_polygon')
  }

  return (
    <>
      <div ref={containerRef} className="map-root" />
      <div className="map-overlay">
        <PlaceSearch token={token} map={mapRef} />
        <div className="hint">
          <h4>Draw your plot</h4>
          <p>
            Find your field, then trace its boundary. Click each corner and click the first
            point again to close the shape. Drag any vertex to adjust it.
          </p>
          {boundary.length >= 3 ? (
            <p style={{ color: 'var(--accent)' }}>
              Plot captured: <b>{(areaM2 / 10000).toFixed(2)} ha</b> ({Math.round(areaM2).toLocaleString()} m&sup2;),
              {' '}{boundary.length} corners. Open the <b>Design</b> tab to plant it.
            </p>
          ) : (
            <p>No plot yet. Draw one, or drop in the demo field to try the planner.</p>
          )}
          <div className="row" style={{ marginTop: 4 }}>
            <button className="primary" onClick={startDrawing} disabled={!ready}>
              {boundary.length >= 3 ? 'Redraw' : 'Draw plot'}
            </button>
            <button onClick={loadDemo} disabled={!ready}>Demo field</button>
            {boundary.length >= 3 && (
              <button className="danger" onClick={clear} disabled={!ready}>Clear</button>
            )}
          </div>
        </div>
      </div>
    </>
  )
}

function fitTo(map, points) {
  const b = new mapboxgl.LngLatBounds()
  for (const p of points) b.extend([p.lng, p.lat])
  map.fitBounds(b, { padding: 80, duration: 600 })
}

/**
 * Minimal Mapbox geocoder. The farmer needs to get to their field without
 * panning the planet, and this is a lot lighter than the full plugin.
 */
function PlaceSearch({ token, map }) {
  const [q, setQ] = useState('')
  const [results, setResults] = useState([])
  const [open, setOpen] = useState(false)

  useEffect(() => {
    if (q.trim().length < 3) {
      setResults([])
      return
    }
    const ctrl = new AbortController()
    const id = setTimeout(async () => {
      try {
        const url =
          'https://api.mapbox.com/search/geocode/v6/forward?q=' +
          encodeURIComponent(q) +
          '&limit=5&access_token=' +
          token
        const res = await fetch(url, { signal: ctrl.signal })
        if (!res.ok) return
        const json = await res.json()
        setResults(json.features || [])
        setOpen(true)
      } catch {
        /* aborted or offline - leave the previous results alone */
      }
    }, 350)
    return () => {
      clearTimeout(id)
      ctrl.abort()
    }
  }, [q, token])

  const pick = (f) => {
    const [lng, lat] = f.geometry.coordinates
    map.current?.flyTo({ center: [lng, lat], zoom: 16, duration: 1200 })
    setQ(f.properties?.name || '')
    setOpen(false)
    setResults([])
  }

  return (
    <div className="search">
      <input
        type="text"
        placeholder="Search for a place or address..."
        value={q}
        onChange={(e) => setQ(e.target.value)}
        onFocus={() => results.length && setOpen(true)}
      />
      {open && results.length > 0 && (
        <div className="results">
          {results.map((f) => (
            <button key={f.id} onClick={() => pick(f)}>
              {f.properties?.full_address || f.properties?.name}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
