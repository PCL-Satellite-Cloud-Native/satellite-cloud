<template>
  <div class="cesium-container">
    <div v-if="loading" class="loading-overlay">
      <div class="loading-message">正在加载集群节点状态...</div>
    </div>
    <div v-if="error" class="error-overlay">
      <div class="error-message">{{ error }}</div>
    </div>
    <div ref="viewerContainer" class="viewer"></div>

    <aside class="hud-panel">
      <div class="hud-title">集群节点星座 · {{ clusterNodes.length }} 节点</div>

      <div class="hud-row">
        <span class="hud-label">节点总数</span>
        <span class="hud-value">{{ clusterNodes.length }}</span>
      </div>
      <div class="hud-row">
        <span class="hud-label">正常</span>
        <span class="hud-value highlight-green">{{ readyCount }}</span>
      </div>
      <div class="hud-row">
        <span class="hud-label">异常</span>
        <span class="hud-value highlight-red">{{ errorCount }}</span>
      </div>

      <div class="hud-divider"></div>

      <div class="hud-subtitle">图例（卫星 = 集群节点）</div>
      <div class="legend-row"><i class="dot" style="background:#ffffff"></i>正常 · 白色</div>
      <div class="legend-row"><i class="dot" style="background:#ffd54a"></i>选中 · 黄色</div>
      <div class="legend-row"><i class="dot" style="background:#ff4d4f"></i>节点异常/无法连通 · 红色</div>

      <div class="hud-divider"></div>

      <div class="hud-subtitle">仿真时钟</div>
      <div class="hud-row">
        <span class="hud-label">当前 UTC</span>
        <span class="hud-value mono sim-time">{{ simTimeLabel }}</span>
      </div>
      <div class="hud-row clock-actions">
        <button type="button" class="hud-btn" @click="toggleClockPlay">
          {{ clockPlaying ? '⏸ 暂停' : '▶ 播放' }}
        </button>
        <button type="button" class="hud-btn" @click="resetClockToStart">↺ 重置</button>
      </div>

      <div class="hud-row">
        <span class="hud-label">仿真倍速</span>
        <select class="hud-select" v-model.number="clockMultiplier" @change="applyClockMultiplier">
          <option :value="1">×1</option>
          <option :value="10">×10</option>
          <option :value="60">×60</option>
          <option :value="300">×300</option>
        </select>
      </div>

      <div class="hud-row">
        <span class="hud-label">地图模式</span>
        <select class="hud-select" v-model="mapViewMode" @change="onMapViewModeChange">
          <option value="2d">2D 平面地图</option>
          <option value="3d">3D 地球球体</option>
        </select>
      </div>

      <div class="hud-actions">
        <button type="button" class="hud-btn" @click="flyToPreset('global')">全球视角</button>
        <button type="button" class="hud-btn" @click="flyToPreset('china')">中国区域</button>
      </div>

      <div class="hud-actions">
        <router-link class="hud-link" to="/simulation/topology">卫星网络拓扑 →</router-link>
      </div>

      <div v-if="selectedSatInfo" class="hud-selected">
        <div class="hud-subtitle">选中卫星 / 节点</div>
        <div class="hud-row"><span class="hud-label">卫星</span><span class="hud-value">{{ selectedSatInfo.satId }}</span></div>
        <div class="hud-row"><span class="hud-label">节点</span><span class="hud-value">{{ selectedSatInfo.nodeName }}</span></div>
        <div class="hud-row">
          <span class="hud-label">状态</span>
          <span class="hud-value" :class="selectedSatInfo.ready ? 'highlight-green' : 'highlight-red'">
            {{ selectedSatInfo.ready ? '正常 Ready' : (selectedSatInfo.status || '异常') }}
          </span>
        </div>
        <div class="hud-row" v-if="selectedSatInfo.roles && selectedSatInfo.roles.length">
          <span class="hud-label">角色</span><span class="hud-value">{{ selectedSatInfo.roles.join(', ') }}</span>
        </div>
        <div class="hud-row" v-if="selectedSatInfo.internalIP">
          <span class="hud-label">IP</span><span class="hud-value mono">{{ selectedSatInfo.internalIP }}</span>
        </div>
      </div>

      <div class="hud-hint">点击卫星选中（黄色高亮）；白色=节点正常，红色=节点异常/无法连通；颜色每 10 秒随节点状态刷新。</div>
    </aside>
  </div>
  <BackHomeButton />
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import BackHomeButton from './BackHomeButton.vue'
import { getClusterNodes } from '../api/cluster.js'
import {
  CLUSTER_NODE_ORDER,
  CLUSTER_SHELL,
  clusterSatId,
  clusterSatDisplayName,
  statusColor,
  orderClusterNodes,
} from '../utils/clusterConstellation.js'

