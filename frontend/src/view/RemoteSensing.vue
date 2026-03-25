<template>
  <div class="remote-sensing-page">
    <header class="page-header card">
      <div>
        <h1>遥感应用</h1>
        <p>实时追踪遥感预处理任务进度、日志与产物。</p>
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
          <h2>创建遥感任务</h2>
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
                </p>
              </div>
              <button type="button" @click="selectTask(task)" :disabled="selectedTask?.id === task.id">
                详情
              </button>
            </div>
            <div class="task-body">
              <div>文件前缀：{{ task.file_prefix }}</div>
              <div>目录：{{ task.input_directory }}</div>
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
            <div v-if="previewUrl" class="preview-image">
              <img :src="previewUrl" alt="融合预览" />
            </div>
            <p v-else class="placeholder">暂无预览图，请等待结果产出。</p>

            <h4>产物下载</h4>
            <ul class="artifact-list" v-if="artifacts.length">
              <li v-for="artifact in artifacts" :key="artifact.id">
                <a :href="artifactUrl(artifact.id)" target="_blank" rel="noreferrer">
                  {{ artifact.label || artifact.type }}
                </a>
              </li>
            </ul>
            <p v-else class="placeholder">暂无产物</p>
          </div>

          <div class="logs">
            <h3>执行日志</h3>
            <div v-if="logs.length" class="log-list">
              <div v-for="log in displayLogs" :key="log.id" class="log-line">
                <small>{{ formatTime(log.created_at) }} · {{ stageNameText(log.stage_name) || '全局' }}</small>
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
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import {
  listRemoteSensingTasks,
  createRemoteSensingTask,
  getRemoteSensingStages,
  getRemoteSensingLogs,
  getRemoteSensingArtifacts,
  streamRemoteSensingEvents,
  artifactDownloadUrl,
} from '../api/remoteSensing'

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
}

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
const submitMessage = ref('')

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
})

const completedStages = computed(
  () => stages.value.filter((stage) => stage.status === 'success' || stage.status === 'failed').length
)

const stageProgress = computed(() => {
  if (!stages.value.length) return 0
  return Math.round((completedStages.value / stages.value.length) * 100)
})

const displayLogs = computed(() => [...logs.value].reverse())

const previewUrl = computed(() => {
  if (!selectedTask.value) return ''
  const preview = artifacts.value.find((artifact) => artifact.type === 'preview')
  if (!preview) return ''
  return artifactDownloadUrl(selectedTask.value.id, preview.id)
})

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

    if (!data.length) {
      selectedTask.value = null
      stages.value = []
      logs.value = []
      artifacts.value = []
      stopEventStream()
      stopPolling()
      return
    }

    if (selectedTask.value) {
      const latestSelected = data.find((item) => item.id === selectedTask.value.id)
      if (latestSelected) {
        selectedTask.value = latestSelected
      }
    }

    if (!autoSelect) return

    const target = preferredId ? data.find((item) => item.id === preferredId) : selectedTask.value
    if (target) {
      const changed = selectedTask.value?.id !== target.id
      selectedTask.value = target
      if (changed) {
        await loadDetails(target.id)
      }
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
  const [stageData, logData, artifactData] = await Promise.all([
    getRemoteSensingStages(taskId),
    getRemoteSensingLogs(taskId, 200),
    getRemoteSensingArtifacts(taskId),
  ])
  stages.value = stageData
  logs.value = logData
  artifacts.value = artifactData
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
        if (reconnectTimer.value) {
          clearTimeout(reconnectTimer.value)
        }
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
    if (selectedTask.value.status !== 'running') {
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
    submitMessage.value = '请填写必填字段'
    return
  }

  submitMessage.value = '正在提交...'
  try {
    await createRemoteSensingTask({
      name: form.name,
      filePrefix: form.filePrefix,
      inputDirectory: form.inputDirectory,
      sensor: form.sensor,
    })
    submitMessage.value = '任务已提交'
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
  await loadTasks()
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

.task-form input {
  margin-top: 0.35rem;
  padding: 0.55rem 0.6rem;
  border: 1px solid #d8dfed;
  border-radius: 6px;
  font-size: 0.93rem;
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
  margin-bottom: 0.6rem;
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
