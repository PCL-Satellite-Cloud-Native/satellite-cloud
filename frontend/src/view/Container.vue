<template>
  <div class="container-page">
    <header class="page-header">
      <div class="header-left">
        <h1 class="page-title">
          <span class="title-badge">容器</span>
          容器编排移植效果
        </h1>
        <p class="page-desc">
          将「任务3容器编排测试代码」的扩缩 / 部署调度 / 迁移三类算法接入系统，
          展示移植后的第四层验收指标（真实算法输出或仿真基线）。
        </p>
      </div>
      <div class="header-actions">
        <BackHomeButton mode="inline" />
        <span class="source-badge" :class="sourceClass">{{ sourceText }}</span>
        <button class="btn btn-ghost" :disabled="loading" @click="load">
          {{ loading ? '加载中…' : '刷新数据' }}
        </button>
      </div>
    </header>

    <div v-if="errorMsg" class="error-banner">加载失败：{{ errorMsg }}</div>

    <section class="algo-grid">
      <article v-for="algo in algorithms" :key="algo.id" class="algo-card">
        <div class="algo-head">
          <div class="algo-title">
            <span class="algo-dot" :class="algo.id" />
            <h2>{{ algo.name }}</h2>
          </div>
          <span class="algo-source" :class="algo.source">{{ algo.source === 'realtime' ? '实时算法' : '仿真基线' }}</span>
        </div>
        <p class="algo-desc">{{ algo.desc }}</p>

        <div class="metric-row">
          <div v-for="m in algo.metrics" :key="m.key" class="metric-card" :class="metricState(m)">
            <div class="metric-label">{{ m.label }}</div>
            <div class="metric-value">
              {{ formatValue(m.value) }}<span class="metric-unit">{{ m.unit }}</span>
            </div>
            <div class="metric-target">
              目标 {{ formatValue(m.target) }}{{ m.unit }}
              <span class="metric-better">{{ m.better === 'up' ? '↑越大越好' : '↓越小越好' }}</span>
            </div>
            <div class="metric-bar">
              <div class="metric-bar-fill" :style="barStyle(m)" />
            </div>
          </div>
        </div>

        <div class="chart-wrap" :ref="el => setChartRef(algo.id, el)"></div>
      </article>
    </section>

    <footer class="page-footer">
      <span v-if="generatedAt">指标生成时间：{{ generatedAt }}</span>
      <span v-if="message" class="footer-note">{{ message }}</span>
    </footer>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, computed } from 'vue'
import BackHomeButton from '../components/BackHomeButton.vue'
import { getContainerMetrics } from '../api/container.js'
import * as echarts from 'echarts'

const algorithms = ref([])
const loading = ref(false)
const errorMsg = ref('')
const generatedAt = ref('')
const message = ref('')
const chartRefs = ref({})
const charts = ref({})

const sourceText = computed(() => {
  const s = algorithms.value.length ? (algorithms.value.some(a => a.source === 'realtime') ? 'realtime' : 'fallback') : 'fallback'
  return s === 'realtime' ? '实时算法输出' : '仿真基线'
})
const sourceClass = computed(() => (sourceText.value === '实时算法输出' ? 'ok' : 'warn'))

function setChartRef(id, el) {
  if (el) chartRefs.value[id] = el
}

function formatValue(v) {
  if (v === null || v === undefined) return '-'
  return Number.isInteger(v) ? v : v.toFixed(2)
}

function metricState(m) {
  const hit = m.value >= m.target
  if (m.better === 'up') return hit ? 'good' : 'bad'
  return hit ? 'good' : 'bad'
}

function barStyle(m) {
  const ratio = m.target === 0 ? 0 : Math.min(m.value / (m.target * 1.5), 1)
  return { width: (ratio * 100).toFixed(1) + '%' }
}

function renderCharts() {
  algorithms.value.forEach(algo => {
    const el = chartRefs.value[algo.id]
    if (!el) return
    const chart = echarts.init(el)
    charts.value[algo.id] = chart
    const names = algo.metrics.map(m => m.label)
    const values = algo.metrics.map(m => m.value)
    const targets = algo.metrics.map(m => m.target)
    chart.setOption({
      tooltip: { trigger: 'axis' },
      legend: { data: ['实际值', '目标值'], textStyle: { color: '#cfe3ff' }, top: 0 },
      grid: { left: 40, right: 16, top: 36, bottom: 24 },
      xAxis: { type: 'category', data: names, axisLabel: { color: '#9fb6d6', interval: 0, fontSize: 11 } },
      yAxis: { type: 'value', axisLabel: { color: '#9fb6d6' }, splitLine: { lineStyle: { color: 'rgba(255,255,255,0.08)' } } },
      series: [
        { name: '实际值', type: 'bar', data: values, itemStyle: { color: '#36a2ff' }, barWidth: '38%' },
        { name: '目标值', type: 'bar', data: targets, itemStyle: { color: 'rgba(250,173,20,0.7)' }, barWidth: '38%' },
      ],
    })
  })
}

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const data = await getContainerMetrics()
    algorithms.value = data.algorithms || []
    generatedAt.value = data.generated_at || ''
    message.value = data.message || ''
    await nextTick()
    renderCharts()
  } catch (e) {
    errorMsg.value = e.message || String(e)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  load()
  window.addEventListener('resize', () => {
    Object.values(charts.value).forEach(c => c && c.resize())
  })
})
</script>

