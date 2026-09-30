-- ============================================================
-- 設計書 12-6節のうち: 家庭・場の削除 TD-1〜TD-4／招待 TI-1〜TI-8／同意 TC-1〜TC-3
--   消すテストは test_fx.reset() で見本データを作り直してから行う。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(32);
SELECT test_fx.build();

-- ========== 家庭の削除 ==========
-- 状況: HA が作った①②（他家庭の③つき）／HA が作った①②（HA の③だけ）／HA の非公開③
SELECT test_fx.mk_problem('P_keep', 'S1', '残る困りごと', 'HA');
SELECT test_fx.mk_measure('M_keep', 'P_keep', '残る対策', 'HA');
SELECT test_fx.mk_trial('T_keep_b', 'M_keep', 'b1', 4, 'all');
SELECT test_fx.mk_trial('T_keep_a', 'M_keep', 'a1', 3, 'all');
SELECT test_fx.mk_problem('P_gone', 'S1', '消える困りごと', 'HA');
SELECT test_fx.mk_measure('M_gone', 'P_gone', '消える対策', 'HA');
SELECT test_fx.mk_trial('T_gone_a', 'M_gone', 'a2', 3, 'household');
SELECT test_fx.as_user('u0a');
SELECT public.create_invite(test_fx.id('HA'));

-- TD-3: household_deletion_preview(HA) → u0a には③の件数（非公開を含む）とメンバー数。b1 には行が無い
SELECT results_eq($$SELECT o_trial_count, o_member_count FROM public.household_deletion_preview(test_fx.id('HA'))$$,
  $$VALUES (2, 2)$$, 'TD-3: 管理者には HA の③の件数（非公開を含む2件）とメンバー数（2人）');
SELECT test_fx.as_user('b1');
SELECT is((SELECT count(*)::int FROM public.household_deletion_preview(test_fx.id('HA'))), 0, 'TD-3: メンバー b1 には行が無い');

-- TD-1: 家庭 HA を削除
SELECT test_fx.as_service();
SELECT is((SELECT array_agg(u ORDER BY u) FROM unnest(public.delete_household_data(test_fx.uid('u0a'), test_fx.id('HA'))) u),
  ARRAY[test_fx.uid('a1'), test_fx.uid('a2')], 'TD-1: 戻り値は a1・a2 のログイン ID');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.members mb WHERE mb.household_id = test_fx.id('HA')), 0, 'TD-1: HA のメンバーが消える');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id IN (test_fx.id('T_keep_a'), test_fx.id('T_gone_a'))), 0,
  'TD-1: HA の③（非公開も）が消える');
SELECT is((SELECT count(*)::int FROM public.invites iv WHERE iv.household_id = test_fx.id('HA')), 0, 'TD-1: HA の招待が消える');
SELECT is((SELECT ARRAY[p.created_household_id IS NULL, m.created_household_id IS NULL]
            FROM public.problems p JOIN public.measures m ON m.problem_id = p.id WHERE p.id = test_fx.id('P_keep')),
  ARRAY[true, true], 'TD-1: 他家庭の③が付いた①②は残り、作った家庭が空になる');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_keep_b')), 1, 'TD-1: 他家庭の③は残る');
SELECT is((SELECT count(*)::int FROM public.problems p WHERE p.id = test_fx.id('P_gone'))
        + (SELECT count(*)::int FROM public.measures m WHERE m.id = test_fx.id('M_gone')), 0,
  'TD-1: ③0件になった①②は消える');

-- TD-2: H0 を u0a が削除 → cannot_delete_own_household
SELECT test_fx.as_service();
SELECT throws_ok(format($$SELECT public.delete_household_data(%L, %L)$$, test_fx.uid('u0a'), test_fx.id('H0')),
  'P0001', 'cannot_delete_own_household', 'TD-2: 管理者の家庭は消せない');

-- TD-4: 場 S2 を x1 が削除 → S2 の全データが消える。um のログイン ID は返らない（S1 に残る）
SELECT test_fx.as_owner();
SELECT test_fx.reset();
SELECT test_fx.mk_problem('Q', 'S2', 'S2の困りごと', 'HX');
SELECT test_fx.mk_measure('N', 'Q', 'S2の対策', 'HX');
SELECT test_fx.mk_book('BK2', 'S2', 'S2の本', NULL, 'x1');
SELECT test_fx.mk_trial('U', 'N', 'um_s2', 4, 'all', 36, DATE '2026-09-01', 'book', 'BK2');
SELECT test_fx.as_service();
SELECT is((SELECT array_agg(u ORDER BY u) FROM unnest(public.delete_space_data(test_fx.uid('x1'), test_fx.id('S2'))) u),
  ARRAY[test_fx.uid('x1'), test_fx.uid('y1')], 'TD-4: 戻り値は x1・y1 だけ（um は S1 に残るので返らない）');
