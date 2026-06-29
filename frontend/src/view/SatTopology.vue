<template>
  <div class="wrap" :class="{ 'right-collapsed': rightPanelCollapsed }">
    <div class="left">
      <div class="card">
        <div class="h">T0 初始拓扑</div>

        <div class="small" v-if="loading">正在加载 CSV… {{ loadProgress }}</div>
        <div class="small" v-else-if="ready">
          已加载: {{ sats.length }} 颗卫星（Pilot 15 节点）<br />
          T0时刻: <span class="mono">{{ t0Label }}</span>
        </div>
        <div class="small" v-else>数据未加载</div>

        <div class="divider"></div>

        <div class="h2">链路连线</div>
        <label class="check">
          <input type="checkbox" v-model="showLinks" :disabled="!ready" />
          <span>显示 ISL 直连</span>
        </label>
        <button class="btn wide" @click="resetView" :disabled="!ready">重置相机视图</button>
      </div>

      <div class="card">
        <div class="h">正在执行任务的卫星</div>
        <div class="small" v-if="activeTasksLoading">正在刷新运行中任务…</div>
        <div v-else-if="activeTasks.length === 0" class="small">当前无运行中的遥感任务。</div>
        <ul v-else class="task-highlight-list">
          <li v-for="task in activeTasks" :key="task.id">
            <button type="button" class="task-highlight-btn running" @click="focusActiveTask(task)">
              <span class="mono">#{{ task.id }}</span>
              <span>{{ taskActiveLabel(task) }}</span>
              <span class="task-node" v-if="task.host_node_name">节点 {{ task.host_node_name }}</span>
            </button>
          </li>
        </ul>
      </div>

      <div class="card">
        <div class="h">当前选中卫星</div>
        <div v-if="selected">
          <div class="kv"><b>卫星</b><span class="mono">{{ selected.displayName || satNameFromSatId(selected.id) }}</span></div>
          <div class="kv"><b>sat_id</b><span class="mono">{{ selected.id }}</span></div>
          <div class="kv" v-if="selected.hostNode"><b>部署节点</b><span class="mono">{{ selected.hostNode }}</span></div>
          <div class="kv"><b>轨道 (Orbit)</b><span>{{ selected.orbit }}</span></div>
          <div class="kv"><b>槽位 (Slot)</b><span>{{ selected.slot }}</span></div>
          <template v-if="selectedReachableDelays.length">
            <div class="divider"></div>
            <div class="h2">星间时延（3 跳内）</div>
            <ul class="delay-neighbor-list">
              <li v-for="link in selectedReachableDelays" :key="link.peerId">
                <span class="delay-hop">h{{ link.hop }}</span>
                <span class="delay-peer">{{ link.peerName }}</span>
                <span class="mono delay-ms">{{ link.delayS != null ? formatDelayMs(link.delayS) : '—' }}</span>
              </li>
            </ul>
          </template>
          <div class="divider"></div>
          <div class="h2">地理坐标 (LLA)</div>
          <div class="kv"><b>纬度</b><span>{{ fmt(selected.lla_Lat, 6) }}°</span></div>
          <div class="kv"><b>经度</b><span>{{ fmt(selected.lla_Lon, 6) }}°</span></div>
          <div class="kv"><b>高度</b><span>{{ fmt(selected.lla_Alt, 3) }} km</span></div>
        </div>
        <div v-else class="small">点击 3D 卫星查看详情；选中后显示 3 跳内时延。</div>
      </div>
    </div>

    <div class="center">
      <div ref="host" class="viewport"></div>
      <button
        type="button"
        class="right-panel-toggle"
        :title="rightPanelCollapsed ? '展开路由子网' : '收起路由子网'"
        @click="toggleRightPanel"
      >
        {{ rightPanelCollapsed ? '◀' : '▶' }}
      </button>
    </div>

    <div class="right" v-show="!rightPanelCollapsed">
      <div class="card topology-card">
        <div class="h">路由子网（以选中卫星为中心）</div>

        <div class="controls">
          <label class="control-item">
            <span class="label">中心卫星</span>
            <select class="select" v-model="selectedRouter" :disabled="!ready">
              <option v-for="sat in sats" :key="sat.id" :value="sat.id">
                {{ sat.displayName || satNameFromSatId(sat.id) }} ({{ sat.id }})
              </option>
            </select>
          </label>
          <div class="router-meta small" v-if="routerStatus === 'ready'">
            可达节点 {{ routerNodeCount }} · 最大 16 跳 · 按轨道分行 · 同轨按星位排列
            <span v-if="routerDataSource"> · 数据源 {{ routerDataSource }}</span>
          </div>
        </div>

        <div class="router-legend small">
          <span class="legend-item"><i class="dot center"></i>中心</span>
          <span v-for="o in orbitLegendOrbits" :key="o" class="legend-item">
            <i class="dot" :style="{ background: orbitColorHex(o) }"></i>轨{{ o }}
          </span>
          <span class="legend-item"><i class="dot task-active"></i>任务运行中</span>
          <span class="legend-item muted">横向 = 同轨星位 · 黄色 = 跨轨链路</span>
        </div>

        <div class="topology-container">
          <v-network-graph
            class="graph-canvas"
            :selected-nodes="graphSelectedNodes"
            @update:selected-nodes="graphSelectedNodes = $event"
            :nodes="routerNodes"
            :edges="routerEdges"
            :layouts="routerLayouts"
            :configs="graphConfigs"
            @node:click="onRouterNodeClick"
            @node:pointerover="onRouterNodePointerover"
            @node:pointerout="onRouterNodePointerout"
          >
            <template #override-node="{ nodeId, scale }">
              <circle
                :r="getRouterNodeStyle(nodeId).radius * scale"
                :fill="getRouterNodeStyle(nodeId).fill"
                stroke="#ffffff"
                :stroke-width="getRouterNodeStyle(nodeId).strokeWidth * scale"
              />
            </template>
            <template #edge-label="{ edge, ...slotProps }">
              <v-edge-label
                v-if="edge.label"
                :text="edge.label"
                align="center"
                vertical-align="above"
                v-bind="slotProps"
              />
            </template>
          </v-network-graph>

          <div v-if="routerStatus === 'ready' && routerNodeCount === 0" class="overlay">
            <div class="overlay-text">当前中心卫星无路由数据<br/>请切换中心或导入 router CSV</div>
          </div>
          <div v-else-if="routerStatus !== 'ready'" class="overlay">
            <div class="overlay-text">
              <template v-if="routerStatus === 'loading'">正在加载拓扑数据...</template>
              <template v-else>错误：{{ routerErrorMsg }}</template>
            </div>
          </div>
        </div>

        <div class="small" style="margin-top: 10px;">
          点击 3D 卫星或下图节点可切换中心；数据来自 DB（router_nodes / router_links）
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, reactive, watch, markRaw, computed } from "vue";
import { useRoute } from "vue-router";
import { listRemoteSensingTasks } from "../api/remoteSensing";
import { getSatellite } from "../api/satellite";
import { satNameFromSatId } from "../utils/satNaming";
import {
  orbitColorHex,
  orbitColorThree,
  ROUTER_CENTER_COLOR,
  TASK_ACTIVE_COLOR_HEX,
  TASK_ACTIVE_EMISSIVE_HEX,
} from "../utils/orbitColors";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { CSS2DRenderer, CSS2DObject } from "three/examples/jsm/renderers/CSS2DRenderer.js";
import { TubeGeometry, LineCurve3 } from "three";

