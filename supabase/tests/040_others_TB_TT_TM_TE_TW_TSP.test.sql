-- ============================================================
-- 設計書 12-2節「その他」: 本 TB-C1・TB-U1〜U3・TB-D1〜D4／タグ TT-C1・C2・U1／
--   管理 TM-1〜TM-8／書き出し TE-1・TE-2／退会 TW-1〜TW-4／場の一覧 TSP-1（S1。TSP-1 は S1・S2）
-- 消すテスト（TM-4・TM-5・TW-*）は、1つずつ test_fx.reset() で見本データを作り直してから行う。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(60);
SELECT test_fx.build();

-- ========== 本 ==========
-- TB-C1: b1 が ensure_book → 登録。同じ題名・著者でもう一度 → 同じ ID
SELECT test_fx.as_user('b1');
SELECT test_fx.put('B_c1', public.ensure_book(test_fx.id('S1'), 'ねんねの本', '著者一'));
SELECT isnt(test_fx.id('B_c1'), NULL, 'TB-C1: ensure_book で本を登録できる');
SELECT is(public.ensure_book(test_fx.id('S1'), 'ねんねの本', '著者一'), test_fx.id('B_c1'),
  'TB-C1: 同じ題名・著者でもう一度呼ぶと同じ ID');
SELECT is(public.ensure_book(test_fx.id('S1'), '　ねんねの本 ', '著者一'), test_fx.id('B_c1'),
  'TB-C1（補い）: 前後の空白（全角も）を取ってから同じ本と判定する');

-- TB-U1〜U3: b1 が登録した本 → u0a・b1 は直せる、a1 は0行
SELECT test_fx.as_user('u0a');
SELECT is(test_fx.exec_count(format($$UPDATE public.books SET title = 'ねんねの本（改）' WHERE id = %L$$, test_fx.id('B_c1'))), 1,
  'TB-U1: 管理者 u0a はその場の本の題名を直せる');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$UPDATE public.books SET title = 'ねんねの本' WHERE id = %L$$, test_fx.id('B_c1'))), 1,
  'TB-U2: 登録した b1 は直せる');
SELECT test_fx.as_user('a1');
SELECT is(test_fx.exec_count(format($$UPDATE public.books SET title = '乗っ取り' WHERE id = %L$$, test_fx.id('B_c1'))), 0,
  'TB-U3: 登録していない a1 は直せない（0行）');

-- TB-D1: A の非公開③が使う本（b1 が登録）→ b1 が DELETE → 0行
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P', 'S1', '本の困りごと', 'HA');
SELECT test_fx.mk_measure('M', 'P', '本の対策', 'HA');
SELECT test_fx.mk_book('B_used', 'S1', '使われている本', NULL, 'b1');
SELECT test_fx.mk_trial('T_book', 'M', 'a1', 4, 'household', 36, DATE '2026-09-01', 'book', 'B_used');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.books WHERE id = %L$$, test_fx.id('B_used'))), 0,
  'TB-D1: 見えない非公開③が使っている本は、登録した b1 でも消せない（0行）');

-- TB-D2・TB-D3: 使う③が0件の本 → a1（登録していない）は0行、b1 は消せる
SELECT test_fx.as_owner();
SELECT test_fx.mk_book('B_free', 'S1', '使われていない本', '著者二', 'b1');
SELECT test_fx.as_user('a1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.books WHERE id = %L$$, test_fx.id('B_free'))), 0,
  'TB-D3: 登録していない a1 は、使われていない本も消せない（0行）');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.books WHERE id = %L$$, test_fx.id('B_free'))), 1,
  'TB-D2: 使う③が0件の本は、登録した b1 が消せる');

-- TB-D4（v0.2）: 使う③0件の本（b1 が登録）→ a1 の delete_book は false、b1 は true
SELECT test_fx.as_owner();
SELECT test_fx.mk_book('B_d4', 'S1', '消す本', NULL, 'b1');
SELECT test_fx.as_user('a1');
SELECT is(public.delete_book(test_fx.id('B_d4')), false, 'TB-D4: 登録していない a1 の delete_book は false');
SELECT test_fx.as_user('b1');
SELECT is(public.delete_book(test_fx.id('B_d4')), true, 'TB-D4: 登録した b1 の delete_book は true');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.books b WHERE b.id = test_fx.id('B_d4')), 0, 'TB-D4: 本が消えている');

