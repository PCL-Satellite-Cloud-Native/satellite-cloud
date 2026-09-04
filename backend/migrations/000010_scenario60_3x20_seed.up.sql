-- 000010_scenario60_3x20_seed.up.sql
-- 60 节点 3x20 场景及卫星种子（与 pilot-map-60 / Sat_1_1…Sat_3_20 对齐）

BEGIN;

WITH s AS (
  INSERT INTO public.scenarios (
    name, epoch, start_time, end_time,
    alt_km, inc_deg, n_planes, n_sats_per_plane, sensor_config,
    created_at, updated_at
  )
  SELECT
    'Scenario60_3x20',
    '15 Jul 2026 00:00:00 UTCG',
    '15 Jul 2026 00:00:00',
    '16 Jul 2026 00:00:00',
    550.000000,
    53.000000,
    3,
    20,
    '{"coneHalfAngleDeg":30,"type":"SimpleConic"}'::jsonb,
    NOW(), NOW()
  WHERE NOT EXISTS (SELECT 1 FROM public.scenarios WHERE name = 'Scenario60_3x20')
  RETURNING id
), sid AS (
  SELECT id FROM s
  UNION ALL
  SELECT id FROM public.scenarios WHERE name = 'Scenario60_3x20'
  LIMIT 1
)
INSERT INTO public.satellites (
  scenario_id, sat_id, stk_name, plane_index, sat_index_in_plane,
  alt_km, sma_km, ecc, inc_deg, raan_deg, argp_deg, ta_deg,
  created_at, updated_at
)
SELECT
  sid.id, v.sat_id, v.stk_name, v.plane_index, v.sat_index_in_plane,
  v.alt_km, v.sma_km, v.ecc, v.inc_deg, v.raan_deg, v.argp_deg, v.ta_deg,
  NOW(), NOW()
FROM sid, (
  SELECT 'sat-1-1' AS sat_id, 'Sat_1_1' AS stk_name, 1 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-2' AS sat_id, 'Sat_1_2' AS stk_name, 1 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 18.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-3' AS sat_id, 'Sat_1_3' AS stk_name, 1 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 36.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-4' AS sat_id, 'Sat_1_4' AS stk_name, 1 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 54.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-5' AS sat_id, 'Sat_1_5' AS stk_name, 1 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 72.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-6' AS sat_id, 'Sat_1_6' AS stk_name, 1 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-7' AS sat_id, 'Sat_1_7' AS stk_name, 1 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 108.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-8' AS sat_id, 'Sat_1_8' AS stk_name, 1 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 126.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-9' AS sat_id, 'Sat_1_9' AS stk_name, 1 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 144.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-10' AS sat_id, 'Sat_1_10' AS stk_name, 1 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 162.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-11' AS sat_id, 'Sat_1_11' AS stk_name, 1 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-12' AS sat_id, 'Sat_1_12' AS stk_name, 1 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 198.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-13' AS sat_id, 'Sat_1_13' AS stk_name, 1 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 216.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-14' AS sat_id, 'Sat_1_14' AS stk_name, 1 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 234.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-15' AS sat_id, 'Sat_1_15' AS stk_name, 1 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 252.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-16' AS sat_id, 'Sat_1_16' AS stk_name, 1 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-17' AS sat_id, 'Sat_1_17' AS stk_name, 1 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 288.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-18' AS sat_id, 'Sat_1_18' AS stk_name, 1 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 306.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-19' AS sat_id, 'Sat_1_19' AS stk_name, 1 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 324.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-20' AS sat_id, 'Sat_1_20' AS stk_name, 1 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         0.000000 AS raan_deg, 0.000000 AS argp_deg, 342.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-1' AS sat_id, 'Sat_2_1' AS stk_name, 2 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-2' AS sat_id, 'Sat_2_2' AS stk_name, 2 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 18.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-3' AS sat_id, 'Sat_2_3' AS stk_name, 2 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 36.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-4' AS sat_id, 'Sat_2_4' AS stk_name, 2 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 54.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-5' AS sat_id, 'Sat_2_5' AS stk_name, 2 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 72.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-6' AS sat_id, 'Sat_2_6' AS stk_name, 2 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-7' AS sat_id, 'Sat_2_7' AS stk_name, 2 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 108.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-8' AS sat_id, 'Sat_2_8' AS stk_name, 2 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 126.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-9' AS sat_id, 'Sat_2_9' AS stk_name, 2 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 144.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-10' AS sat_id, 'Sat_2_10' AS stk_name, 2 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 162.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-11' AS sat_id, 'Sat_2_11' AS stk_name, 2 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-12' AS sat_id, 'Sat_2_12' AS stk_name, 2 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 198.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-13' AS sat_id, 'Sat_2_13' AS stk_name, 2 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 216.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-14' AS sat_id, 'Sat_2_14' AS stk_name, 2 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 234.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-15' AS sat_id, 'Sat_2_15' AS stk_name, 2 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 252.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-16' AS sat_id, 'Sat_2_16' AS stk_name, 2 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-17' AS sat_id, 'Sat_2_17' AS stk_name, 2 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 288.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-18' AS sat_id, 'Sat_2_18' AS stk_name, 2 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 306.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-19' AS sat_id, 'Sat_2_19' AS stk_name, 2 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 324.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-20' AS sat_id, 'Sat_2_20' AS stk_name, 2 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         120.000000 AS raan_deg, 0.000000 AS argp_deg, 342.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-1' AS sat_id, 'Sat_3_1' AS stk_name, 3 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-2' AS sat_id, 'Sat_3_2' AS stk_name, 3 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 18.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-3' AS sat_id, 'Sat_3_3' AS stk_name, 3 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 36.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-4' AS sat_id, 'Sat_3_4' AS stk_name, 3 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 54.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-5' AS sat_id, 'Sat_3_5' AS stk_name, 3 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 72.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-6' AS sat_id, 'Sat_3_6' AS stk_name, 3 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-7' AS sat_id, 'Sat_3_7' AS stk_name, 3 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 108.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-8' AS sat_id, 'Sat_3_8' AS stk_name, 3 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 126.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-9' AS sat_id, 'Sat_3_9' AS stk_name, 3 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 144.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-10' AS sat_id, 'Sat_3_10' AS stk_name, 3 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 162.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-11' AS sat_id, 'Sat_3_11' AS stk_name, 3 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-12' AS sat_id, 'Sat_3_12' AS stk_name, 3 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 198.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-13' AS sat_id, 'Sat_3_13' AS stk_name, 3 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 216.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-14' AS sat_id, 'Sat_3_14' AS stk_name, 3 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 234.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-15' AS sat_id, 'Sat_3_15' AS stk_name, 3 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 252.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-16' AS sat_id, 'Sat_3_16' AS stk_name, 3 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-17' AS sat_id, 'Sat_3_17' AS stk_name, 3 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 288.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-18' AS sat_id, 'Sat_3_18' AS stk_name, 3 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 306.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-19' AS sat_id, 'Sat_3_19' AS stk_name, 3 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 324.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-20' AS sat_id, 'Sat_3_20' AS stk_name, 3 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg,
         240.000000 AS raan_deg, 0.000000 AS argp_deg, 342.000000 AS ta_deg
) v
WHERE NOT EXISTS (
  SELECT 1 FROM public.satellites existing
  INNER JOIN sid ON existing.scenario_id = sid.id
  WHERE existing.sat_id = v.sat_id
);

COMMIT;
