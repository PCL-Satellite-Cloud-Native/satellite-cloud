/**
 * 5 节点 k3s 集群的「节点星座」定义。
 *
 * 主页「星座仿真系统 / 卫星网络拓扑」把 5 颗卫星与 5 个集群节点一一对应：
 *  - 5 颗卫星处于同一壳层（同一轨道面），真近点角等间隔 72°，构成相邻卫星环；
 *  - 卫星颜色随对应节点的健康状态变化：
 *      白色 = 节点正常（Ready）
 *      黄色 = 选中（用户点击查看）
 *      红色 = 节点异常 / 无法连通（NotReady）
 */

// 5 个集群节点（顺序即卫星在壳层中的相邻顺序，master 在前）。
export const CLUSTER_NODE_ORDER = [
  'k3s-master07',
  'k3s-node08',
  'k3s-node09',
  'k3s-node10',
  'k3s-node11',
]

// 同一壳层轨道参数（演示用，近似 LEO）。
export const CLUSTER_SHELL = {
  altitudeKm: 550,
  inclinationDeg: 53,
  raanDeg: 30,
  periodSeconds: 5400,
}

// 状态配色（CSS 十六进制）。优先级：选中(黄) > 异常(红) > 正常(白)。
export const NODE_STATUS_COLORS = {
  normal: '#ffffff', // 白色：节点正常
  selected: '#ffd54a', // 黄色：选中
  error: '#ff4d4f', // 红色：节点异常 / 无法连通
}

// 第 index 颗卫星（0..n-1）的真近点角，等间隔分布。
export function shellTrueAnomalyDeg(index, total) {
  return (index * 360) / total
}

// 卫星 id：同一壳层 orbit=1，slot=index+1。
export function clusterSatId(index) {
  return `sat-1-${index + 1}`
}

// 显示名 = 节点名，使卫星直接对应集群节点。
export function clusterSatDisplayName(nodeName) {
  return nodeName
}

// 由节点名解析为稳定索引；不在已知列表中的节点按出现顺序追加。
export function clusterNodeIndex(nodeName) {
  const i = CLUSTER_NODE_ORDER.indexOf(nodeName)
  return i // -1 表示未知节点
}

// 节点状态 → 颜色（十六进制字符串）。
export function statusColor({ ready, selected }) {
  if (selected) return NODE_STATUS_COLORS.selected
  if (!ready) return NODE_STATUS_COLORS.error
  return NODE_STATUS_COLORS.normal
}

// 把后端返回的节点列表按 CLUSTER_NODE_ORDER 重新排序并补全。
export function orderClusterNodes(nodes) {
  const arr = Array.isArray(nodes) ? nodes : []
  const ordered = []
  const seen = new Set()
  for (const name of CLUSTER_NODE_ORDER) {
    const n = arr.find((x) => x.name === name)
    if (n) {
      ordered.push(n)
      seen.add(n.name)
    }
  }
  for (const n of arr) {
    if (!seen.has(n.name)) ordered.push(n)
  }
  return ordered
}
