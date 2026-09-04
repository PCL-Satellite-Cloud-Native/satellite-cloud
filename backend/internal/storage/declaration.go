package storage

// storage 包的声明式支持（存储 CRD 化）：
// 把"产物存储的期望状态"（后端类型 nfs/minio、产物根目录、MinIO 连接、
// 产物上传开关）从环境变量 + 配置文件收敛为 StorageDeclaration，
// 由 apply-config 以 kind: StorageBackend 清单幂等同步到 storage_backends 表，
// 并在 backend=minio 时幂等确保 MinIO Bucket 存在。
// storage 不反向依赖 declarative 包（declarative → storage 单向依赖），
// 因此 DeclarationFromSpec 使用基本类型参数。

import (
	"context"
	"fmt"

	"satellite-cloud/backend/internal/config"
)

// StorageDeclaration 产物存储的声明式配置（源自 kind: StorageBackend 清单）。
// 与 config.StorageConfig 的差异：多一个逻辑名 Name（唯一标识），
// 用于幂等登记到 storage_backends 表。
type StorageDeclaration struct {
	// Name 存储后端逻辑名（如 default），全局唯一。
	Name string
	// Backend 存储后端类型：nfs | minio（缺省 nfs）。
	Backend string
	// RSArtifactRoot 遥感融合产物根目录（nfs 模式）。
	RSArtifactRoot string
	// ODArtifactRoot 目标检测产物根目录（nfs 模式）。
	ODArtifactRoot string
	// ArtifactUploadMinio 任务完成后是否将产物上传 MinIO（D0 试点）。
	ArtifactUploadMinio bool
	// MinioEndpoint / MinioAccessKey / MinioSecretKey / MinioBucket /
	// MinioPrefix / MinioUseSSL MinIO 对象存储连接配置（backend=minio 时必填）。
	MinioEndpoint  string
	MinioAccessKey string
	MinioSecretKey string
	MinioBucket    string
	MinioPrefix    string
	MinioUseSSL    bool
}

// DefaultStorageDeclaration 返回默认存储声明（nfs，无 MinIO 上传），
// 与迁移种子 000012_storage_backends.up.sql 保持一致。
func DefaultStorageDeclaration() StorageDeclaration {
	return StorageDeclaration{Name: "default", Backend: "nfs"}
}

// DeclarationFromSpec 由 StorageBackend 清单的期望状态构造存储声明。
// 使用基本类型参数，避免 storage 依赖 declarative 包。
func DeclarationFromSpec(backend, rsRoot, odRoot string, uploadMinio bool,
	minioEndpoint, minioAccessKey, minioSecretKey, minioBucket, minioPrefix string,
	minioUseSSL bool) StorageDeclaration {
	if backend == "" {
		backend = "nfs"
	}
	if minioBucket == "" {
		minioBucket = "satellite-artifacts"
	}
	return StorageDeclaration{
		Backend:             backend,
		RSArtifactRoot:      rsRoot,
		ODArtifactRoot:      odRoot,
		ArtifactUploadMinio: uploadMinio,
		MinioEndpoint:       minioEndpoint,
		MinioAccessKey:      minioAccessKey,
		MinioSecretKey:      minioSecretKey,
		MinioBucket:         minioBucket,
		MinioPrefix:         minioPrefix,
		MinioUseSSL:         minioUseSSL,
	}
}

// ToConfig 将存储声明转换为 config.StorageConfig，供 factory.New 复用。
func (d StorageDeclaration) ToConfig() config.StorageConfig {
	return config.StorageConfig{
		Backend:             d.Backend,
		MinIOEndpoint:       d.MinioEndpoint,
		MinIOAccessKey:      d.MinioAccessKey,
		MinIOSecretKey:      d.MinioSecretKey,
		MinIOBucket:         d.MinioBucket,
		MinIOPrefix:         d.MinioPrefix,
		MinIOUseSSL:         d.MinioUseSSL,
		ArtifactUploadMinIO: d.ArtifactUploadMinio,
	}
}

// ApplyDeclaration 将存储声明应用到运行环境：
//   - nfs：直接构建 nfsBackend（本地/NFS 路径读写）；
//   - minio：构建 minioBackend，并幂等确保 MinIO Bucket 存在（失败返回错误）。
//
// 返回的 Backend 供运行时代码直接使用；声明同时由
// declarative.ReconcileStorageBackend 幂等登记到 storage_backends 表。
func ApplyDeclaration(ctx context.Context, decl StorageDeclaration) (Backend, error) {
	b, err := New(decl.ToConfig())
	if err != nil {
		return nil, fmt.Errorf("构建存储后端(%s): %w", decl.Backend, err)
	}
	if b.Mode() == "minio" {
		if mb, ok := b.(interface{ EnsureBucket(context.Context) error }); ok {
			if err := mb.EnsureBucket(ctx); err != nil {
				return nil, err
			}
		}
	}
	return b, nil
}
