<template>
  <div class="monitor-layout">
    <!-- 顶部标题栏 -->
    <header class="monitor-header">
      <div class="title-block">
        <h1>卫星网络 · 性能监控中台</h1>
      </div>
      <div class="header-actions">
        <BackHomeButton mode="inline" />
        <div class="env-tag">环境：开发环境</div>
        <button class="btn btn-primary">导出当前视图</button>
      </div>
    </header>

    <!-- 过滤器区域 -->
    <section class="filter-bar">
      <div class="filter-group">
        <label>时间范围</label>
        <select v-model="timeRange">
          <option value="5m">最近 5 分钟</option>
          <option value="1h">最近 1 小时</option>
          <option value="6h">最近 6 小时</option>
          <option value="24h">最近 24 小时</option>
        </select>
      </div>
      <div class="filter-group">
        <label>星座 / 拓扑</label>
        <select v-model="selectedConstellation">
          <option value="all">全部星座</option>
          <option value="pc-lab">鹏城实验室 · 演示星座</option>
          <option value="leo-demo">LEO 演示星座</option>
        </select>
      </div>
      <div class="filter-group">
        <label>观测指标</label>
        <select v-model="selectedMetric">
          <option value="traffic">链路流量</option>
          <option value="latency">端到端时延</option>
          <option value="error">错误率</option>
        </select>
      </div>
      <div class="filter-group">
        <label>刷新频率</label>
        <select v-model="refreshInterval">
          <option value="off">手动</option>
          <option value="5s">5s</option>
          <option value="15s">15s</option>
          <option value="60s">60s</option>
        </select>
      </div>
      <div class="filter-actions">
        <button class="btn" @click="fakeRefresh">刷新</button>
        <button class="btn btn-ghost">重置</button>
      </div>
    </section>

    <!-- 顶部概要指标卡片 -->
    <section class="summary-grid">
      <div class="summary-card">
        <div class="card-header">
          <span class="card-title">集群 QPS</span>
          <span class="badge badge-green">稳定</span>
        </div>
        <div class="card-value">{{ metrics.qps.toLocaleString() }}</div>
        <div class="card-footer">
          <span>过去 {{ displayTimeRange }} 平均值</span>
          <span :class="['trend', metrics.qpsTrend >= 0 ? 'up' : 'down']">
            {{ metrics.qpsTrend >= 0 ? '+' : '' }}{{ metrics.qpsTrend.toFixed(1) }}%
          </span>
        </div>
      </div>

      <div class="summary-card">
        <div class="card-header">
          <span class="card-title">平均时延 (p95)</span>
          <span class="badge" :class="latencyBadgeClass">{{ latencyBadgeText }}</span>
        </div>
        <div class="card-value">{{ metrics.latencyP95 }} ms</div>
        <div class="card-footer">
          <span>卫星链路</span>
          <span :class="['trend', metrics.latencyTrend >= 0 ? 'up' : 'down']">
            {{ metrics.latencyTrend >= 0 ? '+' : '' }}{{ metrics.latencyTrend.toFixed(1) }}%
          </span>
        </div>
      </div>

      <div class="summary-card">
        <div class="card-header">
          <span class="card-title">错误率</span>
          <span class="badge badge-red" v-if="metrics.errorRate > 1">告警</span>
          <span class="badge badge-green" v-else>正常</span>
        </div>
        <div class="card-value">{{ metrics.errorRate.toFixed(2) }}%</div>
        <div class="card-footer">
          <span>5xx / 所有请求</span>
          <span :class="['trend', metrics.errorTrend >= 0 ? 'up' : 'down']">
            {{ metrics.errorTrend >= 0 ? '+' : '' }}{{ metrics.errorTrend.toFixed(1) }}%
          </span>
        </div>
      </div>

      <div class="summary-card">
        <div class="card-header">
          <span class="card-title">活跃卫星节点</span>
          <span class="badge badge-blue">拓扑视角</span>
        </div>
        <div class="card-value">{{ metrics.activeSatellites }}</div>
        <div class="card-footer">
          <span>共 {{ metrics.totalSatellites }} 颗 · {{ metrics.activePlanes }} 条轨道面</span>
          <span class="trend up">+{{ metrics.newSatellites }} (新增)</span>
        </div>
      </div>
    </section>

    <!-- 主体：左侧“折线图” + 右侧“TopN表格” -->
    <section class="main-grid">
      <!-- 伪折线图区域 -->
      <div class="panel">
        <div class="panel-header">
          <div>
            <h2>时序指标</h2>
          </div>
          <div class="legend">
            <span class="legend-item">
              <span class="dot dot-blue"></span> 请求 QPS
            </span>
            <span class="legend-item">
              <span class="dot dot-green"></span> 成功率
            </span>
            <span class="legend-item">
              <span class="dot dot-orange"></span> p95 时延
            </span>
          </div>
        </div>

        <!-- 这里用简单的 div 模拟折线/面积图，而不引入额外图表库 -->
        <div class="fake-chart">
          <div class="y-axis-labels">
            <span>高</span>
            <span>中</span>
            <span>低</span>
          </div>
          <div class="chart-body">
            <div
              v-for="(p, idx) in timeSeries"
              :key="idx"
              class="chart-column"
            >
              <div class="line latency" :style="{ height: p.latency + '%' }"></div>
              <div class="line success" :style="{ height: p.success + '%' }"></div>
              <div class="line qps" :style="{ height: p.qps + '%' }"></div>
            </div>
          </div>
        </div>

        <div class="chart-footer">
          <span>时间轴（模拟 {{ displayTimeRange }} 内采样点）</span>
        </div>
      </div>

      <!-- TopN 表格区域 -->
      <div class="panel">
        <div class="panel-header">
          <div>
            <h2>Top 5 热点卫星链路</h2>
          </div>
        </div>

        <table class="metric-table">
          <thead>
            <tr>
              <th>排名</th>
              <th>链路</th>
              <th>平均时延 (ms)</th>
              <th>错误率</th>
              <th>流量占比</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(link, index) in topLinks" :key="link.id">
              <td>#{{ index + 1 }}</td>
              <td>
                <div class="link-name">
                  <span class="link-badge">Plane {{ link.plane }}</span>
                  <span>{{ link.from }} → {{ link.to }}</span>
                </div>
              </td>
              <td>{{ link.latency }}</td>
              <td :class="['error-cell', link.errorRate > 1 ? 'high' : '']">
                {{ link.errorRate.toFixed(2) }}%
              </td>
              <td>
                <div class="traffic-bar">
                  <div
                    class="traffic-fill"
                    :style="{ width: link.trafficShare + '%' }"
                  ></div>
                  <span class="traffic-text">{{ link.trafficShare.toFixed(1) }}%</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- 底部：标签页形式的“指标说明” -->
    <section class="doc-section">
      <h2>指标说明（Demo）</h2>
      <ul class="doc-list">
        <li>
          <strong>集群 QPS：</strong>
          模拟整个卫星网络中所有服务的请求吞吐量，单位为 requests / second。
        </li>
        <li>
          <strong>平均时延 (p95)：</strong>
          模拟 95% 请求的端到端时延。
        </li>
        <li>
          <strong>错误率：</strong>
          模拟 5xx 错误占所有请求的比例，用于观察系统稳定性。
        </li>
        <li>
          <strong>活跃卫星节点：</strong>
          当前参与转发 / 通信的卫星数量，结合轨道面数展示网络规模。
        </li>
      </ul>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import BackHomeButton from '../components/BackHomeButton.vue'

