-- 000008_remote_sensing_task_topology.up.sql
-- Phase 5：遥感任务绑定场景与卫星（拓扑关联 v1）
BEGIN;

ALTER TABLE public.remote_sensing_tasks
    ADD COLUMN IF NOT EXISTS scenario_id BIGINT REFERENCES public.scenarios(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS satellite_id BIGINT REFERENCES public.satellites(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.remote_sensing_tasks.scenario_id IS '所属仿真场景（拓扑）';
COMMENT ON COLUMN public.remote_sensing_tasks.satellite_id IS '执行/关联卫星（satellites.id）';

CREATE INDEX IF NOT EXISTS idx_remote_sensing_tasks_scenario
    ON public.remote_sensing_tasks (scenario_id);

CREATE INDEX IF NOT EXISTS idx_remote_sensing_tasks_satellite
    ON public.remote_sensing_tasks (satellite_id);

COMMIT;
