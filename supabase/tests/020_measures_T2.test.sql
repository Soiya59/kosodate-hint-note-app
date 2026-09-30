-- ============================================================
-- 設計書 12-2節「② 対策」（すべて S1）
--   T2-R1〜R3・C1・U1〜U5・D1〜D5 は ①の表の①を②に読み替えたもの（関数は rename_measure・delete_measure）。
--   T2-C2・T2-C3・T2-M1 は設計書の「加えて」の表のとおり。
--   （v0.3）設計書 12-2節 ② は全部書き出され、この組み方と同じになった。T2-D1 を false に、T2-D6 を追加。
--   ①の T1-C2・T1-C3 に当たる確かめ（家庭の上書き）は、番号が「加えて」の T2-C2・C3 と重なるので T2-C1 にまとめた。
-- 対応する RLS: measures_select_visible / measures_insert_under_visible_problem / measures_update_editable /
--              measures_delete_deletable ＋ トリガー immutable_column（設計書 3-2節 ②）
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(25);
SELECT test_fx.build();

-- 共通の①（A が作り、A のみんなの③があるので全員に見える）
SELECT test_fx.mk_problem('P', 'S1', '共通の困りごと', 'HA');
SELECT test_fx.mk_measure('M_pub', 'P', '見える対策', 'HA');
SELECT test_fx.mk_trial('T_pub', 'M_pub', 'a1', 4, 'all');

-- ---------- 読む ----------
SELECT test_fx.mk_measure('M_r1', 'P', 'R1の対策', 'HA');
SELECT test_fx.mk_trial('T_r1', 'M_r1', 'a1', 4, 'household');
SELECT test_fx.mk_measure('M_r2', 'P', 'R2の対策', 'HA');
SELECT test_fx.as_user('u0a');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M_r1')), 0,
  'T2-R1: A の非公開③だけの②は、管理者 u0a にも出ない');
SELECT test_fx.as_user('a2');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M_r2')), 1,
  'T2-R2: A が作った③0件の②は、a2 に出る');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M_pub')), 1,
  'T2-R3: A のみんなの③がある②は、b1 に出る');

-- ---------- 作る ----------
SELECT test_fx.as_user('u0a');
SELECT lives_ok($$INSERT INTO public.measures (problem_id, name) VALUES (test_fx.id('P'), 'C1の対策（管理者）')$$,
  'T2-C1: 管理者 u0a が見える①の下に②を作れる');
SELECT test_fx.as_user('b1');
SELECT lives_ok($$INSERT INTO public.measures (problem_id, name, created_household_id)
                  VALUES (test_fx.id('P'), 'C1の対策（b1）', test_fx.id('HA'))$$,
  'T2-C1: b1 が家庭 HA を付けて②を INSERT しても通る');
SELECT test_fx.as_owner();
SELECT is((SELECT m.created_household_id FROM public.measures m WHERE m.name = 'C1の対策（管理者）'), test_fx.id('H0'),
  'T2-C1: 管理者が作った②の家庭は H0');
SELECT is((SELECT m.created_household_id FROM public.measures m WHERE m.name = 'C1の対策（b1）'), test_fx.id('HB'),
  'T2-C1: b1 が作った②の家庭は HB に上書きされる');

-- T2-C2: A の①（A の非公開③だけ＝B に見えない）→ b1 がその下に②を INSERT → not_visible。存在しない①と同じエラー
SELECT test_fx.mk_problem('P_hidden', 'S1', '見えない困りごと', 'HA');
SELECT test_fx.mk_measure('M_hidden', 'P_hidden', '見えない対策', 'HA');
SELECT test_fx.mk_trial('T_hidden', 'M_hidden', 'a1', 4, 'household');
SELECT test_fx.as_user('b1');
SELECT throws_ok(format($$INSERT INTO public.measures (problem_id, name) VALUES (%L, 'のぞき見')$$, test_fx.id('P_hidden')),
  '42501', 'not_visible', 'T2-C2: 見えない①の下に②を作ろうとすると not_visible');
SELECT throws_ok($$INSERT INTO public.measures (problem_id, name) VALUES ('00000000-0000-0000-0000-00000000dead', 'のぞき見')$$,
  '42501', 'not_visible', 'T2-C2: 存在しない①の ID でも同じ not_visible');

-- T2-C3: 同じ①を save_trial で指定 → 同じ拒否
SELECT throws_ok(format($$SELECT test_fx.save_trial(p_space_id => %L, p_problem_id => %L, p_measure_name => 'のぞき見', p_score => 3)$$,
  test_fx.id('S1'), test_fx.id('P_hidden')),
  '42501', 'not_visible', 'T2-C3: save_trial で見えない①を指定しても同じ not_visible');

