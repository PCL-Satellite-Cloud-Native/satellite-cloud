<template>
  <div class="wrap">
    <div class="left">
      <div class="card">
        <div class="h">T0 初始拓扑</div>

        <div class="small" v-if="loading">正在加载 CSV… {{ loadProgress }}</div>
        <div class="small" v-else-if="ready">
          已加载: {{ sats.length }} 颗卫星<br />
          T0时刻: <span class="mono">{{ t0Label }}</span>
        </div>
        <div class="small" v-else>数据未加载</div>

        <div class="divider"></div>

        <div class="h2">链路连线</div>
        <label class="check">
          <input type="checkbox" v-model="showLinks" :disabled="!ready" />
          <span>启用连线显示</span>
        </label>

        <div class="row2">
          <div class="label">连线模式</div>
          <select class="select" v-model="linkMode" :disabled="!ready || !showLinks">
            <option value="orbit">同轨环网 (Same-orbit)</option>
            <option value="delay">时延矩阵 (CSV定义)</option>
          </select>
        </div>

        <button class="btn wide" @click="resetView" :disabled="!ready">重置相机视图</button>
      </div>

      <div class="card">
        <div class="h">当前选中卫星</div>
        <div v-if="selected">
          <div class="kv"><b>ID</b><span class="mono">{{ selected.id }}</span></div>
          <div class="kv"><b>轨道 (Orbit)</b><span>{{ selected.orbit }}</span></div>
          <div class="kv"><b>槽位 (Slot)</b><span>{{ selected.slot }}</span></div>
          <div class="divider"></div>
          <div class="h2">地理坐标 (LLA)</div>
          <div class="kv"><b>纬度</b><span>{{ fmt(selected.lla_Lat, 6) }}°</span></div>
          <div class="kv"><b>经度</b><span>{{ fmt(selected.lla_Lon, 6) }}°</span></div>
          <div class="kv"><b>高度</b><span>{{ fmt(selected.lla_Alt, 3) }} km</span></div>
        </div>
        <div v-else class="small">请点击 3D 视图中的卫星节点查看详情。</div>
      </div>
    </div>

    <div class="center">
      <div ref="host" class="viewport"></div>
    </div>

    <div class="right">
      <div class="card topology-card">
        <div class="h">路由拓扑 (Router Topology)</div>
        
        <div class="controls">
          <label class="control-item">
            <span class="label">中心节点 ID (独立查询)</span>
            <input class="input" v-model.trim="selectedRouter" placeholder="例如：r001001 或 sat-1-1" />
          </label>
        </div>

        <div class="topology-container">
          <v-network-graph 
            class="graph-canvas"
            :nodes="routerNodes" 
            :edges="routerEdges" 
            :layouts="routerLayouts"
            :configs="graphConfigs"
          >
            <template #override-node="{ scale }">
              <image :href="satIcon" :x="-12 * scale" :y="-12 * scale" :width="24 * scale" :height="24 * scale" />
            </template>
            <template #edge-label="{ edge, ...slotProps }">
              <v-edge-label :text="edge.label" align="center" vertical-align="above" v-bind="slotProps" />
            </template>
          </v-network-graph>

          <div v-if="routerStatus !== 'ready'" class="overlay">
            <div class="overlay-text">
              <template v-if="routerStatus === 'loading'">正在加载拓扑数据...</template>
              <template v-else>错误：{{ routerErrorMsg }}</template>
            </div>
          </div>
        </div>

        <div class="small" style="margin-top: 10px;">
          数据来自服务端 API（DB 中 router_nodes / router_links）<br/>
          BFS 最大 16 跳，节点展示名为 sat_id，同心圆布局
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, reactive, watch, markRaw } from "vue";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { CSS2DRenderer, CSS2DObject } from "three/examples/jsm/renderers/CSS2DRenderer.js";
import { TubeGeometry, LineCurve3 } from "three";

// 引入 v-network-graph
import { VNetworkGraph, VEdgeLabel, defineConfigs } from 'v-network-graph'
import 'v-network-graph/lib/style.css'

// ---------------------------------------------------------
// 2D 路由拓扑逻辑
// ---------------------------------------------------------
const satIcon = '/satellite.svg' 