window.CESIUM_BASE_URL = '/cesium'
import * as Cesium from 'cesium'

const viewerContainer = ref(null)
const loading = ref(false)
const error = ref(null)
const satelliteCount = ref(0)
const clockMultiplier = ref(10)
const imagerySource = ref('builtin')

const clusterNodes = ref([])
const selectedNodeName = ref(null)
const selectedSatInfo = ref(null)

const nodeByName = computed(() => {
  const m = {}
  for (const n of clusterNodes.value) m[n.name] = n
  return m
})
const readyCount = computed(() => clusterNodes.value.filter((n) => n.ready).length)
const errorCount = computed(() => clusterNodes.value.length - readyCount.value)

const MAP_MODE_KEY = 'satViewer.mapMode'
const MAP_TILES_URL = (import.meta.env.VITE_MAP_TILES_URL || '').trim()

function loadMapViewMode() {
  try {
    const saved = localStorage.getItem(MAP_MODE_KEY)
    if (saved === '2d' || saved === '3d') return saved
  } catch {}
  return '3d'
}

const mapViewMode = ref(loadMapViewMode())
const simTimeLabel = ref('—')
const clockPlaying = ref(true)

let viewer = null
let handler = null
let nodeRefreshTimer = null
let removeClockTickListener = null
const entityBySatId = new Map()

const IMAGERY_LABELS = {
  'xyz-tiles': '内网 XYZ 瓦片',
  'hd-tiles': '本地高清瓦片（离线）',
  'hd-single': '本地高清全景（离线）',
  'natural-earth': 'Natural Earth II（离线）',
  'builtin': '内置底图（低清）',
  'failed': '底图加载失败',
}

const imageryLabel = computed(() => IMAGERY_LABELS[imagerySource.value] || IMAGERY_LABELS.builtin)

function formatSimTime(julianDate) {
  if (!julianDate) return '—'
  const d = Cesium.JulianDate.toDate(julianDate)
  return d.toISOString().replace('T', ' ').slice(0, 19) + ' UTC'
}

function setupClockHud(v) {
  if (removeClockTickListener) {
    removeClockTickListener()
    removeClockTickListener = null
  }
  const tick = () => {
    simTimeLabel.value = formatSimTime(v.clock.currentTime)
    clockPlaying.value = v.clock.shouldAnimate
  }
  v.clock.onTick.addEventListener(tick)
  removeClockTickListener = () => v.clock.onTick.removeEventListener(tick)
  tick()
}

function syncClockPlayback(playing = true) {
  if (!viewer || viewer.isDestroyed()) return
  viewer.clock.shouldAnimate = playing
  clockPlaying.value = playing
  if (viewer.clockViewModel) {
    viewer.clockViewModel.shouldAnimate = playing
  }
}

function toggleClockPlay() {
  if (!viewer || viewer.isDestroyed()) return
  syncClockPlayback(!viewer.clock.shouldAnimate)
}

function resetClockToStart() {
  if (!viewer || viewer.isDestroyed()) return
  viewer.clock.currentTime = viewer.clock.startTime.clone()
  simTimeLabel.value = formatSimTime(viewer.clock.currentTime)
}

async function assetExists(url) {
  try {
    let resp = await fetch(url, { method: 'HEAD' })
    if (resp.ok) return true
    resp = await fetch(url, { method: 'GET', cache: 'no-store' })
    return resp.ok
  } catch {
    return false
  }
}

async function loadImageryMeta() {
  try {
    const resp = await fetch('/assets/earth_imagery_meta.json')
    if (resp.ok) return await resp.json()
  } catch {}
  return null
}

function labelFromMeta(meta, fallback) {
  if (!meta?.source || meta.source === 'synthetic') return fallback
  if (meta.source === 'blue-marble' || meta.source === 'local') return 'hd-tiles'
  if (meta.source === 'natural-earth') return 'natural-earth'
  return fallback
}

