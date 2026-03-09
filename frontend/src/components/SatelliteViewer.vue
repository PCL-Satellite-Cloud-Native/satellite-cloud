<template>
  <div class="cesium-container">
    <div v-if="loading" class="loading-overlay">
      <div class="loading-message">正在计算覆盖轨道与加载数据...</div>
    </div>
    <div v-if="error" class="error-overlay">
      <div class="error-message">{{ error }}</div>
    </div>
    <div ref="viewerContainer" class="viewer"></div>
    
    <div class="instruction-overlay">
      <div>已选中高亮: {{ highlightedSatIds.size }} 颗</div>
      <div class="sub-text">点击任意卫星可 手动开启/关闭 高亮</div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { getScenarioWithSatellites, getScenarios } from '../api/satellite.js'

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
const highlightedSatIds = ref(new Set()) // 响应式的高亮集合
let viewer = null
let handler = null // 点击事件处理器

// 中国中心点
const CHINA_CENTER = { lon: 104.0, lat: 35.0 }

// --------------------------------------------------------------------
// 核心逻辑：动态样式控制
// --------------------------------------------------------------------

/**
 * 更新单个卫星实体的样式（高亮 vs 普通）
 */
function updateEntityStyle(entity, isHighlighted, altitudeMeters) {
  // 1. 设置点样式
  const pointColor = isHighlighted ? Cesium.Color.GOLD : Cesium.Color.WHITE.withAlpha(0.7)
  const pointSize = isHighlighted ? 14 : 5
  
  entity.point.color = pointColor
  entity.point.pixelSize = pointSize
  entity.point.outline = isHighlighted
  entity.point.outlineColor = Cesium.Color.BLACK

  // 2. 设置轨迹样式
  const pathWidth = isHighlighted ? 4 : 1.5
  let pathMaterial
  if (isHighlighted) {
    pathMaterial = new Cesium.PolylineGlowMaterialProperty({
      glowPower: 0.2,
      color: Cesium.Color.GOLD
    })
  } else {
    pathMaterial = Cesium.Color.WHITE.withAlpha(0.4)
  }
  
  entity.path.width = pathWidth
  entity.path.material = pathMaterial

  // 3. 设置标签显隐
  entity.label.show = isHighlighted

  // 4. 设置圆锥体 (Sensor Cone)
  // 逻辑：给圆锥体一个特定的ID: satelliteID + "_cone"
  const coneId = entity.id + '_cone'
  let coneEntity = viewer.entities.getById(coneId)

  if (isHighlighted) {
    // 如果需要高亮且没有圆锥体，创建它
    if (!coneEntity) {
      const halfAngle = Cesium.Math.toRadians(30)
      const bottomRadius = altitudeMeters * Math.tan(halfAngle)
      
      coneEntity = viewer.entities.add({
        id: coneId,
        parent: entity, // 绑定父子关系，自动跟随位置
        // 动态位置：始终位于卫星下方一半高度处
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
          material: Cesium.Color.GOLD.withAlpha(0.15),
          outline: true,
          outlineColor: Cesium.Color.GOLD.withAlpha(0.4),
          numberOfVerticalLines: 4,
        }
      })
    } else {
      // 如果已有，确保显示
      coneEntity.show = true
    }
  } else {
    // 如果不需要高亮且有圆锥体，隐藏它
    if (coneEntity) {
      coneEntity.show = false
    }
  }
}

/**
 * 点击交互处理
 */
function setupClickHandler(satellitesMap) {
  handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas)
  
  handler.setInputAction((movement) => {
    const pickedObject = viewer.scene.pick(movement.position)
    
    if (Cesium.defined(pickedObject) && pickedObject.id) {
      const entity = pickedObject.id
      // 检查点击的是不是卫星（排除圆锥体本身被点击的情况，虽然圆锥体很难被点中）
      // 我们通过 id 是否存在于 satellitesMap 来判断
      const satData = satellitesMap.get(entity.id) || satellitesMap.get(entity.id.replace('_cone', ''))
      
      if (satData) {
        // 真正的卫星ID
        const realId = satData.sat_id || satData.stk_name
        const entityToUpdate = viewer.entities.getById(realId)
        
        if (entityToUpdate) {
          toggleSatelliteHighlight(realId, entityToUpdate, satData.alt_km * 1000)
        }
      }
    }
  }, Cesium.ScreenSpaceEventType.LEFT_CLICK)
}

