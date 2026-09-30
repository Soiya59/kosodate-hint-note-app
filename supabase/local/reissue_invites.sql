-- ============================================================
-- ローカル専用: 見本の招待コードを出し直す（2026-09-30 開発部）
-- 本番には流さない。seed_local.sql の後で、コードを使い切ったときに流す。
--   Get-Content supabase\local\reissue_invites.sql -Encoding UTF8 | docker exec -i supabase_db_kosodate-hint-note-app psql -U postgres -d postgres -v ON_ERROR_STOP=1
-- 同じコード（HNTA-2345 など）の古い行を消してから、新しく7日有効で入れる。
-- 「まちがいが続いたため入れない（locked）」の解除もする（招待の失敗の記録を消す。ローカルだけ）。
-- ============================================================
\set ON_ERROR_STOP on
BEGIN;
DELETE FROM public.invites
 WHERE code_hash IN (SELECT app_private.hash_invite_code(c) FROM unnest(ARRAY['HNTA2345','HNTB2345','HNTC2345','HNTD2345']) AS c);
INSERT INTO public.invites (household_id, code_hash)
SELECT hh.id, app_private.hash_invite_code(x.code)
FROM public.households hh
JOIN public.spaces sp ON sp.id = hh.space_id AND sp.name = '試しのノート'
JOIN (VALUES ('兄の家', 'HNTA2345'), ('姉の家', 'HNTB2345'), ('弟の家', 'HNTC2345'), ('統括の家', 'HNTD2345')) AS x(hname, code)
  ON x.hname = hh.display_name;
DELETE FROM public.invite_attempts WHERE NOT succeeded;
COMMIT;
SELECT count(*) AS unused_invites FROM public.invites WHERE used_at IS NULL;
