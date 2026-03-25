-- 000005_remote_sensing_tasks.up.sql
-- 为遥感流水线记录任务/阶段/产物/日志
BEGIN;

-- 任务表：记录一次遥感处理
CREATE TABLE IF NOT EXISTS public.remote_sensing_tasks (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    status          VARCHAR(32) NOT NULL DEFAULT 'pending',
    input_directory TEXT NOT NULL,
    file_prefix     VARCHAR(255) NOT NULL,
    sensor          VARCHAR(64),
    current_stage   VARCHAR(64),
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    finished_at     TIMESTAMPTZ
);

COMMENT ON COLUMN public.remote_sensing_tasks.name IS '任务名称，可用场景/景号';
COMMENT ON COLUMN public.remote_sensing_tasks.status IS 'pending/running/completed/failed';
COMMENT ON COLUMN public.remote_sensing_tasks.current_stage IS '最新活跃阶段';

CREATE INDEX IF NOT EXISTS idx_remote_sensing_tasks_status
    ON public.remote_sensing_tasks (status);

-- 阶段表：每步流水线状态
CREATE TABLE IF NOT EXISTS public.remote_sensing_task_stages (
    id              BIGSERIAL PRIMARY KEY,
    task_id         BIGINT NOT NULL REFERENCES public.remote_sensing_tasks(id) ON DELETE CASCADE,
    name            VARCHAR(128) NOT NULL,
    title           VARCHAR(128),
    stage_order     INTEGER NOT NULL,
    status          VARCHAR(32) NOT NULL DEFAULT 'pending',
    output_path     TEXT,
    details         JSONB DEFAULT '{}'::jsonb,
    message         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    finished_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_remote_sensing_task_stages_task
    ON public.remote_sensing_task_stages (task_id, stage_order);

COMMENT ON COLUMN public.remote_sensing_task_stages.details IS 'JSON 结构的额外信息';

-- artifact 表：保存处理产物/预览路径
CREATE TABLE IF NOT EXISTS public.remote_sensing_task_artifacts (
    id          BIGSERIAL PRIMARY KEY,
    task_id     BIGINT NOT NULL REFERENCES public.remote_sensing_tasks(id) ON DELETE CASCADE,
    type        VARCHAR(64) NOT NULL,
    label       VARCHAR(128),
    path        TEXT NOT NULL,
    metadata    JSONB DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_remote_sensing_task_artifacts_task
    ON public.remote_sensing_task_artifacts (task_id);

COMMENT ON COLUMN public.remote_sensing_task_artifacts.type IS 'raw/preview 等';

-- log 表：记录阶段日志
CREATE TABLE IF NOT EXISTS public.remote_sensing_task_logs (
    id          BIGSERIAL PRIMARY KEY,
    task_id     BIGINT NOT NULL REFERENCES public.remote_sensing_tasks(id) ON DELETE CASCADE,
    stage_name  VARCHAR(128),
    level       VARCHAR(32) NOT NULL,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_remote_sensing_task_logs_task
    ON public.remote_sensing_task_logs (task_id);

-- 触发器：保持 updated_at 自动更新
CREATE TRIGGER trg_set_updated_at_remote_sensing_tasks
    BEFORE UPDATE ON public.remote_sensing_tasks
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_set_updated_at_remote_sensing_task_stages
    BEFORE UPDATE ON public.remote_sensing_task_stages
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
