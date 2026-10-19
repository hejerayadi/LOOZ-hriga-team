import { useEffect, useRef, useState, useCallback } from "react";
import * as THREE from "three";

// ---- procedural soil texture (no external images/network needed) ----
function createSoilTexture(base, speckA, speckB, speckC) {
  const size = 256;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, size, size);

  const colors = [speckA, speckB, speckC];
  for (let i = 0; i < 1500; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const r = 0.6 + Math.random() * 2.4;
    ctx.globalAlpha = 0.22 + Math.random() * 0.35;
    ctx.fillStyle = colors[Math.floor(Math.random() * colors.length)];
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
  for (let i = 0; i < 20; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const r = 8 + Math.random() * 16;
    const grd = ctx.createRadialGradient(x, y, 0, x, y, r);
    grd.addColorStop(0, colors[Math.floor(Math.random() * colors.length)]);
    grd.addColorStop(1, "transparent");
    ctx.globalAlpha = 0.16;
    ctx.fillStyle = grd;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;

  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  return tex;
}

// ---- small billboard label showing the tree's id ----
function createIdSprite(id, variety) {
  const canvas = document.createElement("canvas");
  canvas.width = 128;
  canvas.height = 64;
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "rgba(255,255,255,0.96)";
  ctx.fillRect(0, 0, 128, 64);
  ctx.lineWidth = 5;
  ctx.strokeStyle = variety === "pollinizer" ? "#e08a86" : "#6f9a4c";
  ctx.strokeRect(3, 3, 122, 58);
  ctx.fillStyle = "#292524";
  ctx.font = "bold 32px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("#" + id, 64, 34);

  const tex = new THREE.CanvasTexture(canvas);
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex }));
  sprite.scale.set(1.15, 0.58, 1);
  return sprite;
}

// ---- an almond-tree-like mesh: short trunk, 3 splayed branches, leafy lobes, blossom flecks ----
function buildTreeMesh(variety, id, showLabel) {
  const group = new THREE.Group();
  const isPollinizer = variety === "pollinizer";

  const trunkMat = new THREE.MeshStandardMaterial({ color: "#a58e6f", roughness: 0.95 });
  const branchMat = new THREE.MeshStandardMaterial({ color: "#ad9678", roughness: 0.95 });
  const canopyMat = new THREE.MeshStandardMaterial({
    color: isPollinizer ? "#c99089" : "#8fa06b",
    roughness: 0.85,
  });
  const blossomMat = new THREE.MeshBasicMaterial({ color: isPollinizer ? "#f6d7d0" : "#fbf6ea" });

  const trunkHeight = 0.55;
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.17, trunkHeight, 8), trunkMat);
  trunk.position.y = trunkHeight / 2;
  trunk.castShadow = true;
  group.add(trunk);

  const trunkTop = new THREE.Vector3(0, trunkHeight, 0);
  const branchDefs = [
    { angle: 0.3, tilt: 0.62, length: 0.85 },
    { angle: 2.4, tilt: 0.58, length: 0.95 },
    { angle: 4.4, tilt: 0.66, length: 0.8 },
  ];
  branchDefs.forEach((b) => {
    const dir = new THREE.Vector3(
      Math.sin(b.tilt) * Math.cos(b.angle),
      Math.cos(b.tilt),
      Math.sin(b.tilt) * Math.sin(b.angle)
    ).normalize();

    const branch = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.09, b.length, 6), branchMat);
    branch.position.copy(dir.clone().multiplyScalar(b.length / 2).add(trunkTop));
    branch.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
    branch.castShadow = true;
    group.add(branch);

    const lobe = new THREE.Mesh(new THREE.IcosahedronGeometry(0.5 + Math.random() * 0.1, 0), canopyMat);
    lobe.position.copy(dir.clone().multiplyScalar(b.length).add(trunkTop)).add(new THREE.Vector3(0, 0.15, 0));
    lobe.castShadow = true;
    group.add(lobe);
  });

  const centerLobe = new THREE.Mesh(new THREE.IcosahedronGeometry(0.42, 0), canopyMat);
  centerLobe.position.set(0, trunkHeight + 0.55, 0);
  centerLobe.castShadow = true;
  group.add(centerLobe);

  for (let i = 0; i < 5; i++) {
    const a = Math.random() * Math.PI * 2;
    const h = trunkHeight + 0.3 + Math.random() * 0.95;
    const r = 0.35 + Math.random() * 0.35;
    const bloom = new THREE.Mesh(new THREE.IcosahedronGeometry(0.07, 0), blossomMat);
    bloom.position.set(Math.cos(a) * r, h, Math.sin(a) * r);
    group.add(bloom);
  }

  const basin = new THREE.Mesh(
    new THREE.RingGeometry(0.2, 0.65, 24),
    new THREE.MeshBasicMaterial({ color: "#7a6244", transparent: true, opacity: 0.5, side: THREE.DoubleSide })
  );
  basin.rotation.x = -Math.PI / 2;
  basin.position.y = 0.015;
  group.add(basin);

  if (showLabel) {
    const label = createIdSprite(id, variety);
    label.position.set(0, 2.55, 0);
    group.add(label);
  }

  return group;
}

