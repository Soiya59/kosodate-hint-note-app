-- ============================================================
-- 設計書 12-6節のうち: 年齢 TA-1〜TA-6／並び順 TO-1〜TO-7／検索 TQ-1〜TQ-6／候補 TK-1〜TK-5（S1）
--   並びの確かめは、関数の出力の順番（WITH ORDINALITY）どおりに ID を並べて比べる。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(42);
SELECT test_fx.build();

-- ========== 年齢 ==========
-- TA-1〜5: 年齢 0・6・36・42・216 の③を書き、list_age_counts → 0歳・3歳・18歳の行（要件 5-3 の表どおり）
SELECT test_fx.mk_problem('PA0', 'S1', '年齢0の困りごと', 'HA');
SELECT test_fx.mk_measure('MA0', 'PA0', '年齢0の対策', 'HA');
SELECT test_fx.mk_problem('PA3', 'S1', '年齢3の困りごと', 'HA');
SELECT test_fx.mk_measure('MA3', 'PA3', '年齢3の対策', 'HA');
SELECT test_fx.mk_problem('PA18', 'S1', '年齢18の困りごと', 'HA');
SELECT test_fx.mk_measure('MA18', 'PA18', '年齢18の対策', 'HA');
SELECT test_fx.as_user('a1');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 4, p_age_months => 0)$$, test_fx.id('MA0')),   'TA-1: 0歳（0か月）を書ける');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 4, p_age_months => 6)$$, test_fx.id('MA0')),   'TA-2: 0歳半（6か月）を書ける');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 4, p_age_months => 36)$$, test_fx.id('MA3')),  'TA-3: 3歳（36か月）を書ける');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 4, p_age_months => 42)$$, test_fx.id('MA3')),  'TA-4: 3歳半（42か月）を書ける');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 4, p_age_months => 216)$$, test_fx.id('MA18')), 'TA-5: 18歳（216か月）を書ける');
SELECT results_eq(
  $$SELECT o_age_years, o_problem_count FROM public.list_age_counts(test_fx.id('S1'))$$,
  $$VALUES (0, 1), (3, 1), (18, 1)$$,
  'TA-1〜5: list_age_counts は 0歳（③2件→①1件）・3歳（③2件→①1件）・18歳（①1件）の3行');
-- TA-6: 年齢 7・217・-6 → 拒否（制約）
SELECT throws_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_age_months => 7)$$, test_fx.id('MA0')),   '23514', NULL, 'TA-6: 7か月（6の倍数でない）は拒否');
SELECT throws_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_age_months => 217)$$, test_fx.id('MA0')), '23514', NULL, 'TA-6: 217か月（18歳を超える）は拒否');
SELECT throws_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_age_months => -6)$$, test_fx.id('MA0')),  '23514', NULL, 'TA-6: -6か月は拒否');

-- ========== 並び順 ==========
-- TO-1: 要件 6-3 の確認例（A: うち4・兄の家2／B: 4・4・3／C: 5／D: 2・1／E: 試し中）→ C, B, A, D, E
-- TO-2: ③0件の②（作った家庭から）→ いちばん下
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('PO', 'S1', '並びの困りごと', 'HB');
SELECT test_fx.mk_measure('OA', 'PO', '対策A', 'HB');
SELECT test_fx.mk_trial('OA1', 'OA', 'b1', 4); SELECT test_fx.mk_trial('OA2', 'OA', 'a1', 2);
SELECT test_fx.mk_measure('OB', 'PO', '対策B', 'HB');
SELECT test_fx.mk_trial('OB1', 'OB', 'b1', 4); SELECT test_fx.mk_trial('OB2', 'OB', 'a1', 4); SELECT test_fx.mk_trial('OB3', 'OB', 'c1', 3);
SELECT test_fx.mk_measure('OC', 'PO', '対策C', 'HB');
SELECT test_fx.mk_trial('OC1', 'OC', 'a1', 5);
SELECT test_fx.mk_measure('OD', 'PO', '対策D', 'HB');
SELECT test_fx.mk_trial('OD1', 'OD', 'b1', 2); SELECT test_fx.mk_trial('OD2', 'OD', 'a1', 1);
SELECT test_fx.mk_measure('OE', 'PO', '対策E', 'HB');
SELECT test_fx.mk_trial('OE1', 'OE', 'a1', NULL);
SELECT test_fx.mk_measure('OF', 'PO', '対策F（③なし）', 'HB');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(l.o_measure_id ORDER BY l.n) FROM public.list_measures(test_fx.id('PO')) WITH ORDINALITY l(o_measure_id, o_name, o_chh, o_group, o_best, o_hh, o_latest, o_cnt, o_trials, n) WHERE l.n <= 5),
  ARRAY[test_fx.id('OC'), test_fx.id('OB'), test_fx.id('OA'), test_fx.id('OD'), test_fx.id('OE')],
  'TO-1: 対策の一覧の順は C, B, A, D, E');