-- ========== タグ ==========
-- TT-C1: u0a がタグ「病院」を追加 → 並びは「外出」の次・「その他」の前
SELECT test_fx.as_user('u0a');
SELECT lives_ok($$INSERT INTO public.tags (space_id, name) VALUES (test_fx.id('S1'), '病院')$$, 'TT-C1: 管理者がタグを追加できる');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(t.name ORDER BY t.sort_order) FROM (
            SELECT tg.name, tg.sort_order FROM public.tags tg WHERE tg.space_id = test_fx.id('S1') AND tg.kind IN ('trouble', 'both')
            ORDER BY tg.sort_order DESC LIMIT 3) t),
  ARRAY['外出', '病院', 'その他'], 'TT-C1: 並びは「外出」の次・「その他」の前');

-- TT-C2: b1 がタグを追加 → 拒否
SELECT test_fx.as_user('b1');
SELECT throws_ok($$INSERT INTO public.tags (space_id, name) VALUES (test_fx.id('S1'), '勝手タグ')$$, '42501', NULL,
  'TT-C2: メンバーはタグを追加できない');

-- TT-U1: u0a がタグの名前を UPDATE／DELETE → 0行（次フェーズ）
SELECT test_fx.as_user('u0a');
SELECT is(test_fx.exec_count(format($$UPDATE public.tags SET name = 'ねる' WHERE id = %L$$, test_fx.id('tag1_寝る'))), 0,
  'TT-U1: タグの名前は変えられない（0行）');
SELECT is(test_fx.exec_count(format($$DELETE FROM public.tags WHERE id = %L$$, test_fx.id('tag1_寝る'))), 0,
  'TT-U1: タグは消せない（0行）');

-- ========== 管理 ==========
-- TM-1: u0a が create_invite(HB) → 8文字／b1 が同じ → 拒否
SELECT test_fx.as_user('u0a');
SELECT matches(public.create_invite(test_fx.id('HB')), '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$',
  'TM-1: 管理者の create_invite は、紛らわしい文字を除いた8文字を返す');
SELECT test_fx.as_user('b1');
SELECT throws_ok(format($$SELECT public.create_invite(%L)$$, test_fx.id('HB')), '42501', NULL,
  'TM-1: メンバーの create_invite は拒否');

-- TM-2: u0a が発行した招待 → u0a が失効できる／b1 は0行
SELECT test_fx.as_owner();
SELECT test_fx.put('INV', (SELECT iv.id FROM public.invites iv WHERE iv.household_id = test_fx.id('HB') LIMIT 1));
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$UPDATE public.invites SET revoked_at = now() WHERE id = %L$$, test_fx.id('INV'))), 0,
  'TM-2: メンバーは招待を失効できない（0行）');
SELECT test_fx.as_user('u0a');
SELECT is(test_fx.exec_count(format($$UPDATE public.invites SET revoked_at = now() WHERE id = %L$$, test_fx.id('INV'))), 1,
  'TM-2: 管理者は招待を失効できる');

-- TM-3: u0a が家庭を作る → できる／b1 → 拒否
--   （v0.3 W2）メンバーの拒否は forbidden（42501）。上限（5）に達した後でも、上限より先に forbidden になる
SELECT test_fx.as_user('b1');
SELECT throws_ok($$INSERT INTO public.households (space_id, display_name) VALUES (test_fx.id('S1'), '家庭E')$$, '42501', 'forbidden',
  'TM-3: メンバーは家庭を作れない（forbidden・42501）');
SELECT test_fx.as_user('u0a');
SELECT lives_ok($$INSERT INTO public.households (space_id, display_name) VALUES (test_fx.id('S1'), '家庭D')$$,
  'TM-3: 管理者は家庭を作れる');
SELECT test_fx.as_user('b1');
SELECT throws_ok($$INSERT INTO public.households (space_id, display_name) VALUES (test_fx.id('S1'), '家庭F')$$, '42501', 'forbidden',
  'TM-3（v0.3）: S1 の家庭が上限（5）に達していても、b1 には forbidden（42501）');

