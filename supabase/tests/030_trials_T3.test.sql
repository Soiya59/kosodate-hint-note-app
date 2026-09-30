-- ============================================================
-- 設計書 12-2節「③ 試した結果」 T3-R1〜R4・T3-C1〜C4・T3-U1〜U5・T3-D1〜D4（すべて S1）
-- 対応する RLS: trials_select_visible / trials_insert_own_household / trials_update_own_household /
--              trials_delete_own_or_admin_public ＋ トリガー（設計書 3-2節 ③・3-5節）
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(33);
SELECT test_fx.build();

SELECT test_fx.mk_problem('P', 'S1', '③の困りごと', 'HA');
SELECT test_fx.mk_measure('M', 'P', '③の対策', 'HA');
SELECT test_fx.mk_trial('T_pub', 'M', 'a1', 4, 'all');
SELECT test_fx.mk_trial('T_priv', 'M', 'a1', 5, 'household');

-- ---------- 読む ----------
-- T3-R1: A のみんなの③ → u0a・u0b・a1・b1・c1 の全員に出る
SELECT test_fx.as_user('u0a');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_pub')), 1, 'T3-R1: みんなの③が u0a に出る');
SELECT test_fx.as_user('u0b');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_pub')), 1, 'T3-R1: みんなの③が u0b に出る');
SELECT test_fx.as_user('a1');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_pub')), 1, 'T3-R1: みんなの③が a1 に出る');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_pub')), 1, 'T3-R1: みんなの③が b1 に出る');
SELECT test_fx.as_user('c1');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_pub')), 1, 'T3-R1: みんなの③が c1 に出る');

-- T3-R2: A の非公開③ → a1・a2 に出る
SELECT test_fx.as_user('a1');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_priv')), 1, 'T3-R2: A の非公開③が a1 に出る');
SELECT test_fx.as_user('a2');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_priv')), 1, 'T3-R2: A の非公開③が a2 に出る');

-- T3-R3: A の非公開③ → b1・c1 に出ない（表でも、list_measures の o_trials でも、o_trial_count でも）
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_priv')), 0, 'T3-R3: A の非公開③は b1 の表に出ない');
SELECT is((SELECT lm.o_trial_count FROM public.list_measures(test_fx.id('P')) lm WHERE lm.o_measure_id = test_fx.id('M')), 1,
  'T3-R3: b1 の list_measures の o_trial_count は1（みんなの③だけ）');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P')) lm, jsonb_array_elements(lm.o_trials) e
            WHERE e->>'trial_id' = test_fx.id('T_priv')::text), 0,
  'T3-R3: b1 の list_measures の o_trials に非公開③が入らない');
SELECT test_fx.as_user('c1');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_priv')), 0, 'T3-R3: A の非公開③は c1 の表に出ない');
SELECT is((SELECT lm.o_trial_count FROM public.list_measures(test_fx.id('P')) lm WHERE lm.o_measure_id = test_fx.id('M')), 1,
  'T3-R3: c1 の o_trial_count も1');

-- T3-R4: A の非公開③ → u0a（管理者）に出ない
SELECT test_fx.as_user('u0a');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_priv')), 0, 'T3-R4: A の非公開③は管理者 u0a にも出ない');

-- ---------- 書く ----------
-- T3-C1: A の②（見える）→ b1 が save_trial（p_measure_id）→ 書ける。家庭＝HB
SELECT test_fx.as_user('b1');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 3)$$, test_fx.id('M')),
  'T3-C1: b1 が見える②に save_trial で③を書ける');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(DISTINCT t.household_id) FROM public.trials t
            WHERE t.measure_id = test_fx.id('M') AND t.created_by_member_id = test_fx.id('m_b1')),
  ARRAY[test_fx.id('HB')], 'T3-C1: 書いた③の家庭は HB');

-- T3-C2: 同じ②に b1 がもう2件（同じ年齢も）→ 書ける（何件でも）
SELECT test_fx.as_user('b1');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 4, p_age_months => 36)$$, test_fx.id('M')),
  'T3-C2: 同じ②に2件目');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => NULL, p_age_months => 36)$$, test_fx.id('M')),
  'T3-C2: 同じ②に3件目（同じ年齢・試し中）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.measure_id = test_fx.id('M') AND t.household_id = test_fx.id('HB')), 3,
  'T3-C2: 同じ家庭が同じ②に3件書けている');

