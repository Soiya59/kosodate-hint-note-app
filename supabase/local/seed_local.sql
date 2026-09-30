-- ============================================================
-- ローカル専用の見本データ（2026-09-30 開発部）
--
-- - ローカルの Supabase（Docker・ポート 55422）だけに流す。**本番には絶対に流さない。**
--   本番の最初の場は、設計書 v0.3 14-1節の6（統括のログインで bootstrap_space を1回）で作る。
-- - `supabase db reset` で自動では流れない（ファイル名を seed.sql にしていない）。
--   自動で流すと、supabase/tests の見本データとぶつかるおそれがあるため。
-- - メールアドレスは存在しない形（…@example.invalid）だけ。家族の名前は入れない。
-- - 何度流してもよい（先に同じ見本を消してから作り直す）。
--
-- 流し方（PowerShell。プログラムの置き場所で）:
--   Get-Content supabase\local\seed_local.sql -Encoding UTF8 | docker exec -i supabase_db_kosodate-hint-note-app psql -U postgres -d postgres -v ON_ERROR_STOP=1
--
-- できるもの:
--   ノート「試しのノート」（家庭4つ: 統括の家・兄の家・姉の家・弟の家）
--   ログイン2つ（どちらも番号のメールでログインできる。メールはローカルのメール受け http://127.0.0.1:55424 に届く）
--     kanri@example.invalid  … 統括の家・管理者・呼び名「統括（見本）」・同意済み
--     ani@example.invalid    … 兄の家・メンバー・呼び名「兄（見本）」・同意済み
--   困りごと・対策・試した結果の見本（数件。v0.4: 育てたい・試したい〈2〜3歳〉・テレビの見本も1件）
--   招待コード（7日有効・1回だけ使える）:
--     HNTA-2345 → 兄の家 ／ HNTB-2345 → 姉の家 ／ HNTC-2345 → 弟の家 ／ HNTD-2345 → 統括の家
--   使い切ったら supabase/local/reissue_invites.sql で出し直す。
-- ============================================================
\set ON_ERROR_STOP on
BEGIN;

-- 0. 前の見本を消す（場を消すと家庭・メンバー・①②③・招待も一緒に消える）
DELETE FROM public.spaces WHERE name = '試しのノート';
DELETE FROM auth.users WHERE email IN ('kanri@example.invalid', 'ani@example.invalid');

-- 1. ログイン（Supabase のログインの表。ローカルだけ。トークンの列を空文字にしておかないと、ログインのときに失敗する）
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
   'kanri@example.invalid', '', now(), '', '', '', '',
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
   'ani@example.invalid', '', now(), '', '', '', '',
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
SELECT u.id::text, u.id, jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
FROM auth.users u
WHERE u.email IN ('kanri@example.invalid', 'ani@example.invalid');

-- 2. ノート（場）・家庭・管理者・タグ11個（本番と同じ関数 bootstrap_space）
CREATE TEMP TABLE seed_ids (k text PRIMARY KEY, v uuid) ON COMMIT DROP;
INSERT INTO seed_ids
SELECT 'space', public.bootstrap_space('20000000-0000-0000-0000-000000000001', '試しのノート', '統括の家', '統括（見本）');

INSERT INTO public.households (space_id, display_name)
SELECT (SELECT v FROM seed_ids WHERE k = 'space'), x.n
FROM (VALUES ('兄の家'), ('姉の家'), ('弟の家')) AS x(n);

-- 兄の家に見本のメンバー（ふだんは招待コードで入る。見本のデータを「ほかの家庭」として書くため直接入れる）
INSERT INTO public.members (space_id, household_id, auth_user_id, display_name, role)
SELECT hh.space_id, hh.id, '20000000-0000-0000-0000-000000000002', '兄（見本）', 'member'
FROM public.households hh
WHERE hh.space_id = (SELECT v FROM seed_ids WHERE k = 'space') AND hh.display_name = '兄の家';

-- 3. 同意（書き方の約束 第1版）
INSERT INTO public.consents (auth_user_id, consent_version)
VALUES ('20000000-0000-0000-0000-000000000001', public.current_rules_version()),
       ('20000000-0000-0000-0000-000000000002', public.current_rules_version());

-- 4. 招待コード（コードそのものは保存しない。照合用の値だけ。期限は場の設定＝7日でトリガーが決める）
INSERT INTO public.invites (household_id, code_hash)
SELECT hh.id, app_private.hash_invite_code(x.code)
FROM public.households hh
JOIN (VALUES ('兄の家', 'HNTA2345'), ('姉の家', 'HNTB2345'), ('弟の家', 'HNTC2345'), ('統括の家', 'HNTD2345')) AS x(hname, code)
  ON x.hname = hh.display_name
WHERE hh.space_id = (SELECT v FROM seed_ids WHERE k = 'space');