SELECT is((SELECT l.o_measure_id FROM public.list_measures(test_fx.id('PO')) WITH ORDINALITY l(o_measure_id, o_name, o_chh, o_group, o_best, o_hh, o_latest, o_cnt, o_trials, n) ORDER BY l.n DESC LIMIT 1),
  test_fx.id('OF'), 'TO-2: ③0件の②はいちばん下');

-- TO-3: 困りごとの一覧は見える③の最後の更新の新しい順。他家庭の非公開③を直しても、b1 の一覧の順が変わらない
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('Pa', 'S1', '順1', 'HA'); SELECT test_fx.mk_measure('Ma', 'Pa', '順1の対策', 'HA');
SELECT test_fx.mk_trial('Ta', 'Ma', 'a1', 3, 'all');
SELECT test_fx.mk_problem('Pb', 'S1', '順2', 'HA'); SELECT test_fx.mk_measure('Mb', 'Pb', '順2の対策', 'HA');
SELECT test_fx.mk_trial('Tb', 'Mb', 'a1', 3, 'all');
SELECT test_fx.mk_problem('Pc', 'S1', '順3', 'HA'); SELECT test_fx.mk_measure('Mc', 'Pc', '順3の対策', 'HA');
SELECT test_fx.mk_trial('Tc', 'Mc', 'a1', 3, 'all');
SELECT test_fx.mk_trial('Tc_priv', 'Mc', 'a1', 3, 'household');
SELECT test_fx.set_updated_at('trials', 'Ta', '2026-01-03 00:00+09');
SELECT test_fx.set_updated_at('trials', 'Tb', '2026-01-02 00:00+09');
SELECT test_fx.set_updated_at('trials', 'Tc', '2026-01-01 00:00+09');
SELECT test_fx.set_updated_at('trials', 'Tc_priv', '2026-01-01 00:00+09');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(s.o_problem_id ORDER BY s.n) FROM public.search_problems(test_fx.id('S1'), '順') WITH ORDINALITY s(o_problem_id, o_name, o_chh, o_tags, o_mc, o_tc, o_sort, n)),
  ARRAY[test_fx.id('Pa'), test_fx.id('Pb'), test_fx.id('Pc')], 'TO-3: 見える③の最後の更新の新しい順（順1→順2→順3）');
SELECT test_fx.as_user('a1');
SELECT is(test_fx.exec_count(format($$UPDATE public.trials SET note = '直した' WHERE id = %L$$, test_fx.id('Tc_priv'))), 1, 'TO-3: a1 が自家庭の非公開③を直す');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(s.o_problem_id ORDER BY s.n) FROM public.search_problems(test_fx.id('S1'), '順') WITH ORDINALITY s(o_problem_id, o_name, o_chh, o_tags, o_mc, o_tc, o_sort, n)),
  ARRAY[test_fx.id('Pa'), test_fx.id('Pb'), test_fx.id('Pc')], 'TO-3: 他家庭の非公開③を直しても、b1 の一覧の順は変わらない');
SELECT test_fx.as_user('a1');
SELECT is((SELECT s.o_problem_id FROM public.search_problems(test_fx.id('S1'), '順') s LIMIT 1), test_fx.id('Pc'),
  'TO-3（補い）: 直した a1 自身の一覧では順3が先頭になる');

-- TO-4: 出典のタブ「本」→ 本の③を持つ②だけ。行の中の③は種類に関係なく全部
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('PS', 'S1', '出典の困りごと', 'HA');
SELECT test_fx.mk_book('BKs', 'S1', '出典の本', NULL, 'a1');
SELECT test_fx.mk_measure('MS1', 'PS', '本もある対策', 'HA');
SELECT test_fx.mk_trial('TS1b', 'MS1', 'a1', 4, 'all', 36, DATE '2026-09-01', 'book', 'BKs');
SELECT test_fx.mk_trial('TS1o', 'MS1', 'b1', 3, 'all', 36, DATE '2026-09-01', 'own');
SELECT test_fx.mk_measure('MS2', 'PS', '本のない対策', 'HA');
SELECT test_fx.mk_trial('TS2o', 'MS2', 'a1', 5, 'all', 36, DATE '2026-09-01', 'own');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(l.o_measure_id) FROM public.list_measures(test_fx.id('PS'), 'book') l), ARRAY[test_fx.id('MS1')],
  'TO-4: 出典のタブ「本」では、本の③を持つ②だけ');
