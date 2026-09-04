<template>
  <div class="dashboard-root">
    <header class="screen-header">
      <h1 class="main-title">卫星集群实时监控数据</h1>
    </header>

    <div class="main-content">
      
      <div class="section-header">
        <h2 class="section-title">CPU和内存使用情况</h2>
        
        <div class="inline-controls">
          <div class="control-group">
            <label>节点:</label>
            <select v-model="resSelectedNode" @change="onResNodeChange">
              <option v-for="node in nodeList" :key="node" :value="node">{{ node }}</option>
            </select>
          </div>
          <div class="control-group">
            <label>对象:</label>
            <select v-model="resSelectedTarget" @change="onResTargetChange">
              <option :value="CURRENT_NODE_KEY">★ 当前节点</option>
              <option v-for="pod in resPodList" :key="pod" :value="pod">{{ pod }}</option>
            </select>
          </div>
        </div>
      </div>

      <div class="chart-row">
        <div class="chart-item">
          <div class="chart-title">
            CPU 使用情况 
            <span class="unit-tag">({{ isResNodeSelected ? '使用率 %' : '核心数 Core' }})</span>
          </div>
          <div ref="cpuChartRef" class="chart-dom"></div>
        </div>

        <div class="chart-item">
          <div class="chart-title">
            内存 使用情况 
            <span class="unit-tag">({{ isResNodeSelected ? '使用率 %' : '容量 GB' }})</span>
          </div>
          <div ref="memChartRef" class="chart-dom"></div>
        </div>
      </div>

      <div class="network-section">
        <div class="section-header">
          <h2 class="section-title">网络流量 (Inbound / Outbound)</h2>
          
          <div class="inline-controls">
            <div class="control-group">
               <label>节点:</label>
               <select v-model="netSelectedNode" @change="onNetNodeChange">
                 <option v-for="node in nodeList" :key="node" :value="node">{{ node }}</option>
               </select>
            </div>
            
            <div class="control-group">
               <label>对象:</label>
               <select v-model="netSelectedTarget" @change="onNetTargetChange">
                 <option :value="CURRENT_NODE_KEY">★ 当前节点</option>
                 <option v-for="pod in netPodList" :key="pod" :value="pod">{{ pod }}</option>
               </select>
            </div>

            <div class="control-group">
               <label>{{ isNetNodeSelected ? '网卡:' : 'Service:' }}</label>
               <select v-model="netSelectedSub" @change="onNetSubChange" style="min-width: 140px;">
                 <option v-for="opt in netSubOptions" :key="opt" :value="opt">{{ opt }}</option>
               </select>
            </div>
          </div>
        </div>

        <div class="chart-row">
          <div class="chart-item">
             <div class="chart-title">
               流入流量 (Inbound) - KB/s
               <span class="unit-tag">{{ netSelectedSub }}</span>
             </div>
             <div ref="netInChartRef" class="chart-dom"></div>
          </div>

          <div class="chart-item">
             <div class="chart-title">
               流出流量 (Outbound) - KB/s
               <span class="unit-tag">{{ netSelectedSub }}</span>
             </div>
             <div ref="netOutChartRef" class="chart-dom"></div>
           </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'

/* ------------------ 1. 常量与配置 ------------------ */
const CURRENT_NODE_KEY = '__CURRENT_NODE__'
const BASE_PATH = '/data/monitor_data_csv'
const ONE_DAY_MS = 24 * 60 * 60 * 1000 

/* ------------------ 2. 全局数据状态 ------------------ */
const nodeList = ref([])
const nodePodMap = ref({}) 

// --- 资源部分 (Section 1) 状态 ---
const resSelectedNode = ref('')
const resSelectedTarget = ref(CURRENT_NODE_KEY)
const isResNodeSelected = computed(() => resSelectedTarget.value === CURRENT_NODE_KEY)
const resPodList = computed(() => nodePodMap.value[resSelectedNode.value] || [])