/** 按优先级尝试底图；某一源加载失败时自动回退下一项 */
async function setupOfflineImagery(v) {
  v.imageryLayers.removeAll()
  const meta = await loadImageryMeta()

  const candidates = []

  if (MAP_TILES_URL) {
    const url = MAP_TILES_URL.includes('{z}')
      ? MAP_TILES_URL
      : `${MAP_TILES_URL.replace(/\/$/, '')}/{z}/{x}/{y}.png`
    candidates.push({
      label: 'xyz-tiles',
      create: () => new Cesium.UrlTemplateImageryProvider({
        url,
        minimumLevel: 0,
        maximumLevel: 18,
      }),
    })
  }

  if (await assetExists('/assets/earth_hd.jpg')) {
    candidates.push({
      label: labelFromMeta(meta, 'hd-single'),
      create: () => new Cesium.SingleTileImageryProvider({
        url: '/assets/earth_hd.jpg',
        rectangle: Cesium.Rectangle.fromDegrees(-180, -90, 180, 90),
      }),
    })
  }

  if (await assetExists('/tiles/earth-hd/tilemapresource.xml')) {
    candidates.push({
      label: labelFromMeta(meta, 'hd-tiles'),
      create: () => new Cesium.TileMapServiceImageryProvider({ url: '/tiles/earth-hd' }),
    })
  }

  candidates.push({
    label: 'natural-earth',
    create: () => new Cesium.TileMapServiceImageryProvider({
      url: Cesium.buildModuleUrl('Assets/Textures/NaturalEarthII'),
    }),
  })

  let idx = 0
  const tryNext = () => {
    if (idx >= candidates.length) {
      imagerySource.value = 'failed'
      console.warn('所有底图源均不可用')
      return
    }
    const { label, create } = candidates[idx++]
    try {
      const provider = create()
      const layer = v.imageryLayers.addImageryProvider(provider)
      imagerySource.value = label

      const onError = (err) => {
        provider.errorEvent.removeEventListener(onError)
        console.warn(`底图 ${label} 加载失败，尝试下一源`, err)
        v.imageryLayers.remove(layer, false)
        tryNext()
      }
      provider.errorEvent.addEventListener(onError)
    } catch (err) {
      console.warn(`底图 ${label} 初始化失败`, err)
      tryNext()
    }
  }

  tryNext()
}

function applyClockMultiplier() {
  if (viewer && !viewer.isDestroyed()) {
    viewer.clock.multiplier = clockMultiplier.value
  }
}

function applySceneAppearance(mode) {
  if (!viewer || viewer.isDestroyed()) return
  const is2d = mode === '2d'
  viewer.scene.globe.enableLighting = !is2d
  viewer.scene.globe.showGroundAtmosphere = !is2d
  viewer.scene.skyAtmosphere.show = !is2d
  viewer.scene.sun.show = !is2d
  viewer.scene.moon.show = false
  if (viewer.scene.skyBox) viewer.scene.skyBox.show = !is2d
}

function applyMapViewMode(mode, animate = true) {
  if (!viewer || viewer.isDestroyed()) return
  const duration = animate ? 1 : 0
  if (mode === '2d') {
    viewer.scene.morphTo2D(duration)
  } else {
    viewer.scene.morphTo3D(duration)
  }
  applySceneAppearance(mode)
  try {
    localStorage.setItem(MAP_MODE_KEY, mode)
  } catch {}
}

function onMapViewModeChange() {
  applyMapViewMode(mapViewMode.value, true)
  const refit = () => {
    viewer.scene.morphComplete.removeEventListener(refit)
    flyToPreset('global')
  }
  viewer.scene.morphComplete.addEventListener(refit)
}

function flyToPreset(preset) {
  if (!viewer || viewer.isDestroyed()) return
  const is2d = mapViewMode.value === '2d'
  const duration = 1.5

  if (preset === 'global') {
    if (is2d) {
      viewer.camera.flyTo({
        destination: Cesium.Rectangle.fromDegrees(-180, -85, 180, 85),
        duration,
      })
    } else {
      viewer.camera.flyTo({
        destination: Cesium.Cartesian3.fromDegrees(105.0, 32.0, 18000000),
        duration,
      })
    }
    return
  }
  if (preset === 'china') {
    if (is2d) {
      viewer.camera.flyTo({
        destination: Cesium.Rectangle.fromDegrees(73, 18, 135, 54),
        duration,
      })
    } else {
      viewer.camera.flyTo({
        destination: Cesium.Cartesian3.fromDegrees(104.0, 35.0, 8000000),
        duration,
      })
    }
    return
  }
}