SELECT is((SELECT jsonb_array_length(l.o_trials) FROM public.list_measures(test_fx.id('PS'), 'book') l), 2,
  'TO-4: 行の中の③は種類に関係なく全部（本とうちで考えたの2件）');

-- TO-5（v0.2）: ②に うち 5〈2歳〉・兄の家 4〈3歳〉・姉の家 試し中〈3歳〉・うち 2〈3歳〉（すべてみんな）→ list_measures(①, NULL, 3)
--   o_trials の順が「4（3歳）→ 2（3歳）→ 試し中（3歳）→ 5（2歳）」、in_age は前の3件だけ true。3歳の③が無い②は行に出ない
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('PG', 'S1', '年齢の並びの困りごと', 'HA');
SELECT test_fx.mk_measure('MG', 'PG', '年齢の並びの対策', 'HA');
SELECT test_fx.mk_trial('G_uchi5', 'MG', 'a1', 5, 'all', 24, DATE '2026-09-10');
SELECT test_fx.mk_trial('G_ani4', 'MG', 'b1', 4, 'all', 36, DATE '2026-09-09');
SELECT test_fx.mk_trial('G_ane', 'MG', 'c1', NULL, 'all', 36, DATE '2026-09-08');
SELECT test_fx.mk_trial('G_uchi2', 'MG', 'a2', 2, 'all', 36, DATE '2026-09-07');
SELECT test_fx.mk_measure('MG2', 'PG', '2歳だけの対策', 'HA');
SELECT test_fx.mk_trial('G2', 'MG2', 'a1', 5, 'all', 24);
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg((e.v->>'trial_id')::uuid ORDER BY e.n) FROM public.list_measures(test_fx.id('PG'), NULL, 3) l,
                  jsonb_array_elements(l.o_trials) WITH ORDINALITY e(v, n) WHERE l.o_measure_id = test_fx.id('MG')),
  ARRAY[test_fx.id('G_ani4'), test_fx.id('G_uchi2'), test_fx.id('G_ane'), test_fx.id('G_uchi5')],
  'TO-5: 3歳で絞り込み中は「4（3歳）→ 2（3歳）→ 試し中（3歳）→ 5（2歳）」');
SELECT is((SELECT array_agg((e.v->>'in_age')::boolean ORDER BY e.n) FROM public.list_measures(test_fx.id('PG'), NULL, 3) l,
                  jsonb_array_elements(l.o_trials) WITH ORDINALITY e(v, n) WHERE l.o_measure_id = test_fx.id('MG')),
  ARRAY[true, true, true, false], 'TO-5: in_age は前の3件（3歳の③）だけ true');
SELECT is((SELECT array_agg(l.o_measure_id) FROM public.list_measures(test_fx.id('PG'), NULL, 3) l), ARRAY[test_fx.id('MG')],
  'TO-5: 3歳の③が無い②は行に出ない');

-- TO-6（v0.2）: 同じ②で list_measures(①)（歳なし）→「5 → 4 → 2 → 試し中」。in_age はすべて false
SELECT is((SELECT array_agg((e.v->>'trial_id')::uuid ORDER BY e.n) FROM public.list_measures(test_fx.id('PG')) l,
                  jsonb_array_elements(l.o_trials) WITH ORDINALITY e(v, n) WHERE l.o_measure_id = test_fx.id('MG')),
  ARRAY[test_fx.id('G_uchi5'), test_fx.id('G_ani4'), test_fx.id('G_uchi2'), test_fx.id('G_ane')],
  'TO-6: 歳なしでは「5 → 4 → 2 → 試し中」');
SELECT is((SELECT array_agg(DISTINCT (e.v->>'in_age')::boolean) FROM public.list_measures(test_fx.id('PG')) l,
                  jsonb_array_elements(l.o_trials) e(v)),
  ARRAY[false], 'TO-6: 歳なしでは in_age はすべて false');