const routerStatus = ref('loading')
const routerErrorMsg = ref('')
const selectedRouter = ref('sat-1-1') // 默认中心节点，可填 r001001 或 sat-1-1

const routerNodes = reactive({})
const routerEdges = reactive({})
const routerLayouts = reactive({ nodes: {} })

const graphConfigs = defineConfigs({
  view: {
    scalingObjects: true,
    minZoomLevel: 0.1,
    maxZoomLevel: 16,
    panEnabled: true,
    zoomEnabled: true,
  },
  node: {
    normal: { type: "circle", radius: 16, color: "#4466cc" },
    label: { color: "#ffffff", fontSize: 11 },
  },
  edge: {
    normal: { width: 2, color: "#555555" },
    label: { color: "#eeeeee", fontSize: 10 },
  },
})

/** 从服务端 API 加载路由拓扑（BFS + 布局由后端完成，节点展示名为 sat_id） */
async function loadRouterData () {
  routerStatus.value = 'loading'
  routerErrorMsg.value = ''
  const center = selectedRouter.value || 'r001001'
  try {
    const resp = await fetch(`/api/topology/router?center=${encodeURIComponent(center)}`)
    if (!resp.ok) {
      const t = await resp.text()
      throw new Error(t || `HTTP ${resp.status}`)
    }
    const data = await resp.json() as { nodes: Record<string, { name: string }>; edges: Record<string, { source: string; target: string; label?: string }>; layouts: { nodes: Record<string, { x: number; y: number }> } }
    // 原地更新以保持 v-network-graph 的响应式
    for (const k of Object.keys(routerNodes)) delete (routerNodes as Record<string, unknown>)[k]
    for (const [k, v] of Object.entries(data.nodes || {})) (routerNodes as Record<string, unknown>)[k] = v
    for (const k of Object.keys(routerEdges)) delete (routerEdges as Record<string, unknown>)[k]
    for (const [k, v] of Object.entries(data.edges || {})) (routerEdges as Record<string, unknown>)[k] = v
    routerLayouts.nodes = (data.layouts && data.layouts.nodes) ? { ...data.layouts.nodes } : {}
    routerStatus.value = 'ready'
  } catch (e: unknown) {
    routerStatus.value = 'error'
    routerErrorMsg.value = e instanceof Error ? e.message : String(e)
  }
}

// 中心节点变化时重新请求 API
watch(selectedRouter, () => {
  loadRouterData()
})

// ---------------------------------------------------------
// TypeScript 类型定义 (3D)
// ---------------------------------------------------------
type SatT0 = {
  id: string;
  orbit: number;
  slot: number;
  utc: string;
  r: [number, number, number]; 
  lla_Lat: number;
  lla_Lon: number;
  lla_Alt: number;
  coe_SemiMajorAxis: number;
  coe_Eccentricity: number;
  coe_Inclination: number;
  coe_RAAN: number;
  coe_ArgPerigee: number;
  coe_TrueAnomaly: number;
  mesh: THREE.Mesh;
};

type Selected = Omit<SatT0, "mesh" | "r"> & { r: [number, number, number] };

type DelayEdge = {
  aId: string;
  bId: string;
  delayS: number;
  distKm: number;
};

// ---------------------------------------------------------
// 状态与引用 (3D)
// ---------------------------------------------------------
const host = ref<HTMLDivElement | null>(null);
const loading = ref(true);
const ready = ref(false);
const loadProgress = ref("");
const t0Label = ref("");
const sats = ref<SatT0[]>([]);
const selected = ref<Selected | null>(null);

const showLinks = ref(true);
const linkMode = ref<"orbit" | "delay">("orbit");

const DELAY_CSV = "/data/delay_15x15.csv";
const C_KM_S = 299792.458; 
const delayEdges = ref<DelayEdge[]>([]);

let renderer: THREE.WebGLRenderer | null = null;
let labelRenderer: CSS2DRenderer | null = null;
let scene: THREE.Scene | null = null;
let camera: THREE.PerspectiveCamera | null = null;
let controls: OrbitControls | null = null;
let raf = 0;
let resizeObs: ResizeObserver | null = null;
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

