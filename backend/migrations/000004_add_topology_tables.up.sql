-- 000004_add_topology_tables.up.sql
-- 为拓扑与路由可视化增加统一的数据表结构（后续由工具从 CSV 导入）。

BEGIN;

-- 卫星状态表（当前用于 T0，将来可扩展为多时刻）
CREATE TABLE IF NOT EXISTS public.satellite_states (
    id           BIGSERIAL PRIMARY KEY,
    scenario_id  BIGINT NOT NULL REFERENCES public.scenarios(id) ON DELETE CASCADE,
    sat_id       VARCHAR(100) NOT NULL,
    t_utc        TIMESTAMPTZ NOT NULL,
    r_x          DOUBLE PRECISION NOT NULL,
    r_y          DOUBLE PRECISION NOT NULL,
    r_z          DOUBLE PRECISION NOT NULL,
    lla_lat      DOUBLE PRECISION,
    lla_lon      DOUBLE PRECISION,
    lla_alt      DOUBLE PRECISION,
    coe_sma_km   DOUBLE PRECISION,
    coe_ecc      DOUBLE PRECISION,
    coe_inc_deg  DOUBLE PRECISION,
    coe_raan_deg DOUBLE PRECISION,
    coe_argp_deg DOUBLE PRECISION,
    coe_ta_deg   DOUBLE PRECISION,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sat_states_scenario_sat_time
    ON public.satellite_states (scenario_id, sat_id, t_utc);


-- 卫星间延迟边（用于 delay_15x15 等矩阵）
CREATE TABLE IF NOT EXISTS public.satellite_delay_edges (
    id          BIGSERIAL PRIMARY KEY,
    scenario_id BIGINT NOT NULL REFERENCES public.scenarios(id) ON DELETE CASCADE,
    a_id        VARCHAR(100) NOT NULL,
    b_id        VARCHAR(100) NOT NULL,
    delay_s     DOUBLE PRECISION NOT NULL,
    dist_km     DOUBLE PRECISION NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delay_edges_scenario_a_b
    ON public.satellite_delay_edges (scenario_id, a_id, b_id);


-- 路由节点（router ↔ 卫星映射）
CREATE TABLE IF NOT EXISTS public.router_nodes (
    id                BIGSERIAL PRIMARY KEY,
    scenario_id       BIGINT NOT NULL REFERENCES public.scenarios(id) ON DELETE CASCADE,
    router_id         VARCHAR(16) NOT NULL,   -- 例如 r001001
    sat_id            VARCHAR(100) NOT NULL,  -- 例如 sat-1-1
    plane_index       INTEGER NOT NULL,
    sat_index_in_plane INTEGER NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_router_nodes_scenario_router
    ON public.router_nodes (scenario_id, router_id);


-- 路由邻接边（2D 拓扑图使用）
CREATE TABLE IF NOT EXISTS public.router_links (
    id          BIGSERIAL PRIMARY KEY,
    scenario_id BIGINT NOT NULL REFERENCES public.scenarios(id) ON DELETE CASCADE,
    src_router  VARCHAR(16) NOT NULL,
    dst_router  VARCHAR(16) NOT NULL,
    delay_ms    DOUBLE PRECISION,
    loss        DOUBLE PRECISION,
    bandwidth   DOUBLE PRECISION,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_router_links_scenario_src
    ON public.router_links (scenario_id, src_router);

COMMIT;