-- 5. 見本の記録（本人になりすまして、画面と同じ関数 save_trial で書く。トリガー・RLS を通る）
GRANT SELECT, INSERT ON seed_ids TO authenticated;

-- 5-1. 統括（見本）として
SELECT set_config('role', 'authenticated', true),
       set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true),
       set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);

INSERT INTO seed_ids
SELECT 'book', public.ensure_book((SELECT v FROM seed_ids WHERE k = 'space'), 'ねんねの本（見本）', '見本 花子');

INSERT INTO seed_ids
SELECT 'm_ehon', (public.save_trial(
  (SELECT v FROM seed_ids WHERE k = 'space'), NULL, '寝ない',
  ARRAY(SELECT tg.id FROM public.tags tg WHERE tg.space_id = (SELECT v FROM seed_ids WHERE k = 'space') AND tg.name IN ('寝る', '気持ち・かんしゃく')),
  NULL, '寝る前に絵本', 4::smallint, 24::smallint, 'book', (SELECT v FROM seed_ids WHERE k = 'book'), NULL, NULL,
  '毎晩2冊まで。見本の記録です。', (now() AT TIME ZONE 'Asia/Tokyo')::date - 20, 'all') ->> 'measure_id')::uuid;

SELECT public.save_trial(
  (SELECT v FROM seed_ids WHERE k = 'space'),
  (SELECT me.problem_id FROM public.measures me WHERE me.id = (SELECT v FROM seed_ids WHERE k = 'm_ehon')),
  NULL, NULL, NULL, '部屋を真っ暗にする', NULL::smallint, 30::smallint, 'own', NULL, NULL, NULL,
  NULL, (now() AT TIME ZONE 'Asia/Tokyo')::date - 11, 'household');

SELECT public.save_trial(
  (SELECT v FROM seed_ids WHERE k = 'space'), NULL, '歯みがきを嫌がる',
  ARRAY(SELECT tg.id FROM public.tags tg WHERE tg.space_id = (SELECT v FROM seed_ids WHERE k = 'space') AND tg.name = '着替え・身支度'),
  NULL, '歌いながらみがく', 3::smallint, 42::smallint, 'heard', NULL, NULL, '保育士',
  NULL, (now() AT TIME ZONE 'Asia/Tokyo')::date - 5, 'all');

-- 5-1b. （v0.4 の列の見本・2026-09-30 追記）育てたい・試したい（範囲）・テレビ。v0.5 でタグは育てたいの「自分でする力」に（育てたいの①に困りごとのタグは付けられない）
SELECT public.save_trial(
  (SELECT v FROM seed_ids WHERE k = 'space'), NULL, '自分でやろうとする力',
  ARRAY(SELECT tg.id FROM public.tags tg WHERE tg.space_id = (SELECT v FROM seed_ids WHERE k = 'space') AND tg.name = '自分でする力'),
  NULL, 'できたことを言葉にして返す', NULL::smallint, 24::smallint, 'tv', NULL, NULL, NULL,
  '見本の記録です。', (now() AT TIME ZONE 'Asia/Tokyo')::date - 2, 'all',
  'grow', 'want', 36::smallint, '夕方の子育て特集（見本）');

-- 5-2. 兄（見本）として（同じ対策に「うちでも試した」）
SELECT set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000002","role":"authenticated"}', true),
       set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);

SELECT public.save_trial(
  NULL, NULL, NULL, NULL, (SELECT v FROM seed_ids WHERE k = 'm_ehon'), NULL, 5::smallint, 36::smallint, 'web', NULL,
  'https://example.invalid/sleep', NULL, '絵本より先に部屋を暗くした。見本の記録です。', (now() AT TIME ZONE 'Asia/Tokyo')::date - 3, 'all');

SELECT public.save_trial(
  (SELECT v FROM seed_ids WHERE k = 'space'), NULL, 'ごはんを立ち歩く',
  ARRAY(SELECT tg.id FROM public.tags tg WHERE tg.space_id = (SELECT v FROM seed_ids WHERE k = 'space') AND tg.name = '食べる'),
  NULL, '座ったら1口ほめる', 2::smallint, 36::smallint, 'own', NULL, NULL, NULL,
  NULL, (now() AT TIME ZONE 'Asia/Tokyo')::date - 1, 'all');

RESET role;
COMMIT;

-- 確かめ（件数）
SELECT 'households' AS what, count(*) FROM public.households
UNION ALL SELECT 'members', count(*) FROM public.members
UNION ALL SELECT 'problems', count(*) FROM public.problems
UNION ALL SELECT 'measures', count(*) FROM public.measures
UNION ALL SELECT 'trials', count(*) FROM public.trials
UNION ALL SELECT 'invites(unused)', count(*) FROM public.invites WHERE used_at IS NULL;
