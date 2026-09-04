-- 000003_seed_starlink_36x22.up.sql
-- 从 starlink_shell1_36x22.json 导入完整星座场景及卫星数据

BEGIN;

WITH s AS (
  INSERT INTO public.scenarios (
    name, epoch, start_time, end_time,
    alt_km, inc_deg, n_planes, n_sats_per_plane, sensor_config,
    created_at, updated_at
  )
  SELECT
    'Scenario5_full_36x22',
    '15 Dec 2025 00:00:00 UTCG',
    '15 Dec 2025 00:00:00',
    '16 Dec 2025 00:00:00',
    550.000000,
    53.000000,
    36,
    22,
    '{"coneHalfAngleDeg":30,"type":"SimpleConic"}'::jsonb,
    NOW(), NOW()
  WHERE NOT EXISTS (SELECT 1 FROM public.scenarios WHERE name = 'Scenario5_full_36x22')
  RETURNING id
), sid AS (
  SELECT id FROM s
  UNION ALL
  SELECT id FROM public.scenarios WHERE name = 'Scenario5_full_36x22'
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
FROM sid,
(
  SELECT 'sat-1-1' AS sat_id, 'Sat_1_1' AS stk_name, 1 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-2' AS sat_id, 'Sat_1_2' AS stk_name, 1 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-1-3' AS sat_id, 'Sat_1_3' AS stk_name, 1 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-1-4' AS sat_id, 'Sat_1_4' AS stk_name, 1 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-1-5' AS sat_id, 'Sat_1_5' AS stk_name, 1 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-1-6' AS sat_id, 'Sat_1_6' AS stk_name, 1 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-1-7' AS sat_id, 'Sat_1_7' AS stk_name, 1 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-1-8' AS sat_id, 'Sat_1_8' AS stk_name, 1 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-1-9' AS sat_id, 'Sat_1_9' AS stk_name, 1 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-1-10' AS sat_id, 'Sat_1_10' AS stk_name, 1 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-1-11' AS sat_id, 'Sat_1_11' AS stk_name, 1 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-1-12' AS sat_id, 'Sat_1_12' AS stk_name, 1 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-1-13' AS sat_id, 'Sat_1_13' AS stk_name, 1 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-1-14' AS sat_id, 'Sat_1_14' AS stk_name, 1 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-1-15' AS sat_id, 'Sat_1_15' AS stk_name, 1 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-1-16' AS sat_id, 'Sat_1_16' AS stk_name, 1 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-1-17' AS sat_id, 'Sat_1_17' AS stk_name, 1 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-1-18' AS sat_id, 'Sat_1_18' AS stk_name, 1 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-1-19' AS sat_id, 'Sat_1_19' AS stk_name, 1 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-1-20' AS sat_id, 'Sat_1_20' AS stk_name, 1 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-1-21' AS sat_id, 'Sat_1_21' AS stk_name, 1 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-1-22' AS sat_id, 'Sat_1_22' AS stk_name, 1 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 0.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-2-1' AS sat_id, 'Sat_2_1' AS stk_name, 2 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-2-2' AS sat_id, 'Sat_2_2' AS stk_name, 2 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-2-3' AS sat_id, 'Sat_2_3' AS stk_name, 2 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-2-4' AS sat_id, 'Sat_2_4' AS stk_name, 2 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-2-5' AS sat_id, 'Sat_2_5' AS stk_name, 2 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-2-6' AS sat_id, 'Sat_2_6' AS stk_name, 2 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-7' AS sat_id, 'Sat_2_7' AS stk_name, 2 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-2-8' AS sat_id, 'Sat_2_8' AS stk_name, 2 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-2-9' AS sat_id, 'Sat_2_9' AS stk_name, 2 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-2-10' AS sat_id, 'Sat_2_10' AS stk_name, 2 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-2-11' AS sat_id, 'Sat_2_11' AS stk_name, 2 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-2-12' AS sat_id, 'Sat_2_12' AS stk_name, 2 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-2-13' AS sat_id, 'Sat_2_13' AS stk_name, 2 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-2-14' AS sat_id, 'Sat_2_14' AS stk_name, 2 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-2-15' AS sat_id, 'Sat_2_15' AS stk_name, 2 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-2-16' AS sat_id, 'Sat_2_16' AS stk_name, 2 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-2-17' AS sat_id, 'Sat_2_17' AS stk_name, 2 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-2-18' AS sat_id, 'Sat_2_18' AS stk_name, 2 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-2-19' AS sat_id, 'Sat_2_19' AS stk_name, 2 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-2-20' AS sat_id, 'Sat_2_20' AS stk_name, 2 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-2-21' AS sat_id, 'Sat_2_21' AS stk_name, 2 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-2-22' AS sat_id, 'Sat_2_22' AS stk_name, 2 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 10.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-3-1' AS sat_id, 'Sat_3_1' AS stk_name, 3 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-2' AS sat_id, 'Sat_3_2' AS stk_name, 3 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-3-3' AS sat_id, 'Sat_3_3' AS stk_name, 3 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-3-4' AS sat_id, 'Sat_3_4' AS stk_name, 3 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-3-5' AS sat_id, 'Sat_3_5' AS stk_name, 3 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-3-6' AS sat_id, 'Sat_3_6' AS stk_name, 3 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-3-7' AS sat_id, 'Sat_3_7' AS stk_name, 3 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-3-8' AS sat_id, 'Sat_3_8' AS stk_name, 3 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-3-9' AS sat_id, 'Sat_3_9' AS stk_name, 3 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-3-10' AS sat_id, 'Sat_3_10' AS stk_name, 3 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-3-11' AS sat_id, 'Sat_3_11' AS stk_name, 3 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-3-12' AS sat_id, 'Sat_3_12' AS stk_name, 3 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-3-13' AS sat_id, 'Sat_3_13' AS stk_name, 3 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-3-14' AS sat_id, 'Sat_3_14' AS stk_name, 3 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-3-15' AS sat_id, 'Sat_3_15' AS stk_name, 3 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-3-16' AS sat_id, 'Sat_3_16' AS stk_name, 3 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-3-17' AS sat_id, 'Sat_3_17' AS stk_name, 3 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-3-18' AS sat_id, 'Sat_3_18' AS stk_name, 3 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-3-19' AS sat_id, 'Sat_3_19' AS stk_name, 3 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-3-20' AS sat_id, 'Sat_3_20' AS stk_name, 3 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-3-21' AS sat_id, 'Sat_3_21' AS stk_name, 3 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-3-22' AS sat_id, 'Sat_3_22' AS stk_name, 3 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 20.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-4-1' AS sat_id, 'Sat_4_1' AS stk_name, 4 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-4-2' AS sat_id, 'Sat_4_2' AS stk_name, 4 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-4-3' AS sat_id, 'Sat_4_3' AS stk_name, 4 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-4-4' AS sat_id, 'Sat_4_4' AS stk_name, 4 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-4-5' AS sat_id, 'Sat_4_5' AS stk_name, 4 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-4-6' AS sat_id, 'Sat_4_6' AS stk_name, 4 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-4-7' AS sat_id, 'Sat_4_7' AS stk_name, 4 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-4-8' AS sat_id, 'Sat_4_8' AS stk_name, 4 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-4-9' AS sat_id, 'Sat_4_9' AS stk_name, 4 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-4-10' AS sat_id, 'Sat_4_10' AS stk_name, 4 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-4-11' AS sat_id, 'Sat_4_11' AS stk_name, 4 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-4-12' AS sat_id, 'Sat_4_12' AS stk_name, 4 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-4-13' AS sat_id, 'Sat_4_13' AS stk_name, 4 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-4-14' AS sat_id, 'Sat_4_14' AS stk_name, 4 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-4-15' AS sat_id, 'Sat_4_15' AS stk_name, 4 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-4-16' AS sat_id, 'Sat_4_16' AS stk_name, 4 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-4-17' AS sat_id, 'Sat_4_17' AS stk_name, 4 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-4-18' AS sat_id, 'Sat_4_18' AS stk_name, 4 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-4-19' AS sat_id, 'Sat_4_19' AS stk_name, 4 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-4-20' AS sat_id, 'Sat_4_20' AS stk_name, 4 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-4-21' AS sat_id, 'Sat_4_21' AS stk_name, 4 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-4-22' AS sat_id, 'Sat_4_22' AS stk_name, 4 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 30.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-5-1' AS sat_id, 'Sat_5_1' AS stk_name, 5 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-5-2' AS sat_id, 'Sat_5_2' AS stk_name, 5 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-5-3' AS sat_id, 'Sat_5_3' AS stk_name, 5 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-5-4' AS sat_id, 'Sat_5_4' AS stk_name, 5 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-5-5' AS sat_id, 'Sat_5_5' AS stk_name, 5 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-5-6' AS sat_id, 'Sat_5_6' AS stk_name, 5 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-5-7' AS sat_id, 'Sat_5_7' AS stk_name, 5 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-5-8' AS sat_id, 'Sat_5_8' AS stk_name, 5 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-5-9' AS sat_id, 'Sat_5_9' AS stk_name, 5 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-5-10' AS sat_id, 'Sat_5_10' AS stk_name, 5 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-5-11' AS sat_id, 'Sat_5_11' AS stk_name, 5 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-5-12' AS sat_id, 'Sat_5_12' AS stk_name, 5 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-5-13' AS sat_id, 'Sat_5_13' AS stk_name, 5 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-5-14' AS sat_id, 'Sat_5_14' AS stk_name, 5 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-5-15' AS sat_id, 'Sat_5_15' AS stk_name, 5 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-5-16' AS sat_id, 'Sat_5_16' AS stk_name, 5 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-5-17' AS sat_id, 'Sat_5_17' AS stk_name, 5 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-5-18' AS sat_id, 'Sat_5_18' AS stk_name, 5 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-5-19' AS sat_id, 'Sat_5_19' AS stk_name, 5 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-5-20' AS sat_id, 'Sat_5_20' AS stk_name, 5 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-5-21' AS sat_id, 'Sat_5_21' AS stk_name, 5 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-5-22' AS sat_id, 'Sat_5_22' AS stk_name, 5 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 40.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-6-1' AS sat_id, 'Sat_6_1' AS stk_name, 6 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-6-2' AS sat_id, 'Sat_6_2' AS stk_name, 6 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-6-3' AS sat_id, 'Sat_6_3' AS stk_name, 6 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-6-4' AS sat_id, 'Sat_6_4' AS stk_name, 6 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-6-5' AS sat_id, 'Sat_6_5' AS stk_name, 6 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-6-6' AS sat_id, 'Sat_6_6' AS stk_name, 6 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-6-7' AS sat_id, 'Sat_6_7' AS stk_name, 6 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-6-8' AS sat_id, 'Sat_6_8' AS stk_name, 6 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-6-9' AS sat_id, 'Sat_6_9' AS stk_name, 6 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-6-10' AS sat_id, 'Sat_6_10' AS stk_name, 6 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-6-11' AS sat_id, 'Sat_6_11' AS stk_name, 6 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-6-12' AS sat_id, 'Sat_6_12' AS stk_name, 6 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-6-13' AS sat_id, 'Sat_6_13' AS stk_name, 6 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-6-14' AS sat_id, 'Sat_6_14' AS stk_name, 6 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-6-15' AS sat_id, 'Sat_6_15' AS stk_name, 6 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-6-16' AS sat_id, 'Sat_6_16' AS stk_name, 6 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-6-17' AS sat_id, 'Sat_6_17' AS stk_name, 6 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-6-18' AS sat_id, 'Sat_6_18' AS stk_name, 6 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-6-19' AS sat_id, 'Sat_6_19' AS stk_name, 6 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-6-20' AS sat_id, 'Sat_6_20' AS stk_name, 6 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-6-21' AS sat_id, 'Sat_6_21' AS stk_name, 6 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-6-22' AS sat_id, 'Sat_6_22' AS stk_name, 6 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 50.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-7-1' AS sat_id, 'Sat_7_1' AS stk_name, 7 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-7-2' AS sat_id, 'Sat_7_2' AS stk_name, 7 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-7-3' AS sat_id, 'Sat_7_3' AS stk_name, 7 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-7-4' AS sat_id, 'Sat_7_4' AS stk_name, 7 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-7-5' AS sat_id, 'Sat_7_5' AS stk_name, 7 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-7-6' AS sat_id, 'Sat_7_6' AS stk_name, 7 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-7-7' AS sat_id, 'Sat_7_7' AS stk_name, 7 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-7-8' AS sat_id, 'Sat_7_8' AS stk_name, 7 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-7-9' AS sat_id, 'Sat_7_9' AS stk_name, 7 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-7-10' AS sat_id, 'Sat_7_10' AS stk_name, 7 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-7-11' AS sat_id, 'Sat_7_11' AS stk_name, 7 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-7-12' AS sat_id, 'Sat_7_12' AS stk_name, 7 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-7-13' AS sat_id, 'Sat_7_13' AS stk_name, 7 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-7-14' AS sat_id, 'Sat_7_14' AS stk_name, 7 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-7-15' AS sat_id, 'Sat_7_15' AS stk_name, 7 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-7-16' AS sat_id, 'Sat_7_16' AS stk_name, 7 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-7-17' AS sat_id, 'Sat_7_17' AS stk_name, 7 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-7-18' AS sat_id, 'Sat_7_18' AS stk_name, 7 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-7-19' AS sat_id, 'Sat_7_19' AS stk_name, 7 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-7-20' AS sat_id, 'Sat_7_20' AS stk_name, 7 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-7-21' AS sat_id, 'Sat_7_21' AS stk_name, 7 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-7-22' AS sat_id, 'Sat_7_22' AS stk_name, 7 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 60.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-8-1' AS sat_id, 'Sat_8_1' AS stk_name, 8 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-8-2' AS sat_id, 'Sat_8_2' AS stk_name, 8 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-8-3' AS sat_id, 'Sat_8_3' AS stk_name, 8 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-8-4' AS sat_id, 'Sat_8_4' AS stk_name, 8 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-8-5' AS sat_id, 'Sat_8_5' AS stk_name, 8 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-8-6' AS sat_id, 'Sat_8_6' AS stk_name, 8 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-8-7' AS sat_id, 'Sat_8_7' AS stk_name, 8 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-8-8' AS sat_id, 'Sat_8_8' AS stk_name, 8 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-8-9' AS sat_id, 'Sat_8_9' AS stk_name, 8 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-8-10' AS sat_id, 'Sat_8_10' AS stk_name, 8 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-8-11' AS sat_id, 'Sat_8_11' AS stk_name, 8 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-8-12' AS sat_id, 'Sat_8_12' AS stk_name, 8 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-8-13' AS sat_id, 'Sat_8_13' AS stk_name, 8 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-8-14' AS sat_id, 'Sat_8_14' AS stk_name, 8 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-8-15' AS sat_id, 'Sat_8_15' AS stk_name, 8 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-8-16' AS sat_id, 'Sat_8_16' AS stk_name, 8 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-8-17' AS sat_id, 'Sat_8_17' AS stk_name, 8 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-8-18' AS sat_id, 'Sat_8_18' AS stk_name, 8 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-8-19' AS sat_id, 'Sat_8_19' AS stk_name, 8 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-8-20' AS sat_id, 'Sat_8_20' AS stk_name, 8 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-8-21' AS sat_id, 'Sat_8_21' AS stk_name, 8 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-8-22' AS sat_id, 'Sat_8_22' AS stk_name, 8 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 70.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-9-1' AS sat_id, 'Sat_9_1' AS stk_name, 9 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-9-2' AS sat_id, 'Sat_9_2' AS stk_name, 9 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-9-3' AS sat_id, 'Sat_9_3' AS stk_name, 9 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-9-4' AS sat_id, 'Sat_9_4' AS stk_name, 9 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-9-5' AS sat_id, 'Sat_9_5' AS stk_name, 9 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-9-6' AS sat_id, 'Sat_9_6' AS stk_name, 9 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-9-7' AS sat_id, 'Sat_9_7' AS stk_name, 9 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-9-8' AS sat_id, 'Sat_9_8' AS stk_name, 9 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-9-9' AS sat_id, 'Sat_9_9' AS stk_name, 9 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-9-10' AS sat_id, 'Sat_9_10' AS stk_name, 9 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-9-11' AS sat_id, 'Sat_9_11' AS stk_name, 9 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-9-12' AS sat_id, 'Sat_9_12' AS stk_name, 9 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-9-13' AS sat_id, 'Sat_9_13' AS stk_name, 9 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-9-14' AS sat_id, 'Sat_9_14' AS stk_name, 9 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-9-15' AS sat_id, 'Sat_9_15' AS stk_name, 9 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-9-16' AS sat_id, 'Sat_9_16' AS stk_name, 9 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-9-17' AS sat_id, 'Sat_9_17' AS stk_name, 9 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-9-18' AS sat_id, 'Sat_9_18' AS stk_name, 9 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-9-19' AS sat_id, 'Sat_9_19' AS stk_name, 9 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-9-20' AS sat_id, 'Sat_9_20' AS stk_name, 9 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-9-21' AS sat_id, 'Sat_9_21' AS stk_name, 9 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-9-22' AS sat_id, 'Sat_9_22' AS stk_name, 9 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 80.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-10-1' AS sat_id, 'Sat_10_1' AS stk_name, 10 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-10-2' AS sat_id, 'Sat_10_2' AS stk_name, 10 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-10-3' AS sat_id, 'Sat_10_3' AS stk_name, 10 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-10-4' AS sat_id, 'Sat_10_4' AS stk_name, 10 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-10-5' AS sat_id, 'Sat_10_5' AS stk_name, 10 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-10-6' AS sat_id, 'Sat_10_6' AS stk_name, 10 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-10-7' AS sat_id, 'Sat_10_7' AS stk_name, 10 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-10-8' AS sat_id, 'Sat_10_8' AS stk_name, 10 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-10-9' AS sat_id, 'Sat_10_9' AS stk_name, 10 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-10-10' AS sat_id, 'Sat_10_10' AS stk_name, 10 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-10-11' AS sat_id, 'Sat_10_11' AS stk_name, 10 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-10-12' AS sat_id, 'Sat_10_12' AS stk_name, 10 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-10-13' AS sat_id, 'Sat_10_13' AS stk_name, 10 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-10-14' AS sat_id, 'Sat_10_14' AS stk_name, 10 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-10-15' AS sat_id, 'Sat_10_15' AS stk_name, 10 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-10-16' AS sat_id, 'Sat_10_16' AS stk_name, 10 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-10-17' AS sat_id, 'Sat_10_17' AS stk_name, 10 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-10-18' AS sat_id, 'Sat_10_18' AS stk_name, 10 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-10-19' AS sat_id, 'Sat_10_19' AS stk_name, 10 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-10-20' AS sat_id, 'Sat_10_20' AS stk_name, 10 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-10-21' AS sat_id, 'Sat_10_21' AS stk_name, 10 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-10-22' AS sat_id, 'Sat_10_22' AS stk_name, 10 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 90.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-11-1' AS sat_id, 'Sat_11_1' AS stk_name, 11 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-11-2' AS sat_id, 'Sat_11_2' AS stk_name, 11 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-11-3' AS sat_id, 'Sat_11_3' AS stk_name, 11 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-11-4' AS sat_id, 'Sat_11_4' AS stk_name, 11 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-11-5' AS sat_id, 'Sat_11_5' AS stk_name, 11 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-11-6' AS sat_id, 'Sat_11_6' AS stk_name, 11 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-11-7' AS sat_id, 'Sat_11_7' AS stk_name, 11 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-11-8' AS sat_id, 'Sat_11_8' AS stk_name, 11 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-11-9' AS sat_id, 'Sat_11_9' AS stk_name, 11 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-11-10' AS sat_id, 'Sat_11_10' AS stk_name, 11 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-11-11' AS sat_id, 'Sat_11_11' AS stk_name, 11 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-11-12' AS sat_id, 'Sat_11_12' AS stk_name, 11 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-11-13' AS sat_id, 'Sat_11_13' AS stk_name, 11 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-11-14' AS sat_id, 'Sat_11_14' AS stk_name, 11 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-11-15' AS sat_id, 'Sat_11_15' AS stk_name, 11 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-11-16' AS sat_id, 'Sat_11_16' AS stk_name, 11 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-11-17' AS sat_id, 'Sat_11_17' AS stk_name, 11 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-11-18' AS sat_id, 'Sat_11_18' AS stk_name, 11 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-11-19' AS sat_id, 'Sat_11_19' AS stk_name, 11 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-11-20' AS sat_id, 'Sat_11_20' AS stk_name, 11 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-11-21' AS sat_id, 'Sat_11_21' AS stk_name, 11 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-11-22' AS sat_id, 'Sat_11_22' AS stk_name, 11 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 100.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-12-1' AS sat_id, 'Sat_12_1' AS stk_name, 12 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-12-2' AS sat_id, 'Sat_12_2' AS stk_name, 12 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-12-3' AS sat_id, 'Sat_12_3' AS stk_name, 12 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-12-4' AS sat_id, 'Sat_12_4' AS stk_name, 12 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-12-5' AS sat_id, 'Sat_12_5' AS stk_name, 12 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-12-6' AS sat_id, 'Sat_12_6' AS stk_name, 12 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-12-7' AS sat_id, 'Sat_12_7' AS stk_name, 12 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-12-8' AS sat_id, 'Sat_12_8' AS stk_name, 12 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-12-9' AS sat_id, 'Sat_12_9' AS stk_name, 12 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-12-10' AS sat_id, 'Sat_12_10' AS stk_name, 12 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-12-11' AS sat_id, 'Sat_12_11' AS stk_name, 12 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-12-12' AS sat_id, 'Sat_12_12' AS stk_name, 12 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-12-13' AS sat_id, 'Sat_12_13' AS stk_name, 12 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-12-14' AS sat_id, 'Sat_12_14' AS stk_name, 12 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-12-15' AS sat_id, 'Sat_12_15' AS stk_name, 12 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-12-16' AS sat_id, 'Sat_12_16' AS stk_name, 12 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-12-17' AS sat_id, 'Sat_12_17' AS stk_name, 12 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-12-18' AS sat_id, 'Sat_12_18' AS stk_name, 12 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-12-19' AS sat_id, 'Sat_12_19' AS stk_name, 12 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-12-20' AS sat_id, 'Sat_12_20' AS stk_name, 12 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-12-21' AS sat_id, 'Sat_12_21' AS stk_name, 12 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-12-22' AS sat_id, 'Sat_12_22' AS stk_name, 12 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 110.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-13-1' AS sat_id, 'Sat_13_1' AS stk_name, 13 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-13-2' AS sat_id, 'Sat_13_2' AS stk_name, 13 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-13-3' AS sat_id, 'Sat_13_3' AS stk_name, 13 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-13-4' AS sat_id, 'Sat_13_4' AS stk_name, 13 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-13-5' AS sat_id, 'Sat_13_5' AS stk_name, 13 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-13-6' AS sat_id, 'Sat_13_6' AS stk_name, 13 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-13-7' AS sat_id, 'Sat_13_7' AS stk_name, 13 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-13-8' AS sat_id, 'Sat_13_8' AS stk_name, 13 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-13-9' AS sat_id, 'Sat_13_9' AS stk_name, 13 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-13-10' AS sat_id, 'Sat_13_10' AS stk_name, 13 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-13-11' AS sat_id, 'Sat_13_11' AS stk_name, 13 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-13-12' AS sat_id, 'Sat_13_12' AS stk_name, 13 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-13-13' AS sat_id, 'Sat_13_13' AS stk_name, 13 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-13-14' AS sat_id, 'Sat_13_14' AS stk_name, 13 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-13-15' AS sat_id, 'Sat_13_15' AS stk_name, 13 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-13-16' AS sat_id, 'Sat_13_16' AS stk_name, 13 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-13-17' AS sat_id, 'Sat_13_17' AS stk_name, 13 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-13-18' AS sat_id, 'Sat_13_18' AS stk_name, 13 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-13-19' AS sat_id, 'Sat_13_19' AS stk_name, 13 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-13-20' AS sat_id, 'Sat_13_20' AS stk_name, 13 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-13-21' AS sat_id, 'Sat_13_21' AS stk_name, 13 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-13-22' AS sat_id, 'Sat_13_22' AS stk_name, 13 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 120.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-14-1' AS sat_id, 'Sat_14_1' AS stk_name, 14 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-14-2' AS sat_id, 'Sat_14_2' AS stk_name, 14 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-14-3' AS sat_id, 'Sat_14_3' AS stk_name, 14 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-14-4' AS sat_id, 'Sat_14_4' AS stk_name, 14 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-14-5' AS sat_id, 'Sat_14_5' AS stk_name, 14 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-14-6' AS sat_id, 'Sat_14_6' AS stk_name, 14 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-14-7' AS sat_id, 'Sat_14_7' AS stk_name, 14 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-14-8' AS sat_id, 'Sat_14_8' AS stk_name, 14 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-14-9' AS sat_id, 'Sat_14_9' AS stk_name, 14 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-14-10' AS sat_id, 'Sat_14_10' AS stk_name, 14 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-14-11' AS sat_id, 'Sat_14_11' AS stk_name, 14 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-14-12' AS sat_id, 'Sat_14_12' AS stk_name, 14 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-14-13' AS sat_id, 'Sat_14_13' AS stk_name, 14 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-14-14' AS sat_id, 'Sat_14_14' AS stk_name, 14 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-14-15' AS sat_id, 'Sat_14_15' AS stk_name, 14 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-14-16' AS sat_id, 'Sat_14_16' AS stk_name, 14 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-14-17' AS sat_id, 'Sat_14_17' AS stk_name, 14 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-14-18' AS sat_id, 'Sat_14_18' AS stk_name, 14 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-14-19' AS sat_id, 'Sat_14_19' AS stk_name, 14 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-14-20' AS sat_id, 'Sat_14_20' AS stk_name, 14 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-14-21' AS sat_id, 'Sat_14_21' AS stk_name, 14 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-14-22' AS sat_id, 'Sat_14_22' AS stk_name, 14 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 130.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-15-1' AS sat_id, 'Sat_15_1' AS stk_name, 15 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-15-2' AS sat_id, 'Sat_15_2' AS stk_name, 15 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-15-3' AS sat_id, 'Sat_15_3' AS stk_name, 15 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-15-4' AS sat_id, 'Sat_15_4' AS stk_name, 15 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-15-5' AS sat_id, 'Sat_15_5' AS stk_name, 15 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-15-6' AS sat_id, 'Sat_15_6' AS stk_name, 15 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-15-7' AS sat_id, 'Sat_15_7' AS stk_name, 15 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-15-8' AS sat_id, 'Sat_15_8' AS stk_name, 15 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-15-9' AS sat_id, 'Sat_15_9' AS stk_name, 15 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-15-10' AS sat_id, 'Sat_15_10' AS stk_name, 15 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-15-11' AS sat_id, 'Sat_15_11' AS stk_name, 15 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-15-12' AS sat_id, 'Sat_15_12' AS stk_name, 15 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-15-13' AS sat_id, 'Sat_15_13' AS stk_name, 15 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-15-14' AS sat_id, 'Sat_15_14' AS stk_name, 15 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-15-15' AS sat_id, 'Sat_15_15' AS stk_name, 15 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-15-16' AS sat_id, 'Sat_15_16' AS stk_name, 15 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-15-17' AS sat_id, 'Sat_15_17' AS stk_name, 15 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-15-18' AS sat_id, 'Sat_15_18' AS stk_name, 15 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-15-19' AS sat_id, 'Sat_15_19' AS stk_name, 15 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-15-20' AS sat_id, 'Sat_15_20' AS stk_name, 15 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-15-21' AS sat_id, 'Sat_15_21' AS stk_name, 15 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-15-22' AS sat_id, 'Sat_15_22' AS stk_name, 15 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 140.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-16-1' AS sat_id, 'Sat_16_1' AS stk_name, 16 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-16-2' AS sat_id, 'Sat_16_2' AS stk_name, 16 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-16-3' AS sat_id, 'Sat_16_3' AS stk_name, 16 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-16-4' AS sat_id, 'Sat_16_4' AS stk_name, 16 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-16-5' AS sat_id, 'Sat_16_5' AS stk_name, 16 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-16-6' AS sat_id, 'Sat_16_6' AS stk_name, 16 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-16-7' AS sat_id, 'Sat_16_7' AS stk_name, 16 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-16-8' AS sat_id, 'Sat_16_8' AS stk_name, 16 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-16-9' AS sat_id, 'Sat_16_9' AS stk_name, 16 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-16-10' AS sat_id, 'Sat_16_10' AS stk_name, 16 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-16-11' AS sat_id, 'Sat_16_11' AS stk_name, 16 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-16-12' AS sat_id, 'Sat_16_12' AS stk_name, 16 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-16-13' AS sat_id, 'Sat_16_13' AS stk_name, 16 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-16-14' AS sat_id, 'Sat_16_14' AS stk_name, 16 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-16-15' AS sat_id, 'Sat_16_15' AS stk_name, 16 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-16-16' AS sat_id, 'Sat_16_16' AS stk_name, 16 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-16-17' AS sat_id, 'Sat_16_17' AS stk_name, 16 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-16-18' AS sat_id, 'Sat_16_18' AS stk_name, 16 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-16-19' AS sat_id, 'Sat_16_19' AS stk_name, 16 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-16-20' AS sat_id, 'Sat_16_20' AS stk_name, 16 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-16-21' AS sat_id, 'Sat_16_21' AS stk_name, 16 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-16-22' AS sat_id, 'Sat_16_22' AS stk_name, 16 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 150.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-17-1' AS sat_id, 'Sat_17_1' AS stk_name, 17 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-17-2' AS sat_id, 'Sat_17_2' AS stk_name, 17 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-17-3' AS sat_id, 'Sat_17_3' AS stk_name, 17 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-17-4' AS sat_id, 'Sat_17_4' AS stk_name, 17 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-17-5' AS sat_id, 'Sat_17_5' AS stk_name, 17 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-17-6' AS sat_id, 'Sat_17_6' AS stk_name, 17 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-17-7' AS sat_id, 'Sat_17_7' AS stk_name, 17 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-17-8' AS sat_id, 'Sat_17_8' AS stk_name, 17 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-17-9' AS sat_id, 'Sat_17_9' AS stk_name, 17 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-17-10' AS sat_id, 'Sat_17_10' AS stk_name, 17 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-17-11' AS sat_id, 'Sat_17_11' AS stk_name, 17 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-17-12' AS sat_id, 'Sat_17_12' AS stk_name, 17 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-17-13' AS sat_id, 'Sat_17_13' AS stk_name, 17 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-17-14' AS sat_id, 'Sat_17_14' AS stk_name, 17 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-17-15' AS sat_id, 'Sat_17_15' AS stk_name, 17 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-17-16' AS sat_id, 'Sat_17_16' AS stk_name, 17 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-17-17' AS sat_id, 'Sat_17_17' AS stk_name, 17 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-17-18' AS sat_id, 'Sat_17_18' AS stk_name, 17 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-17-19' AS sat_id, 'Sat_17_19' AS stk_name, 17 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-17-20' AS sat_id, 'Sat_17_20' AS stk_name, 17 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-17-21' AS sat_id, 'Sat_17_21' AS stk_name, 17 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-17-22' AS sat_id, 'Sat_17_22' AS stk_name, 17 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 160.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-18-1' AS sat_id, 'Sat_18_1' AS stk_name, 18 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-18-2' AS sat_id, 'Sat_18_2' AS stk_name, 18 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-18-3' AS sat_id, 'Sat_18_3' AS stk_name, 18 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-18-4' AS sat_id, 'Sat_18_4' AS stk_name, 18 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-18-5' AS sat_id, 'Sat_18_5' AS stk_name, 18 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-18-6' AS sat_id, 'Sat_18_6' AS stk_name, 18 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-18-7' AS sat_id, 'Sat_18_7' AS stk_name, 18 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-18-8' AS sat_id, 'Sat_18_8' AS stk_name, 18 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-18-9' AS sat_id, 'Sat_18_9' AS stk_name, 18 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-18-10' AS sat_id, 'Sat_18_10' AS stk_name, 18 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-18-11' AS sat_id, 'Sat_18_11' AS stk_name, 18 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-18-12' AS sat_id, 'Sat_18_12' AS stk_name, 18 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-18-13' AS sat_id, 'Sat_18_13' AS stk_name, 18 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-18-14' AS sat_id, 'Sat_18_14' AS stk_name, 18 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-18-15' AS sat_id, 'Sat_18_15' AS stk_name, 18 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-18-16' AS sat_id, 'Sat_18_16' AS stk_name, 18 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-18-17' AS sat_id, 'Sat_18_17' AS stk_name, 18 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-18-18' AS sat_id, 'Sat_18_18' AS stk_name, 18 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-18-19' AS sat_id, 'Sat_18_19' AS stk_name, 18 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-18-20' AS sat_id, 'Sat_18_20' AS stk_name, 18 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-18-21' AS sat_id, 'Sat_18_21' AS stk_name, 18 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-18-22' AS sat_id, 'Sat_18_22' AS stk_name, 18 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 170.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-19-1' AS sat_id, 'Sat_19_1' AS stk_name, 19 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-19-2' AS sat_id, 'Sat_19_2' AS stk_name, 19 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-19-3' AS sat_id, 'Sat_19_3' AS stk_name, 19 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-19-4' AS sat_id, 'Sat_19_4' AS stk_name, 19 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-19-5' AS sat_id, 'Sat_19_5' AS stk_name, 19 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-19-6' AS sat_id, 'Sat_19_6' AS stk_name, 19 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-19-7' AS sat_id, 'Sat_19_7' AS stk_name, 19 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-19-8' AS sat_id, 'Sat_19_8' AS stk_name, 19 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-19-9' AS sat_id, 'Sat_19_9' AS stk_name, 19 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-19-10' AS sat_id, 'Sat_19_10' AS stk_name, 19 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-19-11' AS sat_id, 'Sat_19_11' AS stk_name, 19 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-19-12' AS sat_id, 'Sat_19_12' AS stk_name, 19 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-19-13' AS sat_id, 'Sat_19_13' AS stk_name, 19 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-19-14' AS sat_id, 'Sat_19_14' AS stk_name, 19 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-19-15' AS sat_id, 'Sat_19_15' AS stk_name, 19 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-19-16' AS sat_id, 'Sat_19_16' AS stk_name, 19 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-19-17' AS sat_id, 'Sat_19_17' AS stk_name, 19 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-19-18' AS sat_id, 'Sat_19_18' AS stk_name, 19 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-19-19' AS sat_id, 'Sat_19_19' AS stk_name, 19 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-19-20' AS sat_id, 'Sat_19_20' AS stk_name, 19 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-19-21' AS sat_id, 'Sat_19_21' AS stk_name, 19 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-19-22' AS sat_id, 'Sat_19_22' AS stk_name, 19 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 180.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-20-1' AS sat_id, 'Sat_20_1' AS stk_name, 20 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-20-2' AS sat_id, 'Sat_20_2' AS stk_name, 20 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-20-3' AS sat_id, 'Sat_20_3' AS stk_name, 20 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-20-4' AS sat_id, 'Sat_20_4' AS stk_name, 20 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-20-5' AS sat_id, 'Sat_20_5' AS stk_name, 20 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-20-6' AS sat_id, 'Sat_20_6' AS stk_name, 20 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-20-7' AS sat_id, 'Sat_20_7' AS stk_name, 20 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-20-8' AS sat_id, 'Sat_20_8' AS stk_name, 20 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-20-9' AS sat_id, 'Sat_20_9' AS stk_name, 20 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-20-10' AS sat_id, 'Sat_20_10' AS stk_name, 20 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-20-11' AS sat_id, 'Sat_20_11' AS stk_name, 20 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-20-12' AS sat_id, 'Sat_20_12' AS stk_name, 20 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-20-13' AS sat_id, 'Sat_20_13' AS stk_name, 20 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-20-14' AS sat_id, 'Sat_20_14' AS stk_name, 20 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-20-15' AS sat_id, 'Sat_20_15' AS stk_name, 20 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-20-16' AS sat_id, 'Sat_20_16' AS stk_name, 20 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-20-17' AS sat_id, 'Sat_20_17' AS stk_name, 20 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-20-18' AS sat_id, 'Sat_20_18' AS stk_name, 20 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-20-19' AS sat_id, 'Sat_20_19' AS stk_name, 20 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-20-20' AS sat_id, 'Sat_20_20' AS stk_name, 20 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-20-21' AS sat_id, 'Sat_20_21' AS stk_name, 20 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-20-22' AS sat_id, 'Sat_20_22' AS stk_name, 20 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 190.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-21-1' AS sat_id, 'Sat_21_1' AS stk_name, 21 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-21-2' AS sat_id, 'Sat_21_2' AS stk_name, 21 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-21-3' AS sat_id, 'Sat_21_3' AS stk_name, 21 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-21-4' AS sat_id, 'Sat_21_4' AS stk_name, 21 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-21-5' AS sat_id, 'Sat_21_5' AS stk_name, 21 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-21-6' AS sat_id, 'Sat_21_6' AS stk_name, 21 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-21-7' AS sat_id, 'Sat_21_7' AS stk_name, 21 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-21-8' AS sat_id, 'Sat_21_8' AS stk_name, 21 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-21-9' AS sat_id, 'Sat_21_9' AS stk_name, 21 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-21-10' AS sat_id, 'Sat_21_10' AS stk_name, 21 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-21-11' AS sat_id, 'Sat_21_11' AS stk_name, 21 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-21-12' AS sat_id, 'Sat_21_12' AS stk_name, 21 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-21-13' AS sat_id, 'Sat_21_13' AS stk_name, 21 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-21-14' AS sat_id, 'Sat_21_14' AS stk_name, 21 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-21-15' AS sat_id, 'Sat_21_15' AS stk_name, 21 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-21-16' AS sat_id, 'Sat_21_16' AS stk_name, 21 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-21-17' AS sat_id, 'Sat_21_17' AS stk_name, 21 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-21-18' AS sat_id, 'Sat_21_18' AS stk_name, 21 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-21-19' AS sat_id, 'Sat_21_19' AS stk_name, 21 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-21-20' AS sat_id, 'Sat_21_20' AS stk_name, 21 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-21-21' AS sat_id, 'Sat_21_21' AS stk_name, 21 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-21-22' AS sat_id, 'Sat_21_22' AS stk_name, 21 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 200.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-22-1' AS sat_id, 'Sat_22_1' AS stk_name, 22 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-22-2' AS sat_id, 'Sat_22_2' AS stk_name, 22 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-22-3' AS sat_id, 'Sat_22_3' AS stk_name, 22 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-22-4' AS sat_id, 'Sat_22_4' AS stk_name, 22 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-22-5' AS sat_id, 'Sat_22_5' AS stk_name, 22 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-22-6' AS sat_id, 'Sat_22_6' AS stk_name, 22 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-22-7' AS sat_id, 'Sat_22_7' AS stk_name, 22 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-22-8' AS sat_id, 'Sat_22_8' AS stk_name, 22 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-22-9' AS sat_id, 'Sat_22_9' AS stk_name, 22 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-22-10' AS sat_id, 'Sat_22_10' AS stk_name, 22 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-22-11' AS sat_id, 'Sat_22_11' AS stk_name, 22 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-22-12' AS sat_id, 'Sat_22_12' AS stk_name, 22 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-22-13' AS sat_id, 'Sat_22_13' AS stk_name, 22 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-22-14' AS sat_id, 'Sat_22_14' AS stk_name, 22 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-22-15' AS sat_id, 'Sat_22_15' AS stk_name, 22 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-22-16' AS sat_id, 'Sat_22_16' AS stk_name, 22 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-22-17' AS sat_id, 'Sat_22_17' AS stk_name, 22 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-22-18' AS sat_id, 'Sat_22_18' AS stk_name, 22 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-22-19' AS sat_id, 'Sat_22_19' AS stk_name, 22 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-22-20' AS sat_id, 'Sat_22_20' AS stk_name, 22 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-22-21' AS sat_id, 'Sat_22_21' AS stk_name, 22 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-22-22' AS sat_id, 'Sat_22_22' AS stk_name, 22 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 210.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-23-1' AS sat_id, 'Sat_23_1' AS stk_name, 23 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-23-2' AS sat_id, 'Sat_23_2' AS stk_name, 23 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-23-3' AS sat_id, 'Sat_23_3' AS stk_name, 23 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-23-4' AS sat_id, 'Sat_23_4' AS stk_name, 23 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-23-5' AS sat_id, 'Sat_23_5' AS stk_name, 23 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-23-6' AS sat_id, 'Sat_23_6' AS stk_name, 23 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-23-7' AS sat_id, 'Sat_23_7' AS stk_name, 23 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-23-8' AS sat_id, 'Sat_23_8' AS stk_name, 23 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-23-9' AS sat_id, 'Sat_23_9' AS stk_name, 23 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-23-10' AS sat_id, 'Sat_23_10' AS stk_name, 23 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-23-11' AS sat_id, 'Sat_23_11' AS stk_name, 23 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-23-12' AS sat_id, 'Sat_23_12' AS stk_name, 23 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-23-13' AS sat_id, 'Sat_23_13' AS stk_name, 23 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-23-14' AS sat_id, 'Sat_23_14' AS stk_name, 23 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-23-15' AS sat_id, 'Sat_23_15' AS stk_name, 23 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-23-16' AS sat_id, 'Sat_23_16' AS stk_name, 23 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-23-17' AS sat_id, 'Sat_23_17' AS stk_name, 23 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-23-18' AS sat_id, 'Sat_23_18' AS stk_name, 23 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-23-19' AS sat_id, 'Sat_23_19' AS stk_name, 23 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-23-20' AS sat_id, 'Sat_23_20' AS stk_name, 23 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-23-21' AS sat_id, 'Sat_23_21' AS stk_name, 23 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-23-22' AS sat_id, 'Sat_23_22' AS stk_name, 23 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 220.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-24-1' AS sat_id, 'Sat_24_1' AS stk_name, 24 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-24-2' AS sat_id, 'Sat_24_2' AS stk_name, 24 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-24-3' AS sat_id, 'Sat_24_3' AS stk_name, 24 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-24-4' AS sat_id, 'Sat_24_4' AS stk_name, 24 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-24-5' AS sat_id, 'Sat_24_5' AS stk_name, 24 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-24-6' AS sat_id, 'Sat_24_6' AS stk_name, 24 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-24-7' AS sat_id, 'Sat_24_7' AS stk_name, 24 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-24-8' AS sat_id, 'Sat_24_8' AS stk_name, 24 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-24-9' AS sat_id, 'Sat_24_9' AS stk_name, 24 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-24-10' AS sat_id, 'Sat_24_10' AS stk_name, 24 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-24-11' AS sat_id, 'Sat_24_11' AS stk_name, 24 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-24-12' AS sat_id, 'Sat_24_12' AS stk_name, 24 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-24-13' AS sat_id, 'Sat_24_13' AS stk_name, 24 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-24-14' AS sat_id, 'Sat_24_14' AS stk_name, 24 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-24-15' AS sat_id, 'Sat_24_15' AS stk_name, 24 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-24-16' AS sat_id, 'Sat_24_16' AS stk_name, 24 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-24-17' AS sat_id, 'Sat_24_17' AS stk_name, 24 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-24-18' AS sat_id, 'Sat_24_18' AS stk_name, 24 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-24-19' AS sat_id, 'Sat_24_19' AS stk_name, 24 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-24-20' AS sat_id, 'Sat_24_20' AS stk_name, 24 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-24-21' AS sat_id, 'Sat_24_21' AS stk_name, 24 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-24-22' AS sat_id, 'Sat_24_22' AS stk_name, 24 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 230.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-25-1' AS sat_id, 'Sat_25_1' AS stk_name, 25 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-25-2' AS sat_id, 'Sat_25_2' AS stk_name, 25 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-25-3' AS sat_id, 'Sat_25_3' AS stk_name, 25 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-25-4' AS sat_id, 'Sat_25_4' AS stk_name, 25 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-25-5' AS sat_id, 'Sat_25_5' AS stk_name, 25 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-25-6' AS sat_id, 'Sat_25_6' AS stk_name, 25 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-25-7' AS sat_id, 'Sat_25_7' AS stk_name, 25 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-25-8' AS sat_id, 'Sat_25_8' AS stk_name, 25 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-25-9' AS sat_id, 'Sat_25_9' AS stk_name, 25 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-25-10' AS sat_id, 'Sat_25_10' AS stk_name, 25 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-25-11' AS sat_id, 'Sat_25_11' AS stk_name, 25 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-25-12' AS sat_id, 'Sat_25_12' AS stk_name, 25 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-25-13' AS sat_id, 'Sat_25_13' AS stk_name, 25 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-25-14' AS sat_id, 'Sat_25_14' AS stk_name, 25 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-25-15' AS sat_id, 'Sat_25_15' AS stk_name, 25 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-25-16' AS sat_id, 'Sat_25_16' AS stk_name, 25 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-25-17' AS sat_id, 'Sat_25_17' AS stk_name, 25 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-25-18' AS sat_id, 'Sat_25_18' AS stk_name, 25 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-25-19' AS sat_id, 'Sat_25_19' AS stk_name, 25 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-25-20' AS sat_id, 'Sat_25_20' AS stk_name, 25 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-25-21' AS sat_id, 'Sat_25_21' AS stk_name, 25 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-25-22' AS sat_id, 'Sat_25_22' AS stk_name, 25 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 240.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-26-1' AS sat_id, 'Sat_26_1' AS stk_name, 26 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-26-2' AS sat_id, 'Sat_26_2' AS stk_name, 26 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-26-3' AS sat_id, 'Sat_26_3' AS stk_name, 26 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-26-4' AS sat_id, 'Sat_26_4' AS stk_name, 26 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-26-5' AS sat_id, 'Sat_26_5' AS stk_name, 26 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-26-6' AS sat_id, 'Sat_26_6' AS stk_name, 26 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-26-7' AS sat_id, 'Sat_26_7' AS stk_name, 26 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-26-8' AS sat_id, 'Sat_26_8' AS stk_name, 26 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-26-9' AS sat_id, 'Sat_26_9' AS stk_name, 26 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-26-10' AS sat_id, 'Sat_26_10' AS stk_name, 26 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-26-11' AS sat_id, 'Sat_26_11' AS stk_name, 26 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-26-12' AS sat_id, 'Sat_26_12' AS stk_name, 26 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-26-13' AS sat_id, 'Sat_26_13' AS stk_name, 26 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-26-14' AS sat_id, 'Sat_26_14' AS stk_name, 26 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-26-15' AS sat_id, 'Sat_26_15' AS stk_name, 26 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-26-16' AS sat_id, 'Sat_26_16' AS stk_name, 26 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-26-17' AS sat_id, 'Sat_26_17' AS stk_name, 26 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-26-18' AS sat_id, 'Sat_26_18' AS stk_name, 26 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-26-19' AS sat_id, 'Sat_26_19' AS stk_name, 26 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-26-20' AS sat_id, 'Sat_26_20' AS stk_name, 26 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-26-21' AS sat_id, 'Sat_26_21' AS stk_name, 26 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-26-22' AS sat_id, 'Sat_26_22' AS stk_name, 26 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 250.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-27-1' AS sat_id, 'Sat_27_1' AS stk_name, 27 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-27-2' AS sat_id, 'Sat_27_2' AS stk_name, 27 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-27-3' AS sat_id, 'Sat_27_3' AS stk_name, 27 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-27-4' AS sat_id, 'Sat_27_4' AS stk_name, 27 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-27-5' AS sat_id, 'Sat_27_5' AS stk_name, 27 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-27-6' AS sat_id, 'Sat_27_6' AS stk_name, 27 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-27-7' AS sat_id, 'Sat_27_7' AS stk_name, 27 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-27-8' AS sat_id, 'Sat_27_8' AS stk_name, 27 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-27-9' AS sat_id, 'Sat_27_9' AS stk_name, 27 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-27-10' AS sat_id, 'Sat_27_10' AS stk_name, 27 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-27-11' AS sat_id, 'Sat_27_11' AS stk_name, 27 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-27-12' AS sat_id, 'Sat_27_12' AS stk_name, 27 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-27-13' AS sat_id, 'Sat_27_13' AS stk_name, 27 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-27-14' AS sat_id, 'Sat_27_14' AS stk_name, 27 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-27-15' AS sat_id, 'Sat_27_15' AS stk_name, 27 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-27-16' AS sat_id, 'Sat_27_16' AS stk_name, 27 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-27-17' AS sat_id, 'Sat_27_17' AS stk_name, 27 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-27-18' AS sat_id, 'Sat_27_18' AS stk_name, 27 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-27-19' AS sat_id, 'Sat_27_19' AS stk_name, 27 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-27-20' AS sat_id, 'Sat_27_20' AS stk_name, 27 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-27-21' AS sat_id, 'Sat_27_21' AS stk_name, 27 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-27-22' AS sat_id, 'Sat_27_22' AS stk_name, 27 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 260.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-28-1' AS sat_id, 'Sat_28_1' AS stk_name, 28 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-28-2' AS sat_id, 'Sat_28_2' AS stk_name, 28 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-28-3' AS sat_id, 'Sat_28_3' AS stk_name, 28 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-28-4' AS sat_id, 'Sat_28_4' AS stk_name, 28 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-28-5' AS sat_id, 'Sat_28_5' AS stk_name, 28 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-28-6' AS sat_id, 'Sat_28_6' AS stk_name, 28 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-28-7' AS sat_id, 'Sat_28_7' AS stk_name, 28 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-28-8' AS sat_id, 'Sat_28_8' AS stk_name, 28 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-28-9' AS sat_id, 'Sat_28_9' AS stk_name, 28 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-28-10' AS sat_id, 'Sat_28_10' AS stk_name, 28 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-28-11' AS sat_id, 'Sat_28_11' AS stk_name, 28 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-28-12' AS sat_id, 'Sat_28_12' AS stk_name, 28 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-28-13' AS sat_id, 'Sat_28_13' AS stk_name, 28 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-28-14' AS sat_id, 'Sat_28_14' AS stk_name, 28 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-28-15' AS sat_id, 'Sat_28_15' AS stk_name, 28 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-28-16' AS sat_id, 'Sat_28_16' AS stk_name, 28 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-28-17' AS sat_id, 'Sat_28_17' AS stk_name, 28 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-28-18' AS sat_id, 'Sat_28_18' AS stk_name, 28 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-28-19' AS sat_id, 'Sat_28_19' AS stk_name, 28 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-28-20' AS sat_id, 'Sat_28_20' AS stk_name, 28 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-28-21' AS sat_id, 'Sat_28_21' AS stk_name, 28 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-28-22' AS sat_id, 'Sat_28_22' AS stk_name, 28 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 270.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-29-1' AS sat_id, 'Sat_29_1' AS stk_name, 29 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-29-2' AS sat_id, 'Sat_29_2' AS stk_name, 29 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-29-3' AS sat_id, 'Sat_29_3' AS stk_name, 29 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-29-4' AS sat_id, 'Sat_29_4' AS stk_name, 29 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-29-5' AS sat_id, 'Sat_29_5' AS stk_name, 29 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-29-6' AS sat_id, 'Sat_29_6' AS stk_name, 29 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-29-7' AS sat_id, 'Sat_29_7' AS stk_name, 29 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-29-8' AS sat_id, 'Sat_29_8' AS stk_name, 29 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-29-9' AS sat_id, 'Sat_29_9' AS stk_name, 29 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-29-10' AS sat_id, 'Sat_29_10' AS stk_name, 29 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-29-11' AS sat_id, 'Sat_29_11' AS stk_name, 29 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-29-12' AS sat_id, 'Sat_29_12' AS stk_name, 29 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-29-13' AS sat_id, 'Sat_29_13' AS stk_name, 29 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-29-14' AS sat_id, 'Sat_29_14' AS stk_name, 29 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-29-15' AS sat_id, 'Sat_29_15' AS stk_name, 29 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-29-16' AS sat_id, 'Sat_29_16' AS stk_name, 29 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-29-17' AS sat_id, 'Sat_29_17' AS stk_name, 29 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-29-18' AS sat_id, 'Sat_29_18' AS stk_name, 29 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-29-19' AS sat_id, 'Sat_29_19' AS stk_name, 29 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-29-20' AS sat_id, 'Sat_29_20' AS stk_name, 29 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-29-21' AS sat_id, 'Sat_29_21' AS stk_name, 29 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-29-22' AS sat_id, 'Sat_29_22' AS stk_name, 29 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 280.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-30-1' AS sat_id, 'Sat_30_1' AS stk_name, 30 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-30-2' AS sat_id, 'Sat_30_2' AS stk_name, 30 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-30-3' AS sat_id, 'Sat_30_3' AS stk_name, 30 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-30-4' AS sat_id, 'Sat_30_4' AS stk_name, 30 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-30-5' AS sat_id, 'Sat_30_5' AS stk_name, 30 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-30-6' AS sat_id, 'Sat_30_6' AS stk_name, 30 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-30-7' AS sat_id, 'Sat_30_7' AS stk_name, 30 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-30-8' AS sat_id, 'Sat_30_8' AS stk_name, 30 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-30-9' AS sat_id, 'Sat_30_9' AS stk_name, 30 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-30-10' AS sat_id, 'Sat_30_10' AS stk_name, 30 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-30-11' AS sat_id, 'Sat_30_11' AS stk_name, 30 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-30-12' AS sat_id, 'Sat_30_12' AS stk_name, 30 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-30-13' AS sat_id, 'Sat_30_13' AS stk_name, 30 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-30-14' AS sat_id, 'Sat_30_14' AS stk_name, 30 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-30-15' AS sat_id, 'Sat_30_15' AS stk_name, 30 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-30-16' AS sat_id, 'Sat_30_16' AS stk_name, 30 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-30-17' AS sat_id, 'Sat_30_17' AS stk_name, 30 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-30-18' AS sat_id, 'Sat_30_18' AS stk_name, 30 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-30-19' AS sat_id, 'Sat_30_19' AS stk_name, 30 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-30-20' AS sat_id, 'Sat_30_20' AS stk_name, 30 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-30-21' AS sat_id, 'Sat_30_21' AS stk_name, 30 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-30-22' AS sat_id, 'Sat_30_22' AS stk_name, 30 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 290.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-31-1' AS sat_id, 'Sat_31_1' AS stk_name, 31 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-31-2' AS sat_id, 'Sat_31_2' AS stk_name, 31 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-31-3' AS sat_id, 'Sat_31_3' AS stk_name, 31 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-31-4' AS sat_id, 'Sat_31_4' AS stk_name, 31 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-31-5' AS sat_id, 'Sat_31_5' AS stk_name, 31 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-31-6' AS sat_id, 'Sat_31_6' AS stk_name, 31 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-31-7' AS sat_id, 'Sat_31_7' AS stk_name, 31 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-31-8' AS sat_id, 'Sat_31_8' AS stk_name, 31 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-31-9' AS sat_id, 'Sat_31_9' AS stk_name, 31 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-31-10' AS sat_id, 'Sat_31_10' AS stk_name, 31 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-31-11' AS sat_id, 'Sat_31_11' AS stk_name, 31 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-31-12' AS sat_id, 'Sat_31_12' AS stk_name, 31 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-31-13' AS sat_id, 'Sat_31_13' AS stk_name, 31 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-31-14' AS sat_id, 'Sat_31_14' AS stk_name, 31 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-31-15' AS sat_id, 'Sat_31_15' AS stk_name, 31 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-31-16' AS sat_id, 'Sat_31_16' AS stk_name, 31 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-31-17' AS sat_id, 'Sat_31_17' AS stk_name, 31 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-31-18' AS sat_id, 'Sat_31_18' AS stk_name, 31 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-31-19' AS sat_id, 'Sat_31_19' AS stk_name, 31 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-31-20' AS sat_id, 'Sat_31_20' AS stk_name, 31 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-31-21' AS sat_id, 'Sat_31_21' AS stk_name, 31 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-31-22' AS sat_id, 'Sat_31_22' AS stk_name, 31 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 300.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-32-1' AS sat_id, 'Sat_32_1' AS stk_name, 32 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-32-2' AS sat_id, 'Sat_32_2' AS stk_name, 32 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-32-3' AS sat_id, 'Sat_32_3' AS stk_name, 32 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-32-4' AS sat_id, 'Sat_32_4' AS stk_name, 32 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-32-5' AS sat_id, 'Sat_32_5' AS stk_name, 32 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-32-6' AS sat_id, 'Sat_32_6' AS stk_name, 32 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-32-7' AS sat_id, 'Sat_32_7' AS stk_name, 32 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-32-8' AS sat_id, 'Sat_32_8' AS stk_name, 32 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-32-9' AS sat_id, 'Sat_32_9' AS stk_name, 32 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-32-10' AS sat_id, 'Sat_32_10' AS stk_name, 32 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-32-11' AS sat_id, 'Sat_32_11' AS stk_name, 32 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-32-12' AS sat_id, 'Sat_32_12' AS stk_name, 32 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-32-13' AS sat_id, 'Sat_32_13' AS stk_name, 32 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-32-14' AS sat_id, 'Sat_32_14' AS stk_name, 32 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-32-15' AS sat_id, 'Sat_32_15' AS stk_name, 32 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-32-16' AS sat_id, 'Sat_32_16' AS stk_name, 32 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-32-17' AS sat_id, 'Sat_32_17' AS stk_name, 32 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-32-18' AS sat_id, 'Sat_32_18' AS stk_name, 32 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-32-19' AS sat_id, 'Sat_32_19' AS stk_name, 32 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-32-20' AS sat_id, 'Sat_32_20' AS stk_name, 32 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-32-21' AS sat_id, 'Sat_32_21' AS stk_name, 32 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-32-22' AS sat_id, 'Sat_32_22' AS stk_name, 32 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 310.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-33-1' AS sat_id, 'Sat_33_1' AS stk_name, 33 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-33-2' AS sat_id, 'Sat_33_2' AS stk_name, 33 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-33-3' AS sat_id, 'Sat_33_3' AS stk_name, 33 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-33-4' AS sat_id, 'Sat_33_4' AS stk_name, 33 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-33-5' AS sat_id, 'Sat_33_5' AS stk_name, 33 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-33-6' AS sat_id, 'Sat_33_6' AS stk_name, 33 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-33-7' AS sat_id, 'Sat_33_7' AS stk_name, 33 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-33-8' AS sat_id, 'Sat_33_8' AS stk_name, 33 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-33-9' AS sat_id, 'Sat_33_9' AS stk_name, 33 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-33-10' AS sat_id, 'Sat_33_10' AS stk_name, 33 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-33-11' AS sat_id, 'Sat_33_11' AS stk_name, 33 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-33-12' AS sat_id, 'Sat_33_12' AS stk_name, 33 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-33-13' AS sat_id, 'Sat_33_13' AS stk_name, 33 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-33-14' AS sat_id, 'Sat_33_14' AS stk_name, 33 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-33-15' AS sat_id, 'Sat_33_15' AS stk_name, 33 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-33-16' AS sat_id, 'Sat_33_16' AS stk_name, 33 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-33-17' AS sat_id, 'Sat_33_17' AS stk_name, 33 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-33-18' AS sat_id, 'Sat_33_18' AS stk_name, 33 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-33-19' AS sat_id, 'Sat_33_19' AS stk_name, 33 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-33-20' AS sat_id, 'Sat_33_20' AS stk_name, 33 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-33-21' AS sat_id, 'Sat_33_21' AS stk_name, 33 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-33-22' AS sat_id, 'Sat_33_22' AS stk_name, 33 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 320.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-34-1' AS sat_id, 'Sat_34_1' AS stk_name, 34 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-34-2' AS sat_id, 'Sat_34_2' AS stk_name, 34 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-34-3' AS sat_id, 'Sat_34_3' AS stk_name, 34 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-34-4' AS sat_id, 'Sat_34_4' AS stk_name, 34 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-34-5' AS sat_id, 'Sat_34_5' AS stk_name, 34 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-34-6' AS sat_id, 'Sat_34_6' AS stk_name, 34 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-34-7' AS sat_id, 'Sat_34_7' AS stk_name, 34 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-34-8' AS sat_id, 'Sat_34_8' AS stk_name, 34 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-34-9' AS sat_id, 'Sat_34_9' AS stk_name, 34 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-34-10' AS sat_id, 'Sat_34_10' AS stk_name, 34 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-34-11' AS sat_id, 'Sat_34_11' AS stk_name, 34 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-34-12' AS sat_id, 'Sat_34_12' AS stk_name, 34 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-34-13' AS sat_id, 'Sat_34_13' AS stk_name, 34 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-34-14' AS sat_id, 'Sat_34_14' AS stk_name, 34 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-34-15' AS sat_id, 'Sat_34_15' AS stk_name, 34 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-34-16' AS sat_id, 'Sat_34_16' AS stk_name, 34 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-34-17' AS sat_id, 'Sat_34_17' AS stk_name, 34 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-34-18' AS sat_id, 'Sat_34_18' AS stk_name, 34 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-34-19' AS sat_id, 'Sat_34_19' AS stk_name, 34 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-34-20' AS sat_id, 'Sat_34_20' AS stk_name, 34 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-34-21' AS sat_id, 'Sat_34_21' AS stk_name, 34 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-34-22' AS sat_id, 'Sat_34_22' AS stk_name, 34 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 330.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg UNION ALL
  SELECT 'sat-35-1' AS sat_id, 'Sat_35_1' AS stk_name, 35 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 0.000000 AS ta_deg UNION ALL
  SELECT 'sat-35-2' AS sat_id, 'Sat_35_2' AS stk_name, 35 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 16.363636 AS ta_deg UNION ALL
  SELECT 'sat-35-3' AS sat_id, 'Sat_35_3' AS stk_name, 35 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 32.727273 AS ta_deg UNION ALL
  SELECT 'sat-35-4' AS sat_id, 'Sat_35_4' AS stk_name, 35 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 49.090909 AS ta_deg UNION ALL
  SELECT 'sat-35-5' AS sat_id, 'Sat_35_5' AS stk_name, 35 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 65.454545 AS ta_deg UNION ALL
  SELECT 'sat-35-6' AS sat_id, 'Sat_35_6' AS stk_name, 35 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 81.818182 AS ta_deg UNION ALL
  SELECT 'sat-35-7' AS sat_id, 'Sat_35_7' AS stk_name, 35 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 98.181818 AS ta_deg UNION ALL
  SELECT 'sat-35-8' AS sat_id, 'Sat_35_8' AS stk_name, 35 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 114.545455 AS ta_deg UNION ALL
  SELECT 'sat-35-9' AS sat_id, 'Sat_35_9' AS stk_name, 35 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 130.909091 AS ta_deg UNION ALL
  SELECT 'sat-35-10' AS sat_id, 'Sat_35_10' AS stk_name, 35 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 147.272727 AS ta_deg UNION ALL
  SELECT 'sat-35-11' AS sat_id, 'Sat_35_11' AS stk_name, 35 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 163.636364 AS ta_deg UNION ALL
  SELECT 'sat-35-12' AS sat_id, 'Sat_35_12' AS stk_name, 35 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 180.000000 AS ta_deg UNION ALL
  SELECT 'sat-35-13' AS sat_id, 'Sat_35_13' AS stk_name, 35 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 196.363636 AS ta_deg UNION ALL
  SELECT 'sat-35-14' AS sat_id, 'Sat_35_14' AS stk_name, 35 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 212.727273 AS ta_deg UNION ALL
  SELECT 'sat-35-15' AS sat_id, 'Sat_35_15' AS stk_name, 35 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 229.090909 AS ta_deg UNION ALL
  SELECT 'sat-35-16' AS sat_id, 'Sat_35_16' AS stk_name, 35 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 245.454545 AS ta_deg UNION ALL
  SELECT 'sat-35-17' AS sat_id, 'Sat_35_17' AS stk_name, 35 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 261.818182 AS ta_deg UNION ALL
  SELECT 'sat-35-18' AS sat_id, 'Sat_35_18' AS stk_name, 35 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 278.181818 AS ta_deg UNION ALL
  SELECT 'sat-35-19' AS sat_id, 'Sat_35_19' AS stk_name, 35 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 294.545455 AS ta_deg UNION ALL
  SELECT 'sat-35-20' AS sat_id, 'Sat_35_20' AS stk_name, 35 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 310.909091 AS ta_deg UNION ALL
  SELECT 'sat-35-21' AS sat_id, 'Sat_35_21' AS stk_name, 35 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 327.272727 AS ta_deg UNION ALL
  SELECT 'sat-35-22' AS sat_id, 'Sat_35_22' AS stk_name, 35 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 340.000000 AS raan_deg, 0.000000 AS argp_deg, 343.636364 AS ta_deg UNION ALL
  SELECT 'sat-36-1' AS sat_id, 'Sat_36_1' AS stk_name, 36 AS plane_index, 1 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 8.181818 AS ta_deg UNION ALL
  SELECT 'sat-36-2' AS sat_id, 'Sat_36_2' AS stk_name, 36 AS plane_index, 2 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 24.545455 AS ta_deg UNION ALL
  SELECT 'sat-36-3' AS sat_id, 'Sat_36_3' AS stk_name, 36 AS plane_index, 3 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 40.909091 AS ta_deg UNION ALL
  SELECT 'sat-36-4' AS sat_id, 'Sat_36_4' AS stk_name, 36 AS plane_index, 4 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 57.272727 AS ta_deg UNION ALL
  SELECT 'sat-36-5' AS sat_id, 'Sat_36_5' AS stk_name, 36 AS plane_index, 5 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 73.636364 AS ta_deg UNION ALL
  SELECT 'sat-36-6' AS sat_id, 'Sat_36_6' AS stk_name, 36 AS plane_index, 6 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 90.000000 AS ta_deg UNION ALL
  SELECT 'sat-36-7' AS sat_id, 'Sat_36_7' AS stk_name, 36 AS plane_index, 7 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 106.363636 AS ta_deg UNION ALL
  SELECT 'sat-36-8' AS sat_id, 'Sat_36_8' AS stk_name, 36 AS plane_index, 8 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 122.727273 AS ta_deg UNION ALL
  SELECT 'sat-36-9' AS sat_id, 'Sat_36_9' AS stk_name, 36 AS plane_index, 9 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 139.090909 AS ta_deg UNION ALL
  SELECT 'sat-36-10' AS sat_id, 'Sat_36_10' AS stk_name, 36 AS plane_index, 10 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 155.454545 AS ta_deg UNION ALL
  SELECT 'sat-36-11' AS sat_id, 'Sat_36_11' AS stk_name, 36 AS plane_index, 11 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 171.818182 AS ta_deg UNION ALL
  SELECT 'sat-36-12' AS sat_id, 'Sat_36_12' AS stk_name, 36 AS plane_index, 12 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 188.181818 AS ta_deg UNION ALL
  SELECT 'sat-36-13' AS sat_id, 'Sat_36_13' AS stk_name, 36 AS plane_index, 13 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 204.545455 AS ta_deg UNION ALL
  SELECT 'sat-36-14' AS sat_id, 'Sat_36_14' AS stk_name, 36 AS plane_index, 14 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 220.909091 AS ta_deg UNION ALL
  SELECT 'sat-36-15' AS sat_id, 'Sat_36_15' AS stk_name, 36 AS plane_index, 15 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 237.272727 AS ta_deg UNION ALL
  SELECT 'sat-36-16' AS sat_id, 'Sat_36_16' AS stk_name, 36 AS plane_index, 16 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 253.636364 AS ta_deg UNION ALL
  SELECT 'sat-36-17' AS sat_id, 'Sat_36_17' AS stk_name, 36 AS plane_index, 17 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 270.000000 AS ta_deg UNION ALL
  SELECT 'sat-36-18' AS sat_id, 'Sat_36_18' AS stk_name, 36 AS plane_index, 18 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 286.363636 AS ta_deg UNION ALL
  SELECT 'sat-36-19' AS sat_id, 'Sat_36_19' AS stk_name, 36 AS plane_index, 19 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 302.727273 AS ta_deg UNION ALL
  SELECT 'sat-36-20' AS sat_id, 'Sat_36_20' AS stk_name, 36 AS plane_index, 20 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 319.090909 AS ta_deg UNION ALL
  SELECT 'sat-36-21' AS sat_id, 'Sat_36_21' AS stk_name, 36 AS plane_index, 21 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 335.454545 AS ta_deg UNION ALL
  SELECT 'sat-36-22' AS sat_id, 'Sat_36_22' AS stk_name, 36 AS plane_index, 22 AS sat_index_in_plane,
         550.000000 AS alt_km, 6928.137000 AS sma_km, 0.000000 AS ecc, 53.000000 AS inc_deg, 350.000000 AS raan_deg, 0.000000 AS argp_deg, 351.818182 AS ta_deg
) AS v
WHERE NOT EXISTS (
  SELECT 1
  FROM public.satellites s
  WHERE s.scenario_id = sid.id
    AND s.sat_id = v.sat_id
);

COMMIT;
