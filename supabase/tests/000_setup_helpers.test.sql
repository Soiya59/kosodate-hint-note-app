-- ============================================================
-- 000: テスト用の道具（見本データを作る関数・なりすましの関数）を入れる
--
-- 設計書: 設計部/成果物/データと権限の設計書_v0.2（2026-09-30）.md 12-1節
--   「見本データ（テストの最初に、持ち主の権限で入れる）」と「なりすまし方」を関数にしたもの。
--
-- - このファイルだけは最後に COMMIT する（ほかのテストファイルから使うため）。
--   入るのは test_fx スキーマ（テスト用の道具）だけで、見本データそのものは入れない。
--   見本データは各テストファイルが BEGIN の後に test_fx.build() で作り、最後の ROLLBACK で消える。
-- - ファイル名の 000 は「最初に流す」ため（pg_prove はファイル名の順に流す）。
-- - ローカルの Supabase と GitHub Actions の中だけで使う。本番には流さない（設計書 12-1節）。
-- - メールアドレスは存在しない形（…@example.invalid）だけを使う。
-- ============================================================
BEGIN;
SET LOCAL client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

DROP SCHEMA IF EXISTS test_fx CASCADE;
CREATE SCHEMA test_fx;
GRANT USAGE ON SCHEMA test_fx TO anon, authenticated, service_role;

-- 見本の利用者（設計書 12-1節の表）。ID は固定。
CREATE TABLE test_fx.users (name text PRIMARY KEY, uid uuid NOT NULL UNIQUE);
INSERT INTO test_fx.users (name, uid) VALUES
  ('u0a', '10000000-0000-0000-0000-000000000001'),
  ('u0b', '10000000-0000-0000-0000-000000000002'),
  ('a1',  '10000000-0000-0000-0000-000000000003'),
  ('a2',  '10000000-0000-0000-0000-000000000004'),
  ('b1',  '10000000-0000-0000-0000-000000000005'),
  ('um',  '10000000-0000-0000-0000-000000000006'),
  ('c1',  '10000000-0000-0000-0000-000000000007'),
  ('x1',  '10000000-0000-0000-0000-000000000008'),
  ('y1',  '10000000-0000-0000-0000-000000000009'),
  ('uo',  '10000000-0000-0000-0000-00000000000a');

-- 作った行の ID を名前で引くための表（中身は各テストの中だけ。ROLLBACK で消える）
CREATE TABLE test_fx.ids (k text PRIMARY KEY, v uuid NOT NULL);

CREATE FUNCTION test_fx.uid(p_name text) RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.uid FROM test_fx.users u WHERE u.name = p_name
$$;

CREATE FUNCTION test_fx.id(p_key text) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v uuid;
BEGIN
  SELECT i.v INTO v FROM test_fx.ids i WHERE i.k = p_key;
  IF v IS NULL THEN RAISE EXCEPTION 'test_fx.id: unknown key %', p_key; END IF;
  RETURN v;
END $$;

CREATE FUNCTION test_fx.put(p_key text, p_id uuid) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
  INSERT INTO test_fx.ids (k, v) VALUES (p_key, p_id)
  ON CONFLICT (k) DO UPDATE SET v = excluded.v
  RETURNING v
$$;

-- ------------------------------------------------------------
-- なりすまし（設計書 12-1節の SET LOCAL ROLE ／ request.jwt.claims と同じこと）
-- ------------------------------------------------------------
CREATE FUNCTION test_fx.as_user(p_name text) RETURNS void
LANGUAGE plpgsql VOLATILE AS $$
DECLARE v uuid := test_fx.uid(p_name);
BEGIN
  IF v IS NULL THEN RAISE EXCEPTION 'test_fx.as_user: unknown user %', p_name; END IF;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v::text, true);
END $$;

CREATE FUNCTION test_fx.as_anon() RETURNS void
LANGUAGE plpgsql VOLATILE AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END $$;

