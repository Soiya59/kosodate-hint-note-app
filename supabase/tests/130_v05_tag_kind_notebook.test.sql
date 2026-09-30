-- v0.5 の確かめ42件（設計書 v0.5 12-8節の番号）。設計部が一時の場所で書いて通したもの（2026-09-30）を、設計書 12-8節「そのまま写してよい」に従い開発部が写した（中身は変えていない）。
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(42);
SELECT test_fx.build();

-- ===================== TG5: 最初のタグと並び（Y1・Y2）
SELECT is((SELECT count(*)::int FROM public.tags tg WHERE tg.space_id = test_fx.id('S1')), 24, 'TG5-1: 場を作ると最初のタグは24個');
SELECT is((SELECT string_agg(tg.kind || ':' || c, ',' ORDER BY tg.kind) FROM (SELECT t.kind, count(*) c FROM public.tags t WHERE t.space_id = test_fx.id('S1') GROUP BY t.kind) tg),
  'both:2,grow:13,trouble:9', 'TG5-1: 困りごと9・育てたい13・両方2');
SELECT is((SELECT array_agg(tg.name ORDER BY tg.kind) FROM public.tags tg WHERE tg.space_id = test_fx.id('S1') AND tg.kind = 'both'), ARRAY['ことば','その他'], 'TG5-1: 両方は「ことば」「その他」');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(tg.name ORDER BY tg.sort_order) FROM public.tags tg WHERE tg.space_id = test_fx.id('S1') AND tg.kind IN ('trouble', 'both')),
  ARRAY['寝る','食べる','トイレ','着替え・身支度','ことば','気持ち・かんしゃく','きょうだい','友だち・園・学校','スマホ・テレビ','外出','その他'],
  'TG5-2: 困りごとの並び（sort_order。v0.4 までの11個と同じ順）');
SELECT is((SELECT array_agg(tg.name ORDER BY tg.grow_sort_order) FROM public.tags tg WHERE tg.space_id = test_fx.id('S1') AND tg.kind IN ('grow', 'both')),
  ARRAY['自己肯定感','やり抜く力','集中力','考える力','好奇心','自制心','ことば','運動','勉強','料理','思いやり','人との関わり','気持ちの整理','自分でする力','その他'],
  'TG5-3: 育てたいの並び（grow_sort_order。「ことば」は7番目）');
SELECT is((SELECT array_agg(tg.name ORDER BY tg.sort_order) FROM public.tags tg WHERE tg.space_id = test_fx.id('S1')),
  ARRAY['寝る','食べる','トイレ','着替え・身支度','ことば','気持ち・かんしゃく','きょうだい','友だち・園・学校','スマホ・テレビ','外出',
        '自己肯定感','やり抜く力','集中力','考える力','好奇心','自制心','運動','勉強','料理','思いやり','人との関わり','気持ちの整理','自分でする力','その他'],
  'TG5-4: ［すべて］の並び（困りごと → 育てたいだけ → その他）');

-- ===================== TG5: ①に付けられるタグ（Y3）
SELECT is((SELECT (public.save_trial(test_fx.id('S1'), NULL, '育つ①', ARRAY[test_fx.id('tag1_集中力'), test_fx.id('tag1_ことば')], NULL, '②', 3::smallint, 36::smallint,
              NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'grow', NULL, NULL, NULL)) ->> 'problem_id' IS NOT NULL), true, 'TG5-5: 育てたいの①に育てたい・両方のタグを付けて書ける');
SELECT is((SELECT array_agg(tg.name ORDER BY tg.name) FROM public.problem_tags pt JOIN public.tags tg ON tg.id = pt.tag_id JOIN public.problems pr ON pr.id = pt.problem_id WHERE pr.name = '育つ①'),
  ARRAY['ことば','集中力'], 'TG5-5: 付いたタグ（「その他」は外れる）');
SELECT throws_ok(format($$SELECT public.save_trial(%L, NULL, '育つ②', ARRAY[%L]::uuid[], NULL, '②', 3::smallint, 36::smallint, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'grow', NULL, NULL, NULL)$$,
  test_fx.id('S1'), test_fx.id('tag1_寝る')), 'P0001', 'tag_kind_mismatch', 'TG5-6: 育てたいの①に困りごとのタグは付けられない（書く全体が取り消し）');
SELECT is((SELECT count(*)::int FROM public.problems pr WHERE pr.name = '育つ②'), 0, 'TG5-6: ①は残らない（1つの処理）');
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_t', 'S1', '困る①', 'HB');
SELECT test_fx.as_user('b1');
SELECT throws_ok(format($$SELECT public.set_problem_tags(%L, ARRAY[%L]::uuid[])$$, test_fx.id('P_t'), test_fx.id('tag1_思いやり')), 'P0001', 'tag_kind_mismatch',
  'TG5-6: 困りごとの①に set_problem_tags で育てたいのタグ → tag_kind_mismatch');
