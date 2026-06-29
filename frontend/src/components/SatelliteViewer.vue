<template>
  <div class="cesium-container">
    <div v-if="loading" class="loading-overlay">
      <div class="loading-message">正在计算覆盖轨道与加载数据...</div>
    </div>
    <div v-if="error" class="error-overlay">
      <div class="error-message">{{ error }}</div>
    </div>
    <div ref="viewerContainer" class="viewer"></div>

    <aside class="hud-panel">
      <div class="hud-title">数字孪生 · 星座仿真</div>
      <div class="hud-row">
        <span class="hud-label">场景</span>
        <span class="hud-value">{{ scenarioName || '—' }}</span>
      </div>
      <div class="hud-row">
        <span class="hud-label">仿真时段</span>
        <span class="hud-value mono">{{ scenarioTimeRange }}</span>
      </div>
      <div class="hud-row">
        <span class="hud-label">卫星</span>
        <span class="hud-value">{{ satelliteCount }} 颗{{ pilotModeLabel }}</span>
      </div>
      <div class="hud-row">
        <span class="hud-label">运行中高亮</span>
        <span class="hud-value highlight-green">{{ runningHighlightCount }} 颗</span>
      </div>
      <div class="hud-row">
        <span class="hud-label">底图</span>
        <span class="hud-value">{{ imageryLabel }}</span>
      </div>

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

      <div class="hud-divider"></div>

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
        <button type="button" class="hud-btn" :disabled="!lastHighlightedSatId" @click="flyToPreset('follow')">跟踪选中</button>
      </div>

      <div class="hud-actions">
        <router-link class="hud-link" to="/simulation/topology">卫星网络拓扑 →</router-link>
        <router-link class="hud-link" to="/remote-sensing">遥感任务 →</router-link>
      </div>

      <div v-if="selectedSatInfo" class="hud-selected">
        <div class="hud-subtitle">选中卫星</div>
        <div class="hud-row"><span class="hud-label">名称</span><span class="hud-value">{{ selectedSatInfo.label }}</span></div>
        <div class="hud-row"><span class="hud-label">sat_id</span><span class="hud-value mono">{{ selectedSatInfo.id }}</span></div>
        <div class="hud-row"><span class="hud-label">高度</span><span class="hud-value">{{ selectedSatInfo.altKm }} km</span></div>
        <router-link class="hud-link hud-link-btn" :to="topologyLink">查看路由子网 →</router-link>
      </div>

      <div class="hud-hint">点击卫星高亮（金色锥）；绿色 = 正在执行任务（含覆盖锥）</div>
    </aside>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { getScenarioWithSatellites, getScenarios } from '../api/satellite.js'
import { listRemoteSensingTasks } from '../api/remoteSensing.js'
import { displaySatName } from '../utils/satNaming.js'

window.CESIUM_BASE_URL = '/cesium'
import * as Cesium from 'cesium'

const props = defineProps({
  scenarioId: {
    type: [Number, String],
    default: null
  }
})

const viewerContainer = ref(null)
const loading = ref(false)
const error = ref(null)
const highlightedSatIds = ref(new Set())
const runningHighlightIds = ref(new Set())
const runningHighlightCount = ref(0)
const scenarioName = ref('')
const scenarioTimeRange = ref('—')
const satelliteCount = ref(0)
const clockMultiplier = ref(10)
const imagerySource = ref('builtin')

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
const selectedSatInfo = ref(null)
const lastHighlightedSatId = ref(null)

let viewer = null
let handler = null
let runningTasksTimer = null
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

const topologyLink = computed(() => {
  const satId = selectedSatInfo.value?.id || lastHighlightedSatId.value
  if (satId) {
    return { path: '/simulation/topology', query: { satId } }
  }
  return { path: '/simulation/topology' }
})

const pilotModeLabel = computed(() => {
  return satelliteCount.value === 15 ? ' (Pilot)' : ''
})