function createCircularOrbitPositions(start, periodSeconds, altitudeMeters, inclinationDeg, raanDeg, initialTrueAnomalyDeg, samples = 360) {
  const property = new Cesium.SampledPositionProperty()
  const inclRad = Cesium.Math.toRadians(inclinationDeg)
  const raanRad = Cesium.Math.toRadians(raanDeg)
  const initialTrueAnomalyRad = Cesium.Math.toRadians(initialTrueAnomalyDeg)

  for (let i = 0; i <= samples; i++) {
    const t = (i / samples) * periodSeconds
    const time = Cesium.JulianDate.addSeconds(start, t, new Cesium.JulianDate())
    const currentAnomaly = (t / periodSeconds) * Math.PI * 2 + initialTrueAnomalyRad
    const latRad = Math.asin(Math.sin(inclRad) * Math.sin(currentAnomaly))
    const argOfLat = Math.atan2(Math.cos(currentAnomaly), Math.sin(currentAnomaly) * Math.cos(inclRad))
    const lonRad = raanRad + argOfLat
    const lon = Cesium.Math.toDegrees(lonRad)
    const lat = Cesium.Math.toDegrees(latRad)
    const pos = Cesium.Cartesian3.fromDegrees(lon, lat, altitudeMeters)
    property.addSample(time, pos)
  }
  property.setInterpolationOptions({ interpolationDegree: 1, interpolationAlgorithm: Cesium.LinearApproximation })
  return property
}

// ---------------------------------------------------------
// 集群节点星座：5 颗卫星 = 5 个集群节点，同一壳层相邻
// ---------------------------------------------------------

function updateEntityStyle(entity, altitudeMeters) {
  const data = entity._satData
  const node = data?.nodeName ? nodeByName.value[data.nodeName] : null
  const ready = node ? node.ready : true
  const selected = selectedNodeName.value === data?.nodeName
  const hex = statusColor({ ready, selected })
  const base = Cesium.Color.fromCssColorString(hex)

  entity.point.color = selected ? base : base.withAlpha(0.92)
  entity.point.pixelSize = selected ? 16 : 9
  entity.point.outline = true
  entity.point.outlineColor = Cesium.Color.BLACK

  entity.path.width = selected ? 4 : 1.5
  entity.path.material = base.withAlpha(selected ? 0.7 : 0.4)

  entity.label.show = selected
}

function refreshAllEntityStyles() {
  for (const [, entity] of entityBySatId.entries()) {
    const alt = entity._satData?.altitudeMeters ?? 550000
    updateEntityStyle(entity, alt)
  }
}

function setupClickHandler() {
  handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas)
  handler.setInputAction((movement) => {
    const pickedObject = viewer.scene.pick(movement.position)
    if (Cesium.defined(pickedObject) && pickedObject.id) {
      const entity = pickedObject.id
      const data = entity._satData
      if (data?.nodeName) selectNode(data.nodeName)
    }
  }, Cesium.ScreenSpaceEventType.LEFT_CLICK)
}

function selectNode(nodeName) {
  if (selectedNodeName.value === nodeName) {
    selectedNodeName.value = null
    selectedSatInfo.value = null
    if (viewer.trackedEntity) viewer.trackedEntity = undefined
  } else {
    selectedNodeName.value = nodeName
    const node = nodeByName.value[nodeName]
    const idx = CLUSTER_NODE_ORDER.indexOf(nodeName)
    selectedSatInfo.value = {
      satId: clusterSatId(idx < 0 ? 0 : idx),
      nodeName,
      ready: node?.ready ?? true,
      status: node?.status || (node?.ready ? 'Ready' : 'Unknown'),
      roles: node?.roles || [],
      internalIP: node?.internalIP || '',
    }
  }
  refreshAllEntityStyles()
}

