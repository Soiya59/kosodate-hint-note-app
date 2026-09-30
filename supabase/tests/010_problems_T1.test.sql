-- ============================================================
-- 設計書 12-2節「① 困りごと」 T1-R1〜R3・T1-C1〜C3・T1-U1〜U5・T1-T1〜T3・T1-D1〜D6（すべて S1。v0.3 で T1-D1 を false に、T1-D6 を追加）
-- 対応する RLS: problems_select_visible / problems_insert_own_household / problems_update_editable /
--              problems_delete_deletable / problem_tags_*（設計書 3-2節 ①）
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(39);
SELECT test_fx.build();

-- ---------- 読む ----------
-- T1-R1: A が①を作り、A の非公開③だけ → u0a（管理者）には出ない
SELECT test_fx.mk_problem('P_r1', 'S1', 'R1の困りごと', 'HA');
SELECT test_fx.mk_measure('M_r1', 'P_r1', 'R1の対策', 'HA');
SELECT test_fx.mk_trial('T_r1', 'M_r1', 'a1', 4, 'household');
-- T1-R2: A が①を作り、③0件 → a2 には出る
SELECT test_fx.mk_problem('P_r2', 'S1', 'R2の困りごと', 'HA');
-- T1-R3: A が①を作り、A のみんなの③1件 → b1 には出る
SELECT test_fx.mk_problem('P_r3', 'S1', 'R3の困りごと', 'HA');
SELECT test_fx.mk_measure('M_r3', 'P_r3', 'R3の対策', 'HA');
SELECT test_fx.mk_trial('T_r3', 'M_r3', 'a1', 4, 'all');

SELECT test_fx.as_user('u0a');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P_r1')), 0,
  'T1-R1: A の非公開③だけの①は、管理者 u0a にも出ない');
SELECT test_fx.as_user('a2');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P_r2')), 1,
  'T1-R2: A が作った③0件の①は、A の別の人 a2 に出る');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P_r3')), 1,
  'T1-R3: A のみんなの③が1件ある①は、b1 に出る');

-- ---------- 作る ----------
-- T1-C1: u0a が①を作る → 作れる。作った家庭＝H0
SELECT test_fx.as_user('u0a');
SELECT lives_ok($$INSERT INTO public.problems (space_id, name) VALUES (test_fx.id('S1'), 'C1の困りごと')$$,
  'T1-C1: 管理者 u0a が①を作れる');
SELECT test_fx.as_owner();
SELECT is((SELECT p.created_household_id FROM public.problems p WHERE p.name = 'C1の困りごと'), test_fx.id('H0'),
  'T1-C1: 作った家庭は H0（管理者の家庭）');

-- T1-C2: b1 が①を作る → 作った家庭＝HB。タグ「その他」が付いている
SELECT test_fx.as_user('b1');
SELECT lives_ok($$INSERT INTO public.problems (space_id, name) VALUES (test_fx.id('S1'), 'C2の困りごと')$$,
  'T1-C2: b1 が①を作れる');
SELECT test_fx.as_owner();
SELECT is((SELECT p.created_household_id FROM public.problems p WHERE p.name = 'C2の困りごと'), test_fx.id('HB'),
  'T1-C2: 作った家庭は HB');
SELECT is((SELECT array_agg(pt.tag_id) FROM public.problem_tags pt JOIN public.problems p ON p.id = pt.problem_id
            WHERE p.name = 'C2の困りごと'), ARRAY[test_fx.id('tag1_その他')],
  'T1-C2: タグ「その他」が付いている');

-- T1-C3: b1 が created_household_id = HA を付けて直接 INSERT → 作れるが HB に上書き
SELECT test_fx.as_user('b1');
SELECT lives_ok($$INSERT INTO public.problems (space_id, name, created_household_id)
                  VALUES (test_fx.id('S1'), 'C3の困りごと', test_fx.id('HA'))$$,
  'T1-C3: 家庭 HA を付けた INSERT も通る');
SELECT test_fx.as_owner();
SELECT is((SELECT p.created_household_id FROM public.problems p WHERE p.name = 'C3の困りごと'), test_fx.id('HB'),
  'T1-C3: 作った家庭は HB に上書きされる');

-- T1-C1・C2（補い）: 画面の書く画面（F-10）は①を save_trial で作る（設計書 6章）。新しい①②③を1回で作れること。
--   （v0.2 ではこの道が RLS で必ず失敗した＝開発部の修正1。schema v0.3 の W1 で取り込み済み。TR-3 も同じ確かめ）
SELECT test_fx.as_user('b1');
SELECT lives_ok($$SELECT test_fx.save_trial(p_space_id => test_fx.id('S1'), p_problem_name => 'F10の困りごと',
                    p_tag_ids => ARRAY[test_fx.id('tag1_寝る')], p_measure_name => 'F10の対策', p_score => 4)$$,
  'T1-C1（補い）: save_trial で新しい①②③を1回で作れる');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(pt.tag_id) FROM public.problem_tags pt JOIN public.problems p ON p.id = pt.problem_id
            WHERE p.name = 'F10の困りごと'), ARRAY[test_fx.id('tag1_寝る')],
  'T1-C2（補い）: save_trial で選んだタグ「寝る」だけが付く（「その他」は外れる）');