// 引入 v-network-graph
import { VNetworkGraph, VEdgeLabel, defineConfigs } from 'v-network-graph'
import 'v-network-graph/lib/style.css'

const route = useRoute();

const RIGHT_PANEL_KEY = 'satTopology.rightCollapsed'
const rightPanelCollapsed = ref(false)

function toggleRightPanel() {
  rightPanelCollapsed.value = !rightPanelCollapsed.value
  try {
    localStorage.setItem(RIGHT_PANEL_KEY, rightPanelCollapsed.value ? '1' : '0')
  } catch { /* ignore */ }
  requestAnimationFrame(() => {
    if (host.value && renderer && camera) {
      const w = host.value.clientWidth
      const h = host.value.clientHeight
      renderer.setSize(w, h)
      labelRenderer?.setSize(w, h)
      camera.aspect = w / h
      camera.updateProjectionMatrix()
    }
  })
}

const activeTasks = ref<Array<{
  id: number
  executed_sat_id?: string
  host_node_name?: string
  current_stage?: string
  file_prefix?: string
}>>([]);
const activeTasksLoading = ref(false);
const taskHighlightSatIds = ref<Set<string>>(new Set());
let activeTasksTimer: ReturnType<typeof setInterval> | null = null;

async function loadActiveTasks() {
  activeTasksLoading.value = true;
  try {
    const tasks = await listRemoteSensingTasks({ status: "running" });
    activeTasks.value = tasks ?? [];

    const nextHighlight = new Set<string>();
    for (const task of activeTasks.value) {
      if (task.executed_sat_id) nextHighlight.add(task.executed_sat_id);
    }
    taskHighlightSatIds.value = nextHighlight;
    refreshAllMeshStyles();
  } catch (e) {
    console.error("加载运行中遥感任务失败", e);
  } finally {
    activeTasksLoading.value = false;
  }
}

function taskActiveLabel(task: {
  id: number
  executed_sat_id?: string
  file_prefix?: string
  current_stage?: string
}) {
  const sat = task.executed_sat_id ? satNameFromSatId(task.executed_sat_id) : "等待识别…";
  const stage = task.current_stage ? ` · ${task.current_stage}` : "";
  return `${sat}${stage}`;
}

function focusActiveTask(task: { executed_sat_id?: string }) {
  if (!task.executed_sat_id) return;
  selectedRouter.value = task.executed_sat_id;
  selectSatById(task.executed_sat_id);
}

