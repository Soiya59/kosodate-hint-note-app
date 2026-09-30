-- ============================================================
-- 設計書 12-4節「場の区切り」 TS-1〜TS-10
--   S1（4家庭）と S2（2家庭）の間で、読む・書く・直す・消すが一切またがらないこと。
--   um は S1 では家庭B、S2 では家庭X。uo はどの場でもない。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(37);
SELECT test_fx.build();

-- S2 に①②③（みんな）・本・タグ（場を作ったときの11個）・招待を入れる
SELECT test_fx.mk_problem('Q', 'S2', 'S2の困りごと', 'HX');
SELECT test_fx.mk_measure('N', 'Q', 'S2の対策', 'HX');
SELECT test_fx.mk_book('BK2', 'S2', 'S2の本', NULL, 'x1');
SELECT test_fx.mk_trial('U', 'N', 'x1', 4, 'all', 36, DATE '2026-09-01', 'book', 'BK2');
SELECT test_fx.as_user('x1');
SELECT public.create_invite(test_fx.id('HY'));
-- S1 にも少し入れる（TS-6・TS-7 用）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P', 'S1', 'S1の困りごと', 'HB');
SELECT test_fx.mk_measure('M', 'P', 'ひみつS1', 'HB');
SELECT test_fx.mk_trial('T_hb_priv', 'M', 'b1', 4, 'household');
-- S2 で失敗した招待の試行を1件（invite_attempts が読めないことの確かめ用）
SELECT test_fx.as_user('y1');
SELECT public.join_with_invite_code('XXXXXXXX', 'まちがい');

-- TS-1: a1（S1 だけ）が12の表を直接読んでも S2 の行が1件も出ない。一覧・年齢・書き出しは空
SELECT test_fx.as_user('a1');
SELECT is((SELECT count(*)::int FROM public.spaces s WHERE s.id = test_fx.id('S2')), 0, 'TS-1: spaces に S2 が出ない');
SELECT is((SELECT count(*)::int FROM public.households h WHERE h.space_id = test_fx.id('S2')), 0, 'TS-1: households に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.members m WHERE m.space_id = test_fx.id('S2')), 0, 'TS-1: members に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.consents c WHERE c.auth_user_id <> test_fx.uid('a1')), 0, 'TS-1: consents は自分の行だけ');
SELECT is((SELECT count(*)::int FROM public.invites i), 0, 'TS-1: invites は1件も出ない（S2 の招待も、管理者でないので S1 の招待も）');
SELECT is((SELECT count(*)::int FROM public.invite_attempts ia), 0, 'TS-1: invite_attempts は1件も出ない');
SELECT is((SELECT count(*)::int FROM public.tags t WHERE t.space_id = test_fx.id('S2')), 0, 'TS-1: tags に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.space_id = test_fx.id('S2')), 0, 'TS-1: problems に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.problem_tags pt WHERE pt.problem_id = test_fx.id('Q')), 0, 'TS-1: problem_tags に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.measures m WHERE m.space_id = test_fx.id('S2')), 0, 'TS-1: measures に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.books b WHERE b.space_id = test_fx.id('S2')), 0, 'TS-1: books に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.space_id = test_fx.id('S2')), 0, 'TS-1: trials に S2 の行が出ない');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S2'))), 0, 'TS-1: search_problems(S2) は空');
SELECT is((SELECT count(*)::int FROM public.list_age_counts(test_fx.id('S2'))), 0, 'TS-1: list_age_counts(S2) は空');
SELECT is((SELECT jsonb_array_length(e->'households') + jsonb_array_length(e->'members') + jsonb_array_length(e->'tags')
                + jsonb_array_length(e->'problems') + jsonb_array_length(e->'measures') + jsonb_array_length(e->'books')
                + jsonb_array_length(e->'trials')
             FROM (SELECT public.export_visible_data(test_fx.id('S2')) AS e) x), 0,
  'TS-1: export_visible_data(S2) の中身はすべて空');
SELECT is((SELECT e->'space' FROM (SELECT public.export_visible_data(test_fx.id('S2')) AS e) x), 'null'::jsonb,
  'TS-1: export_visible_data(S2) の場の情報も空');

-- TS-2: S2 の②（みんなの③つき）→ a1 が save_trial／直接 INSERT → not_visible。存在しない ID と同じ
SELECT throws_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 3)$$, test_fx.id('N')),
  '42501', 'not_visible', 'TS-2: 別の場の②に save_trial → not_visible');
SELECT throws_ok(format($$INSERT INTO public.trials (measure_id, age_months) VALUES (%L, 36)$$, test_fx.id('N')),
  '42501', 'not_visible', 'TS-2: 別の場の②に直接 INSERT → not_visible');
SELECT throws_ok($$SELECT test_fx.save_trial(p_measure_id => '00000000-0000-0000-0000-00000000dead', p_score => 3)$$,
  '42501', 'not_visible', 'TS-2: 存在しない②の ID でも同じ not_visible');

-- TS-3: S2 の①の ID → a1 の rename_problem・delete_problem は false
SELECT is(public.rename_problem(test_fx.id('Q'), '乗っ取り'), false, 'TS-3: 別の場の①の rename_problem は false');
SELECT is(public.delete_problem(test_fx.id('Q')), false, 'TS-3: 別の場の①の delete_problem は false');