/**
 * 切换高亮状态
 */
function toggleSatelliteHighlight(satId, entity, altitudeMeters) {
  if (highlightedSatIds.value.has(satId)) {
    highlightedSatIds.value.delete(satId)
    updateEntityStyle(entity, false, altitudeMeters)
  } else {
    highlightedSatIds.value.add(satId)
    updateEntityStyle(entity, true, altitudeMeters)
  }
}

// --------------------------------------------------------------------
// 辅助计算函数 (保持不变)
// --------------------------------------------------------------------

function getSatellitePositionAtTime(sat, periodSeconds) {
  const inclRad = Cesium.Math.toRadians(sat.inc_deg)
  const raanRad = Cesium.Math.toRadians(sat.raan_deg)
  const initialTaRad = Cesium.Math.toRadians(sat.ta_deg)
  const t = 0 
  const currentAnomaly = (t / periodSeconds) * Math.PI * 2 + initialTaRad
  const latRad = Math.asin(Math.sin(inclRad) * Math.sin(currentAnomaly))
  const argOfLat = Math.atan2(Math.cos(currentAnomaly), Math.sin(currentAnomaly) * Math.cos(inclRad))
  const lonRad = raanRad + argOfLat
  let lon = Cesium.Math.toDegrees(lonRad)
  let lat = Cesium.Math.toDegrees(latRad)
  while (lon > 180) lon -= 360
  while (lon < -180) lon += 360
  return { longitude: lon, latitude: lat }
}

function getDistance(lon1, lat1, lon2, lat2) {
  return Math.sqrt(Math.pow(lon1 - lon2, 2) + Math.pow(lat1 - lat2, 2))
}

function filterChinaSatellites(satellites) {
  const periodSeconds = 5400 
  const planes = {} 

  satellites.forEach(sat => {
    const pos = getSatellitePositionAtTime(sat, periodSeconds)
    if (!planes[sat.plane_index]) planes[sat.plane_index] = []
    planes[sat.plane_index].push({
      ...sat,
      _dist: getDistance(pos.longitude, pos.latitude, CHINA_CENTER.lon, CHINA_CENTER.lat),
      _ta: sat.ta_deg
    })
  })

  const planeScores = Object.keys(planes).map(pIdx => {
    const sats = planes[pIdx]
    const minDistance = Math.min(...sats.map(s => s._dist))
    return { pIdx, minDistance, sats }
  })

  planeScores.sort((a, b) => a.minDistance - b.minDistance)
  const selectedPlanes = planeScores.slice(0, 3)
  const resultIds = new Set()

  selectedPlanes.forEach(plane => {
    const sats = plane.sats
    sats.sort((a, b) => a._ta - b._ta)
    let closestSatIndex = 0
    let minD = 99999
    sats.forEach((s, i) => {
      if (s._dist < minD) { minD = s._dist; closestSatIndex = i }
    })
    const total = sats.length
    for (let k = -2; k <= 2; k++) {
      let idx = (closestSatIndex + k) % total
      if (idx < 0) idx += total
      resultIds.add(sats[idx].sat_id || sats[idx].stk_name)
    }
  })
  return resultIds
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
  property.setInterpolationOptions({ interpolationDegree: 1, interpolationAlgorithm: Cesium.LinearApproximation });
  return property
}

function parseTime(timeStr) {
  if (!timeStr) return Cesium.JulianDate.now()
  const date = new Date(timeStr)
  return !isNaN(date.getTime()) ? Cesium.JulianDate.fromDate(date) : Cesium.JulianDate.now()
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

  return getScenarioWithSatellites(scenarios[0].id)
}

// --------------------------------------------------------------------
// 初始化流程
// --------------------------------------------------------------------

