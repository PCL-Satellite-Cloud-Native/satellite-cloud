package storage

import (
	"fmt"
	"strings"

	"satellite-cloud/backend/internal/config"
)

// New 按配置创建存储后端；默认 nfs（与 Phase 5+ pilot 行为一致）。
func New(cfg config.StorageConfig) (Backend, error) {
	backend := strings.ToLower(strings.TrimSpace(cfg.Backend))
	switch backend {
	case "", "nfs", "local":
		return newNFSBackend(), nil
	case "minio", "s3":
		if cfg.MinIOEndpoint == "" {
			return nil, fmt.Errorf("SATELLITE_STORAGE_BACKEND=minio 需要 SATELLITE_MINIO_ENDPOINT")
		}
		if cfg.MinIOBucket == "" {
			return nil, fmt.Errorf("SATELLITE_STORAGE_BACKEND=minio 需要 SATELLITE_MINIO_BUCKET")
		}
		return newMinIOBackend(
			cfg.MinIOEndpoint,
			cfg.MinIOAccessKey,
			cfg.MinIOSecretKey,
			cfg.MinIOBucket,
			cfg.MinIOPrefix,
			cfg.MinIOUseSSL,
		)
	default:
		return nil, fmt.Errorf("未知 storage backend: %q", cfg.Backend)
	}
}