function syncFootprintCone(entity, altitudeMeters, mode) {
  const coneId = entity.id + '_cone'
  let coneEntity = viewer.entities.getById(coneId)

  if (!mode) {
    if (coneEntity) coneEntity.show = false
    return
  }

  const isGold = mode === 'gold'
  const fill = isGold ? Cesium.Color.GOLD : Cesium.Color.LIME
  const halfAngle = Cesium.Math.toRadians(30)
  const bottomRadius = altitudeMeters * Math.tan(halfAngle)

  if (!coneEntity) {
    coneEntity = viewer.entities.add({
      id: coneId,
      parent: entity,
      position: new Cesium.CallbackProperty((time) => {
        const pos = entity.position.getValue(time)
        if (!pos) return null
        const cart = Cesium.Cartographic.fromCartesian(pos)
        return Cesium.Cartesian3.fromRadians(cart.longitude, cart.latitude, altitudeMeters / 2)
      }, false),
      cylinder: {
        length: altitudeMeters,
        topRadius: 0,
        bottomRadius: bottomRadius,
        material: fill.withAlpha(0.15),
        outline: true,
        outlineColor: fill.withAlpha(0.45),
        numberOfVerticalLines: 4,
      }
    })
  } else {
    coneEntity.show = true
    coneEntity.cylinder.material = fill.withAlpha(0.15)
    coneEntity.cylinder.outlineColor = fill.withAlpha(0.45)
  }
}

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
    const resp = await fetch(url, { method: 'HEAD' })
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

async function hasRealLocalImagery() {
  const meta = await loadImageryMeta()
  if (meta?.source && meta.source !== 'synthetic') return true
  if (await assetExists('/tiles/earth-hd/tilemapresource.xml')) {
    try {
      const resp = await fetch('/assets/earth_hd.jpg', { method: 'HEAD' })
      if (resp.ok) {
        const len = Number(resp.headers.get('content-length') || 0)
        return len >= 80_000
      }
    } catch {}
  }
  return false
}

async function setupOfflineImagery(v) {
  v.imageryLayers.removeAll()
  try {
    if (MAP_TILES_URL) {
      const url = MAP_TILES_URL.includes('{z}')
        ? MAP_TILES_URL
        : `${MAP_TILES_URL.replace(/\/$/, '')}/{z}/{x}/{y}.png`
      v.imageryLayers.addImageryProvider(
        new Cesium.UrlTemplateImageryProvider({
          url,
          minimumLevel: 0,
          maximumLevel: 18,
        })
      )
      imagerySource.value = 'xyz-tiles'
      return
    }

    const realLocal = await hasRealLocalImagery()
    const meta = await loadImageryMeta()

    if (realLocal && (await assetExists('/tiles/earth-hd/tilemapresource.xml'))) {
      v.imageryLayers.addImageryProvider(
        new Cesium.TileMapServiceImageryProvider({ url: '/tiles/earth-hd' })
      )
      if (meta?.source === 'blue-marble' || meta?.source === 'local') {
        imagerySource.value = 'hd-tiles'
      } else if (meta?.source === 'natural-earth') {
        imagerySource.value = 'natural-earth'
      } else {
        imagerySource.value = 'hd-tiles'
      }
      return
    }

    if (realLocal && (await assetExists('/assets/earth_hd.jpg'))) {
      v.imageryLayers.addImageryProvider(
        new Cesium.SingleTileImageryProvider({
          url: '/assets/earth_hd.jpg',
          rectangle: Cesium.Rectangle.fromDegrees(-180, -90, 180, 90),
        })
      )
      imagerySource.value = meta?.source === 'natural-earth' ? 'natural-earth' : 'hd-single'
      return
    }

    v.imageryLayers.addImageryProvider(
      new Cesium.TileMapServiceImageryProvider({
        url: Cesium.buildModuleUrl('Assets/Textures/NaturalEarthII'),
      })
    )
    imagerySource.value = 'natural-earth'
  } catch (e) {
    console.warn('底图加载失败', e)
    imagerySource.value = 'failed'
  }
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
  if (preset === 'follow' && lastHighlightedSatId.value) {
    const entity = viewer.entities.getById(lastHighlightedSatId.value)
    if (entity) {
      viewer.trackedEntity = entity
      viewer.camera.flyTo({
        destination: Cesium.Cartesian3.fromDegrees(104.0, 35.0, 12000000),
        duration: 1.2,
      })
    }
  }
}

