package declarative

import (
	"math"
	"testing"

	"satellite-cloud/backend/internal/model"
)

const sampleSatelliteManifest = `apiVersion: cloud.satellite.io/v1
kind: Satellite
metadata:
  name: scenario5-sat1-1-alt-override
spec:
  scenarioName: Scenario5_full_36x22
  satId: sat-1-1
  altKm: 600
`

const sampleSatelliteDeleteManifest = `apiVersion: cloud.satellite.io/v1
kind: Satellite
metadata:
  name: scenario5-sat-99-1-delete
  annotations:
    cloud.satellite.io/delete: "true"
spec:
  scenarioName: Scenario5_full_36x22
  satId: sat-99-1
`

func TestParseSatellite(t *testing.T) {
	sat, err := ParseSatellite([]byte(sampleSatelliteManifest))
	if err != nil {
		t.Fatal(err)
	}
	if sat.Kind != KindSatellite {
		t.Errorf("kind=%q", sat.Kind)
	}
	if sat.Metadata.Name != "scenario5-sat1-1-alt-override" {
		t.Errorf("metadata.name=%q", sat.Metadata.Name)
	}
	if sat.Spec.ScenarioName != "Scenario5_full_36x22" || sat.Spec.SatID != "sat-1-1" {
		t.Errorf("spec 解析错误: %+v", sat.Spec)
	}
	if sat.Spec.AltKm == nil || math.Abs(*sat.Spec.AltKm-600) > 1e-9 {
		t.Errorf("altKm=%v", sat.Spec.AltKm)
	}
	if sat.Spec.RaanDeg != nil || sat.Spec.TaDeg != nil || sat.Spec.IncDeg != nil {
		t.Errorf("未声明字段应为 nil: %+v", sat.Spec)
	}
	if DeleteRequested(sat) {
		t.Error("无删除注解不应判定删除")
	}
}

func TestParseSatellite_DeleteAnnotation(t *testing.T) {
	sat, err := ParseSatellite([]byte(sampleSatelliteDeleteManifest))
	if err != nil {
		t.Fatal(err)
	}
	if !DeleteRequested(sat) {
		t.Error("应识别删除注解")
	}
}

func TestParseSatellite_RejectsBadKind(t *testing.T) {
	_, err := ParseSatellite([]byte(`apiVersion: cloud.satellite.io/v1
kind: SatelliteConstellation
metadata:
  name: x
spec: {}`))
	if err == nil {
		t.Fatal("错误 kind 应被拒绝")
	}
}

func TestParseSatellite_RequiresScenarioName(t *testing.T) {
	_, err := ParseSatellite([]byte(`apiVersion: cloud.satellite.io/v1
kind: Satellite
metadata:
  name: x
spec:
  satId: sat-1-1`))
	if err == nil {
		t.Fatal("缺少 scenarioName 应被拒绝")
	}
}

func TestParseSatellite_RequiresIDOrSlot(t *testing.T) {
	_, err := ParseSatellite([]byte(`apiVersion: cloud.satellite.io/v1
kind: Satellite
metadata:
  name: x
spec:
  scenarioName: S`))
	if err == nil {
		t.Fatal("satId 与 (plane,satInPlane) 全缺应被拒绝")
	}
}

func TestParseSatellite_SlotOnly(t *testing.T) {
	sat, err := ParseSatellite([]byte(`apiVersion: cloud.satellite.io/v1
kind: Satellite
metadata:
  name: x
spec:
  scenarioName: S
  plane: 2
  satInPlane: 3`))
	if err != nil {
		t.Fatal(err)
	}
	if sat.Spec.SatID != "" || *sat.Spec.PlaneIndex != 2 || *sat.Spec.SatInPlane != 3 {
		t.Errorf("spec=%+v", sat.Spec)
	}
}

func TestParseManifest_KindDispatch(t *testing.T) {
	// Constellation
	m, err := ParseManifest([]byte(sampleManifest))
	if err != nil {
		t.Fatal(err)
	}
	if m.Kind != KindConstellation || m.Constellation == nil || m.Satellite != nil {
		t.Errorf("kind 分发错误: %+v", m)
	}
	// Satellite
	m2, err := ParseManifest([]byte(sampleSatelliteManifest))
	if err != nil {
		t.Fatal(err)
	}
	if m2.Kind != KindSatellite || m2.Satellite == nil || m2.Constellation != nil {
		t.Errorf("kind 分发错误: %+v", m2)
	}
	// 未知 kind
	if _, err := ParseManifest([]byte("kind: Deployment\nmetadata:\n  name: x")); err == nil {
		t.Fatal("未知 kind 应被拒绝")
	}
}

// TestWalkerSlot_MatchesSeed 验证单星推导与 migration seed 规律一致。
func TestWalkerSlot_MatchesSeed(t *testing.T) {
	cases := []struct {
		plane, slot int
		wantRaan    float64
		wantTa      float64
	}{
		{1, 1, 0, 0},
		{2, 1, 10, 8.181818},   // 偶面偏移半颗 360/22/2
		{2, 2, 10, 24.545455},   // (2-1)*360/22 + 8.181818
		{36, 22, 350, 351.818182},
	}
	for _, c := range cases {
		raan, ta := WalkerSlot(c.plane, c.slot, 36, 22)
		if math.Abs(raan-c.wantRaan) > 1e-4 || math.Abs(ta-c.wantTa) > 1e-4 {
			t.Errorf("WalkerSlot(%d,%d)=%.6f/%.6f, want %.6f/%.6f",
				c.plane, c.slot, raan, ta, c.wantRaan, c.wantTa)
		}
	}
}

