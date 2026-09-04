package model

import "time"

// StorageBackend 声明式产物存储（kind: StorageBackend）在 PostgreSQL 中的
// 持久化记录。对应迁移：000012_storage_backends.up.sql。
type StorageBackend struct {
	ID uint `gorm:"primaryKey" json:"id"`
	// Name 存储后端逻辑名（唯一，如 default）。
	Name string `gorm:"size:64;uniqueIndex;not null" json:"name"`
	// Backend 存储后端类型：nfs | minio。
	Backend string `gorm:"size:16;not null;default:nfs" json:"backend"`
	// RSArtifactRoot 遥感融合产物根目录（nfs 模式）。
	RSArtifactRoot string `gorm:"size:1024;not null;default:''" json:"rs_artifact_root"`
	// ODArtifactRoot 目标检测产物根目录（nfs 模式）。
	ODArtifactRoot string `gorm:"size:1024;not null;default:''" json:"od_artifact_root"`
	// ArtifactUploadMinio 任务完成后是否将产物上传 MinIO（D0 试点）。
	ArtifactUploadMinio bool `gorm:"not null;default:false" json:"artifact_upload_minio"`
	// MinioEndpoint MinIO 端点（如 minio:9000）。
	MinioEndpoint string `gorm:"size:256;not null;default:''" json:"minio_endpoint"`
	// MinioAccessKey MinIO 访问密钥。
	MinioAccessKey string `gorm:"size:256;not null;default:''" json:"minio_access_key"`
	// MinioSecretKey MinIO 私有密钥。
	MinioSecretKey string `gorm:"size:512;not null;default:''" json:"minio_secret_key"`
	// MinioBucket MinIO Bucket 名。
	MinioBucket string `gorm:"size:128;not null;default:satellite-artifacts" json:"minio_bucket"`
	// MinioPrefix MinIO 对象键统一前缀。
	MinioPrefix string `gorm:"size:256;not null;default:''" json:"minio_prefix"`
	// MinioUseSSL 是否使用 TLS 访问 MinIO。
	MinioUseSSL bool `gorm:"not null;default:false" json:"minio_use_ssl"`
	// CreatedAt 创建时间。
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
	// UpdatedAt 最后同步时间。
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}