-- TS-4: S1 のタグ ID を、x1 が S2 の①に付ける → 拒否
SELECT test_fx.as_user('x1');
SELECT throws_ok(format($$INSERT INTO public.problem_tags (problem_id, tag_id) VALUES (%L, %L)$$, test_fx.id('Q'), test_fx.id('tag1_寝る')),
  '42501', 'not_visible', 'TS-4: 別の場のタグは付けられない');

-- TS-5: um が S2 の②に save_trial → ③の家庭は HX（HB ではない）
SELECT test_fx.as_user('um');
SELECT test_fx.put('T_um_s2', (test_fx.save_trial(p_measure_id => test_fx.id('N'), p_score => 5, p_visibility => 'household')->>'trial_id')::uuid);
SELECT test_fx.as_owner();
SELECT is((SELECT t.household_id FROM public.trials t WHERE t.id = test_fx.id('T_um_s2')), test_fx.id('HX'),
  'TS-5: um が S2 に書いた③の家庭は HX');
SELECT is((SELECT t.created_by_member_id FROM public.trials t WHERE t.id = test_fx.id('T_um_s2')), test_fx.id('m_um_s2'),
  'TS-5（補い）: 書いた人は S2 での um のメンバー ID');

-- TS-6: S1 の HB の非公開③ → um の search_problems(S2)・export_visible_data(S2) に出ない
SELECT test_fx.as_user('um');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S2'), 'ひみつS1')), 0, 'TS-6: S1 の②の名前で S2 を検索しても出ない');
SELECT ok(position(test_fx.id('T_hb_priv')::text IN public.export_visible_data(test_fx.id('S2'))::text) = 0
      AND position(test_fx.id('P')::text IN public.export_visible_data(test_fx.id('S2'))::text) = 0,
  'TS-6: S1 の③・①は S2 の書き出しに混ざらない');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), 'ひみつS1')), 1,
  'TS-6（補い）: um は S1（家庭B）では自家庭の非公開③の①が見える');

-- TS-7: S2 の HX の非公開③（um が書いた）→ b1（S1 の家庭B。um と同じ家庭）に出ない
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_um_s2')), 0,
  'TS-7: um が S2 に書いた非公開③は、S1 で um と同じ家庭の b1 にも出ない');

-- TS-8: u0a（S1 の管理者）が create_invite(HX)／S2 の家庭を INSERT → 拒否
SELECT test_fx.as_user('u0a');
SELECT throws_ok(format($$SELECT public.create_invite(%L)$$, test_fx.id('HX')), 'P0001', 'not_found',
  'TS-8: 別の場の家庭の招待は作れない（HX が見えないので、存在しない家庭と同じ not_found）');
--   （v0.3 W2）家庭の INSERT は forbidden（42501）。v0.2 では上限のトリガーが先に limit_households を返していた（報告書 4-3節）
SELECT throws_ok($$INSERT INTO public.households (space_id, display_name) VALUES (test_fx.id('S2'), '乗っ取り')$$, '42501', 'forbidden',
  'TS-8: 別の場に家庭を作れない（forbidden・42501）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.households h WHERE h.display_name = '乗っ取り'), 0, 'TS-8: S2 に家庭は増えていない');

-- TS-9: delete_member_data(u0a, um の S1 の行, false) → um の S1 の行が消える。戻り値は NULL
SELECT test_fx.as_service();
SELECT is(public.delete_member_data(test_fx.uid('u0a'), test_fx.id('m_um_s1'), false), NULL::uuid,
  'TS-9: S2 に残る um を S1 から外すと、戻り値は NULL（ログインは消さない）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.members mb WHERE mb.id = test_fx.id('m_um_s1')), 0, 'TS-9: um の S1 の行は消えた');
SELECT is((SELECT count(*)::int FROM public.members mb WHERE mb.id = test_fx.id('m_um_s2')), 1, 'TS-9: um の S2 の行は残る');

-- TS-10: uo（どの場でもない）→ 12の表すべて0行。list_my_spaces は空。anon は権限エラー
SELECT test_fx.as_user('uo');
SELECT is((SELECT (SELECT count(*) FROM public.spaces) + (SELECT count(*) FROM public.households) + (SELECT count(*) FROM public.members)
               + (SELECT count(*) FROM public.consents c WHERE c.auth_user_id <> test_fx.uid('uo'))
               + (SELECT count(*) FROM public.invites) + (SELECT count(*) FROM public.invite_attempts)
               + (SELECT count(*) FROM public.tags) + (SELECT count(*) FROM public.problems) + (SELECT count(*) FROM public.problem_tags)
               + (SELECT count(*) FROM public.measures) + (SELECT count(*) FROM public.books) + (SELECT count(*) FROM public.trials))::int, 0,
  'TS-10: uo には12の表すべてが0行（同意は自分の記録だけ）');
SELECT is((SELECT count(*)::int FROM public.list_my_spaces()), 0, 'TS-10: uo の list_my_spaces は空');
SELECT test_fx.as_anon();
SELECT throws_ok('SELECT count(*) FROM public.problems', '42501', NULL, 'TS-10: anon は表を読むと権限エラー（12の表すべては TG-1）');

SELECT * FROM finish();
ROLLBACK;
