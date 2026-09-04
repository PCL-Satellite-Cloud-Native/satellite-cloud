<template>
  <div class="topology-wrap">
    <div class="topology-section">
      <h3>路由拓扑</h3>
      <div class="controls">
        <label class="control-item">
          <span class="label" style="text-align:left; display:block;">卫星编号</span>
          <input class="input" v-model.trim="selectedRouter" placeholder="例如：r001001" />
        </label>
      </div>
      <div class="topology">
        <v-network-graph :nodes="routerNodes" :edges="routerEdges" :layouts="routerLayouts">
          <template #override-node="{ scale }">
            <image :href="satIcon" :x="-12 * scale" :y="-12 * scale" :width="24 * scale" :height="24 * scale" />
          </template>
          <template #edge-label="{ edge, ...slotProps }">
            <v-edge-label :text="edge.label" align="center" vertical-align="above" v-bind="slotProps" />
          </template>
        </v-network-graph>

        <div v-if="routerStatus !== 'ready'" class="overlay">
          <div class="overlay-text">
            <template v-if="routerStatus === 'loading'">路由数据加载中…</template>
            <template v-else>数据加载失败：{{ routerErrorMsg }}</template>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, reactive, ref, watch } from 'vue'
import { VNetworkGraph, VEdgeLabel } from 'v-network-graph'
import 'v-network-graph/lib/style.css'

// 卫星节点图标
const satIcon = '/satellite.svg'

// ===================== 路由拓扑状态与数据 =====================
const routerStatus = ref('loading')
const routerErrorMsg = ref('')
const selectedRouter = ref('r001001')
const routerConnections = ref(new Map())

// 路由器列表（用于数据抓取）
const routers = [
  'r001001', 'r001002', 'r001003', 'r001004', 'r001005',
  'r002001', 'r002002', 'r002003', 'r002004', 'r002005',
  'r003001', 'r003002', 'r003003', 'r003004', 'r003005'
]

// v-network-graph 响应式数据
const routerNodes = reactive({})
const routerEdges = reactive({})
const routerLayouts = reactive({ nodes: {} })

/**
 * 加载路由器连接数据
 */
async function loadRouterData () {
  routerStatus.value = 'loading'
  routerErrorMsg.value = ''
  try {
    const connections = new Map()
    for (const router of routers) {
      const resp = await fetch(`/data/router/${router}_net_qos.csv`)
      if (!resp.ok) continue
      
      const text = await resp.text()
      const lines = text.split(/\r?\n/).filter(l => l.trim())
      if (lines.length < 2) continue

      const header = lines[0].split(',').map(s => s.trim())
      const col = Object.fromEntries(header.map((h, i) => [h, i]))
      
      if (!connections.has(router)) connections.set(router, new Set())
      
      for (let i = 1; i < lines.length; i++) {
        const parts = lines[i].split(',').map(s => s.trim())
        const directNode = parts[col['直连节点']]
        if (directNode && directNode !== router) {
          connections.get(router).add(directNode)
        }
      }
    }
    routerConnections.value = connections
    updateRouterGraph()
    routerStatus.value = 'ready'
  } catch (e) {
    routerStatus.value = 'error'
    routerErrorMsg.value = e?.message ?? String(e)
  }
}

/**
 * 更新图形展示（基于 BFS 计算可达节点并布局）
 */
function updateRouterGraph () {
  const connections = routerConnections.value
  const startRouter = selectedRouter.value

  // 清空旧数据
  Object.keys(routerNodes).forEach(k => delete routerNodes[k])
  Object.keys(routerEdges).forEach(k => delete routerEdges[k])
  routerLayouts.nodes = {}

  if (!connections.has(startRouter)) return

  // 1. 广度优先搜索可达节点 (限制 16 跳)
  const reachable = new Set()
  const queue = [{ router: startRouter, hops: 0 }]
  const visited = new Set([startRouter])

  while (queue.length) {
    const { router, hops } = queue.shift()
    reachable.add(router)
    if (hops >= 16) continue
    
    const neighbors = connections.get(router) || new Set()
    for (const n of neighbors) {
      if (!visited.has(n)) {
        visited.add(n)
        queue.push({ router: n, hops: hops + 1 })
      }
    }
  }

  // 2. 生成节点数据
  for (const router of reachable) {
    routerNodes[router] = { name: router }
  }

  // 3. 生成连线数据（去重）
  const addedEdges = new Set()
  let eid = 1
  for (const s of reachable) {
    const ts = connections.get(s) || new Set()
    for (const t of ts) {
      if (!reachable.has(t)) continue
      const key = s < t ? `${s}-${t}` : `${t}-${s}`
      if (!addedEdges.has(key)) {
        addedEdges.add(key)
        routerEdges[`edge${eid++}`] = { source: s, target: t, label: '连接' }
      }
    }
  }

  // 4. 环形分层布局
  const orbitGroups = { '001': [], '002': [], '003': [] }
  for (const r of reachable) {
    const o = r.substring(1, 4) // 提取轨道标识
    if (orbitGroups[o]) orbitGroups[o].push(r)
  }

  const cx = 0, cy = 0
  const cfg = { 
    '001': { r: 250, off: 0 }, 
    '002': { r: 180, off: Math.PI / 6 }, 
    '003': { r: 110, off: Math.PI / 3 } 
  }

  for (const [o, arr] of Object.entries(orbitGroups)) {
    if (!arr.length) continue
    const step = (2 * Math.PI) / arr.length
    arr.forEach((r, i) => {
      const a = i * step + cfg[o].off
      routerLayouts.nodes[r] = { 
        x: cx + cfg[o].r * Math.cos(a), 
        y: cy + cfg[o].r * Math.sin(a) 
      }
    })
  }
}

// 监听输入变化
watch(selectedRouter, () => {
  if (routerStatus.value === 'ready') updateRouterGraph()
})

onMounted(() => {
  loadRouterData()
})
</script>

<style scoped>
.topology-wrap {
  display: flex;
  justify-content: center;
  width: 100%;
  height: 100vh;
  padding: 20px;
  box-sizing: border-box;
  background-color: #1a1a1a; /* 配合白色文本背景 */
}
.topology-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}
.topology-section h3 { margin: 0; color: #ffffff; }
.controls { width: 100%; max-width: 520px; display: flex; flex-direction: column; gap: 10px; }
.control-item { display: flex; flex-direction: column; gap: 6px; }
.label { font-size: 12px; color: #ffffff; }
.input { height: 32px; padding: 0 10px; border: 1px solid #e2e8f0; border-radius: 8px; outline: none; }
.input:focus { border-color: #3b82f6; }

.topology {
  position: relative;
  background: #fff;
  width: 100%;
  max-width: 900px;
  height: min(700px, calc(100vh - 150px));
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.3);
  overflow: hidden;
}
.overlay { position: absolute; inset: 0; display: flex; justify-content: center; align-items: center; background: rgba(255,255,255,0.8); pointer-events: none; }
.overlay-text { font-size: 13px; color: #475569; }
</style>