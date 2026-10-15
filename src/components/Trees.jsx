import { useLayoutEffect, useMemo, useRef } from 'react'
import * as THREE from 'three'
import { healthBand, HEALTH_COLORS } from '../layout/mockHealth.js'
import { VARIETY_COLORS } from '../layout/varieties.js'

export { VARIETY_COLORS }

const TRUNK_COLOR = '#5a4632'

// A "unit" almond tree, roughly 3.9 m tall with a 1.9 m canopy radius.
// The offsets are baked into the geometry so each instance matrix only has to
// carry position, a uniform size variation, and a random spin.
const TRUNK_H = 1.3
const CANOPY_R = 1.9
const CANOPY_Y = TRUNK_H + CANOPY_R * 0.55

function buildTrunkGeometry() {
  const g = new THREE.CylinderGeometry(0.15, 0.26, TRUNK_H, 6)
  g.translate(0, TRUNK_H / 2, 0)
  return g
}

function buildCanopyGeometry() {
  const g = new THREE.SphereGeometry(CANOPY_R, 10, 7)
  g.scale(1, 0.82, 1)
  g.translate(0, CANOPY_Y, 0)
  return g
}

/** Stable per-tree jitter so a tree keeps its size and spin across renders. */
function jitter(id) {
  let h = 2166136261
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  const a = ((h >>> 0) % 1000) / 1000
  const b = ((h >>> 10) % 1000) / 1000
  return { scale: 0.86 + a * 0.3, spin: b * Math.PI * 2 }
}

export function treeColor(tree, showHealth) {
  if (showHealth) {
    return HEALTH_COLORS[healthBand(tree.healthScore ?? 1)]
  }
  return VARIETY_COLORS[tree.variety] || VARIETY_COLORS.main
}

/**
 * Every tree in two instanced draw calls. Clicking a canopy or trunk reports
 * the tree back up so manual mode can remove it.
 */
export default function Trees({ trees, heightAt, showHealth, interactive, onPick, onHover }) {
  const trunkRef = useRef()
  const canopyRef = useRef()
  const trunkGeo = useMemo(buildTrunkGeometry, [])
  const canopyGeo = useMemo(buildCanopyGeometry, [])
  const count = trees.length

  // Placement only changes when the trees or the terrain under them change.
  useLayoutEffect(() => {
    const trunk = trunkRef.current
    const canopy = canopyRef.current
    if (!trunk || !canopy || !count) return

    const m = new THREE.Matrix4()
    const q = new THREE.Quaternion()
    const pos = new THREE.Vector3()
    const scl = new THREE.Vector3()
    const up = new THREE.Vector3(0, 1, 0)

    for (let i = 0; i < count; i++) {
      const t = trees[i]
      const { scale, spin } = jitter(t.id)
      pos.set(t.x, heightAt(t.x, t.z), t.z)
      q.setFromAxisAngle(up, spin)
      scl.setScalar(scale)
      m.compose(pos, q, scl)
      trunk.setMatrixAt(i, m)
      canopy.setMatrixAt(i, m)
    }
    trunk.instanceMatrix.needsUpdate = true
    canopy.instanceMatrix.needsUpdate = true
    trunk.computeBoundingSphere()
    canopy.computeBoundingSphere()
  }, [trees, count, heightAt])

  // Colour is cheap to update on its own, so toggling the health preview does
  // not touch the matrices.
  useLayoutEffect(() => {
    const canopy = canopyRef.current
    if (!canopy || !count) return
    const c = new THREE.Color()
    for (let i = 0; i < count; i++) {
      c.set(treeColor(trees[i], showHealth))
      canopy.setColorAt(i, c)
    }
    if (canopy.instanceColor) canopy.instanceColor.needsUpdate = true
  }, [trees, count, showHealth])

  if (!count) return null

  const pick = (e) => {
    if (!interactive) return
    if (e.instanceId == null) return
    const tree = trees[e.instanceId]
    if (!tree) return
    e.stopPropagation()
    onPick?.(tree, e)
  }

  const hover = (e) => {
    if (!interactive) return
    if (e.instanceId == null) return
    e.stopPropagation()
    onHover?.(trees[e.instanceId] || null)
  }

  return (
    <group>
      <instancedMesh
        ref={canopyRef}
        args={[canopyGeo, undefined, count]}
        castShadow
        receiveShadow
        frustumCulled={false}
        onClick={pick}
        onPointerMove={hover}
        onPointerOut={() => interactive && onHover?.(null)}
      >
        <meshStandardMaterial roughness={0.85} metalness={0} />
      </instancedMesh>
      <instancedMesh
        ref={trunkRef}
        args={[trunkGeo, undefined, count]}
        castShadow
        receiveShadow
        frustumCulled={false}
        onClick={pick}
        onPointerMove={hover}
      >
        <meshStandardMaterial color={TRUNK_COLOR} roughness={0.95} metalness={0} />
      </instancedMesh>
    </group>
  )
}

/** Ring drawn under whichever tree the pointer is over. */
export function TreeHighlight({ tree, heightAt }) {
  if (!tree) return null
  const y = heightAt(tree.x, tree.z)
  return (
    <group position={[tree.x, y + 0.06, tree.z]}>
      <mesh rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[2.05, 2.45, 28]} />
        <meshBasicMaterial color="#ffffff" transparent opacity={0.75} depthTest={false} />
      </mesh>
    </group>
  )
}