-- TO-7（v0.2）: TO-5 に A の非公開③（3歳・5点）を足す → b1 の o_trials に出ず、順も TO-5 と同じ
SELECT test_fx.as_owner();
SELECT test_fx.mk_trial('G_priv', 'MG', 'a1', 5, 'household', 36, DATE '2026-09-11');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg((e.v->>'trial_id')::uuid ORDER BY e.n) FROM public.list_measures(test_fx.id('PG'), NULL, 3) l,
                  jsonb_array_elements(l.o_trials) WITH ORDINALITY e(v, n) WHERE l.o_measure_id = test_fx.id('MG')),
  ARRAY[test_fx.id('G_ani4'), test_fx.id('G_uchi2'), test_fx.id('G_ane'), test_fx.id('G_uchi5')],
  'TO-7: 見えない③は o_trials に出ず、並びにも効かない（TO-5 と同じ順）');

-- ========== 検索 ==========
SELECT test_fx.as_owner();
-- TQ-1 用
SELECT test_fx.mk_problem('Q1', 'S1', '寝かしつけ', 'HA'); SELECT test_fx.mk_measure('Q1m', 'Q1', '絵本を読む', 'HA'); SELECT test_fx.mk_trial('Q1t', 'Q1m', 'a1', 4);
SELECT test_fx.mk_problem('Q2', 'S1', '寝ない', 'HA');     SELECT test_fx.mk_measure('Q2m', 'Q2', 'ミルク', 'HA');     SELECT test_fx.mk_trial('Q2t', 'Q2m', 'a1', 4);
SELECT test_fx.mk_problem('Q3', 'S1', '絵本が好き', 'HA'); SELECT test_fx.mk_measure('Q3m', 'Q3', '図書館', 'HA');     SELECT test_fx.mk_trial('Q3t', 'Q3m', 'a1', 4);
-- TQ-2 用
SELECT test_fx.mk_problem('Q4', 'S1', 'ABCの歌', 'HA');    SELECT test_fx.mk_measure('Q4m', 'Q4', '一緒に歌う', 'HA'); SELECT test_fx.mk_trial('Q4t', 'Q4m', 'a1', 4);
-- TQ-3 用
SELECT test_fx.mk_problem('Q5', 'S1', 'ねるまえ', 'HA');   SELECT test_fx.mk_measure('Q5m', 'Q5', '暗くする', 'HA');   SELECT test_fx.mk_trial('Q5t', 'Q5m', 'a1', 4);
SELECT test_fx.mk_problem('Q6', 'S1', 'ネルシャツ', 'HA'); SELECT test_fx.mk_measure('Q6m', 'Q6', '洗う', 'HA');       SELECT test_fx.mk_trial('Q6t', 'Q6m', 'a1', 4);
-- TQ-4 用（見える①の下に、非公開③だけの②「秘密の言葉」）
SELECT test_fx.mk_problem('Q7', 'S1', 'ことばが遅い', 'HA'); SELECT test_fx.mk_measure('Q7m', 'Q7', '話しかける', 'HA'); SELECT test_fx.mk_trial('Q7t', 'Q7m', 'a1', 4);
SELECT test_fx.mk_measure('Q7x', 'Q7', '秘密の言葉', 'HA'); SELECT test_fx.mk_trial('Q7xt', 'Q7x', 'a1', 5, 'household');
-- TQ-5 用（Q1 にタグ「寝る」、Q8「寝返り」にはタグを付けない）
INSERT INTO public.problem_tags (problem_id, tag_id) VALUES (test_fx.id('Q1'), test_fx.id('tag1_寝る'));
SELECT test_fx.mk_problem('Q8', 'S1', '寝返り', 'HA');     SELECT test_fx.mk_measure('Q8m', 'Q8', '見守る', 'HA');     SELECT test_fx.mk_trial('Q8t', 'Q8m', 'a1', 4);
-- TQ-6 用
SELECT test_fx.mk_problem('Q9', 'S1', '2歳だけの困りごと', 'HA'); SELECT test_fx.mk_measure('Q9m', 'Q9', '2歳の対策', 'HA'); SELECT test_fx.mk_trial('Q9t', 'Q9m', 'a1', 4, 'all', 24);

SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(s.o_problem_id) FROM public.search_problems(test_fx.id('S1'), '寝 絵本') s), ARRAY[test_fx.id('Q1')],
  'TQ-1: 「寝 絵本」→ 名前に「寝」を含み、下の見える②に「絵本」がある①だけ');