async function applyRouteSatelliteHighlight() {
  const satId = route.query.satId;
  if (typeof satId === "string" && satId) {
    selectedRouter.value = satId;
    if (ready.value) selectSatById(satId);
    return;
  }
  const raw = route.query.satelliteId;
  if (!raw) return;
  const satelliteDbId = Number(raw);
  if (!Number.isFinite(satelliteDbId)) return;
  try {
    const sat = await getSatellite(satelliteDbId);
    selectedRouter.value = sat.sat_id;
    if (ready.value) selectSatById(sat.sat_id);
  } catch (e) {
    console.error("路由卫星高亮失败", e);
  }
}

function selectSatById(satId: string) {
  const sat = sats.value.find((x) => x.id === satId);
  if (!sat) return;
  selected.value = {
    id: sat.id,
    displayName: sat.displayName,
    hostNode: sat.hostNode,
    orbit: sat.orbit,
    slot: sat.slot,
    utc: sat.utc,
    r: sat.r,
    lla_Lat: sat.lla_Lat,
    lla_Lon: sat.lla_Lon,
    lla_Alt: sat.lla_Alt,
    coe_SemiMajorAxis: sat.coe_SemiMajorAxis,
    coe_Eccentricity: sat.coe_Eccentricity,
    coe_Inclination: sat.coe_Inclination,
    coe_RAAN: sat.coe_RAAN,
    coe_ArgPerigee: sat.coe_ArgPerigee,
    coe_TrueAnomaly: sat.coe_TrueAnomaly,
  };
  refreshAllMeshStyles();
  buildSelectedNeighborhoodHighlight(sat.id);
  if (selectedRouter.value !== satId) {
    selectedRouter.value = satId;
  }
}

// ---------------------------------------------------------
// 2D 路由拓扑逻辑
// ---------------------------------------------------------
type RouterNodeView = {
  name: string;
  sat_id?: string;
  hop?: number;
  orbit?: number;
  is_center?: boolean;
  color?: string;
};

function orbitGraphColor(orbit?: number, isCenter?: boolean) {
  if (isCenter) return ROUTER_CENTER_COLOR;
  if (orbit) return orbitColorHex(orbit);
  return "#94a3b8";
}

function routerOrbitFromId(routerId: string): number {
  if (routerId.length < 4) return 0;
  const n = parseInt(routerId.slice(1, 4), 10);
  return Number.isFinite(n) ? n : 0;
}

function routerSlotFromId(routerId: string): number {
  if (routerId.length < 7) return 0;
  const n = parseInt(routerId.slice(4, 7), 10);
  return Number.isFinite(n) ? n : 0;
}

/** 路由子网：每轨一行，同轨内按星位从左到右 */
function computeOrbitRowLayout(
  nodeIds: string[],
  nodes: Record<string, RouterNodeView>
): Record<string, { x: number; y: number }> {
  const COL = 92;
  const ROW = 108;
  const byOrbit = new Map<number, string[]>();

  for (const id of nodeIds) {
    const orbit = nodes[id]?.orbit ?? routerOrbitFromId(id);
    if (!byOrbit.has(orbit)) byOrbit.set(orbit, []);
    byOrbit.get(orbit)!.push(id);
  }

  const orbits = [...byOrbit.keys()].sort((a, b) => a - b);
  const layouts: Record<string, { x: number; y: number }> = {};

  orbits.forEach((orbit, rowIdx) => {
    const arr = byOrbit.get(orbit)!;
    arr.sort((a, b) => {
      const sa = routerSlotFromId(a);
      const sb = routerSlotFromId(b);
      if (sa !== sb) return sa - sb;
      return a.localeCompare(b);
    });
    const y = (rowIdx - (orbits.length - 1) / 2) * ROW;
    arr.forEach((id, colIdx) => {
      const x = (colIdx - (arr.length - 1) / 2) * COL;
      layouts[id] = { x, y };
    });
  });

  return layouts;
}

const routerStatus = ref('loading')
const routerErrorMsg = ref('')
const selectedRouter = ref('sat-1-1')
const routerNodeCount = ref(0)
const routerDataSource = ref('')
const centerRouterId = ref('')
const graphSelectedNodes = ref<string[]>([])
const routerHoverRouterId = ref<string | null>(null)
const routerHoverSatId = ref<string | null>(null)

const routerNodes = reactive<Record<string, RouterNodeView>>({})
const routerEdges = reactive<Record<string, { source: string; target: string; label?: string }>>({})
const routerLayouts = reactive<{ nodes: Record<string, { x: number; y: number }> }>({ nodes: {} })

function getRouterNodeStyle(nodeId: string) {
  const node = routerNodes[nodeId];
  const isCenter = !!node?.is_center || nodeId === centerRouterId.value;
  const isHover = nodeId === routerHoverRouterId.value;
  return {
    radius: isCenter ? 14 : (isHover ? 13 : 11),
    fill: node?.color || "#4466cc",
    strokeWidth: isCenter ? 2.8 : (isHover ? 2.2 : 1.2),
  };
}

