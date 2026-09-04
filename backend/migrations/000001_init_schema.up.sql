-- 000001_init_schema.up.sql（含软删除字段 deleted_at）
-- 初始化数据库表结构，适用于 PostgreSQL

BEGIN;

-- 场景表
CREATE TABLE IF NOT EXISTS public.scenarios (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    epoch           VARCHAR(100) NOT NULL,
    start_time      VARCHAR(100) NOT NULL,
    end_time        VARCHAR(100) NOT NULL,
    alt_km          DOUBLE PRECISION NOT NULL,
    inc_deg         DOUBLE PRECISION NOT NULL,
    n_planes        INTEGER NOT NULL,
    n_sats_per_plane INTEGER NOT NULL,
    sensor_config   JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

COMMENT ON TABLE public.scenarios IS '场景';
COMMENT ON COLUMN public.scenarios.name IS '场景名称';
COMMENT ON COLUMN public.scenarios.epoch IS '历元时间';
COMMENT ON COLUMN public.scenarios.start_time IS '开始时间';
COMMENT ON COLUMN public.scenarios.end_time IS '结束时间';
COMMENT ON COLUMN public.scenarios.alt_km IS '高度(km)';
COMMENT ON COLUMN public.scenarios.inc_deg IS '倾角(度)';
COMMENT ON COLUMN public.scenarios.n_planes IS '轨道面数量';
COMMENT ON COLUMN public.scenarios.n_sats_per_plane IS '每轨道面卫星数';
COMMENT ON COLUMN public.scenarios.sensor_config IS '传感器配置';


-- 卫星表
CREATE TABLE IF NOT EXISTS public.satellites (
    id                  BIGSERIAL PRIMARY KEY,
    scenario_id         BIGINT NOT NULL REFERENCES public.scenarios(id) ON DELETE CASCADE,
    sat_id              VARCHAR(100) NOT NULL,
    stk_name            VARCHAR(255) NOT NULL,
    plane_index         INTEGER NOT NULL,
    sat_index_in_plane  INTEGER NOT NULL,
    alt_km              DOUBLE PRECISION NOT NULL,
    sma_km              DOUBLE PRECISION NOT NULL,
    ecc                 DOUBLE PRECISION NOT NULL,
    inc_deg             DOUBLE PRECISION NOT NULL,
    raan_deg            DOUBLE PRECISION NOT NULL,
    argp_deg            DOUBLE PRECISION NOT NULL,
    ta_deg              DOUBLE PRECISION NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ
);

COMMENT ON TABLE public.satellites IS '卫星';
COMMENT ON COLUMN public.satellites.sat_id IS '卫星ID';
COMMENT ON COLUMN public.satellites.stk_name IS 'STK名称';
COMMENT ON COLUMN public.satellites.plane_index IS '轨道面索引';
COMMENT ON COLUMN public.satellites.sat_index_in_plane IS '轨道面内卫星索引';
COMMENT ON COLUMN public.satellites.alt_km IS '高度(km)';
COMMENT ON COLUMN public.satellites.sma_km IS '半长轴(km)';
COMMENT ON COLUMN public.satellites.ecc IS '偏心率';
COMMENT ON COLUMN public.satellites.inc_deg IS '倾角(度)';
COMMENT ON COLUMN public.satellites.raan_deg IS '升交点赤经(度)';
COMMENT ON COLUMN public.satellites.argp_deg IS '近地点幅角(度)';
COMMENT ON COLUMN public.satellites.ta_deg IS '真近点角(度)';


-- 索引
CREATE INDEX IF NOT EXISTS idx_satellites_scenario_sat_id
    ON public.satellites (scenario_id, sat_id);

CREATE INDEX IF NOT EXISTS idx_satellites_plane_sat_index
    ON public.satellites (plane_index, sat_index_in_plane);

CREATE INDEX IF NOT EXISTS idx_scenarios_deleted_at
    ON public.scenarios (deleted_at);

CREATE INDEX IF NOT EXISTS idx_satellites_deleted_at
    ON public.satellites (deleted_at);


-- 触发器：保持 updated_at 自动更新时间
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_set_updated_at_scenarios'
    ) THEN
        CREATE TRIGGER trg_set_updated_at_scenarios
        BEFORE UPDATE ON public.scenarios
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_set_updated_at_satellites'
    ) THEN
        CREATE TRIGGER trg_set_updated_at_satellites
        BEFORE UPDATE ON public.satellites
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;
END;
$$;

COMMIT;