function updateEntityStyle(entity, isHighlighted, altitudeMeters) {
  const isRunning = runningHighlightIds.value.has(entity.id)
  const active = isHighlighted || isRunning
  const pointColor = isRunning
    ? Cesium.Color.LIME
    : (isHighlighted ? Cesium.Color.GOLD : Cesium.Color.WHITE.withAlpha(0.85))
  const pointSize = active ? 14 : 6

  entity.point.color = pointColor
  entity.point.pixelSize = pointSize
  entity.point.outline = active
  entity.point.outlineColor = Cesium.Color.BLACK

  const pathWidth = active ? 4 : 1.5
  let pathMaterial
  if (isRunning) {
    pathMaterial = new Cesium.PolylineGlowMaterialProperty({
      glowPower: 0.25,
      color: Cesium.Color.LIME
    })
  } else if (isHighlighted) {
    pathMaterial = new Cesium.PolylineGlowMaterialProperty({
      glowPower: 0.2,
      color: Cesium.Color.GOLD
    })
  } else {
    pathMaterial = Cesium.Color.WHITE.withAlpha(0.45)
  }

  entity.path.width = pathWidth
  entity.path.material = pathMaterial
  entity.label.show = active

  let coneMode = null
  if (isHighlighted) {
    coneMode = 'gold'
  } else if (isRunning) {
    coneMode = 'lime'
  }
  syncFootprintCone(entity, altitudeMeters, coneMode)
}

function setupClickHandler(satellitesMap) {
  handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas)

  handler.setInputAction((movement) => {
    const pickedObject = viewer.scene.pick(movement.position)

    if (Cesium.defined(pickedObject) && pickedObject.id) {
      const entity = pickedObject.id
      const satData = satellitesMap.get(entity.id) || satellitesMap.get(entity.id.replace('_cone', ''))

      if (satData) {
        const realId = satData.sat_id || satData.stk_name
        const entityToUpdate = viewer.entities.getById(realId)

        if (entityToUpdate) {
          toggleSatelliteHighlight(realId, entityToUpdate, satData.alt_km * 1000, satData)
        }
      }
    }
  }, Cesium.ScreenSpaceEventType.LEFT_CLICK)
}

function toggleSatelliteHighlight(satId, entity, altitudeMeters, satData) {
  if (highlightedSatIds.value.has(satId)) {
    highlightedSatIds.value.delete(satId)
    selectedSatInfo.value = null
    lastHighlightedSatId.value = null
    if (viewer.trackedEntity === entity) {
      viewer.trackedEntity = undefined
    }
    updateEntityStyle(entity, false, altitudeMeters)
  } else {
    highlightedSatIds.value.clear()
    for (const [id, ent] of entityBySatId.entries()) {
      const alt = ent._satData ? ent._satData.alt_km * 1000 : 550000
      updateEntityStyle(ent, false, alt)
    }
    highlightedSatIds.value.add(satId)
    lastHighlightedSatId.value = satId
    selectedSatInfo.value = {
      id: satId,
      label: displaySatName(satData),
      altKm: satData?.alt_km ?? '—',
    }
    updateEntityStyle(entity, true, altitudeMeters)
  }
}

