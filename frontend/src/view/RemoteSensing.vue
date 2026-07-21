<template>
  <div class="remote-sensing-page">
    <header class="page-header card">
      <div>
        <h1>遥感应用</h1>
        <p>预处理与目标识别串行流水线：一次提交，自动完成融合与 YOLOv8 检测。</p>
      </div>
      <div class="header-actions">
        <span class="live-indicator" :class="{ on: isLiveRefreshing }">
          {{ isLiveRefreshing ? '实时刷新中' : '静态查看' }}
        </span>
        <button type="button" class="ghost" @click="loadTasks()">刷新任务</button>
      </div>
    </header>

    <div class="page-body">
      <section class="task-panel">
        <form class="task-form card" @submit.prevent="submitTask">
          <h2>创建任务</h2>

          <fieldset class="form-section">
            <legend>指定执行卫星（必选）</legend>
            <label>
              仿真场景
              <select v-model="form.scenarioId" @change="onScenarioChange" required>
                <option :value="null" disabled>请选择场景</option>
                <option v-for="s in scenarios" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </label>
            <label>
              执行卫星
              <select v-model="form.satelliteId" :disabled="!form.scenarioId" required>
                <option :value="null" disabled>请选择卫星</option>
                <option v-for="sat in scenarioSatellites" :key="sat.id" :value="sat.id">
                  {{ sat.sat_id }} · {{ sat.stk_name }}
                </option>
              </select>
            </label>
            <p class="form-hint">
              60 节点验收输入仅在锚点：<strong>sat1 / sat21 / sat41</strong>（对应 sat-1-1 / sat-2-1 / sat-3-1）。
              不指定卫星会被任意节点抢到并因缺少 TIFF 失败。
            </p>
          </fieldset>

          <fieldset class="form-section">
            <legend>预处理（1–9 阶段）</legend>
            <label>
              任务名称
              <input v-model="form.name" placeholder="可选，默认使用前缀" />
            </label>
            <label>
              数据前缀
              <input v-model="form.filePrefix" placeholder="例如 GF2_PMS1_..." required />
            </label>
            <label>
              数据目录
              <input v-model="form.inputDirectory" placeholder="例如 input/" required />
            </label>
            <label>
              Sensor
              <input v-model="form.sensor" placeholder="可选，如 MSS1" />
            </label>
          </fieldset>

          <fieldset class="form-section">
            <legend>目标识别（第 10 阶段）</legend>
            <label class="checkbox-row">
              <input type="checkbox" v-model="form.enableDetection" />
              融合完成后自动运行 YOLOv8 检测
            </label>
            <template v-if="form.enableDetection">
              <div class="class-picker">
                <div class="class-picker-head">
                  <span class="class-picker-title">检测目标类别</span>
                  <span class="class-picker-actions">
                    <button type="button" class="link-btn" @click="selectAllDetectionClasses">全选</button>
                    <button type="button" class="link-btn" @click="clearDetectionClasses">清空</button>
                  </span>
                </div>
                <p class="form-hint">勾选需要检测的地物类型；未勾选任何类别时无法提交。</p>
                <div class="class-checkbox-grid">
                  <label
                    v-for="item in DETECTION_CLASSES"
                    :key="item.id"
                    class="class-checkbox-item"
                  >
                    <input type="checkbox" :value="item.id" v-model="form.detectionClassIds" />
                    <span class="class-text">
                      <span class="class-label">{{ item.label }}</span>
                      <span class="class-name-en">{{ item.name }}</span>
                    </span>
                  </label>
                </div>
                <p class="class-summary" v-if="detectionSelectionSummary">
                  已选：{{ detectionSelectionSummary }}
                </p>
              </div>
              <label class="checkbox-row">
                <input type="checkbox" v-model="form.detectionDrawLabels" />
                在输出瓦片上绘制标签
              </label>
              <p class="form-hint">融合 .dat 路径由后端自动解析，无需手动填写。</p>
            </template>
          </fieldset>

          <div class="form-actions">
            <button type="submit">提交任务</button>
            <span class="form-note" v-if="submitMessage">{{ submitMessage }}</span>
          </div>
        </form>

        <div class="task-list card">
          <header class="task-list-header">
            <h3>任务列表</h3>
            <span v-if="tasks.length">{{ tasks.length }} 个任务</span>
            <span v-else>暂无任务</span>
          </header>

          <div v-for="task in tasks" :key="task.id" class="task-card" :class="task.status">
            <div class="task-card-head">
              <div>
                <div class="task-name">{{ task.name || task.file_prefix }}</div>
                <p class="task-meta">
                  状态：{{ statusText(task.status) }}
                  · 阶段：{{ stageNameText(task.current_stage) || '等待中' }}
                  <span v-if="taskExecutionLabel(task)"> · {{ taskExecutionLabel(task) }}</span>
                  <span v-if="task.enable_detection === false"> · 未启用检测</span>
                </p>
              </div>
              <button type="button" @click="selectTask(task)" :disabled="selectedTask?.id === task.id">
                详情
              </button>
            </div>
            <div class="task-body">
              <div>文件前缀：{{ task.file_prefix }}</div>
              <div>目录：{{ task.input_directory }}</div>
              <div v-if="task.enable_detection !== false && task.detection_classes !== undefined">
                检测类别：{{ formatDetectionClasses(task.detection_classes) }}
              </div>
              <div v-if="task.executed_sat_id || task.host_node_name" class="task-topology-row">
                执行卫星：{{ satNameFromSatId(task.executed_sat_id) || '—' }}
                <span v-if="task.host_node_name" class="task-node-hint"> · 部署节点 {{ task.host_node_name }}</span>
                <router-link
                  v-if="task.executed_sat_id"
                  class="topology-link"
                  :to="{ path: '/simulation/topology', query: { satId: task.executed_sat_id } }"
                >
                  拓扑高亮
                </router-link>
              </div>
              <div v-else-if="task.status === 'running'" class="task-topology-row muted">
                等待 worker 上报执行节点…
              </div>
              <div>创建：{{ formatTime(task.created_at) }}</div>
            </div>
          </div>
        </div>
      </section>

      <section class="detail-panel card" v-if="selectedTask">
        <div class="detail-header">
          <h2>{{ selectedTask.name || selectedTask.file_prefix }}</h2>
          <span class="status-chip" :class="selectedTask.status">{{ statusText(selectedTask.status) }}</span>
        </div>

        <div class="pipeline-hint card-inline">
          流水线：预处理 9 阶段
          <template v-if="selectedTask.enable_detection !== false"> → 目标识别</template>
          <template v-else>（已跳过目标识别）</template>
        </div>

        <div class="summary-grid">
          <article class="summary-item">
            <span>当前阶段</span>
            <strong>{{ currentStageText }}</strong>
          </article>
          <article class="summary-item">
            <span>阶段进度</span>
            <strong>{{ completedStages }}/{{ stages.length || 0 }}</strong>
          </article>
          <article class="summary-item">
            <span>总耗时</span>
            <strong>{{ durationText }}</strong>
          </article>
          <article class="summary-item">
            <span>预计剩余</span>
            <strong>{{ etaText }}</strong>
          </article>
          <article class="summary-item" v-if="selectedTask.enable_detection !== false">
            <span>检测类别</span>
            <strong>{{ formatDetectionClasses(selectedTask.detection_classes) }}</strong>
          </article>
          <article class="summary-item" v-if="selectedTask.executed_sat_id || selectedTask.host_node_name">
            <span>执行卫星</span>
            <strong>
              {{ selectedTask.executed_sat_id ? satNameFromSatId(selectedTask.executed_sat_id) : '—' }}
              <span v-if="selectedTask.host_node_name" class="task-node-hint"> · 节点 {{ selectedTask.host_node_name }}</span>
              <router-link
                v-if="selectedTask.executed_sat_id"
                class="topology-link inline"
                :to="{ path: '/simulation/topology', query: { satId: selectedTask.executed_sat_id } }"
              >
                拓扑
              </router-link>
            </strong>
          </article>
          <article class="summary-item" v-if="selectedTask.error_message">
            <span>失败原因</span>
            <strong>{{ selectedTask.error_message }}</strong>
          </article>
        </div>

        <div class="progress-wrap">
          <div class="progress-bar">
            <div class="progress-bar__fill" :style="{ width: `${stageProgress}%` }"></div>
          </div>
          <span>{{ stageProgress }}% 完成</span>
        </div>

        <div class="stage-rank" v-if="stageDurationRanking.length">
          <h3>阶段耗时排行</h3>
          <ul>
            <li v-for="item in stageDurationRanking" :key="item.name">
              <span>{{ item.title }}</span>
              <strong>{{ item.durationText }}</strong>
            </li>
          </ul>
        </div>

        <div class="timeline">
          <article v-for="stage in stages" :key="stage.id" class="timeline-stage" :class="stage.status">
            <header>
              <span class="circle" :class="stage.status"></span>
              <div>
                <div class="stage-name">{{ stage.title || stageNameText(stage.name) }}</div>
                <p class="stage-meta">{{ stageStatusText(stage.status) }}</p>
              </div>
            </header>
            <p class="stage-message" v-if="stage.message">{{ stage.message }}</p>
            <span class="stage-details" v-if="stage.details">{{ formatDetails(stage.details) }}</span>
          </article>
        </div>

        <div class="result-grid">
          <div class="preview">
            <h3>结果预览</h3>

            <div v-if="previewGroups.length" class="preview-gallery">
              <p v-if="detectionSummaryText" class="detection-summary">{{ detectionSummaryText }}</p>
              <div class="preview-tabs" role="tablist" aria-label="结果分类">
                <button
                  v-for="group in previewGroups"
                  :key="group.key"
                  type="button"
                  class="preview-tab"
                  :class="{ active: activePreviewTab === group.key }"
                  role="tab"
                  :aria-selected="activePreviewTab === group.key"
                  @click="selectPreviewTab(group.key)"
                >
                  <span class="tab-label">{{ group.label }}</span>
                  <span v-if="group.kind === 'detection'" class="tab-stats">
                    <span class="tab-stat">{{ group.tileCount }}图</span>
                    <span class="tab-stat tab-stat--target">{{ group.detectionCount }}目标</span>
                  </span>
                  <span v-else class="tab-count">{{ group.totalCount ?? group.images.length }}</span>
                </button>
              </div>

              <div v-if="activePreviewGroup" class="preview-main">
                <div class="preview-image">
                  <img :src="activePreviewImageUrl" :alt="activePreviewGroup.label" />
                </div>

                <div class="preview-toolbar" v-if="activePreviewGroup.images.length > 1">
                  <button type="button" class="ghost sm" @click="shiftPreviewImage(-1)">上一张</button>
                  <span class="preview-counter">
                    {{ activeImageIndex + 1 }} / {{ activePreviewGroup.images.length }}
                    <template v-if="activePreviewGroup.kind === 'detection' && activePreviewGroup.totalCount > activePreviewGroup.images.length">
                      （预览 {{ activePreviewGroup.images.length }} / {{ activePreviewGroup.tileCount }} 图）
                    </template>
                    · {{ activePreviewImage?.label }}
                  </span>
                  <button type="button" class="ghost sm" @click="shiftPreviewImage(1)">下一张</button>
                </div>

                <div class="thumb-strip" v-if="activePreviewGroup.images.length > 1">
                  <button
                    v-for="(img, index) in activePreviewGroup.images"
                    :key="img.id"
                    type="button"
                    class="thumb-btn"
                    :class="{ active: index === activeImageIndex }"
                    @click="activeImageIndex = index"
                  >
                    <img :src="artifactUrl(img.id)" :alt="img.label" loading="lazy" />
                  </button>
                </div>

                <p class="preview-caption">
                  <template v-if="activePreviewGroup.kind === 'fusion'">预处理融合预览（imgshow）</template>
                  <template v-else-if="activePreviewGroup.kind === 'detection'">
                    {{ activePreviewGroup.label }} · 含目标瓦片 {{ activePreviewGroup.tileCount }} 张 · 检出 {{ activePreviewGroup.detectionCount }} 个目标<template v-if="activePreviewGroup.tileCount > activePreviewGroup.images.length"> · 预览前 {{ activePreviewGroup.images.length }} 张</template>
                  </template>
                </p>
              </div>
            </div>
            <p v-else class="placeholder">暂无预览图，请等待结果产出。</p>

            <div v-if="detectionTileCount > 0" class="detection-download-bar">
              <a
                class="primary sm"
                :href="detectionTilesArchiveUrl(selectedTask.id)"
                download
              >
                下载全部检测瓦片（{{ detectionTileCount }} 图<template v-if="detectionStats?.total_detections"> · {{ detectionStats.total_detections }} 目标</template>）
              </a>
            </div>

            <details class="artifact-downloads" v-if="downloadArtifacts.length">
              <summary>产物下载（{{ downloadArtifacts.length }}）</summary>
              <ul class="artifact-list">
                <li v-for="artifact in downloadArtifacts" :key="artifact.id">
                  <a :href="artifactUrl(artifact.id)" target="_blank" rel="noreferrer">
                    {{ artifact.label || artifact.type }}
                  </a>
                </li>
              </ul>
            </details>
          </div>

          <div class="logs">
            <h3>执行日志</h3>
            <div v-if="logs.length" class="log-list">
              <div v-for="log in displayLogs" :key="log.id" class="log-line">
                <small>
                  {{ formatTime(log.created_at) }}
                  · {{ stageNameText(log.stage_name) || '全局' }}
                </small>
                <p>{{ log.content }}</p>
              </div>
            </div>
            <p v-else class="placeholder">暂无日志</p>
          </div>
        </div>
      </section>

      <section v-else class="detail-placeholder card">
        <p>请选择左侧任务查看详细信息</p>
      </section>
    </div>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  listRemoteSensingTasks,
  createRemoteSensingTask,
  getRemoteSensingStages,
  getRemoteSensingLogs,
  getRemoteSensingArtifacts,
  getRemoteSensingDetectionStats,
  streamRemoteSensingEvents,
  artifactDownloadUrl,
  detectionTilesArchiveUrl,
} from '../api/remoteSensing'
import { getScenarios, getSatellitesByScenario, getSatellite } from '../api/satellite'
import { displaySatName, satNameFromSatId } from '../utils/satNaming'

