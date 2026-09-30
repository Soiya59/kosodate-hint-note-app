-- v0.4 の確かめ60件（設計書 v0.4 12-7節の番号）。設計部が一時の場所で書いて通したもの（2026-09-30）を、設計書 12-7節「そのまま写してよい」に従い開発部が写した（中身は変えていない）。
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(59);
SELECT test_fx.build();

-- 見本: 状態・範囲つきの③を持ち主の権限で入れる道具（このファイルの中だけ。ROLLBACK で消える）
CREATE FUNCTION test_fx.mk_trial4(
  p_key text, p_measure text, p_member text, p_status text, p_score integer,
  p_age integer, p_age_to integer DEFAULT NULL, p_visibility text DEFAULT 'all',
  p_tried_on date DEFAULT DATE '2026-09-01', p_source_type text DEFAULT 'own', p_source_text text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v uuid; v_member uuid := test_fx.id('m_' || p_member); v_hh uuid;
BEGIN
  SELECT mb.household_id INTO v_hh FROM public.members mb WHERE mb.id = v_member;
  INSERT INTO public.trials (measure_id, household_id, created_by_member_id, updated_by_member_id,
                             status, score, age_months, age_months_to, source_type, source_text, tried_on, visibility)
  VALUES (test_fx.id(p_measure), v_hh, v_member, v_member, p_status, p_score, p_age, p_age_to,
          p_source_type, p_source_text, p_tried_on, p_visibility)
  RETURNING id INTO v;
  RETURN test_fx.put(p_key, v);
END $$;

-- ===================== TK: ①の種類（X1・X6・X9・X10・X11）
SELECT test_fx.as_user('b1');
SELECT is((SELECT (test_fx.save_trial(p_space_id => test_fx.id('S1'), p_problem_name => '困る①', p_measure_name => '②a', p_score => 3)) ->> 'trial_id' IS NOT NULL), true,
  'TK-1: 種類を送らずに①を作れる');
SELECT is((SELECT pr.kind FROM public.problems pr WHERE pr.name = '困る①'), 'trouble', 'TK-1: 種類を送らないと困りごと');
SELECT is((SELECT public.save_trial(test_fx.id('S1'), NULL, '育てる①', NULL, NULL, '②b', 3::smallint, 36::smallint, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                                    'grow', NULL, NULL, NULL) ->> 'trial_id' IS NOT NULL), true, 'TK-2: save_trial の p_problem_kind で育てたいを作れる');
SELECT is((SELECT pr.kind FROM public.problems pr WHERE pr.name = '育てる①'), 'grow', 'TK-2: 種類は grow');
SELECT is((SELECT array_agg(o_name ORDER BY o_name) FROM public.search_problems(test_fx.id('S1'), p_kind => 'grow')), ARRAY['育てる①'], 'TK-3: p_kind=grow は育てたいだけ');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), p_kind => 'trouble') WHERE o_name = '育てる①'), 0, 'TK-3: p_kind=trouble に育てたいは出ない');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'))), 2, 'TK-3: p_kind なし＝すべて');
SELECT is((SELECT o_kind FROM public.search_problems(test_fx.id('S1')) WHERE o_name = '育てる①'), 'grow', 'TK-3: o_kind');
SELECT is((SELECT o_kind FROM public.suggest_problems(test_fx.id('S1'), '育てる')), 'grow', 'TK-4: suggest_problems の o_kind');
-- 同じ名前が別の種類にあってもよい
SELECT lives_ok($$SELECT public.save_trial(test_fx.id('S1'), NULL, '育てる①', NULL, NULL, '②c', 3::smallint, 36::smallint, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'trouble', NULL, NULL, NULL)$$,
  'TK-5: 同じ名前の①を別の種類で作れる');
