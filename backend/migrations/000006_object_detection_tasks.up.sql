-- 000006_object_detection_tasks.up.sql
-- 为目标检测任务记录状态/阶段/产物/日志
BEGIN;

CREATE TABLE IF NOT EXISTS public.object_detection_tasks (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    status          VARCHAR(32) NOT NULL DEFAULT 'pending',
    input_path      TEXT NOT NULL,
    classes         VARCHAR(255),
    draw_labels     BOOLEAN NOT NULL DEFAULT FALSE,
    current_stage   VARCHAR(64),
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    finished_at     TIMESTAMPTZ
);

COMMENT ON COLUMN public.object_detection_tasks.status IS 'pending/running/completed/failed';
COMMENT ON COLUMN public.object_detection_tasks.input_path IS 'ENVI .dat 输入路径';
COMMENT ON COLUMN public.object_detection_tasks.classes IS '逗号分隔的类别 ID 或名称，空表示全部';

CREATE INDEX IF NOT EXISTS idx_object_detection_tasks_status
    ON public.object_detection_tasks (status);

CREATE TABLE IF NOT EXISTS public.object_detection_task_stages (
    id              BIGSERIAL PRIMARY KEY,
    task_id         BIGINT NOT NULL REFERENCES public.object_detection_tasks(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_object_detection_task_stages_task
    ON public.object_detection_task_stages (task_id, stage_order);

CREATE TABLE IF NOT EXISTS public.object_detection_task_artifacts (
    id          BIGSERIAL PRIMARY KEY,
    task_id     BIGINT NOT NULL REFERENCES public.object_detection_tasks(id) ON DELETE CASCADE,
    type        VARCHAR(64) NOT NULL,
    label       VARCHAR(128),
    path        TEXT NOT NULL,
    metadata    JSONB DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_object_detection_task_artifacts_task
    ON public.object_detection_task_artifacts (task_id);

CREATE TABLE IF NOT EXISTS public.object_detection_task_logs (
    id          BIGSERIAL PRIMARY KEY,
    task_id     BIGINT NOT NULL REFERENCES public.object_detection_tasks(id) ON DELETE CASCADE,
    stage_name  VARCHAR(128),
    level       VARCHAR(32) NOT NULL,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_object_detection_task_logs_task
    ON public.object_detection_task_logs (task_id);

CREATE TRIGGER trg_set_updated_at_object_detection_tasks
    BEFORE UPDATE ON public.object_detection_tasks
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_set_updated_at_object_detection_task_stages
    BEFORE UPDATE ON public.object_detection_task_stages
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