-- TM-6（v0.2）: 家庭の表示名の変更
SELECT test_fx.as_user('u0a');
SELECT is(test_fx.exec_count(format($$UPDATE public.households SET display_name = '弟の家' WHERE id = %L$$, test_fx.id('HB'))), 1,
  'TM-6: 管理者は HB の表示名を「弟の家」に変えられる');
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$UPDATE public.households SET display_name = '乗っ取り' WHERE id = %L$$, test_fx.id('HA'))), 0,
  'TM-6: メンバーは家庭の表示名を変えられない（0行）');
SELECT test_fx.as_user('u0a');
SELECT throws_ok(format($$UPDATE public.households SET display_name = '家庭A' WHERE id = %L$$, test_fx.id('HB')), '23505', NULL,
  'TM-6: 同じ場に同じ名前の家庭があると 23505');
SELECT is(test_fx.exec_count(format($$UPDATE public.households SET display_name = '乗っ取り' WHERE id = %L$$, test_fx.id('HX'))), 0,
  'TM-6: 別の場（S2）の家庭は変えられない（0行）');

-- TM-7（v0.2）: 自分の表示名
SELECT test_fx.as_user('b1');
SELECT is(test_fx.exec_count(format($$UPDATE public.members SET display_name = 'Bさん' WHERE id = %L$$, test_fx.id('m_b1'))), 1,
  'TM-7: 自分の表示名は変えられる');
SELECT is(test_fx.exec_count(format($$UPDATE public.members SET display_name = '乗っ取り' WHERE id = %L$$, test_fx.id('m_a1'))), 0,
  'TM-7: 他の人の表示名は変えられない（0行）');
SELECT throws_ok(format($$UPDATE public.members SET role = 'admin' WHERE id = %L$$, test_fx.id('m_b1')), 'P0001', 'immutable_column',
  'TM-7: 自分の役割を admin にはできない（immutable_column）');

-- TM-8（v0.2）: 行の番号（id）は変えられない
SELECT test_fx.as_user('u0a');
SELECT throws_ok(format($$UPDATE public.households SET id = gen_random_uuid() WHERE id = %L$$, test_fx.id('HB')), 'P0001', 'immutable_column',
  'TM-8: 家庭の id は変えられない（immutable_column）');
SELECT test_fx.as_owner();
SELECT test_fx.mk_trial('T_a1', 'M', 'a1', 3, 'all');
SELECT test_fx.as_user('a1');
SELECT throws_ok(format($$UPDATE public.trials SET id = gen_random_uuid() WHERE id = %L$$, test_fx.id('T_a1')), 'P0001', 'immutable_column',
  'TM-8: ③の id は変えられない（immutable_column）');