const timeRange = ref('5m')
const selectedConstellation = ref('pc-lab')
const selectedMetric = ref('traffic')
const refreshInterval = ref('off')

const metrics = ref({
  qps: 12500,
  qpsTrend: 3.4,
  latencyP95: 180,
  latencyTrend: -4.2,
  errorRate: 0.85,
  errorTrend: -1.1,
  activeSatellites: 768,
  totalSatellites: 1024,
  activePlanes: 24,
  newSatellites: 12
})

const timeSeries = ref(
  Array.from({ length: 24 }, (_, idx) => ({
    qps: 40 + Math.random() * 50 + (idx % 5) * 5,
    success: 70 + Math.random() * 25,
    latency: 30 + Math.random() * 50
  }))
)

const topLinks = ref([
  { id: 1, plane: 1, from: 'SAT-1A', to: 'SAT-1B', latency: 210, errorRate: 1.32, trafficShare: 18.5 },
  { id: 2, plane: 3, from: 'SAT-3C', to: 'SAT-3D', latency: 195, errorRate: 0.94, trafficShare: 15.2 },
  { id: 3, plane: 5, from: 'SAT-5E', to: 'SAT-5F', latency: 230, errorRate: 0.75, trafficShare: 12.8 },
  { id: 4, plane: 7, from: 'SAT-7G', to: 'SAT-7H', latency: 260, errorRate: 2.10, trafficShare: 10.1 },
  { id: 5, plane: 9, from: 'SAT-9K', to: 'SAT-9L', latency: 180, errorRate: 0.45, trafficShare: 8.9 }
])

