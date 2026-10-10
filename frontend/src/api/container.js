/**
 * 容器编排算法移植效果 API
 * 对应后端 GET /api/container/metrics
 */
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? '/api'

async function handleJSON(response) {
  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(errorText || response.statusText)
  }
  return response.json()
}

/**
 * 获取三类容器编排算法（扩缩 / 部署调度 / 迁移）的移植验收指标
 */
export function getContainerMetrics() {
  return fetch(`${API_BASE_URL}/container/metrics`).then(handleJSON)
}
