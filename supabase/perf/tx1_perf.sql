-- ============================================================
-- TX-1: 軽さ（設計書 第11章 11-3節の手順 D）。毎回は流さない（tests/ の外に置いた）。スキーマを変えたときに流す。
--   ローカルの Supabase に 4家庭・①300件・②600件・③1,000件（1/4 を非公開）の見本データを入れ、
--   各家庭のメンバーとして、読む関数を10回ずつ呼んで1回あたりの時間（ミリ秒）を測る。合格は各100ミリ秒以内。
--   前提: tests/000_setup_helpers.test.sql を一度流して test_fx がある（npx supabase test db の後）。
--   流し方（PowerShell）:
--     Get-Content supabase\perf\tx1_perf.sql | docker exec -i supabase_db_kosodate-hint-note-app psql -U postgres -d postgres
--   最後に ROLLBACK するので、データは残らない。
-- ============================================================
BEGIN;
SELECT test_fx.build();

-- 見本データ（持ち主の権限で入れる）。家庭 H0・HA・HB・HC に順に割り当てる
DO $$
DECLARE
  v_s1 uuid := test_fx.id('S1');
  v_hh uuid[] := ARRAY[test_fx.id('H0'), test_fx.id('HA'), test_fx.id('HB'), test_fx.id('HC')];
  v_mb uuid[] := ARRAY[test_fx.id('m_u0a'), test_fx.id('m_a1'), test_fx.id('m_b1'), test_fx.id('m_c1')];
  v_tags uuid[];
  v_p uuid; v_m uuid; i int; j int; k int := 0;
BEGIN
  SELECT array_agg(tg.id) INTO v_tags FROM public.tags tg WHERE tg.space_id = v_s1 AND NOT tg.is_other AND tg.kind IN ('trouble', 'both');
  FOR i IN 1..300 LOOP
    INSERT INTO public.problems (space_id, name, created_household_id)
    VALUES (v_s1, '困りごと' || i || CASE WHEN i % 7 = 0 THEN ' 寝る' ELSE '' END, v_hh[1 + i % 4]) RETURNING id INTO v_p;
    INSERT INTO public.problem_tags (problem_id, tag_id) VALUES (v_p, v_tags[1 + i % 10]) ON CONFLICT DO NOTHING;
    FOR j IN 1..2 LOOP
      INSERT INTO public.measures (problem_id, name, created_household_id)
      VALUES (v_p, '対策' || i || '-' || j, v_hh[1 + (i + j) % 4]) RETURNING id INTO v_m;
      -- ③: 1,000件を②600件に配る（1件か2件）。4件に1件は非公開
      FOR k IN 1..(CASE WHEN (i * 2 + j) % 3 = 0 THEN 1 ELSE 2 END) LOOP
        EXIT WHEN (SELECT count(*) FROM public.trials) >= 1000;
        INSERT INTO public.trials (measure_id, household_id, created_by_member_id, score, age_months, tried_on, visibility)
        VALUES (v_m, v_hh[1 + (i + j + k) % 4], v_mb[1 + (i + j + k) % 4],
                CASE WHEN (i + k) % 5 = 0 THEN NULL ELSE 1 + (i + j + k) % 5 END,
                6 * ((i + j) % 37), DATE '2026-01-01' + (i % 250),
                CASE WHEN (i + j + k) % 4 = 0 THEN 'household' ELSE 'all' END);
      END LOOP;
    END LOOP;
  END LOOP;
END $$;
ANALYZE public.problems; ANALYZE public.measures; ANALYZE public.trials; ANALYZE public.problem_tags;
SELECT (SELECT count(*) FROM public.problems) AS problems, (SELECT count(*) FROM public.measures) AS measures,
       (SELECT count(*) FROM public.trials) AS trials,
       (SELECT count(*) FROM public.trials WHERE visibility = 'household') AS private_trials;

-- 測る（各家庭のメンバーとして、各関数を10回。平均と最大のミリ秒）
CREATE TEMP TABLE perf (who text, fn text, avg_ms numeric, max_ms numeric) ON COMMIT DROP;
GRANT ALL ON perf TO authenticated;
DO $$
DECLARE
  v_who text; v_fn text; v_sql text; v_t0 timestamptz; v_ms numeric; v_sum numeric; v_max numeric; n int;
  v_p uuid := (SELECT p.id FROM public.problems p ORDER BY p.name LIMIT 1);
  v_s1 uuid := test_fx.id('S1');
BEGIN
  FOREACH v_who IN ARRAY ARRAY['u0a', 'a1', 'b1', 'c1'] LOOP
    PERFORM test_fx.as_user(v_who);
    FOR v_fn, v_sql IN VALUES
      ('search_problems（言葉なし）', format('SELECT count(*) FROM public.search_problems(%L)', v_s1)),
      ('search_problems（言葉「寝る」）', format('SELECT count(*) FROM public.search_problems(%L, %L)', v_s1, '寝る')),
      ('list_measures（歳なし）', format('SELECT count(*) FROM public.list_measures(%L)', v_p)),
      ('list_measures（歳あり 3歳）', format('SELECT count(*) FROM public.list_measures(%L, NULL, 3)', v_p)),
      ('list_age_counts', format('SELECT count(*) FROM public.list_age_counts(%L)', v_s1)),
      ('suggest_problems（1文字）', format('SELECT count(*) FROM public.suggest_problems(%L, %L)', v_s1, '困')),
      ('suggest_measures（空の文字）', format('SELECT count(*) FROM public.suggest_measures(%L, %L)', v_p, '')),
      ('suggest_measures（1文字）', format('SELECT count(*) FROM public.suggest_measures(%L, %L)', v_p, '対')),
      ('list_my_spaces', 'SELECT count(*) FROM public.list_my_spaces()')
    LOOP
      v_sum := 0; v_max := 0;
      FOR n IN 1..10 LOOP
        v_t0 := clock_timestamp();
        EXECUTE v_sql;
        v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000;
        v_sum := v_sum + v_ms; v_max := greatest(v_max, v_ms);
      END LOOP;
      INSERT INTO perf VALUES (v_who, v_fn, round(v_sum / 10, 2), round(v_max, 2));
    END LOOP;
  END LOOP;
  PERFORM test_fx.as_owner();
END $$;
SELECT fn AS "関数", round(avg(avg_ms), 2) AS "平均ms（4家庭の平均）", max(max_ms) AS "最大ms",
       CASE WHEN max(max_ms) <= 100 THEN '合格' ELSE '100ms超え' END AS "判定"
FROM perf GROUP BY fn ORDER BY fn;
ROLLBACK;
