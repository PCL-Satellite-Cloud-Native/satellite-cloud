-- 000007_remote_sensing_detection_fields.up.sql
-- 遥感任务合并目标识别参数（串行流水线第 10 阶段）
BEGIN;

ALTER TABLE public.remote_sensing_tasks
    ADD COLUMN IF NOT EXISTS enable_detection BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS detection_classes VARCHAR(255),
    ADD COLUMN IF NOT EXISTS detection_draw_labels BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.remote_sensing_tasks.enable_detection IS '是否在融合后执行 YOLOv8 目标识别';
COMMENT ON COLUMN public.remote_sensing_tasks.detection_classes IS '检测类别 ID/名称，逗号分隔，空表示全部';

INSERT INTO public.remote_sensing_task_stages (task_id, name, title, stage_order, status)
SELECT t.id, 'object_detection', 'YOLOv8 目标识别', 10, 'pending'
FROM public.remote_sensing_tasks t
WHERE NOT EXISTS (
    SELECT 1 FROM public.remote_sensing_task_stages s
    WHERE s.task_id = t.id AND s.name = 'object_detection'
);

COMMIT;
