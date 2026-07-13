package storage

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"strings"
)

// Backend 产物存储抽象（Phase 6：NFS 默认，MinIO 可选）。
type Backend interface {
	Mode() string
	ResolveLocalPath(rootAbs, relPath string) (string, error)
	Open(ctx context.Context, rootAbs, relPath string) (io.ReadCloser, error)
}

func SafeJoinRoot(rootAbs, relPath string) (string, error) {
	rootAbs, err := filepath.Abs(rootAbs)
	if err != nil {
		return "", err
	}
	target := filepath.Clean(filepath.Join(rootAbs, relPath))
	if target != rootAbs && !strings.HasPrefix(target, rootAbs+string(filepath.Separator)) {
		return "", fmt.Errorf("artifact path 越界")
	}
	return target, nil
}

func objectKey(prefix, rootKey, relPath string) string {
	rel := filepath.ToSlash(filepath.Clean(relPath))
	rel = strings.TrimPrefix(rel, "./")
	parts := []string{}
	if p := strings.Trim(strings.TrimSpace(prefix), "/"); p != "" {
		parts = append(parts, p)
	}
	if k := strings.Trim(strings.TrimSpace(rootKey), "/"); k != "" {
		parts = append(parts, k)
	}
	if rel != "" && rel != "." {
		parts = append(parts, rel)
	}
	return strings.Join(parts, "/")
}