const route = useRoute()

const STAGE_TITLE_MAP = {
  tiff_to_envi_mss: 'TIFF → ENVI（MSS）',
  tiff_to_envi_pan: 'TIFF → ENVI（PAN）',
  pan_rad_toa: 'PAN 辐射定标',
  pan_rpc_warp_quarters: 'PAN RPC 分块',
  pan_merge_warp_square: 'PAN 拼接裁切',
  mss_rad_quac_rpc: 'MSS QUAC + RPC',
  mss_coregister_to_pan: '多光谱与全色配准',
  pansharpen_fusion: 'Pan-sharpen 融合',
  fusion_stack_envi: '融合堆栈 ENVI',
  object_detection: 'YOLOv8 目标识别',
}

const DETECTION_CLASSES = [
  { id: 0, label: '油罐', name: 'oil' },
  { id: 1, label: '桥梁', name: 'bridge' },
  { id: 2, label: '篮球场', name: 'basketball court' },
  { id: 3, label: '田径场', name: 'ground track field' },
  { id: 4, label: '环形交叉口', name: 'roundabout' },
  { id: 5, label: '码头', name: 'harbor' },
  { id: 6, label: '其他球场', name: 'other court' },
  { id: 7, label: '足球场', name: 'soccer ball field' },
]

const STATUS_TEXT_MAP = {
  pending: '等待中',
  running: '运行中',
  completed: '已完成',
  failed: '失败',
  success: '成功',
}

