import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Canvas, useThree } from '@react-three/fiber'
import { OrbitControls, Sky, Line } from '@react-three/drei'
import * as THREE from 'three'
import { useStore } from '../state/store.js'
import { sampleElevation } from '../data/elevation.js'
import { pointInRings } from '../geo/projection.js'
import Ground from './Ground.jsx'
import Trees, { TreeHighlight } from './Trees.jsx'
import { healthBand } from '../layout/mockHealth.js'

/**
 * Solar position for the time-of-day slider. Rises in the east (+x), peaks to
 * the south (+z, northern hemisphere), sets in the west - enough to judge how
 * row orientation will shade the rows next door.
 */
function sunDirection(hour) {
  const t = Math.max(0, Math.min(1, (hour - 6) / 14))
  const az = Math.PI * t
  const el = Math.sin(Math.PI * t) * 1.15
  return new THREE.Vector3(Math.cos(az) * Math.cos(el), Math.sin(el), Math.sin(az) * Math.cos(el))
}

/** Tell a real click from the end of an orbit drag. */
function DragGuard({ stateRef }) {
  const gl = useThree((s) => s.gl)
  useEffect(() => {
    const el = gl.domElement
    const down = (e) => {
      stateRef.current = { x: e.clientX, y: e.clientY, dragged: false }
    }
    const move = (e) => {
      const s = stateRef.current
      if (s && !s.dragged && Math.hypot(e.clientX - s.x, e.clientY - s.y) > 4) s.dragged = true
    }
    el.addEventListener('pointerdown', down)
    el.addEventListener('pointermove', move)
    return () => {
      el.removeEventListener('pointerdown', down)
      el.removeEventListener('pointermove', move)
    }
  }, [gl, stateRef])
  return null
}

/** Frame the whole plot whenever a different plot is loaded. */
function CameraRig({ bounds, controlsRef }) {
  const camera = useThree((s) => s.camera)
  const key = bounds ? `${bounds.minX.toFixed(1)}|${bounds.maxX.toFixed(1)}|${bounds.minZ.toFixed(1)}` : 'none'

  useEffect(() => {
    if (!bounds) return
    const r = Math.max(bounds.width, bounds.depth)
    camera.position.set(bounds.centerX, r * 0.62, bounds.centerZ + r * 0.85)
    camera.near = 0.5
    camera.far = r * 25
    camera.updateProjectionMatrix()
    const c = controlsRef.current
    if (c) {
      c.target.set(bounds.centerX, 0, bounds.centerZ)
      c.update()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key])

  return null
}

/** Terrain-hugging polyline. Straight edges are subdivided so they drape. */
function DrapedLine({ points, heightAt, lift = 0.25, closed = true, ...props }) {
  const pts = useMemo(() => {
    if (!points || points.length < 2) return null
    const src = closed ? [...points, points[0]] : points
    const out = []
    for (let i = 0; i < src.length - 1; i++) {
      const a = src[i]
      const b = src[i + 1]
      const steps = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.z - a.z) / 4))
      for (let s = 0; s < steps; s++) {
        const t = s / steps
        const x = a.x + (b.x - a.x) * t
        const z = a.z + (b.z - a.z) * t
        out.push([x, heightAt(x, z) + lift, z])
      }
    }
    const last = src[src.length - 1]
    out.push([last.x, heightAt(last.x, last.z) + lift, last.z])
    return out
  }, [points, heightAt, lift, closed])

  if (!pts) return null
  return <Line points={pts} {...props} />
}