function applyNodeStatusToSelection() {
  if (!selectedNodeName.value) return
  const node = nodeByName.value[selectedNodeName.value]
  if (!node) return
  selectedSatInfo.value = {
    ...selectedSatInfo.value,
    ready: node.ready,
    status: node.status || (node.ready ? 'Ready' : 'Unknown'),
  }
}

async function refreshNodeStatus() {
  try {
    const data = await getClusterNodes()
    const ns = Array.isArray(data.nodes) ? data.nodes : []
    const map = {}
    for (const n of ns) map[n.name] = n
    clusterNodes.value = clusterNodes.value.map((n) => map[n.name] || n)
    refreshAllEntityStyles()
    applyNodeStatusToSelection()
  } catch (e) {
    console.warn('刷新集群节点状态失败', e)
  }
}

async function initializeViewer() {
  try {
    loading.value = true
    error.value = null

    const data = await getClusterNodes()
    const ordered = orderClusterNodes(data.nodes)

    if (!ordered.length) {
      throw new Error('未获取到集群节点，请确认后端 /api/cluster/nodes 可用（后端需以集群内 ServiceAccount 运行并具备 nodes 读取权限）')
    }

    clusterNodes.value = ordered
    satelliteCount.value = ordered.length

    if (!viewer) {
      viewer = new Cesium.Viewer(viewerContainer.value, {
        timeline: true,
        animation: true,
        shouldAnimate: true,
        baseLayerPicker: false,
        geocoder: false,
        homeButton: false,
        sceneModePicker: false,
        navigationHelpButton: false,
        shadows: false,
        selectionIndicator: false,
        infoBox: false,
        imageryProvider: false,
        terrainProvider: new Cesium.EllipsoidTerrainProvider(),
      })

      await setupOfflineImagery(viewer)
      applyMapViewMode(mapViewMode.value, false)
      setupClickHandler()
    }

    const start = Cesium.JulianDate.now()
    const end = Cesium.JulianDate.addHours(start, 6, new Cesium.JulianDate())
    viewer.clock.startTime = start
    viewer.clock.stopTime = end
    viewer.clock.currentTime = start
    viewer.clock.multiplier = clockMultiplier.value
    syncClockPlayback(true)

    if (!removeClockTickListener) {
      setupClockHud(viewer)
    }

    entityBySatId.clear()
    viewer.entities.removeAll()

    const total = ordered.length
    ordered.forEach((node, index) => {
      const satId = clusterSatId(index)
      const altitudeMeters = CLUSTER_SHELL.altitudeKm * 1000
      const ta = (index * 360) / total // 同一壳层，真近点角等间隔 → 相邻卫星

      const positionProp = createCircularOrbitPositions(
        start, CLUSTER_SHELL.periodSeconds, altitudeMeters,
        CLUSTER_SHELL.inclinationDeg, CLUSTER_SHELL.raanDeg, ta, 720
      )

      const label = clusterSatDisplayName(node.name)

      const entity = viewer.entities.add({
        id: satId,
        name: label,
        position: positionProp,
        point: {
          pixelSize: 9,
          color: Cesium.Color.WHITE.withAlpha(0.92),
          outline: true,
          outlineColor: Cesium.Color.BLACK,
        },
        path: {
          show: true,
          resolution: 60,
          material: Cesium.Color.WHITE.withAlpha(0.4),
          width: 1.5,
          leadTime: 0,
          trailTime: CLUSTER_SHELL.periodSeconds,
        },
        label: {
          show: false,
          text: label,
          font: '14px sans-serif',
          fillColor: Cesium.Color.WHITE,
          style: Cesium.LabelStyle.FILL,
          pixelOffset: new Cesium.Cartesian2(0, -20),
          distanceDisplayCondition: new Cesium.DistanceDisplayCondition(0, 10000000),
        },
      })
      entity._satData = { nodeName: node.name, satId, altitudeMeters, index }
      entityBySatId.set(satId, entity)
      updateEntityStyle(entity, altitudeMeters)
    })

    refreshAllEntityStyles()
    flyToPreset('global')
    loading.value = false

    if (nodeRefreshTimer) clearInterval(nodeRefreshTimer)
    nodeRefreshTimer = setInterval(refreshNodeStatus, 10000)
  } catch (err) {
    console.error(err)
    error.value = '加载失败: ' + err.message
    loading.value = false
  }
}

onMounted(() => {
  initializeViewer()
})