const tasks = ref([])
const selectedTask = ref(null)
const stages = ref([])
const logs = ref([])
const artifacts = ref([])
const detectionStats = ref(null)
const submitMessage = ref('')
const activePreviewTab = ref('')
const activeImageIndex = ref(0)

const eventSource = ref(null)
const eventTaskId = ref(null)
const detailRefreshTimer = ref(null)
const pollTimer = ref(null)
const pollTaskId = ref(null)
const reconnectTimer = ref(null)
const nowTickTimer = ref(null)
const nowTick = ref(Date.now())

const form = reactive({
  name: '',
  filePrefix: '',
  inputDirectory: 'input',
  sensor: '',
  enableDetection: true,
  detectionClassIds: [1, 5],
  detectionDrawLabels: true,
  scenarioId: null,
  satelliteId: null,
})

const scenarios = ref([])
const scenarioSatellites = ref([])
const satelliteLookup = ref(new Map())

function scenarioName(scenarioId) {
  const found = scenarios.value.find((s) => s.id === scenarioId)
  return found ? found.name : `场景 #${scenarioId}`
}

function taskExecutionLabel(task) {
  if (task.executed_sat_id) return `执行于 ${satNameFromSatId(task.executed_sat_id)}`
  if (task.status === 'running') return '等待识别执行卫星'
  if (task.satellite_id) return `指定 ${satelliteLabel(task.satellite_id)}`
  return ''
}

function satelliteLabel(satelliteId) {
  const info = satelliteLookup.value.get(satelliteId)
  if (!info) return `#${satelliteId}`
  return displaySatName(info, info.stk_name)
}

async function loadScenarios() {
  try {
    const data = await getScenarios()
    scenarios.value = data.results ?? data
  } catch (err) {
    console.error('场景列表加载失败', err)
  }
}