async function refreshRunningHighlights() {
  try {
    const tasks = await listRemoteSensingTasks({ status: 'running' })
    const next = new Set()
    for (const t of tasks ?? []) {
      if (t.executed_sat_id) next.add(t.executed_sat_id)
    }
    runningHighlightIds.value = next
    runningHighlightCount.value = next.size
    for (const [satId, entity] of entityBySatId.entries()) {
      const sat = entity._satData
      const alt = sat ? sat.alt_km * 1000 : 550000
      const manual = highlightedSatIds.value.has(satId)
      updateEntityStyle(entity, manual, alt)
    }
  } catch (e) {
    console.warn('刷新运行中任务高亮失败', e)
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

function parseTime(timeStr) {
  if (!timeStr) return Cesium.JulianDate.now()
  const date = new Date(timeStr)
  return !isNaN(date.getTime()) ? Cesium.JulianDate.fromDate(date) : Cesium.JulianDate.now()
}

function formatJulianRange(start, end) {
  const fmt = (jd) => {
    const d = Cesium.JulianDate.toDate(jd)
    return d.toISOString().replace('T', ' ').slice(0, 19)
  }
  return `${fmt(start)} ~ ${fmt(end)}`
}

function normalizeScenarioList(responseData) {
  if (Array.isArray(responseData)) {
    return responseData
  }
  if (responseData && Array.isArray(responseData.results)) {
    return responseData.results
  }
  return []
}

async function resolveScenarioWithSatellites(preferredScenarioId) {
  const hasPreferredId = preferredScenarioId !== null && preferredScenarioId !== undefined && preferredScenarioId !== ''

  if (hasPreferredId) {
    try {
      return await getScenarioWithSatellites(preferredScenarioId)
    } catch (err) {
      if (!String(err?.message || '').includes('Not Found')) {
        throw err
      }
    }
  }

  const scenariosResponse = await getScenarios()
  const scenarios = normalizeScenarioList(scenariosResponse)
  if (!scenarios.length) {
    throw new Error('未找到场景数据，请先在后端导入场景数据（可运行 backend/inser_data.py）')
  }
  const preferred = scenarios.find(s => s.name === 'Scenario5_full_36x22') || scenarios[0]
  return getScenarioWithSatellites(preferred.id)
}

async function initializeViewer() {
  try {
    loading.value = true
    error.value = null

    const { scenario, satellites } = await resolveScenarioWithSatellites(props.scenarioId)
    if (!satellites.length) {
      throw new Error(`场景 ${scenario.id} 下没有卫星数据，请先导入卫星数据`)
    }

    scenarioName.value = scenario.name || `场景 #${scenario.id}`
    satelliteCount.value = satellites.length

    const satellitesMap = new Map()
    satellites.forEach(s => satellitesMap.set(s.sat_id || s.stk_name, s))

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

      setupClickHandler(satellitesMap)
    }

    const startTime = parseTime(scenario.start_time || scenario.epoch)
    const endTime = parseTime(scenario.end_time)
    scenarioTimeRange.value = formatJulianRange(startTime, endTime)

    viewer.clock.startTime = startTime
    viewer.clock.stopTime = endTime
    viewer.clock.currentTime = startTime
    viewer.clock.multiplier = clockMultiplier.value
    syncClockPlayback(true)

    if (!removeClockTickListener) {
      setupClockHud(viewer)
    }

    highlightedSatIds.value = new Set()
    entityBySatId.clear()
    viewer.entities.removeAll()

    satellites.forEach((satellite) => {
      const satId = satellite.sat_id || satellite.stk_name
      const periodSeconds = 5400
      const altitudeMeters = satellite.alt_km * 1000

      const positionProp = createCircularOrbitPositions(
        startTime, periodSeconds, altitudeMeters,
        satellite.inc_deg, satellite.raan_deg, satellite.ta_deg, 720
      )

      const label = displaySatName(satellite)

      const entity = viewer.entities.add({
        id: satId,
        name: label,
        position: positionProp,
        point: {
          pixelSize: 6,
          color: Cesium.Color.WHITE.withAlpha(0.85),
          outline: false,
        },
        path: {
          show: true,
          resolution: 60,
          material: Cesium.Color.WHITE.withAlpha(0.45),
          width: 1.5,
          leadTime: 0,
          trailTime: periodSeconds
        },
        label: {
          show: false,
          text: label,
          font: '14px sans-serif',
          fillColor: Cesium.Color.LIME,
          style: Cesium.LabelStyle.FILL,
          pixelOffset: new Cesium.Cartesian2(0, -20),
          distanceDisplayCondition: new Cesium.DistanceDisplayCondition(0, 10000000)
        }
      })
      entity._satData = satellite
      entityBySatId.set(satId, entity)
      updateEntityStyle(entity, false, altitudeMeters)
    })

    await refreshRunningHighlights()
    runningTasksTimer = setInterval(refreshRunningHighlights, 5000)

    flyToPreset('global')

    loading.value = false
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
  if (runningTasksTimer) {
    clearInterval(runningTasksTimer)
    runningTasksTimer = null
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
  width: 280px;
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

.hud-divider {
  height: 1px;
  margin: 10px 0;
  background: rgba(255, 255, 255, 0.12);
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

.hud-link-btn {
  display: inline-block;
  margin-top: 6px;
  padding: 5px 8px;
  border-radius: 8px;
  background: rgba(125, 211, 252, 0.12);
  border: 1px solid rgba(125, 211, 252, 0.35);
}

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
