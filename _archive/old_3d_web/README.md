# Almond Orchard Planner

Plan an almond orchard on your real field, in 3D.

Draw your plot on a satellite map, let the layout engine fill it with trees at the
spacing you want, then walk the result in 3D on the actual terrain — with the real
satellite image under your feet and the real slope beneath it. Tweak it by hand,
then export a planting list the field team can take out with them.

```bash
npm install
npm run dev        # http://localhost:5173
npm run smoke      # headless checks on the geometry, layout and export code
npm run build
```

## Mapbox token

The map, the satellite ground texture and the elevation data all come from Mapbox.
Get a free public token at [account.mapbox.com](https://account.mapbox.com/access-tokens/)
and either:

- paste it into the prompt the app shows on first run (stored in `localStorage`), or
- copy `.env.example` to `.env` and set `VITE_MAPBOX_TOKEN=pk...`

**Without a token** the app still runs: choose *Skip for now* to load a demo field
near Kairouan. You get the full layout engine and 3D view on plain ground, and
elevation falls back to [open-elevation.com](https://open-elevation.com).

## How it works

### 1. Plot input

Draw the boundary with `@mapbox/mapbox-gl-draw` on a satellite map — corner by
corner, dragging vertices to fine-tune. There is a place search so you can get to
your field without panning the planet.

The drawn lng/lat ring is projected to a local metre grid anchored at the plot
centroid: `+x` is east, `-z` is north, so the default camera looks north across
the field. The metres-per-degree scale is *measured* with turf at the plot's own
latitude rather than hard-coded, so the grid holds up anywhere. Over a field-sized
area the flat-earth approximation is good to a few centimetres — the round-trip
test in `scripts/smoke-layout.mjs` pins this down.

Area and perimeter come from `turf.area` / `turf.length` on the real geodesic
polygon, not from the flattened grid.

### 2. Layout engine

`src/layout/generateLayout.js` takes the polygon plus tree spacing, row spacing,
a pollinizer rule and a boundary setback, and returns planted positions.

- **Setback** shrinks the plot with a negative `turf.buffer` in metres *before*
  projection, so the headland is geodesically correct. If the setback would erase
  a small plot entirely, it falls back to the raw boundary instead of planting
  nothing.
- **Lattice fill** lays a rotated grid over the planting area and keeps the nodes
  that land inside it, optionally staggering alternate rows (quincunx).
- **Orientation search** is the part that earns the "AI" label. Angle and lattice
  phase interact — a grid that looks bad at phase 0 can be the best one once it is
  nudged half a spacing — so ranking angles at a single phase picks losers. The
  engine scores each angle as the better of two phases, shortlists the top
  candidates, then runs a full 4x4 phase search on the finalists. On a diamond-
  shaped plot this finds ~36 more trees than an axis-aligned grid.
- **Rows do not rotate for nothing.** Maximum tree count is not the only thing
  that matters: skewed rows mean awkward headlands and more turning for the
  tractor. Counts within 1% of the best are treated as a tie and settled in favour
  of the angle closest to the plot's longest edge. On the demo field that means
  rows along the boundary (981 trees) rather than a 41° skew for 3 more trees.

A ~4.3 ha plot solves in well under 100 ms, so the sliders regenerate live.

Turn off *Auto row direction* to set the angle yourself.

### 3. 3D view

`react-three-fiber` + `drei`'s `OrbitControls`. Trees are procedural — a cylinder
trunk and a squashed sphere canopy — drawn as **two instanced meshes** regardless
of tree count, so a 5,000-tree orchard is still two draw calls. Each tree gets a
stable size and spin hashed from its id, so it does not shimmer between renders.

Colour shows variety (deep green main / lime pollinizer) or, with the health
preview on, green-amber-red.

There is a time-of-day slider driving the sun and the shadows — useful for judging
how a row direction will shade its neighbours.

### 4. Manual mode

Switch to **Manual** and click bare ground to plant, click a tree to pull it out.
Planting is clipped to the setback ring, and a small drag threshold keeps the end
of an orbit from planting a tree by accident.

Manual edits survive until you press *Regenerate layout* — the sidebar warns you
how many you are about to lose.

### 5. Terrain and satellite

The ground mesh, the satellite photo and the elevation grid are all derived from
**one padded bounding box**. Deriving them separately is the classic way to end up
with the photo drifting out of register with the terrain.

- **Satellite**: Mapbox Static Images API. Web Mercator stretches latitude, so the
  image aspect ratio is computed in mercator space — otherwise Mapbox letterboxes
  the bbox and the texture no longer lines up with the field.
- **Elevation**: Mapbox Terrain-RGB tiles (~5 m/px) stitched into a canvas and
  decoded, with open-elevation.com as a keyless fallback and flat ground if both
  fail. Heights are stored relative to the plot mean so the scene sits around
  `y = 0` whatever the real altitude is. Trees sample the same grid bilinearly, so
  they sit on the surface rather than through it.

Vertical exaggeration is adjustable — real field slope is usually too subtle to
read at 1x.

### 6. Export

| Button | What you get |
| --- | --- |
| **Save** | Full project JSON — boundary, params, every tree. Reopens with **Open**. |
| **GeoJSON** | Plot polygon + one `Point` per tree in WGS84, for QGIS or a GPS planting app. |
| **CSV** | Planting list: id, variety, lat/lng, local x/z, row, health. |

## Data model

```js
Plot  = { boundaryPoints: [{ lat, lng }], soilZones: [] }
Tree  = { id, x, z, variety: 'main' | 'pollinizer', healthScore?, row?, col? }
```

`x`/`z` are metres in the local grid. `soilZones` is carried through save/load but
not yet used — it is the hook for the next feature.

## Layout

```
src/
  geo/projection.js       lng/lat <-> local metres, area, point-in-polygon
  layout/generateLayout.js  setback, lattice fill, orientation search
  layout/mockHealth.js    placeholder health scores (smooth stress patches)
  data/satellite.js       Mapbox Static Images URL, mercator-correct
  data/elevation.js       Terrain-RGB tiles + open-elevation fallback
  io/project.js           save / load / GeoJSON / CSV
  state/store.js          zustand store
  components/             MapPlotDrawer, OrchardScene, Ground, Trees, Sidebar
scripts/                  headless checks (npm run smoke)
```

`mapbox-gl` and `three` are lazy-loaded per view, so the initial bundle is ~515 kB
rather than 3.3 MB.

## Testing

`npm run smoke` runs both suites headlessly — no browser, no Mapbox token:

- **Layout**: projection round-trips to <1 cm, area matches, tree counts match hand
  arithmetic, the setback is respected, no two trees are closer than the spacing,
  pollinizer rows land where the rule says, auto-orient never loses to a fixed
  grid, and degenerate inputs (empty boundary, oversized setback) do not throw.
- **IO**: save/load round-trips positions to 1 cm, exported GeoJSON reprojects back
  onto the same trees, CSV shape is stable, and malformed project files are
  rejected with a readable message.

## Known limits and next steps

- **Health scores are mock.** `mockHealth.js` synthesises smooth stress patches so
  the preview looks like a real field map rather than confetti. It is a placeholder
  for the monitoring pillar — swap it for the sensor/NDVI feed and nothing else has
  to change.
- **Trees are procedural.** The layout logic and camera are solid, so swapping in
  a GLTF model (Kenney's low-poly nature pack, say) is now a contained change in
  `Trees.jsx` — keep the instancing, load with drei's `useGLTF`.
- **`soilZones` is a stub** in the data model, not yet drawn or used by the engine.
- **Flat-earth projection** is fine to a few centimetres at field scale but is not
  meant for plots spanning kilometres.
- The 3D view was verified through the build and headless geometry tests; the
  browser rendering itself has not been exercised in an automated test.
