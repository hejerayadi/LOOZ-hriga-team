import { useEffect, useMemo, useState } from 'react'
import * as THREE from 'three'
import { sampleElevation } from '../data/elevation.js'

/** Load a cross-origin image as a texture, without suspending on failure. */
function useImageTexture(url) {
  const [texture, setTexture] = useState(null)

  useEffect(() => {
    if (!url) {
      setTexture(null)
      return
    }
    let cancelled = false
    const loader = new THREE.TextureLoader()
    loader.setCrossOrigin('anonymous')
    loader.load(
      url,
      (t) => {
        if (cancelled) {
          t.dispose()
          return
        }
        t.colorSpace = THREE.SRGBColorSpace
        t.anisotropy = 8
        t.wrapS = THREE.ClampToEdgeWrapping
        t.wrapT = THREE.ClampToEdgeWrapping
        setTexture(t)
      },
      undefined,
      () => !cancelled && setTexture(null),
    )
    return () => {
      cancelled = true
    }
  }, [url])

  // Free the GPU copy when we swap to a different plot.
  useEffect(() => () => texture?.dispose(), [texture])

  return texture
}

/**
 * The field itself: a mesh spanning the plot's padded bounding box, displaced
 * by real elevation and skinned with the satellite photo of the same box.
 * Both come from the same bbox, so the photo lines up with the ground.
 */
export default function Ground({ bounds, grid, exaggeration = 1, textureUrl, onPlant, plantable }) {
  const texture = useImageTexture(textureUrl)

  const geometry = useMemo(() => {
    if (!bounds) return null
    // Match the mesh resolution to the elevation grid so every vertex lands on
    // a real sample instead of an interpolated one.
    const seg = grid ? grid.n - 1 : 16
    const nx = seg + 1
    const positions = new Float32Array(nx * nx * 3)
    const uvs = new Float32Array(nx * nx * 2)
    const indices = []

    for (let r = 0; r < nx; r++) {
      const tz = r / seg
      const z = bounds.minZ + bounds.depth * tz
      for (let c = 0; c < nx; c++) {
        const tx = c / seg
        const x = bounds.minX + bounds.width * tx
        const i = r * nx + c
        positions[i * 3] = x
        positions[i * 3 + 1] = grid ? sampleElevation(grid, bounds, x, z) * exaggeration : 0
        positions[i * 3 + 2] = z
        uvs[i * 2] = tx
        // Row 0 is the north edge, which is the top of the satellite image.
        uvs[i * 2 + 1] = 1 - tz
      }
    }

    for (let r = 0; r < seg; r++) {
      for (let c = 0; c < seg; c++) {
        const a = r * nx + c
        const b = a + 1
        const d = a + nx
        const e = d + 1
        indices.push(a, d, b, b, d, e)
      }
    }

    const g = new THREE.BufferGeometry()
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3))
    g.setAttribute('uv', new THREE.BufferAttribute(uvs, 2))
    g.setIndex(indices)
    g.computeVertexNormals()
    g.computeBoundingSphere()
    return g
  }, [bounds, grid, exaggeration])

  useEffect(() => () => geometry?.dispose(), [geometry])

  if (!geometry) return null

  return (
    <mesh
      geometry={geometry}
      receiveShadow
      onClick={(e) => {
        if (!plantable) return
        e.stopPropagation()
        onPlant?.(e.point.x, e.point.z)
      }}
    >
      <meshStandardMaterial
        map={texture || undefined}
        color={texture ? '#ffffff' : '#7d6b52'}
        roughness={0.95}
        metalness={0}
      />
    </mesh>
  )
}