let orbitLinkLines = new Map<number, THREE.LineSegments>();
let delayLine: THREE.LineSegments | null = null;
const delayModeLabels: CSS2DObject[] = [];
let delayHighlightGroup: THREE.Group | null = null;
const nodeLabels: CSS2DObject[] = [];

const KM_TO_UNITS = 1 / 1000;
const ORBIT_COLORS = [0x4cc9f0, 0x4ade80, 0xa78bfa, 0xfbbf24, 0xfb7185];
function colorForOrbit(orbit: number) { return ORBIT_COLORS[orbit % ORBIT_COLORS.length]; }

const HIGHLIGHT_COLOR = 0xffcc66;
const HIGHLIGHT_RADIUS = 0.02;
const HIGHLIGHT_TUBULAR_SEG = 8;
const HIGHLIGHT_RADIAL_SEG = 10;

// ---------------------------------------------------------
// 工具函数
// ---------------------------------------------------------
function fmt(x: number, digits: number) { return Number.isFinite(x) ? x.toFixed(digits) : "-"; }
function parseCsv(text: string): string[][] {
  const clean = (text ?? "").replace(/^\uFEFF/, "");
  const lines = clean.split(/\r?\n/).filter((l) => l.trim().length > 0);
  return lines.map((l) => l.split(",").map((x) => x.trim()));
}
function getColIndexMap(headerRow: string[]) {
  const map = new Map<string, number>();
  headerRow.forEach((name, idx) => map.set(name.replace(/^\uFEFF/, "").trim(), idx));
  return map;
}
function numAt(row: string[], idx: number) {
  if (idx < 0 || idx >= row.length) return NaN;
  const v = Number(row[idx]);
  return Number.isFinite(v) ? v : NaN;
}
function parseOrbitSlotFromFilename(name: string) {
  const m = name.match(/^Sat_(\d+)_(\d+)_/i);
  return { orbit: m ? Number(m[1]) : 0, slot: m ? Number(m[2]) : 0 };
}

// ---------------------------------------------------------
// Three.js 逻辑
// ---------------------------------------------------------
function makeNodeMesh() {
  const geo = new THREE.SphereGeometry(0.09, 20, 20);
  const mat = new THREE.MeshStandardMaterial({ color: 0xb9d4ff, roughness: 0.55, metalness: 0.15 });
  return new THREE.Mesh(geo, mat);
}
function addLights(s: THREE.Scene) {
  s.add(new THREE.AmbientLight(0xffffff, 0.85));
  const d = new THREE.DirectionalLight(0xffffff, 1.0);
  d.position.set(3, 2, 4);
  s.add(d);
}
function addNodeLabel(mesh: THREE.Mesh, text: string) {
  const div = document.createElement("div");
  div.className = "node-label";
  div.textContent = text;
  const obj = new CSS2DObject(div);
  obj.position.set(0, 0.18, 0);
  mesh.add(obj);
  nodeLabels.push(obj);
}
function setHighlight(mesh: THREE.Mesh | null) {
  for (const sat of sats.value) {
    const mat = sat.mesh.material as THREE.MeshStandardMaterial;
    mat.emissive.setHex(0x000000);
    mat.color.setHex(colorForOrbit(sat.orbit));
    sat.mesh.scale.setScalar(1);
  }
  if (mesh) {
    const mat = mesh.material as THREE.MeshStandardMaterial;
    mat.emissive.setHex(0x2b5cff);
    mat.color.setHex(0xffffff);
    mesh.scale.setScalar(1.25);
  }
}
function resetView() {
  if (!camera || !controls) return;
  camera.position.set(0, 0, 12);
  controls.target.set(0, 0, 0);
  controls.update();
}