SELECT is((SELECT array_agg(s.o_problem_id ORDER BY s.o_problem_id) FROM public.search_problems(test_fx.id('S1'), 'ＡＢＣ') s),
          (SELECT array_agg(s.o_problem_id ORDER BY s.o_problem_id) FROM public.search_problems(test_fx.id('S1'), 'abc') s),
  'TQ-2: 「ＡＢＣ」と「abc」は同じ結果');
SELECT is((SELECT array_agg(s.o_problem_id) FROM public.search_problems(test_fx.id('S1'), 'abc') s), ARRAY[test_fx.id('Q4')],
  'TQ-2: その結果は「ABCの歌」');
SELECT is((SELECT array_agg(s.o_problem_id) FROM public.search_problems(test_fx.id('S1'), 'ねる') s), ARRAY[test_fx.id('Q5')],
  'TQ-3: 「ねる」は「ねるまえ」だけ');
SELECT is((SELECT array_agg(s.o_problem_id) FROM public.search_problems(test_fx.id('S1'), 'ネル') s), ARRAY[test_fx.id('Q6')],
  'TQ-3: 「ネル」は「ネルシャツ」だけ（ひらがなとカタカナは別）');
SELECT is((SELECT count(*)::int FROM public.search_problems(test_fx.id('S1'), '秘密')), 0,
  'TQ-4: 非公開③だけの②「秘密の言葉」の名前では、b1 の検索に出ない');
SELECT is((SELECT array_agg(s.o_problem_id) FROM public.search_problems(test_fx.id('S1'), '寝', test_fx.id('tag1_寝る')) s), ARRAY[test_fx.id('Q1')],
  'TQ-5: タグ「寝る」＋言葉「寝」→ 両方を満たす①だけ（「寝ない」「寝返り」は出ない）');
SELECT ok(test_fx.id('Q1') IN (SELECT s.o_problem_id FROM public.search_problems(test_fx.id('S1'), NULL, NULL, 3) s)
      AND test_fx.id('Q9') NOT IN (SELECT s.o_problem_id FROM public.search_problems(test_fx.id('S1'), NULL, NULL, 3) s),
  'TQ-6: 年齢3歳で絞ると、3歳の見える③を持つ①だけ（2歳だけの①は出ない）');

-- ========== 候補 ==========
-- TK-1: TV-2 の①（A の非公開③だけ）の名前 → b1 の suggest_problems に出ない
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('K1', 'S1', 'かくれた困りごと', 'HA'); SELECT test_fx.mk_measure('K1m', 'K1', 'かくれた対策', 'HA');
SELECT test_fx.mk_trial('K1t', 'K1m', 'a1', 4, 'household');
-- TK-2: 同じ名前の見える① → o_is_exact = true が先頭
SELECT test_fx.mk_problem('K2long', 'S1', 'よなきがひどい', 'HA'); SELECT test_fx.mk_measure('K2lm', 'K2long', '抱っこ', 'HA'); SELECT test_fx.mk_trial('K2lt', 'K2lm', 'a1', 4);
SELECT test_fx.mk_problem('K2', 'S1', 'よなき', 'HA'); SELECT test_fx.mk_measure('K2m', 'K2', 'おしゃぶり', 'HA'); SELECT test_fx.mk_trial('K2t', 'K2m', 'a1', 4);
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.suggest_problems(test_fx.id('S1'), 'かくれた')), 0, 'TK-1: 見えない①は候補に出ない');
SELECT is((SELECT s.o_problem_id FROM public.suggest_problems(test_fx.id('S1'), 'よなき') s LIMIT 1), test_fx.id('K2'),
  'TK-2: 完全一致の①が先頭');
SELECT is((SELECT s.o_is_exact FROM public.suggest_problems(test_fx.id('S1'), 'よなき') s LIMIT 1), true, 'TK-2: 先頭の o_is_exact は true');

