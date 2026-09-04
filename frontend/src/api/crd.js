/**
 * 声明式清单（CRD）同步 API
 * 覆盖 kind：SatelliteConstellation / Satellite / NetworkTopology /
 *           JobQueue / StorageBackend / RemoteSensingTask / ObjectDetectionTask
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
 * 执行 CRD 清单同步（POST /api/crd/sync）
 * @param {string} configDir 可选，清单目录；缺省使用后端启动时目录
 */
export function syncCrd(configDir) {
  return fetch(`${API_BASE_URL}/crd/sync`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(configDir ? { config_dir: configDir } : {}),
  }).then(handleJSON)
}

/**
 * 获取声明式任务队列（kind: JobQueue）列表
 */
export function listJobQueues() {
  return fetch(`${API_BASE_URL}/job-queues`).then(handleJSON)
}

/**
 * 获取声明式产物存储（kind: StorageBackend）列表
 */
export function listStorageBackends() {
  return fetch(`${API_BASE_URL}/storage-backends`).then(handleJSON)
}

/**
 * 列出 CRD 清单 YAML 文件（GET /api/crd/manifests）
 */
export function listCrdManifests() {
  return fetch(`${API_BASE_URL}/crd/manifests`).then(handleJSON)
}

/**
 * 读取单个清单文件内容（GET /api/crd/manifests/:filename）
 */
export function getCrdManifest(filename) {
  return fetch(`${API_BASE_URL}/crd/manifests/${encodeURIComponent(filename)}`).then(handleJSON)
}

/**
 * 保存（覆盖）单个清单文件（PUT /api/crd/manifests/:filename）
 */
export function saveCrdManifest(filename, content) {
  return fetch(`${API_BASE_URL}/crd/manifests/${encodeURIComponent(filename)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content }),
  }).then(handleJSON)
}

/**
 * 执行（应用）单个清单文件（POST /api/crd/manifests/:filename/apply）
 */
export function applyCrdManifest(filename) {
  return fetch(`${API_BASE_URL}/crd/manifests/${encodeURIComponent(filename)}/apply`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}',
  }).then(handleJSON)
}
