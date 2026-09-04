package storage

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// Backend 产物存储抽象（Phase 6：NFS 默认，MinIO 可选；D0 增加 Put）。
type Backend interface {
	Mode() string
	ResolveLocalPath(rootAbs, relPath string) (string, error)
	Open(ctx context.Context, rootAbs, relPath string) (io.ReadCloser, error)
	// Put 写入产物；size<0 时由实现自行探测（MinIO 可用 -1）。
	Put(ctx context.Context, rootAbs, relPath string, r io.Reader, size int64) error
}

// PutFile 将本地文件上传/写入 Backend（D0：worker hostPath → MinIO）。
func PutFile(ctx context.Context, b Backend, rootAbs, relPath, localAbs string) error {
	if b == nil {
		return fmt.Errorf("storage backend 为空")
	}
	f, err := os.Open(localAbs)
	if err != nil {
		return err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return err
	}
	return b.Put(ctx, rootAbs, relPath, f, st.Size())
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

// rootKeyForObject 决定 MinIO 对象键中的 root 段。
// 检测产物 path 以 output_detection/ 开头，即使 rootAbs 误为 RS Root 也须用 object_detection。
func rootKeyForObject(rootAbs, relPath string) string {
	rel := filepath.ToSlash(filepath.Clean(relPath))
	if strings.HasPrefix(rel, "output_detection/") {
		return "object_detection"
	}
	return rootKeyFromAbs(rootAbs)
}