-- T3-C3: B に見えない② → b1 が直接 INSERT → not_visible
SELECT test_fx.mk_measure('M_hidden', 'P', '見えない対策', 'HA');
SELECT test_fx.mk_trial('T_hidden', 'M_hidden', 'a1', 4, 'household');
SELECT test_fx.as_user('b1');
SELECT throws_ok(format($$INSERT INTO public.trials (measure_id, age_months) VALUES (%L, 36)$$, test_fx.id('M_hidden')),
  '42501', 'not_visible', 'T3-C3: 見えない②に③を書こうとすると not_visible');

-- T3-C4: b1 が household_id = HA を付けて INSERT → 家庭は HB に上書き
SELECT lives_ok(format($$INSERT INTO public.trials (measure_id, age_months, household_id, note) VALUES (%L, 36, %L, 'C4')$$,
  test_fx.id('M'), test_fx.id('HA')), 'T3-C4: 家庭 HA を付けた INSERT も通る');
SELECT test_fx.as_owner();
SELECT is((SELECT t.household_id FROM public.trials t WHERE t.note = 'C4'), test_fx.id('HB'),
  'T3-C4: 家庭は HB に上書きされる');

-- ---------- 直す ----------
-- T3-U1: a1 が書いた③を a2 が点数を直す → 直せる。updated_by は a2
SELECT test_fx.as_user('a2');
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET score = 2 WHERE id = %L$$, test_fx.id('T_pub'))), 1,
  'T3-U1: 同じ家庭の a2 が a1 の③を直せる');
SELECT test_fx.as_owner();
SELECT is((SELECT t.updated_by_member_id FROM public.trials t WHERE t.id = test_fx.id('T_pub')), test_fx.id('m_a2'),
  'T3-U1: updated_by_member_id は a2');

-- T3-U2: A の③ → b1 が直接 UPDATE → 0行
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET score = 1 WHERE id = %L$$, test_fx.id('T_pub'))), 0,
  'T3-U2: 他家庭の③は直せない（0行）');

-- T3-U3: A のみんなの③ → u0a が直接 UPDATE → 0行
SELECT test_fx.as_user('u0a');
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET score = 1 WHERE id = %L$$, test_fx.id('T_pub'))), 0,
  'T3-U3: 管理者も他家庭の③は直せない（0行）');

-- T3-U4: A の③ → a1 が household_id・measure_id を変える → immutable_column
SELECT test_fx.as_user('a1');
SELECT throws_ok(format($$UPDATE public.trials SET household_id = %L WHERE id = %L$$, test_fx.id('HB'), test_fx.id('T_pub')),
  'P0001', 'immutable_column', 'T3-U4: ③の家庭は変えられない');
SELECT throws_ok(format($$UPDATE public.trials SET measure_id = %L WHERE id = %L$$, test_fx.id('M_hidden'), test_fx.id('T_pub')),
  'P0001', 'immutable_column', 'T3-U4: ③の②は変えられない');

-- T3-U5: A の試し中の③ → a1 が score を 4 に → 直せる。tried_on は変わらない
SELECT test_fx.as_owner();
SELECT test_fx.mk_trial('T_trying', 'M', 'a1', NULL, 'all', 36, DATE '2026-08-15');
SELECT test_fx.as_user('a1');
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET score = 4 WHERE id = %L$$, test_fx.id('T_trying'))), 1,
  'T3-U5: 試し中の③に点数を付けられる');
SELECT test_fx.as_owner();
SELECT is((SELECT t.tried_on FROM public.trials t WHERE t.id = test_fx.id('T_trying')), DATE '2026-08-15',
  'T3-U5: 試した日は変わらない');

-- ---------- 消す ----------
SELECT test_fx.mk_trial('T_d1', 'M', 'a1', 3, 'all');
SELECT test_fx.mk_trial('T_d2', 'M', 'a1', 3, 'all');
SELECT test_fx.mk_trial('T_d3', 'M', 'a1', 3, 'all');
SELECT test_fx.mk_trial('T_d4', 'M', 'a1', 3, 'household');
SELECT test_fx.as_user('a2');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.trials WHERE id = %L$$, test_fx.id('T_d1'))), 1,
  'T3-D1: 同じ家庭の a2 が A の③を消せる');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.trials WHERE id = %L$$, test_fx.id('T_d2'))), 0,
  'T3-D2: 他家庭の③は消せない（0行）');
SELECT test_fx.as_user('u0a');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.trials WHERE id = %L$$, test_fx.id('T_d3'))), 1,
  'T3-D3: 管理者は他家庭の「みんな」の③を消せる');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.trials WHERE id = %L$$, test_fx.id('T_d4'))), 0,
  'T3-D4: 管理者も他家庭の非公開③は消せない（0行）');

SELECT * FROM finish();
ROLLBACK;