-- ========== 書き出し ==========
-- TE-1: A の非公開③だけの①②がある → b1・u0a の export_visible_data(S1) に入らない。メール・ログイン ID も入らない
SELECT test_fx.as_owner();
SELECT test_fx.mk_problem('P_priv', 'S1', '非公開だけの困りごと', 'HA');
SELECT test_fx.mk_measure('M_priv', 'P_priv', '非公開だけの対策', 'HA');
SELECT test_fx.mk_trial('T_priv', 'M_priv', 'a1', 5, 'household');
SELECT test_fx.as_user('b1');
SELECT ok(position(test_fx.id('P_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0
      AND position(test_fx.id('M_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0
      AND position(test_fx.id('T_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0,
  'TE-1: b1 の書き出しに、A の非公開③だけの①②③が入らない');
SELECT ok(position('@' IN public.export_visible_data(test_fx.id('S1'))::text) = 0
      AND NOT EXISTS (SELECT 1 FROM test_fx.users u WHERE position(u.uid::text IN public.export_visible_data(test_fx.id('S1'))::text) > 0),
  'TE-1: b1 の書き出しにメールアドレス・ログイン ID が入らない');
SELECT test_fx.as_user('u0a');
SELECT ok(position(test_fx.id('P_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0
      AND position(test_fx.id('T_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) = 0,
  'TE-1: 管理者 u0a の書き出しにも入らない');
SELECT ok(position('@' IN public.export_visible_data(test_fx.id('S1'))::text) = 0
      AND NOT EXISTS (SELECT 1 FROM test_fx.users u WHERE position(u.uid::text IN public.export_visible_data(test_fx.id('S1'))::text) > 0),
  'TE-1: 管理者 u0a の書き出しにもメールアドレス・ログイン ID が入らない');
-- TE-2: 同じ → a1 の書き出しには入っている
SELECT test_fx.as_user('a1');
SELECT ok(position(test_fx.id('P_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) > 0
      AND position(test_fx.id('M_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) > 0
      AND position(test_fx.id('T_priv')::text IN public.export_visible_data(test_fx.id('S1'))::text) > 0,
  'TE-2: a1 の書き出しには自家庭の非公開③とその①②が入っている');

-- ========== 場の一覧 ==========
-- TSP-1（v0.2）: um が list_my_spaces() → 2行。管理者の表示名つき。uo は0行
SELECT test_fx.as_user('um');
SELECT is((SELECT count(*)::int FROM public.list_my_spaces()), 2, 'TSP-1: 2つの場に入っている um には2行');
SELECT is((SELECT l.o_admin_display_name FROM public.list_my_spaces() l WHERE l.o_space_id = test_fx.id('S1')), '統括',
  'TSP-1: S1 の行の管理者の表示名は u0a の表示名');
SELECT is((SELECT l.o_admin_display_name FROM public.list_my_spaces() l WHERE l.o_space_id = test_fx.id('S2')), 'Xの管理者',
  'TSP-1: S2 の行の管理者の表示名は x1 の表示名');
SELECT is((SELECT l.o_household_id FROM public.list_my_spaces() l WHERE l.o_space_id = test_fx.id('S2')), test_fx.id('HX'),
  'TSP-1（補い）: S2 の行の自分の家庭は HX');
SELECT test_fx.as_user('uo');
SELECT is((SELECT count(*)::int FROM public.list_my_spaces()), 0, 'TSP-1: どの場でもない uo には0行');

-- TSP-2（v0.3 W3）: um の S2 の行の created_at を S1 の行より前にする → list_my_spaces の順は S2 → S1（参加した順）
SELECT test_fx.as_owner();
--   トリガーが created_at を上書きしないよう、その間だけ止める（ROLLBACK で元に戻る）
ALTER TABLE public.members DISABLE TRIGGER USER;
UPDATE public.members SET created_at = now() - interval '1 day' WHERE id = test_fx.id('m_um_s2');
ALTER TABLE public.members ENABLE TRIGGER USER;
SELECT test_fx.as_user('um');
SELECT is((SELECT array_agg(l.o_space_id ORDER BY l.n) FROM public.list_my_spaces() WITH ORDINALITY l(o_space_id, a, b, c, d, e, f, g, h, i, n)),
  ARRAY[test_fx.id('S2'), test_fx.id('S1')], 'TSP-2: list_my_spaces は参加した順（S2 → S1）');

-- ========== 管理者によるメンバー・家庭の削除（service_role） ==========
-- TM-4: delete_member_data(a1, b1 の ID) → forbidden ／ (u0a, b1 の ID) → 消える
SELECT test_fx.as_owner();
SELECT test_fx.reset();
SELECT test_fx.as_service();
SELECT throws_ok(format($$SELECT public.delete_member_data(%L, %L, false)$$, test_fx.uid('a1'), test_fx.id('m_b1')), '42501', 'forbidden',
  'TM-4: 管理者でない a1 が b1 を外そうとすると forbidden');
SELECT lives_ok(format($$SELECT public.delete_member_data(%L, %L, false)$$, test_fx.uid('u0a'), test_fx.id('m_b1')),
  'TM-4: 管理者 u0a は b1 を外せる');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.members mb WHERE mb.id = test_fx.id('m_b1')), 0, 'TM-4: b1 の行が消えている');

-- TM-5: delete_household_data(b1, HC) → forbidden ／ (u0a, HC) → 消える
SELECT test_fx.reset();
SELECT test_fx.as_service();
SELECT throws_ok(format($$SELECT public.delete_household_data(%L, %L)$$, test_fx.uid('b1'), test_fx.id('HC')), '42501', 'forbidden',
  'TM-5: 管理者でない b1 は家庭を消せない（forbidden）');
SELECT is(public.delete_household_data(test_fx.uid('u0a'), test_fx.id('HC')), ARRAY[test_fx.uid('c1')],
  'TM-5: 管理者 u0a は HC を消せる（戻り値は c1 のログイン ID）');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.households hh WHERE hh.id = test_fx.id('HC')), 0, 'TM-5: HC が消えている');

-- ========== 退会 ==========
-- TW-1: delete_member_data(b1, b1, true) → b1 の③が消え、b1 の行が消え、b1 のログイン ID が返る
SELECT test_fx.reset();
SELECT test_fx.mk_problem('P', 'S1', '退会の困りごと', 'HA');
SELECT test_fx.mk_measure('M', 'P', '退会の対策', 'HA');
SELECT test_fx.mk_trial('T_a', 'M', 'a1', 4, 'all');
SELECT test_fx.mk_trial('T_b_pub', 'M', 'b1', 3, 'all');
SELECT test_fx.mk_trial('T_b_priv', 'M', 'b1', 2, 'household');
SELECT test_fx.as_service();
SELECT is(public.delete_member_data(test_fx.uid('b1'), test_fx.id('m_b1'), true), test_fx.uid('b1'),
  'TW-1: 本人の退会（③も消す）→ b1 のログイン ID が返る');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id IN (test_fx.id('T_b_pub'), test_fx.id('T_b_priv'))), 0,
  'TW-1: b1 が書いた③（みんな・非公開）が消えている');
SELECT is((SELECT count(*)::int FROM public.members mb WHERE mb.id = test_fx.id('m_b1')), 0, 'TW-1: b1 の行が消えている');
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_a')), 1, 'TW-1: 他の人の③は残っている');

-- TW-2: delete_member_data(u0a, u0a, false) → admin_cannot_leave
SELECT test_fx.as_service();
SELECT throws_ok(format($$SELECT public.delete_member_data(%L, %L, false)$$, test_fx.uid('u0a'), test_fx.id('m_u0a')), 'P0001', 'admin_cannot_leave',
  'TW-2: 管理者は退会できない（admin_cannot_leave）');

-- TW-3（v0.2）: b1 が書いた③がある → delete_member_data(u0a, b1, NULL) → ③は残る（家庭 HB・書いた人は空）。b1 の行は消える
SELECT test_fx.as_owner();
SELECT test_fx.reset();
SELECT test_fx.mk_problem('P', 'S1', '外すの困りごと', 'HA');
SELECT test_fx.mk_measure('M', 'P', '外すの対策', 'HA');
SELECT test_fx.mk_trial('T_b_pub', 'M', 'b1', 3, 'all');
SELECT test_fx.mk_trial('T_b_priv', 'M', 'b1', 2, 'household');
SELECT test_fx.as_service();
SELECT is(public.delete_member_data(test_fx.uid('u0a'), test_fx.id('m_b1'), NULL), test_fx.uid('b1'),
  'TW-3: 管理者が b1 を外す（③の選択を省略）→ b1 はどの場にも残らないのでログイン ID が返る');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.trials t
            WHERE t.id IN (test_fx.id('T_b_pub'), test_fx.id('T_b_priv'))
              AND t.household_id = test_fx.id('HB') AND t.created_by_member_id IS NULL), 2,
  'TW-3: 省略時は「残す」＝b1 の③（みんな・非公開）は家庭 HB の③として残り、書いた人は空');
SELECT is((SELECT count(*)::int FROM public.members mb WHERE mb.id = test_fx.id('m_b1')), 0, 'TW-3: b1 の行は消える');

-- TW-4（v0.2）: c1 が書いた③がある → delete_member_data(c1, c1, NULL) → c1 の③は消える。c1 のログイン ID が返る
SELECT test_fx.mk_trial('T_c', 'M', 'c1', 4, 'all');
SELECT test_fx.as_service();
SELECT is(public.delete_member_data(test_fx.uid('c1'), test_fx.id('m_c1'), NULL), test_fx.uid('c1'),
  'TW-4: 本人の退会で③の選択を省略 → c1 のログイン ID が返る');
SELECT test_fx.as_owner();
SELECT is((SELECT count(*)::int FROM public.trials t WHERE t.id = test_fx.id('T_c')), 0,
  'TW-4: 省略時は「消す」＝c1 の③は消える');

SELECT * FROM finish();
ROLLBACK;
