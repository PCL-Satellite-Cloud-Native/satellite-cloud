package objectdetection

import (
	"path"
	"runtime"
	"strings"
)

func pathForOSAccess(p string) string {
	if runtime.GOOS != "windows" {
		return p
	}
	const prefix = "/mnt/"
	if !strings.HasPrefix(p, prefix) {
		return p
	}
	rest := strings.TrimPrefix(p, prefix)
	slash := strings.IndexByte(rest, '/')
	if slash <= 0 {
		return p
	}
	drive := strings.ToUpper(rest[:slash])
	tail := rest[slash+1:]
	return drive + ":\\" + strings.ReplaceAll(path.Clean(tail), "/", "\\")
}

func usesWSLRunner(runnerPath string) bool {
	if runtime.GOOS != "windows" {
		return false
	}
	return strings.Contains(strings.ToLower(runnerPath), "wsl")
}

func pathForWSLRunner(p string) string {
	p = strings.ReplaceAll(p, "\\", "/")
	if strings.HasPrefix(p, "/mnt/") {
		return p
	}
	if runtime.GOOS == "windows" && len(p) >= 2 && p[1] == ':' {
		drive := strings.ToLower(string(p[0]))
		rest := strings.TrimPrefix(p[2:], "/")
		return "/mnt/" + drive + "/" + rest
	}
	return p
}

func normalizeArgsForRunner(runnerPath string, args []string) []string {
	if !usesWSLRunner(runnerPath) {
		return args
	}
	out := make([]string, len(args))
	for i, a := range args {
		out[i] = pathForWSLRunner(a)
	}
	return out
}
