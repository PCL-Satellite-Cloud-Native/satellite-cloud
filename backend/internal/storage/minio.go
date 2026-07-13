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

func rootKeyFromAbs(rootAbs string) string {
	clean := filepath.ToSlash(filepath.Clean(rootAbs))
	if strings.Contains(clean, "object_detection") {
		return "object_detection"
	}
	return "remote_sensing"
}
