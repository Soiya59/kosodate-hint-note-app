-- ============================================================
-- 設計書 12-5節「2-5節（案A）の受け入れ」 TL-1〜TL-7（S1）
--   直す・消すができないとき、見える他家庭の③が理由でも、見えない③が理由でも、
--   返事（戻り値・エラーの有無）がまったく同じであること。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(18);
SELECT test_fx.build();

-- 状況: 1) B の①②に A の非公開③だけ ／ 2) B の①②に A のみんなの③
SELECT test_fx.mk_problem('P1', 'S1', 'TL1の困りごと', 'HB');
SELECT test_fx.mk_measure('M1', 'P1', 'TL1の対策', 'HB');
SELECT test_fx.mk_trial('T1', 'M1', 'a1', 4, 'household');
SELECT test_fx.mk_problem('P2', 'S1', 'TL2の困りごと', 'HB');
SELECT test_fx.mk_measure('M2', 'P2', 'TL2の対策', 'HB');
SELECT test_fx.mk_trial('T2', 'M2', 'a1', 4, 'all');

SELECT test_fx.as_user('b1');
-- TL-1
SELECT lives_ok(format($$SELECT public.rename_measure(%L, '直す1')$$, test_fx.id('M1')), 'TL-1: A の非公開③だけ → rename_measure はエラーにならない');
SELECT is(public.rename_measure(test_fx.id('M1'), '直す1'), false, 'TL-1: A の非公開③だけ → rename_measure は false');
-- TL-2
SELECT lives_ok(format($$SELECT public.rename_measure(%L, '直す2')$$, test_fx.id('M2')), 'TL-2: A のみんなの③ → rename_measure はエラーにならない（TL-1 と同じ）');
SELECT is(public.rename_measure(test_fx.id('M2'), '直す2'), false, 'TL-2: A のみんなの③ → rename_measure は false（TL-1 と同じ）');
-- TL-3: delete_measure・rename_problem・set_problem_tags・delete_problem もすべて false で、TL-1 と TL-2 で同じ
SELECT is(ARRAY[public.delete_measure(test_fx.id('M1')), public.rename_problem(test_fx.id('P1'), '直す'),
                public.set_problem_tags(test_fx.id('P1'), ARRAY[test_fx.id('tag1_寝る')]), public.delete_problem(test_fx.id('P1'))],
          ARRAY[false, false, false, false], 'TL-3: 非公開③だけの状況で、4つの関数はすべて false');
SELECT is(ARRAY[public.delete_measure(test_fx.id('M2')), public.rename_problem(test_fx.id('P2'), '直す'),
                public.set_problem_tags(test_fx.id('P2'), ARRAY[test_fx.id('tag1_寝る')]), public.delete_problem(test_fx.id('P2'))],
          ARRAY[false, false, false, false], 'TL-3: みんなの③の状況でも、4つの関数はすべて false（同じ返事）');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(m.name ORDER BY m.name) FROM public.measures m WHERE m.id IN (test_fx.id('M1'), test_fx.id('M2'))),
  ARRAY['TL1の対策', 'TL2の対策'], 'TL-1〜3: ②の名前は変わらず、消えてもいない');
SELECT is((SELECT array_agg(p.name ORDER BY p.name) FROM public.problems p WHERE p.id IN (test_fx.id('P1'), test_fx.id('P2'))),
  ARRAY['TL1の困りごと', 'TL2の困りごと'], 'TL-3: ①の名前は変わらず、消えてもいない');
SELECT is((SELECT count(*)::int FROM public.problem_tags pt WHERE pt.problem_id IN (test_fx.id('P1'), test_fx.id('P2')) AND pt.tag_id = test_fx.id('tag1_寝る')), 0,
  'TL-3: タグも変わらない');

