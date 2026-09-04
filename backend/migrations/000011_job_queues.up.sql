-- job_queues：声明式任务队列（kind: JobQueue）的期望状态记录。
-- 由 apply-config 幂等同步；rs-worker / od-worker 启动时按 name 读取。
CREATE TABLE IF NOT EXISTS job_queues (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(64)  NOT NULL UNIQUE,
    stream          VARCHAR(128) NOT NULL,
    consumer_group  VARCHAR(128) NOT NULL,
    consumer_prefix VARCHAR(64),
    concurrency     INTEGER      NOT NULL DEFAULT 1,
    mode            VARCHAR(16)  NOT NULL DEFAULT 'external',
    redis_addr      VARCHAR(255),
    max_len         BIGINT       NOT NULL DEFAULT 0,
    enabled         BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 默认队列声明：与既有环境变量默认值保持一致
-- （SATELLITE_REDIS_STREAM_RS=rs.jobs / SATELLITE_REDIS_CONSUMER_GROUP=rs-workers
--   SATELLITE_REDIS_STREAM_OD=od.jobs / SATELLITE_REDIS_OD_CONSUMER_GROUP=od-workers）。
INSERT INTO job_queues (name, stream, consumer_group, consumer_prefix, concurrency, mode)
VALUES
    ('rs', 'rs.jobs', 'rs-workers', 'rs-worker', 1, 'external'),
    ('od', 'od.jobs', 'od-workers', 'od-worker', 1, 'external')
ON CONFLICT (name) DO NOTHING;