export default function OrchardScene() {
  const trees = useStore((s) => s.trees)
  const localBoundary = useStore((s) => s.localBoundary)
  const groundBounds = useStore((s) => s.groundBounds)
  const layoutMeta = useStore((s) => s.layoutMeta)
  const view = useStore((s) => s.view)
  const mode = useStore((s) => s.mode)
  const terrain = useStore((s) => s.terrain)
  const satellite = useStore((s) => s.satellite)
  const addTreeAt = useStore((s) => s.addTreeAt)
  const removeTree = useStore((s) => s.removeTree)

  const controlsRef = useRef()
  const dragRef = useRef(null)
  const [hovered, setHovered] = useState(null)

  const useTerrain = view.showTerrain && terrain.grid && groundBounds
  const heightAt = useCallback(
    (x, z) => (useTerrain ? sampleElevation(terrain.grid, groundBounds, x, z) * view.exaggeration : 0),
    [useTerrain, terrain.grid, groundBounds, view.exaggeration],
  )

  // Clicking outside the fence should not plant a tree.
  const plantRings = useMemo(() => {
    if (layoutMeta?.rings?.length) return layoutMeta.rings
    return localBoundary.length >= 3 ? [localBoundary] : []
  }, [layoutMeta, localBoundary])

  const handlePlant = (x, z) => {
    if (dragRef.current?.dragged) return
    if (mode !== 'manual') return
    if (plantRings.length && !pointInRings(x, z, plantRings)) return
    addTreeAt(x, z)
  }

  const handlePick = (tree) => {
    if (dragRef.current?.dragged) return
    if (mode !== 'manual') return
    removeTree(tree.id)
    setHovered(null)
  }

  const sun = useMemo(() => sunDirection(view.sunHour), [view.sunHour])
  const radius = groundBounds ? Math.max(groundBounds.width, groundBounds.depth) : 200
  const sunPos = useMemo(() => sun.clone().multiplyScalar(radius * 1.4), [sun, radius])
  const lightTarget = useMemo(() => new THREE.Object3D(), [])

  return (
    <>
      <Canvas
        shadows={view.shadows}
        dpr={[1, 2]}
        camera={{ fov: 50, position: [0, 120, 160] }}
        gl={{ antialias: true }}
        style={{ cursor: mode === 'manual' ? 'crosshair' : 'grab' }}
      >
        <DragGuard stateRef={dragRef} />
        <CameraRig bounds={groundBounds} controlsRef={controlsRef} />

        <Sky sunPosition={sun.toArray()} turbidity={6} rayleigh={1.4} mieCoefficient={0.006} />
        <hemisphereLight args={['#bcd4ff', '#6b5a3e', 0.55]} />
        <ambientLight intensity={0.25} />
        <primitive object={lightTarget} position={[groundBounds?.centerX ?? 0, 0, groundBounds?.centerZ ?? 0]} />
        <directionalLight
          position={[
            (groundBounds?.centerX ?? 0) + sunPos.x,
            Math.max(20, sunPos.y),
            (groundBounds?.centerZ ?? 0) + sunPos.z,
          ]}
          target={lightTarget}
          intensity={2.1}
          castShadow={view.shadows}
          shadow-mapSize={[2048, 2048]}
          shadow-bias={-0.0004}
          shadow-normalBias={0.06}
          shadow-camera-near={1}
          shadow-camera-far={radius * 4}
          shadow-camera-left={-radius * 0.75}
          shadow-camera-right={radius * 0.75}
          shadow-camera-top={radius * 0.75}
          shadow-camera-bottom={-radius * 0.75}
        />

        <Ground
          bounds={groundBounds}
          grid={useTerrain ? terrain.grid : null}
          exaggeration={view.exaggeration}
          textureUrl={view.showSatellite ? satellite.url : null}
          plantable={mode === 'manual'}
          onPlant={handlePlant}
        />

        {view.showBoundary && localBoundary.length >= 3 && (
          <DrapedLine
            points={localBoundary}
            heightAt={heightAt}
            color="#ffffff"
            lineWidth={2}
            lift={0.3}
          />
        )}

        {view.showSetback &&
          layoutMeta?.rings?.map((ring, i) => (
            <DrapedLine
              key={i}
              points={ring}
              heightAt={heightAt}
              color="#7fb069"
              lineWidth={1.5}
              lift={0.22}
              dashed
              dashSize={3}
              gapSize={2.5}
            />
          ))}

        <Trees
          trees={trees}
          heightAt={heightAt}
          showHealth={view.showHealth}
          interactive
          onPick={handlePick}
          onHover={setHovered}
        />
        {mode === 'manual' && <TreeHighlight tree={hovered} heightAt={heightAt} />}

        <OrbitControls
          ref={controlsRef}
          enableDamping
          dampingFactor={0.08}
          maxPolarAngle={Math.PI / 2 - 0.03}
          minDistance={6}
          maxDistance={radius * 5}
          makeDefault
        />
      </Canvas>

      <SceneHUD hovered={hovered} terrain={terrain} view={view} treeCount={trees.length} />

      <div className={`mode-pill ${mode === 'manual' ? 'manual' : ''}`}>
        {mode === 'manual'
          ? 'Manual edit - click the ground to plant, click a tree to remove'
          : 'AI layout - drag to orbit, scroll to zoom'}
      </div>
    </>
  )
}

function SceneHUD({ hovered, terrain, view, treeCount }) {
  return (
    <div className="scene-hud">
      {hovered ? (
        <>
          <div>
            <b>{hovered.variety === 'pollinizer' ? 'Pollinizer' : 'Main variety'}</b>
            {hovered.row != null ? ` - row ${hovered.row + 1}` : ' - manual'}
          </div>
          {hovered.healthScore != null && (
            <div>
              Health <b>{Math.round(hovered.healthScore * 100)}%</b> ({healthBand(hovered.healthScore)})
            </div>
          )}
        </>
      ) : (
        <>
          <div>
            <b>{treeCount.toLocaleString()}</b> trees
          </div>
          <div>
            {view.showTerrain && terrain.status === 'loading' && 'Loading elevation...'}
            {view.showTerrain && terrain.status === 'ready' && terrain.grid && (
              <>
                Slope range <b>{terrain.grid.relief.toFixed(1)} m</b>
              </>
            )}
            {(!view.showTerrain || terrain.status === 'idle' || terrain.status === 'error') &&
              'Flat ground'}
          </div>
        </>
      )}
    </div>
  )
}