async function loadSatellitesForScenario(scenarioId) {
  if (!scenarioId) {
    scenarioSatellites.value = []
    return
  }
  try {
    const sats = await getSatellitesByScenario(scenarioId)
    scenarioSatellites.value = sats
    const next = new Map(satelliteLookup.value)
    for (const sat of sats) next.set(sat.id, sat)
    satelliteLookup.value = next
  } catch (err) {
    console.error('卫星列表加载失败', err)
    scenarioSatellites.value = []
  }
}

function onScenarioChange() {
  form.satelliteId = null
  loadSatellitesForScenario(form.scenarioId)
}

async function ensureSatelliteLookup(tasksList) {
  const missing = [...new Set(tasksList.map((t) => t.satellite_id).filter(Boolean))]
    .filter((id) => !satelliteLookup.value.has(id))
  if (!missing.length) return
  const next = new Map(satelliteLookup.value)
  await Promise.all(
    missing.map(async (id) => {
      try {
        const sat = await getSatellite(id)
        next.set(id, sat)
      } catch {
        /* ignore */
      }
    })
  )
  satelliteLookup.value = next
}

const detectionSelectionSummary = computed(() => {
  if (!form.detectionClassIds.length) return ''
  if (form.detectionClassIds.length === DETECTION_CLASSES.length) return '全部 8 类'
  return form.detectionClassIds
    .slice()
    .sort((a, b) => a - b)
    .map((id) => DETECTION_CLASSES.find((c) => c.id === id)?.label || id)
    .join('、')
})

function selectAllDetectionClasses() {
  form.detectionClassIds = DETECTION_CLASSES.map((c) => c.id)
}

function clearDetectionClasses() {
  form.detectionClassIds = []
}

function buildDetectionClassesParam() {
  const ids = [...form.detectionClassIds].sort((a, b) => a - b)
  if (!ids.length) return null
  if (ids.length === DETECTION_CLASSES.length) return ''
  return ids.join(',')
}

function formatDetectionClasses(value) {
  if (value === undefined || value === null) return '-'
  const raw = String(value).trim()
  if (!raw) return '全部类别'
  return raw
    .split(',')
    .map((token) => {
      const id = Number(token.trim())
      const found = DETECTION_CLASSES.find((c) => c.id === id)
      return found ? found.label : token.trim()
    })
    .join('、')
}

const completedStages = computed(
  () => stages.value.filter((stage) => stage.status === 'success' || stage.status === 'failed').length
)

const stageProgress = computed(() => {
  if (!stages.value.length) return 0
  return Math.round((completedStages.value / stages.value.length) * 100)
})

const displayLogs = computed(() => [...logs.value].reverse())

const IMAGE_ARTIFACT_TYPES = new Set(['preview', 'detection_preview', 'detection_tile'])

function isImageArtifact(artifact) {
  return IMAGE_ARTIFACT_TYPES.has(artifact.type)
}

function classLabelFromDir(dir) {
  if (!dir) return '未分类'
  const found = DETECTION_CLASSES.find((c) => c.name === dir)
  return found ? found.label : dir
}

function classOrderFromDir(dir) {
  const found = DETECTION_CLASSES.find((c) => c.name === dir)
  return found ? found.id : 99
}

const PREVIEW_TILES_PER_CLASS = 8

const detectionStatsByClass = computed(() => {
  const map = new Map()
  for (const row of detectionStats.value?.by_class ?? []) {
    map.set(row.class_dir, row)
  }
  return map
})

const detectionSummaryText = computed(() => {
  const stats = detectionStats.value
  if (!stats?.total_detections) return ''
  const tiles = stats.total_tiles ?? 0
  return `共检出 ${stats.total_detections} 个目标，分布在 ${tiles} 张含目标瓦片中`
})

const previewGroups = computed(() => {
  if (!selectedTask.value) return []

  const groups = []
  const fusion = artifacts.value.filter((a) => a.type === 'preview')
  if (fusion.length) {
    groups.push({
      key: 'fusion',
      label: '融合影像',
      kind: 'fusion',
      totalCount: fusion.length,
      images: fusion.map((a) => ({
        id: a.id,
        label: a.label || '融合预览',
      })),
    })
  }

  const byClass = new Map()
  for (const a of artifacts.value) {
    if (a.type !== 'detection_preview' && a.type !== 'detection_tile') continue
    const classDir = a.metadata?.class_dir || 'unknown'
    if (!byClass.has(classDir)) byClass.set(classDir, [])
    byClass.get(classDir).push({
      id: a.id,
      label: a.label || classDir,
    })
  }

  const detectionGroups = [...byClass.entries()]
    .sort(([a], [b]) => classOrderFromDir(a) - classOrderFromDir(b))
    .map(([classDir, images]) => {
      const sorted = images.sort((x, y) => x.label.localeCompare(y.label))
      const stat = detectionStatsByClass.value.get(classDir)
      return {
        key: `detection-${classDir}`,
        label: classLabelFromDir(classDir),
        kind: 'detection',
        tileCount: stat?.tile_count ?? sorted.length,
        detectionCount: stat?.detection_count ?? 0,
        totalCount: stat?.tile_count ?? sorted.length,
        images: sorted.slice(0, PREVIEW_TILES_PER_CLASS),
      }
    })

  return groups.concat(detectionGroups)
})

const detectionTileCount = computed(() => {
  if (detectionStats.value?.total_tiles) {
    return detectionStats.value.total_tiles
  }
  return artifacts.value.filter((a) => a.type === 'detection_preview' || a.type === 'detection_tile').length
})

const downloadArtifacts = computed(() =>
  artifacts.value.filter((a) => !isImageArtifact(a))
)

const activePreviewGroup = computed(() =>
  previewGroups.value.find((g) => g.key === activePreviewTab.value) || null
)

const activePreviewImage = computed(() => {
  const group = activePreviewGroup.value
  if (!group?.images.length) return null
  const index = Math.min(activeImageIndex.value, group.images.length - 1)
  return group.images[index]
})

const activePreviewImageUrl = computed(() => {
  if (!selectedTask.value || !activePreviewImage.value) return ''
  return artifactDownloadUrl(selectedTask.value.id, activePreviewImage.value.id)
})

