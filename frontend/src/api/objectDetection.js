const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? '/api'

async function handleJSON(response) {
  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(errorText || response.statusText)
  }
  return response.json()
}

export function listObjectDetectionTasks() {
  return fetch(`${API_BASE_URL}/object-detection/tasks`).then(handleJSON)
}

export function createObjectDetectionTask(payload) {
  return fetch(`${API_BASE_URL}/object-detection/tasks`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }).then(handleJSON)
}

export function getObjectDetectionStages(taskId) {
  return fetch(`${API_BASE_URL}/object-detection/tasks/${taskId}/stages`).then(handleJSON)
}

export function getObjectDetectionLogs(taskId, limit = 200) {
  return fetch(`${API_BASE_URL}/object-detection/tasks/${taskId}/logs?limit=${limit}`).then(handleJSON)
}

export function getObjectDetectionArtifacts(taskId) {
  return fetch(`${API_BASE_URL}/object-detection/tasks/${taskId}/artifacts`).then(handleJSON)
}

export function streamObjectDetectionEvents(taskId, onEvent, onError) {
  const source = new EventSource(`${API_BASE_URL}/object-detection/tasks/${taskId}/events`)
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
  return `${API_BASE_URL}/object-detection/tasks/${taskId}/artifacts/${artifactId}`
}