export default function OrchardPlanner() {
  const mountRef = useRef(null);
  const sceneRef = useRef(null);
  const cameraRef = useRef(null);
  const rendererRef = useRef(null);
  const treesGroupRef = useRef(null);
  const plotMeshRef = useRef(null);
  const plotTexRef = useRef(null);
  const raycasterRef = useRef(new THREE.Raycaster());
  const nextIdRef = useRef(1);
  const pressedKeysRef = useRef({});
  const cameraModeRef = useRef("orbit");

  const camStateRef = useRef({
    theta: Math.PI / 4,
    phi: Math.PI / 3.4,
    radius: 62,
    target: new THREE.Vector3(0, 1, 0),
  });
  const walkStateRef = useRef({ x: 0, z: -24, yaw: 0 });
  const dragRef = useRef({ dragging: false, moved: false, lastX: 0, lastY: 0, startX: 0, startY: 0 });

  const [mode, setMode] = useState("ai");
  const [cameraMode, setCameraMode] = useState("orbit");
  const [placeVariety, setPlaceVariety] = useState("main");
  const [plotWidth, setPlotWidth] = useState(36);
  const [plotLength, setPlotLength] = useState(36);
  const [treeSpacing, setTreeSpacing] = useState(6);
  const [rowSpacing, setRowSpacing] = useState(6);
  const [pollinizerEvery, setPollinizerEvery] = useState(4);
  const [showLabels, setShowLabels] = useState(false);
  const [trees, setTrees] = useState([]);

  useEffect(() => { cameraModeRef.current = cameraMode; }, [cameraMode]);

  const resetWalker = useCallback(() => {
    walkStateRef.current = { x: 0, z: -(plotLength / 2) - 6, yaw: 0 };
  }, [plotLength]);

  const generateLayout = useCallback(() => {
    const halfW = plotWidth / 2;
    const halfL = plotLength / 2;
    const cols = Math.max(1, Math.floor(plotWidth / treeSpacing) + 1);
    const rows = Math.max(1, Math.floor(plotLength / rowSpacing) + 1);
    const newTrees = [];
    let id = 1;
    for (let r = 0; r < rows; r++) {
      const z = -halfL + r * rowSpacing;
      if (z > halfL + 0.001) continue;
      const isPollinizerRow = pollinizerEvery > 0 && (r + 1) % pollinizerEvery === 0;
      for (let c = 0; c < cols; c++) {
        const x = -halfW + c * treeSpacing;
        if (x > halfW + 0.001) continue;
        newTrees.push({ id: id++, x, z, variety: isPollinizerRow ? "pollinizer" : "main" });
      }
    }
    nextIdRef.current = id;
    setTrees(newTrees);
  }, [plotWidth, plotLength, treeSpacing, rowSpacing, pollinizerEvery]);

  // ---- one-time three.js setup ----
  useEffect(() => {
    const mount = mountRef.current;
    const width = mount.clientWidth || 800;
    const height = mount.clientHeight || 600;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color("#cfe9ef");
    scene.fog = new THREE.Fog("#cfe9ef", 70, 170);
    sceneRef.current = scene;

    const camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 1000);
    cameraRef.current = camera;

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(width, height);
    renderer.shadowMap.enabled = true;
    mount.appendChild(renderer.domElement);
    rendererRef.current = renderer;

    scene.add(new THREE.AmbientLight(0xffffff, 0.6));
    const sun = new THREE.DirectionalLight(0xfff2d9, 1.1);
    sun.position.set(35, 48, 22);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    Object.assign(sun.shadow.camera, { left: -55, right: 55, top: 55, bottom: -55 });
    scene.add(sun);

    const fieldTex = createSoilTexture("#9caf7c", "#7f9663", "#b7c497", "#6d8353");
    fieldTex.repeat.set(40, 40);
    const field = new THREE.Mesh(
      new THREE.PlaneGeometry(400, 400),
      new THREE.MeshStandardMaterial({ map: fieldTex, roughness: 1 })
    );
    field.rotation.x = -Math.PI / 2;
    field.position.y = -0.01;
    field.receiveShadow = true;
    scene.add(field);

    plotTexRef.current = createSoilTexture("#ab8f66", "#8f7550", "#c4a273", "#7a6244");

    const treesGroup = new THREE.Group();
    treesGroupRef.current = treesGroup;
    scene.add(treesGroup);

    const clock = new THREE.Clock();
    let raf;
    const animate = () => {
      raf = requestAnimationFrame(animate);
      const dt = Math.min(clock.getDelta(), 0.05);

      if (cameraModeRef.current === "walk") {
        const w = walkStateRef.current;
        const keys = pressedKeysRef.current;
        const turnSpeed = 1.7;
        const moveSpeed = 8;
        if (keys.left) w.yaw += turnSpeed * dt;
        if (keys.right) w.yaw -= turnSpeed * dt;
        const fwd = { x: Math.sin(w.yaw), z: Math.cos(w.yaw) };
        if (keys.up) { w.x += fwd.x * moveSpeed * dt; w.z += fwd.z * moveSpeed * dt; }
        if (keys.down) { w.x -= fwd.x * moveSpeed * dt; w.z -= fwd.z * moveSpeed * dt; }
        const limit = 185;
        w.x = Math.max(-limit, Math.min(limit, w.x));
        w.z = Math.max(-limit, Math.min(limit, w.z));
        camera.position.set(w.x, 1.7, w.z);
        camera.lookAt(w.x + fwd.x, 1.7, w.z + fwd.z);
      } else {
        const s = camStateRef.current;
        camera.position.set(
          s.target.x + s.radius * Math.sin(s.phi) * Math.sin(s.theta),
          s.target.y + s.radius * Math.cos(s.phi),
          s.target.z + s.radius * Math.sin(s.phi) * Math.cos(s.theta)
        );
        camera.lookAt(s.target);
      }
      renderer.render(scene, camera);
    };
    animate();

    const handleResize = () => {
      const w = mount.clientWidth, h = mount.clientHeight;
      if (!w || !h) return;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    };
    const ro = new ResizeObserver(handleResize);
    ro.observe(mount);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      renderer.dispose();
      if (mount.contains(renderer.domElement)) mount.removeChild(renderer.domElement);
    };
  }, []);

  useEffect(() => {
    generateLayout();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ---- rebuild plot boundary mesh when size changes ----
  useEffect(() => {
    const scene = sceneRef.current;
    if (!scene || !plotTexRef.current) return;
    if (plotMeshRef.current) {
      scene.remove(plotMeshRef.current);
      plotMeshRef.current.geometry.dispose();
      plotMeshRef.current.material.dispose();
    }
    const tex = plotTexRef.current;
    tex.repeat.set(plotWidth / 5, plotLength / 5);
    tex.needsUpdate = true;
    const mesh = new THREE.Mesh(
      new THREE.PlaneGeometry(plotWidth, plotLength),
      new THREE.MeshStandardMaterial({ map: tex, roughness: 1 })
    );
    mesh.rotation.x = -Math.PI / 2;
    mesh.receiveShadow = true;
    scene.add(mesh);
    plotMeshRef.current = mesh;
  }, [plotWidth, plotLength]);

  // ---- rebuild trees whenever the tree list (or label visibility) changes ----
  useEffect(() => {
    const group = treesGroupRef.current;
    if (!group) return;
    while (group.children.length) {
      const child = group.children.pop();
      child.traverse((o) => {
        if (o.geometry) o.geometry.dispose();
        if (o.material) {
          if (o.material.map) o.material.map.dispose();
          o.material.dispose();
        }
      });
    }
    trees.forEach((t) => {
      const obj = buildTreeMesh(t.variety, t.id, showLabels);
      obj.position.set(t.x, 0, t.z);
      obj.userData.id = t.id;
      group.add(obj);
    });
  }, [trees, showLabels]);

  // ---- keyboard controls, active only while walking ----
  useEffect(() => {
    if (cameraMode !== "walk") return;
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();

    const setKey = (key, val) => {
      const keys = pressedKeysRef.current;
      if (key === "ArrowUp" || key === "w" || key === "W") keys.up = val;
      if (key === "ArrowDown" || key === "s" || key === "S") keys.down = val;
      if (key === "ArrowLeft" || key === "a" || key === "A") keys.left = val;
      if (key === "ArrowRight" || key === "d" || key === "D") keys.right = val;
    };
    const onKeyDown = (e) => {
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key)) e.preventDefault();
      setKey(e.key, true);
    };
    const onKeyUp = (e) => setKey(e.key, false);

    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
      pressedKeysRef.current = {};
    };
  }, [cameraMode]);

  // ---- pointer interaction: drag to orbit, click to place/remove (orbit view only) ----
  const handlePointerDown = (e) => {
    if (cameraMode !== "orbit") return;
    dragRef.current = { dragging: true, moved: false, startX: e.clientX, startY: e.clientY, lastX: e.clientX, lastY: e.clientY };
  };

  const handlePointerMove = (e) => {
    if (cameraMode !== "orbit") return;
    const d = dragRef.current;
    if (!d.dragging) return;
    const dx = e.clientX - d.lastX;
    const dy = e.clientY - d.lastY;
    d.lastX = e.clientX;
    d.lastY = e.clientY;
    if (Math.abs(e.clientX - d.startX) + Math.abs(e.clientY - d.startY) > 4) d.moved = true;
    const s = camStateRef.current;
    s.theta -= dx * 0.0065;
    s.phi = Math.min(Math.PI / 2 - 0.05, Math.max(0.2, s.phi - dy * 0.0065));
  };

  const handleClick = (e) => {
    if (cameraMode !== "orbit" || mode !== "manual" || !cameraRef.current) return;
    const rect = mountRef.current.getBoundingClientRect();
    const mouse = new THREE.Vector2(
      ((e.clientX - rect.left) / rect.width) * 2 - 1,
      -((e.clientY - rect.top) / rect.height) * 2 + 1
    );
    const raycaster = raycasterRef.current;
    raycaster.setFromCamera(mouse, cameraRef.current);

    const treeHits = raycaster.intersectObjects(treesGroupRef.current.children, true);
    if (treeHits.length > 0) {
      let obj = treeHits[0].object;
      while (obj && obj.userData.id === undefined) obj = obj.parent;
      if (obj && obj.userData.id !== undefined) {
        setTrees((prev) => prev.filter((t) => t.id !== obj.userData.id));
        return;
      }
    }
    if (plotMeshRef.current) {
      const planeHits = raycaster.intersectObject(plotMeshRef.current);
      if (planeHits.length > 0) {
        const p = planeHits[0].point;
        const id = nextIdRef.current++;
        setTrees((prev) => [...prev, { id, x: p.x, z: p.z, variety: placeVariety }]);
      }
    }
  };

  const handlePointerUp = (e) => {
    if (cameraMode !== "orbit") return;
    const d = dragRef.current;
    d.dragging = false;
    if (!d.moved) handleClick(e);
  };

  const handleWheel = (e) => {
    if (cameraMode !== "orbit") return;
    e.preventDefault();
    const s = camStateRef.current;
    s.radius = Math.min(130, Math.max(14, s.radius + e.deltaY * 0.05));
  };

  const resetView = () => {
    camStateRef.current = { ...camStateRef.current, theta: Math.PI / 4, phi: Math.PI / 3.4, radius: 62 };
    resetWalker();
  };

  const enterWalkMode = () => {
    resetWalker();
    setCameraMode("walk");
  };

  const mainCount = trees.filter((t) => t.variety === "main").length;
  const pollCount = trees.length - mainCount;

  const Slider = ({ label, value, onChange, min, max, step, unit }) => (
    <label className="block mb-3">
      <div className="flex justify-between text-sm text-stone-600 mb-1">
        <span>{label}</span>
        <span className="text-stone-800 font-medium">{value}{unit}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        style={{ accentColor: "#4d7c33" }}
        className="w-full"
      />
    </label>
  );

  return (
    <div className="w-full h-screen flex bg-stone-50" style={{ fontFamily: "ui-sans-serif, system-ui, sans-serif" }}>
      <aside className="h-full overflow-y-auto p-5 border-r border-stone-200 bg-white" style={{ width: "290px", flexShrink: 0 }}>
        <h1 className="text-lg font-semibold text-stone-800">Orchard layout planner</h1>
        <p className="text-xs text-stone-500 mt-1 mb-5">Small simulation for the 3D placement pillar.</p>

        <div className="mb-5">
          <div className="text-sm font-medium text-stone-700 mb-2">View</div>
          <div className="flex flex-col gap-2">
            <button
              onClick={() => setCameraMode("orbit")}
              className="text-sm font-medium rounded-md py-2 px-3 border"
              style={{
                borderColor: "#d6d3ce",
                backgroundColor: cameraMode === "orbit" ? "#292524" : "white",
                color: cameraMode === "orbit" ? "white" : "#44403c",
              }}
            >
              Orbit view
            </button>
            <button
              onClick={enterWalkMode}
              className="text-sm font-medium rounded-md py-2 px-3 border"
              style={{
                borderColor: "#d6d3ce",
                backgroundColor: cameraMode === "walk" ? "#292524" : "white",
                color: cameraMode === "walk" ? "white" : "#44403c",
              }}
            >
              Walk through orchard
            </button>
          </div>
        </div>

        {cameraMode === "walk" ? (
          <div className="mb-5 p-3 rounded-md" style={{ backgroundColor: "#f5f2ea" }}>
            <div className="text-xs text-stone-600 leading-relaxed">
              <span className="font-medium text-stone-800">↑ / W</span> walk forward<br />
              <span className="font-medium text-stone-800">↓ / S</span> walk back<br />
              <span className="font-medium text-stone-800">← / A, → / D</span> turn
            </div>
          </div>
        ) : (
          <>
            <div className="mb-5">
              <div className="text-sm font-medium text-stone-700 mb-2">Plot size</div>
              <Slider label="Width" value={plotWidth} onChange={setPlotWidth} min={12} max={60} step={2} unit=" m" />
              <Slider label="Length" value={plotLength} onChange={setPlotLength} min={12} max={60} step={2} unit=" m" />
            </div>

            <div className="mb-5">
              <div className="text-sm font-medium text-stone-700 mb-2">Spacing</div>
              <Slider label="Tree spacing" value={treeSpacing} onChange={setTreeSpacing} min={4} max={10} step={0.5} unit=" m" />
              <Slider label="Row spacing" value={rowSpacing} onChange={setRowSpacing} min={4} max={10} step={0.5} unit=" m" />
              <Slider label="Pollinizer row every" value={pollinizerEvery} onChange={setPollinizerEvery} min={2} max={6} step={1} unit=" rows" />
            </div>

            <div className="mb-5 flex flex-col gap-2">
              <button
                onClick={() => { setMode("ai"); generateLayout(); }}
                className="text-sm font-medium text-white rounded-md py-2 px-3"
                style={{ backgroundColor: mode === "ai" ? "#3f6626" : "#4d7c33" }}
              >
                Generate AI layout
              </button>
              <button
                onClick={() => setMode("manual")}
                className="text-sm font-medium rounded-md py-2 px-3 border"
                style={{
                  borderColor: "#d6d3ce",
                  backgroundColor: mode === "manual" ? "#292524" : "white",
                  color: mode === "manual" ? "white" : "#44403c",
                }}
              >
                Manual placement
              </button>
            </div>

            {mode === "manual" && (
              <div className="mb-5 p-3 rounded-md" style={{ backgroundColor: "#f5f2ea" }}>
                <div className="text-xs text-stone-600 mb-2">Click the ground to plant, click a tree to remove it.</div>
                <div className="flex gap-2">
                  <button
                    onClick={() => setPlaceVariety("main")}
                    className="text-xs rounded-md py-1.5 px-2 flex-1"
                    style={{ backgroundColor: placeVariety === "main" ? "#6f9a4c" : "#e7e3da", color: placeVariety === "main" ? "white" : "#44403c" }}
                  >
                    Main variety
                  </button>
                  <button
                    onClick={() => setPlaceVariety("pollinizer")}
                    className="text-xs rounded-md py-1.5 px-2 flex-1"
                    style={{ backgroundColor: placeVariety === "pollinizer" ? "#e08a86" : "#e7e3da", color: placeVariety === "pollinizer" ? "white" : "#44403c" }}
                  >
                    Pollinizer
                  </button>
                </div>
                <button onClick={() => setTrees([])} className="text-xs text-stone-500 mt-2 underline">
                  Clear all trees
                </button>
              </div>
            )}
          </>
        )}

        <div className="mb-3 p-3 rounded-md border border-stone-200">
          <div className="text-sm font-medium text-stone-700 mb-1">{trees.length} trees planted</div>
          <div className="text-xs text-stone-500">{mainCount} main variety · {pollCount} pollinizer</div>
        </div>

        <label className="flex items-center gap-2 text-xs text-stone-600 mb-5">
          <input type="checkbox" checked={showLabels} onChange={(e) => setShowLabels(e.target.checked)} />
          Show tree IDs
        </label>

        <div className="text-xs text-stone-500 space-y-1.5">
          <div className="flex items-center gap-2"><span style={{ width: 10, height: 10, borderRadius: 999, backgroundColor: "#8fa06b", display: "inline-block" }} /> Main variety</div>
          <div className="flex items-center gap-2"><span style={{ width: 10, height: 10, borderRadius: 999, backgroundColor: "#c99089", display: "inline-block" }} /> Pollinizer variety</div>
          <div className="flex items-center gap-2"><span style={{ width: 10, height: 10, borderRadius: 2, backgroundColor: "#ab8f66", display: "inline-block" }} /> Plot boundary</div>
        </div>

        <button onClick={resetView} className="text-xs text-stone-500 underline mt-5">Reset view</button>
      </aside>

      <div className="flex-1 h-full relative">
        <div
          ref={mountRef}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerLeave={handlePointerUp}
          onWheel={handleWheel}
          className="w-full h-full"
          style={{ cursor: cameraMode === "walk" ? "default" : (mode === "manual" ? "crosshair" : "grab"), touchAction: "none" }}
        />
        <div className="absolute top-3 left-3 text-xs px-2.5 py-1 rounded-full bg-white border border-stone-200 text-stone-600">
          {cameraMode === "walk" ? "Walking through the orchard" : (mode === "ai" ? "AI-generated layout" : "Manual placement mode")}
        </div>
        <div className="absolute bottom-3 left-3 text-xs text-stone-500">
          {cameraMode === "walk" ? "Arrow keys or WASD to move" : "Drag to rotate · scroll to zoom"}
        </div>
      </div>
    </div>
  );
}
