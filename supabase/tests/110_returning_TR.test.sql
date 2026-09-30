-- ============================================================
-- 設計書 v0.3 12-6節 TR-1〜TR-3（6-1節「RETURNING の落とし穴」の見張り）（S1）
--   ①②の表への INSERT … RETURNING は、SELECT のポリシーが見える一覧の関数（STABLE）経由なので、
--   入れたばかりの行が見えず必ず拒否される（v0.2 で開発部が見つけた修正1＝v0.3 の W1）。
--   TR-1・TR-2 は「落とし穴がまだある」ことを確かめ、この形を関数・画面に書かないことの見張りにする。
--   もし将来 RLS の作りを変えてこの2件が落ちたら、落とし穴が無くなったということなので、設計書 6-1節と一緒に直す。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(8);
SELECT test_fx.build();

SELECT test_fx.mk_problem('P', 'S1', 'TRの困りごと', 'HB');

SELECT test_fx.as_user('b1');
-- TR-1: ①の INSERT … RETURNING は拒否（42501）、RETURNING なしは通る
SELECT throws_ok($$INSERT INTO public.problems (space_id, name) VALUES (test_fx.id('S1'), 'TR1 RETURNING') RETURNING id$$,
  '42501', NULL, 'TR-1: ①の INSERT … RETURNING id は拒否（42501）');
SELECT lives_ok($$INSERT INTO public.problems (space_id, name) VALUES (test_fx.id('S1'), 'TR1 RETURNINGなし')$$,
  'TR-1: ①の INSERT（RETURNING なし）は通る');

-- TR-2: 見える①の下に②の INSERT … RETURNING は拒否（42501）、RETURNING なしは通る
SELECT throws_ok($$INSERT INTO public.measures (problem_id, name) VALUES (test_fx.id('P'), 'TR2 RETURNING') RETURNING id$$,
  '42501', NULL, 'TR-2: ②の INSERT … RETURNING id は拒否（42501）');
SELECT lives_ok($$INSERT INTO public.measures (problem_id, name) VALUES (test_fx.id('P'), 'TR2 RETURNINGなし')$$,
  'TR-2: ②の INSERT（RETURNING なし）は通る');

-- TR-3: 本の INSERT … RETURNING は通る／save_trial で新しい①②③を作れる（W1）
SELECT lives_ok($$INSERT INTO public.books (space_id, title) VALUES (test_fx.id('S1'), 'TR3の本') RETURNING id$$,
  'TR-3: 本の INSERT … RETURNING id は通る（SELECT のポリシーが列だけで決まるため）');
SELECT lives_ok($$SELECT test_fx.save_trial(p_space_id => test_fx.id('S1'), p_problem_name => 'TR3の困りごと',
                    p_measure_name => 'TR3の対策', p_score => 4)$$,
  'TR-3: save_trial で新しい①②③を1回で作れる（W1）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.trials t JOIN public.measures m ON m.id = t.measure_id
            JOIN public.problems p ON p.id = m.problem_id WHERE p.name = 'TR3の困りごと' AND m.name = 'TR3の対策'), 1,
  'TR-3: 作った①②③がつながって入っている');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.name = 'TR1 RETURNING'), 0,
  'TR-1（補い）: 拒否された①は入っていない');

SELECT * FROM finish();
ROLLBACK;