// TestBuildSatelliteModel_DeriveFromScenario 创建场景：未声明字段按构型推导。
func TestBuildSatelliteModel_DeriveFromScenario(t *testing.T) {
	sc := model.Scenario{Name: "S5", AltKm: 550, IncDeg: 53, NPlanes: 36, NSatsPerPlane: 22}
	spec := SatelliteCRSpec{ScenarioName: "S5", SatID: "sat-2-1"}
	m, err := buildSatelliteModel(sc, spec, nil)
	if err != nil {
		t.Fatal(err)
	}
	if m.SatID != "sat-2-1" || m.StkName != "Sat_sat-2-1" {
		t.Errorf("sat=%s stk=%s", m.SatID, m.StkName)
	}
	if math.Abs(m.SmaKm-6928.137) > 1e-3 {
		t.Errorf("sma=%.6f", m.SmaKm)
	}
	if math.Abs(m.RaanDeg-10) > 1e-4 || math.Abs(m.TaDeg-8.181818) > 1e-4 {
		t.Errorf("raan=%.6f ta=%.6f", m.RaanDeg, m.TaDeg)
	}
	if math.Abs(m.IncDeg-53) > 1e-4 || m.Ecc != 0 {
		t.Errorf("inc=%.6f ecc=%v", m.IncDeg, m.Ecc)
	}
}

// TestBuildSatelliteModel_SlotDerivedID satId 缺省时由 (plane, satInPlane) 推导。
func TestBuildSatelliteModel_SlotDerivedID(t *testing.T) {
	sc := model.Scenario{Name: "S60", AltKm: 550, IncDeg: 53, NPlanes: 3, NSatsPerPlane: 20}
	plane, slot := 2, 1
	spec := SatelliteCRSpec{ScenarioName: "S60", PlaneIndex: &plane, SatInPlane: &slot}
	m, err := buildSatelliteModel(sc, spec, nil)
	if err != nil {
		t.Fatal(err)
	}
	if m.SatID != "sat-2-1" {
		t.Errorf("satID=%s", m.SatID)
	}
	// 3 面 × 20 颗：偶面偏移 9°
	if math.Abs(m.RaanDeg-120) > 1e-4 || math.Abs(m.TaDeg-9) > 1e-4 {
		t.Errorf("raan=%.6f ta=%.6f", m.RaanDeg, m.TaDeg)
	}
}

// TestBuildSatelliteModel_ExplicitOverrides 显式声明优先于构型推导。
func TestBuildSatelliteModel_ExplicitOverrides(t *testing.T) {
	sc := model.Scenario{Name: "S5", AltKm: 550, IncDeg: 53, NPlanes: 36, NSatsPerPlane: 22}
	alt, inc, ta := 600.0, 70.0, 12.5
	spec := SatelliteCRSpec{
		ScenarioName: "S5", SatID: "sat-2-1",
		AltKm: &alt, IncDeg: &inc, TaDeg: &ta,
	}
	m, err := buildSatelliteModel(sc, spec, nil)
	if err != nil {
		t.Fatal(err)
	}
	if math.Abs(m.AltKm-600) > 1e-4 || math.Abs(m.SmaKm-6978.137) > 1e-3 {
		t.Errorf("alt=%.6f sma=%.6f", m.AltKm, m.SmaKm)
	}
	if math.Abs(m.IncDeg-70) > 1e-4 || math.Abs(m.TaDeg-12.5) > 1e-4 {
		t.Errorf("inc=%.6f ta=%.6f", m.IncDeg, m.TaDeg)
	}
	// 未声明的 raan 仍走构型推导
	if math.Abs(m.RaanDeg-10) > 1e-4 {
		t.Errorf("raan=%.6f", m.RaanDeg)
	}
}

// TestBuildSatelliteModel_ExistingPreserved 更新场景：未声明字段保留现值。
func TestBuildSatelliteModel_ExistingPreserved(t *testing.T) {
	sc := model.Scenario{Name: "S5", AltKm: 550, IncDeg: 53, NPlanes: 36, NSatsPerPlane: 22}
	existing := &model.Satellite{
		SatID: "sat-2-1", StkName: "CustomName",
		PlaneIndex: 2, SatIndexInPlane: 1,
		AltKm: 500, SmaKm: 6878.137, Ecc: 0.1,
		IncDeg: 80, RaanDeg: 5, ArgpDeg: 6, TaDeg: 7,
	}
	alt := 600.0
	spec := SatelliteCRSpec{ScenarioName: "S5", SatID: "sat-2-1", AltKm: &alt}
	m, err := buildSatelliteModel(sc, spec, existing)
	if err != nil {
		t.Fatal(err)
	}
	// 显式 altKm 生效并联动 sma
	if math.Abs(m.AltKm-600) > 1e-4 || math.Abs(m.SmaKm-6978.137) > 1e-3 {
		t.Errorf("alt=%.6f sma=%.6f", m.AltKm, m.SmaKm)
	}
	// 未声明字段保留现值
	if m.StkName != "CustomName" {
		t.Errorf("stkName=%q", m.StkName)
	}
	if math.Abs(m.IncDeg-80) > 1e-4 || math.Abs(m.RaanDeg-5) > 1e-4 ||
		math.Abs(m.ArgpDeg-6) > 1e-4 || math.Abs(m.TaDeg-7) > 1e-4 || m.Ecc != 0.1 {
		t.Errorf("未声明字段未保留现值: %+v", m)
	}
}

func TestSatIDToSlot(t *testing.T) {
	if p, s := satIDToSlot("sat-36-22"); p != 36 || s != 22 {
		t.Errorf("sat-36-22 -> %d/%d", p, s)
	}
	if p, s := satIDToSlot("custom-id"); p != 0 || s != 0 {
		t.Errorf("非法格式应返回 0/0，实际 %d/%d", p, s)
	}
}