-- 種類を変える: 名前を直すのと同じ条件
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_k', 'S1', '種類を変える①', 'HA');
SELECT test_fx.mk_measure('M_k', 'P_k', '種類の②', 'HA');
SELECT test_fx.mk_trial('T_k', 'M_k', 'a1', 4);
SELECT test_fx.as_user('a2');
SELECT is(public.set_problem_kind(test_fx.id('P_k'), 'grow'), true, 'TK-6: 自家庭の③だけなら作った家庭が種類を変えられる');
SELECT test_fx.as_owner();
SELECT is((SELECT pr.kind FROM public.problems pr WHERE pr.id = test_fx.id('P_k')), 'grow', 'TK-6: 変わった');
SELECT test_fx.mk_trial4('T_kw', 'M_k', 'b1', 'want', NULL, 24, NULL, 'household');
SELECT test_fx.as_user('a2');
SELECT is(public.set_problem_kind(test_fx.id('P_k'), 'trouble'), false, 'TK-7: 他家庭の③（非公開の試したい）が付いたら false（試したいも③として数える＝⑧）');
SELECT is(public.rename_problem(test_fx.id('P_k'), '新しい名前'), false, 'TK-7: 名前を直すのも同じく false');
SELECT test_fx.as_user('u0a');
SELECT is(public.set_problem_kind(test_fx.id('P_k'), 'trouble'), true, 'TK-8: 管理者はいつでも変えられる');
SELECT throws_ok(format($$SELECT public.set_problem_kind(%L, 'other')$$, test_fx.id('P_k')), '23514', NULL, 'TK-8: 種類の値の誤りは 23514');
SELECT test_fx.as_user('c1');
SELECT is(public.set_problem_kind(test_fx.id('P_k'), 'grow'), false, 'TK-9: 他家庭が作った①は false');

-- ===================== TSt: ③の状態（X2・X5・X10）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_s', 'S1', '状態の①', 'HB');
SELECT test_fx.mk_measure('M_s', 'P_s', '状態の②', 'HB');
SELECT test_fx.as_user('b1');
SELECT is((SELECT public.save_trial(NULL, NULL, NULL, NULL, test_fx.id('M_s'), NULL, NULL, 24::smallint, 'book', NULL, NULL, NULL, NULL, NULL, NULL,
                                    NULL, 'want', 36::smallint, NULL) ->> 'trial_id' IS NOT NULL), true, 'TSt-1: 試したい（2〜3歳）を書ける');
SELECT is((SELECT tr.status || '/' || coalesce(tr.score::text, '空') || '/' || tr.age_months || '-' || tr.age_months_to FROM public.trials tr WHERE tr.measure_id = test_fx.id('M_s')),
  'want/空/24-36', 'TSt-1: 状態 want・点数は空・年齢 24〜36');
SELECT throws_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, 4::smallint, 24::smallint, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'want', NULL, NULL)$$, test_fx.id('M_s')),
  '23514', NULL, 'TSt-2: 試したいに点数を付けて書くと 23514');
SELECT throws_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, NULL, 24::smallint, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'scored', NULL, NULL)$$, test_fx.id('M_s')),
  '23514', NULL, 'TSt-2: 試したで点数が無いと 23514');
SELECT test_fx.as_owner();
SELECT test_fx.mk_trial4('T_w1', 'M_s', 'b1', 'want', NULL, 24, NULL, 'all', DATE '2026-09-01');
SELECT test_fx.mk_trial4('T_w2', 'M_s', 'b1', 'want', NULL, 24, NULL, 'all', DATE '2026-09-01');
SELECT test_fx.mk_trial4('T_w3', 'M_s', 'b1', 'want', NULL, 24, NULL, 'all', DATE '2026-09-01');
SELECT test_fx.mk_trial4('T_sc', 'M_s', 'b1', 'scored', 4, 24);
SELECT test_fx.as_user('b1');
-- 点数だけを UPDATE（v0.3 の setTrialScore の書き方）→ 試した・日付は今日
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET score = 5 WHERE id = %L$$, test_fx.id('T_w1'))), 1, 'TSt-3: 試したいに点数だけを付ける UPDATE が通る');
SELECT is((SELECT tr.status || '/' || (tr.tried_on = (now() AT TIME ZONE 'Asia/Tokyo')::date) FROM public.trials tr WHERE tr.id = test_fx.id('T_w1')), 'scored/true',
  'TSt-3: 状態は試した・日付は今日');
