import { lazy, Suspense, useEffect, useRef, useState } from 'react'
import { useStore, DEMO_PLOT } from './state/store.js'
import Sidebar from './components/Sidebar.jsx'
import { toProjectJSON, fromProjectJSON, toGeoJSON, toCSV, download } from './io/project.js'

// mapbox-gl and three are megabytes each and are never both on screen, so each
// view pulls its own chunk the first time it is opened.
const MapPlotDrawer = lazy(() => import('./components/MapPlotDrawer.jsx'))
const OrchardScene = lazy(() => import('./components/OrchardScene.jsx'))

function Loading({ what }) {
  return (
    <div className="empty">
      <p>
        <span className="loading-dot" />
        Loading {what}...
      </p>
    </div>
  )
}

export default function App() {
  const token = useStore((s) => s.token)
  const setToken = useStore((s) => s.setToken)
  const boundary = useStore((s) => s.boundary)
  const setBoundary = useStore((s) => s.setBoundary)
  const loadProject = useStore((s) => s.loadProject)
  const view = useStore((s) => s.view)
  const terrain = useStore((s) => s.terrain)
  const loadTerrain = useStore((s) => s.loadTerrain)
  const trees = useStore((s) => s.trees)

  const hasPlot = boundary.length >= 3
  const [tab, setTab] = useState('plot')
  const [skipMap, setSkipMap] = useState(false)
  const [error, setError] = useState(null)
  const fileRef = useRef(null)

  // Pull elevation the first time the farmer actually looks at the 3D view.
  useEffect(() => {
    if (tab === 'design' && hasPlot && view.showTerrain && terrain.status === 'idle') {
      loadTerrain()
    }
  }, [tab, hasPlot, view.showTerrain, terrain.status, loadTerrain])

  const saveProject = () => {
    const json = toProjectJSON(useStore.getState())
    download(`orchard-${new Date().toISOString().slice(0, 10)}.json`, JSON.stringify(json, null, 2))
  }

  const openProject = async (file) => {
    setError(null)
    try {
      const text = await file.text()
      loadProject(fromProjectJSON(JSON.parse(text)))
      setTab('design')
    } catch (e) {
      setError(e.message || 'Could not read that file.')
    }
  }

  const exportGeoJSON = () => {
    setError(null)
    try {
      const gj = toGeoJSON(useStore.getState())
      download(`orchard-${new Date().toISOString().slice(0, 10)}.geojson`, JSON.stringify(gj, null, 2), 'application/geo+json')
    } catch (e) {
      setError(e.message)
    }
  }

  const exportCSV = () => {
    setError(null)
    try {
      download(`planting-list-${new Date().toISOString().slice(0, 10)}.csv`, toCSV(useStore.getState()), 'text/csv')
    } catch (e) {
      setError(e.message)
    }
  }

  const useDemoPlot = () => {
    setBoundary(DEMO_PLOT)
    setTab('design')
  }

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <span className="dot" />
          Almond Orchard Planner
          <small>3D layout &amp; planting design</small>
        </div>

        <nav className="tabs">
          <button className={`tab ${tab === 'plot' ? 'active' : ''}`} onClick={() => setTab('plot')}>
            1. Plot
          </button>
          <button
            className={`tab ${tab === 'design' ? 'active' : ''}`}
            onClick={() => setTab('design')}
            disabled={!hasPlot}
            title={hasPlot ? '' : 'Draw a plot boundary first'}
          >
            2. Design
          </button>
        </nav>

        <div className="spacer" />

        {error && <span className="note err">{error}</span>}

        <div className="io">
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            style={{ display: 'none' }}
            onChange={(e) => {
              const f = e.target.files?.[0]
              if (f) openProject(f)
              e.target.value = ''
            }}
          />
          <button onClick={() => fileRef.current?.click()}>Open</button>
          <button onClick={saveProject} disabled={!hasPlot}>Save</button>
          <button onClick={exportGeoJSON} disabled={!trees.length}>GeoJSON</button>
          <button onClick={exportCSV} disabled={!trees.length}>CSV</button>
        </div>
      </header>

      <div className="body">
        <main className="stage">
          {tab === 'plot' ? (
            token ? (
              <Suspense fallback={<Loading what="the map" />}>
                <MapPlotDrawer />
              </Suspense>
            ) : skipMap ? (
              <NoMapPanel onDemo={useDemoPlot} onAddToken={() => setSkipMap(false)} hasPlot={hasPlot} />
            ) : (
              <TokenGate onSave={setToken} onSkip={() => setSkipMap(true)} />
            )
          ) : hasPlot ? (
            <Suspense fallback={<Loading what="the 3D view" />}>
              <OrchardScene />
            </Suspense>
          ) : (
            <div className="empty">
              <h2>No plot yet</h2>
              <p>Draw your field boundary on the map first.</p>
              <button className="primary" onClick={() => setTab('plot')}>Go to the map</button>
            </div>
          )}
        </main>
        <Sidebar />
      </div>
    </div>
  )
}

function TokenGate({ onSave, onSkip }) {
  const [value, setValue] = useState('')
  const valid = value.trim().startsWith('pk.')

  return (
    <div className="gate">
      <div className="gate-card">
        <h2>Connect a Mapbox token</h2>
        <p>
          The planner uses Mapbox to show your real field, to skin the 3D ground with a satellite
          photo of it, and to read the elevation under it. A free account covers far more than a
          season of planning.
        </p>
        <p>
          Create one at{' '}
          <a href="https://account.mapbox.com/access-tokens/" target="_blank" rel="noreferrer">
            account.mapbox.com
          </a>
          , then paste the public token (it starts with <code>pk.</code>) below. It is kept in this
          browser only. You can also put it in a <code>.env</code> file as{' '}
          <code>VITE_MAPBOX_TOKEN</code>.
        </p>
        <input
          type="text"
          placeholder="pk...."
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && valid && onSave(value.trim())}
        />
        <div className="row">
          <button className="primary" disabled={!valid} onClick={() => onSave(value.trim())}>
            Use this token
          </button>
          <button className="ghost" onClick={onSkip}>
            Skip for now
          </button>
        </div>
      </div>
    </div>
  )
}

function NoMapPanel({ onDemo, onAddToken, hasPlot }) {
  return (
    <div className="gate">
      <div className="gate-card">
        <h2>Working without a map</h2>
        <p>
          Drawing a real boundary needs a Mapbox token. Without one you can still try the layout
          engine and the whole 3D view on a demo field near Kairouan - you just get plain ground
          instead of a satellite photo, and elevation comes from open-elevation.com instead.
        </p>
        <p>You can also open a saved project from the toolbar.</p>
        <div className="row">
          <button className="primary" onClick={onDemo}>
            {hasPlot ? 'Reload demo field' : 'Use the demo field'}
          </button>
          <button className="ghost" onClick={onAddToken}>
            Add a token
          </button>
        </div>
      </div>
    </div>
  )
}