// ... Clear functions ...
function clearOrbitLinks() {
  if (!scene) return;
  for (const line of orbitLinkLines.values()) {
    scene.remove(line);
    line.geometry.dispose();
    (line.material as THREE.Material).dispose();
  }
  orbitLinkLines.clear();
}
function clearDelayModeLinks() {
  if (!scene) return;
  if (delayLine) {
    scene.remove(delayLine);
    delayLine.geometry.dispose();
    (delayLine.material as THREE.Material).dispose();
    delayLine = null;
  }
  for (const lab of delayModeLabels) scene.remove(lab);
  delayModeLabels.length = 0;
}
function clearDelayHighlight() {
  if (!scene) return;
  if (!delayHighlightGroup) return;
  scene.remove(delayHighlightGroup);
  const toDispose: THREE.Object3D[] = [];
  delayHighlightGroup.traverse((obj) => { toDispose.push(obj); });
  for (const obj of toDispose) {
    if (obj.parent) obj.parent.remove(obj);
    if (obj instanceof THREE.Mesh) {
      (obj.geometry as THREE.BufferGeometry)?.dispose?.();
      (obj.material as THREE.Material)?.dispose?.();
    }
  }
  delayHighlightGroup = null;
}
function clearAllSats() {
  if (!scene) return;
  nodeLabels.length = 0;
  for (const sat of sats.value) {
    scene.remove(sat.mesh);
    (sat.mesh.geometry as THREE.BufferGeometry).dispose();
    (sat.mesh.material as THREE.Material).dispose();
  }
  sats.value = [];
}

// ... Build Link functions ...
function buildOrbitLinksOnly() {
  if (!scene) return;
  const map = new Map<number, SatT0[]>();
  for (const sat of sats.value) {
    const arr = map.get(sat.orbit) ?? [];
    arr.push(sat);
    map.set(sat.orbit, arr);
  }
  for (const [orbit, arr] of map.entries()) {
    if (arr.length < 2) continue;
    arr.sort((a, b) => a.slot - b.slot);
    const positions: number[] = [];
    for (let i = 0; i < arr.length - 1; i++) {
      const a = arr[i].mesh.position;
      const b = arr[i + 1].mesh.position;
      positions.push(a.x, a.y, a.z, b.x, b.y, b.z);
    }
    const geom = new THREE.BufferGeometry();
    geom.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3));
    const mat = new THREE.LineBasicMaterial({ color: colorForOrbit(orbit), transparent: true, opacity: 0.35 });
    const line = new THREE.LineSegments(geom, mat);
    line.frustumCulled = false;
    scene.add(line);
    orbitLinkLines.set(orbit, line);
  }
}
function buildDelayLinksAll() {
  if (!scene) return;
  const satById = new Map(sats.value.map((s) => [s.id, s]));
  const positions: number[] = [];
  for (const e of delayEdges.value) {
    const a = satById.get(e.aId);
    const b = satById.get(e.bId);
    if (!a || !b) continue;
    const pa = a.mesh.position;
    const pb = b.mesh.position;
    positions.push(pa.x, pa.y, pa.z, pb.x, pb.y, pb.z);
    const mid = new THREE.Vector3().addVectors(pa, pb).multiplyScalar(0.5);
    const div = document.createElement("div");
    div.className = "edge-label";
    div.textContent = `delay: ${e.delayS.toFixed(6)} s\ndist: ${e.distKm.toFixed(1)} km`;
    const obj = new CSS2DObject(div);
    obj.position.copy(mid);
    scene.add(obj);
    delayModeLabels.push(obj);
  }
  const geom = new THREE.BufferGeometry();
  geom.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3));
  const mat = new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.35 });
  delayLine = new THREE.LineSegments(geom, mat);
  delayLine.frustumCulled = false;
  scene.add(delayLine);
}
function buildDelayHighlightForSelected(selectedId: string | null) {
  if (!scene) return;
  clearDelayHighlight();
  if (!selectedId) return;
  const rel = delayEdges.value.filter((e) => e.aId === selectedId || e.bId === selectedId);
  if (!rel.length) return;
  const satById = new Map(sats.value.map((s) => [s.id, s]));
  const group = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: HIGHLIGHT_COLOR, roughness: 0.35, metalness: 0.15, emissive: new THREE.Color(0x553300), emissiveIntensity: 0.6 });
  for (const e of rel) {
    const a = satById.get(e.aId);
    const b = satById.get(e.bId);
    if (!a || !b) continue;
    const pa = a.mesh.position.clone();
    const pb = b.mesh.position.clone();
    const curve = new LineCurve3(pa, pb);
    const tube = new TubeGeometry(curve, HIGHLIGHT_TUBULAR_SEG, HIGHLIGHT_RADIUS, HIGHLIGHT_RADIAL_SEG, false);
    const tubeMesh = new THREE.Mesh(tube, mat);
    tubeMesh.frustumCulled = false;
    group.add(tubeMesh);
    const mid = new THREE.Vector3().addVectors(pa, pb).multiplyScalar(0.5);
    const div = document.createElement("div");
    div.className = "edge-label edge-label--highlight";
    div.textContent = `delay: ${e.delayS.toFixed(6)} s\ndist: ${e.distKm.toFixed(1)} km`;
    const obj = new CSS2DObject(div);
    obj.position.copy(mid);
    group.add(obj);
  }
  scene.add(group);
  delayHighlightGroup = group;
}
function rebuildLinks() {
  if (!scene) return;
  clearOrbitLinks();
  clearDelayModeLinks();
  clearDelayHighlight();
  if (!showLinks.value) return;
  if (linkMode.value === "orbit") {
    buildOrbitLinksOnly();
    buildDelayHighlightForSelected(selected.value?.id ?? null);
    return;
  }
  if (linkMode.value === "delay") {
    buildDelayLinksAll();
    return;
  }
}

