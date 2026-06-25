-- 记录任务实际执行的 K8s 节点与卫星（node 标签 satellite.io/id）
BEGIN;

ALTER TABLE public.remote_sensing_tasks
    ADD COLUMN IF NOT EXISTS host_node_name VARCHAR(255),
    ADD COLUMN IF NOT EXISTS executed_sat_id VARCHAR(100);

COMMENT ON COLUMN public.remote_sensing_tasks.host_node_name IS '执行任务的 K8s 节点名';
COMMENT ON COLUMN public.remote_sensing_tasks.executed_sat_id IS '实际执行节点 satellite.io/id（拓扑 sat_id）';

CREATE INDEX IF NOT EXISTS idx_remote_sensing_tasks_executed_sat_id
    ON public.remote_sensing_tasks (executed_sat_id);

COMMIT;