-- [試し始めた]: 状態を試し中に → 日付は今日
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET status = 'trying', age_months = 30, age_months_to = NULL WHERE id = %L$$, test_fx.id('T_w2'))), 1, 'TSt-4: 試し始めた');
SELECT is((SELECT tr.status || '/' || coalesce(tr.score::text, '空') || '/' || (tr.tried_on = (now() AT TIME ZONE 'Asia/Tokyo')::date) || '/' || tr.age_months FROM public.trials tr WHERE tr.id = test_fx.id('T_w2')),
  'trying/空/true/30', 'TSt-4: 試し中・点数は空・日付は今日・年齢は確かめた値');
-- 日付を画面が送ったときはそれを使う
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET status = 'trying', tried_on = DATE '2026-09-20' WHERE id = %L$$, test_fx.id('T_w3'))), 1, 'TSt-5: 日付つきで試し始めた');
SELECT is((SELECT tr.tried_on FROM public.trials tr WHERE tr.id = test_fx.id('T_w3')), DATE '2026-09-20', 'TSt-5: 送った日付のまま');
-- 試した → 試したいに戻す（状態だけを送る）→ 点数は空に
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET status = 'want' WHERE id = %L$$, test_fx.id('T_sc'))), 1, 'TSt-6: 試した→試したいに戻せる');
SELECT is((SELECT tr.status || '/' || coalesce(tr.score::text, '空') FROM public.trials tr WHERE tr.id = test_fx.id('T_sc')), 'want/空', 'TSt-6: 点数は空になる');
-- 点数を空にしただけ → 試し中
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET score = NULL WHERE id = %L$$, test_fx.id('T_w1'))), 1, 'TSt-7: 点数を空にする');
SELECT is((SELECT tr.status FROM public.trials tr WHERE tr.id = test_fx.id('T_w1')), 'trying', 'TSt-7: 試し中になる');