SELECT throws_ok(format($$INSERT INTO public.problem_tags (problem_id, tag_id) VALUES (%L, %L)$$, test_fx.id('P_t'), test_fx.id('tag1_思いやり')), 'P0001', 'tag_kind_mismatch',
  'TG5-6: 表へ直接 INSERT しても同じ');
SELECT is(public.set_problem_tags(test_fx.id('P_t'), ARRAY[test_fx.id('tag1_寝る'), test_fx.id('tag1_ことば')]), true, 'TG5-6: 困りごと・両方のタグは付けられる');

-- ===================== TG5: ①の種類を変えたとき（Y4）
SELECT is(public.set_problem_kind(test_fx.id('P_t'), 'grow'), true, 'TG5-7: 種類を育てたいに変える');
SELECT is((SELECT array_agg(tg.name) FROM public.problem_tags pt JOIN public.tags tg ON tg.id = pt.tag_id WHERE pt.problem_id = test_fx.id('P_t')),
  ARRAY['ことば'], 'TG5-7: 合わない「寝る」は外れ、両方の「ことば」は残る');
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_t2', 'S1', '寝るだけの①', 'HB');
SELECT test_fx.as_user('b1');
SELECT is(public.set_problem_tags(test_fx.id('P_t2'), ARRAY[test_fx.id('tag1_寝る')]), true, 'TG5-8: タグは「寝る」だけ');
SELECT is(public.set_problem_kind(test_fx.id('P_t2'), 'grow'), true, 'TG5-8: 種類を育てたいに変える');
SELECT is((SELECT array_agg(tg.name) FROM public.problem_tags pt JOIN public.tags tg ON tg.id = pt.tag_id WHERE pt.problem_id = test_fx.id('P_t2')),
  ARRAY['その他'], 'TG5-8: タグが0個になったら「その他」');
SELECT is(public.set_problem_kind(test_fx.id('P_t2'), 'trouble'), true, 'TG5-8: 困りごとに戻す');
SELECT is((SELECT array_agg(tg.name) FROM public.problem_tags pt JOIN public.tags tg ON tg.id = pt.tag_id WHERE pt.problem_id = test_fx.id('P_t2')),
  ARRAY['その他'], 'TG5-8: 「その他」は両方なのでそのまま');
SELECT test_fx.as_user('c1');
SELECT is(public.set_problem_kind(test_fx.id('P_t'), 'trouble'), false, 'TG5-9: 変えられない人（他家庭）は false');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(tg.name) FROM public.problem_tags pt JOIN public.tags tg ON tg.id = pt.tag_id WHERE pt.problem_id = test_fx.id('P_t')),
  ARRAY['ことば'], 'TG5-9: false のときはタグも変わらない');

-- ===================== TG5: 管理者がタグを足す（Y5）
SELECT test_fx.as_user('u0a');
SELECT lives_ok($$INSERT INTO public.tags (space_id, name, kind) VALUES (test_fx.id('S1'), '早寝早起き', 'grow')$$, 'TG5-10: 育てたいのタグを足せる');
SELECT lives_ok($$INSERT INTO public.tags (space_id, name, kind) VALUES (test_fx.id('S1'), 'あそび', 'both')$$, 'TG5-10: 両方のタグを足せる');
SELECT lives_ok($$INSERT INTO public.tags (space_id, name) VALUES (test_fx.id('S1'), '病院')$$, 'TG5-10: 種類を送らないと困りごと');
SELECT test_fx.as_owner();
SELECT is((SELECT string_agg(tg.name || ':' || tg.kind || ':' || tg.sort_order || ':' || coalesce(tg.grow_sort_order::text, '-'), ',' ORDER BY tg.created_at, tg.name)
             FROM public.tags tg WHERE tg.space_id = test_fx.id('S1') AND tg.name IN ('早寝早起き', 'あそび', '病院')),
  'あそび:both:11:16,早寝早起き:grow:115:15,病院:trouble:12:-', 'TG5-10: 並び順はトリガーが種類ごとに決める（どれも「その他」の前）');
SELECT test_fx.as_user('u0a');
SELECT throws_ok($$INSERT INTO public.tags (space_id, name, kind) VALUES (test_fx.id('S1'), '変な種類', 'x')$$, '23514', NULL, 'TG5-11: 種類の値の誤りは 23514');
SELECT throws_ok($$SELECT app_private.seed_default_tags(test_fx.id('S1'))$$, '42501', NULL, 'TG5-12: ログインした人は最初のタグを入れる関数を使えない');
SELECT test_fx.as_owner();
SELECT lives_ok($$SELECT app_private.seed_default_tags(test_fx.id('S1'))$$, 'TG5-12: 運営者（持ち主）はもう一度呼べる');
SELECT is((SELECT count(*)::int FROM public.tags tg WHERE tg.space_id = test_fx.id('S1')), 27, 'TG5-12: 何度呼んでも増えない（24＋足した3）');

