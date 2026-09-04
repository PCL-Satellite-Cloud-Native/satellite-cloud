package storage

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type minioBackend struct {
	client *minio.Client
	bucket string
	prefix string
}

func newMinIOBackend(endpoint, accessKey, secretKey, bucket, prefix string, useSSL bool) (Backend, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("minio client: %w", err)
	}
	return &minioBackend{client: client, bucket: bucket, prefix: prefix}, nil
}

func (b *minioBackend) Mode() string { return "minio" }

// EnsureBucket 幂等确保 MinIO Bucket 存在（不存在则创建）。
// 供声明式 ApplyDeclaration / ReconcileStorageBackend 调用。
func (b *minioBackend) EnsureBucket(ctx context.Context) error {
	exists, err := b.client.BucketExists(ctx, b.bucket)
	if err != nil {
		return fmt.Errorf("minio bucket %q 检查失败: %w", b.bucket, err)
	}
	if exists {
		return nil
	}
	if err := b.client.MakeBucket(ctx, b.bucket, minio.MakeBucketOptions{}); err != nil {
		return fmt.Errorf("minio bucket %q 创建失败: %w", b.bucket, err)
	}
	return nil
}

func (b *minioBackend) ResolveLocalPath(rootAbs, relPath string) (string, error) {
	return "", fmt.Errorf("minio 模式不支持本地路径解析，请使用 Open")
}

func (b *minioBackend) Open(ctx context.Context, rootAbs, relPath string) (io.ReadCloser, error) {
	key := objectKey(b.prefix, rootKeyForObject(rootAbs, relPath), relPath)
	obj, err := b.client.GetObject(ctx, b.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("minio get %q: %w", key, err)
	}
	if _, err := obj.Stat(); err != nil {
		_ = obj.Close()
		return nil, fmt.Errorf("minio stat %q: %w", key, err)
	}
	return obj, nil
}

func (b *minioBackend) Put(ctx context.Context, rootAbs, relPath string, r io.Reader, size int64) error {
	key := objectKey(b.prefix, rootKeyForObject(rootAbs, relPath), relPath)
	contentType := "application/octet-stream"
	lower := strings.ToLower(relPath)
	switch {
	case strings.HasSuffix(lower, ".png"):
		contentType = "image/png"
	case strings.HasSuffix(lower, ".jpg"), strings.HasSuffix(lower, ".jpeg"):
		contentType = "image/jpeg"
	case strings.HasSuffix(lower, ".txt"):
		contentType = "text/plain; charset=utf-8"
	}
	_, err := b.client.PutObject(ctx, b.bucket, key, r, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return fmt.Errorf("minio put %q: %w", key, err)
	}
	return nil
}

func rootKeyFromAbs(rootAbs string) string {
	clean := filepath.ToSlash(filepath.Clean(rootAbs))
	if strings.Contains(clean, "object_detection") {
		return "object_detection"
	}
	return "remote_sensing"
}