watch(previewGroups, (groups) => {
  if (!groups.length) {
    activePreviewTab.value = ''
    activeImageIndex.value = 0
    return
  }
  if (!groups.some((g) => g.key === activePreviewTab.value)) {
    activePreviewTab.value = groups[0].key
    activeImageIndex.value = 0
  }
})

function selectPreviewTab(key) {
  activePreviewTab.value = key
  activeImageIndex.value = 0
}

function shiftPreviewImage(delta) {
  const group = activePreviewGroup.value
  if (!group?.images.length) return
  const next = (activeImageIndex.value + delta + group.images.length) % group.images.length
  activeImageIndex.value = next
}

const isLiveRefreshing = computed(() => selectedTask.value?.status === 'running')

const currentStageText = computed(() => {
  if (!selectedTask.value) return '-'
  const current = selectedTask.value.current_stage
  if (current) return stageNameText(current)
  const runningStage = stages.value.find((stage) => stage.status === 'running')
  if (runningStage) return stageNameText(runningStage.name)
  if (selectedTask.value.status === 'completed') return '全部阶段完成'
  return '-'
})

const durationText = computed(() => {
  if (!selectedTask.value?.started_at) return '-'
  const startTs = new Date(selectedTask.value.started_at).getTime()
  const endTs = selectedTask.value.finished_at
    ? new Date(selectedTask.value.finished_at).getTime()
    : nowTick.value
  const seconds = Math.max(0, Math.floor((endTs - startTs) / 1000))
  const minutes = Math.floor(seconds / 60)
  const remainSeconds = seconds % 60
  return `${minutes} 分 ${remainSeconds} 秒`
})

const stageDurationRanking = computed(() => {
  if (!stages.value.length) return []
  const items = stages.value
    .map((stage) => {
      if (!stage.started_at) return null
      const startTs = new Date(stage.started_at).getTime()
      const endTs =
        stage.finished_at && (stage.status === 'success' || stage.status === 'failed')
          ? new Date(stage.finished_at).getTime()
          : nowTick.value
      const seconds = Math.max(0, Math.floor((endTs - startTs) / 1000))
      return {
        name: stage.name,
        title: stage.title || stageNameText(stage.name),
        seconds,
        durationText: formatDuration(seconds),
      }
    })
    .filter(Boolean)
  return items.sort((a, b) => b.seconds - a.seconds).slice(0, 3)
})

const etaText = computed(() => {
  if (!selectedTask.value) return '-'
  if (selectedTask.value.status === 'completed') return '0 分 0 秒'
  if (selectedTask.value.status === 'failed') return '-'

  const finished = stages.value.filter((stage) => stage.status === 'success')
  const pendingCount = stages.value.filter((stage) => stage.status === 'pending' || stage.status === 'running').length
  if (!finished.length || !pendingCount) return '-'

  const totalSeconds = finished.reduce((sum, stage) => {
    if (!stage.started_at || !stage.finished_at) return sum
    const startTs = new Date(stage.started_at).getTime()
    const endTs = new Date(stage.finished_at).getTime()
    return sum + Math.max(0, Math.floor((endTs - startTs) / 1000))
  }, 0)

  if (!totalSeconds) return '-'
  const avgSeconds = Math.round(totalSeconds / finished.length)
  return formatDuration(avgSeconds * pendingCount)
})

function statusText(status) {
  return STATUS_TEXT_MAP[status] || status || '-'
}

function stageStatusText(status) {
  return STATUS_TEXT_MAP[status] || status || '-'
}

function stageNameText(name) {
  return STAGE_TITLE_MAP[name] || name || ''
}

function artifactUrl(id) {
  if (!selectedTask.value) return '#'
  return artifactDownloadUrl(selectedTask.value.id, id)
}

