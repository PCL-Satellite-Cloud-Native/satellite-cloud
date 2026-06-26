package pilotcluster

import "fmt"

// Pilot 15 星与 STK 导入星历 CSV 的轨道/槽位偏移（Sat_6_6 … Sat_8_10 ↔ sat-1-1 … sat-3-5）。
//
// 临时桥接：当前 DB/CSV 仍为 legacy STK 命名，Pilot 业务 ID 为 sat-{p}-{s}。
// 归档与回滚步骤见 docs/archives/2026-06-11_phase5-ephem-id-bridge.md
// STK 更新且 sat_id 一一对应后：删除本文件及相关 lookup，恢复直接 ID 匹配。
const ephemOrbitOffset = 5
const ephemSlotOffset = 5

// EphemOrbitSlot 将 Pilot 轨道面/槽位映射到 legacy 星历 CSV 中的 orbit/slot。
func EphemOrbitSlot(pilotOrbit, pilotSlot int) (int, int) {
	return pilotOrbit + ephemOrbitOffset, pilotSlot + ephemSlotOffset
}

// EphemSTKName 返回 Pilot 星对应的 STK 星历名，如 sat-1-1 → Sat_6_6。
func EphemSTKName(pilotOrbit, pilotSlot int) string {
	o, s := EphemOrbitSlot(pilotOrbit, pilotSlot)
	return fmt.Sprintf("Sat_%d_%d", o, s)
}

// EphemSTKFromPilotSatID 从 sat-{plane}-{slot} 推导 STK 星历名。
func EphemSTKFromPilotSatID(satID string) string {
	var orbit, slot int
	if _, err := fmt.Sscanf(satID, "sat-%d-%d", &orbit, &slot); err == nil && orbit > 0 {
		return EphemSTKName(orbit, slot)
	}
	return ""
}