const graphConfigs = defineConfigs({
  view: {
    scalingObjects: true,
    minZoomLevel: 0.1,
    maxZoomLevel: 16,
    panEnabled: true,
    zoomEnabled: true,
    autoPanAndZoomOnLoad: "fit-content",
  },
  node: {
    normal: { type: "circle", radius: 16, color: "#4466cc" },
    label: { color: "#ffffff", fontSize: 10 },
  },
  edge: {
    normal: {
      width: 2,
      color: "#64748b",
    },
    label: { color: "#fbbf24", fontSize: 9 },
  },
})

function applyRouterGraphPayload(data: {
  nodes?: Record<string, RouterNodeView>;
  edges?: Record<string, { source: string; target: string; label?: string }>;
  layouts?: { nodes?: Record<string, { x: number; y: number }> };
}) {
  for (const k of Object.keys(routerNodes)) delete routerNodes[k];
  for (const [k, v] of Object.entries(data.nodes || {})) {
    const label = v.name || satNameFromSatId(v.sat_id || k) || k;
    routerNodes[k] = {
      ...v,
      name: label,
      color: orbitGraphColor(v.orbit, v.is_center),
    };
  }
  for (const k of Object.keys(routerEdges)) delete routerEdges[k];
  for (const [k, v] of Object.entries(data.edges || {})) {
    routerEdges[k] = { ...v };
  }
  const nodeIds = Object.keys(data.nodes || {});
  routerLayouts.nodes = computeOrbitRowLayout(nodeIds, data.nodes || {});
  routerNodeCount.value = nodeIds.length;
}

/** 从服务端 API 加载路由拓扑（BFS + 按轨道分行布局） */
async function loadRouterData () {
  routerStatus.value = 'loading'
  routerErrorMsg.value = ''
  const center = selectedRouter.value || 'sat-1-1'
  try {
    const resp = await fetch(`/api/topology/router?center=${encodeURIComponent(center)}`)
    if (!resp.ok) {
      const t = await resp.text()
      throw new Error(t || `HTTP ${resp.status}`)
    }
    const data = await resp.json() as {
      center?: string;
      nodes: Record<string, RouterNodeView>;
      edges: Record<string, { source: string; target: string; label?: string }>;
      layouts: { nodes: Record<string, { x: number; y: number }> };
      data_source?: string;
    }
    applyRouterGraphPayload(data)
    centerRouterId.value = data.center || ''
    graphSelectedNodes.value = centerRouterId.value ? [centerRouterId.value] : []
    routerDataSource.value = data.data_source === 'csv' ? 'CSV 回退' : (data.data_source === 'db' ? 'DB' : '')
    routerStatus.value = 'ready'
  } catch (e: unknown) {
    routerStatus.value = 'error'
    routerErrorMsg.value = e instanceof Error ? e.message : String(e)
  }
}

function onRouterNodeClick({ node }: { node: string }) {
  const meta = routerNodes[node];
  const satId = meta?.sat_id;
  if (!satId) return;
  selectSatById(satId);
}

function onRouterNodePointerover({ node }: { node: string }) {
  routerHoverRouterId.value = node;
  routerHoverSatId.value = routerNodes[node]?.sat_id || null;
  refreshAllMeshStyles();
}

function onRouterNodePointerout() {
  routerHoverRouterId.value = null;
  routerHoverSatId.value = null;
  refreshAllMeshStyles();
}

watch(selectedRouter, () => {
  loadRouterData()
})