// ... Interaction ...
function pickSatMesh(ev: PointerEvent): THREE.Mesh | null {
  if (!renderer || !camera) return null;
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.x = ((ev.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -(((ev.clientY - rect.top) / rect.height) * 2 - 1);
  raycaster.setFromCamera(pointer, camera);
  const hits = raycaster.intersectObjects(sats.value.map((s) => s.mesh), false);
  return hits.length ? (hits[0].object as THREE.Mesh) : null;
}

function onPointerDown(ev: PointerEvent) {
  const mesh = pickSatMesh(ev);
  if (!mesh) {
    setHighlight(null);
    selected.value = null;
    if (linkMode.value === "orbit") buildDelayHighlightForSelected(null);
    return;
  }
  setHighlight(mesh);
  const ud = mesh.userData as { id: string };
  const sat = sats.value.find((x) => x.id === ud.id);
  if (!sat) return;

  selected.value = {
    id: sat.id, orbit: sat.orbit, slot: sat.slot, utc: sat.utc, r: sat.r,
    lla_Lat: sat.lla_Lat, lla_Lon: sat.lla_Lon, lla_Alt: sat.lla_Alt,
    coe_SemiMajorAxis: sat.coe_SemiMajorAxis, coe_Eccentricity: sat.coe_Eccentricity, coe_Inclination: sat.coe_Inclination,
    coe_RAAN: sat.coe_RAAN, coe_ArgPerigee: sat.coe_ArgPerigee, coe_TrueAnomaly: sat.coe_TrueAnomaly,
  };

  // 【修改】：删除了这里联动 selectedRouter 的代码，实现了逻辑分离。
  // 点击 3D 卫星不再影响右侧路由图，右侧路由图只响应手动输入。

  if (linkMode.value === "orbit") buildDelayHighlightForSelected(sat.id);
}
function animate() {
  if (!renderer || !scene || !camera) return;
  controls?.update();
  renderer.render(scene, camera);
  labelRenderer?.render(scene, camera);
  raf = requestAnimationFrame(animate);
}

// ... Loading Data ...
// 第一阶段：从后端 /api/topology/t0 获取 T0 状态，替代直接读取 15 个 CSV。
async function loadT0() {
  loading.value = true;
  ready.value = false;
  loadProgress.value = "";
  clearOrbitLinks();
  clearDelayModeLinks();
  clearDelayHighlight();
  clearAllSats();
  selected.value = null;
  t0Label.value = "";
  try {
    loadProgress.value = "fetching /api/topology/t0";
    const res = await fetch("/api/topology/t0");
    if (!res.ok) throw new Error(`Fetch failed: /api/topology/t0 (${res.status})`);
    const data: Array<{
      id: string;
      orbit: number;
      slot: number;
      utc: string;
      r: [number, number, number];
      lla_Lat: number;
      lla_Lon: number;
      lla_Alt: number;
      coe_SemiMajorAxis: number;
      coe_Eccentricity: number;
      coe_Inclination: number;
      coe_RAAN: number;
      coe_ArgPerigee: number;
      coe_TrueAnomaly: number;
    }> = await res.json();

    for (const s of data) {
      const mesh = markRaw(makeNodeMesh());
      (mesh.material as THREE.MeshStandardMaterial).color.setHex(colorForOrbit(s.orbit));
      mesh.name = "Sat";
      mesh.userData = { id: s.id };
      const [rx, ry, rz] = s.r;
      mesh.position.set(rx * KM_TO_UNITS, ry * KM_TO_UNITS, rz * KM_TO_UNITS);
      addNodeLabel(mesh, s.id);
      sats.value.push({
        id: s.id,
        orbit: s.orbit,
        slot: s.slot,
        utc: s.utc,
        r: [rx, ry, rz],
        lla_Lat: s.lla_Lat,
        lla_Lon: s.lla_Lon,
        lla_Alt: s.lla_Alt,
        coe_SemiMajorAxis: s.coe_SemiMajorAxis,
        coe_Eccentricity: s.coe_Eccentricity,
        coe_Inclination: s.coe_Inclination,
        coe_RAAN: s.coe_RAAN,
        coe_ArgPerigee: s.coe_ArgPerigee,
        coe_TrueAnomaly: s.coe_TrueAnomaly,
        mesh,
      });
      scene?.add(mesh);
      if (!t0Label.value) t0Label.value = s.utc;
    }
  } catch (err) {
    console.error(err);
  }
  loading.value = false;
  ready.value = sats.value.length > 0;
  loadProgress.value = ready.value ? "done" : "no sats";
}
async function loadDelayMatrix() {
  try {
    const res = await fetch("/api/topology/delay");
    if (!res.ok) return;
    const edges: DelayEdge[] = await res.json();
    delayEdges.value = edges;
  } catch (e) { console.error(e); }
}

watch([showLinks, linkMode], () => { if (ready.value) rebuildLinks(); });
watch(() => selected.value?.id ?? null, (id) => { if (ready.value && showLinks.value && linkMode.value === "orbit") buildDelayHighlightForSelected(id); });

onMounted(async () => {
  // 加载 2D 拓扑数据
  loadRouterData();

  if (!host.value) return;
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x050817); 
  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(host.value.clientWidth, host.value.clientHeight);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  host.value.appendChild(renderer.domElement);
  labelRenderer = new CSS2DRenderer();
  labelRenderer.setSize(host.value.clientWidth, host.value.clientHeight);
  labelRenderer.domElement.style.position = "absolute";
  labelRenderer.domElement.style.top = "0";
  labelRenderer.domElement.style.left = "0";
  labelRenderer.domElement.style.pointerEvents = "none";
  host.value.appendChild(labelRenderer.domElement);
  camera = new THREE.PerspectiveCamera(45, host.value.clientWidth / host.value.clientHeight, 0.01, 2000);
  camera.position.set(0, 0, 12);
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.08;
  addLights(scene);
  
  // Stars
  const starPos = new Float32Array(900 * 3);
  for (let i = 0; i < 900; i++) starPos[i*3] = (Math.random()-0.5)*80, starPos[i*3+1] = (Math.random()-0.5)*80, starPos[i*3+2] = (Math.random()-0.5)*80;
  const starGeo = new THREE.BufferGeometry();
  starGeo.setAttribute("position", new THREE.BufferAttribute(starPos, 3));
  scene.add(new THREE.Points(starGeo, new THREE.PointsMaterial({ size: 0.05, color: 0xffffff })));

  try {
    await loadT0();
    await loadDelayMatrix();
    rebuildLinks();
    renderer.domElement.addEventListener("pointerdown", onPointerDown);
    resizeObs = new ResizeObserver(() => {
      if (!host.value || !renderer || !camera) return;
      const w = host.value.clientWidth;
      const h = host.value.clientHeight;
      renderer.setSize(w, h);
      labelRenderer?.setSize(w, h);
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
    });
    resizeObs.observe(host.value);
    raf = requestAnimationFrame(animate);
  } catch (e: any) { console.error(e); }
});

onBeforeUnmount(() => {
  if (raf) cancelAnimationFrame(raf);
  if (renderer) renderer.domElement.removeEventListener("pointerdown", onPointerDown);
  if (resizeObs && host.value) resizeObs.unobserve(host.value);
  resizeObs = null;
  controls?.dispose();
  clearOrbitLinks();
  clearDelayModeLinks();
  clearDelayHighlight();
  if (scene) {
    for (const sat of sats.value) {
      scene.remove(sat.mesh);
      (sat.mesh.geometry as THREE.BufferGeometry).dispose();
      (sat.mesh.material as THREE.Material).dispose();
    }
  }
  sats.value = [];
  labelRenderer?.domElement.remove();
  renderer?.dispose();
  renderer?.domElement.remove();
});
</script>

<style scoped>
.wrap {
  display: grid;
  /* 调整列宽：左侧稍微收窄，右侧加宽到 600px */
  grid-template-columns: 320px 1fr 600px;
  height: 100vh;
  background: #050817;
  color: #e8eeff;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
}

.left, .right { padding: 12px; overflow: hidden; display: flex; flex-direction: column; }
.center { position: relative; padding: 12px 0; }
.viewport { position: absolute; inset: 12px; border-radius: 14px; overflow: hidden; border: 1px solid rgba(255, 255, 255, 0.1); }

.card {
  background: rgba(10, 14, 30, 0.72);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 14px;
  padding: 12px;
  margin-bottom: 12px;
  backdrop-filter: blur(8px);
}

.topology-card {
  display: flex;
  flex-direction: column;
  flex: 1; /* 撑满右侧高度 */
  overflow: hidden;
}

.controls { display: flex; flex-direction: column; gap: 10px; margin-bottom: 10px; }
.control-item { display: flex; flex-direction: column; gap: 4px; }

.topology-container {
  position: relative;
  flex: 1; /* 占据卡片剩余空间 */
  width: 100%;
  border-radius: 8px;
  background: rgba(0, 0, 0, 0.3);
  border: 1px solid rgba(255, 255, 255, 0.08);
  overflow: hidden;
}

.graph-canvas {
  width: 100%;
  height: 100%;
}

.overlay {
  position: absolute;
  inset: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  background: rgba(0, 0, 0, 0.6);
  pointer-events: none;
  z-index: 10;
}
.overlay-text { font-size: 13px; color: #cbd5e1; }

/* ================== 通用 UI 组件 ================== */
.h { font-weight: 800; margin-bottom: 10px; }
.h2 { font-weight: 700; margin: 10px 0 6px; font-size: 13px; }
.row2 { display: grid; grid-template-columns: 110px 1fr; align-items: center; gap: 10px; margin: 8px 0; }
.label { font-size: 12px; opacity: 0.9; }
.small { font-size: 12px; opacity: 0.82; line-height: 1.5; margin-top: 8px; }

.btn { padding: 8px 10px; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.16); background: rgba(255, 255, 255, 0.08); color: #e8eeff; cursor: pointer; font-size: 12px; }
.btn:hover { background: rgba(255, 255, 255, 0.12); }
.wide { width: 100%; }

.select, .input {
  width: 100%; padding: 7px 9px; border-radius: 10px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.06); color: #e8eeff; outline: none;
}
.input:focus { border-color: #3b82f6; }

.check { display: flex; gap: 8px; align-items: center; font-size: 13px; margin: 6px 0 10px; }
.kv { display: grid; grid-template-columns: 90px 1fr; gap: 10px; font-size: 12px; line-height: 1.8; }
.divider { height: 1px; margin: 10px 0; background: rgba(255, 255, 255, 0.12); }
.mono { font-family: ui-monospace, monospace; }

/* Labels */
.node-label { font-size: 12px; padding: 2px 6px; border-radius: 8px; background: rgba(0, 0, 0, 0.45); border: 1px solid rgba(255, 255, 255, 0.18); color: #e8eeff; transform: translate(-50%, -50%); }
.edge-label { white-space: pre; font-size: 11px; line-height: 1.25; padding: 4px 6px; border-radius: 10px; background: rgba(0, 0, 0, 0.52); border: 1px solid rgba(255, 255, 255, 0.14); color: #e8eeff; transform: translate(-50%, -50%); max-width: 240px; }
.edge-label--highlight { border-color: rgba(255, 204, 102, 0.55); box-shadow: 0 0 14px rgba(255, 204, 102, 0.18); }
</style>
