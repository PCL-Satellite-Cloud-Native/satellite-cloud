package declarative

import (
	"reflect"
	"testing"

	"satellite-cloud/backend/internal/model"
)

func sc36x22() ScenarioSpec {
	return ScenarioSpec{
		Name:          "Scenario5_full_36x22",
		AltKm:         550,
		IncDeg:        53,
		NPlanes:       36,
		NSatsPerPlane: 22,
	}
}

func TestGenerateConstellation_Size(t *testing.T) {
	sats, err := GenerateConstellation(sc36x22())
	if err != nil {
		t.Fatal(err)
	}
	if len(sats) != 36*22 {
		t.Fatalf("期望 792 颗卫星，实际 %d", len(sats))
	}
	// 每个 plane 22 颗
	byPlane := map[int]int{}
	for _, s := range sats {
		byPlane[s.PlaneIndex]++
	}
	for p := 1; p <= 36; p++ {
		if byPlane[p] != 22 {
			t.Errorf("plane %d 应有 22 颗，实际 %d", p, byPlane[p])
		}
	}
}

// TestGenerateConstellation_MatchesSeed 验证与 migration seed 000003 的数值规律一致。
func TestGenerateConstellation_MatchesSeed(t *testing.T) {
	sats, _ := GenerateConstellation(sc36x22())
	idx := func(plane, slot int) model.Satellite {
		for _, s := range sats {
			if s.PlaneIndex == plane && s.SatIndexInPlane == slot {
				return s
			}
		}
		t.Fatalf("sat-%d-%d 未生成", plane, slot)
		return model.Satellite{}
	}

	cases := []struct {
		plane, slot int
		satID       string
		raan, ta    float64
	}{
		{1, 1, "sat-1-1", 0, 0},
		{1, 2, "sat-1-2", 0, 16.363636},
		{1, 22, "sat-1-22", 0, 343.636364},
		{2, 1, "sat-2-1", 10, 8.181818}, // 偶面偏移半颗
		{2, 2, "sat-2-2", 10, 24.545455},
		{3, 1, "sat-3-1", 20, 0}, // 奇面无偏移
		{4, 1, "sat-4-1", 30, 8.181818},
		{36, 1, "sat-36-1", 350, 8.181818},
		{36, 22, "sat-36-22", 350, 351.818182},
	}
	for _, c := range cases {
		s := idx(c.plane, c.slot)
		if s.SatID != c.satID {
			t.Errorf("plane=%d slot=%d SatID=%q 期望 %q", c.plane, c.slot, s.SatID, c.satID)
		}
		if s.RaanDeg != c.raan {
			t.Errorf("%s raan=%.6f 期望 %.6f", s.SatID, s.RaanDeg, c.raan)
		}
		if s.TaDeg != c.ta {
			t.Errorf("%s ta=%.6f 期望 %.6f", s.SatID, s.TaDeg, c.ta)
		}
	}
}

func TestGenerateConstellation_OrbitParams(t *testing.T) {
	sats, _ := GenerateConstellation(sc36x22())
	s := sats[0]
	if s.SmaKm != 6928.137 {
		t.Errorf("sma=%.3f 期望 6378.137+550=6928.137", s.SmaKm)
	}
	if s.AltKm != 550 {
		t.Errorf("alt=%.3f 期望 550", s.AltKm)
	}
	if s.Ecc != 0 || s.ArgpDeg != 0 {
		t.Errorf("近圆轨道应为 ecc=0 argp=0，实际 %v %v", s.Ecc, s.ArgpDeg)
	}
	if s.IncDeg != 53 {
		t.Errorf("inc=%.3f 期望 53", s.IncDeg)
	}
	if s.StkName != "Sat_1_1" {
		t.Errorf("stk_name=%q 期望 Sat_1_1", s.StkName)
	}
}

func TestGenerateConstellation_Deterministic(t *testing.T) {
	a, _ := GenerateConstellation(sc36x22())
	b, _ := GenerateConstellation(sc36x22())
	if !reflect.DeepEqual(a, b) {
		t.Fatal("同一输入两次生成结果不一致，破坏确定性")
	}
}

func TestGenerateConstellation_Invalid(t *testing.T) {
	if _, err := GenerateConstellation(ScenarioSpec{NPlanes: 0, NSatsPerPlane: 22}); err == nil {
		t.Fatal("nPlanes=0 应报错")
	}
	if _, err := GenerateConstellation(ScenarioSpec{NPlanes: 3, NSatsPerPlane: 20, AltKm: 0}); err == nil {
		t.Fatal("altKm=0 应报错")
	}
}

func TestInlineSatellites_Defaults(t *testing.T) {
	list := []SatelliteSpec{
		{SatID: "sat-1-1", PlaneIndex: 1, SatInPlane: 1, AltKm: 550, RaanDeg: 10, TaDeg: 5},
	}
	sats, err := InlineSatellites(sc36x22(), list)
	if err != nil {
		t.Fatal(err)
	}
	if len(sats) != 1 {
		t.Fatalf("期望 1 颗，实际 %d", len(sats))
	}
	s := sats[0]
	if s.StkName != "Sat_sat-1-1" {
		t.Errorf("默认 stk_name=%q", s.StkName)
	}
	if s.SmaKm != 6928.137 {
		t.Errorf("sma=%.3f 期望由 alt 推导 6928.137", s.SmaKm)
	}
	if s.IncDeg != 53 {
		t.Errorf("默认 inc 应取场景值 53，实际 %.3f", s.IncDeg)
	}
}

func TestDesiredSatellites_Modes(t *testing.T) {
	if _, err := DesiredSatellites(SatelliteConstellationSpec{
		Scenario:   sc36x22(),
		Satellites: SatellitesSpec{Mode: "generated"},
	}); err != nil {
		t.Fatalf("generated 模式应可用: %v", err)
	}
	if _, err := DesiredSatellites(SatelliteConstellationSpec{
		Scenario:   sc36x22(),
		Satellites: SatellitesSpec{Mode: "inline"},
	}); err == nil {
		t.Fatal("inline 模式空列表应报错")
	}
}