// ---------------------------------------------------------
// TypeScript 类型定义 (3D)
// ---------------------------------------------------------
type SatT0 = {
  id: string;
  displayName?: string;
  hostNode?: string;
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

const orbitLegendOrbits = computed(() => {
  const orbits = new Set<number>();
  for (const s of sats.value) {
    if (s.orbit > 0) orbits.add(s.orbit);
  }
  return [...orbits].sort((a, b) => a - b);
});

const showLinks = ref(true);

type RouterDirectLink = {
  src_sat_id: string;
  dst_sat_id: string;
  cross_orbit: boolean;
};
const routerDirectLinks = ref<RouterDirectLink[]>([]);

const DELAY_CSV = "/data/delay_15x15.csv";
const C_KM_S = 299792.458;
const delayDataSource = ref("");
const delayEdges = ref<DelayEdge[]>([]);
const DELAY_VIEW_HOPS = 3;

function buildRouterAdjacency() {
  const adj = new Map<string, string[]>();
  for (const link of routerDirectLinks.value) {
    const s = link.src_sat_id;
    const d = link.dst_sat_id;
    if (!adj.has(s)) adj.set(s, []);
    if (!adj.has(d)) adj.set(d, []);
    adj.get(s)!.push(d);
    adj.get(d)!.push(s);
  }
  return adj;
}

function bfsWithinHops(startId: string, maxHops: number) {
  const adj = buildRouterAdjacency();
  const hopBy = new Map<string, number>([[startId, 0]]);
  const prev = new Map<string, string>();
  const queue = [startId];
  for (let qi = 0; qi < queue.length; qi++) {
    const cur = queue[qi];
    const h = hopBy.get(cur)!;
    if (h >= maxHops) continue;
    for (const next of adj.get(cur) || []) {
      if (hopBy.has(next)) continue;
      hopBy.set(next, h + 1);
      prev.set(next, cur);
      queue.push(next);
    }
  }
  return { hopBy, prev };
}

function pathDelayS(fromId: string, toId: string, prev: Map<string, string>): number | null {
  if (fromId === toId) return 0;
  let cur = toId;
  let total = 0;
  while (cur !== fromId) {
    const p = prev.get(cur);
    if (!p) return null;
    const edge = lookupDelay(p, cur);
    if (!edge) return null;
    total += edge.delayS;
    cur = p;
  }
  return total;
}

function subgraphRouterLinks(hopBy: Map<string, number>) {
  return routerDirectLinks.value.filter(
    (link) => hopBy.has(link.src_sat_id) && hopBy.has(link.dst_sat_id)
  );
}

const selectedReachableDelays = computed(() => {
  const sel = selected.value;
  if (!sel || delayEdges.value.length === 0) return [];
  const { hopBy, prev } = bfsWithinHops(sel.id, DELAY_VIEW_HOPS);
  const satById = new Map(sats.value.map((s) => [s.id, s]));
  const items: Array<{
    peerId: string;
    peerName: string;
    hop: number;
    delayS: number | null;
  }> = [];

  for (const [peerId, hop] of hopBy.entries()) {
    if (peerId === sel.id || hop === 0) continue;
    const peer = satById.get(peerId);
    let delayS: number | null = null;
    if (hop === 1) {
      delayS = lookupDelay(sel.id, peerId)?.delayS ?? null;
    } else {
      delayS = pathDelayS(sel.id, peerId, prev);
    }
    items.push({
      peerId,
      peerName: peer?.displayName || satNameFromSatId(peerId),
      hop,
      delayS,
    });
  }
  return items.sort((a, b) => a.hop - b.hop || (a.delayS ?? Infinity) - (b.delayS ?? Infinity));
});

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
let crossOrbitLinkLine: THREE.LineSegments | null = null;
let delayLine: THREE.LineSegments | null = null;
const delayModeLabels: CSS2DObject[] = [];
let delayHighlightGroup: THREE.Group | null = null;
const nodeLabels: CSS2DObject[] = [];

const KM_TO_UNITS = 1 / 1000;

const HIGHLIGHT_COLOR = 0xffcc66;
const HIGHLIGHT_RADIUS = 0.02;
const HIGHLIGHT_TUBULAR_SEG = 8;
const HIGHLIGHT_RADIAL_SEG = 10;

// ---------------------------------------------------------
// 工具函数
// ---------------------------------------------------------
function fmt(x: number, digits: number) { return Number.isFinite(x) ? x.toFixed(digits) : "-"; }

function formatDelayMs(delayS: number) {
  const ms = delayS * 1000;
  if (ms < 1) return `${(delayS * 1e6).toFixed(0)} µs`;
  if (ms < 1000) return `${ms.toFixed(2)} ms`;
  return `${delayS.toFixed(3)} s`;
}

function delayPairKey(aId: string, bId: string) {
  return aId < bId ? `${aId}|${bId}` : `${bId}|${aId}`;
}

function lookupDelay(aId: string, bId: string): DelayEdge | undefined {
  const key = delayPairKey(aId, bId);
  return delayEdges.value.find((e) => delayPairKey(e.aId, e.bId) === key);
}

function pilotSatIdFromEphem(name: string) {
  const m = name.match(/^Sat_(\d+)_(\d+)$/i);
  if (!m) return name;
  const orbit = Number(m[1]) - 5;
  const slot = Number(m[2]) - 5;
  if (orbit >= 1 && orbit <= 3 && slot >= 1 && slot <= 5) {
    return `sat-${orbit}-${slot}`;
  }
  return name;
}

function parseDelayCsv(text: string): DelayEdge[] {
  const rows = parseCsv(text);
  if (rows.length < 2) return [];
  const colNames = rows[0].slice(1);
  const edges: DelayEdge[] = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    const rowName = (row[0] || "").trim();
    if (!rowName) continue;
    for (let j = 1; j < row.length && j - 1 < colNames.length; j++) {
      const colName = (colNames[j - 1] || "").trim();
      const v = Number(row[j]);
      if (!colName || !Number.isFinite(v) || v === 0) continue;
      if (rowName >= colName) continue;
      const aId = pilotSatIdFromEphem(rowName);
      const bId = pilotSatIdFromEphem(colName);
      edges.push({ aId, bId, delayS: v, distKm: v * C_KM_S });
    }
  }
  return edges;
}