-- ===================== TA: 年齢の範囲（X3・X7・X6・X8）
SELECT test_fx.as_owner();
SELECT test_fx.reset();   -- 件数を数えるので、見本データを作り直す
SELECT test_fx.mk_problem('P_a', 'S1', '年齢の①', 'HA');
SELECT test_fx.mk_measure('M_a', 'P_a', '年齢の②', 'HA');
SELECT test_fx.as_user('a1');
SELECT throws_ok(format($$INSERT INTO public.trials (measure_id, score, age_months, age_months_to) VALUES (%L, 3, 0, 60)$$, test_fx.id('M_a')), '23514', NULL, 'TA-7: 0歳〜5歳（60か月）は保存できない');
SELECT throws_ok(format($$INSERT INTO public.trials (measure_id, score, age_months, age_months_to) VALUES (%L, 3, 36, 24)$$, test_fx.id('M_a')), '23514', NULL, 'TA-7: まで＜から は保存できない');
SELECT throws_ok(format($$INSERT INTO public.trials (measure_id, score, age_months, age_months_to) VALUES (%L, 3, 12, 20)$$, test_fx.id('M_a')), '23514', NULL, 'TA-7: 6の倍数でない まで は保存できない');
SELECT lives_ok(format($$INSERT INTO public.trials (measure_id, score, age_months, age_months_to) VALUES (%L, 3, 36, 36)$$, test_fx.id('M_a')), 'TA-8: まで＝から は保存できる');
SELECT is((SELECT count(*)::int FROM public.trials tr WHERE tr.measure_id = test_fx.id('M_a') AND tr.age_months = 36 AND tr.age_months_to IS NULL), 1, 'TA-8: まで＝から は空（1つの年齢）にそろう');
-- 要件 5-4節の確認例（別の①に1件ずつ。家庭Aのみんなの③）
SELECT test_fx.as_owner();
DELETE FROM public.trials tr WHERE tr.measure_id = test_fx.id('M_a');
SELECT test_fx.mk_problem('P_r1', 'S1', '範囲1', 'HA'); SELECT test_fx.mk_measure('M_r1', 'P_r1', 'r1', 'HA'); SELECT test_fx.mk_trial4('T_r1', 'M_r1', 'a1', 'scored', 3, 24);         -- 2歳
SELECT test_fx.mk_problem('P_r2', 'S1', '範囲2', 'HA'); SELECT test_fx.mk_measure('M_r2', 'P_r2', 'r2', 'HA'); SELECT test_fx.mk_trial4('T_r2', 'M_r2', 'a1', 'scored', 3, 18, 30);     -- 1歳半〜2歳半
SELECT test_fx.mk_problem('P_r3', 'S1', '範囲3', 'HA'); SELECT test_fx.mk_measure('M_r3', 'P_r3', 'r3', 'HA'); SELECT test_fx.mk_trial4('T_r3', 'M_r3', 'a1', 'want', NULL, 24, 36);   -- 2〜3歳（試したい）
SELECT test_fx.mk_problem('P_r4', 'S1', '範囲4', 'HA'); SELECT test_fx.mk_measure('M_r4', 'P_r4', 'r4', 'HA'); SELECT test_fx.mk_trial4('T_r4', 'M_r4', 'a1', 'trying', NULL, 36, 72); -- 3〜6歳
SELECT test_fx.mk_problem('P_r5', 'S1', '範囲5', 'HA'); SELECT test_fx.mk_measure('M_r5', 'P_r5', 'r5', 'HA'); SELECT test_fx.mk_trial4('T_r5', 'M_r5', 'a1', 'scored', 2, 180, 216); -- 15〜18歳
SELECT test_fx.mk_trial4('T_r5p', 'M_r5', 'a1', 'scored', 2, 60, NULL, 'household');   -- 5歳・非公開（b1 には見えない）
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(o_age_years::text || ':' || o_problem_count ORDER BY o_age_years) FROM public.list_age_counts(test_fx.id('S1'))),
  ARRAY['1:1','2:3','3:2','4:1','5:1','6:1','15:1','16:1','17:1','18:1'],
  'TA-9: 1歳ごと（範囲の③は入る歳すべて。試したいも数える。非公開の5歳は b1 には数えない＝5歳は範囲4だけ）');
SELECT test_fx.as_user('a1');
SELECT is((SELECT o_problem_count FROM public.list_age_counts(test_fx.id('S1')) WHERE o_age_years = 5), 2, 'TA-9: a1 には自家庭の非公開の5歳も数える');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(o_name ORDER BY o_name) FROM public.search_problems(test_fx.id('S1'), p_age_years => 3, p_age_years_to => 5)),
  ARRAY['範囲3','範囲4'], 'TA-11: 3〜5歳で絞ると 2〜3歳・3〜6歳の③を持つ①');
SELECT is((SELECT array_agg(o_name ORDER BY o_name) FROM public.search_problems(test_fx.id('S1'), p_age_years => 1)),
  ARRAY['範囲2'], 'TA-11: 1歳で絞ると 1歳半〜2歳半だけ');
SELECT is((SELECT (o_trials -> 0 ->> 'in_age')::boolean FROM public.list_measures(test_fx.id('P_r3'), NULL, 3)), true, 'TA-12: list_measures の in_age も範囲で判定（2〜3歳は3歳に入る）');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P_r3'), NULL, 4)), 0, 'TA-12: 4歳で絞ると 2〜3歳の②は出ない');