CREATE FUNCTION test_fx.as_service() RETURNS void
LANGUAGE plpgsql VOLATILE AS $$
BEGIN
  PERFORM set_config('role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END $$;

-- 見本データを入れる側（接続した持ち主＝postgres）に戻る
CREATE FUNCTION test_fx.as_owner() RETURNS void
LANGUAGE plpgsql VOLATILE AS $$
BEGIN
  PERFORM set_config('role', 'none', true);
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END $$;

-- 今の立場で SQL を1本流し、変わった行の数を返す（「0行」の確かめに使う）。
-- SECURITY INVOKER なので、RLS は今の立場のまま効く。
CREATE FUNCTION test_fx.exec_count(p_sql text) RETURNS integer
LANGUAGE plpgsql VOLATILE AS $$
DECLARE v_rows integer;
BEGIN
  EXECUTE p_sql;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows;
END $$;

-- ------------------------------------------------------------
-- 見本データ（設計書 12-1節の表）
--   S1（4家庭）: H0 統括の家（u0a 管理者・u0b）／HA 家庭A（a1・a2）／HB 家庭B（b1・um）／HC 家庭C（c1）
--   S2（2家庭）: HX 家庭X（x1 管理者・um）／HY 家庭Y（y1）
--   uo: どの場でもない（ログインだけ）
--   全員を同意済みにする（同意のテストは、その中で同意を消す）。
-- ------------------------------------------------------------
CREATE FUNCTION test_fx.build() RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_s1 uuid; v_s2 uuid;
  v_h0 uuid; v_ha uuid; v_hb uuid; v_hc uuid; v_hx uuid; v_hy uuid;
  r record;
BEGIN
  DELETE FROM test_fx.ids;
  INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
  SELECT u.uid, u.name || '@example.invalid', 'authenticated', 'authenticated', now(), now()
  FROM test_fx.users u;

  -- S1（場を作る関数 bootstrap_space を使う＝管理者・最初の家庭・タグ11個も作られる）
  v_s1 := public.bootstrap_space(test_fx.uid('u0a'), 'テストの場1', '統括の家', '統括');
  SELECT mb.household_id INTO v_h0 FROM public.members mb
   WHERE mb.space_id = v_s1 AND mb.auth_user_id = test_fx.uid('u0a');
  INSERT INTO public.households (space_id, display_name) VALUES (v_s1, '家庭A') RETURNING id INTO v_ha;
  INSERT INTO public.households (space_id, display_name) VALUES (v_s1, '家庭B') RETURNING id INTO v_hb;
  INSERT INTO public.households (space_id, display_name) VALUES (v_s1, '家庭C') RETURNING id INTO v_hc;
  INSERT INTO public.members (space_id, household_id, auth_user_id, display_name) VALUES
    (v_s1, v_h0, test_fx.uid('u0b'), '統括の妻'),
    (v_s1, v_ha, test_fx.uid('a1'),  'Aの夫'),
    (v_s1, v_ha, test_fx.uid('a2'),  'Aの妻'),
    (v_s1, v_hb, test_fx.uid('b1'),  'Bの人'),
    (v_s1, v_hb, test_fx.uid('um'),  '二つの場の人'),
    (v_s1, v_hc, test_fx.uid('c1'),  'Cの人');

  -- S2
  v_s2 := public.bootstrap_space(test_fx.uid('x1'), 'テストの場2', '家庭X', 'Xの管理者');
  SELECT mb.household_id INTO v_hx FROM public.members mb
   WHERE mb.space_id = v_s2 AND mb.auth_user_id = test_fx.uid('x1');
  INSERT INTO public.households (space_id, display_name) VALUES (v_s2, '家庭Y') RETURNING id INTO v_hy;
  INSERT INTO public.members (space_id, household_id, auth_user_id, display_name) VALUES
    (v_s2, v_hx, test_fx.uid('um'), '二つの場の人'),
    (v_s2, v_hy, test_fx.uid('y1'), 'Yの人');

  -- 同意（全員）
  INSERT INTO public.consents (auth_user_id, consent_version)
  SELECT u.uid, public.current_rules_version() FROM test_fx.users u;

  PERFORM test_fx.put('S1', v_s1); PERFORM test_fx.put('S2', v_s2);
  PERFORM test_fx.put('H0', v_h0); PERFORM test_fx.put('HA', v_ha); PERFORM test_fx.put('HB', v_hb);
  PERFORM test_fx.put('HC', v_hc); PERFORM test_fx.put('HX', v_hx); PERFORM test_fx.put('HY', v_hy);
  -- メンバーの ID: m_<名前>。um だけは m_um_s1 / m_um_s2
  FOR r IN
    SELECT u.name, mb.id, mb.space_id FROM public.members mb JOIN test_fx.users u ON u.uid = mb.auth_user_id
  LOOP
    IF r.name = 'um' THEN
      PERFORM test_fx.put(CASE WHEN r.space_id = v_s1 THEN 'm_um_s1' ELSE 'm_um_s2' END, r.id);
    ELSE
      PERFORM test_fx.put('m_' || r.name, r.id);
    END IF;
  END LOOP;
  -- タグの ID: tag1_<名前>（S1）／tag2_<名前>（S2）
  FOR r IN SELECT tg.id, tg.name, tg.space_id FROM public.tags tg WHERE tg.space_id IN (v_s1, v_s2) LOOP
    PERFORM test_fx.put(CASE WHEN r.space_id = v_s1 THEN 'tag1_' ELSE 'tag2_' END || r.name, r.id);
  END LOOP;
END $$;

-- 見本データを全部消して作り直す（1つのファイルの中で、消すテストを何度もするため）
CREATE FUNCTION test_fx.reset() RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.spaces;          -- 家庭・メンバー・①②③・本・タグ・招待が CASCADE で消える
  DELETE FROM auth.users au WHERE au.id IN (SELECT u.uid FROM test_fx.users u);  -- 同意・試行も消える
  PERFORM test_fx.build();
END $$;

-- ------------------------------------------------------------
-- 状況を作る道具（持ち主の権限で入れる＝トリガーが家庭を上書きしない）
-- ------------------------------------------------------------
-- ①: 作った家庭 p_hh（'HA' など）
CREATE FUNCTION test_fx.mk_problem(p_key text, p_space text, p_name text, p_hh text) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v uuid;
BEGIN
  INSERT INTO public.problems (space_id, name, created_household_id)
  VALUES (test_fx.id(p_space), p_name, test_fx.id(p_hh)) RETURNING id INTO v;
  RETURN test_fx.put(p_key, v);
END $$;

-- ②: ①の下に。作った家庭 p_hh
CREATE FUNCTION test_fx.mk_measure(p_key text, p_problem text, p_name text, p_hh text) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v uuid;
BEGIN
  INSERT INTO public.measures (problem_id, name, created_household_id)
  VALUES (test_fx.id(p_problem), p_name, test_fx.id(p_hh)) RETURNING id INTO v;
  RETURN test_fx.put(p_key, v);
END $$;

-- ③: 書いた人 p_member（'a1' など。um は 'um_s1'／'um_s2'）。家庭はその人の家庭。
CREATE FUNCTION test_fx.mk_trial(
  p_key text, p_measure text, p_member text, p_score integer,
  p_visibility text DEFAULT 'all', p_age_months integer DEFAULT 36,
  p_tried_on date DEFAULT DATE '2026-09-01', p_source_type text DEFAULT 'own', p_book text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v uuid; v_member uuid := test_fx.id('m_' || p_member); v_hh uuid;
BEGIN
  SELECT mb.household_id INTO v_hh FROM public.members mb WHERE mb.id = v_member;
  INSERT INTO public.trials (measure_id, household_id, created_by_member_id, updated_by_member_id,
                             score, age_months, source_type, book_id, tried_on, visibility)
  VALUES (test_fx.id(p_measure), v_hh, v_member, v_member, p_score, p_age_months, p_source_type,
          CASE WHEN p_book IS NULL THEN NULL ELSE test_fx.id(p_book) END, p_tried_on, p_visibility)
  RETURNING id INTO v;
  RETURN test_fx.put(p_key, v);
END $$;

-- 本: 登録した人 p_member
CREATE FUNCTION test_fx.mk_book(p_key text, p_space text, p_title text, p_author text, p_member text) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v uuid;
BEGIN
  INSERT INTO public.books (space_id, title, author, created_by_member_id)
  VALUES (test_fx.id(p_space), p_title, p_author, test_fx.id('m_' || p_member)) RETURNING id INTO v;
  RETURN test_fx.put(p_key, v);
END $$;

-- updated_at を過去の日時にする（1つのトランザクションの中では now() が同じなので、並び順のテストに使う）。
-- トリガーが updated_at を now() で上書きするので、その間だけトリガーを止める（ROLLBACK で元に戻る）。
CREATE FUNCTION test_fx.set_updated_at(p_table text, p_key text, p_at timestamptz) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER USER', p_table);
  EXECUTE format('UPDATE public.%I SET updated_at = $1 WHERE id = $2', p_table) USING p_at, test_fx.id(p_key);
  EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER USER', p_table);
END $$;

-- save_trial を、使わない引数を省いて呼ぶための包み（呼んだ人の権限で動く＝RLS もそのまま）
CREATE FUNCTION test_fx.save_trial(
  p_space_id uuid DEFAULT NULL, p_problem_id uuid DEFAULT NULL, p_problem_name text DEFAULT NULL,
  p_tag_ids uuid[] DEFAULT NULL, p_measure_id uuid DEFAULT NULL, p_measure_name text DEFAULT NULL,
  p_score integer DEFAULT NULL, p_age_months integer DEFAULT 36, p_source_type text DEFAULT NULL,
  p_book_id uuid DEFAULT NULL, p_source_url text DEFAULT NULL, p_heard_from text DEFAULT NULL,
  p_note text DEFAULT NULL, p_tried_on date DEFAULT NULL, p_visibility text DEFAULT NULL
) RETURNS jsonb
LANGUAGE sql VOLATILE AS $$
  SELECT public.save_trial(p_space_id, p_problem_id, p_problem_name, p_tag_ids, p_measure_id, p_measure_name,
                           p_score::smallint, p_age_months::smallint, p_source_type, p_book_id, p_source_url,
                           p_heard_from, p_note, p_tried_on, p_visibility)
$$;

-- 今の立場で public の関数をすべて（引数は NULL で）呼び、権限エラー（42501）にならなかった関数の名前を返す（TG-2・TG-3）
CREATE FUNCTION test_fx.callable_functions(p_only text[] DEFAULT NULL) RETURNS text[]
LANGUAGE plpgsql VOLATILE AS $$
DECLARE
  r record; v_out text[] := '{}'; v_args text;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, p.pronargs, p.proargtypes
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
      AND (p_only IS NULL OR p.proname = ANY (p_only))
    ORDER BY p.proname
  LOOP
    SELECT coalesce(string_agg('NULL::' || format_type(t.typ, NULL), ', ' ORDER BY t.ord), '')
      INTO v_args
      FROM unnest(r.proargtypes::oid[]) WITH ORDINALITY AS t(typ, ord);
    BEGIN
      EXECUTE format('SELECT public.%I(%s)', r.proname, v_args);
      v_out := v_out || r.proname;
    EXCEPTION
      WHEN insufficient_privilege THEN NULL;         -- 期待どおりの権限エラー
      WHEN OTHERS THEN v_out := v_out || (r.proname || '(' || SQLERRM || ')');
    END;
  END LOOP;
  RETURN v_out;
END $$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_fx TO anon, authenticated, service_role;
GRANT SELECT ON test_fx.users TO anon, authenticated, service_role;

SELECT plan(1);
SELECT has_function('test_fx', 'build', 'テスト用の道具（test_fx）を入れた');
SELECT * FROM finish();
COMMIT;