const displayTimeRange = computed(() => {
  switch (timeRange.value) {
    case '5m':
      return '5 分钟'
    case '1h':
      return '1 小时'
    case '6h':
      return '6 小时'
    case '24h':
      return '24 小时'
    default:
      return '5 分钟'
  }
})

const latencyBadgeClass = computed(() => {
  if (metrics.value.latencyP95 < 200) return 'badge-green'
  if (metrics.value.latencyP95 < 400) return 'badge-orange'
  return 'badge-red'
})

const latencyBadgeText = computed(() => {
  if (metrics.value.latencyP95 < 200) return '优'
  if (metrics.value.latencyP95 < 400) return '良'
  return '较高'
})

let timer = null

const tickFakeData = () => {
  const m = metrics.value
  m.qps = Math.max(5000, Math.min(20000, m.qps + (Math.random() - 0.5) * 800))
  m.qpsTrend = (Math.random() - 0.3) * 8

  m.latencyP95 = Math.max(80, Math.min(450, m.latencyP95 + (Math.random() - 0.5) * 40))
  m.latencyTrend = (Math.random() - 0.5) * 10

  m.errorRate = Math.max(0.1, Math.min(3.5, m.errorRate + (Math.random() - 0.5) * 0.3))
  m.errorTrend = (Math.random() - 0.5) * 5

  timeSeries.value.shift()
  timeSeries.value.push({
    qps: 40 + Math.random() * 50,
    success: 70 + Math.random() * 25,
    latency: 30 + Math.random() * 50
  })
}

const setupAutoRefresh = () => {
  if (timer) {
    clearInterval(timer)
    timer = null
  }
  if (refreshInterval.value === 'off') return

  const ms =
    refreshInterval.value === '5s'
      ? 5000
      : refreshInterval.value === '15s'
      ? 15000
      : 60000

  timer = setInterval(tickFakeData, ms)
}

const fakeRefresh = () => {
  tickFakeData()
}

onMounted(() => {
  setupAutoRefresh()
})

onUnmounted(() => {
  if (timer) {
    clearInterval(timer)
  }
})

watch(refreshInterval, () => {
  setupAutoRefresh()
})
</script>