// --- 网络部分 (Section 2) 状态 ---
const netSelectedNode = ref('')
const netSelectedTarget = ref(CURRENT_NODE_KEY)
const netSelectedSub = ref('') 
const netSubOptions = ref([])  

const isNetNodeSelected = computed(() => netSelectedTarget.value === CURRENT_NODE_KEY)
const netPodList = computed(() => nodePodMap.value[netSelectedNode.value] || [])

/* ------------------ 3. 图表 DOM 引用 ------------------ */
const cpuChartRef = ref(null)
const memChartRef = ref(null)
const netInChartRef = ref(null) 
const netOutChartRef = ref(null) 

let cpuChart = null, memChart = null, netInChart = null, netOutChart = null

/* ------------------ 4. 原始数据存储 ------------------ */
const rawNodeData = { cpu: [], mem: [], netIn: [], netOut: [] }
const rawPodData = { cpu: [], mem: [], netIn: [], netOut: [] }

/* ------------------ 5. CSV 解析与工具函数 ------------------ */
const splitCSVLine = (line) => {
  const result = []
  let current = ''
  let inQuotes = false
  for (let i = 0; i < line.length; i++) {
    const char = line[i]
    if (char === '"') inQuotes = !inQuotes
    else if (char === ',' && !inQuotes) {
      result.push(current.trim()); current = ''
    } else current += char
  }
  result.push(current.trim())
  return result
}

