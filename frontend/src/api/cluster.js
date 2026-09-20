/**
 * 集群节点状态 API。
 * 后端 /api/cluster/nodes 基于 in-cluster k8s 客户端列出节点与 Ready 状态。
 */
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? '/api'

/**
 * 获取集群节点状态列表。
 * @returns {Promise<{available:boolean, count:number, nodes:Array, message?:string}>}
 */
export async function getClusterNodes() {
  const response = await fetch(`${API_BASE_URL}/cluster/nodes`)
  if (!response.ok) {
    throw new Error(`获取集群节点失败: ${response.statusText}`)
  }
  return response.json()
}