-- TK-3（v0.2）: ①の下に見える②が6件 → suggest_measures(①, '') は5件。順は list_measures(①) の上から5件と同じ。o_is_exact はすべて false
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('K3', 'S1', '候補6件の困りごと', 'HA');
SELECT test_fx.mk_measure('K3a', 'K3', '候補a', 'HA'); SELECT test_fx.mk_trial('K3at', 'K3a', 'a1', 2);
SELECT test_fx.mk_measure('K3b', 'K3', '候補b', 'HA'); SELECT test_fx.mk_trial('K3bt', 'K3b', 'a1', 5);
SELECT test_fx.mk_measure('K3c', 'K3', '候補c', 'HA'); SELECT test_fx.mk_trial('K3ct', 'K3c', 'a1', NULL);
SELECT test_fx.mk_measure('K3d', 'K3', '候補d', 'HA'); SELECT test_fx.mk_trial('K3dt', 'K3d', 'a1', 4); SELECT test_fx.mk_trial('K3dt2', 'K3d', 'b1', 4);
SELECT test_fx.mk_measure('K3e', 'K3', '候補e', 'HA'); SELECT test_fx.mk_trial('K3et', 'K3e', 'a1', 4);
SELECT test_fx.mk_measure('K3f', 'K3', '候補f', 'HB');   -- ③0件（b1 の家庭が作った）
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.suggest_measures(test_fx.id('K3'), '')), 5, 'TK-3: 打つ前（空の文字）でも5件');
SELECT is((SELECT array_agg(s.o_measure_id ORDER BY s.n) FROM public.suggest_measures(test_fx.id('K3'), '') WITH ORDINALITY s(o_measure_id, o_name, o_is_exact, n)),
          (SELECT array_agg(l.o_measure_id ORDER BY l.n) FROM public.list_measures(test_fx.id('K3')) WITH ORDINALITY l(o_measure_id, o_name, o_chh, o_group, o_best, o_hh, o_latest, o_cnt, o_trials, n) WHERE l.n <= 5),
  'TK-3: 順は list_measures(①) の上から5件と同じ');
SELECT is((SELECT array_agg(DISTINCT s.o_is_exact) FROM public.suggest_measures(test_fx.id('K3'), '') s), ARRAY[false], 'TK-3: o_is_exact はすべて false');

-- TK-4（v0.2）: TV-4 の①（②x は A の非公開③だけ、②y はみんな）→ b1 の suggest_measures(①, NULL) は②y だけ。a1 には両方
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('K4', 'S1', 'TK4の困りごと', 'HA');
SELECT test_fx.mk_measure('K4x', 'K4', '候補x', 'HA'); SELECT test_fx.mk_trial('K4xt', 'K4x', 'a1', 5, 'household');
SELECT test_fx.mk_measure('K4y', 'K4', '候補y', 'HA'); SELECT test_fx.mk_trial('K4yt', 'K4y', 'a1', 3, 'all');
SELECT test_fx.as_user('b1');
SELECT is((SELECT array_agg(s.o_measure_id) FROM public.suggest_measures(test_fx.id('K4'), NULL) s), ARRAY[test_fx.id('K4y')], 'TK-4: b1 には②y だけ');
SELECT test_fx.as_user('a1');
SELECT is((SELECT array_agg(s.o_measure_id ORDER BY s.o_name) FROM public.suggest_measures(test_fx.id('K4'), NULL) s), ARRAY[test_fx.id('K4x'), test_fx.id('K4y')],
  'TK-4: a1 には②x・②y の両方');

-- TK-5（v0.2）: suggest_problems(S1, '')・suggest_books(S1, '') → 0行。suggest_measures(①, '寝') の順は「完全一致 → 前方一致 → 短い名前 → 名前順」
SELECT test_fx.as_owner();
SELECT test_fx.mk_book('K5bk', 'S1', '候補の本', NULL, 'b1');
SELECT test_fx.mk_problem('K5', 'S1', 'TK5の困りごと', 'HB');
SELECT test_fx.mk_measure('K5d', 'K5', 'よく寝る', 'HB');
SELECT test_fx.mk_measure('K5c', 'K5', 'お昼寝', 'HB');
SELECT test_fx.mk_measure('K5b', 'K5', '寝かしつけ', 'HB');
SELECT test_fx.mk_measure('K5a', 'K5', '寝', 'HB');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.suggest_problems(test_fx.id('S1'), '')), 0, 'TK-5: suggest_problems は空の文字では0行');
SELECT is((SELECT count(*)::int FROM public.suggest_books(test_fx.id('S1'), '')), 0, 'TK-5: suggest_books は空の文字では0行');
SELECT is((SELECT array_agg(s.o_name ORDER BY s.n) FROM public.suggest_measures(test_fx.id('K5'), '寝') WITH ORDINALITY s(o_measure_id, o_name, o_is_exact, n)),
  ARRAY['寝', '寝かしつけ', 'お昼寝', 'よく寝る'], 'TK-5: 打ったあとの順は「完全一致 → 前方一致 → 短い名前 → 名前順」');

SELECT * FROM finish();
ROLLBACK;