-- ===================== TO-8: 並び（要件 6-3節の確認例 A〜F）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_o', 'S1', '並びの①', 'HA');
SELECT test_fx.mk_measure('M_A', 'P_o', 'A', 'HA'); SELECT test_fx.mk_trial('tA1', 'M_A', 'a1', 4); SELECT test_fx.mk_trial('tA2', 'M_A', 'b1', 2);
SELECT test_fx.mk_measure('M_B', 'P_o', 'B', 'HA'); SELECT test_fx.mk_trial('tB1', 'M_B', 'a1', 4); SELECT test_fx.mk_trial('tB2', 'M_B', 'b1', 4); SELECT test_fx.mk_trial('tB3', 'M_B', 'c1', 3);
SELECT test_fx.mk_measure('M_C', 'P_o', 'C', 'HA'); SELECT test_fx.mk_trial('tC1', 'M_C', 'b1', 5);
SELECT test_fx.mk_measure('M_D', 'P_o', 'D', 'HA'); SELECT test_fx.mk_trial('tD1', 'M_D', 'a1', 2, 'all', 24); SELECT test_fx.mk_trial('tD2', 'M_D', 'a1', 1, 'all', 60);
SELECT test_fx.mk_measure('M_E', 'P_o', 'E', 'HA'); SELECT test_fx.mk_trial('tE1', 'M_E', 'b1', NULL);
SELECT test_fx.mk_measure('M_F', 'P_o', 'F', 'HA'); SELECT test_fx.mk_trial4('tF1', 'M_F', 'c1', 'want', NULL, 24); SELECT test_fx.mk_trial4('tF2', 'M_F', 'b1', 'want', NULL, 24, 36);
SELECT test_fx.mk_measure('M_G', 'P_o', 'G（③0件）', 'HA');
SELECT test_fx.as_user('a1');
SELECT is((SELECT array_agg(o_name) FROM public.list_measures(test_fx.id('P_o'))), ARRAY['C','B','A','D','E','F','G（③0件）'], 'TO-8: 並びは C, B, A, D, E, F（すべて試したい）, ③0件');
SELECT is((SELECT o_group::text || '/' || o_household_count FROM public.list_measures(test_fx.id('P_o')) WHERE o_name = 'F'), '2/0', 'TO-8: F はグループ2・家庭の数に試したいは数えない');
SELECT is((SELECT o_group FROM public.list_measures(test_fx.id('P_o')) WHERE o_name = 'G（③0件）'), 3, 'TO-8: ③0件はグループ3');
SELECT is((SELECT array_agg(o_name) FROM public.suggest_measures(test_fx.id('P_o'), '')), ARRAY['C','B','A','D','E'], 'TO-8: ②の候補（打つ前）も同じ並びの上から5件');
-- 行の中: 試した → 試し中 → 試したい
SELECT test_fx.as_owner();
SELECT test_fx.mk_trial4('tA3', 'M_A', 'c1', 'want', NULL, 24);
SELECT test_fx.mk_trial('tA4', 'M_A', 'c1', NULL);
SELECT test_fx.as_user('a1');
SELECT is((SELECT array_agg(x ->> 'status') FROM public.list_measures(test_fx.id('P_o')) lm, jsonb_array_elements(lm.o_trials) x WHERE lm.o_name = 'A'),
  ARRAY['scored','scored','trying','want'], 'TO-9: 行の中は 試した（点数順）→ 試し中 → 試したい');
SELECT is((SELECT o_household_count FROM public.list_measures(test_fx.id('P_o')) WHERE o_name = 'A'), 3, 'TO-9: 試し中の c1 は家庭の数に入る（HA・HB・HC）');

