<template>
  <div class="topology-wrap">
    <div class="topology-section">
      <h3>路由拓扑 (Zabbix API)</h3>
      <div class="controls">
        <label class="control-item">
          <span class="label" style="text-align:left; display:block;">卫星编号</span>
          <input class="input" v-model.trim="selectedRouter" placeholder="例如：r001001" />
        </label>
        <div class="status-bar">
          <span :class="['indicator', routerStatus]"></span>
          {{ statusText }}
        </div>
      </div>
      <div class="topology">
        <v-network-graph :nodes="routerNodes" :edges="routerEdges" :layouts="routerLayouts">
          <template #override-node="{ scale }">
            <circle :r="12 * scale" fill="#4466cc" />
            </template>
          <template #edge-label="{ edge, ...slotProps }">
            <v-edge-label :text="edge.label" align="center" vertical-align="above" v-bind="slotProps" />
          </template>
        </v-network-graph>

        <div v-if="routerStatus !== 'ready'" class="overlay">
          <div class="overlay-text">
            <template v-if="routerStatus === 'loading'">
              <div class="spinner"></div> 正在从 Zabbix 获取数据...
            </template>
            <template v-else>数据加载失败：{{ routerErrorMsg }}</template>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, reactive, ref, computed, watch } from 'vue'
import { VNetworkGraph, VEdgeLabel } from 'v-network-graph'
import 'v-network-graph/lib/style.css'

// 卫星节点图标
const satIcon = '/satellite.svg'

// ===================== Zabbix API 类定义 =====================
// 移植自参考代码，适配 Vue 环境
class ZabbixAPI {
  constructor(apiUrl, username, password) {
    this.apiUrl = apiUrl
    this.username = username
    this.password = password
    this.authToken = null
    this.requestId = 1
  }

  async login() {
    const payload = {
      jsonrpc: "2.0",
      method: "user.login",
      params: { username: this.username, password: this.password },
      id: this.requestId++
    }
    const res = await fetch(this.apiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    })
    const result = await res.json()
    if (result.error) throw new Error(`Zabbix登录失败: ${result.error.data}`)
    this.authToken = result.result
    return this.authToken
  }

  async call(method, params = {}) {
    if (!this.authToken && method !== 'user.login') await this.login()
    
    const payload = {
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: this.requestId++
    }
    
    const headers = { 'Content-Type': 'application/json' }
    if (this.authToken) headers['Authorization'] = `Bearer ${this.authToken}`

    const res = await fetch(this.apiUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload)
    })
    const result = await res.json()
    if (result.error) throw new Error(`${method} 调用失败: ${result.error.data}`)
    return result
  }

  async getRouters(hostNames) {
    return this.call('host.get', {
      output: ['hostid', 'host', 'name', 'status'],
      filter: { host: hostNames }
    })
  }

  // 获取 OSPF 邻居数据的 History
  async getOSPFNeighborsData(hostIds) {
    // 1. 获取 Item ID
    const itemsResult = await this.call('item.get', {
      output: ['itemid', 'hostid', 'key_'],
      hostids: hostIds,
      search: { key_: 'frr.ospf.neighbors' } // 确保这个Key与你Zabbix中实际的Key一致
    })

    if (!itemsResult.result.length) return []

    // 2. 获取最新 History 数据
    const itemIds = itemsResult.result.map(item => item.itemid)
    // 建立 itemid -> hostid 的映射，方便后续处理
    const itemHostMap = {}
    itemsResult.result.forEach(i => itemHostMap[i.itemid] = i.hostid)

    const historyResult = await this.call('history.get', {
      output: ['itemid', 'value'],
      history: 4, // 4 = text (根据实际监控项类型调整：1=str, 2=log, 4=text)
      itemids: itemIds,
      sortfield: 'clock',
      sortorder: 'DESC',
      limit: itemIds.length // 获取每个item的一条最新数据
    })

    // 将数据组合: hostId -> value
    return historyResult.result.map(h => ({
      hostid: itemHostMap[h.itemid],
      value: h.value
    }))
  }
}

// ===================== 路由拓扑状态与数据 =====================
const routerStatus = ref('loading')
const routerErrorMsg = ref('')
const selectedRouter = ref('r001001')
const routerConnections = ref(new Map())
const statusText = ref('准备就绪')

// 目标路由器列表（用于 API 过滤）
const targetRouters = [
  'r001001', 'r001002', 'r001003', 'r001004', 'r001005',
  'r002001', 'r002002', 'r002003', 'r002004', 'r002005',
  'r003001', 'r003002', 'r003003', 'r003004', 'r003005'
]

// v-network-graph 响应式数据
const routerNodes = reactive({})
const routerEdges = reactive({})
const routerLayouts = reactive({ nodes: {} })

/**
 * 解析 Zabbix 返回的 OSPF 数据获取邻居列表
 * @param {string} value - Zabbix item value (可能是JSON，可能是CLI文本)
 * @returns {Array} 邻居主机名列表
 */
function parseNeighborsFromZabbixValue(value) {
  // TODO: 这里需要根据你实际的监控项返回值进行调整
  // 假设1：返回的是 JSON 数组 ["r001002", "r002001"]
  try {
    const parsed = JSON.parse(value)
    if (Array.isArray(parsed)) return parsed
    // 如果是对象结构，可能需要 parsed.neighbors 等
  } catch (e) {
    // 忽略 JSON 解析错误，尝试文本解析
  }

  // 假设2：返回的是文本，包含邻居名字
  // 简单粗暴匹配：如果在文本中发现了 targetRouters 中的名字，就认为是邻居
  const found = []
  targetRouters.forEach(r => {
    if (value.includes(r)) found.push(r)
  })
  return found
}

