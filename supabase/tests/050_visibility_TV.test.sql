-- ============================================================
-- 設計書 12-3節「見え方の確認例」 TV-1〜TV-9（要件 2-4 の7行＋4家庭＋2家庭の場）
--   A（家庭A）が書き、B（b1）から見る。TV-9 だけ S2。
--   見え方の規則は visible_measure_ids() / visible_problem_ids() の2か所だけ（設計書 3-3節）。
--   一覧・検索・候補・年齢の件数・対策の一覧・出典のタブ・書き出しは RLS を通して同じ規則になることを確かめる。
--   年齢は状況ごとに分けた（TV-1＝2歳、TV-2＝4歳、TV-7＝5歳）。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(48);
SELECT test_fx.build();

-- TV-1: A が①②を作り、A の③（みんな）1件 → b1 に①②が見える。一覧・検索・候補・年齢の件数にも出る
SELECT test_fx.mk_problem('P1', 'S1', 'TV1のこまりごと', 'HA');
SELECT test_fx.mk_measure('M1', 'P1', 'TV1のたいさく', 'HA');
SELECT test_fx.mk_trial('T1', 'M1', 'a1', 4, 'all', 24);
-- TV-2: A が①②を作り、A の③（非公開）1件だけ → b1 に①②が見えない
SELECT test_fx.mk_problem('P2', 'S1', 'TV2のこまりごと', 'HA');
SELECT test_fx.mk_measure('M2', 'P2', 'TV2のたいさく', 'HA');
SELECT test_fx.mk_trial('T2', 'M2', 'a1', 4, 'household', 48);

SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P1')), 1, 'TV-1: ①が見える');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M1')), 1, 'TV-1: ②が見える');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), 'TV1のこまりごと') s WHERE s.o_problem_id = test_fx.id('P1')), 1,
  'TV-1: search_problems に出る');
SELECT is((SELECT count(*)::int FROM public.suggest_problems(test_fx.id('S1'), 'TV1の') s WHERE s.o_problem_id = test_fx.id('P1')), 1,
  'TV-1: suggest_problems に出る');
SELECT is((SELECT a.o_problem_count FROM public.list_age_counts(test_fx.id('S1')) a WHERE a.o_age_years = 2), 1,
  'TV-1: list_age_counts の2歳に1件');

-- TV-2 の確かめ（b1 から、どこにも出ない）
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P2')), 0, 'TV-2: ①が見えない（表）');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M2')), 0, 'TV-2: ②が見えない（表）');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'))  s WHERE s.o_problem_id = test_fx.id('P2')), 0,
  'TV-2: 困りごとの一覧（search_problems・言葉なし）に出ない');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), 'TV2のこまりごと')), 0, 'TV-2: ①の名前で検索しても出ない');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), 'TV2のたいさく')), 0, 'TV-2: ②の名前で検索しても出ない');
SELECT is((SELECT count(*)::int FROM public.suggest_problems(test_fx.id('S1'), 'TV2')), 0, 'TV-2: 候補（suggest_problems）に出ない');
SELECT is((SELECT count(*)::int FROM public.list_age_counts(test_fx.id('S1')) a WHERE a.o_age_years = 4), 0, 'TV-2: 年齢の件数（4歳）に出ない');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P2'))), 0, 'TV-2: 対策の一覧に出ない');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P2'), 'own')), 0, 'TV-2: 出典のタブ（うちで考えた）にも出ない');
SELECT is((SELECT count(*)::int FROM public.suggest_measures(test_fx.id('P2'), '')), 0, 'TV-2（補い）: ②の候補にも出ない');
SELECT ok(position(test_fx.id('P2')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0
      AND position(test_fx.id('M2')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0
      AND position(test_fx.id('T2')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0,
  'TV-2: 書き出しにも出ない');

-- TV-3: TV-2 と同じ状況に A の③（みんな）を足す → ①② が見える。③はみんなの1件だけ（o_trial_count = 1）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P3', 'S1', 'TV3のこまりごと', 'HA');
SELECT test_fx.mk_measure('M3', 'P3', 'TV3のたいさく', 'HA');
SELECT test_fx.mk_trial('T3a', 'M3', 'a1', 4, 'household', 48);
SELECT test_fx.mk_trial('T3b', 'M3', 'a2', 3, 'all', 48);
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P3')), 1, 'TV-3: みんなの③を足すと①が見える');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M3')), 1, 'TV-3: ②も見える');
SELECT is((SELECT l.o_trial_count FROM public.list_measures(test_fx.id('P3')) l), 1, 'TV-3: ③はみんなの1件だけ（o_trial_count = 1）');
SELECT is((SELECT s.o_trial_count FROM public.search_problems(test_fx.id('S1'), 'TV3') s), 1, 'TV-3: 一覧の③の数も1');

-- TV-4: A が①と②x（非公開の③だけ）と②y（みんなの③）を作る → ①と②y だけ見える
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P4', 'S1', 'TV4のこまりごと', 'HA');
SELECT test_fx.mk_measure('M4x', 'P4', 'ひみつのえくす', 'HA');
SELECT test_fx.mk_trial('T4x', 'M4x', 'a1', 5, 'household');
SELECT test_fx.mk_measure('M4y', 'P4', 'おおやけのわい', 'HA');
SELECT test_fx.mk_trial('T4y', 'M4y', 'a1', 3, 'all');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P4')), 1, 'TV-4: ①は見える');
SELECT is((SELECT array_agg(l.o_measure_id) FROM public.list_measures(test_fx.id('P4')) l), ARRAY[test_fx.id('M4y')],
  'TV-4: list_measures(①) は②y だけ（②x が出ない）');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), 'ひみつのえくす')), 0, 'TV-4: ②x の名前で検索しても①が出ない');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), 'おおやけのわい')), 1, 'TV-4（補い）: ②y の名前では①が出る');