SELECT is((SELECT p.created_household_id FROM public.problems p WHERE p.name = 'F10の困りごと'), test_fx.id('HB'),
  'T1-C2（補い）: save_trial で作った①の家庭は HB');

-- ---------- 名前を直す ----------
-- T1-U1: A の①に B のみんなの③と A の非公開③ → u0a の rename_problem は true
SELECT test_fx.mk_problem('P_u1', 'S1', 'U1の困りごと', 'HA');
SELECT test_fx.mk_measure('M_u1', 'P_u1', 'U1の対策', 'HA');
SELECT test_fx.mk_trial('T_u1b', 'M_u1', 'b1', 3, 'all');
SELECT test_fx.mk_trial('T_u1a', 'M_u1', 'a1', 4, 'household');
SELECT test_fx.as_user('u0a');
SELECT is(public.rename_problem(test_fx.id('P_u1'), 'U1を直した'), true,
  'T1-U1: 管理者はいつでも①の名前を直せる（true）');

-- T1-U2: A の①に A の③だけ → a2 の rename_problem は true
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_u2', 'S1', 'U2の困りごと', 'HA');
SELECT test_fx.mk_measure('M_u2', 'P_u2', 'U2の対策', 'HA');
SELECT test_fx.mk_trial('T_u2', 'M_u2', 'a1', 4, 'all');
SELECT test_fx.as_user('a2');
SELECT is(public.rename_problem(test_fx.id('P_u2'), 'U2を直した'), true,
  'T1-U2: 自家庭の③だけなら、同じ家庭の a2 が直せる（true）');

-- T1-U3: A の①に B のみんなの③ → a1 は false、名前は変わらない
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_u3', 'S1', 'U3の困りごと', 'HA');
SELECT test_fx.mk_measure('M_u3', 'P_u3', 'U3の対策', 'HA');
SELECT test_fx.mk_trial('T_u3', 'M_u3', 'b1', 4, 'all');
SELECT test_fx.as_user('a1');
SELECT is(public.rename_problem(test_fx.id('P_u3'), 'U3を直した'), false,
  'T1-U3: 他家庭のみんなの③が付いた①は、作った家庭の a1 でも直せない（false）');
SELECT is((SELECT p.name FROM public.problems p WHERE p.id = test_fx.id('P_u3')), 'U3の困りごと',
  'T1-U3: 名前は変わらない');

-- T1-U4: A の①に B の非公開③だけ → a1 は false（T1-U3 と同じ返事）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_u4', 'S1', 'U4の困りごと', 'HA');
SELECT test_fx.mk_measure('M_u4', 'P_u4', 'U4の対策', 'HA');
SELECT test_fx.mk_trial('T_u4', 'M_u4', 'b1', 4, 'household');
SELECT test_fx.as_user('a1');
SELECT is(public.rename_problem(test_fx.id('P_u4'), 'U4を直した'), false,
  'T1-U4: 見えない他家庭の③だけでも false（T1-U3 と同じ返事）');

-- T1-U5: A の①（見える）→ b1 の rename_problem は false、直接 UPDATE は0行
SELECT test_fx.as_user('b1');
SELECT is(public.rename_problem(test_fx.id('P_r3'), 'R3を直した'), false,
  'T1-U5: 他家庭が作った①は rename_problem が false');
SELECT is(test_fx.exec_count(format($$UPDATE public.problems SET name = 'R3を直した' WHERE id = %L$$, test_fx.id('P_r3'))), 0,
  'T1-U5: 直接 UPDATE しても0行');

-- ---------- タグを付け外す ----------
-- T1-T1: T1-U2 と同じ状況で、a2 が set_problem_tags（寝る）→ true。タグは「寝る」だけ
SELECT test_fx.as_user('a2');
SELECT is(public.set_problem_tags(test_fx.id('P_u2'), ARRAY[test_fx.id('tag1_寝る')]), true,
  'T1-T1: 自家庭の③だけの①のタグを a2 が付け替えられる（true）');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(pt.tag_id) FROM public.problem_tags pt WHERE pt.problem_id = test_fx.id('P_u2')),
  ARRAY[test_fx.id('tag1_寝る')], 'T1-T1: タグは「寝る」だけ（「その他」は外れる）');