SELECT test_fx.as_owner();
SELECT is((SELECT (SELECT count(*) FROM public.spaces s WHERE s.id = test_fx.id('S2'))
               + (SELECT count(*) FROM public.households h WHERE h.space_id = test_fx.id('S2'))
               + (SELECT count(*) FROM public.members m WHERE m.space_id = test_fx.id('S2'))
               + (SELECT count(*) FROM public.tags t WHERE t.space_id = test_fx.id('S2'))
               + (SELECT count(*) FROM public.problems p WHERE p.space_id = test_fx.id('S2'))
               + (SELECT count(*) FROM public.measures m WHERE m.space_id = test_fx.id('S2'))
               + (SELECT count(*) FROM public.books b WHERE b.space_id = test_fx.id('S2'))
               + (SELECT count(*) FROM public.trials t WHERE t.space_id = test_fx.id('S2')))::int, 0,
  'TD-4: S2 の全データ（場・家庭・メンバー・タグ・①②③・本）が消える');
SELECT is((SELECT count(*)::int FROM public.members m WHERE m.id = test_fx.id('m_um_s1')), 1, 'TD-4: um の S1 の行は残る');
SELECT test_fx.as_service();
SELECT throws_ok(format($$SELECT public.delete_space_data(%L, %L)$$, test_fx.uid('b1'), test_fx.id('S1')),
  '42501', 'forbidden', 'TD-4（補い）: 管理者でない b1 は場を消せない');

-- ========== 招待 ==========
SELECT test_fx.as_owner();
SELECT test_fx.reset();
-- TI-1: 有効なコードで uo が参加 → joined。家庭はコードで指定した家庭
CREATE TEMP TABLE codes (k text PRIMARY KEY, code text) ON COMMIT DROP;   -- 発行したコードを覚えておく（テストの中だけ）
GRANT ALL ON codes TO authenticated, service_role;
SELECT test_fx.as_user('u0a');
INSERT INTO codes VALUES ('c1', public.create_invite(test_fx.id('HC')));
SELECT test_fx.as_user('uo');
SELECT is(public.join_with_invite_code((SELECT code FROM codes WHERE k = 'c1'), '新しい人'), 'joined', 'TI-1: 有効なコードで参加できる（joined）');
SELECT test_fx.as_owner();
SELECT is((SELECT mb.household_id FROM public.members mb WHERE mb.auth_user_id = test_fx.uid('uo')), test_fx.id('HC'),
  'TI-1: 入った家庭はコードで指定した HC');

-- TI-2: 同じコードをもう一度 → invalid（y1 が使おうとする）
SELECT test_fx.as_user('y1');
SELECT is(public.join_with_invite_code((SELECT code FROM codes WHERE k = 'c1'), 'Yの人'), 'invalid', 'TI-2: 使用済みのコードは invalid');

-- TI-3: 期限切れ／失効したコード → invalid（区別しない）
SELECT test_fx.as_user('u0a');
INSERT INTO codes VALUES ('expired', public.create_invite(test_fx.id('HC')));
INSERT INTO codes VALUES ('revoked', public.create_invite(test_fx.id('HC')));
SELECT test_fx.as_owner();
UPDATE public.invites SET expires_at = now() - interval '1 minute'
 WHERE code_hash = app_private.hash_invite_code((SELECT code FROM codes WHERE k = 'expired'));
SELECT test_fx.as_user('u0a');
UPDATE public.invites SET revoked_at = now()
 WHERE code_hash = app_private.hash_invite_code((SELECT code FROM codes WHERE k = 'revoked'));
SELECT test_fx.as_user('y1');
SELECT is(ARRAY[public.join_with_invite_code((SELECT code FROM codes WHERE k = 'expired'), 'Yの人'),
                public.join_with_invite_code((SELECT code FROM codes WHERE k = 'revoked'), 'Yの人')],
  ARRAY['invalid', 'invalid'], 'TI-3: 期限切れ・失効のコードはどちらも invalid（区別しない）');

-- TI-4: 5回まちがえた後 → 正しいコードでも locked（1時間）
SELECT test_fx.as_user('u0a');
INSERT INTO codes VALUES ('good', public.create_invite(test_fx.id('HC')));
SELECT test_fx.as_user('y1');   -- ここまでに y1 は3回まちがえている（TI-2・TI-3）
SELECT public.join_with_invite_code('ZZZZZZZZ', 'Yの人');
SELECT public.join_with_invite_code('ZZZZZZZZ', 'Yの人');
SELECT is(public.join_with_invite_code((SELECT code FROM codes WHERE k = 'good'), 'Yの人'), 'locked',
  'TI-4: 1時間に5回まちがえた後は、正しいコードでも locked');