-- TL-4: H0 が②を作り、A の非公開③だけ → u0a（管理者）の delete_measure は false
SELECT test_fx.mk_problem('P4', 'S1', 'TL4の困りごと', 'H0');
SELECT test_fx.mk_measure('M4', 'P4', 'TL4の対策', 'H0');
SELECT test_fx.mk_trial('T4', 'M4', 'a1', 4, 'household');
SELECT test_fx.as_user('u0a');
SELECT is(public.delete_measure(test_fx.id('M4')), false, 'TL-4: 見えない③が付いた②は管理者でも消せない（false）');

-- TL-5: B が②を作り、B の③1件と A の非公開③1件 → b1 が自分の③を消したあと delete_measure → ③は消える。false
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P5', 'S1', 'TL5の困りごと', 'HB');
SELECT test_fx.mk_measure('M5', 'P5', 'TL5の対策', 'HB');
SELECT test_fx.mk_trial('T5b', 'M5', 'b1', 3, 'all');
SELECT test_fx.mk_trial('T5a', 'M5', 'a1', 4, 'household');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.trials WHERE id = %L$$, test_fx.id('T5b'))), 1, 'TL-5: b1 は自分の③を消せる');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P5')) l WHERE l.o_trial_count = 0), 1,
  'TL-5（補い）: b1 から見える③は0件になる（画面が「対策も消しますか」を聞く場面）');
SELECT is(public.delete_measure(test_fx.id('M5')), false, 'TL-5: 見えない③が残るので delete_measure は false');

-- TL-6（4家庭）: B の②に、A の非公開③だけ／C の非公開③だけ → b1 の rename_measure はどちらも false で同じ
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P6', 'S1', 'TL6の困りごと', 'HB');
SELECT test_fx.mk_measure('M6a', 'P6', 'TL6の対策A', 'HB');
SELECT test_fx.mk_trial('T6a', 'M6a', 'a1', 4, 'household');
SELECT test_fx.mk_measure('M6c', 'P6', 'TL6の対策C', 'HB');
SELECT test_fx.mk_trial('T6c', 'M6c', 'c1', 4, 'household');
SELECT test_fx.as_user('b1');
SELECT is(ARRAY[public.rename_measure(test_fx.id('M6a'), '直す'), public.rename_measure(test_fx.id('M6c'), '直す')],
          ARRAY[false, false], 'TL-6: A の非公開③でも C の非公開③でも false で同じ（どの家庭かは分からない）');

-- TL-7（v0.2。本）: b1 が登録した本を、A の非公開③だけが使う／A のみんなの③だけが使う → delete_book はどちらも false、本は残る
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P7', 'S1', 'TL7の困りごと', 'HA');
SELECT test_fx.mk_measure('M7', 'P7', 'TL7の対策', 'HA');
SELECT test_fx.mk_book('BK_priv', 'S1', '非公開③が使う本', NULL, 'b1');
SELECT test_fx.mk_book('BK_pub', 'S1', 'みんなの③が使う本', NULL, 'b1');
SELECT test_fx.mk_trial('T7p', 'M7', 'a1', 4, 'household', 36, DATE '2026-09-01', 'book', 'BK_priv');
SELECT test_fx.mk_trial('T7a', 'M7', 'a1', 4, 'all', 36, DATE '2026-09-01', 'book', 'BK_pub');
SELECT test_fx.as_user('b1');
SELECT lives_ok(format($$SELECT public.delete_book(%L)$$, test_fx.id('BK_priv')), 'TL-7: 非公開③が使う本 → delete_book はエラーにならない');
SELECT lives_ok(format($$SELECT public.delete_book(%L)$$, test_fx.id('BK_pub')), 'TL-7: みんなの③が使う本 → delete_book はエラーにならない（同じ）');
SELECT is(ARRAY[public.delete_book(test_fx.id('BK_priv')), public.delete_book(test_fx.id('BK_pub'))], ARRAY[false, false],
  'TL-7: どちらも false（返事がまったく同じ）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.books b WHERE b.id IN (test_fx.id('BK_priv'), test_fx.id('BK_pub'))), 2, 'TL-7: 本は2冊とも残る');

SELECT * FROM finish();
ROLLBACK;
