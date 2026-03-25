const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? '/api'

async function handleJSON(response) {
  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(errorText || response.statusText)
  }
  return response.json()
}

export function listRemoteSensingTasks() {
  return fetch(`${API_BASE_URL}/remote-sensing/tasks`).then(handleJSON)
}

export function createRemoteSensingTask(payload) {
  return fetch(`${API_BASE_URL}/remote-sensing/tasks`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }).then(handleJSON)
}

export function getRemoteSensingStages(taskId) {
  return fetch(`${API_BASE_URL}/remote-sensing/tasks/${taskId}/stages`).then(handleJSON)
}

export function getRemoteSensingLogs(taskId, limit = 200) {
  return fetch(`${API_BASE_URL}/remote-sensing/tasks/${taskId}/logs?limit=${limit}`).then(handleJSON)
}

export function getRemoteSensingArtifacts(taskId) {
  return fetch(`${API_BASE_URL}/remote-sensing/tasks/${taskId}/artifacts`).then(handleJSON)
}

export function streamRemoteSensingEvents(taskId, onEvent, onError) {
  const source = new EventSource(`${API_BASE_URL}/remote-sensing/tasks/${taskId}/events`)
  source.addEventListener('stage_update', (event) => {
    try {
      onEvent(JSON.parse(event.data))
    } catch (err) {
      console.error('无法解析事件', err)
    }
  })
  source.onerror = (err) => {
    if (onError) {
      onError(err)
    }
  }
  return source
}

export function artifactDownloadUrl(taskId, artifactId) {
  return `${API_BASE_URL}/remote-sensing/tasks/${taskId}/artifacts/${artifactId}`
}