function attachDelayLabel(
  target: THREE.Scene | THREE.Group,
  pa: THREE.Vector3,
  pb: THREE.Vector3,
  aId: string,
  bId: string,
  highlight = false
) {
  const edge = lookupDelay(aId, bId);
  if (!edge) return;
  const mid = new THREE.Vector3().addVectors(pa, pb).multiplyScalar(0.5);
  const div = document.createElement("div");
  div.className = highlight ? "edge-label edge-label--highlight" : "edge-label";
  div.textContent = `${formatDelayMs(edge.delayS)} · ${edge.distKm.toFixed(0)} km`;
  const obj = new CSS2DObject(div);
  obj.position.copy(mid);
  target.add(obj);
  if (target === scene) {
    delayModeLabels.push(obj);
  }
}
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
function refreshAllMeshStyles() {
  for (const sat of sats.value) {
    const mat = sat.mesh.material as THREE.MeshStandardMaterial;
    if (selected.value?.id === sat.id) {
      mat.emissive.setHex(0x2b5cff);
      mat.color.setHex(0xffffff);
      sat.mesh.scale.setScalar(1.25);
    } else if (routerHoverSatId.value === sat.id) {
      mat.emissive.setHex(0x0099cc);
      mat.color.setHex(0xccf7ff);
      sat.mesh.scale.setScalar(1.18);
    } else if (taskHighlightSatIds.value.has(sat.id)) {
      mat.emissive.setStyle(TASK_ACTIVE_EMISSIVE_HEX);
      mat.color.setStyle(TASK_ACTIVE_COLOR_HEX);
      sat.mesh.scale.setScalar(1.12);
    } else {
      mat.emissive.setHex(0x000000);
      mat.color.setHex(orbitColorThree(sat.orbit));
      sat.mesh.scale.setScalar(1);
    }
  }
}

function getConstellationBounds() {
  if (sats.value.length === 0) return null;
  const box = new THREE.Box3();
  for (const sat of sats.value) {
    box.expandByPoint(sat.mesh.position);
  }
  const center = new THREE.Vector3();
  const size = new THREE.Vector3();
  box.getCenter(center);
  box.getSize(size);
  const radius = Math.max(size.x, size.y, size.z) * 0.55 + 0.35;
  return { center, radius: Math.max(radius, 1.2) };
}

function fitConstellationView() {
  if (!camera || !controls) return;
  const bounds = getConstellationBounds();
  if (!bounds) return;
  controls.target.copy(bounds.center);
  const dist = Math.max(bounds.radius * 2.6, 4);
  camera.position.set(bounds.center.x, bounds.center.y, bounds.center.z + dist);
  controls.update();
}
function setHighlight(mesh: THREE.Mesh | null) {
  if (!mesh) {
    selected.value = null;
  }
  refreshAllMeshStyles();
}
function resetView() {
  fitConstellationView();
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
  if (crossOrbitLinkLine) {
    scene.remove(crossOrbitLinkLine);
    crossOrbitLinkLine.geometry.dispose();
    (crossOrbitLinkLine.material as THREE.Material).dispose();
    crossOrbitLinkLine = null;
  }
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

// 3D 路由直连：与 net_qos.csv / router_links 一致（仅相邻 ISL，非闭合环）
function buildRouterDirectLinks() {
  if (!scene) return;
  const satById = new Map(sats.value.map((s) => [s.id, s]));
  const byOrbitPositions = new Map<number, number[]>();
  const crossOrbitPositions: number[] = [];

  for (const link of routerDirectLinks.value) {
    const a = satById.get(link.src_sat_id);
    const b = satById.get(link.dst_sat_id);
    if (!a || !b) continue;
    const pa = a.mesh.position;
    const pb = b.mesh.position;
    const seg = [pa.x, pa.y, pa.z, pb.x, pb.y, pb.z];
    if (link.cross_orbit) {
      crossOrbitPositions.push(...seg);
    } else {
      const orbit = a.orbit;
      const arr = byOrbitPositions.get(orbit) ?? [];
      arr.push(...seg);
      byOrbitPositions.set(orbit, arr);
    }
  }

  for (const [orbit, positions] of byOrbitPositions.entries()) {
    if (positions.length < 6) continue;
    const geom = new THREE.BufferGeometry();
    geom.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3));
    const mat = new THREE.LineBasicMaterial({
      color: orbitColorThree(orbit),
      transparent: true,
      opacity: 0.42,
    });
    const line = new THREE.LineSegments(geom, mat);
    line.frustumCulled = false;
    scene.add(line);
    orbitLinkLines.set(orbit, line);
  }

  if (crossOrbitPositions.length >= 6) {
    const geom = new THREE.BufferGeometry();
    geom.setAttribute("position", new THREE.Float32BufferAttribute(crossOrbitPositions, 3));
    const mat = new THREE.LineBasicMaterial({
      color: 0xfbbf24,
      transparent: true,
      opacity: 0.32,
    });
    crossOrbitLinkLine = new THREE.LineSegments(geom, mat);
    crossOrbitLinkLine.frustumCulled = false;
    scene.add(crossOrbitLinkLine);
  }
}

