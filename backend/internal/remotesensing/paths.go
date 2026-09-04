package remotesensing

import (
	"path"
	"runtime"
	"strings"
)

// pathForOSAccess 将 WSL 路径（/mnt/d/...）转为 Windows 可访问路径，供 os.Stat 等使用。
// Python 在 WSL 内运行时仍应使用原始 /mnt/ 路径。
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

func usesWSLPython(pythonBin string) bool {
	if runtime.GOOS != "windows" {
		return false
	}
	lower := strings.ToLower(pythonBin)
	return strings.Contains(lower, "wsl")
}

// normalizeArgsForPython 将传给 Python 的相对路径参数统一为 / 分隔，避免 WSL 下生成
// output_preprocessingpan_warp_quartersworkersgroup1 这类错误目录。
func normalizeArgsForPython(pythonBin string, args []string) []string {
	if !usesWSLPython(pythonBin) {
		return args
	}
	out := make([]string, len(args))
	for i, a := range args {
		out[i] = strings.ReplaceAll(a, "\\", "/")
	}
	return out
}