-- ===================== TSo5: このノートで知った（Y6）
SELECT test_fx.mk_problem('P_n', 'S1', 'ノートの①', 'HA');
SELECT test_fx.mk_measure('M_n', 'P_n', 'ノートの②', 'HA');
SELECT test_fx.mk_trial('T_n', 'M_n', 'a1', 4);
SELECT test_fx.as_user('b1');
SELECT lives_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, 3::smallint, 36::smallint, 'notebook', NULL, NULL, NULL, NULL, NULL, NULL)$$, test_fx.id('M_n')),
  'TSo5-1: 「このノートで知った」で書ける（うちでも試した）');
SELECT throws_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, 3::smallint, 36::smallint, 'notebook', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '兄の家')$$, test_fx.id('M_n')),
  '23514', NULL, 'TSo5-2: 「このノートで知った」に詳細の文字は付けられない');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P_n'), 'notebook')), 1, 'TSo5-3: 出典のタブ「このノート」で絞れる');

-- ===================== TA5: まとまりの関数は無い（Y7）
SELECT hasnt_function('public', 'list_age_band_counts', 'TA5-1: list_age_band_counts は消した');

-- ===================== TE-5: 書き出しに書いた人（Y8）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_e', 'S1', '書き出しの①', 'HA');
SELECT test_fx.mk_measure('M_e', 'P_e', '書き出しの②', 'HA');
SELECT test_fx.mk_trial('T_e1', 'M_e', 'a1', 4, 'all');
SELECT test_fx.mk_trial('T_e2', 'M_e', 'a1', 3, 'household');
SELECT test_fx.as_user('b1');
SELECT is((SELECT x ->> 'created_by_name' FROM jsonb_array_elements(public.export_visible_data(test_fx.id('S1')) -> 'trials') x WHERE x ->> 'id' = test_fx.id('T_e1')::text),
  'Aの夫', 'TE-5: 書き出しの③に書いた人の呼び名');
SELECT is((SELECT count(*)::int FROM jsonb_array_elements(public.export_visible_data(test_fx.id('S1')) -> 'trials') x WHERE x ->> 'id' = test_fx.id('T_e2')::text),
  0, 'TE-5: 他家庭の非公開③は入らない（見え方は変わらない）');
SELECT test_fx.as_user('a1');
SELECT is((SELECT count(*)::int FROM jsonb_array_elements(public.export_visible_data(test_fx.id('S1')) -> 'trials') x WHERE x ->> 'id' IN (test_fx.id('T_e1')::text, test_fx.id('T_e2')::text) AND x ->> 'created_by_name' = 'Aの夫'),
  2, 'TE-5: 自家庭の非公開③も呼び名つきで入る');
SELECT test_fx.as_owner();
SELECT public.delete_member_data(test_fx.uid('u0a'), test_fx.id('m_a1'), false);
SELECT test_fx.as_user('a2');
SELECT is((SELECT coalesce(x ->> 'created_by_name', '空') || '/' || coalesce(x ->> 'created_by_member_id', '空') FROM jsonb_array_elements(public.export_visible_data(test_fx.id('S1')) -> 'trials') x WHERE x ->> 'id' = test_fx.id('T_e1')::text),
  '空/空', 'TE-5: 書いた人が外されたら呼び名・メンバー ID は null');

-- ===================== TSt-8: 直すモードの日付（本部長判断）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_d', 'S1', '日付の①', 'HB');
SELECT test_fx.mk_measure('M_d', 'P_d', '日付の②', 'HB');
INSERT INTO public.trials (measure_id, household_id, created_by_member_id, status, age_months, tried_on)
  VALUES (test_fx.id('M_d'), test_fx.id('HB'), test_fx.id('m_b1'), 'want', 24, DATE '2026-09-01'),
         (test_fx.id('M_d'), test_fx.id('HB'), test_fx.id('m_b1'), 'want', 30, DATE '2026-09-01');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET status = 'scored', score = 3, tried_on = DATE '2026-09-01' WHERE measure_id = %L AND age_months = 24$$, test_fx.id('M_d'))), 1, 'TSt-8: 同じ日付を送って直す');
SELECT is((SELECT tr.tried_on = (now() AT TIME ZONE 'Asia/Tokyo')::date FROM public.trials tr WHERE tr.measure_id = test_fx.id('M_d') AND tr.age_months = 24), true, 'TSt-8: 前と同じ日付なら今日になる');
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET status = 'trying', tried_on = DATE '2026-09-10' WHERE measure_id = %L AND age_months = 30$$, test_fx.id('M_d'))), 1, 'TSt-8: 違う日付を送って直す');
SELECT is((SELECT tr.tried_on FROM public.trials tr WHERE tr.measure_id = test_fx.id('M_d') AND tr.age_months = 30), DATE '2026-09-10', 'TSt-8: 違う日付ならその日付');

SELECT * FROM finish();
ROLLBACK;
