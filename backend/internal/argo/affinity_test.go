package argo

import "testing"

func TestPanRPCNodeAffinityRequired(t *testing.T) {
	t.Parallel()
	aff := panRPCNodeAffinity("sat-1-1", true)
	nodeAff, ok := aff["nodeAffinity"].(map[string]interface{})
	if !ok {
		t.Fatal("missing nodeAffinity")
	}
	if _, ok := nodeAff["requiredDuringSchedulingIgnoredDuringExecution"]; !ok {
		t.Fatal("expected requiredDuringSchedulingIgnoredDuringExecution")
	}
	if _, ok := nodeAff["preferredDuringSchedulingIgnoredDuringExecution"]; ok {
		t.Fatal("unexpected preferredDuringSchedulingIgnoredDuringExecution")
	}
}

func TestPanRPCNodeAffinityPreferred(t *testing.T) {
	t.Parallel()
	aff := panRPCNodeAffinity("sat-2-1", false)
	nodeAff, ok := aff["nodeAffinity"].(map[string]interface{})
	if !ok {
		t.Fatal("missing nodeAffinity")
	}
	if _, ok := nodeAff["preferredDuringSchedulingIgnoredDuringExecution"]; !ok {
		t.Fatal("expected preferredDuringSchedulingIgnoredDuringExecution")
	}
}