function formatTime(value) {
  if (!value) return '-'
  return new Intl.DateTimeFormat('zh-CN', {
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(new Date(value))
}

function formatDuration(seconds) {
  const safe = Math.max(0, Number(seconds) || 0)
  const minutes = Math.floor(safe / 60)
  const remainSeconds = safe % 60
  return `${minutes} 分 ${remainSeconds} 秒`
}

function formatDetails(details) {
  if (!details) return ''
  if (typeof details === 'string') return details
  const completed = details.completed
  const total = details.total
  if (typeof completed === 'number' && typeof total === 'number') {
    return `子步骤：${completed}/${total}`
  }
  return JSON.stringify(details)
}

async function loadTasks(preferredId, options = {}) {
  const { autoSelect = true } = options
  try {
    const data = await listRemoteSensingTasks()
    tasks.value = data
    await ensureSatelliteLookup(data)

    if (!data.length) {
      selectedTask.value = null
      stages.value = []
      logs.value = []
      artifacts.value = []
      detectionStats.value = null
      stopEventStream()
      stopPolling()
      return
    }

    if (selectedTask.value) {
      const latestSelected = data.find((item) => item.id === selectedTask.value.id)
      if (latestSelected) selectedTask.value = latestSelected
    }

    if (!autoSelect) return

    const target = preferredId ? data.find((item) => item.id === preferredId) : selectedTask.value
    if (target) {
      const changed = selectedTask.value?.id !== target.id
      selectedTask.value = target
      if (changed) await loadDetails(target.id)
      syncLiveRefresh()
      return
    }

    selectedTask.value = data[0]
    await loadDetails(data[0].id)
    syncLiveRefresh()
  } catch (err) {
    console.error('任务列表加载失败', err)
  }
}

async function loadDetails(taskId) {
  const task = selectedTask.value
  const statsPromise =
    task?.enable_detection !== false
      ? getRemoteSensingDetectionStats(taskId).catch(() => null)
      : Promise.resolve(null)

  const [stageData, logData, artifactData, statsData] = await Promise.all([
    getRemoteSensingStages(taskId),
    getRemoteSensingLogs(taskId, 200),
    getRemoteSensingArtifacts(taskId),
    statsPromise,
  ])
  stages.value = stageData
  logs.value = logData
  artifacts.value = artifactData
  detectionStats.value = statsData
}

async function selectTask(task) {
  selectedTask.value = task
  await loadDetails(task.id)
  syncLiveRefresh()
}

function scheduleDetailRefresh(taskId) {
  if (detailRefreshTimer.value) return
  detailRefreshTimer.value = setTimeout(async () => {
    detailRefreshTimer.value = null
    if (!selectedTask.value || selectedTask.value.id !== taskId) return
    await loadDetails(taskId)
    await loadTasks(taskId, { autoSelect: false })
    syncLiveRefresh()
  }, 800)
}

function syncLiveRefresh() {
  if (!selectedTask.value) {
    stopEventStream()
    stopPolling()
    return
  }
  if (selectedTask.value.status === 'running') {
    startEventStream(selectedTask.value.id)
    startPolling(selectedTask.value.id)
    return
  }
  stopEventStream()
  stopPolling()
}

function startEventStream(taskId) {
  if (eventTaskId.value === taskId && eventSource.value) return
  stopEventStream()

  eventTaskId.value = taskId
  eventSource.value = streamRemoteSensingEvents(
    taskId,
    (payload) => {
      if (!payload || !selectedTask.value || selectedTask.value.id !== taskId) return

      if (payload.stage_name) {
        selectedTask.value.current_stage = payload.stage_name
      }

      const idx = stages.value.findIndex((stage) => stage.name === payload.stage_name)
      if (idx >= 0) {
        stages.value[idx] = {
          ...stages.value[idx],
          status: payload.status,
          message: payload.message || stages.value[idx].message,
          details: payload.details || stages.value[idx].details,
        }
      }

      if (payload.task_status) {
        selectedTask.value.status = payload.task_status
      }

      scheduleDetailRefresh(taskId)
    },
    () => {
      stopEventStream()
      if (selectedTask.value && selectedTask.value.id === taskId && selectedTask.value.status === 'running') {
        if (reconnectTimer.value) clearTimeout(reconnectTimer.value)
        reconnectTimer.value = setTimeout(() => {
          reconnectTimer.value = null
          if (selectedTask.value && selectedTask.value.id === taskId && selectedTask.value.status === 'running') {
            startEventStream(taskId)
          }
        }, 1500)
      }
    }
  )
}

function stopEventStream() {
  if (eventSource.value) {
    eventSource.value.close()
    eventSource.value = null
  }
  if (reconnectTimer.value) {
    clearTimeout(reconnectTimer.value)
    reconnectTimer.value = null
  }
  eventTaskId.value = null
}

function startPolling(taskId) {
  if (pollTimer.value && pollTaskId.value === taskId) return
  stopPolling()
  pollTaskId.value = taskId
  pollTimer.value = setInterval(async () => {
    if (!selectedTask.value || selectedTask.value.id !== taskId) {
      stopPolling()
      return
    }
    await loadDetails(taskId)
    await loadTasks(taskId, { autoSelect: false })
    if (selectedTask.value?.status !== 'running') {
      syncLiveRefresh()
    }
  }, 4000)
}

function stopPolling() {
  if (pollTimer.value) {
    clearInterval(pollTimer.value)
    pollTimer.value = null
  }
  pollTaskId.value = null
}

async function submitTask() {
  if (!form.filePrefix || !form.inputDirectory) {
    submitMessage.value = '请填写预处理必填字段'
    return
  }
  if (!form.scenarioId || !form.satelliteId) {
    submitMessage.value = '请选择仿真场景与执行卫星（60 节点输入仅在锚点 sat1/sat21/sat41）'
    return
  }

  let detectionClasses = ''
  if (form.enableDetection) {
    const built = buildDetectionClassesParam()
    if (built === null) {
      submitMessage.value = '请至少勾选一个检测类别'
      return
    }
    detectionClasses = built
  }

  submitMessage.value = '正在提交...'
  try {
    await createRemoteSensingTask({
      name: form.name,
      filePrefix: form.filePrefix,
      inputDirectory: form.inputDirectory,
      sensor: form.sensor,
      enableDetection: form.enableDetection,
      detectionClasses,
      detectionDrawLabels: form.detectionDrawLabels,
      scenarioId: form.scenarioId,
      satelliteId: form.satelliteId,
    })
    submitMessage.value = '任务已提交（预处理 → 目标识别串行执行）'
    form.name = ''
    form.filePrefix = ''
    form.inputDirectory = 'input'
    form.sensor = ''
    await loadTasks()
  } catch (err) {
    submitMessage.value = err.message || '提交失败'
  }
}

onMounted(async () => {
  await loadScenarios()
  const preferredId = route.query.task ? Number(route.query.task) : undefined
  await loadTasks(preferredId)
  nowTickTimer.value = setInterval(() => {
    nowTick.value = Date.now()
  }, 1000)
})

onBeforeUnmount(() => {
  stopEventStream()
  stopPolling()
  if (detailRefreshTimer.value) {
    clearTimeout(detailRefreshTimer.value)
    detailRefreshTimer.value = null
  }
  if (nowTickTimer.value) {
    clearInterval(nowTickTimer.value)
    nowTickTimer.value = null
  }
})
</script>

<style scoped>
.remote-sensing-page {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  background: linear-gradient(180deg, #f5f8fe 0%, #eef3fb 100%);
}

.card {
  background: #fff;
  border: 1px solid #e8edf8;
  border-radius: 12px;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.04);
}

.page-header {
  padding: 1rem 1.2rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.page-header h1 {
  margin: 0;
  font-size: 1.5rem;
}

.page-header p {
  margin: 0.35rem 0 0;
  color: #5a647a;
}

.form-section {
  border: 1px solid #e8edf8;
  border-radius: 8px;
  padding: 0.75rem 0.85rem 0.25rem;
  margin-bottom: 0.85rem;
}

.form-section legend {
  font-weight: 600;
  font-size: 0.9rem;
  color: #3d4a63;
  padding: 0 0.35rem;
}

.pipeline-hint.card-inline {
  margin-bottom: 1rem;
  padding: 0.65rem 0.85rem;
  background: #f8fafd;
  border: 1px solid #e8edf8;
  border-radius: 8px;
  font-size: 0.88rem;
  color: #5a647a;
}

.checkbox-row {
  flex-direction: row !important;
  align-items: center;
  gap: 0.5rem;
}

.form-hint {
  font-size: 0.82rem;
  color: #6b758a;
  margin: 0.25rem 0 0.5rem;
}

.class-picker {
  margin: 0.5rem 0 0.75rem;
}

.class-picker-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.35rem;
}

.class-picker-title {
  font-weight: 600;
  font-size: 0.88rem;
  color: #3d4a63;
}

.class-picker-actions {
  display: flex;
  gap: 0.5rem;
}

.link-btn {
  border: none;
  background: none;
  color: #1265d8;
  font-size: 0.82rem;
  cursor: pointer;
  padding: 0;
}

.class-checkbox-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.45rem;
}

.class-checkbox-item {
  display: flex;
  flex-direction: row;
  align-items: flex-start;
  gap: 0.45rem;
  padding: 0.5rem 0.55rem;
  border: 1px solid #e8edf8;
  border-radius: 8px;
  background: #fafbfd;
  cursor: pointer;
  margin: 0;
}

.class-checkbox-item input {
  margin-top: 0.2rem;
  flex-shrink: 0;
}

.class-text {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  min-width: 0;
}

.class-label {
  font-size: 0.88rem;
  font-weight: 600;
  color: #2f3a4f;
  line-height: 1.3;
}

.class-name-en {
  display: block;
  font-size: 0.75rem;
  color: #8a94a8;
  font-weight: 400;
}

.class-summary {
  margin: 0.55rem 0 0;
  font-size: 0.84rem;
  color: #1265d8;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}

.live-indicator {
  font-size: 0.82rem;
  padding: 0.24rem 0.6rem;
  border-radius: 999px;
  background: #f2f4f8;
  color: #5f6b80;
}

.live-indicator.on {
  background: #e4f7ec;
  color: #157347;
}

.page-body {
  display: grid;
  grid-template-columns: minmax(320px, 360px) 1fr;
  gap: 1rem;
  min-height: 0;
}

.task-panel {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.task-form,
.task-list,
.detail-panel,
.detail-placeholder {
  padding: 1rem;
}

.task-form h2 {
  margin: 0 0 0.8rem;
  font-size: 1.05rem;
}

.task-form label {
  display: flex;
  flex-direction: column;
  margin-bottom: 0.75rem;
  font-size: 0.88rem;
  color: #4e5a71;
}

.task-form input,
.task-form select {
  margin-top: 0.35rem;
  padding: 0.55rem 0.6rem;
  border: 1px solid #d8dfed;
  border-radius: 6px;
  font-size: 0.93rem;
}

.task-topology-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.topology-link {
  color: #1265d8;
  font-size: 0.82rem;
  text-decoration: none;
}

.topology-link:hover {
  text-decoration: underline;
}

.topology-link.inline {
  margin-left: 0.35rem;
}

.task-node-hint {
  font-size: 0.82rem;
  color: #6b758a;
}

.task-topology-row.muted {
  color: #8a94a8;
  font-style: italic;
}

.form-section--optional legend {
  color: #6b758a;
}

.form-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.form-actions button {
  background: #1265d8;
  color: #fff;
  border: none;
  padding: 0.55rem 1rem;
  border-radius: 6px;
  cursor: pointer;
}

.form-note {
  color: #5f6b80;
  font-size: 0.86rem;
}

.task-list {
  max-height: calc(100vh - 220px);
  overflow-y: auto;
}

.task-list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.task-list-header h3 {
  margin: 0;
  font-size: 1rem;
}

.task-card {
  border: 1px solid #e8edf8;
  border-radius: 10px;
  padding: 0.85rem;
  margin-top: 0.75rem;
}

.task-card.pending {
  border-left: 4px solid #d38f27;
}

.task-card.running {
  border-left: 4px solid #0f71d8;
}

.task-card.completed {
  border-left: 4px solid #23884f;
}

.task-card.failed {
  border-left: 4px solid #bd3b3b;
}

.task-card-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.6rem;
}

.task-card-head button {
  border: none;
  background: #edf3ff;
  padding: 0.35rem 0.75rem;
  border-radius: 6px;
  cursor: pointer;
}

.task-card-head button:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.task-name {
  font-weight: 600;
  overflow-wrap: anywhere;
}

.task-meta {
  margin: 0.2rem 0 0;
  color: #67738b;
  font-size: 0.82rem;
  overflow-wrap: anywhere;
}

.task-body {
  margin-top: 0.65rem;
  font-size: 0.84rem;
  color: #4e5a71;
}

.task-body div {
  overflow-wrap: anywhere;
}

.detail-panel {
  display: flex;
  flex-direction: column;
  gap: 0.9rem;
}

.detail-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.6rem;
}

.detail-header h2 {
  margin: 0;
  overflow-wrap: anywhere;
}

.status-chip {
  padding: 0.22rem 0.85rem;
  border-radius: 999px;
  font-size: 0.82rem;
  background: #f0f4fc;
  color: #4e5a71;
  white-space: nowrap;
}

.status-chip.running {
  background: #eaf3ff;
  color: #0f71d8;
}

.status-chip.completed {
  background: #e7f8ef;
  color: #23884f;
}

.status-chip.failed {
  background: #fdecec;
  color: #bd3b3b;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(120px, 1fr));
  gap: 0.6rem;
}

.summary-item {
  border: 1px solid #e8edf8;
  border-radius: 8px;
  padding: 0.55rem 0.65rem;
  background: #f9fbff;
}

.summary-item span {
  display: block;
  color: #697489;
  font-size: 0.78rem;
}

.summary-item strong {
  display: block;
  margin-top: 0.24rem;
  font-size: 0.9rem;
  color: #2d3748;
  overflow-wrap: anywhere;
}

.progress-wrap {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.progress-wrap > span {
  white-space: nowrap;
  color: #4e5a71;
  font-size: 0.84rem;
}

.progress-bar {
  height: 10px;
  border-radius: 999px;
  background: #edf2fb;
  overflow: hidden;
  flex: 1;
}

.progress-bar__fill {
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, #2f7df0, #54a8ff);
}

.stage-rank {
  border: 1px solid #e8edf8;
  border-radius: 10px;
  padding: 0.75rem 0.85rem;
  background: #fbfdff;
}

.stage-rank h3 {
  margin: 0 0 0.5rem;
  font-size: 0.95rem;
}

.stage-rank ul {
  margin: 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.stage-rank li {
  display: flex;
  justify-content: space-between;
  gap: 0.6rem;
  font-size: 0.86rem;
  color: #4e5a71;
}

.stage-rank li span {
  overflow-wrap: anywhere;
}

.stage-rank li strong {
  white-space: nowrap;
}

.timeline {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.timeline-stage {
  border: 1px solid #e8edf8;
  border-radius: 10px;
  padding: 0.72rem;
}

.timeline-stage.running {
  border-color: #b9d8ff;
  background: #f5faff;
}

.timeline-stage.failed {
  border-color: #f4cbcb;
  background: #fff8f8;
}

.timeline-stage header {
  display: flex;
  align-items: center;
  gap: 0.7rem;
}

.circle {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #cdd6e5;
}

.circle.success {
  background: #23884f;
}

.circle.running {
  background: #0f71d8;
}

.circle.failed {
  background: #bd3b3b;
}

.stage-name {
  font-weight: 600;
  overflow-wrap: anywhere;
}

.stage-meta {
  margin: 0;
  font-size: 0.8rem;
  color: #6f7b91;
}

.stage-message,
.stage-details {
  display: block;
  margin-top: 0.35rem;
  color: #4e5a71;
  font-size: 0.85rem;
  overflow-wrap: anywhere;
}

.result-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.9rem;
}

.preview,
.logs {
  padding: 0.9rem;
  border: 1px solid #e8edf8;
  border-radius: 10px;
  background: #fbfdff;
  min-height: 240px;
}

.preview h3,
.logs h3,
.preview h4 {
  margin: 0 0 0.55rem;
}

.preview-image img {
  width: 100%;
  border-radius: 10px;
  display: block;
  background: #eef2f8;
}

.detection-download-bar {
  margin-top: 0.65rem;
}

.detection-download-bar .primary.sm {
  display: inline-flex;
  align-items: center;
  padding: 0.45rem 0.85rem;
  font-size: 0.85rem;
  text-decoration: none;
  border-radius: 8px;
  background: #1265d8;
  color: #fff;
}

.detection-download-bar .primary.sm:hover {
  background: #0f54b8;
}

.preview-gallery {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.preview-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.preview-tab {
  border: 1px solid #d8dfed;
  background: #fff;
  border-radius: 999px;
  padding: 0.35rem 0.75rem;
  font-size: 0.82rem;
  cursor: pointer;
  color: #4e5a71;
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.preview-tab.active {
  border-color: #1265d8;
  background: #edf4ff;
  color: #1265d8;
  font-weight: 600;
}

.tab-count {
  font-size: 0.75rem;
  opacity: 0.85;
}

.tab-label {
  margin-right: 0.15rem;
}

.tab-stats {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
}

.tab-stat {
  font-size: 0.72rem;
  padding: 0.08rem 0.4rem;
  border-radius: 999px;
  background: #eef2f8;
  color: #5a647a;
}

.tab-stat--target {
  background: #e8f2ff;
  color: #1265d8;
}

.detection-summary {
  margin: 0 0 0.5rem;
  font-size: 0.84rem;
  color: #5a647a;
}

.preview-main {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.preview-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  font-size: 0.82rem;
  color: #5a647a;
}

.preview-counter {
  flex: 1;
  text-align: center;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ghost.sm {
  padding: 0.3rem 0.55rem;
  font-size: 0.8rem;
}

.thumb-strip {
  display: flex;
  gap: 0.35rem;
  overflow-x: auto;
  padding-bottom: 0.15rem;
}

.thumb-btn {
  border: 2px solid transparent;
  border-radius: 6px;
  padding: 0;
  background: none;
  cursor: pointer;
  flex-shrink: 0;
  width: 56px;
  height: 56px;
  overflow: hidden;
}

.thumb-btn.active {
  border-color: #1265d8;
}

.thumb-btn img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.preview-caption {
  margin: 0;
  font-size: 0.8rem;
  color: #8a94a8;
}

.artifact-downloads {
  margin-top: 0.75rem;
  font-size: 0.88rem;
}

.artifact-downloads summary {
  cursor: pointer;
  color: #1265d8;
  user-select: none;
}

.placeholder {
  color: #7a859a;
  font-size: 0.88rem;
}

.artifact-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.artifact-list a {
  color: #176cd4;
  overflow-wrap: anywhere;
}

.log-list {
  max-height: 320px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.log-line {
  background: #fff;
  border-radius: 8px;
  padding: 0.5rem;
  border: 1px solid #e8edf8;
}

.log-line small {
  display: block;
  margin-bottom: 0.3rem;
  color: #78849b;
}

.log-line p {
  margin: 0;
  color: #354154;
  overflow-wrap: anywhere;
}

.detail-placeholder {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 460px;
  color: #7b879c;
}

.ghost {
  background: transparent;
  border: 1px solid #cfd8ea;
  padding: 0.45rem 0.9rem;
  border-radius: 6px;
  cursor: pointer;
}

@media (max-width: 1100px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(120px, 1fr));
  }
}

@media (max-width: 960px) {
  .page-body {
    grid-template-columns: 1fr;
  }

  .task-list {
    max-height: none;
  }

  .result-grid {
    grid-template-columns: 1fr;
  }
}
</style>
