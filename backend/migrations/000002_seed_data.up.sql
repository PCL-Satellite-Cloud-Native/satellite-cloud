-- 000002_seed_data.up.sql
-- 最小示例数据种子：Scenario5 + plane 1 前三颗卫星

BEGIN;

WITH s AS (
    INSERT INTO public.scenarios (
        name,
        epoch,
        start_time,
        end_time,
        alt_km,
        inc_deg,
        n_planes,
        n_sats_per_plane,
        sensor_config,
        created_at,
        updated_at
    )
    VALUES (
        'Scenario5',
        '15 Dec 2025 00:00:00',
        '15 Dec 2025 00:00:00',
        '16 Dec 2025 00:00:00',
        550.0,
        53.0,
        36,
        22,
        '{"type": "SimpleConic", "coneHalfAngleDeg": 30.0}'::jsonb,
        NOW(),
        NOW()
    )
    RETURNING id
)
INSERT INTO public.satellites (
    scenario_id,
    sat_id,
    stk_name,
    plane_index,
    sat_index_in_plane,
    alt_km,
    sma_km,
    ecc,
    inc_deg,
    raan_deg,
    argp_deg,
    ta_deg,
    created_at,
    updated_at
)
SELECT
    s.id AS scenario_id,
    v.sat_id,
    v.stk_name,
    v.plane_index,
    v.sat_index_in_plane,
    v.alt_km,
    v.sma_km,
    v.ecc,
    v.inc_deg,
    v.raan_deg,
    v.argp_deg,
    v.ta_deg,
    NOW(),
    NOW()
FROM s
CROSS JOIN (
    VALUES
        ('sat-1-1', 'Sat_1_1', 1, 1, 550.0, 6928.137, 0.0, 53.0, 0.0, 0.0, 0.0),
        ('sat-1-2', 'Sat_1_2', 1, 2, 550.0, 6928.137, 0.0, 53.0, 0.0, 0.0, 16.363636363636363),
        ('sat-1-3', 'Sat_1_3', 1, 3, 550.0, 6928.137, 0.0, 53.0, 0.0, 0.0, 32.72727272727273)
) AS v(
    sat_id,
    stk_name,
    plane_index,
    sat_index_in_plane,
    alt_km,
    sma_km,
    ecc,
    inc_deg,
    raan_deg,
    argp_deg,
    ta_deg
);

COMMIT;