/**
 * 从 API 加载数据
 */
async function loadRouterData() {
  routerStatus.value = 'loading'
  routerErrorMsg.value = ''
  statusText.value = '正在连接 Zabbix API...'
  
  try {
    // 1. 初始化 API (根据实际环境配置 URL)
    // 注意：如果是跨域请求，需要在 vite.config.js 配置 proxy，或者服务器开启 CORS
    const zabbix = new ZabbixAPI(
      '/api_jsonrpc.php', // 建议使用相对路径配合 Proxy，避免直接写 IP 导致 Mixed Content
      // 'http://8.166.136.8:8081/api_jsonrpc.php', // 如果不涉及跨域，可以用绝对路径
      'Admin', 
      'zabbix'
    )

    // 2. 登录
    await zabbix.login()
    statusText.value = '登录成功，获取主机列表...'

    // 3. 获取路由器主机信息 (Node)
    const hostsRes = await zabbix.getRouters(targetRouters)
    if (!hostsRes.result || hostsRes.result.length === 0) {
      throw new Error('未找到任何路由器主机')
    }

    const hostIdMap = {} // hostid -> hostname
    const hostnameMap = {} // hostname -> hostid
    hostsRes.result.forEach(h => {
      hostIdMap[h.hostid] = h.host
      hostnameMap[h.host] = h.hostid
    })

    statusText.value = '获取拓扑连接关系...'

    // 4. 获取 OSPF 邻居信息 (Edge)
    const hostIds = Object.keys(hostIdMap)
    const neighborDataList = await zabbix.getOSPFNeighborsData(hostIds)

    // 5. 构建连接 Map
    const connections = new Map()
    
    // 初始化所有节点
    targetRouters.forEach(r => connections.set(r, new Set()))

    neighborDataList.forEach(data => {
      const currentRouterName = hostIdMap[data.hostid]
      if (!currentRouterName) return

      const neighbors = parseNeighborsFromZabbixValue(data.value)
      
      neighbors.forEach(neighborName => {
        // 确保邻居在我们的监控范围内，且不是自己
        if (targetRouters.includes(neighborName) && neighborName !== currentRouterName) {
          connections.get(currentRouterName).add(neighborName)
          // 确保双向连接 (可选，取决于OSPF单向还是双向可见)
          if (!connections.has(neighborName)) connections.set(neighborName, new Set())
          connections.get(neighborName).add(currentRouterName)
        }
      })
    })

    routerConnections.value = connections
    updateRouterGraph()
    routerStatus.value = 'ready'
    statusText.value = '数据已更新'

  } catch (e) {
    console.error(e)
    routerStatus.value = 'error'
    routerErrorMsg.value = e?.message ?? String(e)
    statusText.value = '发生错误'
  }
}

/**
 * 更新图形展示（逻辑保持不变：BFS 计算 + 轨道布局）
 */
function updateRouterGraph() {
  const connections = routerConnections.value
  const startRouter = selectedRouter.value

  // 清空旧数据
  Object.keys(routerNodes).forEach(k => delete routerNodes[k])
  Object.keys(routerEdges).forEach(k => delete routerEdges[k])
  routerLayouts.nodes = {}

  // 如果起始节点不在数据中（比如 API 没返回这个节点），尝试使用第一个存在的节点
  let root = startRouter
  if (!connections.has(root)) {
    const keys = Array.from(connections.keys())
    if (keys.length > 0) root = keys[0]
    else return // 无数据
  }

  // 1. BFS 搜索
  const reachable = new Set()
  const queue = [{ router: root, hops: 0 }]
  const visited = new Set([root])

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

  // 2. 生成节点
  for (const router of reachable) {
    routerNodes[router] = { name: router }
  }

  // 3. 生成连线
  const addedEdges = new Set()
  let eid = 1
  for (const s of reachable) {
    const ts = connections.get(s) || new Set()
    for (const t of ts) {
      if (!reachable.has(t)) continue
      const key = s < t ? `${s}-${t}` : `${t}-${s}`
      if (!addedEdges.has(key)) {
        addedEdges.add(key)
        routerEdges[`edge${eid++}`] = { source: s, target: t, label: '' } // label可留空或显示延迟
      }
    }
  }

  // 4. 布局计算 (轨道布局)
  const orbitGroups = { '001': [], '002': [], '003': [] }
  for (const r of reachable) {
    const o = r.substring(1, 4)
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
    // 按名称排序以保持相对位置稳定
    arr.sort() 
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
  background-color: #1a1a1a;
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

.status-bar {
  display: flex;
  align-items: center;
  font-size: 12px;
  color: #aaa;
  gap: 8px;
}
.indicator { width: 8px; height: 8px; border-radius: 50%; background: #666; }
.indicator.loading { background: #eab308; box-shadow: 0 0 8px #eab308; }
.indicator.ready { background: #22c55e; box-shadow: 0 0 8px #22c55e; }
.indicator.error { background: #ef4444; }

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
.overlay { 
  position: absolute; inset: 0; 
  display: flex; justify-content: center; align-items: center; 
  background: rgba(255,255,255,0.9); z-index: 10;
}
.overlay-text { font-size: 14px; color: #475569; display: flex; align-items: center; gap: 10px; }
.spinner {
  width: 16px; height: 16px;
  border: 2px solid #cbd5e1; border-top-color: #3b82f6;
  border-radius: 50%; animation: spin 1s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
</style>
