package declarative

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/storage"
)

// StorageBackendReconcileResult 汇报产物存储声明式同步的结果。
type StorageBackendReconcileResult struct {
	// CRName 清单 metadata.name。
	CRName string
	// BackendName 实际写入的存储后端逻辑名（spec.name，缺省 metadata.name）。
	BackendName string
	// Backend 存储后端类型（nfs / minio）。
	Backend string
	// Action 取值：created / updated / skipped / deleted / notfound。
	Action string
	// BucketAction 取值：created / existing / failed / skipped
	// （dry-run、nfs 后端或未提供 MinIO 连接信息）。
	BucketAction string
	// BucketError MinIO Bucket 确保失败时的错误信息（不阻塞持久层同步）。
	BucketError string
}

// ReconcileStorageBackend 把一份 StorageBackend CR 同步到 PostgreSQL 的
// storage_backends 表（幂等），并在 backend=minio 且连接信息完整时，
// 幂等确保 MinIO Bucket 存在。
//
// 同步语义：
//  1. 带删除注解（cloud.satellite.io/delete=true）→ 删除 storage_backends 记录；
//     注意：仅删除声明登记，不会删除已落盘产物，也不会删除 MinIO Bucket；
//  2. 按存储后端逻辑名（spec.name，缺省 metadata.name）幂等查找；
//  3. 不存在 → 插入声明（Action=created），并（可选）确保 MinIO Bucket 存在；
//  4. 已存在 → spec 期望字段与库中不一致时收敛更新（Action=updated），
//     一致则跳过（Action=skipped）；MinIO Bucket 确保仍执行一次（幂等）。
//
// 与既有机制的关系：后端服务启动时仍按环境变量构造 storage.Backend；
// 本同步登记"期望状态"到 storage_backends 表，作为未来
// controller / 启动引导读取声明的单一事实来源。MinIO 连接信息不完整时
// 仅登记声明，Bucket 仍由后端运行时的 ApplyDeclaration 幂等创建。
func ReconcileStorageBackend(db *gorm.DB, cr *StorageBackend, _ ReconcileOptions) (*StorageBackendReconcileResult, error) {
	if cr == nil {
		return nil, errors.New("nil manifest")
	}
	res := &StorageBackendReconcileResult{
		CRName: cr.Metadata.Name,
	}

	// 1. 删除注解分支
	if DeleteRequestedStorageBackend(cr) {
		return deleteStorageBackend(db, cr)
	}

	// 2. 存储后端逻辑名：spec.name 缺省取 metadata.name
	name := cr.Spec.Name
	if name == "" {
		name = cr.Metadata.Name
	}
	res.BackendName = name
	res.Backend = desiredStorageBackendType(cr)

	// 3. 幂等查找
	var existing model.StorageBackend
	err := db.Where("name = ?", name).First(&existing).Error
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("query storage backend %q: %w", name, err)
	}

	// 4. 不存在 → 创建
	if errors.Is(err, gorm.ErrRecordNotFound) {
		created, createErr := createStorageBackend(db, cr, name)
		if createErr != nil {
			return nil, createErr
		}
		res.Backend = created.Backend
		res.Action = "created"
		ensureStorageBucket(res, cr)
		return res, nil
	}

	// 5. 已存在 → 收敛期望字段
	res.Backend = existing.Backend
	if storageBackendSpecsEqual(existing, cr) {
		res.Action = "skipped"
		ensureStorageBucket(res, cr)
		return res, nil
	}
	if err := db.Model(&model.StorageBackend{}).Where("id = ?", existing.ID).Updates(map[string]interface{}{
		"backend":               desiredStorageBackendType(cr),
		"rs_artifact_root":      cr.Spec.RSArtifactRoot,
		"od_artifact_root":      cr.Spec.ODArtifactRoot,
		"artifact_upload_minio": cr.Spec.ArtifactUploadMinio,
		"minio_endpoint":        desiredStorageMinioField(cr, "endpoint"),
		"minio_access_key":      desiredStorageMinioField(cr, "accessKey"),
		"minio_secret_key":      desiredStorageMinioField(cr, "secretKey"),
		"minio_bucket":          desiredStorageBucket(cr),
		"minio_prefix":          desiredStorageMinioField(cr, "prefix"),
		"minio_use_ssl":         desiredStorageMinioUseSSL(cr),
		"updated_at":            time.Now().UTC(),
	}).Error; err != nil {
		return nil, fmt.Errorf("update storage backend %q: %w", name, err)
	}
	res.Backend = desiredStorageBackendType(cr)
	res.Action = "updated"
	ensureStorageBucket(res, cr)
	return res, nil
}

// createStorageBackend 插入存储声明到 storage_backends 表（幂等）。
func createStorageBackend(db *gorm.DB, cr *StorageBackend, name string) (*model.StorageBackend, error) {
	now := time.Now().UTC()
	sb := model.StorageBackend{
		Name:                name,
		Backend:             desiredStorageBackendType(cr),
		RSArtifactRoot:      cr.Spec.RSArtifactRoot,
		ODArtifactRoot:      cr.Spec.ODArtifactRoot,
		ArtifactUploadMinio: cr.Spec.ArtifactUploadMinio,
		MinioEndpoint:       desiredStorageMinioField(cr, "endpoint"),
		MinioAccessKey:      desiredStorageMinioField(cr, "accessKey"),
		MinioSecretKey:      desiredStorageMinioField(cr, "secretKey"),
		MinioBucket:         desiredStorageBucket(cr),
		MinioPrefix:         desiredStorageMinioField(cr, "prefix"),
		MinioUseSSL:         desiredStorageMinioUseSSL(cr),
		CreatedAt:           now,
		UpdatedAt:           now,
	}
	if err := db.Create(&sb).Error; err != nil {
		return nil, fmt.Errorf("create storage backend %q: %w", name, err)
	}
	return &sb, nil
}