<style scoped>
.monitor-layout {
  min-height: 100vh;
  padding: 24px 32px 40px;
  background-color: #0b1020;
  color: #e5e7eb;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

.monitor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.title-block h1 {
  margin: 0;
  font-size: 24px;
  color: #f9fafb;
}

.subtitle {
  margin-top: 4px;
  font-size: 13px;
  color: #9ca3af;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.env-tag {
  padding: 4px 10px;
  border-radius: 999px;
  border: 1px solid #374151;
  font-size: 12px;
  color: #9ca3af;
}

.btn {
  padding: 6px 14px;
  border-radius: 6px;
  border: 1px solid #4b5563;
  background: transparent;
  color: #e5e7eb;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn:hover {
  background-color: #1f2937;
}

.btn-primary {
  border-color: #2563eb;
  background: linear-gradient(90deg, #2563eb, #4f46e5);
}

.btn-primary:hover {
  filter: brightness(1.03);
}

.btn-ghost {
  border-style: dashed;
}

.filter-bar {
  display: flex;
  align-items: flex-end;
  gap: 16px;
  margin-bottom: 20px;
  padding: 12px 16px;
  border-radius: 10px;
  background: rgba(15, 23, 42, 0.9);
  border: 1px solid #1f2937;
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.filter-group label {
  font-size: 12px;
  color: #9ca3af;
}

.filter-group select {
  min-width: 140px;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid #374151;
  background-color: #020617;
  color: #e5e7eb;
  font-size: 13px;
}

.filter-actions {
  margin-left: auto;
  display: flex;
  gap: 8px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 20px;
}

.summary-card {
  padding: 14px 16px 12px;
  border-radius: 10px;
  background: radial-gradient(circle at top left, rgba(59, 130, 246, 0.15), transparent 60%),
    #020617;
  border: 1px solid #1f2937;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.card-title {
  font-size: 13px;
  color: #9ca3af;
}

.badge {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  border: 1px solid #374151;
}

.badge-green {
  background-color: rgba(22, 163, 74, 0.15);
  border-color: #22c55e;
  color: #bbf7d0;
}

.badge-orange {
  background-color: rgba(245, 158, 11, 0.15);
  border-color: #f59e0b;
  color: #fed7aa;
}

.badge-red {
  background-color: rgba(239, 68, 68, 0.15);
  border-color: #ef4444;
  color: #fecaca;
}

.badge-blue {
  background-color: rgba(37, 99, 235, 0.15);
  border-color: #60a5fa;
  color: #bfdbfe;
}

.card-value {
  font-size: 22px;
  font-weight: 600;
  color: #f9fafb;
  margin-bottom: 4px;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 11px;
  color: #6b7280;
}

.trend {
  font-weight: 500;
}

.trend.up {
  color: #4ade80;
}

.trend.down {
  color: #f97316;
}

.main-grid {
  display: grid;
  grid-template-columns: 3fr 2fr;
  gap: 16px;
  margin-bottom: 24px;
}

.panel {
  padding: 14px 16px 12px;
  border-radius: 10px;
  background: #020617;
  border: 1px solid #1f2937;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 10px;
}

.panel-header h2 {
  margin: 0;
  font-size: 15px;
  color: #e5e7eb;
}

.panel-subtitle {
  margin-top: 4px;
  font-size: 12px;
  color: #6b7280;
}

.legend {
  display: flex;
  gap: 10px;
  font-size: 11px;
  color: #9ca3af;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
}

.dot-blue {
  background-color: #60a5fa;
}

.dot-green {
  background-color: #34d399;
}

.dot-orange {
  background-color: #fb923c;
}

.fake-chart {
  display: flex;
  align-items: stretch;
  gap: 6px;
  margin-top: 6px;
  padding-top: 4px;
}

.y-axis-labels {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  font-size: 10px;
  color: #4b5563;
  padding-right: 6px;
}

.chart-body {
  flex: 1;
  display: grid;
  grid-template-columns: repeat(24, minmax(0, 1fr));
  align-items: flex-end;
  gap: 3px;
  height: 120px;
}

.chart-column {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  gap: 1px;
}

.line {
  border-radius: 2px;
}

.line.qps {
  background: linear-gradient(to top, rgba(59, 130, 246, 0.9), rgba(59, 130, 246, 0.3));
}

.line.success {
  background: linear-gradient(to top, rgba(16, 185, 129, 0.9), rgba(16, 185, 129, 0.3));
}

.line.latency {
  background: linear-gradient(to top, rgba(249, 115, 22, 0.9), rgba(249, 115, 22, 0.3));
}

.chart-footer {
  margin-top: 6px;
  font-size: 11px;
  color: #4b5563;
}

.metric-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

.metric-table th,
.metric-table td {
  padding: 6px 8px;
  border-bottom: 1px solid #111827;
}

.metric-table thead th {
  font-weight: 500;
  color: #9ca3af;
  background-color: #020617;
}

.metric-table tbody tr:hover {
  background-color: rgba(31, 41, 55, 0.6);
}

.link-name {
  display: flex;
  align-items: center;
  gap: 6px;
}

.link-badge {
  padding: 2px 6px;
  border-radius: 999px;
  background-color: rgba(37, 99, 235, 0.15);
  color: #93c5fd;
  font-size: 11px;
}

.error-cell.high {
  color: #f97316;
}

.traffic-bar {
  position: relative;
  height: 8px;
  border-radius: 999px;
  background-color: #020617;
  overflow: hidden;
  border: 1px solid #111827;
}

.traffic-fill {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  border-radius: 999px;
  background: linear-gradient(90deg, #22c55e, #16a34a);
}

.traffic-text {
  margin-left: 6px;
  font-size: 11px;
  color: #9ca3af;
}

.doc-section {
  margin-top: 16px;
  padding: 14px 16px 12px;
  border-radius: 10px;
  background: #020617;
  border: 1px solid #1f2937;
}

.doc-section h2 {
  margin: 0 0 8px;
  font-size: 14px;
  color: #e5e7eb;
}

.doc-list {
  margin: 0 0 8px;
  padding-left: 18px;
  font-size: 12px;
  color: #9ca3af;
}

.doc-list li {
  margin-bottom: 4px;
}

.doc-tip {
  margin: 0;
  font-size: 11px;
  color: #6b7280;
}

@media (max-width: 1024px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .main-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .monitor-layout {
    padding: 16px;
  }

  .monitor-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .filter-bar {
    flex-wrap: wrap;
  }

  .summary-grid {
    grid-template-columns: 1fr;
  }
}
</style>