const parseCSV = (text) => {
  const lines = text.split('\n').filter(l => l.trim())
  if (lines.length < 2) return []
  const headers = splitCSVLine(lines[0])
  return lines.slice(1).map(line => {
    const values = splitCSVLine(line)
    const obj = {}
    headers.forEach((h, i) => {
      const cleanKey = h.replace(/["\r]/g, '').trim()
      obj[cleanKey] = values[i]?.replace(/["\r]/g, '')
    })
    return obj
  })
}

const parseValue = (val) => {
  if (!val) return 0
  const num = parseFloat(val)
  return isNaN(num) ? 0 : num
}

const getTimestamp = (timeStr) => {
  if (!timeStr) return 0
  const cleanStr = timeStr.replace(/\//g, '-').split('.')[0]
  return new Date(cleanStr).getTime()
}

const formatAxisTime = (ts) => {
  if (!ts) return ''
  const date = new Date(ts)
  const p = (n) => n < 10 ? `0${n}` : n
  return `${p(date.getMonth()+1)}-${p(date.getDate())} ${p(date.getHours())}:${p(date.getMinutes())}`
}

/**
 * 核心调试函数：数据处理、聚合去重、日志打印
 * 修复波峰波谷震荡问题的关键逻辑
 */
const processAndAggregateData = (data, timeKey, valueKey, debugLabel = 'General') => {
  if (!data || data.length === 0) {
    // console.log(`[${debugLabel}] 数据为空`) // 调试用
    return [];
  }
  
  const timeMap = new Map()
  let duplicateCount = 0;

  data.forEach((d) => {
    const tStr = d[timeKey] || d['Time']
    if (!tStr) return
    
    const ts = getTimestamp(tStr)
    const val = parseValue(d[valueKey])

    if (timeMap.has(ts)) {
      duplicateCount++;
      const oldVal = timeMap.get(ts)
      
      // 仅在控制台打印前 3 个重复案例，方便调试确认
      if (duplicateCount <= 3) {
        console.warn(`[${debugLabel}] 发现重复时间点!`, 
          `\n时间: ${tStr}`, 
          `\n旧值: ${oldVal}`, 
          `\n新值: ${val}`, 
          `\n(已自动取最大值合并)`
        );
      }

      // 【关键逻辑】取最大值合并，消除震荡
      timeMap.set(ts, Math.max(oldVal, val))
    } else {
      timeMap.set(ts, val)
    }
  })

  // 如果发现大量重复，打印汇总信息
  if (duplicateCount > 0) {
    console.warn(`%c[${debugLabel}] 检测结束: 共合并了 ${duplicateCount} 个重复时间点`, 'color: orange; font-weight: bold;');
  }

  // 转为数组并按时间排序
  const sortedData = Array.from(timeMap.entries())
    .map(([ts, val]) => ({ ts, val }))
    .sort((a, b) => a.ts - b.ts)

  // 截取最近 24 小时
  if (sortedData.length === 0) return []
  const lastTime = sortedData[sortedData.length - 1].ts
  const cutoffTime = lastTime - ONE_DAY_MS

  return sortedData.filter(d => d.ts >= cutoffTime)
}

/* ------------------ 6. 数据加载逻辑 ------------------ */
const loadAllData = async () => {
  try {
    const files = [
      'node_cpu_7d.csv', 'node_mem_7d.csv', 'node_network_in_7d.csv', 'node_network_out_7d.csv',
      'pod_cpu_7d.csv', 'pod_mem_7d.csv', 'pod_network_in_7d.csv', 'pod_network_out_7d.csv'
    ]
    const responses = await Promise.all(files.map(f => fetch(`${BASE_PATH}/${f}`).then(r => r.text())))
    
    rawNodeData.cpu = parseCSV(responses[0])
    rawNodeData.mem = parseCSV(responses[1])
    rawNodeData.netIn = parseCSV(responses[2])
    rawNodeData.netOut = parseCSV(responses[3])

    rawPodData.cpu = parseCSV(responses[4])
    rawPodData.mem = parseCSV(responses[5])
    rawPodData.netIn = parseCSV(responses[6])
    rawPodData.netOut = parseCSV(responses[7])

    const nodes = new Set()
    const mapping = {}
    rawNodeData.cpu.forEach(d => { if(d['Node Name']) nodes.add(d['Node Name']) })
    rawPodData.cpu.forEach(d => {
      const nName = d['Node Name']
      const pName = d['Pod Name']
      if (nName && pName) {
        if (!mapping[nName]) mapping[nName] = new Set()
        mapping[nName].add(pName)
      }
    })

    nodeList.value = Array.from(nodes).sort()
    for (const key in mapping) {
      nodePodMap.value[key] = Array.from(mapping[key]).sort()
    }

    if (nodeList.value.length > 0) {
      resSelectedNode.value = nodeList.value[0]
      netSelectedNode.value = nodeList.value[0]
      updateResourceCharts()
      updateNetSubOptions()
    }

  } catch (error) {
    console.error("加载数据失败:", error)
  }
}

/* ------------------ 7. 渲染逻辑：资源部分 ------------------ */
const getChartOption = (title, xData, seriesData, color, unit) => ({
  backgroundColor: 'transparent',
  tooltip: { trigger: 'axis', formatter: (p) => `${p[0].axisValue}<br/>${p[0].marker} ${p[0].seriesName}: <b>${p[0].value}</b> ${unit}` },
  grid: { top: '15%', left: '5%', right: '5%', bottom: '10%', containLabel: true },
  xAxis: { type: 'category', data: xData, boundaryGap: false, axisLabel: { color: '#aaa' } },
  yAxis: { type: 'value', name: unit, nameTextStyle: { color: '#aaa' }, splitLine: { lineStyle: { color: '#333', type: 'dashed' } }, axisLabel: { color: '#aaa' } },
  series: [{
    name: title, type: 'line', smooth: true, showSymbol: false, data: seriesData,
    lineStyle: { width: 2, color: color },
    areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: color + '66' }, { offset: 1, color: 'transparent' }]) }
  }]
})

const updateResourceCharts = () => {
  let cpuRecs = [], memRecs = []
  let cpuKey = '', memKey = '', timeKey = '', unitCpu = '', unitMem = ''

  if (isResNodeSelected.value) {
    cpuRecs = rawNodeData.cpu.filter(d => d['Node Name'] === resSelectedNode.value)
    memRecs = rawNodeData.mem.filter(d => d['Node Name'] === resSelectedNode.value)
    cpuKey = 'CPU Usage(%)'; memKey = 'Memory Usage(%)'; timeKey = 'Time(YYYY-MM-DD HH:MM:SS)'; 
    unitCpu = '%'; unitMem = '%'
  } else {
    cpuRecs = rawPodData.cpu.filter(d => d['Pod Name'] === resSelectedTarget.value)
    memRecs = rawPodData.mem.filter(d => d['Pod Name'] === resSelectedTarget.value)
    cpuKey = Object.keys(cpuRecs[0]||{}).find(k => k.includes('CPU Usage')) || 'CPU Usage'
    memKey = Object.keys(memRecs[0]||{}).find(k => k.includes('Memory Usage')) || 'Memory Usage'
    timeKey = Object.keys(cpuRecs[0]||{}).find(k => k.includes('Time')) || 'Time'
    unitCpu = 'Core'; unitMem = 'GB'
  }

  // 使用调试版聚合函数
  const finalCpu = processAndAggregateData(cpuRecs, timeKey, cpuKey, 'CPU')
  const finalMem = processAndAggregateData(memRecs, timeKey, memKey, 'Memory')

  cpuChart.setOption(getChartOption('CPU', finalCpu.map(d => formatAxisTime(d.ts)), finalCpu.map(d => d.val), '#00fa9a', unitCpu), true)
  memChart.setOption(getChartOption('Memory', finalMem.map(d => formatAxisTime(d.ts)), finalMem.map(d => d.val), '#3a4de9', unitMem), true)
}

/* ------------------ 8. 渲染逻辑：网络部分 ------------------ */
const updateNetSubOptions = () => {
  const options = new Set()
  if (isNetNodeSelected.value) {
    const records = rawNodeData.netIn.filter(d => d['Node Name'] === netSelectedNode.value)
    records.forEach(d => {
       const card = d['Network Card'] || d['Interface'] || d['device'] || 'eth0'
       if(card) options.add(card)
    })
  } else {
    const records = rawPodData.netIn.filter(d => d['Pod Name'] === netSelectedTarget.value)
    records.forEach(d => {
       const svc = d['关联Service'] || d['Service'] || d['Service Name']
       if(svc) options.add(svc)
    })
  }
  netSubOptions.value = Array.from(options).sort()
  
  // 保持当前选项（如果存在），否则选第一个
  if (netSubOptions.value.length > 0) {
    if (!netSubOptions.value.includes(netSelectedSub.value)) {
       netSelectedSub.value = netSubOptions.value[0]
    }
  } else {
    netSelectedSub.value = ''
  }
  updateNetworkCharts()
}

const updateNetworkCharts = () => {
  let inRecs = [], outRecs = []
  let timeKey = ''
  const subValue = netSelectedSub.value

  if (isNetNodeSelected.value) {
    timeKey = 'Time(YYYY-MM-DD HH:MM:SS)'
    inRecs = rawNodeData.netIn.filter(d => d['Node Name'] === netSelectedNode.value && (d['Network Card'] == subValue || d['Interface'] == subValue))
    outRecs = rawNodeData.netOut.filter(d => d['Node Name'] === netSelectedNode.value && (d['Network Card'] == subValue || d['Interface'] == subValue))
  } else {
    const sample = rawPodData.netIn[0] || {}
    timeKey = Object.keys(sample).find(k => k.includes('Time')) || 'Time'
    inRecs = rawPodData.netIn.filter(d => d['Pod Name'] === netSelectedTarget.value && d['关联Service'] == subValue)
    outRecs = rawPodData.netOut.filter(d => d['Pod Name'] === netSelectedTarget.value && d['关联Service'] == subValue)
  }

  // 使用调试版聚合函数
  const finalIn = processAndAggregateData(inRecs, timeKey, 'Inbound Traffic Rate(B/s)', `NetIn-${subValue}`)
  const finalOut = processAndAggregateData(outRecs, timeKey, 'Outbound Traffic Rate(B/s)', `NetOut-${subValue}`)
  
  const toKB = v => (v / 1024).toFixed(2)

  netInChart.setOption(getChartOption('Inbound', finalIn.map(d => formatAxisTime(d.ts)), finalIn.map(d => toKB(d.val)), '#00fa9a', 'KB/s'), true)
  netOutChart.setOption(getChartOption('Outbound', finalOut.map(d => formatAxisTime(d.ts)), finalOut.map(d => toKB(d.val)), '#ffd700', 'KB/s'), true)
}

/* ------------------ 9. 事件监听 ------------------ */
const onResNodeChange = () => { resSelectedTarget.value = CURRENT_NODE_KEY; updateResourceCharts() }
const onResTargetChange = () => { updateResourceCharts() }
const onNetNodeChange = () => { netSelectedTarget.value = CURRENT_NODE_KEY; updateNetSubOptions() }
const onNetTargetChange = () => { updateNetSubOptions() }
const onNetSubChange = () => { updateNetworkCharts() }

/* ------------------ 10. 生命周期 ------------------ */
onMounted(() => {
  cpuChart = echarts.init(cpuChartRef.value, 'dark')
  memChart = echarts.init(memChartRef.value, 'dark')
  netInChart = echarts.init(netInChartRef.value, 'dark')
  netOutChart = echarts.init(netOutChartRef.value, 'dark')
  loadAllData()
  window.addEventListener('resize', () => { cpuChart && cpuChart.resize(); memChart && memChart.resize(); netInChart && netInChart.resize(); netOutChart && netOutChart.resize() })
})
onUnmounted(() => { cpuChart?.dispose(); memChart?.dispose(); netInChart?.dispose(); netOutChart?.dispose() })
</script>

<style scoped>
.dashboard-root {
  min-height: 100vh;
  background: #020617;
  color: #fff;
  padding: 20px;
  font-family: 'Segoe UI', sans-serif;
}

.screen-header {
  margin-bottom: 20px;
  border-bottom: 1px solid #1a3a6a;
  padding-bottom: 15px;
}

.main-title {
  text-align: center;
  font-size: 32px;
  letter-spacing: 4px;
  margin: 0;
  text-shadow: 0 0 10px rgba(0, 210, 255, 0.5);
}

/* ================= 布局核心样式 ================= */

/* 1. 标题栏容器：Flex布局，左对齐，垂直居中 */
.section-header {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 20px; /* 标题和控件之间的间距 */
  margin: 25px 0 15px 0;
  border-bottom: 1px solid rgba(26, 58, 106, 0.5);
  padding-bottom: 8px;
}

/* 2. 标题样式 */
.section-title {
  color: #00d2ff;
  border-left: 4px solid #00d2ff;
  padding-left: 10px;
  margin: 0;
  font-size: 18px;
  white-space: nowrap; /* 防止标题换行 */
}

/* 3. 控件容器：Flex布局 */
.inline-controls {
  display: flex;
  align-items: center;
  gap: 15px; /* 控件组之间的间距 */
}

.control-group {
  display: flex;
  align-items: center;
  gap: 8px; /* label 和 select 之间的间距 */
}

.control-group label {
  color: #aaa;
  font-size: 14px;
  font-weight: normal;
  white-space: nowrap;
}

select {
  background: #0b1124;
  border: 1px solid #1a3a6a;
  color: #fff;
  padding: 4px 8px; 
  border-radius: 4px;
  outline: none;
  cursor: pointer;
  font-size: 13px;
  min-width: 120px;
}
select:focus {
  border-color: #00d2ff;
}

/* ================= 图表容器 ================= */
.chart-row {
  display: flex;
  gap: 20px;
  height: 350px;
  margin-bottom: 10px;
}

.chart-item {
  flex: 1;
  background: rgba(16, 18, 48, 0.6);
  border: 1px solid #1a3a6a;
  padding: 15px;
  border-radius: 4px;
  display: flex;
  flex-direction: column;
}

.chart-title {
  color: #e0e0e0;
  font-size: 16px;
  margin-bottom: 10px;
  display: flex;
  justify-content: space-between;
}

.unit-tag {
  font-size: 12px;
  color: #aaa;
  background: #1a3a6a;
  padding: 2px 6px;
  border-radius: 4px;
}

.chart-dom { flex: 1; width: 100%; }
</style>