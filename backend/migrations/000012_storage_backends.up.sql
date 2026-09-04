-- storage_backends：声明式产物存储（kind: StorageBackend）的期望状态记录。
-- 由 apply-config 幂等同步；后端服务启动时按 name 读取，作为产物存储配置
-- 的单一事实来源（与既有环境变量 SATELLITE_STORAGE_BACKEND / SATELLITE_MINIO_*
-- 并存，声明优先）。
CREATE TABLE IF NOT EXISTS storage_backends (
    id                   BIGSERIAL PRIMARY KEY,
    name                 VARCHAR(64)   NOT NULL UNIQUE,
    backend              VARCHAR(16)   NOT NULL DEFAULT 'nfs',
    rs_artifact_root     VARCHAR(1024) NOT NULL DEFAULT '',
    od_artifact_root     VARCHAR(1024) NOT NULL DEFAULT '',
    artifact_upload_minio BOOLEAN      NOT NULL DEFAULT FALSE,
    minio_endpoint       VARCHAR(256)  NOT NULL DEFAULT '',
    minio_access_key     VARCHAR(256)  NOT NULL DEFAULT '',
    minio_secret_key     VARCHAR(512)  NOT NULL DEFAULT '',
    minio_bucket         VARCHAR(128)  NOT NULL DEFAULT 'satellite-artifacts',
    minio_prefix         VARCHAR(256)  NOT NULL DEFAULT '',
    minio_use_ssl        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- 默认存储声明：与既有环境变量默认值保持一致
-- （SATELLITE_STORAGE_BACKEND=nfs / SATELLITE_ARTIFACT_UPLOAD_MINIO=false，
--   产物根目录为后端默认值 /data/satellite/remote-sensing 与
--   /data/satellite/object-detection）。
INSERT INTO storage_backends (name, backend, rs_artifact_root, od_artifact_root, artifact_upload_minio)
VALUES ('default', 'nfs', '/data/satellite/remote-sensing', '/data/satellite/object-detection', FALSE)
ON CONFLICT (name) DO NOTHING;
