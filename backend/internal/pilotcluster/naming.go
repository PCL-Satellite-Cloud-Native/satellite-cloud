package pilotcluster

import "fmt"

// SatNameFromSatID 由 sat-{plane}-{slot} 推导 STK 显示名 Sat_{plane}_{slot}。
func SatNameFromSatID(satID string) string {
	var plane, slot int
	if _, err := fmt.Sscanf(satID, "sat-%d-%d", &plane, &slot); err == nil && plane > 0 {
		return fmt.Sprintf("Sat_%d_%d", plane, slot)
	}
	return satID
}

func (m *Map) SatName(satID string) string {
	if m == nil || !m.Enabled {
		return SatNameFromSatID(satID)
	}
	if e, ok := m.bySat[satID]; ok && e.SatName != "" {
		return e.SatName
	}
	return SatNameFromSatID(satID)
}

// DisplayLabel 页面展示用卫星名（STK 约定），非 K8s 节点名。
func (m *Map) DisplayLabel(satID string) string {
	return m.SatName(satID)
}