onBeforeUnmount(() => {
  if (removeClockTickListener) {
    removeClockTickListener()
    removeClockTickListener = null
  }
  if (nodeRefreshTimer) {
    clearInterval(nodeRefreshTimer)
    nodeRefreshTimer = null
  }
  if (handler) {
    handler.destroy()
    handler = null
  }
  if (viewer && !viewer.isDestroyed()) {
    viewer.destroy()
    viewer = null
  }
})
</script>

<style scoped>
.cesium-container {
  height: 100vh;
  width: 100%;
  position: relative;
  overflow: hidden;
  background: #000;
}
.viewer { height: 100%; width: 100%; }

.loading-overlay, .error-overlay {
  position: absolute; top: 0; left: 0; right: 0; bottom: 0;
  display: flex; align-items: center; justify-content: center;
  background-color: rgba(0, 0, 0, 0.7); z-index: 1000;
}
.loading-message, .error-message {
  color: #fff; padding: 20px; background: rgba(30,30,30,0.9); border-radius: 8px;
}
.error-message { color: #ff6b6b; }

.hud-panel {
  position: absolute;
  top: 16px;
  left: 16px;
  width: 290px;
  max-height: calc(100vh - 32px);
  overflow-y: auto;
  padding: 14px;
  background: rgba(10, 14, 30, 0.82);
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 12px;
  color: #e8eeff;
  font-size: 12px;
  z-index: 500;
  backdrop-filter: blur(8px);
  pointer-events: auto;
}

.hud-title {
  font-weight: 800;
  font-size: 14px;
  margin-bottom: 10px;
  color: #93c5fd;
}

.hud-subtitle {
  font-weight: 700;
  margin: 4px 0 6px;
  color: #93c5fd;
  font-size: 12px;
}

.hud-selected .hud-subtitle {
  color: #fcd34d;
}

.sim-time {
  font-size: 11px;
  word-break: break-all;
}

.clock-actions {
  grid-template-columns: 1fr 1fr;
  gap: 6px;
}

.clock-actions .hud-btn {
  width: 100%;
}

.hud-row {
  display: grid;
  grid-template-columns: 72px 1fr;
  gap: 8px;
  line-height: 1.7;
  align-items: center;
}

.hud-label { opacity: 0.75; }
.hud-value { word-break: break-all; }
.hud-value.mono, .mono { font-family: ui-monospace, monospace; }
.highlight-green { color: #4ade80; font-weight: 700; }
.highlight-red { color: #ff4d4f; font-weight: 700; }

.hud-divider {
  height: 1px;
  margin: 10px 0;
  background: rgba(255, 255, 255, 0.12);
}

.legend-row {
  display: flex;
  align-items: center;
  gap: 8px;
  line-height: 1.9;
}
.legend-row .dot {
  display: inline-block;
  width: 11px;
  height: 11px;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.6);
}

.hud-select {
  width: 100%;
  padding: 5px 28px 5px 8px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(10, 14, 30, 0.92);
  color: #e8eeff;
  outline: none;
  color-scheme: dark;
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23cbd5e1' d='M2 4l4 4 4-4'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 8px center;
}
.hud-select:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.25);
}
.hud-select:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}
.hud-select option {
  background: #0a0e1e;
  color: #e8eeff;
}
.hud-select option:checked {
  background: #1e3a5f;
  color: #f0f9ff;
}

.hud-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
}

.hud-btn {
  flex: 1;
  min-width: 78px;
  padding: 6px 8px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.16);
  background: rgba(255, 255, 255, 0.08);
  color: #e8eeff;
  cursor: pointer;
  font-size: 11px;
}
.hud-btn:hover:not(:disabled) { background: rgba(255, 255, 255, 0.14); }
.hud-btn:disabled { opacity: 0.45; cursor: not-allowed; }

.hud-link {
  display: block;
  width: 100%;
  padding: 6px 0;
  color: #7dd3fc;
  text-decoration: none;
  font-size: 11px;
}
.hud-link:hover { text-decoration: underline; }

.hud-selected {
  margin-top: 8px;
  padding-top: 4px;
  border-top: 1px dashed rgba(255, 255, 255, 0.12);
}

.hud-hint {
  margin-top: 10px;
  font-size: 11px;
  opacity: 0.72;
  line-height: 1.45;
}
</style>
