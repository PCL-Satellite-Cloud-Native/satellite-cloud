<template>
  <div class="crd-page">
    <!-- 顶栏 -->
    <header class="crd-header">
      <div class="header-left">
        <h1 class="page-title">
          <span class="title-badge">CRD</span>
          声明式清单管理
        </h1>
        <p class="page-desc">
          将场景 / 卫星 / 拓扑 / 任务队列 / 存储后端 / 遥感任务 / 检测任务收敛为
          kubectl 风格的 YAML 清单（cloud.satellite.io/v1），一键同步到数据库
        </p>
      </div>
      <div class="header-actions">
        <BackHomeButton mode="inline" />
        <span class="sync-path" :title="syncInfo">
          清单目录：{{ lastDir || 'config/declarative' }}
        </span>
        <button class="btn btn-ghost" :disabled="loading" @click="loadAll">
          {{ loading ? '加载中…' : '刷新数据' }}
        </button>
        <button class="btn btn-primary" :disabled="syncing" @click="runSync">
          <span v-if="syncing" class="spinner" />
          {{ syncing ? '同步中…' : '执行同步' }}
        </button>
      </div>
    </header>

    <div v-if="errorMsg" class="error-banner">同步失败：{{ errorMsg }}</div>

    <!-- 概览统计 -->
    <section class="stat-grid">
      <div v-for="m in moduleStats" :key="m.kind" class="stat-card" :style="{ '--accent': m.color }">
        <div class="stat-head">
          <span class="stat-kind">{{ m.short }}</span>
          <span class="stat-dot" :class="m.ok ? 'ok' : 'warn'" />
        </div>
        <div class="stat-num">{{ m.count }}</div>
        <div class="stat-label">{{ m.label }}</div>
        <div class="stat-status" :class="m.ok ? 'ok' : 'warn'">
          {{ m.ok ? '同步正常' : '待同步/暂无数据' }}
        </div>
      </div>
    </section>

    <!-- 同步结果 -->
    <section class="panel" v-if="results.length">
      <div class="panel-head">
        <h2 class="panel-title">最近一次同步结果（{{ lastDir || 'config/declarative' }}）</h2>
        <span class="panel-time">同步时间：{{ syncTime }}</span>
      </div>
      <div class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>资源名称</th>
              <th>Kind（CRD 类型）</th>
              <th>动作</th>
              <th>状态</th>
              <th>说明</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(r, i) in results" :key="i">
              <td class="mono">{{ r.name || '-' }}</td>
              <td><span class="kind-tag">{{ r.kind || '-' }}</span></td>
              <td><span class="action-tag" :class="actionClass(r.action)">{{ r.action || '-' }}</span></td>
              <td>
                <span class="status-pill" :class="r.status === 'ok' ? 'ok' : 'err'">
                  {{ r.status || '-' }}
                </span>
              </td>
              <td class="detail-cell" :title="r.detail">{{ r.detail || '-' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- 模块数据 -->
    <section class="panel">
      <div class="panel-head">
        <h2 class="panel-title">各 CRD 模块落库数据</h2>
        <span class="panel-time">与后端 PostgreSQL 实时一致</span>
      </div>
      <div class="tabs">
        <button
          v-for="t in tabs"
          :key="t.key"
          class="tab"
          :class="{ active: activeTab === t.key }"
          @click="activeTab = t.key"
        >
          {{ t.label }}
        </button>
      </div>

      <!-- 清单文件：在线查看 / 修改 / 执行 -->
      <div v-if="activeTab === 'manifest'" class="manifest-wrap">
        <div class="manifest-toolbar">
          <div class="manifest-legend">
            <span class="legend-dot" /> 在线查看
            <span class="legend-dot edit" /> 在线修改
            <span class="legend-dot run" /> 保存 / 执行
          </div>
          <div class="manifest-toolbar-actions">
            <button class="btn btn-ghost btn-sm" :disabled="manifestsLoading" @click="loadManifests">
              {{ manifestsLoading ? '加载中…' : '刷新文件列表' }}
            </button>
            <button
              class="btn btn-ghost btn-sm"
              :disabled="!selectedFile || manifestBusy"
              @click="revertManifest"
            >
              还原未保存修改
            </button>
          </div>
        </div>

        <div class="manifest-body">
          <!-- 左侧：文件列表 -->
          <aside class="manifest-files">
            <div class="manifest-files-head">
              <span>清单目录：{{ manifestDir || lastDir || 'config/declarative' }}</span>
            </div>
            <ul class="file-list">
              <li
                v-for="f in manifests"
                :key="f.name"
                class="file-item"
                :class="{ active: selectedFile === f.name }"
                @click="openManifest(f.name)"
              >
                <div class="file-item-top">
                  <span class="file-name mono">{{ f.name }}</span>
                  <span class="file-size mono">{{ fmtSize(f.size) }}</span>
                </div>
                <div class="file-item-meta">
                  <span class="kind-tag">{{ f.kind || 'Unknown' }}</span>
                  <span class="file-mtime">修改于 {{ f.modified }}</span>
                </div>
              </li>
            </ul>
            <div v-if="!manifests.length && !manifestsLoading" class="manifest-empty">
              未发现 *.yaml 清单文件
            </div>
          </aside>

          <!-- 右侧：YAML 编辑器 -->
          <div class="manifest-editor">
            <div class="editor-head">
              <span class="editor-file mono">{{ selectedFile || '未选择文件' }}</span>
              <span class="editor-state" :class="{ dirty: manifestDirty }">
                {{ manifestDirty ? '● 有未保存的修改' : '● 已同步' }}
              </span>
            </div>
            <textarea
              v-model="yamlContent"
              class="yaml-editor mono"
              spellcheck="false"
              :placeholder="selectedFile ? '在此编辑 YAML 清单…' : '请从左侧选择要查看/编辑的清单文件'"
              :readonly="!selectedFile"
            />
            <div class="editor-actions">
              <div class="editor-msg" :class="{ ok: manifestMsgOk, err: !manifestMsgOk }">
                {{ manifestMsg }}
              </div>
              <div class="editor-btns">
                <button
                  class="btn btn-ghost btn-sm"
                  :disabled="!selectedFile || !manifestDirty || manifestBusy"
                  @click="saveManifest"
                >
                  保存修改
                </button>
                <button
                  class="btn btn-primary btn-sm"
                  :disabled="!selectedFile || manifestBusy"
                  @click="applyManifest"
                >
                  执行该清单
                </button>
              </div>
            </div>
            <div v-if="manifestResults.length" class="manifest-results">
              <h4 class="results-title">最近执行结果</h4>
              <table class="data-table">
                <thead>
                  <tr>
                    <th>资源名称</th>
                    <th>Kind</th>
                    <th>状态</th>
                    <th>说明</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(r, i) in manifestResults" :key="i">
                    <td class="mono">{{ r.name || '-' }}</td>
                    <td><span class="kind-tag">{{ r.kind || '-' }}</span></td>
                    <td>
                      <span class="status-pill" :class="r.status === 'ok' ? 'ok' : 'err'">
                        {{ r.status || '-' }}
                      </span>
                    </td>
                    <td class="detail-cell" :title="r.detail">{{ r.detail || '-' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- 存储后端 -->
      <div v-if="activeTab === 'storage'" class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>名称</th>
              <th>后端类型</th>
              <th>遥感产物根目录</th>
              <th>检测产物根目录</th>
              <th>上传 MinIO</th>
              <th>MinIO Endpoint</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in storageBackends" :key="s.name">
              <td class="mono">{{ s.name }}</td>
              <td><span class="kind-tag">{{ s.backend }}</span></td>
              <td class="mono">{{ s.rs_artifact_root }}</td>
              <td class="mono">{{ s.od_artifact_root }}</td>
              <td>
                <span class="status-pill" :class="s.artifact_upload_minio ? 'ok' : 'off'">
                  {{ s.artifact_upload_minio ? '是' : '否' }}
                </span>
              </td>
              <td class="mono">{{ s.minio_endpoint || '-' }}</td>
            </tr>
            <tr v-if="!storageBackends.length">
              <td colspan="6" class="empty-cell">暂无存储后端声明，请先执行同步</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 任务队列 -->
      <div v-if="activeTab === 'queue'" class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>队列名</th>
              <th>Redis Stream</th>
              <th>消费者组</th>
              <th>并发</th>
              <th>模式</th>
              <th>Redis 地址</th>
              <th>状态</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="q in jobQueues" :key="q.name">
              <td class="mono">{{ q.name }}</td>
              <td class="mono">{{ q.stream }}</td>
              <td class="mono">{{ q.consumer_group }}</td>
              <td>{{ q.concurrency }}</td>
              <td><span class="kind-tag">{{ q.mode }}</span></td>
              <td class="mono">{{ q.redis_addr || '（留空，仅登记声明）' }}</td>
              <td>
                <span class="status-pill" :class="q.enabled ? 'ok' : 'off'">
                  {{ q.enabled ? 'enabled' : 'disabled' }}
                </span>
              </td>
            </tr>
            <tr v-if="!jobQueues.length">
              <td colspan="7" class="empty-cell">暂无队列声明，请先执行同步</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 场景 Constellation -->
      <div v-if="activeTab === 'constellation'" class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>场景 ID</th>
              <th>场景名称</th>
              <th>区域</th>
              <th>轨道面数</th>
              <th>每面卫星数</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="sc in scenarios" :key="sc.id">
              <td>{{ sc.id }}</td>
              <td class="mono">{{ sc.name }}</td>
              <td>{{ sc.region }}</td>
              <td>{{ sc.plane_count }}</td>
              <td>{{ sc.sat_count_per_plane }}</td>
            </tr>
            <tr v-if="!scenarios.length">
              <td colspan="5" class="empty-cell">暂无场景数据，请先执行同步</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 遥感任务 -->
      <div v-if="activeTab === 'rstask'" class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>任务 ID</th>
              <th>名称</th>
              <th>场景</th>
              <th>卫星</th>
              <th>传感器</th>
              <th>状态</th>
              <th>检测</th>
              <th>创建时间</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in rsTasks" :key="t.id">
              <td>{{ t.id }}</td>
              <td class="mono">{{ t.name || '-' }}</td>
              <td>{{ t.scenario_id }}</td>
              <td class="mono">{{ t.satellite_id || '-' }}</td>
              <td>{{ t.sensor || '-' }}</td>
              <td>
                <span class="status-pill" :class="statusClass(t.status)">{{ t.status }}</span>
              </td>
              <td>{{ t.enable_detection ? 'YOLOv8' : '否' }}</td>
              <td class="mono">{{ fmtTime(t.created_at) }}</td>
            </tr>
            <tr v-if="!rsTasks.length">
              <td colspan="8" class="empty-cell">暂无遥感任务，请先执行同步</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 检测任务 -->
      <div v-if="activeTab === 'odtask'" class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>任务 ID</th>
              <th>名称</th>
              <th>输入文件</th>
              <th>类别</th>
              <th>状态</th>
              <th>创建时间</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in odTasks" :key="t.id">
              <td>{{ t.id }}</td>
              <td class="mono">{{ t.name || '-' }}</td>
              <td class="mono detail-cell" :title="t.input_path">{{ t.input_path || '-' }}</td>
              <td>{{ t.classes || '-' }}</td>
              <td>
                <span class="status-pill" :class="statusClass(t.status)">{{ t.status }}</span>
              </td>
              <td class="mono">{{ fmtTime(t.created_at) }}</td>
            </tr>
            <tr v-if="!odTasks.length">
              <td colspan="6" class="empty-cell">暂无检测任务，请先执行同步</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <footer class="crd-footer">
      CRD 清单格式：cloud.satellite.io/v1 · 同步入口 POST /api/crd/sync · 清单目录由
      SATELLITE_CRD_CONFIG_DIR 指定（默认 config/declarative）
    </footer>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import BackHomeButton from '../components/BackHomeButton.vue'
import {
  syncCrd,
  listJobQueues,
  listStorageBackends,
  listCrdManifests,
  getCrdManifest,
  saveCrdManifest,
  applyCrdManifest,
} from '../api/crd.js'
import { getScenarios } from '../api/satellite.js'
import { listRemoteSensingTasks } from '../api/remoteSensing.js'
import { listObjectDetectionTasks } from '../api/objectDetection.js'

const loading = ref(false)
const syncing = ref(false)
const errorMsg = ref('')
const results = ref([])
const lastDir = ref('')
const syncTime = ref('')

const storageBackends = ref([])
const jobQueues = ref([])
const scenarios = ref([])
const rsTasks = ref([])
const odTasks = ref([])

const activeTab = ref('manifest')
const tabs = [
  { key: 'manifest', label: '清单文件 Manifest' },
  { key: 'storage', label: '存储后端 StorageBackend' },
  { key: 'queue', label: '任务队列 JobQueue' },
  { key: 'constellation', label: '场景 SatelliteConstellation' },
  { key: 'rstask', label: '遥感任务 RemoteSensingTask' },
  { key: 'odtask', label: '检测任务 ObjectDetectionTask' },
]

// ---- 清单文件在线查看 / 修改 / 执行 ----
const manifests = ref([])
const manifestDir = ref('')
const manifestsLoading = ref(false)
const selectedFile = ref('')
const yamlContent = ref('')
const manifestDirty = ref(false)
const manifestBusy = ref(false)
const manifestMsg = ref('请从左侧选择一个清单文件进行查看，修改后可保存并执行')
const manifestMsgOk = ref(true)
const manifestResults = ref([])

async function loadManifests() {
  manifestsLoading.value = true
  manifestMsg.value = ''
  try {
    const data = await listCrdManifests()
    manifestDir.value = data.config_dir || ''
    manifests.value = Array.isArray(data.files) ? data.files : []
  } catch (err) {
    manifestMsgOk.value = false
    manifestMsg.value = `加载清单文件列表失败：${err.message || err}`
  } finally {
    manifestsLoading.value = false
  }
}

async function openManifest(filename) {
  selectedFile.value = filename
  manifestDirty.value = false
  manifestMsgOk.value = true
  manifestMsg.value = '加载中…'
  try {
    const data = await getCrdManifest(filename)
    yamlContent.value = data.content || ''
    manifestMsgOk.value = true
    manifestMsg.value = `已打开 ${data.kind || '清单'}（${filename}），可直接编辑`
  } catch (err) {
    manifestMsgOk.value = false
    manifestMsg.value = `读取 ${filename} 失败：${err.message || err}`
  }
}

function revertManifest() {
  if (selectedFile.value) {
    openManifest(selectedFile.value)
    manifestMsgOk.value = true
    manifestMsg.value = '已还原为服务器上的最新内容'
  }
}

async function saveManifest() {
  if (!selectedFile.value) return
  manifestBusy.value = true
  manifestMsg.value = '保存中…'
  try {
    await saveCrdManifest(selectedFile.value, yamlContent.value)
    manifestDirty.value = false
    manifestMsgOk.value = true
    manifestMsg.value = `已保存 ${selectedFile.value}（已通过 YAML 结构校验），可点击「执行该清单」生效`
    await loadManifests()
  } catch (err) {
    manifestMsgOk.value = false
    manifestMsg.value = `保存失败：${err.message || err}`
  } finally {
    manifestBusy.value = false
  }
}

async function applyManifest() {
  if (!selectedFile.value) return
  manifestBusy.value = true
  manifestMsg.value = '执行中…'
  try {
    const data = await applyCrdManifest(selectedFile.value)
    manifestResults.value = Array.isArray(data.results) ? data.results : []
    const r = manifestResults.value[0]
    manifestMsgOk.value = r && r.status === 'ok'
    manifestMsg.value = r
      ? `${selectedFile.value} 执行完成：${r.action || ''} / ${r.detail || ''}`
      : `${selectedFile.value} 执行完成`
    if (r && r.status === 'ok') {
      await loadAll()
    }
  } catch (err) {
    manifestMsgOk.value = false
    manifestMsg.value = `执行失败：${err.message || err}`
  } finally {
    manifestBusy.value = false
  }
}

function fmtSize(bytes) {
  if (!bytes && bytes !== 0) return '-'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}

const syncInfo = computed(() => `清单目录：${lastDir.value || 'config/declarative'}`)

function asArray(data, fallback) {
  if (Array.isArray(data)) return data
  if (data && typeof data === 'object') {
    for (const key of ['results', 'tasks', 'scenarios', 'satellites', 'queues', 'storage_backends']) {
      if (Array.isArray(data[key])) return data[key]
    }
  }
  return fallback
}

async function loadAll() {
  loading.value = true
  errorMsg.value = ''
  try {
    const [storageRes, queueRes, scenarioRes, rsRes, odRes] = await Promise.allSettled([
      listStorageBackends(),
      listJobQueues(),
      getScenarios(),
      listRemoteSensingTasks(),
      listObjectDetectionTasks(),
    ])
    storageBackends.value = storageRes.status === 'fulfilled'
      ? asArray(storageRes.value, []).filter((x) => x && typeof x === 'object') : []
    jobQueues.value = queueRes.status === 'fulfilled'
      ? asArray(queueRes.value, []).filter((x) => x && typeof x === 'object') : []
    scenarios.value = scenarioRes.status === 'fulfilled'
      ? asArray(scenarioRes.value, []).filter((x) => x && typeof x === 'object') : []
    rsTasks.value = rsRes.status === 'fulfilled'
      ? asArray(rsRes.value, []).filter((x) => x && typeof x === 'object') : []
    odTasks.value = odRes.status === 'fulfilled'
      ? asArray(odRes.value, []).filter((x) => x && typeof x === 'object') : []
  } finally {
    loading.value = false
  }
}

async function runSync() {
  syncing.value = true
  errorMsg.value = ''
  try {
    const data = await syncCrd()
    lastDir.value = data.config_dir || ''
    results.value = Array.isArray(data.results) ? data.results : []
    syncTime.value = new Date().toLocaleString()
    await loadAll()
    await loadManifests()
  } catch (err) {
    errorMsg.value = err.message || String(err)
  } finally {
    syncing.value = false
  }
}

const moduleStats = computed(() => {
  const stats = [
    { kind: 'StorageBackend', short: 'StorageBackend', label: '存储后端', color: '#38bdf8', count: storageBackends.value.length, ok: storageBackends.value.length > 0 },
    { kind: 'JobQueue', short: 'JobQueue', label: '任务队列', color: '#a78bfa', count: jobQueues.value.length, ok: jobQueues.value.length > 0 },
    { kind: 'SatelliteConstellation', short: 'Constellation', label: '场景星座', color: '#34d399', count: scenarios.value.length, ok: scenarios.value.length > 0 },
    { kind: 'Satellite', short: 'Satellite', label: '卫星（随场景同步）', color: '#fbbf24', count: scenarios.value.reduce((sum, s) => sum + (Number(s.satellite_count) || 0), 0), ok: scenarios.value.length > 0 },
    { kind: 'NetworkTopology', short: 'Topology', label: '网络拓扑（随场景同步）', color: '#f472b6', count: scenarios.value.length, ok: scenarios.value.length > 0 },
    { kind: 'RemoteSensingTask', short: 'RSTask', label: '遥感任务', color: '#60a5fa', count: rsTasks.value.length, ok: rsTasks.value.length > 0 },
    { kind: 'ObjectDetectionTask', short: 'ODTask', label: '检测任务', color: '#fb7185', count: odTasks.value.length, ok: odTasks.value.length > 0 },
  ]
  return stats
})

function actionClass(action) {
  const a = String(action || '').toLowerCase()
  if (a.includes('created')) return 'created'
  if (a.includes('updated')) return 'updated'
  if (a.includes('skip')) return 'skip'
  if (a.includes('delet')) return 'deleted'
  if (a.includes('error')) return 'error'
  return ''
}

function statusClass(status) {
  const s = String(status || '').toLowerCase()
  if (['completed', 'running', 'ok', 'active'].includes(s)) return 'ok'
  if (['pending', 'queued'].includes(s)) return 'warn'
  return 'err'
}

function fmtTime(v) {
  if (!v) return '-'
  const d = new Date(v)
  return isNaN(d.getTime()) ? String(v) : d.toLocaleString()
}

onMounted(() => {
  loadAll()
  loadManifests()
})
</script>

<style scoped>
.crd-page {
  min-height: 100vh;
  padding: 28px 36px 48px;
  color: #e5edf7;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(56, 189, 248, 0.10), transparent 60%),
    radial-gradient(900px 500px at 10% 110%, rgba(167, 139, 250, 0.08), transparent 60%),
    linear-gradient(180deg, #020a1a 0%, #050d1f 100%);
  font-family: 'Segoe UI', 'Microsoft YaHei', system-ui, sans-serif;
}

.crd-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 20px;
  flex-wrap: wrap;
  margin-bottom: 24px;
}

.page-title {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0 0 8px;
  font-size: 26px;
  font-weight: 700;
  letter-spacing: 0.5px;
}

.title-badge {
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 800;
  color: #020a1a;
  background: linear-gradient(135deg, #38bdf8, #818cf8);
  box-shadow: 0 0 18px rgba(56, 189, 248, 0.45);
}

.page-desc {
  margin: 0;
  color: #8ea3c0;
  font-size: 13px;
  max-width: 720px;
  line-height: 1.7;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.sync-path {
  padding: 6px 12px;
  border: 1px solid #1c2f4a;
  border-radius: 8px;
  color: #7dd3fc;
  background: rgba(10, 25, 50, 0.7);
  font-size: 12px;
  font-family: Consolas, monospace;
}

.btn {
  padding: 9px 18px;
  border: none;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn:disabled { opacity: 0.55; cursor: not-allowed; }

.btn-primary {
  color: #02111f;
  background: linear-gradient(135deg, #38bdf8, #818cf8);
  box-shadow: 0 4px 16px rgba(56, 189, 248, 0.35);
}
.btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 6px 22px rgba(56, 189, 248, 0.5); }

.btn-ghost {
  color: #cfe4f8;
  background: rgba(28, 47, 74, 0.6);
  border: 1px solid #1c2f4a;
}
.btn-ghost:hover:not(:disabled) { background: rgba(40, 65, 100, 0.7); }

.spinner {
  display: inline-block;
  width: 12px;
  height: 12px;
  margin-right: 6px;
  border: 2px solid rgba(2, 17, 31, 0.35);
  border-top-color: #02111f;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  vertical-align: -1px;
}
@keyframes spin { to { transform: rotate(360deg); } }

.error-banner {
  margin-bottom: 20px;
  padding: 12px 16px;
  border: 1px solid rgba(251, 113, 133, 0.4);
  border-radius: 10px;
  background: rgba(251, 113, 133, 0.1);
  color: #fda4af;
  font-size: 13px;
}

.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 14px;
  margin-bottom: 22px;
}

.stat-card {
  position: relative;
  padding: 16px 18px;
  border: 1px solid #1c2f4a;
  border-radius: 14px;
  background: linear-gradient(160deg, rgba(15, 30, 55, 0.85), rgba(8, 18, 38, 0.9));
  overflow: hidden;
}
.stat-card::before {
  content: '';
  position: absolute;
  inset: 0 auto auto 0;
  width: 3px;
  height: 100%;
  background: var(--accent);
  box-shadow: 0 0 14px var(--accent);
}

.stat-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.stat-kind { font-size: 12px; color: #8ea3c0; letter-spacing: 0.4px; }
.stat-dot { width: 9px; height: 9px; border-radius: 50%; }
.stat-dot.ok { background: #34d399; box-shadow: 0 0 10px #34d399; }
.stat-dot.warn { background: #fbbf24; box-shadow: 0 0 10px #fbbf24; }

.stat-num { font-size: 28px; font-weight: 800; line-height: 1.1; color: #fff; }
.stat-label { margin-top: 4px; font-size: 12px; color: #8ea3c0; }
.stat-status { margin-top: 8px; font-size: 11px; }
.stat-status.ok { color: #34d399; }
.stat-status.warn { color: #fbbf24; }

.panel {
  margin-bottom: 22px;
  padding: 18px 20px;
  border: 1px solid #1c2f4a;
  border-radius: 14px;
  background: rgba(8, 18, 38, 0.75);
  backdrop-filter: blur(6px);
}

.panel-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 14px;
}
.panel-title { margin: 0; font-size: 16px; font-weight: 700; color: #dbe9fb; }
.panel-time { font-size: 12px; color: #6b83a3; }

.tabs {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}
.tab {
  padding: 7px 14px;
  border: 1px solid #1c2f4a;
  border-radius: 999px;
  background: transparent;
  color: #8ea3c0;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
}
.tab:hover { color: #cfe4f8; border-color: #2b456e; }
.tab.active {
  color: #02111f;
  background: linear-gradient(135deg, #38bdf8, #818cf8);
  border-color: transparent;
  font-weight: 600;
}

.table-wrap { overflow-x: auto; }

.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.data-table th {
  padding: 10px 12px;
  text-align: left;
  color: #7dd3fc;
  font-weight: 600;
  font-size: 12px;
  border-bottom: 1px solid #1c2f4a;
  white-space: nowrap;
  letter-spacing: 0.3px;
}
.data-table td {
  padding: 10px 12px;
  border-bottom: 1px solid rgba(28, 47, 74, 0.6);
  color: #c8d8ec;
  white-space: nowrap;
}
.data-table tr:hover td { background: rgba(56, 189, 248, 0.05); }

.mono { font-family: Consolas, 'Courier New', monospace; font-size: 12.5px; }

.detail-cell {
  max-width: 320px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.kind-tag {
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 11px;
  color: #7dd3fc;
  background: rgba(56, 189, 248, 0.12);
  border: 1px solid rgba(56, 189, 248, 0.25);
}

.action-tag { padding: 2px 8px; border-radius: 6px; font-size: 11px; }
.action-tag.created { color: #34d399; background: rgba(52, 211, 153, 0.12); }
.action-tag.updated { color: #fbbf24; background: rgba(251, 191, 36, 0.12); }
.action-tag.skip { color: #8ea3c0; background: rgba(142, 163, 192, 0.12); }
.action-tag.deleted { color: #f87171; background: rgba(248, 113, 113, 0.12); }
.action-tag.error { color: #f87171; background: rgba(248, 113, 113, 0.12); }

.status-pill { padding: 2px 8px; border-radius: 999px; font-size: 11px; }
.status-pill.ok { color: #34d399; background: rgba(52, 211, 153, 0.12); }
.status-pill.warn { color: #fbbf24; background: rgba(251, 191, 36, 0.12); }
.status-pill.err { color: #f87171; background: rgba(248, 113, 113, 0.12); }
.status-pill.off { color: #8ea3c0; background: rgba(142, 163, 192, 0.12); }

.empty-cell { text-align: center; color: #6b83a3; padding: 24px !important; }

/* ---- 清单文件：在线查看 / 修改 / 执行 ---- */
.btn-sm { padding: 6px 12px; font-size: 12.5px; border-radius: 8px; }

.manifest-wrap { display: flex; flex-direction: column; gap: 12px; }

.manifest-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}
.manifest-legend { display: flex; align-items: center; gap: 14px; font-size: 12px; color: #8ea3c0; }
.legend-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #38bdf8; margin-right: 5px; }
.legend-dot.edit { background: #a78bfa; }
.legend-dot.run { background: #34d399; }
.manifest-toolbar-actions { display: flex; gap: 8px; }

.manifest-body {
  display: grid;
  grid-template-columns: 300px 1fr;
  gap: 14px;
  min-height: 420px;
}
@media (max-width: 900px) { .manifest-body { grid-template-columns: 1fr; } }

.manifest-files {
  border: 1px solid #1c2f4a;
  border-radius: 12px;
  background: rgba(10, 22, 44, 0.7);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  max-height: 560px;
}
.manifest-files-head {
  padding: 10px 14px;
  border-bottom: 1px solid #1c2f4a;
  color: #7dd3fc;
  font-size: 12px;
  background: rgba(20, 40, 70, 0.5);
}
.file-list { list-style: none; margin: 0; padding: 6px; overflow-y: auto; flex: 1; }
.file-item {
  padding: 10px 12px;
  border: 1px solid transparent;
  border-radius: 9px;
  cursor: pointer;
  transition: all 0.15s;
  margin-bottom: 4px;
}
.file-item:hover { background: rgba(56, 189, 248, 0.07); }
.file-item.active {
  background: rgba(56, 189, 248, 0.13);
  border-color: rgba(56, 189, 248, 0.4);
}
.file-item-top { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.file-name { font-size: 12.5px; color: #cfe4f8; word-break: break-all; }
.file-size { font-size: 11px; color: #6b83a3; flex-shrink: 0; }
.file-item-meta { display: flex; align-items: center; gap: 8px; margin-top: 6px; }
.file-mtime { font-size: 11px; color: #6b83a3; }
.manifest-empty { padding: 24px; text-align: center; color: #6b83a3; font-size: 13px; }

.manifest-editor {
  border: 1px solid #1c2f4a;
  border-radius: 12px;
  background: rgba(5, 14, 30, 0.85);
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.editor-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  border-bottom: 1px solid #1c2f4a;
  background: rgba(20, 40, 70, 0.5);
  border-radius: 12px 12px 0 0;
}
.editor-file { font-size: 12.5px; color: #7dd3fc; word-break: break-all; }
.editor-state { font-size: 12px; color: #34d399; }
.editor-state.dirty { color: #fbbf24; }

.yaml-editor {
  flex: 1;
  min-height: 320px;
  padding: 14px 16px;
  border: none;
  outline: none;
  resize: vertical;
  background: transparent;
  color: #a7d4ff;
  font-size: 12.5px;
  line-height: 1.65;
  caret-color: #38bdf8;
  white-space: pre;
  overflow: auto;
}
.yaml-editor:focus { box-shadow: inset 0 0 0 1px rgba(56, 189, 248, 0.35); }
.yaml-editor:readonly { opacity: 0.6; }

.editor-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-top: 1px solid #1c2f4a;
  flex-wrap: wrap;
}
.editor-msg { font-size: 12px; color: #6b83a3; }
.editor-msg.ok { color: #34d399; }
.editor-msg.err { color: #f87171; }
.editor-btns { display: flex; gap: 8px; }

.manifest-results {
  padding: 14px 14px 16px;
  border-top: 1px solid #1c2f4a;
}
.results-title { margin: 0 0 10px; font-size: 13px; color: #7dd3fc; }

.crd-footer {
  margin-top: 28px;
  text-align: center;
  color: #4d6180;
  font-size: 12px;
  line-height: 1.8;
}
</style>