-- TV-5: A が①②を作り、③をすべて消す → b1 には見えない（a1 には見える）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P5', 'S1', 'TV5のこまりごと', 'HA');
SELECT test_fx.mk_measure('M5', 'P5', 'TV5のたいさく', 'HA');
SELECT test_fx.mk_trial('T5', 'M5', 'a1', 4, 'all');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P5')), 1, 'TV-5: ③があるうちは b1 に見える');
SELECT test_fx.as_user('a1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.trials WHERE id = %L$$, test_fx.id('T5'))), 1, 'TV-5: a1 が③を消す');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P5')), 0, 'TV-5: ③を全部消すと b1 には①が見えない');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M5')), 0, 'TV-5: ②も見えない');
SELECT test_fx.as_user('a1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P5')), 1, 'TV-5: a1（作った家庭）には見える');

-- TV-6: B が①②を作り、A の非公開③だけ → b1 に①②は見える。A の③は見えない。rename は false
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P6', 'S1', 'TV6のこまりごと', 'HB');
SELECT test_fx.mk_measure('M6', 'P6', 'TV6のたいさく', 'HB');
SELECT test_fx.mk_trial('T6', 'M6', 'a1', 4, 'household');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P6')), 1, 'TV-6: B が作った①は b1 に見える');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M6')), 1, 'TV-6: ②も見える');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T6')), 0, 'TV-6: A の非公開③は見えない');
SELECT is(public.rename_measure(test_fx.id('M6'), '直す'), false, 'TV-6: b1 の rename_measure は false');
SELECT is(public.rename_problem(test_fx.id('P6'), '直す'), false, 'TV-6: b1 の rename_problem は false');

-- TV-7: A の非公開③しか無い年齢（5歳）→ b1 の list_age_counts に5歳の行が無い。a1 にはある
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P7', 'S1', 'TV7のこまりごと', 'HA');
SELECT test_fx.mk_measure('M7', 'P7', 'TV7のたいさく', 'HA');
SELECT test_fx.mk_trial('T7', 'M7', 'a1', 4, 'household', 60);
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.list_age_counts(test_fx.id('S1')) a WHERE a.o_age_years = 5), 0, 'TV-7: b1 には5歳の行が無い');
SELECT test_fx.as_user('a1');
SELECT is((SELECT a.o_problem_count FROM public.list_age_counts(test_fx.id('S1')) a WHERE a.o_age_years = 5), 1, 'TV-7: a1 には5歳の行がある');

-- TV-8（4家庭）: TV-2 の①②は b1・c1・u0a の3家庭すべてから見えない。TV-1 の①②は3家庭すべてから見える
SELECT test_fx.as_user('c1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P2')), 0, 'TV-8: TV-2 の①は c1 に見えない');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P1')), 1, 'TV-8: TV-1 の①は c1 に見える');
SELECT test_fx.as_user('u0a');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P2')), 0, 'TV-8: TV-2 の①は u0a（管理者の家庭）に見えない');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P1')), 1, 'TV-8: TV-1 の①は u0a に見える');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id IN (test_fx.id('M1'), test_fx.id('M2'))), 1,
  'TV-8: b1 には TV-1 の②だけ見える');
SELECT test_fx.as_user('u0b');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id IN (test_fx.id('M1'), test_fx.id('M2'))), 1,
  'TV-8: u0b（H0 の管理者でない人）にも TV-1 の②だけ見える');

-- TV-9（2家庭の場 S2）: X が TV-2・TV-6 と同じ状況を作る → y1 から同じ結果
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('Q2', 'S2', 'S2のTV2', 'HX');
SELECT test_fx.mk_measure('N2', 'Q2', 'S2のTV2たいさく', 'HX');
SELECT test_fx.mk_trial('U2', 'N2', 'x1', 4, 'household');
SELECT test_fx.mk_problem('Q6', 'S2', 'S2のTV6', 'HY');
SELECT test_fx.mk_measure('N6', 'Q6', 'S2のTV6たいさく', 'HY');
SELECT test_fx.mk_trial('U6', 'N6', 'x1', 4, 'household');
SELECT test_fx.as_user('y1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('Q2')), 0, 'TV-9: S2 でも、X の非公開③だけの①は y1 に見えない（TV-2）');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S2'), 'S2のTV2')), 0, 'TV-9: 検索にも出ない（TV-2）');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('Q6')), 1, 'TV-9: Y が作った①は y1 に見える（TV-6）');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('U6')), 0, 'TV-9: X の非公開③は見えない（TV-6）');
SELECT is(public.rename_measure(test_fx.id('N6'), '直す'), false, 'TV-9: y1 の rename_measure は false（TV-6）');
SELECT is(public.rename_problem(test_fx.id('Q6'), '直す'), false, 'TV-9: y1 の rename_problem は false（TV-6）');

SELECT * FROM finish();
ROLLBACK;
