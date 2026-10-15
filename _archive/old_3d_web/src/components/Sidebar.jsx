import { useShallow } from 'zustand/react/shallow'
import { useStore, selectStats } from '../state/store.js'
import { VARIETY_COLORS } from '../layout/varieties.js'
import { HEALTH_COLORS } from '../layout/mockHealth.js'

function Slider({ label, unit, value, min, max, step, onChange, disabled }) {
  return (
    <div className="field">
      <label>
        <span>{label}</span>
        <b>
          {value}
          {unit ? ` ${unit}` : ''}
        </b>
      </label>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(parseFloat(e.target.value))}
      />
    </div>
  )
}

function Toggle({ label, checked, onChange, disabled }) {
  return (
    <label className="toggle">
      <input type="checkbox" checked={checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
      <span>{label}</span>
    </label>
  )
}

export default function Sidebar() {
  const hasPlot = useStore((s) => s.boundary.length >= 3)
  const params = useStore((s) => s.params)
  const setParam = useStore((s) => s.setParam)
  const mode = useStore((s) => s.mode)
  const setMode = useStore((s) => s.setMode)
  const brushVariety = useStore((s) => s.brushVariety)
  const setBrushVariety = useStore((s) => s.setBrushVariety)
  const regenerate = useStore((s) => s.regenerate)
  const clearTrees = useStore((s) => s.clearTrees)
  const manualEdits = useStore((s) => s.manualEdits)
  const view = useStore((s) => s.view)
  const setView = useStore((s) => s.setView)
  const terrain = useStore((s) => s.terrain)
  const loadTerrain = useStore((s) => s.loadTerrain)
  const satellite = useStore((s) => s.satellite)
  const trees = useStore((s) => s.trees)
  // selectStats builds a fresh object each call; without a shallow compare
  // zustand v5 would see a new snapshot every render and spin.
  const stats = useStore(useShallow(selectStats))

  return (
    <aside className="sidebar">
      <section className="section">
        <h3>Planting mode</h3>
        <div className="seg">
          <button className={mode === 'ai' ? 'on' : ''} onClick={() => setMode('ai')}>
            AI layout
          </button>
          <button className={mode === 'manual' ? 'on' : ''} onClick={() => setMode('manual')}>
            Manual
          </button>
        </div>
        {mode === 'manual' ? (
          <>
            <div className="field" style={{ marginTop: 12 }}>
              <label>
                <span>Planting</span>
              </label>
              <div className="seg">
                <button className={brushVariety === 'main' ? 'on' : ''} onClick={() => setBrushVariety('main')}>
                  Main
                </button>
                <button
                  className={brushVariety === 'pollinizer' ? 'on' : ''}
                  onClick={() => setBrushVariety('pollinizer')}
                >
                  Pollinizer
                </button>
              </div>
            </div>
            <p className="note">
              Click bare ground inside the fence to plant, click a tree to pull it out. The AI
              layout stays put until you regenerate it.
            </p>
            <div className="row" style={{ marginTop: 10 }}>
              <button className="danger" onClick={clearTrees} disabled={!trees.length}>
                Clear all trees
              </button>
            </div>
          </>
        ) : (
          <p className="note" style={{ marginTop: 10 }}>
            The engine fills the plot with the spacing below and picks the row direction that fits
            the most trees.
          </p>
        )}
      </section>

      <section className="section">
        <h3>Layout</h3>
        <Slider
          label="Tree spacing (in row)"
          unit="m"
          value={params.treeSpacing}
          min={3}
          max={12}
          step={0.5}
          disabled={!hasPlot}
          onChange={(v) => setParam('treeSpacing', v)}
        />
        <Slider
          label="Row spacing"
          unit="m"
          value={params.rowSpacing}
          min={3}
          max={14}
          step={0.5}
          disabled={!hasPlot}
          onChange={(v) => setParam('rowSpacing', v)}
        />
        <div className="field">
          <label>
            <span>Pollinizer rows</span>
            <b>{params.pollinizerEveryNRows ? `${Math.round(100 / params.pollinizerEveryNRows)}%` : 'none'}</b>
          </label>
          <select
            value={params.pollinizerEveryNRows}
            disabled={!hasPlot}
            onChange={(e) => setParam('pollinizerEveryNRows', parseInt(e.target.value, 10))}
          >
            <option value={0}>No pollinizer rows</option>
            <option value={2}>Every 2nd row</option>
            <option value={3}>Every 3rd row</option>
            <option value={4}>Every 4th row</option>
            <option value={5}>Every 5th row</option>
            <option value={6}>Every 6th row</option>
            <option value={8}>Every 8th row</option>
          </select>
        </div>
        <Slider
          label="Boundary setback"
          unit="m"
          value={params.setback}
          min={0}
          max={20}
          step={0.5}
          disabled={!hasPlot}
          onChange={(v) => setParam('setback', v)}
        />
        <Toggle
          label="Auto row direction"
          checked={params.autoOrient}
          disabled={!hasPlot}
          onChange={(v) => setParam('autoOrient', v)}
        />
        <Slider
          label="Row angle"
          unit="deg"
          value={params.autoOrient ? Math.round(stats.rowAngle * 10) / 10 : params.rowAngle}
          min={0}
          max={179}
          step={1}
          disabled={!hasPlot || params.autoOrient}
          onChange={(v) => setParam('rowAngle', v)}
        />
        <Toggle
          label="Stagger alternate rows"
          checked={params.stagger}
          disabled={!hasPlot}
          onChange={(v) => setParam('stagger', v)}
        />
        <div className="row" style={{ marginTop: 12 }}>
          <button className="primary" onClick={regenerate} disabled={!hasPlot}>
            Regenerate layout
          </button>
        </div>
        {manualEdits > 0 && (
          <p className="note warn" style={{ marginTop: 8 }}>
            {manualEdits} manual edit{manualEdits === 1 ? '' : 's'} will be discarded if you
            regenerate.
          </p>
        )}
      </section>

      <section className="section">
        <h3>Orchard</h3>
        <div className="stats">
          <div className="stat wide">
            <div className="v">{stats.total.toLocaleString()}</div>
            <div className="k">trees planted</div>
          </div>
          <div className="stat">
            <div className="v main">{stats.main.toLocaleString()}</div>
            <div className="k">main variety</div>
          </div>
          <div className="stat">
            <div className="v poll">{stats.pollinizer.toLocaleString()}</div>
            <div className="k">pollinizer ({stats.pollinizerPct.toFixed(0)}%)</div>
          </div>
        </div>
        <div className="bar" title="Main vs pollinizer split">
          <i style={{ width: `${100 - stats.pollinizerPct}%`, background: VARIETY_COLORS.main }} />
          <i style={{ width: `${stats.pollinizerPct}%`, background: VARIETY_COLORS.pollinizer }} />
        </div>

        <div style={{ marginTop: 14 }}>
          <div className="kv">
            <span>Plot area</span>
            <b>{stats.areaHa.toFixed(2)} ha</b>
          </div>
          <div className="kv">
            <span>Plantable after setback</span>
            <b>{(stats.plantingAreaM2 / 10000).toFixed(2)} ha</b>
          </div>
          <div className="kv">
            <span>Density</span>
            <b>{stats.densityPerHa.toFixed(0)} trees/ha</b>
          </div>
          <div className="kv">
            <span>Ground allocated</span>
            <b>{stats.coveragePct.toFixed(0)}%</b>
          </div>
          <div className="kv">
            <span>Rows</span>
            <b>{stats.rows || '-'}</b>
          </div>
          <div className="kv">
            <span>Row direction</span>
            <b>{stats.total ? `${Math.round(stats.rowAngle)} deg` : '-'}</b>
          </div>
          <div className="kv">
            <span>Perimeter</span>
            <b>{Math.round(stats.perimeterM)} m</b>
          </div>
        </div>
      </section>

      <section className="section">
        <h3>View</h3>
        <Toggle
          label="Health preview"
          checked={view.showHealth}
          onChange={(v) => setView({ showHealth: v })}
        />
        <div className="legend">
          {view.showHealth ? (
            <>
              <div>
                <span className="swatch" style={{ background: HEALTH_COLORS.healthy }} /> Healthy
              </div>
              <div>
                <span className="swatch" style={{ background: HEALTH_COLORS.stressed }} /> Stressed
              </div>
              <div>
                <span className="swatch" style={{ background: HEALTH_COLORS.critical }} /> Critical
              </div>
              <p className="note">Mock scores standing in for the sensor feed.</p>
            </>
          ) : (
            <>
              <div>
                <span className="swatch" style={{ background: VARIETY_COLORS.main }} /> Main variety
              </div>
              <div>
                <span className="swatch" style={{ background: VARIETY_COLORS.pollinizer }} /> Pollinizer
              </div>
            </>
          )}
        </div>

        <div style={{ marginTop: 12 }}>
          <Toggle
            label="Satellite ground"
            checked={view.showSatellite}
            disabled={!satellite.url}
            onChange={(v) => setView({ showSatellite: v })}
          />
          {!satellite.url && <p className="note">Needs a Mapbox token.</p>}

          <Toggle label="Real elevation" checked={view.showTerrain} onChange={(v) => setView({ showTerrain: v })} />
          {view.showTerrain && (
            <>
              {terrain.status === 'loading' && (
                <p className="note">
                  <span className="loading-dot" />
                  Fetching elevation...
                </p>
              )}
              {terrain.status === 'ready' && (
                <>
                  <p className="note">
                    {terrain.grid.relief.toFixed(1)} m of relief across the plot, via {terrain.source}.
                  </p>
                  <Slider
                    label="Vertical exaggeration"
                    unit="x"
                    value={view.exaggeration}
                    min={1}
                    max={6}
                    step={0.5}
                    onChange={(v) => setView({ exaggeration: v })}
                  />
                </>
              )}
              {terrain.status === 'error' && (
                <>
                  <p className="note err">Elevation unavailable: {terrain.error}</p>
                  <button onClick={loadTerrain}>Retry</button>
                </>
              )}
            </>
          )}

          <Toggle label="Shadows" checked={view.shadows} onChange={(v) => setView({ shadows: v })} />
          <Slider
            label="Time of day"
            unit="h"
            value={view.sunHour}
            min={6}
            max={20}
            step={0.5}
            onChange={(v) => setView({ sunHour: v })}
          />
          <Toggle label="Plot outline" checked={view.showBoundary} onChange={(v) => setView({ showBoundary: v })} />
          <Toggle
            label="Setback line"
            checked={view.showSetback}
            onChange={(v) => setView({ showSetback: v })}
          />
        </div>
      </section>
    </aside>
  )
}