-- T1-T2: T1-U3・U4 と同じ状況で、a1 が set_problem_tags → false。タグは変わらない
SELECT test_fx.as_user('a1');
SELECT is(public.set_problem_tags(test_fx.id('P_u3'), ARRAY[test_fx.id('tag1_寝る')]), false,
  'T1-T2: 他家庭のみんなの③がある①のタグは付け替えられない（false）');
SELECT is(public.set_problem_tags(test_fx.id('P_u4'), ARRAY[test_fx.id('tag1_寝る')]), false,
  'T1-T2: 他家庭の非公開③だけの①も false（同じ返事）');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(pt.tag_id) FROM public.problem_tags pt WHERE pt.problem_id IN (test_fx.id('P_u3'), test_fx.id('P_u4'))),
  ARRAY[test_fx.id('tag1_その他'), test_fx.id('tag1_その他')], 'T1-T2: タグは「その他」のまま変わらない');

-- T1-T3: a2 が set_problem_tags（空）→ true。タグは「その他」だけ
SELECT test_fx.as_user('a2');
SELECT is(public.set_problem_tags(test_fx.id('P_u2'), '{}'::uuid[]), true,
  'T1-T3: 空のタグで set_problem_tags → true');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(pt.tag_id) FROM public.problem_tags pt WHERE pt.problem_id = test_fx.id('P_u2')),
  ARRAY[test_fx.id('tag1_その他')], 'T1-T3: タグは「その他」だけになる');

-- ---------- 消す ----------
-- T1-D1（v0.3）: A の①、③0件（A にだけ見える）→ u0a の delete_problem は false／直接 DELETE は0行。①は残る
--   v0.2 の期待「true」は要件 2-4・U-32 と両立しなかった（開発部の報告 4-1節）。本部長判断 2026-09-30 で要件を正とし false。
SELECT test_fx.mk_problem('P_d1', 'S1', 'D1の困りごと', 'HA');
SELECT test_fx.mk_measure('M_d1', 'P_d1', 'D1の対策', 'HA');
SELECT test_fx.as_user('u0a');
SELECT is(public.delete_problem(test_fx.id('P_d1')), false,
  'T1-D1: A が作った③0件の①は管理者 u0a にも見えないので、delete_problem は false');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.problems WHERE id = %L$$, test_fx.id('P_d1'))), 0,
  'T1-D1: 直接 DELETE しても0行');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P_d1')), 1, 'T1-D1: ①は残る');

-- T1-D6（v0.3）: A が①を作り、その下に H0 が②を作った（③0件）＝ u0a に①が見える → u0a の delete_problem は true。H0 の②も消える
--   同じ形で下に HB の②がある A の①を b1 が消そうとすると false
SELECT test_fx.mk_problem('P_d6', 'S1', 'D6の困りごと', 'HA');
SELECT test_fx.mk_measure('M_d6', 'P_d6', 'D6の対策（H0）', 'H0');
SELECT test_fx.mk_problem('P_d6b', 'S1', 'D6bの困りごと', 'HA');
SELECT test_fx.mk_measure('M_d6b', 'P_d6b', 'D6bの対策（HB）', 'HB');
SELECT test_fx.as_user('u0a');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P_d6')), 1, 'T1-D6: 下に H0 の②がある A の①は u0a に見える');
SELECT is(public.delete_problem(test_fx.id('P_d6')), true, 'T1-D6: 管理者は見える他家庭の③0件の①を消せる（true）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M_d6')), 0, 'T1-D6: 下の H0 の②も CASCADE で消える');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P_d6b')), 1, 'T1-D6: 下に HB の②がある A の①は b1 に見える');
SELECT is(public.delete_problem(test_fx.id('P_d6b')), false, 'T1-D6: 見えていても、作った家庭でも管理者でもない b1 は消せない（false）');

-- T1-D2: A の①に A のみんなの③ → u0a の delete_problem は false
SELECT test_fx.as_user('u0a');
SELECT is(public.delete_problem(test_fx.id('P_r3')), false,
  'T1-D2: ③がある①は管理者でも消せない（false）');

-- T1-D3: A の①、③0件 → a2 の delete_problem は true
SELECT test_fx.as_user('a2');
SELECT is(public.delete_problem(test_fx.id('P_d1')), true,
  'T1-D3: 自家庭が作った③0件の①を a2 が消せる（true）');

-- T1-D4: A の①に A の③だけ → a1 の delete_problem は false
SELECT test_fx.as_user('a1');
SELECT is(public.delete_problem(test_fx.id('P_u2')), false,
  'T1-D4: 自家庭の③でも、③があれば消せない（false）');

-- T1-D5: A の①（見える）、③0件ではない → b1 の直接 DELETE は0行
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.problems WHERE id = %L$$, test_fx.id('P_r3'))), 0,
  'T1-D5: 他家庭の①を直接 DELETE しても0行');

SELECT * FROM finish();
ROLLBACK;
