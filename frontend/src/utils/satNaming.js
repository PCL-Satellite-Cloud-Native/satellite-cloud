/**
 * 卫星命名约定（与后端 pilotcluster / DB stk_name 一致）：
 * - sat_id:   sat-{plane}-{slot}  业务 ID、调度标签 satellite.io/id
 * - sat_name: Sat_{plane}_{slot}  STK/航天仿真主流显示名
 * - node:     K8s 主机名，仅表示部署位置，非卫星名
 */

export function satNameFromSatId(satId) {
  if (!satId) return ''
  const m = String(satId).match(/^sat-(\d+)-(\d+)$/)
  if (m) return `Sat_${m[1]}_${m[2]}`
  return satId
}

/** 优先 stk_name，其次由 sat_id 推导 Sat_p_s */
export function displaySatName(satelliteOrId, stkName) {
  if (stkName) return stkName
  if (typeof satelliteOrId === 'object' && satelliteOrId) {
    return satelliteOrId.stk_name || satNameFromSatId(satelliteOrId.sat_id)
  }
  return satNameFromSatId(satelliteOrId)
}