-- TI-7: すでにその場のメンバー → already_member。コードは未使用のまま
SELECT test_fx.as_user('a1');
SELECT is(public.join_with_invite_code((SELECT code FROM codes WHERE k = 'good'), 'Aの夫'), 'already_member', 'TI-7: すでにメンバーなら already_member');
SELECT test_fx.as_owner();
SELECT is((SELECT iv.used_at FROM public.invites iv WHERE iv.code_hash = app_private.hash_invite_code((SELECT code FROM codes WHERE k = 'good'))), NULL::timestamptz,
  'TI-7: コードは未使用のまま');

-- TI-8: 「abcd efgh」のように小文字・空白で入力 → 通る（uo はもう S1 のメンバーなので、S2 に入らない人として b1 を S2 へ）
SELECT test_fx.as_user('x1');
INSERT INTO codes VALUES ('s2', public.create_invite(test_fx.id('HY')));
SELECT test_fx.as_user('b1');
SELECT is(public.join_with_invite_code(
            lower(substr((SELECT code FROM codes WHERE k = 's2'), 1, 4)) || ' ' || lower(substr((SELECT code FROM codes WHERE k = 's2'), 5, 4)),
            'Bの人'),
  'joined', 'TI-8: 小文字・空白まじりで入力しても参加できる');

-- TI-5: メンバーが上限（max_members）の場 → full
SELECT test_fx.as_owner();
UPDATE public.spaces SET max_members = (SELECT count(*) FROM public.members mb WHERE mb.space_id = test_fx.id('S1')) WHERE id = test_fx.id('S1');
SELECT test_fx.as_user('u0a');
INSERT INTO codes VALUES ('full', public.create_invite(test_fx.id('HC')));
SELECT test_fx.as_user('x1');
SELECT is(public.join_with_invite_code((SELECT code FROM codes WHERE k = 'full'), 'Xの管理者'), 'full', 'TI-5: メンバーが上限の場には入れない（full）');

-- TI-6: 家庭が上限の場で家庭を作る → limit_households
SELECT test_fx.as_owner();
UPDATE public.spaces SET max_households = 4 WHERE id = test_fx.id('S1');
SELECT test_fx.as_user('u0a');
SELECT throws_ok($$INSERT INTO public.households (space_id, display_name) VALUES (test_fx.id('S1'), '家庭D')$$,
  'P0001', 'limit_households', 'TI-6: 家庭が上限の場では家庭を作れない（limit_households）');

-- ========== 同意 ==========
SELECT test_fx.as_owner();
SELECT test_fx.reset();
SELECT test_fx.mk_problem('P', 'S1', '同意の困りごと', 'HB');
SELECT test_fx.mk_measure('M', 'P', '同意の対策', 'HB');
SELECT test_fx.mk_trial('T_b', 'M', 'b1', 3, 'all');
DELETE FROM public.consents WHERE auth_user_id = test_fx.uid('b1');
-- TC-1: 同意していない人が save_trial → consent_required
SELECT test_fx.as_user('b1');
SELECT is(public.has_agreed_current_rules(), false, 'TC-1（補い）: 同意していない b1 の has_agreed_current_rules は false');
SELECT throws_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 3)$$, test_fx.id('M')),
  'P0001', 'consent_required', 'TC-1: 同意していない人は書けない（consent_required）');
-- TC-3: 同意していない人が自分の③を消す → 消せる
SELECT is(test_fx.exec_count(format($$DELETE FROM public.trials WHERE id = %L$$, test_fx.id('T_b'))), 1,
  'TC-3: 同意していなくても自分の③は消せる');
-- TC-2: 同意したあと → 書ける
SELECT lives_ok('SELECT public.record_rules_consent(1)', 'TC-2: record_rules_consent(1) で同意できる');
SELECT lives_ok('SELECT public.record_rules_consent(1)', 'TC-2（補い）: 連打しても失敗しない');
SELECT throws_ok('SELECT public.record_rules_consent(0)', 'P0001', 'stale_version', 'TC-2（補い）: 古い版への同意は stale_version');
SELECT lives_ok(format($$SELECT test_fx.save_trial(p_measure_id => %L, p_score => 3)$$, test_fx.id('M')),
  'TC-2: 同意したあとは書ける');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.consents c WHERE c.auth_user_id = test_fx.uid('b1')), 1, 'TC-2（補い）: 同意の記録は1件だけ');

SELECT * FROM finish();
ROLLBACK;
