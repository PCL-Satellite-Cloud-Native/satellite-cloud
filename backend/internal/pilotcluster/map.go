package pilotcluster

import (
	_ "embed"
	"encoding/json"
	"os"
	"strings"
	"sync"
)

//go:embed pilot-map.json
var embeddedMapJSON []byte

const envEnabled = "SATELLITE_PILOT_CLUSTER"
const envMapFile = "SATELLITE_PILOT_MAP_FILE"

// Entry 单条 K8s 部署节点 ↔ 卫星映射（详见 naming.go）。
type Entry struct {
	Node    string `json:"node"`
	SatID   string `json:"sat_id"`
	SatName string `json:"sat_name"`
	Orbit   int    `json:"orbit"`
	Slot    int    `json:"slot"`
}

type file struct {
	Version     int     `json:"version"`
	Description string  `json:"description"`
	Nodes       []Entry `json:"nodes"`
}

// Map Pilot 集群节点与卫星映射表。
type Map struct {
	Enabled      bool
	BridgeLegacy bool // Pilot 15 星 STK 偏移桥接（Sat_6_6…）；60 节点原生 Sat_1_1 时为 false
	Entries      []Entry
	bySat        map[string]Entry
	byNode       map[string]Entry
	satIDs       map[string]struct{}
}

var (
	loadOnce sync.Once
	cached   *Map
)

// Current 返回 Pilot 映射；嵌入 pilot-map.json 非空则默认启用，SATELLITE_PILOT_CLUSTER=false 可关闭。
func Current() *Map {
	loadOnce.Do(func() {
		cached = load()
	})
	return cached
}

func load() *Map {
	bridgeLegacy := strings.ToLower(strings.TrimSpace(os.Getenv(envEnabled))) != "false"

	var raw []byte
	if path := os.Getenv(envMapFile); path != "" {
		if b, err := os.ReadFile(path); err == nil && len(b) > 0 {
			raw = b
		}
	}
	if len(raw) == 0 {
		if !bridgeLegacy {
			return &Map{Enabled: false, BridgeLegacy: false}
		}
		raw = embeddedMapJSON
	}

	var f file
	if err := json.Unmarshal(raw, &f); err != nil || len(f.Nodes) == 0 {
		return &Map{Enabled: false, BridgeLegacy: bridgeLegacy}
	}
	for i := range f.Nodes {
		if f.Nodes[i].SatName == "" {
			f.Nodes[i].SatName = SatNameFromSatID(f.Nodes[i].SatID)
		}
	}
	m := &Map{
		Enabled:      true,
		BridgeLegacy: bridgeLegacy,
		Entries:      f.Nodes,
		bySat:        make(map[string]Entry, len(f.Nodes)),
		byNode:       make(map[string]Entry, len(f.Nodes)),
		satIDs:       make(map[string]struct{}, len(f.Nodes)),
	}
	for _, e := range f.Nodes {
		m.bySat[e.SatID] = e
		m.byNode[e.Node] = e
		m.satIDs[e.SatID] = struct{}{}
	}
	return m
}

func (m *Map) ContainsSatID(satID string) bool {
	if m == nil || !m.Enabled {
		return true
	}
	_, ok := m.satIDs[satID]
	return ok
}

func (m *Map) HostNode(satID string) string {
	if m == nil || !m.Enabled {
		return ""
	}
	return m.bySat[satID].Node
}

func (m *Map) SatIDForNode(node string) string {
	if m == nil || !m.Enabled {
		return ""
	}
	return m.byNode[node].SatID
}

func (m *Map) EntryForSatID(satID string) (Entry, bool) {
	if m == nil || !m.Enabled {
		return Entry{}, false
	}
	e, ok := m.bySat[satID]
	return e, ok
}

func (m *Map) SatIDList() []string {
	if m == nil || !m.Enabled {
		return nil
	}
	out := make([]string, 0, len(m.Entries))
	for _, e := range m.Entries {
		out = append(out, e.SatID)
	}
	return out
}
