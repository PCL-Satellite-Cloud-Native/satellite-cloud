package remotesensing

import "testing"

func TestPathForOSAccess(t *testing.T) {
	t.Parallel()
	in := "/mnt/d/Code/pcl_satellite_project/Satellite-Remote-Sensing/GMTED2010.jp2"
	want := `D:\Code\pcl_satellite_project\Satellite-Remote-Sensing\GMTED2010.jp2`
	if got := pathForOSAccess(in); got != want {
		t.Fatalf("pathForOSAccess() = %q, want %q", got, want)
	}
}

func TestNormalizeArgsForPython(t *testing.T) {
	t.Parallel()
	args := []string{
		"--input_dir", `output_preprocessing\pan_rad_toa`,
		"--output_dir", `output_preprocessing\pan_warp_quarters\workers\group1`,
	}
	got := normalizeArgsForPython(`D:/proj/wsl-python.cmd`, args)
	want := []string{
		"--input_dir", "output_preprocessing/pan_rad_toa",
		"--output_dir", "output_preprocessing/pan_warp_quarters/workers/group1",
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("args[%d] = %q, want %q", i, got[i], want[i])
		}
	}
}