function buildSelectedNeighborhoodHighlight(selectedId: string | null) {
  if (!scene) return;
  clearDelayHighlight();
  if (!selectedId) return;

  const { hopBy } = bfsWithinHops(selectedId, DELAY_VIEW_HOPS);
  const rel = subgraphRouterLinks(hopBy);
  if (!rel.length) return;

  const satById = new Map(sats.value.map((s) => [s.id, s]));
  const group = new THREE.Group();
  const tubeMat = new THREE.MeshStandardMaterial({
    color: HIGHLIGHT_COLOR,
    roughness: 0.35,
    metalness: 0.15,
    emissive: new THREE.Color(0x553300),
    emissiveIntensity: 0.6,
  });

  for (const e of rel) {
    const a = satById.get(e.src_sat_id);
    const b = satById.get(e.dst_sat_id);
    if (!a || !b) continue;
    const pa = a.mesh.position.clone();
    const pb = b.mesh.position.clone();
    const curve = new LineCurve3(pa, pb);
    const tube = new TubeGeometry(curve, HIGHLIGHT_TUBULAR_SEG, HIGHLIGHT_RADIUS, HIGHLIGHT_RADIAL_SEG, false);
    const tubeMesh = new THREE.Mesh(tube, tubeMat);
    tubeMesh.frustumCulled = false;
    group.add(tubeMesh);
    attachDelayLabel(group, pa, pb, e.src_sat_id, e.dst_sat_id, true);
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
  buildRouterDirectLinks();
  buildSelectedNeighborhoodHighlight(selected.value?.id ?? null);
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
    selected.value = null;
    refreshAllMeshStyles();
    buildSelectedNeighborhoodHighlight(null);
    return;
  }
  const ud = mesh.userData as { id: string };
  selectSatById(ud.id);
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
      display_name?: string;
      host_node?: string;
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
      (mesh.material as THREE.MeshStandardMaterial).color.setHex(orbitColorThree(s.orbit));
      mesh.name = "Sat";
      mesh.userData = { id: s.id };
      const [rx, ry, rz] = s.r;
      mesh.position.set(rx * KM_TO_UNITS, ry * KM_TO_UNITS, rz * KM_TO_UNITS);
      addNodeLabel(mesh, s.display_name || satNameFromSatId(s.id));
      sats.value.push({
        id: s.id,
        displayName: s.display_name || satNameFromSatId(s.id),
        hostNode: s.host_node,
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
  refreshAllMeshStyles();
  fitConstellationView();
  if (sats.value.length > 0 && !sats.value.some((s) => s.id === selectedRouter.value)) {
    selectedRouter.value = sats.value[0].id;
  }
}
async function loadDelayMatrix() {
  try {
    const res = await fetch("/api/topology/delay");
    if (res.ok) {
      const data = await res.json();
      const edges: DelayEdge[] = Array.isArray(data) ? data : (data.edges ?? []);
      if (edges.length > 0) {
        delayEdges.value = edges;
        delayDataSource.value = data.data_source === "csv" ? "csv" : "db";
        return;
      }
    }
    const csvRes = await fetch(DELAY_CSV);
    if (csvRes.ok) {
      const parsed = parseDelayCsv(await csvRes.text());
      if (parsed.length > 0) {
        delayEdges.value = parsed;
        delayDataSource.value = "csv";
        return;
      }
    }
    delayEdges.value = [];
    delayDataSource.value = "";
  } catch (e) {
    console.error("加载时延矩阵失败", e);
  }
}

async function loadRouterDirectLinks() {
  try {
    const resp = await fetch("/api/topology/router-links");
    if (!resp.ok) return;
    const data = (await resp.json()) as { links?: RouterDirectLink[] };
    routerDirectLinks.value = data.links ?? [];
  } catch (e) {
    console.error("加载路由直连失败", e);
  }
}

watch(showLinks, () => { if (ready.value) rebuildLinks(); });
watch(() => selected.value?.id ?? null, (id) => {
  if (!ready.value || !showLinks.value) return;
  buildSelectedNeighborhoodHighlight(id);
});
watch(delayEdges, () => {
  if (ready.value && showLinks.value && selected.value) {
    buildSelectedNeighborhoodHighlight(selected.value.id);
  }
});

onMounted(async () => {
  try {
    rightPanelCollapsed.value = localStorage.getItem(RIGHT_PANEL_KEY) === '1'
  } catch { /* ignore */ }

  loadRouterData();
  void loadRouterDirectLinks();
  void loadActiveTasks();
  activeTasksTimer = setInterval(() => {
    void loadActiveTasks();
  }, 5000);

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
    if (routerDirectLinks.value.length === 0) {
      await loadRouterDirectLinks();
    }
    rebuildLinks();
    fitConstellationView();
    await applyRouteSatelliteHighlight();
    refreshAllMeshStyles();
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
  if (activeTasksTimer) {
    clearInterval(activeTasksTimer);
    activeTasksTimer = null;
  }
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
  grid-template-columns: 320px 1fr 600px;
  height: 100vh;
  background: #050817;
  color: #e8eeff;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
  transition: grid-template-columns 0.22s ease;
}

.wrap.right-collapsed {
  grid-template-columns: 320px 1fr 0;
}

.left, .right { padding: 12px; overflow: hidden; display: flex; flex-direction: column; min-height: 0; }
.center { position: relative; padding: 12px 0; min-width: 0; }

.right-panel-toggle {
  position: absolute;
  top: 50%;
  right: 0;
  transform: translateY(-50%);
  z-index: 20;
  width: 22px;
  height: 56px;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-right: none;
  border-radius: 10px 0 0 10px;
  background: rgba(10, 14, 30, 0.88);
  color: #e8eeff;
  cursor: pointer;
  font-size: 11px;
  padding: 0;
}
.right-panel-toggle:hover {
  background: rgba(30, 40, 70, 0.95);
}
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
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.controls { display: flex; flex-direction: column; gap: 10px; margin-bottom: 10px; }
.control-item { display: flex; flex-direction: column; gap: 4px; }

.topology-container {
  position: relative;
  flex: 1;
  min-height: 280px;
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
  width: 100%;
  padding: 7px 9px;
  border-radius: 10px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(10, 14, 30, 0.92);
  color: #e8eeff;
  outline: none;
}
.select {
  color-scheme: dark;
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23cbd5e1' d='M2 4l4 4 4-4'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
  padding-right: 28px;
}
.select:focus, .input:focus { border-color: #3b82f6; box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.25); }
.select:disabled, .input:disabled { opacity: 0.55; cursor: not-allowed; }
.select option {
  background: #0a0e1e;
  color: #e8eeff;
}
.select option:checked {
  background: #1e3a5f;
  color: #f0f9ff;
}

.check { display: flex; gap: 8px; align-items: center; font-size: 13px; margin: 6px 0 10px; }
.kv { display: grid; grid-template-columns: 90px 1fr; gap: 10px; font-size: 12px; line-height: 1.8; }
.divider { height: 1px; margin: 10px 0; background: rgba(255, 255, 255, 0.12); }
.mono { font-family: ui-monospace, monospace; }

/* Labels */
.node-label { font-size: 12px; padding: 2px 6px; border-radius: 8px; background: rgba(0, 0, 0, 0.45); border: 1px solid rgba(255, 255, 255, 0.18); color: #e8eeff; transform: translate(-50%, -50%); }
.edge-label { white-space: pre; font-size: 11px; line-height: 1.25; padding: 4px 6px; border-radius: 10px; background: rgba(0, 0, 0, 0.52); border: 1px solid rgba(255, 255, 255, 0.14); color: #e8eeff; transform: translate(-50%, -50%); max-width: 240px; }
.edge-label--highlight { border-color: rgba(255, 204, 102, 0.55); box-shadow: 0 0 14px rgba(255, 204, 102, 0.18); }

.task-highlight-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 220px;
  overflow-y: auto;
}

.task-highlight-list li {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.task-highlight-btn {
  flex: 1;
  text-align: left;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(34, 170, 85, 0.12);
  color: #e8eeff;
  border-radius: 10px;
  padding: 7px 9px;
  cursor: pointer;
  font-size: 12px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.task-highlight-btn.running {
  background: rgba(34, 170, 85, 0.18);
  border-color: rgba(34, 170, 85, 0.45);
}

.task-node {
  font-size: 10px;
  opacity: 0.75;
}

.task-result-link {
  font-size: 11px;
  color: #7dd3fc;
  text-decoration: none;
  white-space: nowrap;
}

.task-result-link:hover {
  text-decoration: underline;
}

.router-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 8px;
  align-items: center;
}

.legend-item {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.legend-item.muted {
  opacity: 0.7;
}

.dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.dot.center { background: #fbbf24; }
.dot.task-active { background: #34d399; border-color: rgba(52, 211, 153, 0.6); }

.small.muted, .muted { opacity: 0.65; }

.delay-neighbor-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
  max-height: 180px;
  overflow-y: auto;
}

.delay-neighbor-list li {
  display: grid;
  grid-template-columns: 36px 1fr auto;
  gap: 6px;
  align-items: center;
  font-size: 12px;
  padding: 5px 8px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
}

.delay-hop {
  font-size: 11px;
  opacity: 0.75;
  font-family: ui-monospace, monospace;
}

.delay-peer { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.delay-ms { color: #7dd3fc; font-weight: 600; }
.delay-dist { opacity: 0.75; font-size: 11px; }
.delay-tag {
  grid-column: 1 / -1;
  justify-self: start;
  font-size: 10px;
  color: #fbbf24;
  opacity: 0.9;
}

.router-meta {
  margin-top: 2px;
  opacity: 0.85;
}
</style>