-- ===================== TSo: 出典6つ（X4）
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_s', 'S1', '出典の①', 'HB');
SELECT test_fx.mk_measure('M_s', 'P_s', '出典の②', 'HB');
SELECT test_fx.as_user('b1');
SELECT lives_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, 3::smallint, 24::smallint, 'tv', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'すくすく子育て')$$, test_fx.id('M_s')),
  'TSo-1: テレビ＋番組名で書ける');
SELECT lives_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, 3::smallint, 24::smallint, 'other', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '園のおたより')$$, test_fx.id('M_s')),
  'TSo-1: その他＋何で知ったかで書ける');
SELECT throws_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, 3::smallint, 24::smallint, 'own', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '番組')$$, test_fx.id('M_s')),
  '23514', NULL, 'TSo-2: うちで考えた に詳細の文字は 23514');
SELECT throws_ok(format($$SELECT public.save_trial(NULL, NULL, NULL, NULL, %L, NULL, 3::smallint, 24::smallint, 'tv', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, repeat('あ', 41))$$, test_fx.id('M_s')),
  '23514', NULL, 'TSo-2: 41字は 23514');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P_s'), 'tv')), 1, 'TSo-3: 出典のタブ「テレビ」で絞れる');
SELECT is((SELECT x ->> 'source_text' FROM public.list_measures(test_fx.id('P_s')) lm, jsonb_array_elements(lm.o_trials) x WHERE x ->> 'source_type' = 'tv'),
  'すくすく子育て', 'TSo-3: o_trials に詳細の文字');

-- ===================== TN: 書いた人の呼び名（X8。⑤）
SELECT test_fx.as_user('a1');
SELECT is((SELECT x ->> 'created_by_name' || '（' || (x ->> 'household_name') || '）' FROM public.list_measures(test_fx.id('P_o')) lm, jsonb_array_elements(lm.o_trials) x WHERE x ->> 'trial_id' = test_fx.id('tC1')::text),
  'Bの人（家庭B）', 'TN-1: 他家庭の見える③に、書いた人の呼び名と家庭名');
-- 見えない③の書いた人は出ない（非公開③は o_trials に無い）
SELECT test_fx.as_owner();
SELECT test_fx.mk_trial('tC2', 'M_C', 'c1', 3, 'household');
SELECT test_fx.as_user('a1');
SELECT is((SELECT count(*)::int FROM public.list_measures(test_fx.id('P_o')) lm, jsonb_array_elements(lm.o_trials) x WHERE x ->> 'created_by_name' = 'Cの人' AND lm.o_name = 'C'), 0,
  'TN-2: 他家庭の非公開③の書いた人は出ない（見え方は変わらない）');
-- 書いた人が外された（③は残す）→ 呼び名は空・家庭名だけ
SELECT test_fx.as_owner();
SELECT public.delete_member_data(test_fx.uid('u0a'), test_fx.id('m_b1'), false);
SELECT test_fx.as_user('a1');
SELECT is((SELECT coalesce(x ->> 'created_by_name', '空') || '（' || (x ->> 'household_name') || '）' FROM public.list_measures(test_fx.id('P_o')) lm, jsonb_array_elements(lm.o_trials) x WHERE x ->> 'trial_id' = test_fx.id('tC1')::text),
  '空（家庭B）', 'TN-3: 書いた人が空なら呼び名は null、家庭名は出る');

-- ===================== TE-3: 書き出し（X12）
SELECT is((SELECT (public.export_visible_data(test_fx.id('S1')) -> 'problems' -> 0) ? 'kind'), true, 'TE-3: 書き出しの①に kind');
SELECT is((SELECT count(*)::int FROM jsonb_array_elements(public.export_visible_data(test_fx.id('S1')) -> 'trials') x WHERE x ? 'status' AND x ? 'age_months_to' AND x ? 'source_text'),
  (SELECT count(*)::int FROM jsonb_array_elements(public.export_visible_data(test_fx.id('S1')) -> 'trials')), 'TE-3: 書き出しの③に status・age_months_to・source_text');

SELECT * FROM finish();
ROLLBACK;