-- ---------- 名前を直す ----------
SELECT test_fx.mk_measure('M_u1', 'P', 'U1の対策', 'HA');
SELECT test_fx.mk_trial('T_u1b', 'M_u1', 'b1', 3, 'all');
SELECT test_fx.mk_trial('T_u1a', 'M_u1', 'a1', 4, 'household');
SELECT test_fx.mk_measure('M_u2', 'P', 'U2の対策', 'HA');
SELECT test_fx.mk_trial('T_u2', 'M_u2', 'a1', 4, 'all');
SELECT test_fx.mk_measure('M_u3', 'P', 'U3の対策', 'HA');
SELECT test_fx.mk_trial('T_u3', 'M_u3', 'b1', 4, 'all');
SELECT test_fx.mk_measure('M_u4', 'P', 'U4の対策', 'HA');
SELECT test_fx.mk_trial('T_u4', 'M_u4', 'b1', 4, 'household');

SELECT test_fx.as_user('u0a');
SELECT is(public.rename_measure(test_fx.id('M_u1'), 'U1を直した'), true,
  'T2-U1: 管理者はいつでも②の名前を直せる（true）');
SELECT test_fx.as_user('a2');
SELECT is(public.rename_measure(test_fx.id('M_u2'), 'U2を直した'), true,
  'T2-U2: 自家庭の③だけの②は a2 が直せる（true）');
SELECT test_fx.as_user('a1');
SELECT is(public.rename_measure(test_fx.id('M_u3'), 'U3を直した'), false,
  'T2-U3: 他家庭のみんなの③がある②は a1 が直せない（false）');
SELECT is(public.rename_measure(test_fx.id('M_u4'), 'U4を直した'), false,
  'T2-U4: 他家庭の非公開③だけでも false（同じ返事）');
SELECT test_fx.as_user('b1');
SELECT is(public.rename_measure(test_fx.id('M_pub'), '直した'), false,
  'T2-U5: 他家庭が作った②は rename_measure が false');
SELECT is(test_fx.exec_count(format($$UPDATE public.measures SET name = '直した' WHERE id = %L$$, test_fx.id('M_pub'))), 0,
  'T2-U5: 直接 UPDATE しても0行');

-- T2-M1: a1 が problem_id を別の①に変える → immutable_column
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_other', 'S1', '別の困りごと', 'HA');
SELECT test_fx.as_user('a1');
SELECT throws_ok(format($$UPDATE public.measures SET problem_id = %L WHERE id = %L$$, test_fx.id('P_other'), test_fx.id('M_u2')),
  'P0001', 'immutable_column', 'T2-M1: ②の属する①は付け替えられない（immutable_column）');

-- ---------- 消す ----------
-- T2-D1（v0.3）: A の②、③0件（A にだけ見える）→ u0a の delete_measure は false。②は残る（T1-D1 と同じ理由。本部長判断 2026-09-30）
SELECT test_fx.as_owner();
SELECT test_fx.mk_measure('M_d1', 'P', 'D1の対策', 'HA');
SELECT test_fx.as_user('u0a');
SELECT is(public.delete_measure(test_fx.id('M_d1')), false,
  'T2-D1: A が作った③0件の②は管理者 u0a にも見えないので、delete_measure は false');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M_d1')), 1, 'T2-D1: ②は残る');
-- T2-D6（v0.3）: H0 が作った②、③0件 → u0a の delete_measure は true
SELECT test_fx.mk_measure('M_d6', 'P', 'D6の対策（H0）', 'H0');
SELECT test_fx.as_user('u0a');
SELECT is(public.delete_measure(test_fx.id('M_d6')), true, 'T2-D6: 管理者は自家庭（H0）が作った③0件の②を消せる（true）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M_d6')), 0, 'T2-D6: ②が消えている');

SELECT test_fx.as_user('u0a');
SELECT is(public.delete_measure(test_fx.id('M_pub')), false,
  'T2-D2: ③がある②は管理者でも消せない（false）');
SELECT test_fx.as_user('a2');
SELECT is(public.delete_measure(test_fx.id('M_d1')), true,
  'T2-D3: 自家庭が作った③0件の②を a2 が消せる（true）');
SELECT test_fx.as_user('a1');
SELECT is(public.delete_measure(test_fx.id('M_u2')), false,
  'T2-D4: 自家庭の③でも、③があれば消せない（false）');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.measures WHERE id = %L$$, test_fx.id('M_pub'))), 0,
  'T2-D5: 他家庭の②を直接 DELETE しても0行');

SELECT * FROM finish();
ROLLBACK;