async function initializeViewer() {
  try {
    loading.value = true
    error.value = null
    
    const { scenario, satellites } = await resolveScenarioWithSatellites(props.scenarioId)
    if (!satellites.length) {
      throw new Error(`场景 ${scenario.id} 下没有卫星数据，请先导入卫星数据`)
    }
    
    // 创建快速查找Map，用于点击事件
    const satellitesMap = new Map()
    satellites.forEach(s => satellitesMap.set(s.sat_id || s.stk_name, s))

    if (!viewer) {
      viewer = new Cesium.Viewer(viewerContainer.value, {
        timeline: true,
        animation: true,
        baseLayerPicker: false,
        geocoder: false,
        homeButton: false,
        sceneModePicker: false,
        navigationHelpButton: false,
        shadows: false,
        selectionIndicator: false, // 关闭默认的绿色选择框
        infoBox: false, // 关闭默认的信息框
        imageryProvider: new Cesium.ArcGisMapServerImageryProvider({
          url: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer'
        }),
        terrainProvider: new Cesium.EllipsoidTerrainProvider(),
      })
      
      // 环境设置
      viewer.scene.globe.enableLighting = false 
      viewer.scene.sun.show = false
      viewer.scene.moon.show = false
      viewer.scene.skyAtmosphere.show = false
      viewer.scene.light = new Cesium.DirectionalLight({
        direction: new Cesium.Cartesian3(1, 0, 0)
      })
      
      // 注册点击事件
      setupClickHandler(satellitesMap)
    }
    
    const startTime = parseTime(scenario.start_time || scenario.epoch)
    const endTime = parseTime(scenario.end_time)
    
    viewer.clock.startTime = startTime
    viewer.clock.stopTime = endTime
    viewer.clock.currentTime = startTime
    viewer.clock.multiplier = 10 
    viewer.clock.shouldAnimate = true

    // 1. 获取初始高亮列表
    const initialHighlights = filterChinaSatellites(satellites, startTime)
    highlightedSatIds.value = initialHighlights // 存入响应式变量
    console.log(`初始筛选高亮: ${initialHighlights.size} 颗`)

    // 2. 创建所有卫星实体
    satellites.forEach((satellite) => {
      const satId = satellite.sat_id || satellite.stk_name
      const periodSeconds = 5400 
      const altitudeMeters = satellite.alt_km * 1000
      
      const positionProp = createCircularOrbitPositions(
        startTime, periodSeconds, altitudeMeters,
        satellite.inc_deg, satellite.raan_deg, satellite.ta_deg, 720
      )

      // 先创建基础实体 (默认样式先给普通样式，随后立即更新)
      const entity = viewer.entities.add({
        id: satId,
        name: satellite.stk_name,
        position: positionProp,
        point: {
          pixelSize: 5,
          color: Cesium.Color.WHITE.withAlpha(0.7),
          outline: false,
        },
        path: {
          show: true,
          resolution: 60,
          material: Cesium.Color.WHITE.withAlpha(0.4),
          width: 1.5,
          leadTime: 0,
          trailTime: periodSeconds 
        },
        label: {
          show: false, // 默认不显示
          text: satellite.stk_name,
          font: '14px sans-serif',
          fillColor: Cesium.Color.GOLD,
          style: Cesium.LabelStyle.FILL,
          pixelOffset: new Cesium.Cartesian2(0, -20),
          distanceDisplayCondition: new Cesium.DistanceDisplayCondition(0, 10000000)
        }
      })
      
      // 3. 根据是否高亮，应用一次样式
      const isHighlighted = initialHighlights.has(satId)
      updateEntityStyle(entity, isHighlighted, altitudeMeters)
    })
    
    viewer.camera.flyTo({
      destination: Cesium.Cartesian3.fromDegrees(105.0, 32.0, 18000000),
      duration: 2
    })
    
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

.instruction-overlay {
  position: absolute;
  top: 20px;
  left: 20px;
  padding: 15px;
  background: rgba(30, 30, 30, 0.85);
  border: 1px solid #555;
  border-radius: 8px;
  color: #FFD700;
  font-weight: bold;
  pointer-events: none; /* 让鼠标事件穿透到 Cesium */
  z-index: 500;
}

.sub-text {
  color: #ccc;
  font-size: 12px;
  margin-top: 5px;
  font-weight: normal;
}
</style>