// deleteStorageBackend 按删除注解清理 storage_backends 记录（幂等）。
// 仅删除声明登记，不删除已落盘产物，也不删除 MinIO Bucket。
func deleteStorageBackend(db *gorm.DB, cr *StorageBackend) (*StorageBackendReconcileResult, error) {
	res := &StorageBackendReconcileResult{
		CRName:       cr.Metadata.Name,
		BackendName:  cr.Spec.Name,
		Backend:      desiredStorageBackendType(cr),
		BucketAction: "skipped",
	}
	if res.BackendName == "" {
		res.BackendName = cr.Metadata.Name
	}

	var existing model.StorageBackend
	if err := db.Where("name = ?", res.BackendName).First(&existing).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			res.Action = "notfound" // 幂等：目标已不存在视为完成
			return res, nil
		}
		return nil, fmt.Errorf("query storage backend %q: %w", res.BackendName, err)
	}

	if err := db.Delete(&existing).Error; err != nil {
		return nil, fmt.Errorf("delete storage backend %q: %w", res.BackendName, err)
	}
	res.Action = "deleted"
	return res, nil
}

// ensureStorageBucket 在 backend=minio 且连接信息完整时，幂等确保 MinIO
// Bucket 存在（复用 storage.ApplyDeclaration → EnsureBucket）；
// 失败不阻塞持久层同步，结果写入 res（BucketAction / BucketError）。
// nfs 后端或连接信息不完整时跳过（BucketAction=skipped）。
func ensureStorageBucket(res *StorageBackendReconcileResult, cr *StorageBackend) {
	if desiredStorageBackendType(cr) != "minio" {
		res.BucketAction = "skipped" // nfs 后端无需 Bucket
		return
	}
	if cr.Spec.Minio == nil || cr.Spec.Minio.Endpoint == "" {
		res.BucketAction = "skipped" // 未提供 MinIO 连接信息：仅登记声明
		return
	}
	decl := storage.DeclarationFromSpec(
		"minio", cr.Spec.RSArtifactRoot, cr.Spec.ODArtifactRoot,
		cr.Spec.ArtifactUploadMinio,
		cr.Spec.Minio.Endpoint, cr.Spec.Minio.AccessKey, cr.Spec.Minio.SecretKey,
		desiredStorageBucket(cr), cr.Spec.Minio.Prefix, cr.Spec.Minio.UseSSL,
	)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if _, err := storage.ApplyDeclaration(ctx, decl); err != nil {
		res.BucketAction = "failed"
		res.BucketError = err.Error()
		return
	}
	res.BucketAction = "existing" // Bucket 已存在或已幂等创建
}

// storageBackendSpecsEqual 判断 CR 期望字段与库中记录是否一致（忽略 created_at/updated_at）。
func storageBackendSpecsEqual(sb model.StorageBackend, cr *StorageBackend) bool {
	return sb.Backend == desiredStorageBackendType(cr) &&
		sb.RSArtifactRoot == cr.Spec.RSArtifactRoot &&
		sb.ODArtifactRoot == cr.Spec.ODArtifactRoot &&
		sb.ArtifactUploadMinio == cr.Spec.ArtifactUploadMinio &&
		sb.MinioEndpoint == desiredStorageMinioField(cr, "endpoint") &&
		sb.MinioAccessKey == desiredStorageMinioField(cr, "accessKey") &&
		sb.MinioSecretKey == desiredStorageMinioField(cr, "secretKey") &&
		sb.MinioBucket == desiredStorageBucket(cr) &&
		sb.MinioPrefix == desiredStorageMinioField(cr, "prefix") &&
		sb.MinioUseSSL == desiredStorageMinioUseSSL(cr)
}

// desiredStorageBackendType 返回存储后端类型（缺省 nfs）。
func desiredStorageBackendType(cr *StorageBackend) string {
	if cr.Spec.Backend != "" {
		return cr.Spec.Backend
	}
	return "nfs"
}

// desiredStorageBucket 返回 MinIO Bucket 名（缺省 satellite-artifacts）。
func desiredStorageBucket(cr *StorageBackend) string {
	if cr.Spec.Minio != nil && cr.Spec.Minio.Bucket != "" {
		return cr.Spec.Minio.Bucket
	}
	return "satellite-artifacts"
}

// desiredStorageMinioUseSSL 返回是否使用 TLS 访问 MinIO。
func desiredStorageMinioUseSSL(cr *StorageBackend) bool {
	return cr.Spec.Minio != nil && cr.Spec.Minio.UseSSL
}

// desiredStorageMinioField 返回 MinIO 连接字段（cr.Spec.Minio 为空时返回空串）。
func desiredStorageMinioField(cr *StorageBackend, field string) string {
	if cr.Spec.Minio == nil {
		return ""
	}
	switch field {
	case "endpoint":
		return cr.Spec.Minio.Endpoint
	case "accessKey":
		return cr.Spec.Minio.AccessKey
	case "secretKey":
		return cr.Spec.Minio.SecretKey
	case "prefix":
		return cr.Spec.Minio.Prefix
	}
	return ""
}