<style scoped>
.container-page {
  min-height: 100vh;
  background: radial-gradient(1200px 600px at 50% -10%, #16335c 0%, #0a1830 55%, #060f1f 100%);
  color: #e6f0ff;
  padding: 28px 32px 48px;
  box-sizing: border-box;
}
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  flex-wrap: wrap;
  margin-bottom: 22px;
}
.page-title {
  font-size: 26px;
  font-weight: 700;
  margin: 0;
  display: flex;
  align-items: center;
  gap: 12px;
}
.title-badge {
  background: linear-gradient(135deg, #36a2ff, #2f6bff);
  color: #fff;
  border-radius: 8px;
  padding: 4px 10px;
  font-size: 14px;
  letter-spacing: 1px;
}
.page-desc {
  margin: 10px 0 0;
  color: #9fb6d6;
  max-width: 720px;
  line-height: 1.6;
}
.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}
.source-badge {
  font-size: 12px;
  padding: 4px 10px;
  border-radius: 999px;
}
.source-badge.ok { background: rgba(82, 196, 26, 0.18); color: #b7f5a0; }
.source-badge.warn { background: rgba(250, 173, 20, 0.18); color: #ffd591; }
.btn {
  border: none;
  border-radius: 8px;
  padding: 8px 16px;
  cursor: pointer;
  font-size: 13px;
}
.btn-ghost { background: rgba(255, 255, 255, 0.08); color: #cfe3ff; }
.btn-ghost:disabled { opacity: 0.5; cursor: default; }
.error-banner {
  background: rgba(245, 34, 45, 0.15);
  border: 1px solid rgba(245, 34, 45, 0.4);
  color: #ffb4b4;
  padding: 10px 14px;
  border-radius: 8px;
  margin-bottom: 16px;
}
.algo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
  gap: 20px;
}
.algo-card {
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 14px;
  padding: 18px 20px 8px;
}
.algo-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.algo-title { display: flex; align-items: center; gap: 10px; }
.algo-title h2 { font-size: 17px; margin: 0; }
.algo-dot { width: 12px; height: 12px; border-radius: 50%; }
.algo-dot.scaling { background: #36a2ff; }
.algo-dot.deployment { background: #52c41a; }
.algo-dot.migration { background: #faad14; }
.algo-source { font-size: 12px; padding: 3px 9px; border-radius: 999px; }
.algo-source.realtime { background: rgba(82, 196, 26, 0.18); color: #b7f5a0; }
.algo-source.baseline { background: rgba(250, 173, 20, 0.18); color: #ffd591; }
.algo-desc { color: #9fb6d6; font-size: 13px; margin: 8px 0 16px; line-height: 1.6; }
.metric-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 12px;
}
.metric-card {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 10px;
  padding: 12px;
}
.metric-card.good { border-color: rgba(82, 196, 26, 0.4); }
.metric-card.bad { border-color: rgba(245, 34, 45, 0.4); }
.metric-label { font-size: 12px; color: #9fb6d6; }
.metric-value { font-size: 24px; font-weight: 700; margin: 4px 0; }
.metric-unit { font-size: 12px; color: #9fb6d6; margin-left: 4px; font-weight: 400; }
.metric-target { font-size: 11px; color: #8298b8; }
.metric-better { margin-left: 6px; color: #6f8bb0; }
.metric-bar { height: 5px; background: rgba(255, 255, 255, 0.08); border-radius: 999px; margin-top: 8px; overflow: hidden; }
.metric-bar-fill { height: 100%; background: linear-gradient(90deg, #36a2ff, #2f6bff); }
.metric-card.good .metric-bar-fill { background: linear-gradient(90deg, #52c41a, #38a169); }
.metric-card.bad .metric-bar-fill { background: linear-gradient(90deg, #f5222d, #cf1322); }
.chart-wrap { width: 100%; height: 240px; margin: 14px 0 6px; }
.page-footer {
  margin-top: 22px;
  color: #8298b8;
  font-size: 12px;
  display: flex;
  gap: 18px;
  flex-wrap: wrap;
}
.footer-note { color: #ffd591; }
</style>
