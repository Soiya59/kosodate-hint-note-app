-- ============================================================
-- 子育てヒントノート スキーマ案 v0.5（2026-09-30・設計部）
--
-- ■ 位置づけ
--   - 本番にはまだ適用しない。**v0.5 は、設計部がローカルの Supabase（Docker。一時の場所）に入れて、
--     開発部のテスト（427件）と v0.5 の新しいテストを流して確かめた**（2026-09-30。結果は [設計 14-3e]）。
--   - 正は 設計部/成果物/データと権限の設計書_v0.5（2026-09-30）.md。本ファイルの [設計 n] はその章。
--   - 要件は 企画部/成果物/子育てヒントノート_要件定義書_v0.8（2026-09-30）.md。[要件 x-y] はその節。
--   - v0.1〜v0.4（schema_v0.1〜v0.4）は書き換えずに残している。
--   - **開発部へ**: app 側の最初のマイグレーション（kosodate-hint-note-app の supabase/migrations/
--     20260930000000_initial_schema.sql＝いまは v0.4 と同じ中身）を、**このファイルで丸ごと差し替える**。
--     本番にはまだどこにも入れていないので、ALTER の積み重ね（差分のマイグレーション）は作らない。
--     **ローカルの DB のデータ（統括が触ったもの）を残したいときだけ**、[設計 14-4] の「v0.4 → v0.5 の移し替えの SQL」
--     を使う（マイグレーションにはしない）。v0.4 との差は [設計 15-8]（Y1〜Y7）、画面への影響は [設計 15-9]。
--   - v0.4 から変えた所には「-- [v0.5]」の印を付けた（Y1〜Y7）。要件 v0.8 14-5節の設計部の行 ①〜⑥:
--       Y1  tags.kind（タグの種類 'trouble'＝困りごと／'grow'＝育てたい／'both'＝両方）と tags.grow_sort_order
--           （育てたいの並び。困りごとの並び〈と［すべて］の並び〉は sort_order のまま）                     … ①
--       Y2  最初のタグを24個に（困りごと9・育てたい13・両方2〈ことば・その他〉。A17 確定 2026-09-30）。場を作る関数と、すでにある場の
--           移し替えは同じ関数 app_private.seed_default_tags で行う                                          … ①⑤
--       Y3  ①に付けられるのは①の種類と「両方」のタグだけ（problem_tags のトリガーで守る。違えば tag_kind_mismatch）… ①
--       Y4  ①の種類を変えたら、合わないタグをデータ置き場が外す（0個になれば「その他」＝v0.1 からのトリガー）   … ①
--       Y5  管理者がタグを足すとき種類を渡す（省略＝困りごと）。並び順はトリガーが種類ごとに決める                … ①
--       Y6  出典の種類に 'notebook'（このノートで知った）。7つ。詳細の欄なし                                    … ②
--       Y7  list_age_band_counts を消す（画面で使わなくなった＝要件 v0.8 C106。企画部の推し）                     … ③
--       Y8  export_visible_data の③に書いた人（メンバー ID・呼び名）（開発部の報告 7章の1。2026-09-30 追加）
--       （試したい → 試し中・試したの日付は X5 のまま＝本部長判断 2026-09-30 のとおりの動き。[設計 6章]）
--       R2〜R4 は v0.4 の作りのまま（④）。RLS のポリシー（31個）・見え方の規則・直す消すの判定・GRANT の表、
--       削除・退会の関数（delete_*_data）は変えていない。
--   - v0.3 から v0.4 で変えた所には「-- [v0.4]」の印がある（X1〜X12。[設計 15-6]）。X7 のうち list_age_band_counts は
--     v0.5 で消した。
--   - （記録）v0.4 の X1〜X12（要件 v0.7 14-4節の設計部の行 ①〜⑧）:
--       X1  problems.kind（①の種類 'trouble'＝困りごと／'grow'＝育てたい。既定 'trouble'）         … ①
--       X2  trials.status（③の状態 'scored'＝試した／'trying'＝試し中／'want'＝試したい）と点数の関係 … ②
--       X3  trials.age_months_to（年齢の「まで」。空＝1つの年齢。6の倍数・「から」より大きく・差は36か月まで） … ③
--       X4  出典の種類を6つに（'tv'＝テレビ・'other'＝その他）。詳細の文字 trials.source_text（40字）  … ④
--       X5  trials のトリガー: 状態を点数から決める（状態を送らない古い書き方も通る）／
--           「試したい」→「試し中」「試した」で日付を今日に／「まで」＝「から」なら空に                   … ②③
--       X6  search_problems: 種類での絞り込み p_kind・年齢の範囲の絞り込み p_age_years_to・出力 o_kind   … ①③
--       X7  list_age_counts: 範囲の③を「入る歳」すべてに数える。list_age_band_counts を新設（まとまり） … ③
--       X8  list_measures: 年齢の範囲の絞り込み・並び（試したいは試し中の後）・o_trials に状態・まで・
--           詳細の文字・書いた人の呼び名・家庭名                                                        … ②③④⑤
--       X9  suggest_problems に o_kind、suggest_measures の並びを list_measures とそろえる                 … ①②
--       X10 save_trial に p_problem_kind・p_status・p_age_months_to・p_source_text（どれも省略可）        … ①〜④
--       X11 set_problem_kind を新設（①の種類を変える。名前を直すのと同じ条件。true/false）              … ①
--       X12 export_visible_data に kind・status・age_months_to・source_text                                 … ①〜④
--       RLS のポリシー（31個）・見え方の規則（visible_*_ids）・直す消すの判定（can_*）・GRANT の表は変えていない（⑧）。
--       E-2 の同意した日の関数は足さない（⑥）。同意の版は第1版のまま（current_rules_version() は 1）。
--   - v0.2 から v0.3 で変えた所には「-- [v0.3]」の印がある（W1〜W5。[設計 15-4]）。
--       W1  save_trial: 新しい①②を「INSERT … RETURNING id」で作るのをやめ、ID を先に決めてから入れる
--           （開発部の修正1の取り込み。RETURNING があると、入れたばかりの①②が SELECT のポリシー
--           〈visible_problem_ids()／visible_measure_ids()〉を満たさず、必ず RLS の拒否になっていた）
--       W2  households_before_write: 画面から家庭を作るとき、上限を数える前に「その場の管理者か」を確かめる
--           （権限の無い人に limit_households ではなく 42501 を返す。開発部の報告 4-3節）
--       W3  list_my_spaces: 並びを「場の作成順」から「自分が参加した順（members.created_at）」に
--           （[要件 3-1] F-04「なければ参加が早いノートを開く」を、画面が先頭の行を取るだけで満たすため）
--       W4  RLS のポリシー・表・列・GRANT は変えていない。problems・measures のポリシーの所に、
--           「画面から INSERT … RETURNING（supabase-js の .insert().select()）をしない」注意を書いた（コメントだけ）
--       W5  自己確認（8章）に「RETURNING と見える一覧の関数」の点検を足した（コメントだけ）
--   - v0.1 から v0.2 で変えた所には「-- [v0.2]」の印がある。一覧は [設計 15-2]（V1〜V12）。
--       V1  list_my_spaces に、その場の管理者のメンバー ID と表示名を足した（断りの文「管理者（◯◯さん）」用）
--       V2  list_measures: 年齢で絞り込み中は、行の中の③を「その歳の③ → ほかの歳の③」の順にし、
--           各③に in_age（その歳の③か）を付けた（太字用。[要件 6-2]・C47）
--       V3  suggest_measures: 空の文字（打つ前）でも、対策の一覧と同じ並びで最大5件を返す（C48）
--       V4  delete_member_data: ③を消すかの引数を省略したときの既定を「本人の退会＝消す／管理者が外す＝残す」に（C41）
--       V5  delete_book を新設（本を消せたかを true/false だけで返す。[要件 2-5]・C44）
--       V6  画面から書き換えられる表のトリガーで、id（行の番号）の書き換えも止める（家庭の表示名の変更＝C48 の点検で気づいた）
--   - 前提（2026-09-29・統括。本部長から）:
--       * 最初は4家庭（U-27 決着）。ただし表・関数・RLS は家庭の数に依存しない。
--         上限は場ごとの設定値 spaces.max_households（既定5）・spaces.max_members（既定10）。
--         **2026-09-30・統括決定 A3: 兄弟の家庭の大人だけ・上限10人のまま**（既定値は変えない。
--         「大人だけ」は表では区別できないので、管理者が招待するときに守る運用）。
--   - 2026-09-30・統括決定（A1・A2・A7。[設計 9・10]）: ログインはメールの6桁の番号（パスワードなし）／
--     Supabase は無料プラン・東京・おやこポイントと同じ管理アカウントの別プロジェクト／
--     ログインのメールは Resend・mail.soiyalab.com から差出人名「子育てヒントノート」。
--     いずれも Supabase の管理画面の設定で、この SQL には現れない。
--       * 最終的にはスマホアプリ化し、ストアで一般公開する。最初は身内4家庭だけの Web 版。
--         → **場（ノート）を最初から複数持てる作り**にする。すべての表に space_id を持たせ、RLS で場ごとに区切る。
--           1人が複数の場に入れる（members は「場×ログイン」で1行）。
--         → 「管理者」は**その場の管理者**（場ごとに1人）。統括という特定の人を仕組みに埋め込まない。
--         → Web 専用の前提（ブラウザの保存領域・リンクで戻る認証・URL の形）を DB に持ち込まない。
--
-- ■ 書き方の決まり（PL/pgSQL の列名衝突を作らないため。設計部/CLAUDE.md）
--   1. 関数の引数は p_、PL/pgSQL の変数は v_、RETURNS TABLE の出力列は o_ で始める。
--      表の列名に p_ / v_ / o_ で始まるものは1つも無い（[設計 14-3] の一覧で確認済み）。
--   2. 関数本文で表を参照するときは必ず別名を付け、列は「別名.列名」で書く。
--   3. ON CONFLICT を使う関数（record_rules_consent）には #variable_conflict use_column を置く。
--   4. 関数は search_path = '' で作り、表・関数はすべてスキーマ名つきで書く。
--
-- ■ 権限の考え方（[設計 3]）
--   - 画面のコードは公開リポジトリに置くので、**RLS が唯一の守り**。すべての表で RLS を有効にする。
--   - 読み書きの可否はすべて RLS のポリシーで決める。画面から呼ぶ関数（RPC）は原則
--     SECURITY INVOKER（呼んだ人の権限で動く＝RLS がそのまま効く）。
--   - SECURITY DEFINER（関数の持ち主の権限で動く）は、次の3種類だけ:
--       (a) RLS の判定に使う小さな関数（app_private スキーマ。画面から直接は呼べない）
--       (b) 招待コードでの参加・同意の記録・家庭削除の件数確認（まだ見る権限が無い人／追記専用の表）
--       (c) 退会・家庭の削除・場の削除・場の作成（service_role だけが呼べる）
--   - 新しい表には GRANT SELECT, INSERT, UPDATE, DELETE ... TO authenticated, service_role を書き、
--     anon には付けない（開発部/CLAUDE.md）。念のため anon からは明示的に REVOKE する。
--     GRANT があっても、ポリシーが無い操作は RLS で拒否される（例: spaces への INSERT）。
-- ============================================================


-- ============================================================
-- 0. スキーマと拡張
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;  -- digest / gen_random_bytes（招待コード）

-- RLS の判定に使う関数と、トリガーの関数を置く場所。
-- Supabase の Data API（PostgREST）に公開するのは public だけなので、ここの関数は画面から直接呼べない。
CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC;
GRANT USAGE ON SCHEMA app_private TO authenticated, service_role;


-- ============================================================
-- 1. 表（[設計 2]。列・型・上限は [要件 第4章]）
-- ============================================================

-- ------------------------------------------------------------
-- 1-1. spaces（場＝1冊のノート。[要件 4-6]）
--   上限は場ごとの設定値。画面・処理はこの値だけを見て、家庭の数を決め打ちしない。
--   変えるのは運営者（SQL エディタ＝service_role）。画面からは変えられない（UPDATE のポリシーを作らない）。
-- ------------------------------------------------------------
CREATE TABLE public.spaces (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name             text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 20 AND name !~ '[\r\n]'),
  max_households   smallint NOT NULL DEFAULT 5  CHECK (max_households BETWEEN 1 AND 20),
  max_members      smallint NOT NULL DEFAULT 10 CHECK (max_members BETWEEN 1 AND 50),
  invite_ttl_days  smallint NOT NULL DEFAULT 7  CHECK (invite_ttl_days BETWEEN 1 AND 30),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.spaces TO authenticated, service_role;
REVOKE ALL ON public.spaces FROM anon;
ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-2. households（家庭。場の中の世帯。[要件 4-6]）
-- ------------------------------------------------------------
CREATE TABLE public.households (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id      uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  display_name  text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 20 AND display_name !~ '[\r\n]'),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_households_space_name UNIQUE (space_id, display_name)  -- 画面で家庭名が区別できるように（[設計 16] Q11）
);
CREATE INDEX idx_households_space_id ON public.households(space_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.households TO authenticated, service_role;
REVOKE ALL ON public.households FROM anon;
ALTER TABLE public.households ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-3. members（メンバー＝「ある場の、ある家庭に入っている、あるログイン」。[要件 4-6]）
--   - 1人（1ログイン）が複数の場に入れる。1つの場の中では1つの家庭だけ（uq_members_space_user）。
--   - メールアドレスはここに持たない（Supabase Auth の auth.users だけが持つ。[設計 13]）。
--   - 「有効／退会」の列は持たない。退会したら行ごと消す（[設計 7-2]・[設計 15] Z1）。
--   - 管理者は場ごとに1人（部分ユニーク索引）。
-- ------------------------------------------------------------
CREATE TABLE public.members (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id      uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  household_id  uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  auth_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 20 AND display_name !~ '[\r\n]'),
  role          text NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_members_space_user UNIQUE (space_id, auth_user_id)
);
CREATE UNIQUE INDEX uq_members_one_admin_per_space ON public.members(space_id) WHERE role = 'admin';
CREATE INDEX idx_members_auth_user_id ON public.members(auth_user_id);
CREATE INDEX idx_members_household_id ON public.members(household_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.members TO authenticated, service_role;
REVOKE ALL ON public.members FROM anon;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-4. consents（「書き方の約束」への同意。[要件 4-6・7-2 ①]）
--   約束はアプリ全体で1つなので、場ごとではなく**ログインごと**に持つ。
--   追記専用。書くのは record_rules_consent() だけ（INSERT/UPDATE/DELETE のポリシーを作らない）。
--   おやこポイントの terms_consents（20260918010000_terms_consent.sql）と同じ流儀。
--   違い: ログイン（auth.users）を消したら一緒に消える（ON DELETE CASCADE）。
-- ------------------------------------------------------------
CREATE TABLE public.consents (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_version  integer NOT NULL CHECK (consent_version >= 1),
  consented_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_consents_user_version UNIQUE (auth_user_id, consent_version)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.consents TO authenticated, service_role;
REVOKE ALL ON public.consents FROM anon;
ALTER TABLE public.consents ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-5. invites（招待コード。[要件 2-1]・[設計 8-1]）
--   コードそのものは保存しない（SHA-256 の値だけ）。発行したときに1回だけ画面に出す。
--   URL ではなくコードなので、Web でもアプリでも同じ（[設計 17]）。
-- ------------------------------------------------------------
CREATE TABLE public.invites (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id              uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  household_id          uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  code_hash             text NOT NULL UNIQUE CHECK (code_hash ~ '^[0-9a-f]{64}$'),
  created_by_member_id  uuid NULL REFERENCES public.members(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  expires_at            timestamptz NOT NULL,
  used_at               timestamptz NULL,
  used_by_member_id     uuid NULL REFERENCES public.members(id) ON DELETE SET NULL,
  revoked_at            timestamptz NULL
);
CREATE INDEX idx_invites_space_id ON public.invites(space_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invites TO authenticated, service_role;
REVOKE ALL ON public.invites FROM anon;
ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-6. invite_attempts（招待コードの入力の記録。総当たり防止。[設計 8-1]）
--   ポリシーを1つも作らない＝画面からは読めも書けもしない。書くのは join_with_invite_code() だけ。
-- ------------------------------------------------------------
CREATE TABLE public.invite_attempts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attempted_at  timestamptz NOT NULL DEFAULT now(),
  succeeded     boolean NOT NULL
);
CREATE INDEX idx_invite_attempts_user_time ON public.invite_attempts(auth_user_id, attempted_at);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invite_attempts TO authenticated, service_role;
REVOKE ALL ON public.invite_attempts FROM anon;
ALTER TABLE public.invite_attempts ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-7. tags（タグ。**場ごと**に持つ。[要件 4-5]・[設計 2-3]）
--   場を作るときに最初のタグ（v0.5 で24個。app_private.seed_default_tags）をその場に入れる。「その他」は is_other = true（場に1つ）。
--   並び順は「その他」を常に最後にするため 1000 固定、追加したタグは「その他」以外の最大＋1（トリガー）。
--   名前の変更・削除は次フェーズ（N-20）。
-- ------------------------------------------------------------
-- [v0.5] Y1（[要件 4-5]・C104）: タグの種類 kind（'trouble'＝困りごと／'grow'＝育てたい／'both'＝両方）。
--   並びは2つ持つ: sort_order＝困りごとの並びと［すべて］の並び（困りごと・両方 1〜99 → 育てたいだけ 101〜 → その他 1000）、
--   grow_sort_order＝育てたいの並び（育てたい・両方だけが持つ。その他 1000）。「ことば」（両方）は困りごとでは
--   5番目、育てたいでは7番目に出る（[要件 4-5] の2つの並びを1つの数では表せないため列を分けた）。
--   種類はあとから変えない（タグの UPDATE のポリシーが無い＝名前の変更・削除と一緒に次フェーズ N-20）。
CREATE TABLE public.tags (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id        uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  name            text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 10 AND name !~ '[\r\n]'),
  kind            text NOT NULL DEFAULT 'trouble' CHECK (kind IN ('trouble', 'grow', 'both')),   -- [v0.5] Y1
  sort_order      integer NOT NULL,
  grow_sort_order integer NULL,                                                                  -- [v0.5] Y1
  is_other        boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_tags_space_name UNIQUE (space_id, name),
  CONSTRAINT chk_tags_grow_sort CHECK ((kind = 'trouble') = (grow_sort_order IS NULL)),          -- [v0.5] Y1
  CONSTRAINT chk_tags_other_both CHECK (NOT is_other OR kind = 'both')                           -- [v0.5] Y1「その他」は両方
);
CREATE UNIQUE INDEX uq_tags_one_other_per_space ON public.tags(space_id) WHERE is_other;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tags TO authenticated, service_role;
REVOKE ALL ON public.tags FROM anon;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-8. problems（①困りごと。[要件 4-1]）
--   - 名前は30字・改行なし・前後の空白を取る（トリガー）。**重複を許す**（ユニーク制約を置かない。[要件 2-4]）。
--   - created_household_id は「持ち主」ではなく、名前を直せる条件（K-4）と見え方（2-4節）に使う。
--     家庭が消えたら空（「退会した家庭」）。
--   - 公開範囲の列は持たない（公開範囲は③だけ。K-1）。
-- ------------------------------------------------------------
CREATE TABLE public.problems (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id              uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  name                  text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 30 AND name !~ '[\r\n]'),
  -- [v0.4] X1: ①の種類（[要件 4-1]・C89）。'trouble'＝困りごと／'grow'＝育てたい。既定は困りごと。
  --   直すのは「名前を直す」と同じ条件（problems_update_editable＝can_edit_problem。関数 set_problem_kind）。
  --   同じ名前が別の種類にあってもよい（一意の制約を置かない）。
  kind                  text NOT NULL DEFAULT 'trouble' CHECK (kind IN ('trouble', 'grow')),
  created_household_id  uuid NULL REFERENCES public.households(id) ON DELETE SET NULL,
  created_by_member_id  uuid NULL REFERENCES public.members(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_problems_space_id ON public.problems(space_id);
CREATE INDEX idx_problems_created_household_id ON public.problems(created_household_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.problems TO authenticated, service_role;
REVOKE ALL ON public.problems FROM anon;
ALTER TABLE public.problems ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-9. problem_tags（①とタグ。多対多。[要件 4-5]）
--   どの①にも必ず1つ以上のタグが付く（0個になったら「その他」を付けるトリガー。K-5）。
-- ------------------------------------------------------------
CREATE TABLE public.problem_tags (
  problem_id  uuid NOT NULL REFERENCES public.problems(id) ON DELETE CASCADE,
  tag_id      uuid NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  PRIMARY KEY (problem_id, tag_id)
);
CREATE INDEX idx_problem_tags_tag_id ON public.problem_tags(tag_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.problem_tags TO authenticated, service_role;
REVOKE ALL ON public.problem_tags FROM anon;
ALTER TABLE public.problem_tags ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-10. measures（②対策。[要件 4-2]）
--   - 名前は40字・改行なし。同じ①の中でも重複を許す。場は①から取る（トリガー）。
--   - problem_id は MVP では変えられない（付け替えは N-15）。①を消すと、③が0件の②も一緒に消える（CASCADE）。
--     ③が付いた②は trials.measure_id の外部キー（NO ACTION）で消せない＝二重の守り。
-- ------------------------------------------------------------
CREATE TABLE public.measures (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id              uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  problem_id            uuid NOT NULL REFERENCES public.problems(id) ON DELETE CASCADE,
  name                  text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 40 AND name !~ '[\r\n]'),
  created_household_id  uuid NULL REFERENCES public.households(id) ON DELETE SET NULL,
  created_by_member_id  uuid NULL REFERENCES public.members(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_measures_problem_id ON public.measures(problem_id);
CREATE INDEX idx_measures_space_id ON public.measures(space_id);
CREATE INDEX idx_measures_created_household_id ON public.measures(created_household_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.measures TO authenticated, service_role;
REVOKE ALL ON public.measures FROM anon;
ALTER TABLE public.measures ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-11. books（本。場ごとの共有の一覧。[要件 4-4]）
--   同じ本＝同じ場の中で題名と著者が完全に一致（U-22 仮置き）。著者なしは空文字と同じに扱ってユニークにする。
-- ------------------------------------------------------------
CREATE TABLE public.books (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id              uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  title                 text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100 AND title !~ '[\r\n]'),
  author                text NULL CHECK (author IS NULL OR (char_length(author) BETWEEN 1 AND 60 AND author !~ '[\r\n]')),
  created_by_member_id  uuid NULL REFERENCES public.members(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_books_space_title_author ON public.books(space_id, title, coalesce(author, ''));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.books TO authenticated, service_role;
REVOKE ALL ON public.books FROM anon;
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 1-12. trials（③試した結果。[要件 4-3]）
--   - score: 1〜5、NULL＝「試し中」。
--   - age_months: 月齢（0〜216）。入力は半年刻みなので 6 の倍数だけ（[設計 4]。N-13 で細かくするときに外す）。
--   - source_type: 'book'（本）／'web'（Web・記事）／'heard'（人から聞いた）／'own'（うちで考えた。既定）。
--     詳細の列は、その種類のときだけ入れられる（chk_trials_source_detail）。
--   - heard_from: 候補の言葉（保育士など。U-31）か自由記述、どちらも20字までの1列（[設計 15] Z4）。
--   - visibility: 'all'（みんな＝その場の全員。既定）／'household'（自分の家庭だけ）。
--   - 「どの子の③か」の列は持たない（[要件 4-3]・[設計 13]）。
--   - measure_id・book_id の外部キーは NO ACTION（③が付いた②・本は消せない。場の削除のように
--     同じ文の中で③も消える場合だけ通る）。
-- ------------------------------------------------------------
CREATE TABLE public.trials (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id              uuid NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  measure_id            uuid NOT NULL REFERENCES public.measures(id),
  household_id          uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by_member_id  uuid NULL REFERENCES public.members(id) ON DELETE SET NULL,
  updated_by_member_id  uuid NULL REFERENCES public.members(id) ON DELETE SET NULL,
  -- [v0.4] X2: ③の状態（[要件 4-3・4-3b]・C88）。'scored'＝試した（点数あり）／'trying'＝試し中／'want'＝試したい。
  --   点数は「試した」のときだけ 1〜5、ほかは空（chk_trials_status_score）。v0.3 までの「点数が空＝試し中」を列で持つ。
  --   状態を送らずに書いたとき（v0.3 の書き方）は、トリガーが点数から決める（点数あり＝scored／空＝trying）。
  --   既定値は置かない（既定値があると「送らなかった」と区別できない。送らなければトリガーが決め、NOT NULL は
  --   BEFORE のトリガーの後に確かめられる）。
  status                text NOT NULL CHECK (status IN ('scored', 'trying', 'want')),
  score                 smallint NULL CHECK (score BETWEEN 1 AND 5),
  -- age_months は「年齢（から）」（[要件 4-3]・5-4節。v0.3 までの「試したときの年齢」と同じ列。名前は変えない）
  age_months            smallint NOT NULL CHECK (age_months BETWEEN 0 AND 216 AND age_months % 6 = 0),
  -- [v0.4] X3: 年齢（まで）。空＝1つの年齢。6の倍数・0〜216・「から」より大きく・差は36か月（3年）まで（[要件 5-4]・C90・U-50）。
  --   「まで」＝「から」で送られたら、トリガーが空にする（1つの年齢の持ち方を1通りにする）。
  age_months_to         smallint NULL CHECK (age_months_to IS NULL OR (age_months_to BETWEEN 0 AND 216 AND age_months_to % 6 = 0)),
  -- [v0.4] X4: 出典の種類は6つ（[要件 4-3]・C86）。'tv'＝テレビ・'other'＝その他を足した。並びは画面の定数。
  -- [v0.5] Y6: 'notebook'＝このノートで知った（[要件 4-3]・C105）。詳細の欄は無い（source_text は tv・other だけのまま）。
  --   ［うちでも試した］から書くときに 'notebook' を選んだ状態にするのは画面（既定値はデータ置き場では 'own' のまま）。
  source_type           text NOT NULL DEFAULT 'own' CHECK (source_type IN ('book', 'web', 'tv', 'heard', 'notebook', 'own', 'other')),
  book_id               uuid NULL REFERENCES public.books(id),
  source_url            text NULL CHECK (source_url IS NULL OR (source_url ~ '^https://' AND char_length(source_url) <= 500 AND source_url !~ '[[:space:]]')),
  heard_from            text NULL CHECK (heard_from IS NULL OR (char_length(heard_from) BETWEEN 1 AND 20 AND heard_from !~ '[\r\n]')),
  -- [v0.4] X4: テレビ（番組名など）・その他（何で知ったか）の詳細。40字・改行なし。検索の対象外（[要件 4-3]）。
  source_text           text NULL CHECK (source_text IS NULL OR (char_length(source_text) BETWEEN 1 AND 40 AND source_text !~ '[\r\n]')),
  note                  text NULL CHECK (note IS NULL OR char_length(note) BETWEEN 1 AND 200),
  tried_on              date NOT NULL DEFAULT ((now() AT TIME ZONE 'Asia/Tokyo')::date),
  visibility            text NOT NULL DEFAULT 'all' CHECK (visibility IN ('all', 'household')),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_trials_source_detail CHECK (
        (source_type = 'book'  OR book_id    IS NULL)
    AND (source_type = 'web'   OR source_url IS NULL)
    AND (source_type = 'heard' OR heard_from IS NULL)
    AND (source_type IN ('tv', 'other') OR source_text IS NULL)   -- [v0.4] X4
  ),
  -- [v0.4] X2: 点数があるのは「試した」のときだけ
  CONSTRAINT chk_trials_status_score CHECK ((status = 'scored') = (score IS NOT NULL)),
  -- [v0.4] X3: 「まで」は「から」より大きく、差は36か月まで
  CONSTRAINT chk_trials_age_range CHECK (
    age_months_to IS NULL OR (age_months_to > age_months AND age_months_to - age_months <= 36)
  )
);
CREATE INDEX idx_trials_measure_id ON public.trials(measure_id);
CREATE INDEX idx_trials_household_id ON public.trials(household_id);
CREATE INDEX idx_trials_book_id ON public.trials(book_id) WHERE book_id IS NOT NULL;
CREATE INDEX idx_trials_space_visibility ON public.trials(space_id, visibility);
CREATE INDEX idx_trials_created_by ON public.trials(created_by_member_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.trials TO authenticated, service_role;
REVOKE ALL ON public.trials FROM anon;
ALTER TABLE public.trials ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- 2. 小さな共通関数（app_private。[設計 3-1]）
--   SQL 言語の関数は作るときに本文を検査するので、表の後に置く。
-- ============================================================

-- 前後の空白（全角の空白を含む）を取る。途中の改行は残す（③の一言は改行可）。
CREATE OR REPLACE FUNCTION app_private.trim_text(p_text text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT regexp_replace(p_text, '^[[:space:]　]+|[[:space:]　]+$', '', 'g')
$$;

-- 検索・候補表示のための正規化（[要件 6-1]・[設計 5-4]）。
-- NFKC で全角英数字→半角、半角カナ→全角カナにそろえ、小文字にする。ひらがなとカタカナは別のまま（U-36）。
CREATE OR REPLACE FUNCTION app_private.norm(p_text text)
RETURNS text LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT lower(normalize(coalesce(p_text, ''), NFKC))
$$;

-- [v0.4] X6〜X8: ③の年齢（から p_from・まで p_to〈空＝1つ〉。月齢）が、歳の範囲 p_y1〜p_y2（p_y2 が空なら p_y1 だけ）に
--   入るか（[要件 5-4]「から」の歳〜「まで」の歳〈月齢÷12 の切り捨て〉のどれかが範囲に入れば入る）。
--   例: 18〜30（1歳半〜2歳半）は 1歳・2歳に入る。24〜36（2〜3歳）は 0〜2歳・3〜5歳の両方に入る。
CREATE OR REPLACE FUNCTION app_private.age_overlaps(p_from smallint, p_to smallint, p_y1 integer, p_y2 integer)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT p_y1 IS NOT NULL
     AND (p_from / 12) <= coalesce(p_y2, p_y1)
     AND (coalesce(p_to, p_from) / 12) >= p_y1
$$;

-- 日本時間の今日。
CREATE OR REPLACE FUNCTION app_private.today_jst()
RETURNS date LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT (now() AT TIME ZONE 'Asia/Tokyo')::date
$$;

-- 「書き方の約束」の現行の版。文言を改訂したら、この値と画面側の定数を同じ配信で1つ進める。
CREATE OR REPLACE FUNCTION public.current_rules_version()
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT 1
$$;

-- ------------------------------------------------------------
-- 2-1. ログイン中の人が入っている場・家庭・メンバー（1人が複数の場に入れる）
--   members の RLS もこれらを使うので、SECURITY DEFINER で members を直接読む（RLS の再帰を避ける）。
--   ポリシーでは「x IN (SELECT app_private.my_…())」の形で使い、1回の問い合わせで1回だけ計算させる。
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_private.my_space_ids()
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT mb.space_id FROM public.members mb WHERE mb.auth_user_id = (SELECT auth.uid())
$$;

CREATE OR REPLACE FUNCTION app_private.my_household_ids()
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT mb.household_id FROM public.members mb WHERE mb.auth_user_id = (SELECT auth.uid())
$$;

CREATE OR REPLACE FUNCTION app_private.my_member_ids()
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT mb.id FROM public.members mb WHERE mb.auth_user_id = (SELECT auth.uid())
$$;

CREATE OR REPLACE FUNCTION app_private.admin_space_ids()
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT mb.space_id FROM public.members mb WHERE mb.auth_user_id = (SELECT auth.uid()) AND mb.role = 'admin'
$$;

-- ある場の中での、自分の家庭・自分のメンバー ID（その場のメンバーでなければ NULL）
CREATE OR REPLACE FUNCTION app_private.my_household_in(p_space_id uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT mb.household_id FROM public.members mb
  WHERE mb.auth_user_id = (SELECT auth.uid()) AND mb.space_id = p_space_id
$$;

CREATE OR REPLACE FUNCTION app_private.my_member_in(p_space_id uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT mb.id FROM public.members mb
  WHERE mb.auth_user_id = (SELECT auth.uid()) AND mb.space_id = p_space_id
$$;

-- その場の管理者か（管理者は場ごと。統括という特定の人を埋め込まない）
CREATE OR REPLACE FUNCTION app_private.is_admin_of(p_space_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.members mb
    WHERE mb.auth_user_id = (SELECT auth.uid()) AND mb.space_id = p_space_id AND mb.role = 'admin'
  )
$$;

CREATE OR REPLACE FUNCTION app_private.i_consented()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.consents cs
    WHERE cs.auth_user_id = (SELECT auth.uid())
      AND cs.consent_version = public.current_rules_version()
  )
$$;

-- 書く人の条件（その場のメンバーであること・現行の約束に同意していること）。
-- 消すことには求めない（同意していなくても、自分のものを消す権利は止めない）。
CREATE OR REPLACE FUNCTION app_private.require_writer(p_space_id uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF p_space_id IS NULL OR app_private.my_member_in(p_space_id) IS NULL THEN
    RAISE EXCEPTION 'not_member' USING ERRCODE = '42501';
  END IF;
  IF NOT app_private.i_consented() THEN
    RAISE EXCEPTION 'consent_required' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

-- ------------------------------------------------------------
-- 2-2. 見える②・見える①の集合（[要件 2-4] の規則そのもの。[設計 3-3]）
--   自分が入っている場ごとに、その場での自分の家庭 F で判定する（場をまたいで混ざらない）。
--   ポリシーでは「id IN (SELECT app_private.visible_…())」の形で使う。相関の無い副問い合わせなので、
--   1回の問い合わせにつき1回だけ計算され（ハッシュ化された副計画）、行ごとに③をたどらない（[要件 9-3] の注意）。
--   SECURITY DEFINER なので、中では RLS を通さずに「見えない③も含めて」数えたうえで、規則どおりに絞る。
-- ------------------------------------------------------------
-- ② が M（家庭 F）に見える: (a) ②を作った家庭が F  (b) ②の下に M に見える③（みんな、または F の③）がある
CREATE OR REPLACE FUNCTION app_private.visible_measure_ids()
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH my AS (
    SELECT mb.space_id AS sp, mb.household_id AS hh
    FROM public.members mb
    WHERE mb.auth_user_id = (SELECT auth.uid())
  )
  SELECT me.id
  FROM public.measures me
  JOIN my ON my.sp = me.space_id
  WHERE me.created_household_id = my.hh
     OR EXISTS (
          SELECT 1 FROM public.trials tr
          WHERE tr.measure_id = me.id
            AND (tr.visibility = 'all' OR tr.household_id = my.hh)
        )
$$;

-- ① が M に見える: (a) ①を作った家庭が F  (b) ①の下に M に見える②がある
CREATE OR REPLACE FUNCTION app_private.visible_problem_ids()
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH my AS (
    SELECT mb.space_id AS sp, mb.household_id AS hh
    FROM public.members mb
    WHERE mb.auth_user_id = (SELECT auth.uid())
  ),
  vm AS (
    SELECT vmi.mid FROM app_private.visible_measure_ids() AS vmi(mid)
  )
  SELECT pr.id
  FROM public.problems pr
  JOIN my ON my.sp = pr.space_id
  WHERE pr.created_household_id = my.hh
     OR EXISTS (
          SELECT 1 FROM public.measures me
          JOIN vm ON vm.mid = me.id
          WHERE me.problem_id = pr.id
        )
$$;

-- ------------------------------------------------------------
-- 2-3. 直す・消すの判定（[要件 2-3]・2-5 案A。[設計 3-4]）
--   **見えない③も数える**。返すのは true/false だけ（理由・件数・家庭を返さない）。
--   ポリシーの USING / WITH CHECK から1行につき1回呼ばれる。
-- ------------------------------------------------------------
-- ①の名前・タグを直せるか: 見える①で、(その場の管理者) または (自家庭が作り、他家庭の③〈非公開を含む〉が1件も無い)
CREATE OR REPLACE FUNCTION app_private.can_edit_problem(p_problem_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.problems pr
    WHERE pr.id = p_problem_id
      AND pr.id IN (SELECT vpi.pid FROM app_private.visible_problem_ids() AS vpi(pid))
      AND (
        app_private.is_admin_of(pr.space_id)
        OR (
          pr.created_household_id = app_private.my_household_in(pr.space_id)
          AND NOT EXISTS (
            SELECT 1 FROM public.measures me
            JOIN public.trials tr ON tr.measure_id = me.id
            WHERE me.problem_id = pr.id
              AND tr.household_id <> pr.created_household_id
          )
        )
      )
  )
$$;

-- ①を消せるか: 見える①で、(その場の管理者 または 自家庭が作った) かつ ③が1件も無い（非公開も数える）
CREATE OR REPLACE FUNCTION app_private.can_delete_problem(p_problem_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.problems pr
    WHERE pr.id = p_problem_id
      AND pr.id IN (SELECT vpi.pid FROM app_private.visible_problem_ids() AS vpi(pid))
      AND (
        app_private.is_admin_of(pr.space_id)
        OR pr.created_household_id = app_private.my_household_in(pr.space_id)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.measures me
        JOIN public.trials tr ON tr.measure_id = me.id
        WHERE me.problem_id = pr.id
      )
  )
$$;

-- ②の名前を直せるか（①と同じ考え方。②に付いた③だけを数える）
CREATE OR REPLACE FUNCTION app_private.can_edit_measure(p_measure_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.measures me
    WHERE me.id = p_measure_id
      AND me.id IN (SELECT vmi.mid FROM app_private.visible_measure_ids() AS vmi(mid))
      AND (
        app_private.is_admin_of(me.space_id)
        OR (
          me.created_household_id = app_private.my_household_in(me.space_id)
          AND NOT EXISTS (
            SELECT 1 FROM public.trials tr
            WHERE tr.measure_id = me.id
              AND tr.household_id <> me.created_household_id
          )
        )
      )
  )
$$;

-- ②を消せるか
CREATE OR REPLACE FUNCTION app_private.can_delete_measure(p_measure_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.measures me
    WHERE me.id = p_measure_id
      AND me.id IN (SELECT vmi.mid FROM app_private.visible_measure_ids() AS vmi(mid))
      AND (
        app_private.is_admin_of(me.space_id)
        OR me.created_household_id = app_private.my_household_in(me.space_id)
      )
      AND NOT EXISTS (SELECT 1 FROM public.trials tr WHERE tr.measure_id = me.id)
  )
$$;

-- 本を消せるか: (その場の管理者 または 自分が登録) かつ 使っている③が0件（非公開の③も数える。[設計 15] Z8）
CREATE OR REPLACE FUNCTION app_private.can_delete_book(p_book_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.books bk
    WHERE bk.id = p_book_id
      AND (
        app_private.is_admin_of(bk.space_id)
        OR (bk.created_by_member_id IS NOT NULL AND bk.created_by_member_id = app_private.my_member_in(bk.space_id))
      )
      AND NOT EXISTS (SELECT 1 FROM public.trials tr WHERE tr.book_id = bk.id)
  )
$$;

-- ------------------------------------------------------------
-- 2-4. 招待コード（[設計 8-1]）
--   紛らわしい文字（0/O・1/I）を除いた32文字から8文字。暗号用の乱数を使う（256 は 32 で割り切れるので偏りなし）。
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_private.new_invite_code()
RETURNS text LANGUAGE plpgsql VOLATILE SET search_path = '' AS $$
DECLARE
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea := extensions.gen_random_bytes(8);
  v_out   text := '';
  v_i     integer;
BEGIN
  FOR v_i IN 0..7 LOOP
    v_out := v_out || substr(v_chars, (get_byte(v_bytes, v_i) % 32) + 1, 1);
  END LOOP;
  RETURN v_out;
END;
$$;

-- 入力のゆれ（全角・小文字・空白・ハイフン）をそろえてから SHA-256 にする。
CREATE OR REPLACE FUNCTION app_private.hash_invite_code(p_code text)
RETURNS text LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT encode(
    extensions.digest(upper(regexp_replace(normalize(coalesce(p_code, ''), NFKC), '[[:space:]-]', '', 'g')), 'sha256'),
    'hex'
  )
$$;


-- ============================================================
-- 3. トリガー（[設計 3-5]）
--   画面から来た書き込み（current_user = 'authenticated'）は、家庭・書いた人・場を**サーバー側で決める**
--   （画面が送った値を信用しない）。service_role・関数の持ち主（postgres）からの書き込みは、そのまま通す。
--   トリガーの関数は SECURITY INVOKER（呼んだ人の権限。current_user で画面からかを判定するため）。
--   例外: 「その他」を自動で付ける2つは SECURITY DEFINER（RLS を通さずに1行足すだけ）。
--   画面から①・本・タグ・家庭を作るときは space_id を送る（どの場に作るか）。その場のメンバーでなければ拒否。
-- ============================================================

-- 3-1. spaces
CREATE OR REPLACE FUNCTION app_private.spaces_before_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.name := app_private.trim_text(NEW.name);
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_spaces_before_update
  BEFORE UPDATE ON public.spaces
  FOR EACH ROW EXECUTE FUNCTION app_private.spaces_before_update();

-- 3-2. households（家庭の数の上限。家庭の数を決め打ちせず spaces.max_households を見る）
CREATE OR REPLACE FUNCTION app_private.households_before_write()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_max   integer;
  v_count integer;
BEGIN
  -- [v0.2] 家庭の表示名の変更（その場の管理者だけ。RLS の households_update_admin。[要件 2-3]・C48）は
  --        表を直接 UPDATE する。変えられるのは display_name だけ（下の ELSE で他の列を止める）。
  --        同じ場に同じ表示名があると uq_households_space_name で 23505（画面は「同じ名前の家庭があります」）。
  NEW.display_name := app_private.trim_text(NEW.display_name);
  IF TG_OP = 'INSERT' THEN
    -- [v0.3] W2: 画面からのときは、上限を数える前に「その場の管理者か」を確かめる。
    --   BEFORE のトリガーは RLS の WITH CHECK（households_insert_admin）より先に動くので、v0.2 では
    --   メンバーが作ろうとしたとき・別の場（入っていない場）に作ろうとしたときに、42501 より先に
    --   limit_households が返っていた（拒否はされていた。開発部の報告 4-3節・TM-3・TS-8）。
    --   ここで 42501 にそろえる。別の場・存在しない場は、どちらも同じ 42501（場の有無・上限は漏れない）。
    --   RLS の households_insert_admin はそのまま残す（守りは二重になる）。
    IF current_user = 'authenticated' AND NOT app_private.is_admin_of(NEW.space_id) THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
    END IF;
    -- 注意: ここは画面（管理者）からも通るので FOR UPDATE を付けない。spaces には UPDATE のポリシーが無く、
    -- RLS の下で FOR UPDATE を付けると行が返らず v_max が NULL になる（＝必ず limit_households で失敗する）。
    -- 家庭を作るのは場の管理者1人だけなので、同時に2つ作って上限を1つ超える競合は受け入れる。
    SELECT sp.max_households INTO v_max FROM public.spaces sp WHERE sp.id = NEW.space_id;
    SELECT count(*) INTO v_count FROM public.households hh WHERE hh.space_id = NEW.space_id;
    IF v_max IS NULL OR v_count >= v_max THEN
      RAISE EXCEPTION 'limit_households' USING ERRCODE = 'P0001';
    END IF;
    NEW.created_at := now();
  ELSE
    IF NEW.id IS DISTINCT FROM OLD.id   -- [v0.2] V6
    OR NEW.space_id IS DISTINCT FROM OLD.space_id OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'immutable_column' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_households_before_write
  BEFORE INSERT OR UPDATE ON public.households
  FOR EACH ROW EXECUTE FUNCTION app_private.households_before_write();

-- 3-3. members（メンバーの数の上限。画面から変えられるのは自分の表示名だけ）
CREATE OR REPLACE FUNCTION app_private.members_before_write()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_space_id uuid;
  v_max      integer;
  v_count    integer;
BEGIN
  NEW.display_name := app_private.trim_text(NEW.display_name);
  IF TG_OP = 'INSERT' THEN
    -- 画面から members へ直接 INSERT するポリシーは無い。ここに来るのは参加の関数・場の作成だけ。
    SELECT hh.space_id INTO v_space_id FROM public.households hh WHERE hh.id = NEW.household_id;
    IF v_space_id IS NULL THEN
      RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0001';
    END IF;
    NEW.space_id := v_space_id;
    -- 同時に2人が参加しても上限を超えないよう、場の行をロックしてから数える。
    -- （members への INSERT は SECURITY DEFINER の関数からだけ＝RLS を通らないので FOR UPDATE が効く）
    SELECT sp.max_members INTO v_max FROM public.spaces sp WHERE sp.id = v_space_id FOR UPDATE;
    SELECT count(*) INTO v_count FROM public.members mb WHERE mb.space_id = v_space_id;
    IF v_count >= v_max THEN
      RAISE EXCEPTION 'limit_members' USING ERRCODE = 'P0001';
    END IF;
    NEW.created_at := now();
  ELSE
    IF current_user = 'authenticated' AND (
         NEW.id           IS DISTINCT FROM OLD.id   -- [v0.2] V6
      OR NEW.space_id     IS DISTINCT FROM OLD.space_id
      OR NEW.household_id IS DISTINCT FROM OLD.household_id
      OR NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id
      OR NEW.role         IS DISTINCT FROM OLD.role
      OR NEW.created_at   IS DISTINCT FROM OLD.created_at
    ) THEN
      RAISE EXCEPTION 'immutable_column' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_members_before_write
  BEFORE INSERT OR UPDATE ON public.members
  FOR EACH ROW EXECUTE FUNCTION app_private.members_before_write();

-- 3-4. invites（場は家庭から取る。発行者・期限はサーバーで決める。画面から変えられるのは「失効」だけ）
CREATE OR REPLACE FUNCTION app_private.invites_before_write()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_ttl      integer;
  v_space_id uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT hh.space_id INTO v_space_id FROM public.households hh WHERE hh.id = NEW.household_id;
    IF v_space_id IS NULL THEN
      RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0001';
    END IF;
    NEW.space_id := v_space_id;
    IF current_user = 'authenticated' THEN
      NEW.created_by_member_id := app_private.my_member_in(v_space_id);
      NEW.used_at := NULL;
      NEW.used_by_member_id := NULL;
      NEW.revoked_at := NULL;
    END IF;
    SELECT sp.invite_ttl_days INTO v_ttl FROM public.spaces sp WHERE sp.id = v_space_id;
    NEW.created_at := now();
    NEW.expires_at := now() + make_interval(days => v_ttl);
  ELSIF current_user = 'authenticated' THEN
    IF NEW.id                   IS DISTINCT FROM OLD.id   -- [v0.2] V6
    OR NEW.space_id             IS DISTINCT FROM OLD.space_id
    OR NEW.household_id         IS DISTINCT FROM OLD.household_id
    OR NEW.code_hash            IS DISTINCT FROM OLD.code_hash
    OR NEW.created_by_member_id IS DISTINCT FROM OLD.created_by_member_id
    OR NEW.created_at           IS DISTINCT FROM OLD.created_at
    OR NEW.expires_at           IS DISTINCT FROM OLD.expires_at
    OR NEW.used_at              IS DISTINCT FROM OLD.used_at
    OR NEW.used_by_member_id    IS DISTINCT FROM OLD.used_by_member_id
    OR (OLD.revoked_at IS NOT NULL AND NEW.revoked_at IS DISTINCT FROM OLD.revoked_at)
    THEN
      RAISE EXCEPTION 'immutable_column' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_invites_before_write
  BEFORE INSERT OR UPDATE ON public.invites
  FOR EACH ROW EXECUTE FUNCTION app_private.invites_before_write();

-- 3-5. tags（追加は「その他」の前。is_other は画面から立てられない）
--   [v0.5] Y5: 管理者が足すときは種類を送る（省略＝'trouble'）。並び順はトリガーが種類ごとに決める（画面の値は使わない）:
--     困りごと・両方 → sort_order は「困りごと・両方」の最大＋1（1〜99 の範囲。困りごとの並び・［すべて］の並びで「その他」の前）
--     育てたい       → sort_order は「育てたいだけ」の最大＋1（101〜。［すべて］では困りごとの後・「その他」の前）
--     育てたい・両方 → grow_sort_order は育てたいの並びの最大＋1（育てたいの並びで「その他」の前）
--   困りごと・両方のタグが99個を超えると育てたいの範囲と重なるが、上限の無いタグの追加でもそこまでは想定しない。
CREATE OR REPLACE FUNCTION app_private.tags_before_insert()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_max_order integer;
  v_max_grow  integer;
BEGIN
  NEW.name := app_private.trim_text(NEW.name);
  IF current_user = 'authenticated' THEN
    NEW.is_other := false;
    NEW.kind := coalesce(NEW.kind, 'trouble');
    IF NEW.kind IN ('trouble', 'both') THEN
      SELECT max(tg.sort_order) INTO v_max_order
      FROM public.tags tg WHERE tg.space_id = NEW.space_id AND NOT tg.is_other AND tg.kind IN ('trouble', 'both');
      NEW.sort_order := coalesce(v_max_order, 0) + 1;
    ELSE
      SELECT max(tg.sort_order) INTO v_max_order
      FROM public.tags tg WHERE tg.space_id = NEW.space_id AND NOT tg.is_other AND tg.kind = 'grow';
      NEW.sort_order := greatest(coalesce(v_max_order, 100), 100) + 1;
    END IF;
    IF NEW.kind IN ('grow', 'both') THEN
      SELECT max(tg.grow_sort_order) INTO v_max_grow
      FROM public.tags tg WHERE tg.space_id = NEW.space_id AND NOT tg.is_other AND tg.grow_sort_order IS NOT NULL;
      NEW.grow_sort_order := coalesce(v_max_grow, 0) + 1;
    ELSE
      NEW.grow_sort_order := NULL;
    END IF;
  END IF;
  NEW.created_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_tags_before_insert
  BEFORE INSERT ON public.tags
  FOR EACH ROW EXECUTE FUNCTION app_private.tags_before_insert();

-- 3-6. problems（①）
CREATE OR REPLACE FUNCTION app_private.problems_before_write()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.name := app_private.trim_text(NEW.name);
  IF TG_OP = 'INSERT' THEN
    IF current_user = 'authenticated' THEN
      PERFORM app_private.require_writer(NEW.space_id);
      NEW.created_household_id := app_private.my_household_in(NEW.space_id);
      NEW.created_by_member_id := app_private.my_member_in(NEW.space_id);
    END IF;
    NEW.created_at := now();
  ELSIF current_user = 'authenticated' THEN
    PERFORM app_private.require_writer(OLD.space_id);
    IF NEW.id                   IS DISTINCT FROM OLD.id   -- [v0.2] V6
    OR NEW.space_id             IS DISTINCT FROM OLD.space_id
    OR NEW.created_household_id IS DISTINCT FROM OLD.created_household_id
    OR NEW.created_by_member_id IS DISTINCT FROM OLD.created_by_member_id
    OR NEW.created_at           IS DISTINCT FROM OLD.created_at
    THEN
      RAISE EXCEPTION 'immutable_column' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_problems_before_write
  BEFORE INSERT OR UPDATE ON public.problems
  FOR EACH ROW EXECUTE FUNCTION app_private.problems_before_write();

-- ①を作ったら、まず「その他」を付ける（K-5）。書く関数（save_trial）は、選ばれたタグを足してから
-- 「その他」を外す（選ばれていれば残す）。どの道から作っても①のタグが0個にならない。
CREATE OR REPLACE FUNCTION app_private.problems_after_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.problem_tags (problem_id, tag_id)
  SELECT NEW.id, tg.id
  FROM public.tags tg
  WHERE tg.space_id = NEW.space_id AND tg.is_other;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_problems_after_insert
  AFTER INSERT ON public.problems
  FOR EACH ROW EXECUTE FUNCTION app_private.problems_after_insert();

-- [v0.5] Y4: ①の種類を変えたら、新しい種類に合わないタグ（種類が違い、両方でもないもの）を外す（[要件 4-5]）。
--   種類を変えられるかの判定は、v0.4 のまま RLS の problems_update_editable（can_edit_problem）。ここは変えられた後の後始末だけ
--   なので持ち主の権限（RLS を通らない）で外す。タグが0個になったら、problem_tags_after_delete が「その他」を付ける（K-5）。
--   画面は、外れるタグを前もって「合わないタグ（◯◯）は外れます」と出す（見えている①のタグと、タグの種類から分かる）。
CREATE OR REPLACE FUNCTION app_private.problems_after_update_kind()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.problem_tags pt
  USING public.tags tg
  WHERE pt.problem_id = NEW.id
    AND tg.id = pt.tag_id
    AND tg.kind NOT IN (NEW.kind, 'both');
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_problems_after_update_kind
  AFTER UPDATE OF kind ON public.problems
  FOR EACH ROW WHEN (OLD.kind IS DISTINCT FROM NEW.kind)
  EXECUTE FUNCTION app_private.problems_after_update_kind();

-- 3-7. problem_tags（タグと①が同じ場か）
CREATE OR REPLACE FUNCTION app_private.problem_tags_before_insert()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_problem_space uuid;
  v_tag_space     uuid;
  v_problem_kind  text;   -- [v0.5] Y3
  v_tag_kind      text;   -- [v0.5] Y3
BEGIN
  SELECT pr.space_id, pr.kind INTO v_problem_space, v_problem_kind FROM public.problems pr WHERE pr.id = NEW.problem_id;
  SELECT tg.space_id, tg.kind INTO v_tag_space, v_tag_kind FROM public.tags tg WHERE tg.id = NEW.tag_id;
  IF v_problem_space IS NULL OR v_problem_space IS DISTINCT FROM v_tag_space THEN
    RAISE EXCEPTION 'not_visible' USING ERRCODE = '42501';
  END IF;
  -- [v0.5] Y3: ①に付けられるのは、①の種類のタグと「両方」のタグだけ（[要件 4-5]）。どの立場から書いても守る。
  --   画面は①の種類に合うタグだけを出すので、ふつうは起きない（起きたら画面の不具合）。
  IF v_tag_kind NOT IN (v_problem_kind, 'both') THEN
    RAISE EXCEPTION 'tag_kind_mismatch' USING ERRCODE = 'P0001';
  END IF;
  IF current_user = 'authenticated' THEN
    PERFORM app_private.require_writer(v_problem_space);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_problem_tags_before_insert
  BEFORE INSERT ON public.problem_tags
  FOR EACH ROW EXECUTE FUNCTION app_private.problem_tags_before_insert();

-- タグを外して0個になったら「その他」を付け直す（①そのものが消えたとき＝CASCADE は何もしない）。
CREATE OR REPLACE FUNCTION app_private.problem_tags_after_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.problems pr WHERE pr.id = OLD.problem_id)
     AND NOT EXISTS (SELECT 1 FROM public.problem_tags pt WHERE pt.problem_id = OLD.problem_id)
  THEN
    INSERT INTO public.problem_tags (problem_id, tag_id)
    SELECT pr.id, tg.id
    FROM public.problems pr
    JOIN public.tags tg ON tg.space_id = pr.space_id AND tg.is_other
    WHERE pr.id = OLD.problem_id;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_problem_tags_after_delete
  AFTER DELETE ON public.problem_tags
  FOR EACH ROW EXECUTE FUNCTION app_private.problem_tags_after_delete();

-- 3-8. measures（②。場は①から取る。①は変えられない）
CREATE OR REPLACE FUNCTION app_private.measures_before_write()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_space_id uuid;
BEGIN
  NEW.name := app_private.trim_text(NEW.name);
  IF TG_OP = 'INSERT' THEN
    -- 画面からのときは RLS を通して①を読む＝見えない①・無い①は、どちらも同じ not_visible になる。
    SELECT pr.space_id INTO v_space_id FROM public.problems pr WHERE pr.id = NEW.problem_id;
    IF v_space_id IS NULL THEN
      RAISE EXCEPTION 'not_visible' USING ERRCODE = '42501';
    END IF;
    NEW.space_id := v_space_id;
    IF current_user = 'authenticated' THEN
      PERFORM app_private.require_writer(v_space_id);
      NEW.created_household_id := app_private.my_household_in(v_space_id);
      NEW.created_by_member_id := app_private.my_member_in(v_space_id);
    END IF;
    NEW.created_at := now();
  ELSIF current_user = 'authenticated' THEN
    PERFORM app_private.require_writer(OLD.space_id);
    IF NEW.id                   IS DISTINCT FROM OLD.id   -- [v0.2] V6
    OR NEW.space_id             IS DISTINCT FROM OLD.space_id
    OR NEW.problem_id           IS DISTINCT FROM OLD.problem_id
    OR NEW.created_household_id IS DISTINCT FROM OLD.created_household_id
    OR NEW.created_by_member_id IS DISTINCT FROM OLD.created_by_member_id
    OR NEW.created_at           IS DISTINCT FROM OLD.created_at
    THEN
      RAISE EXCEPTION 'immutable_column' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_measures_before_write
  BEFORE INSERT OR UPDATE ON public.measures
  FOR EACH ROW EXECUTE FUNCTION app_private.measures_before_write();

-- 3-9. books
CREATE OR REPLACE FUNCTION app_private.books_before_write()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.title := app_private.trim_text(NEW.title);
  NEW.author := nullif(app_private.trim_text(coalesce(NEW.author, '')), '');
  IF TG_OP = 'INSERT' THEN
    IF current_user = 'authenticated' THEN
      PERFORM app_private.require_writer(NEW.space_id);
      NEW.created_by_member_id := app_private.my_member_in(NEW.space_id);
    END IF;
    NEW.created_at := now();
  ELSIF current_user = 'authenticated' THEN
    PERFORM app_private.require_writer(OLD.space_id);
    IF NEW.id                   IS DISTINCT FROM OLD.id   -- [v0.2] V6
    OR NEW.space_id             IS DISTINCT FROM OLD.space_id
    OR NEW.created_by_member_id IS DISTINCT FROM OLD.created_by_member_id
    OR NEW.created_at           IS DISTINCT FROM OLD.created_at
    THEN
      RAISE EXCEPTION 'immutable_column' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_books_before_write
  BEFORE INSERT OR UPDATE ON public.books
  FOR EACH ROW EXECUTE FUNCTION app_private.books_before_write();

-- 3-10. trials（③。場は②から、家庭・書いた人はその場での自分から決める。未来の日付は不可）
CREATE OR REPLACE FUNCTION app_private.trials_before_write()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_space_id      uuid;
  v_book_space_id uuid;
BEGIN
  NEW.heard_from := nullif(app_private.trim_text(coalesce(NEW.heard_from, '')), '');
  NEW.source_url := nullif(app_private.trim_text(coalesce(NEW.source_url, '')), '');
  NEW.note       := nullif(app_private.trim_text(coalesce(NEW.note, '')), '');
  NEW.source_text := nullif(app_private.trim_text(coalesce(NEW.source_text, '')), '');   -- [v0.4] X4
  -- [v0.4] X3: 「まで」＝「から」なら 1つの年齢（空）にそろえる
  IF NEW.age_months_to IS NOT DISTINCT FROM NEW.age_months THEN
    NEW.age_months_to := NULL;
  END IF;
  -- [v0.4] X2・X5: 状態と点数（[要件 4-3・4-3b]）。どの立場から書いても同じ（持ち主の権限の見本データも）。
  IF TG_OP = 'INSERT' THEN
    -- 状態を送らなかったとき（v0.3 までの書き方）は点数から決める。送ったときはそのまま（合わなければ chk_trials_status_score で 23514）。
    IF NEW.status IS NULL THEN
      NEW.status := CASE WHEN NEW.score IS NULL THEN 'trying' ELSE 'scored' END;
    END IF;
  ELSE
    IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
      -- 状態は変えず点数だけ直した（v0.3 の「試し中 → 点数」の直し方〈表 trials の score だけを UPDATE〉のまま通す）:
      --   点数を入れた → 試した／点数を空にした → 試し中（「試したい」のままなら試したい）
      IF NEW.score IS DISTINCT FROM OLD.score THEN
        NEW.status := CASE WHEN NEW.score IS NOT NULL THEN 'scored'
                           WHEN OLD.status = 'scored' THEN 'trying'
                           ELSE OLD.status END;
      END IF;
    ELSIF NEW.status IN ('trying', 'want') AND NEW.score IS NOT DISTINCT FROM OLD.score THEN
      -- 状態だけを試し中・試したいに直した（点数から戻す）→ 点数を空にする
      NEW.score := NULL;
    END IF;
    -- 「試したい」→「試し中」「試した」（[試し始めた]・[点数を付ける]）で、日付を直していなければ今日にする
    --   （[要件 4-3]「試したい → 試し中に直したときは今日に変える」。試した も同じに扱う＝[設計 16-4] R2 で企画部に確認）
    IF OLD.status = 'want' AND NEW.status IN ('trying', 'scored')
       AND NEW.tried_on IS NOT DISTINCT FROM OLD.tried_on THEN
      NEW.tried_on := app_private.today_jst();
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    -- 画面からのときは RLS を通して②を読む（見えない②・無い②は同じ not_visible）。
    SELECT me.space_id INTO v_space_id FROM public.measures me WHERE me.id = NEW.measure_id;
    IF v_space_id IS NULL THEN
      RAISE EXCEPTION 'not_visible' USING ERRCODE = '42501';
    END IF;
    NEW.space_id := v_space_id;
    IF current_user = 'authenticated' THEN
      PERFORM app_private.require_writer(v_space_id);
      NEW.household_id := app_private.my_household_in(v_space_id);
      NEW.created_by_member_id := app_private.my_member_in(v_space_id);
      NEW.updated_by_member_id := NEW.created_by_member_id;
    END IF;
    NEW.tried_on := coalesce(NEW.tried_on, app_private.today_jst());
    NEW.created_at := now();
  ELSIF current_user = 'authenticated' THEN
    PERFORM app_private.require_writer(OLD.space_id);
    IF NEW.id                   IS DISTINCT FROM OLD.id   -- [v0.2] V6
    OR NEW.space_id             IS DISTINCT FROM OLD.space_id
    OR NEW.measure_id           IS DISTINCT FROM OLD.measure_id
    OR NEW.household_id         IS DISTINCT FROM OLD.household_id
    OR NEW.created_by_member_id IS DISTINCT FROM OLD.created_by_member_id
    OR NEW.created_at           IS DISTINCT FROM OLD.created_at
    THEN
      RAISE EXCEPTION 'immutable_column' USING ERRCODE = 'P0001';
    END IF;
    NEW.updated_by_member_id := app_private.my_member_in(OLD.space_id);
  END IF;
  IF NEW.tried_on > app_private.today_jst() THEN
    RAISE EXCEPTION 'future_date' USING ERRCODE = 'P0001';
  END IF;
  IF NEW.book_id IS NOT NULL THEN
    SELECT bk.space_id INTO v_book_space_id FROM public.books bk WHERE bk.id = NEW.book_id;
    IF v_book_space_id IS DISTINCT FROM NEW.space_id THEN
      RAISE EXCEPTION 'cross_space' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_trials_before_write
  BEFORE INSERT OR UPDATE ON public.trials
  FOR EACH ROW EXECUTE FUNCTION app_private.trials_before_write();


-- ============================================================
-- 4. RLS のポリシー（[要件 2-3] の権限表そのまま。対応表は [設計 3-2]）
--   **どのポリシーも、まず「自分が入っている場」に絞る**（場をまたいでは何も見えない・書けない）。
--   (SELECT app_private.…()) と括弧で包むのは、1回の問い合わせで1回だけ計算させるため。
--   ここに無い操作は拒否（例: spaces の INSERT/UPDATE/DELETE、members の INSERT/DELETE、tags の UPDATE/DELETE）。
-- ============================================================

-- 4-1. spaces: 自分が入っている場だけ読める。作る・消すのは service_role の関数だけ。
CREATE POLICY spaces_select_member ON public.spaces
  FOR SELECT TO authenticated
  USING (id IN (SELECT app_private.my_space_ids()));

-- 4-2. households: その場の全員が読める。作る・名前を直すのはその場の管理者。消すのは delete_household_data() だけ。
CREATE POLICY households_select_same_space ON public.households
  FOR SELECT TO authenticated
  USING (space_id IN (SELECT app_private.my_space_ids()));
CREATE POLICY households_insert_admin ON public.households
  FOR INSERT TO authenticated
  WITH CHECK (space_id IN (SELECT app_private.admin_space_ids()));
CREATE POLICY households_update_admin ON public.households
  FOR UPDATE TO authenticated
  USING (space_id IN (SELECT app_private.admin_space_ids()))
  WITH CHECK (space_id IN (SELECT app_private.admin_space_ids()));

-- 4-3. members: その場の全員の表示名が読める。直せるのは自分の表示名だけ（列はトリガーで制限）。
--      加わるのは join_with_invite_code()、抜けるのは delete_member_data()（service_role）だけ。
CREATE POLICY members_select_same_space ON public.members
  FOR SELECT TO authenticated
  USING (space_id IN (SELECT app_private.my_space_ids()));
CREATE POLICY members_update_self ON public.members
  FOR UPDATE TO authenticated
  USING (id IN (SELECT app_private.my_member_ids()))
  WITH CHECK (id IN (SELECT app_private.my_member_ids()));

-- 4-4. consents: 自分の記録と、場の管理者はその場のメンバーの記録（誰が同意したかの確認）。
--      書くのは record_rules_consent() だけ。
CREATE POLICY consents_select_own_or_admin ON public.consents
  FOR SELECT TO authenticated
  USING (
    auth_user_id = (SELECT auth.uid())
    OR auth_user_id IN (
      SELECT mb.auth_user_id FROM public.members mb
      WHERE mb.space_id IN (SELECT app_private.admin_space_ids())
    )
  );

-- 4-5. invites: その場の管理者だけ（読む・発行・失効）。
CREATE POLICY invites_select_admin ON public.invites
  FOR SELECT TO authenticated
  USING (space_id IN (SELECT app_private.admin_space_ids()));
CREATE POLICY invites_insert_admin ON public.invites
  FOR INSERT TO authenticated
  WITH CHECK (space_id IN (SELECT app_private.admin_space_ids()));
CREATE POLICY invites_update_admin ON public.invites
  FOR UPDATE TO authenticated
  USING (space_id IN (SELECT app_private.admin_space_ids()))
  WITH CHECK (space_id IN (SELECT app_private.admin_space_ids()));

-- 4-6. invite_attempts: ポリシーなし（画面からは読めない・書けない）。

-- 4-7. tags: その場の全員が読める。追加はその場の管理者（F-27）。名前の変更・削除は次フェーズ（N-20）。
CREATE POLICY tags_select_same_space ON public.tags
  FOR SELECT TO authenticated
  USING (space_id IN (SELECT app_private.my_space_ids()));
CREATE POLICY tags_insert_admin ON public.tags
  FOR INSERT TO authenticated
  WITH CHECK (space_id IN (SELECT app_private.admin_space_ids()));

-- 4-8. problems（①）
--   [v0.3] W4 注意（ポリシーは v0.2 のまま）: problems と measures の「読む」の決まりは、見える一覧の関数
--   （visible_problem_ids()／visible_measure_ids()。STABLE）で決まる。STABLE の関数は、**同じ文の中で入れた
--   ばかりの行を見られない**。PostgreSQL は INSERT に RETURNING が付くと、新しい行が「読む」の決まりも満たすかを
--   確かめるので、**problems・measures への「INSERT … RETURNING」は必ず RLS の拒否になる**
--   （new row violates row-level security policy。開発部がローカルで見つけた＝[設計 6-1]）。
--   → 関数の中では ID を先に gen_random_uuid() で決めてから INSERT する（save_trial。W1）。
--   → 画面（supabase-js）から problems・measures に直接 INSERT するときは .select() を付けない・.upsert() を
--     使わない（どちらも RETURNING／ON CONFLICT になる）。ただし画面が①②を作る道は save_trial だけ（[設計 6]）。
--   ③・本・タグ・家庭・招待の「読む」の決まりは members だけを見る関数（my_space_ids() など）か列だけで
--   決まり、入れる行そのものに左右されないので、RETURNING でも通る（[設計 6-1] の点検表）。
CREATE POLICY problems_select_visible ON public.problems
  FOR SELECT TO authenticated
  USING (id IN (SELECT app_private.visible_problem_ids()));
CREATE POLICY problems_insert_own_household ON public.problems
  FOR INSERT TO authenticated
  WITH CHECK (
    space_id IN (SELECT app_private.my_space_ids())
    AND created_household_id = app_private.my_household_in(space_id)
  );
CREATE POLICY problems_update_editable ON public.problems
  FOR UPDATE TO authenticated
  USING (app_private.can_edit_problem(id))
  WITH CHECK (app_private.can_edit_problem(id));
CREATE POLICY problems_delete_deletable ON public.problems
  FOR DELETE TO authenticated
  USING (app_private.can_delete_problem(id));

-- 4-9. problem_tags（タグの付け外しは①の名前と同じ条件。K-4）
CREATE POLICY problem_tags_select_visible ON public.problem_tags
  FOR SELECT TO authenticated
  USING (problem_id IN (SELECT app_private.visible_problem_ids()));
CREATE POLICY problem_tags_insert_editable ON public.problem_tags
  FOR INSERT TO authenticated
  WITH CHECK (app_private.can_edit_problem(problem_id));
CREATE POLICY problem_tags_delete_editable ON public.problem_tags
  FOR DELETE TO authenticated
  USING (app_private.can_edit_problem(problem_id));

-- 4-10. measures（②。作れるのは見える①の下だけ）
CREATE POLICY measures_select_visible ON public.measures
  FOR SELECT TO authenticated
  USING (id IN (SELECT app_private.visible_measure_ids()));
CREATE POLICY measures_insert_under_visible_problem ON public.measures
  FOR INSERT TO authenticated
  WITH CHECK (
    problem_id IN (SELECT app_private.visible_problem_ids())
    AND created_household_id = app_private.my_household_in(space_id)
  );
CREATE POLICY measures_update_editable ON public.measures
  FOR UPDATE TO authenticated
  USING (app_private.can_edit_measure(id))
  WITH CHECK (app_private.can_edit_measure(id));
CREATE POLICY measures_delete_deletable ON public.measures
  FOR DELETE TO authenticated
  USING (app_private.can_delete_measure(id));

-- 4-11. books（公開範囲を持たない。U-34）
CREATE POLICY books_select_same_space ON public.books
  FOR SELECT TO authenticated
  USING (space_id IN (SELECT app_private.my_space_ids()));
CREATE POLICY books_insert_member ON public.books
  FOR INSERT TO authenticated
  WITH CHECK (
    space_id IN (SELECT app_private.my_space_ids())
    AND created_by_member_id = app_private.my_member_in(space_id)
  );
CREATE POLICY books_update_admin_or_registrant ON public.books
  FOR UPDATE TO authenticated
  USING (
    space_id IN (SELECT app_private.admin_space_ids())
    OR created_by_member_id IN (SELECT app_private.my_member_ids())
  )
  WITH CHECK (
    space_id IN (SELECT app_private.admin_space_ids())
    OR created_by_member_id IN (SELECT app_private.my_member_ids())
  );
CREATE POLICY books_delete_unused ON public.books
  FOR DELETE TO authenticated
  USING (app_private.can_delete_book(id));

-- 4-12. trials（③）
--   読む: 「みんな」はその場の全員、「自分の家庭だけ」は同じ家庭だけ（管理者も他家庭の非公開は読めない）。
--   書く: 自家庭の③として、見える②にだけ。直す: 自家庭の③（夫婦など同じ家庭は誰でも）。
--   消す: 自家庭の③。その場の管理者は他家庭の「みんな」の③も（応急処置）。
--   家庭の ID はどれも1つの場に属するので、household_id の一致だけで場をまたがない。
CREATE POLICY trials_select_visible ON public.trials
  FOR SELECT TO authenticated
  USING (
    space_id IN (SELECT app_private.my_space_ids())
    AND (visibility = 'all' OR household_id IN (SELECT app_private.my_household_ids()))
  );
CREATE POLICY trials_insert_own_household ON public.trials
  FOR INSERT TO authenticated
  WITH CHECK (
    household_id = app_private.my_household_in(space_id)
    AND measure_id IN (SELECT app_private.visible_measure_ids())
  );
CREATE POLICY trials_update_own_household ON public.trials
  FOR UPDATE TO authenticated
  USING (household_id IN (SELECT app_private.my_household_ids()))
  WITH CHECK (household_id IN (SELECT app_private.my_household_ids()));
CREATE POLICY trials_delete_own_or_admin_public ON public.trials
  FOR DELETE TO authenticated
  USING (
    household_id IN (SELECT app_private.my_household_ids())
    OR (visibility = 'all' AND space_id IN (SELECT app_private.admin_space_ids()))
  );


-- ============================================================
-- 5. 画面から呼ぶ関数（RPC。[設計 5・6]）
--   読む関数はすべて SECURITY INVOKER の SQL 関数＝中の問い合わせに RLS がそのまま効く。
--   「見えるものだけで計算する」ことを、関数の中で規則を書き直さずに満たす（規則は RLS の1か所だけ）。
--   一覧の関数は p_space_id（どの場のノートを見ているか）を受け取り、その場だけに絞る。
-- ============================================================

-- 5-0. 自分が入っている場の一覧（画面は「今どの場を見ているか」を端末に覚え、各関数に p_space_id で渡す）
--   [v0.2] V1: o_admin_member_id・o_admin_display_name を足した。断りの文の「管理者（◯◯さん）」の◯◯に
--   画面が差し込む（[要件 2-5] の2。C36）。管理者の表示名は、その場のメンバーなら members の RLS で元々読める
--   情報なので、新しく見せるものは無い。管理者の行は場に必ず1つ（bootstrap_space が作り、退会・削除できない）。
--   念のため LEFT JOIN にし、万一いなければ NULL（画面は「管理者」とだけ出す）。
--   [v0.3] W3: 並びを「自分が参加した順」（mb.created_at）にした（v0.2 は場の作成順）。[要件 3-1] F-04
--   「最後に見ていたノート、なければ参加が早いノートを開く」の「なければ」のとき、画面は先頭の行を開けばよい。
--   MVP では2冊目の入口を作らない（C67）ので、ふつうは1行。出力列は v0.2 と同じ。
--   招待コードで参加した直後の「『◯◯』として参加しました」（F-01・C69）の◯◯は、参加の後にこの関数の
--   o_household_name を読む（参加の前に家庭名を返す関数は作らない）。「管理者（◯◯さん）」は o_admin_display_name。
CREATE OR REPLACE FUNCTION public.list_my_spaces()
RETURNS TABLE (
  o_space_id            uuid,
  o_space_name          text,
  o_household_id        uuid,
  o_household_name      text,
  o_member_id           uuid,
  o_role                text,
  o_max_households      integer,
  o_max_members         integer,
  o_admin_member_id     uuid,   -- [v0.2] V1
  o_admin_display_name  text    -- [v0.2] V1
)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT sp.id, sp.name, hh.id, hh.display_name, mb.id, mb.role, sp.max_households, sp.max_members,
         ad.id, ad.display_name
  FROM public.members mb
  JOIN public.spaces sp ON sp.id = mb.space_id
  JOIN public.households hh ON hh.id = mb.household_id
  LEFT JOIN public.members ad ON ad.space_id = mb.space_id AND ad.role = 'admin'
  WHERE mb.auth_user_id = (SELECT auth.uid())
  ORDER BY mb.created_at, sp.id   -- [v0.3] W3（v0.2 は sp.created_at, sp.id）
$$;

-- 5-1. 困りごとの一覧＋検索＋タグのタブ＋年齢の絞り込み（[要件 6-1・6-2]。F-20・F-22・F-21 の先）
--   並び: その①の下の「見える③」の最後に書かれた・直された日時（無ければ①の作成日時）の新しい順（U-30）。
CREATE OR REPLACE FUNCTION public.search_problems(
  p_space_id     uuid,
  p_query        text    DEFAULT NULL,
  p_tag_id       uuid    DEFAULT NULL,
  p_age_years    integer DEFAULT NULL,
  p_limit        integer DEFAULT 50,
  p_offset       integer DEFAULT 0,
  p_kind         text    DEFAULT NULL,   -- [v0.4] X6: NULL＝すべて／'trouble'／'grow'（[要件 6-1]）
  p_age_years_to integer DEFAULT NULL    -- [v0.4] X6: 年齢のまとまりで絞るときの「まで」の歳（例 3〜5歳なら p_age_years=3, p_age_years_to=5）
)
RETURNS TABLE (
  o_problem_id           uuid,
  o_name                 text,
  o_created_household_id uuid,
  o_tag_ids              uuid[],
  o_measure_count        integer,
  o_trial_count          integer,
  o_sort_at              timestamptz,
  o_kind                 text            -- [v0.4] X6: ①の種類（「育てたい」の札に使う）
)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  WITH q_terms AS (
    SELECT DISTINCT qt.term
    FROM unnest(regexp_split_to_array(app_private.norm(p_query), '[[:space:]]+')) AS qt(term)
    WHERE qt.term <> ''
  ),
  vp AS (   -- 見える①（RLS）のうち、この場のもの
    SELECT pr.id, pr.name, pr.kind, pr.created_household_id, pr.created_at, app_private.norm(pr.name) AS nname
    FROM public.problems pr
    WHERE pr.space_id = p_space_id
      AND (p_kind IS NULL OR pr.kind = p_kind)   -- [v0.4] X6
  ),
  vm AS (   -- 見える②（RLS）
    SELECT me.id, me.problem_id, app_private.norm(me.name) AS nname
    FROM public.measures me
    WHERE me.space_id = p_space_id
  ),
  vt AS (   -- 見える③（RLS）
    SELECT tr.id, tr.measure_id, tr.age_months, tr.age_months_to, tr.updated_at
    FROM public.trials tr
    WHERE tr.space_id = p_space_id
  ),
  hit AS (
    SELECT vp.id, vp.name, vp.kind, vp.created_household_id, vp.created_at
    FROM vp
    WHERE NOT EXISTS (   -- どの語も、①の名前か、その①の下の見える②の名前に含まれる（AND）
            SELECT 1 FROM q_terms qt
            WHERE strpos(vp.nname, qt.term) = 0
              AND NOT EXISTS (
                SELECT 1 FROM vm
                WHERE vm.problem_id = vp.id AND strpos(vm.nname, qt.term) > 0
              )
          )
      AND (p_tag_id IS NULL OR EXISTS (
            SELECT 1 FROM public.problem_tags pt
            WHERE pt.problem_id = vp.id AND pt.tag_id = p_tag_id
          ))
      AND (p_age_years IS NULL OR EXISTS (   -- [v0.4] X6: その歳（まとまり）に入る見える③がある（範囲の③は入る歳すべて）
            SELECT 1 FROM vm JOIN vt ON vt.measure_id = vm.id
            WHERE vm.problem_id = vp.id
              AND app_private.age_overlaps(vt.age_months, vt.age_months_to, p_age_years, p_age_years_to)
          ))
  )
  SELECT
    hit.id,
    hit.name,
    hit.created_household_id,
    (SELECT coalesce(array_agg(pt.tag_id ORDER BY tg.sort_order), '{}'::uuid[])
       FROM public.problem_tags pt JOIN public.tags tg ON tg.id = pt.tag_id
      WHERE pt.problem_id = hit.id),
    (SELECT count(*)::integer FROM vm WHERE vm.problem_id = hit.id),
    (SELECT count(*)::integer FROM vm JOIN vt ON vt.measure_id = vm.id WHERE vm.problem_id = hit.id),
    coalesce(
      (SELECT max(vt.updated_at) FROM vm JOIN vt ON vt.measure_id = vm.id WHERE vm.problem_id = hit.id),
      hit.created_at
    ),
    hit.kind
  FROM hit
  ORDER BY 7 DESC, 1
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
  OFFSET greatest(0, coalesce(p_offset, 0))
$$;

-- 5-2. 年齢の一覧（[要件 6-2]・5-3。1歳ごと＝月齢÷12の切り捨て。件数＝その歳の見える③を持つ①の数。0件の歳は出ない）
-- [v0.4] X7: 範囲の③（から〜まで）は、「から」の歳から「まで」の歳まで（月齢÷12 の切り捨て）の**すべての歳**に数える
--   （[要件 5-4]）。件数は「その歳に入る見える③を1件以上持つ①の数」（同じ歳の中で二重に数えない）。①の種類では分けない（[要件 6-2]）。
CREATE OR REPLACE FUNCTION public.list_age_counts(p_space_id uuid)
RETURNS TABLE (o_age_years integer, o_problem_count integer)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT gs.y, count(DISTINCT me.problem_id)::integer
  FROM public.trials tr
  JOIN public.measures me ON me.id = tr.measure_id
  CROSS JOIN LATERAL generate_series(tr.age_months / 12, coalesce(tr.age_months_to, tr.age_months) / 12) AS gs(y)
  WHERE tr.space_id = p_space_id
  GROUP BY gs.y
  ORDER BY 1
$$;

-- [v0.5] Y7: v0.4 で足した list_age_band_counts（年齢のまとまりごとの件数）は消した。要件 v0.8（C106。統括「わかるし」）で
--   年齢の一覧は1歳ごとだけに戻り、画面で使わなくなったため（企画部の推し＝使わない関数とテストを持たない）。
--   範囲の③を入る歳それぞれに数えるのは list_age_counts のまま。まとまりを戻すときは schema_v0.4 の本文をそのまま戻せばよい。

-- 5-3. 対策の一覧（[要件 6-3]。F-23・F-24。年齢の一覧から来たときの絞り込み U-37）
--   o_group: 0＝点数のある見える③がある ／ 1＝見える③がすべて試し中 ／ 2＝見える③が0件（作った家庭だけに見える②）
--   並び: o_group → 最高点の高い順 → 見える③を付けた家庭の数の多い順（試し中も数える）→ いちばん新しい③の日付 → ②の作成日時
--   o_trials: 見える③を「点数の高い順・同点は日付の新しい順・試し中は最後」に並べた配列（行の中の並び）。
--   出典のタブ・年齢で絞っても、行の中の③と並び順は、絞る前の見える③全部で出す（[要件 6-2・6-3]）。
--   [v0.2] V2: p_age_years を渡されたとき（年齢の一覧から入った＝絞り込み中）は、行の中の③を
--     「その歳の③（点数の高い順・同点は日付の新しい順・試し中は最後）→ ほかの歳の③（同じ並び）」にする。
--     各③に "in_age"（その歳の③なら true。絞り込みが無ければすべて false）を付け、画面はこれで太字にする
--     （[要件 6-2]・C47・U-37 決着）。行の並び（o_group 以下）と、どの行を出すかは v0.1 と同じ。
--   「試し中・◯日目」（C49）は画面が tried_on から計算する（日数＝日本時間の今日 − tried_on ＋ 1）。表は変えない。
--   [v0.4] X8（[要件 6-2〜6-4]・4-3b・5-4節）:
--     o_group: 0＝「試した」の見える③がある ／ 1＝（試したはなく）試し中がある ／ 2＝見える③がすべて試したい
--              ／ 3＝見える③が0件（v0.3 の 2 が 3 になった。画面は o_group の値そのものは使っていない）
--     家庭の数（o_household_count）と日付（o_latest_tried_on）は「試したい」を除いて数える（試したいは試した家庭ではない）。
--     グループ2（すべて試したい）の日付は、試したいの③の日付（書いた日）の最新。
--     行の中の③: その歳の③（絞り込み中）→ 試した（点数の高い順・同点は日付の新しい順）→ 試し中 → 試したい。
--     年齢の絞り込みは p_age_years〜p_age_years_to（まとまり）。範囲の③は入る歳すべてで判定（in_age も同じ）。
--     o_trials の各③に status・age_months_to・source_text・created_by_name（書いた人の呼び名。書いた人が空なら null）・
--     household_name（家庭名）を足した。呼び名・家庭名は members・households の RLS（同じ場の全員が読める）を通して読むので、
--     見え方の規則は変わらない（見える③の書いた人だけが出る）。[要件 6-3]・C87。
CREATE OR REPLACE FUNCTION public.list_measures(
  p_problem_id   uuid,
  p_source_type  text    DEFAULT NULL,
  p_age_years    integer DEFAULT NULL,
  p_age_years_to integer DEFAULT NULL    -- [v0.4] X8: まとまりで絞るときの「まで」の歳
)
RETURNS TABLE (
  o_measure_id           uuid,
  o_name                 text,
  o_created_household_id uuid,
  o_group                integer,
  o_best_score           integer,
  o_household_count      integer,
  o_latest_tried_on      date,
  o_trial_count          integer,
  o_trials               jsonb
)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  WITH vm AS (
    SELECT me.id, me.name, me.created_household_id, me.created_at
    FROM public.measures me
    WHERE me.problem_id = p_problem_id
  ),
  vt AS (
    SELECT tr.id, tr.measure_id, tr.household_id, tr.status, tr.score, tr.age_months, tr.age_months_to,
           tr.source_type, tr.book_id, tr.source_url, tr.heard_from, tr.source_text, tr.note, tr.tried_on,
           tr.visibility, tr.created_at, tr.created_by_member_id,
           app_private.age_overlaps(tr.age_months, tr.age_months_to, p_age_years, p_age_years_to) AS in_age
    FROM public.trials tr
    JOIN vm ON vm.id = tr.measure_id
  ),
  agg AS (
    SELECT vm.id AS mid,
           max(vt.score)::integer                                                   AS best_score,
           count(DISTINCT vt.household_id) FILTER (WHERE vt.status <> 'want')::integer AS hh_count,
           max(vt.tried_on) FILTER (WHERE vt.status <> 'want')                      AS latest_on,
           max(vt.tried_on) FILTER (WHERE vt.status = 'want')                       AS latest_want_on,
           count(vt.id)::integer                                                    AS n_trials,
           coalesce(bool_or(vt.status = 'scored'), false)                           AS has_score,
           coalesce(bool_or(vt.status = 'trying'), false)                           AS has_trying
    FROM vm
    LEFT JOIN vt ON vt.measure_id = vm.id
    GROUP BY vm.id
  )
  SELECT
    vm.id,
    vm.name,
    vm.created_household_id,
    CASE WHEN agg.n_trials = 0 THEN 3 WHEN agg.has_score THEN 0 WHEN agg.has_trying THEN 1 ELSE 2 END,
    agg.best_score,
    agg.hh_count,
    coalesce(agg.latest_on, agg.latest_want_on),
    agg.n_trials,
    (SELECT coalesce(jsonb_agg(jsonb_build_object(
              'trial_id',        t2.id,
              'household_id',    t2.household_id,
              'household_name',  hh.display_name,          -- [v0.4] X8
              'status',          t2.status,                -- [v0.4] X8
              'score',           t2.score,
              'age_months',      t2.age_months,
              'age_months_to',   t2.age_months_to,         -- [v0.4] X8
              'source_type',     t2.source_type,
              'book_title',      bk.title,
              'book_author',     bk.author,
              'source_url',      t2.source_url,
              'heard_from',      t2.heard_from,
              'source_text',     t2.source_text,           -- [v0.4] X8
              'note',            t2.note,
              'tried_on',        t2.tried_on,
              'visibility',      t2.visibility,
              'created_by_member_id', t2.created_by_member_id,
              'created_by_name', mb.display_name,          -- [v0.4] X8 書いた人の呼び名（空なら null）
              'in_age',          t2.in_age
            ) ORDER BY
                t2.in_age DESC,                                                        -- その歳の③を先に
                CASE t2.status WHEN 'scored' THEN 0 WHEN 'trying' THEN 1 ELSE 2 END,   -- [v0.4] 試した → 試し中 → 試したい
                t2.score DESC NULLS LAST, t2.tried_on DESC, t2.created_at DESC, t2.id), '[]'::jsonb)
       FROM vt t2
       LEFT JOIN public.books bk ON bk.id = t2.book_id
       LEFT JOIN public.members mb ON mb.id = t2.created_by_member_id
       LEFT JOIN public.households hh ON hh.id = t2.household_id
      WHERE t2.measure_id = vm.id)
  FROM vm
  JOIN agg ON agg.mid = vm.id
  WHERE (p_source_type IS NULL OR EXISTS (
          SELECT 1 FROM vt t3 WHERE t3.measure_id = vm.id AND t3.source_type = p_source_type))
    AND (p_age_years IS NULL OR EXISTS (
          SELECT 1 FROM vt t4 WHERE t4.measure_id = vm.id AND t4.in_age))
  ORDER BY
    4 ASC,
    agg.best_score DESC NULLS LAST,
    agg.hh_count DESC,
    coalesce(agg.latest_on, agg.latest_want_on) DESC NULLS LAST,
    vm.created_at DESC,
    vm.id
$$;

-- 5-4. 候補表示（F-17。部分一致・最大5件。完全一致を先に。o_is_exact は「すでにあります」の確認に使う）
CREATE OR REPLACE FUNCTION public.suggest_problems(p_space_id uuid, p_text text)
RETURNS TABLE (o_problem_id uuid, o_name text, o_is_exact boolean, o_kind text)   -- [v0.4] X9: o_kind（選んだ①の種類に書く画面を切り替える）
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  WITH q AS (SELECT app_private.norm(app_private.trim_text(coalesce(p_text, ''))) AS t)
  SELECT pr.id, pr.name, app_private.norm(pr.name) = q.t, pr.kind
  FROM public.problems pr
  CROSS JOIN q
  WHERE pr.space_id = p_space_id
    AND q.t <> '' AND strpos(app_private.norm(pr.name), q.t) > 0
  ORDER BY (app_private.norm(pr.name) = q.t) DESC,
           (strpos(app_private.norm(pr.name), q.t) = 1) DESC,
           char_length(pr.name), pr.name, pr.id
  LIMIT 5
$$;

-- [v0.2] V3: ②の候補は、欄を押した時点（打つ前＝p_text が空か NULL）でも最大5件を返す（[要件 F-17]・C48・B21）。
--   打つ前の並びは「対策の一覧（list_measures）と同じ並び」（UIUXデザイン部/成果物/ワイヤーフレーム_v0.1（2026-09-29）.md の C-1 書く画面「B-3 と同じ並び」）:
--   o_group（点数のある見える③あり → すべて試し中 → 見える③0件）→ 見える③の最高点 → 見える③を付けた家庭の数
--   → いちばん新しい③の日付 → ②の作成日時の新しい順 → ID。
--   打ったあと（p_text が空でない）は v0.1 と同じ「完全一致 → 前方一致 → 短い名前 → 名前順」で、同じなら上の並び。
--   ③は RLS を通して読む（SECURITY INVOKER）ので、並びにも見えない③は効かない（[要件 2-4]・Z22）。
--   1つの①の下の②は数件の想定なので、③を数えても重くならない（N-22 のように場全体の候補で数えるのとは違う）。
--   suggest_problems・suggest_books は v0.1 のまま（空の文字では0行）。
CREATE OR REPLACE FUNCTION public.suggest_measures(p_problem_id uuid, p_text text DEFAULT NULL)
RETURNS TABLE (o_measure_id uuid, o_name text, o_is_exact boolean)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  WITH q AS (SELECT app_private.norm(app_private.trim_text(coalesce(p_text, ''))) AS t),
  vm AS (   -- 見える②（RLS）
    SELECT me.id, me.name, me.created_at, app_private.norm(me.name) AS nname
    FROM public.measures me
    WHERE me.problem_id = p_problem_id
  ),
  agg AS (  -- 見える③（RLS）だけで、対策の一覧と同じ並びの材料を作る（[v0.4] X9: list_measures と同じ数え方に）
    SELECT vm.id AS mid,
           max(tr.score)::integer                                                   AS best_score,
           count(DISTINCT tr.household_id) FILTER (WHERE tr.status <> 'want')::integer AS hh_count,
           coalesce(max(tr.tried_on) FILTER (WHERE tr.status <> 'want'),
                    max(tr.tried_on) FILTER (WHERE tr.status = 'want'))             AS latest_on,
           count(tr.id)::integer                                                    AS n_trials,
           coalesce(bool_or(tr.status = 'scored'), false)                           AS has_score,
           coalesce(bool_or(tr.status = 'trying'), false)                           AS has_trying
    FROM vm
    LEFT JOIN public.trials tr ON tr.measure_id = vm.id
    GROUP BY vm.id
  )
  SELECT vm.id, vm.name, (q.t <> '' AND vm.nname = q.t)
  FROM vm
  JOIN agg ON agg.mid = vm.id
  CROSS JOIN q
  WHERE q.t = '' OR strpos(vm.nname, q.t) > 0
  ORDER BY
    (q.t <> '' AND vm.nname = q.t) DESC,                       -- 打ったとき: 完全一致
    (q.t <> '' AND strpos(vm.nname, q.t) = 1) DESC,            -- 打ったとき: 前方一致
    CASE WHEN q.t <> '' THEN char_length(vm.name) END,         -- 打ったとき: 短い名前
    CASE WHEN q.t <> '' THEN vm.name END,                      -- 打ったとき: 名前順
    CASE WHEN agg.n_trials = 0 THEN 3 WHEN agg.has_score THEN 0 WHEN agg.has_trying THEN 1 ELSE 2 END,   -- 以下、対策の一覧と同じ（[v0.4]）
    agg.best_score DESC NULLS LAST,
    agg.hh_count DESC,
    agg.latest_on DESC NULLS LAST,
    vm.created_at DESC,
    vm.id
  LIMIT 5
$$;

CREATE OR REPLACE FUNCTION public.suggest_books(p_space_id uuid, p_text text)
RETURNS TABLE (o_book_id uuid, o_title text, o_author text, o_is_exact boolean)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  WITH q AS (SELECT app_private.norm(app_private.trim_text(coalesce(p_text, ''))) AS t)
  SELECT bk.id, bk.title, bk.author, app_private.norm(bk.title) = q.t
  FROM public.books bk
  CROSS JOIN q
  WHERE bk.space_id = p_space_id
    AND q.t <> '' AND strpos(app_private.norm(bk.title), q.t) > 0
  ORDER BY (app_private.norm(bk.title) = q.t) DESC,
           (strpos(app_private.norm(bk.title), q.t) = 1) DESC,
           char_length(bk.title), bk.title, bk.id
  LIMIT 5
$$;

-- 5-5. 本を選ぶ／無ければ登録する（同じ場で題名と著者が完全に一致すれば同じ本。U-22）
CREATE OR REPLACE FUNCTION public.ensure_book(p_space_id uuid, p_title text, p_author text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_title   text := app_private.trim_text(coalesce(p_title, ''));
  v_author  text := nullif(app_private.trim_text(coalesce(p_author, '')), '');
  v_book_id uuid;
BEGIN
  SELECT bk.id INTO v_book_id
  FROM public.books bk
  WHERE bk.space_id = p_space_id
    AND bk.title = v_title
    AND coalesce(bk.author, '') = coalesce(v_author, '')
  LIMIT 1;
  IF v_book_id IS NULL THEN
    INSERT INTO public.books (space_id, title, author) VALUES (p_space_id, v_title, v_author)
    RETURNING id INTO v_book_id;
  END IF;
  RETURN v_book_id;
END;
$$;

-- 5-6. 書く（F-10。①→②→③を1回で。①②は既存を選ぶか新しく作る）
--   SECURITY INVOKER: 中の INSERT はすべて RLS とトリガーを通る（作れるのは見える①の下の②、見える②への③だけ）。
--   p_problem_id が NULL なら p_space_id の場に p_problem_name で①を作り、p_tag_ids を付ける（空なら「その他」）。
--   p_measure_id が NULL なら p_measure_name で②を作る。
--   本は先に ensure_book() で id を得て p_book_id に渡す。
--   戻り値: {"problem_id":…, "measure_id":…, "trial_id":…}
CREATE OR REPLACE FUNCTION public.save_trial(
  p_space_id     uuid,
  p_problem_id   uuid,
  p_problem_name text,
  p_tag_ids      uuid[],
  p_measure_id   uuid,
  p_measure_name text,
  p_score        smallint,
  p_age_months   smallint,
  p_source_type  text,
  p_book_id      uuid,
  p_source_url   text,
  p_heard_from   text,
  p_note         text,
  p_tried_on     date,
  p_visibility   text,
  -- [v0.4] X10: 後ろに足した（どれも省略可。省略すると v0.3 と同じ動き）
  p_problem_kind  text     DEFAULT NULL,   -- 新しく①を作るときの種類（'trouble'／'grow'。省略＝'trouble'）。既存の①を選んだときは使わない
  p_status        text     DEFAULT NULL,   -- 'scored'／'trying'／'want'。省略＝点数から決める（点数あり＝scored／空＝trying）
  p_age_months_to smallint DEFAULT NULL,   -- 年齢（まで）。省略＝1つの年齢
  p_source_text   text     DEFAULT NULL    -- テレビ・その他の詳細（40字）
)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_problem_id  uuid := p_problem_id;
  v_measure_id  uuid := p_measure_id;
  v_found_pid   uuid;
  v_found_space uuid;
  v_trial_id    uuid;
BEGIN
  IF v_measure_id IS NOT NULL THEN
    -- 既存の②を選んだ（「うちでも試した」を含む）。見えない②は無いのと同じ扱い。
    SELECT me.problem_id, me.space_id INTO v_found_pid, v_found_space
    FROM public.measures me WHERE me.id = v_measure_id;
    IF v_found_pid IS NULL THEN
      RAISE EXCEPTION 'not_visible' USING ERRCODE = '42501';
    END IF;
    IF (v_problem_id IS NOT NULL AND v_problem_id <> v_found_pid)
       OR (p_space_id IS NOT NULL AND p_space_id <> v_found_space) THEN
      RAISE EXCEPTION 'measure_problem_mismatch' USING ERRCODE = 'P0001';
    END IF;
    v_problem_id := v_found_pid;
  ELSE
    IF v_problem_id IS NULL THEN
      IF app_private.trim_text(coalesce(p_problem_name, '')) = '' THEN
        RAISE EXCEPTION 'problem_required' USING ERRCODE = 'P0001';
      END IF;
      -- [v0.3] W1（開発部 2026-09-30 修正1の取り込み）: RETURNING を使わず、ID を先に決めてから入れる。
      --   INSERT … RETURNING では、新しい行が SELECT のポリシー（problems_select_visible＝visible_problem_ids()）も
      --   満たす必要があるが、STABLE の関数は同じ文で入れたばかりの行を見られないため、必ず
      --   「new row violates row-level security policy」になっていた（[設計 6-1]。②も同じ）。
      --   次の文（set_problem_tags・②の INSERT）からは、入れた①が見える（文ごとに見え方が新しくなる）。
      v_problem_id := gen_random_uuid();
      INSERT INTO public.problems (id, space_id, name, kind)   -- [v0.4] X10: kind
      VALUES (v_problem_id, p_space_id, p_problem_name, coalesce(p_problem_kind, 'trouble'));
      IF coalesce(cardinality(p_tag_ids), 0) > 0 THEN
        PERFORM public.set_problem_tags(v_problem_id, p_tag_ids);
      END IF;
    END IF;
    IF app_private.trim_text(coalesce(p_measure_name, '')) = '' THEN
      RAISE EXCEPTION 'measure_required' USING ERRCODE = 'P0001';
    END IF;
    v_measure_id := gen_random_uuid();   -- [v0.3] W1（開発部 修正1）。理由は①と同じ（measures_select_visible）
    INSERT INTO public.measures (id, problem_id, name) VALUES (v_measure_id, v_problem_id, p_measure_name);
  END IF;

  -- ③は RETURNING のままでよい: trials の SELECT のポリシーは、入れる行の列（space_id・visibility・household_id）と
  --   members だけを見る関数で決まり、入れたばかりの行が見えるかに左右されない（[設計 6-1] の点検表）。

  INSERT INTO public.trials (
    measure_id, status, score, age_months, age_months_to, source_type, book_id, source_url, heard_from,
    source_text, note, tried_on, visibility
  ) VALUES (   -- [v0.4] X10: status・age_months_to・source_text（status が NULL ならトリガーが点数から決める）
    v_measure_id, p_status, p_score, p_age_months, p_age_months_to, coalesce(p_source_type, 'own'), p_book_id,
    p_source_url, p_heard_from, p_source_text, p_note, p_tried_on, coalesce(p_visibility, 'all')
  )
  RETURNING id INTO v_trial_id;

  RETURN jsonb_build_object('problem_id', v_problem_id, 'measure_id', v_measure_id, 'trial_id', v_trial_id);
END;
$$;

-- 5-7. ①②の名前を直す・タグを付け外す・消す（[要件 2-5] 案A の4）
--   判定は RLS のポリシー（can_edit_* / can_delete_*。見えない③も数える）で1回。返すのは true/false だけ。
--   できないとき、理由（見える他家庭の③か、見えない③か、③の件数、家庭）は返さない。
CREATE OR REPLACE FUNCTION public.rename_problem(p_problem_id uuid, p_name text)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.problems pr SET name = p_name WHERE pr.id = p_problem_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows = 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.rename_measure(p_measure_id uuid, p_name text)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.measures me SET name = p_name WHERE me.id = p_measure_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows = 1;
END;
$$;

-- [v0.4] X11: ①の種類を変える（[要件 4-1]「あとから変えるのは『名前を直す』と同じ条件」。D-1 の小窓で名前・タグと一緒に）。
--   判定は RLS の problems_update_editable（can_edit_problem。見えない③も数える）で1回。返すのは true/false だけ（2-5 案A）。
--   p_kind が 'trouble'／'grow' 以外なら 23514（画面の不具合）。
CREATE OR REPLACE FUNCTION public.set_problem_kind(p_problem_id uuid, p_kind text)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.problems pr SET kind = p_kind WHERE pr.id = p_problem_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows = 1;
END;
$$;

-- タグを「この組み合わせ」にする。空の配列なら「その他」だけになる（K-5）。
CREATE OR REPLACE FUNCTION public.set_problem_tags(p_problem_id uuid, p_tag_ids uuid[])
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_ids uuid[] := coalesce(p_tag_ids, '{}'::uuid[]);
BEGIN
  IF NOT app_private.can_edit_problem(p_problem_id) THEN
    RETURN false;
  END IF;
  -- 先に足してから外す（途中で0個になって「その他」が付き直すのを避ける）。
  INSERT INTO public.problem_tags (problem_id, tag_id)
  SELECT DISTINCT p_problem_id, x.tid
  FROM unnest(v_ids) AS x(tid)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.problem_tags pt2
    WHERE pt2.problem_id = p_problem_id AND pt2.tag_id = x.tid
  );
  DELETE FROM public.problem_tags pt3
  WHERE pt3.problem_id = p_problem_id
    AND NOT (pt3.tag_id = ANY (v_ids));
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_problem(p_problem_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  DELETE FROM public.problems pr WHERE pr.id = p_problem_id;  -- ③0件の②も CASCADE で消える（[要件 8-5]）
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows = 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_measure(p_measure_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  DELETE FROM public.measures me WHERE me.id = p_measure_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows = 1;
END;
$$;

-- [v0.2] V5: 本を消す（[要件 2-3]「使っている③が0件のときだけ」・2-5 と同じ扱い・C44）。
--   判定は RLS の books_delete_unused（can_delete_book。見えない③も数える）で1回。返すのは true/false だけ。
--   使っている③が見える③か見えない③かで、返事は変わらない。画面は false なら
--   「この本を使っている記録があるため、消せません。」を出す。ボタンは登録した人とその場の管理者に常に出す
--   （どちらも見えている情報で決まるので漏れない）。本を消す画面は MVP では作らない（N-23）が、関数は先に置く
--   （画面を足すときに表・RLS・関数を変えずに済む）。
CREATE OR REPLACE FUNCTION public.delete_book(p_book_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  DELETE FROM public.books bk WHERE bk.id = p_book_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows = 1;
END;
$$;

-- 5-8. 書き出し（F-30。その場で自分から見える分＝RLS を通した全部。メール・ログインの ID は含めない）
--   [v0.5] Y8: ③に書いた人（created_by_member_id・created_by_name）を足した（[設計 7-3]）。
CREATE OR REPLACE FUNCTION public.export_visible_data(p_space_id uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'exported_at', now(),
    'rules_version', public.current_rules_version(),
    'space', (SELECT jsonb_build_object('id', sp.id, 'name', sp.name) FROM public.spaces sp WHERE sp.id = p_space_id),
    'households', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', hh.id, 'display_name', hh.display_name) ORDER BY hh.created_at), '[]'::jsonb)
      FROM public.households hh WHERE hh.space_id = p_space_id),
    'members', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', mb.id, 'household_id', mb.household_id, 'display_name', mb.display_name) ORDER BY mb.created_at), '[]'::jsonb)
      FROM public.members mb WHERE mb.space_id = p_space_id),
    'tags', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', tg.id, 'name', tg.name, 'sort_order', tg.sort_order) ORDER BY tg.sort_order), '[]'::jsonb)
      FROM public.tags tg WHERE tg.space_id = p_space_id),
    'problems', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', pr.id, 'name', pr.name, 'kind', pr.kind, 'created_household_id', pr.created_household_id,   -- [v0.4] X12 kind
        'created_at', pr.created_at, 'updated_at', pr.updated_at,
        'tag_ids', (SELECT coalesce(jsonb_agg(pt.tag_id), '[]'::jsonb) FROM public.problem_tags pt WHERE pt.problem_id = pr.id)
      ) ORDER BY pr.created_at), '[]'::jsonb)
      FROM public.problems pr WHERE pr.space_id = p_space_id),
    'measures', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', me.id, 'problem_id', me.problem_id, 'name', me.name,
        'created_household_id', me.created_household_id, 'created_at', me.created_at, 'updated_at', me.updated_at
      ) ORDER BY me.created_at), '[]'::jsonb)
      FROM public.measures me WHERE me.space_id = p_space_id),
    'books', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', bk.id, 'title', bk.title, 'author', bk.author) ORDER BY bk.created_at), '[]'::jsonb)
      FROM public.books bk WHERE bk.space_id = p_space_id),
    'trials', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', tr.id, 'measure_id', tr.measure_id, 'household_id', tr.household_id,
        'status', tr.status, 'score', tr.score, 'age_months', tr.age_months, 'age_months_to', tr.age_months_to,   -- [v0.4] X12
        'source_type', tr.source_type,
        'book_id', tr.book_id, 'source_url', tr.source_url, 'heard_from', tr.heard_from, 'source_text', tr.source_text,
        'note', tr.note, 'tried_on', tr.tried_on, 'visibility', tr.visibility,
        'created_at', tr.created_at, 'updated_at', tr.updated_at,
        -- [v0.5] Y8（開発部の報告「招待の前に要る画面」7章の1）: 書いた人のメンバー ID と呼び名。書いた人が空なら null。
        --   呼び名は members の RLS（同じ場の全員が読める）を通して読むので、見え方の規則は変わらない（見える③の書いた人だけ）。
        'created_by_member_id', tr.created_by_member_id,
        'created_by_name', mbw.display_name
      ) ORDER BY tr.created_at), '[]'::jsonb)
      FROM public.trials tr
      LEFT JOIN public.members mbw ON mbw.id = tr.created_by_member_id
      WHERE tr.space_id = p_space_id)
  )
$$;

-- 5-9. 同意（F-03）
CREATE OR REPLACE FUNCTION public.has_agreed_current_rules()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT app_private.i_consented()
$$;

CREATE OR REPLACE FUNCTION public.record_rules_consent(p_version integer)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;
  IF p_version IS DISTINCT FROM public.current_rules_version() THEN
    RAISE EXCEPTION 'stale_version' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.consents (auth_user_id, consent_version)
  VALUES (v_uid, p_version)
  ON CONFLICT (auth_user_id, consent_version) DO NOTHING;
END;
$$;

-- 5-10. 招待コードの発行（その場の管理者。RLS の invites_insert_admin が守る）。コードはこの戻り値で1回だけ見える。
CREATE OR REPLACE FUNCTION public.create_invite(p_household_id uuid)
RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_code text := app_private.new_invite_code();
BEGIN
  INSERT INTO public.invites (household_id, code_hash)
  VALUES (p_household_id, app_private.hash_invite_code(v_code));
  RETURN v_code;
END;
$$;
-- 失効は画面から invites を直接 UPDATE（revoked_at = now()）。その場の管理者だけ（RLS）。

-- 5-11. 招待コードで参加（F-01）。まだその場のメンバーでない人が呼ぶので SECURITY DEFINER。
--   戻り値: 'joined' ／ 'invalid'（違う・使用済み・期限切れ・失効を区別しない）／ 'locked'（1時間に5回失敗）
--          ／ 'full'（メンバーの上限）／ 'already_member'（その場にもう入っている）
CREATE OR REPLACE FUNCTION public.join_with_invite_code(p_code text, p_display_name text)
RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_uid           uuid := auth.uid();
  v_fail_count    integer;
  v_invite_id     uuid;
  v_space_id      uuid;
  v_household_id  uuid;
  v_max           integer;
  v_member_count  integer;
  v_new_member_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_fail_count
  FROM public.invite_attempts ia
  WHERE ia.auth_user_id = v_uid
    AND NOT ia.succeeded
    AND ia.attempted_at > now() - interval '1 hour';
  IF v_fail_count >= 5 THEN
    RETURN 'locked';
  END IF;

  SELECT iv.id, iv.space_id, iv.household_id
    INTO v_invite_id, v_space_id, v_household_id
  FROM public.invites iv
  WHERE iv.code_hash = app_private.hash_invite_code(p_code)
    AND iv.used_at IS NULL
    AND iv.revoked_at IS NULL
    AND iv.expires_at > now()
  FOR UPDATE;

  IF v_invite_id IS NULL THEN
    INSERT INTO public.invite_attempts (auth_user_id, succeeded) VALUES (v_uid, false);
    RETURN 'invalid';
  END IF;

  IF EXISTS (SELECT 1 FROM public.members mb WHERE mb.auth_user_id = v_uid AND mb.space_id = v_space_id) THEN
    RETURN 'already_member';   -- コードは使わずに残す
  END IF;

  SELECT sp.max_members INTO v_max FROM public.spaces sp WHERE sp.id = v_space_id;
  SELECT count(*) INTO v_member_count FROM public.members mb WHERE mb.space_id = v_space_id;
  IF v_member_count >= v_max THEN
    RETURN 'full';
  END IF;

  INSERT INTO public.members (space_id, household_id, auth_user_id, display_name, role)
  VALUES (v_space_id, v_household_id, v_uid, p_display_name, 'member')
  RETURNING id INTO v_new_member_id;

  UPDATE public.invites iv
     SET used_at = now(), used_by_member_id = v_new_member_id
   WHERE iv.id = v_invite_id;

  INSERT INTO public.invite_attempts (auth_user_id, succeeded) VALUES (v_uid, true);
  RETURN 'joined';
END;
$$;

-- 5-12. 家庭を消す前の確認（[要件 8-5]「消える③の件数を表示」）。その場の管理者だけに行が返る。
--   件数には、その家庭の「自分の家庭だけ」の③も含まれる（中身は返さない。[設計 15] Z9）。
CREATE OR REPLACE FUNCTION public.household_deletion_preview(p_household_id uuid)
RETURNS TABLE (o_trial_count integer, o_member_count integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT
    (SELECT count(*)::integer FROM public.trials tr WHERE tr.household_id = hh.id),
    (SELECT count(*)::integer FROM public.members mb WHERE mb.household_id = hh.id)
  FROM public.households hh
  WHERE hh.id = p_household_id
    AND app_private.is_admin_of(hh.space_id)
$$;


-- ============================================================
-- 6. service_role だけが呼べる関数（[設計 7]。Edge Function から呼ぶ／運営者が SQL エディタで使う）
--   ログイン情報（auth.users）の削除は、この後に Edge Function が auth.admin.deleteUser() で行う。
--   戻り値の auth_user_id は「**もうどの場にも入っていない**ログイン」だけ（他の場に残る人のログインは消さない）。
--   p_actor_auth_uid は、Edge Function が「送られてきたログインの証明（JWT）」から取り出した本人の ID。
-- ============================================================

-- 6-0. [v0.5] Y2: 最初のタグ（[要件 4-5]。困りごと9・育てたい13・両方2＝24個。育てたいの15個〈両方2を含む〉は統括が A17 で確定した案＝2026-09-30）。
--   場を作る関数（bootstrap_space）から呼ぶ。**すでにある場の移し替えにも同じ関数を使う**（運営者・開発部が SQL で
--   select app_private.seed_default_tags(sp.id) from public.spaces sp; ＝[設計 14-4]）。何度呼んでも同じ結果（冪等）:
--     ・同じ名前のタグがまだ無ければ入れる（あれば入れない。管理者が同じ名前を足していたら、そのタグをそのまま使う）
--     ・「ことば」「その他」が困りごとなら、両方にして育てたいの並びを付ける
--   A17 の答えで最初のタグが変わったら、この関数の VALUES だけを直す（表は変わらない）。
--   呼んだ人の権限で動く（SECURITY INVOKER）。画面からは呼べない（app_private は Data API に出ない。7章で authenticated から外す）。
CREATE OR REPLACE FUNCTION app_private.seed_default_tags(p_space_id uuid)
RETURNS void LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  INSERT INTO public.tags (space_id, name, kind, sort_order, grow_sort_order, is_other)
  SELECT p_space_id, x.tname, x.tkind, x.ord, x.gord, x.tname = 'その他'
  FROM (VALUES
    -- 困りごと（sort_order＝困りごとの並び・［すべて］の並び）
    ('寝る', 'trouble', 1, NULL::integer), ('食べる', 'trouble', 2, NULL), ('トイレ', 'trouble', 3, NULL),
    ('着替え・身支度', 'trouble', 4, NULL), ('ことば', 'both', 5, 7), ('気持ち・かんしゃく', 'trouble', 6, NULL),
    ('きょうだい', 'trouble', 7, NULL), ('友だち・園・学校', 'trouble', 8, NULL), ('スマホ・テレビ', 'trouble', 9, NULL),
    ('外出', 'trouble', 10, NULL),
    -- 育てたい（grow_sort_order＝育てたいの並び。「ことば」は7番目。統括が A17 で確定＝2026-09-30）
    ('自己肯定感', 'grow', 101, 1), ('やり抜く力', 'grow', 102, 2), ('集中力', 'grow', 103, 3),
    ('考える力', 'grow', 104, 4), ('好奇心', 'grow', 105, 5), ('自制心', 'grow', 106, 6),
    ('運動', 'grow', 108, 8), ('勉強', 'grow', 109, 9), ('料理', 'grow', 110, 10),
    ('思いやり', 'grow', 111, 11), ('人との関わり', 'grow', 112, 12), ('気持ちの整理', 'grow', 113, 13),
    ('自分でする力', 'grow', 114, 14),
    -- 両方・最後
    ('その他', 'both', 1000, 1000)
  ) AS x(tname, tkind, ord, gord)
  WHERE NOT EXISTS (SELECT 1 FROM public.tags t0 WHERE t0.space_id = p_space_id AND t0.name = x.tname);

  UPDATE public.tags tg
     SET kind = 'both', grow_sort_order = d.gord
    FROM (VALUES ('ことば', 7), ('その他', 1000)) AS d(tname, gord)
   WHERE tg.space_id = p_space_id AND tg.name = d.tname AND tg.kind <> 'both';
$$;

-- 6-1. 場を作る（MVP は運営者が SQL エディタで実行。一般公開では画面から作れる関数を別に足す。[設計 18]）
CREATE OR REPLACE FUNCTION public.bootstrap_space(
  p_admin_auth_uid      uuid,
  p_space_name          text,
  p_household_name      text,
  p_admin_display_name  text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_space_id     uuid;
  v_household_id uuid;
BEGIN
  INSERT INTO public.spaces (name) VALUES (p_space_name) RETURNING id INTO v_space_id;
  INSERT INTO public.households (space_id, display_name) VALUES (v_space_id, p_household_name)
  RETURNING id INTO v_household_id;
  INSERT INTO public.members (space_id, household_id, auth_user_id, display_name, role)
  VALUES (v_space_id, v_household_id, p_admin_auth_uid, p_admin_display_name, 'admin');
  -- [v0.5] Y2: 最初のタグ24個を入れる（v0.4 までの11個から。中身は app_private.seed_default_tags）。
  PERFORM app_private.seed_default_tags(v_space_id);
  RETURN v_space_id;
END;
$$;

-- 6-2. メンバーの退会（本人）・削除（その場の管理者）。[要件 8-5]
--   p_delete_trials = true: その人が書いた③を消す ／ false: 家庭の記録として残す（書いた人は空になる）。
--   [v0.2] V4: p_delete_trials を省略（NULL）したときの既定は、[要件 8-5]・C41 のとおり
--     「本人の退会＝消す（true）」「管理者が他のメンバーを外す＝残す（false）」。
--     画面は選んだ値を必ず送る（既定値は画面の初期の選択と同じ）。省略時の既定をここに持つのは、
--     Edge Function や運営者の手作業で渡し忘れたときも要件の既定になるようにするため（消すと戻せない）。
--   ①②は共有物なので残す（作った人は空になる）。管理者は退会できない（先に場の削除。U-18）。
--   戻り値: そのログインがもうどの場にも入っていなければ auth_user_id、まだ他の場に入っていれば NULL。
CREATE OR REPLACE FUNCTION public.delete_member_data(
  p_actor_auth_uid uuid,
  p_member_id      uuid,
  p_delete_trials  boolean DEFAULT NULL   -- [v0.2] V4
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_target_space    uuid;
  v_target_role     text;
  v_target_auth_uid uuid;
  v_actor_id        uuid;
  v_actor_role      text;
  v_delete_trials   boolean;   -- [v0.2] V4
BEGIN
  SELECT mb.space_id, mb.role, mb.auth_user_id INTO v_target_space, v_target_role, v_target_auth_uid
  FROM public.members mb WHERE mb.id = p_member_id;
  IF v_target_auth_uid IS NULL THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0001';
  END IF;

  SELECT mb.id, mb.role INTO v_actor_id, v_actor_role
  FROM public.members mb
  WHERE mb.auth_user_id = p_actor_auth_uid AND mb.space_id = v_target_space;
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0001';   -- 別の場の人からは「無い」と同じに見せる
  END IF;
  IF v_target_role = 'admin' THEN
    RAISE EXCEPTION 'admin_cannot_leave' USING ERRCODE = 'P0001';
  END IF;
  IF p_member_id <> v_actor_id AND v_actor_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  -- [v0.2] V4: 省略時は「本人なら消す・管理者が外すなら残す」
  v_delete_trials := coalesce(p_delete_trials, p_member_id = v_actor_id);
  IF v_delete_trials THEN
    DELETE FROM public.trials tr WHERE tr.created_by_member_id = p_member_id;
  END IF;
  DELETE FROM public.members mb WHERE mb.id = p_member_id;

  IF EXISTS (SELECT 1 FROM public.members mb2 WHERE mb2.auth_user_id = v_target_auth_uid) THEN
    RETURN NULL;
  END IF;
  RETURN v_target_auth_uid;
END;
$$;

-- 6-3. 家庭の削除（その場の管理者）。[要件 8-5]
--   その家庭のメンバー・③（非公開を含む）・招待を消す。その家庭が作った①②は、
--   他家庭の③が付いていれば残し（作った家庭は空＝「退会した家庭」。以後はその場の管理者だけが直せる）、
--   ③が0件なら消す。管理者の家庭は消せない。
--   戻り値: 消したメンバーのうち、もうどの場にも入っていないログインの auth_user_id の配列。
CREATE OR REPLACE FUNCTION public.delete_household_data(
  p_actor_auth_uid uuid,
  p_household_id   uuid
)
RETURNS uuid[]
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_target_space    uuid;
  v_actor_household uuid;
  v_actor_role      text;
  v_auth_uids       uuid[];
  v_problem_ids     uuid[];
  v_measure_ids     uuid[];
BEGIN
  SELECT hh.space_id INTO v_target_space FROM public.households hh WHERE hh.id = p_household_id;
  IF v_target_space IS NULL THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0001';
  END IF;
  SELECT mb.household_id, mb.role INTO v_actor_household, v_actor_role
  FROM public.members mb
  WHERE mb.auth_user_id = p_actor_auth_uid AND mb.space_id = v_target_space;
  IF v_actor_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_household_id = v_actor_household THEN
    RAISE EXCEPTION 'cannot_delete_own_household' USING ERRCODE = 'P0001';
  END IF;

  SELECT coalesce(array_agg(mb.auth_user_id), '{}'::uuid[]) INTO v_auth_uids
  FROM public.members mb WHERE mb.household_id = p_household_id;
  SELECT coalesce(array_agg(pr.id), '{}'::uuid[]) INTO v_problem_ids
  FROM public.problems pr WHERE pr.created_household_id = p_household_id;
  SELECT coalesce(array_agg(me.id), '{}'::uuid[]) INTO v_measure_ids
  FROM public.measures me WHERE me.created_household_id = p_household_id;

  -- 家庭を消すと、その家庭の③・メンバー・招待が CASCADE で消え、①②の created_household_id は空になる。
  DELETE FROM public.households hh WHERE hh.id = p_household_id;

  -- その家庭が作った②のうち、③が0件になったものを消す。
  DELETE FROM public.measures me
  WHERE me.id = ANY (v_measure_ids)
    AND NOT EXISTS (SELECT 1 FROM public.trials tr WHERE tr.measure_id = me.id);
  -- その家庭が作った①のうち、③が0件になったものを消す（下の③0件の②も CASCADE で消える）。
  DELETE FROM public.problems pr
  WHERE pr.id = ANY (v_problem_ids)
    AND NOT EXISTS (
      SELECT 1 FROM public.measures me2
      JOIN public.trials tr2 ON tr2.measure_id = me2.id
      WHERE me2.problem_id = pr.id
    );

  RETURN ARRAY(
    SELECT u.uid FROM unnest(v_auth_uids) AS u(uid)
    WHERE NOT EXISTS (SELECT 1 FROM public.members mb3 WHERE mb3.auth_user_id = u.uid)
  );
END;
$$;

-- 6-4. 場の削除（その場の管理者。P1。当面は運営者の手作業でも可）。
--   戻り値: その場のメンバーのうち、もうどの場にも入っていないログインの auth_user_id の配列。
CREATE OR REPLACE FUNCTION public.delete_space_data(
  p_actor_auth_uid uuid,
  p_space_id       uuid
)
RETURNS uuid[]
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_auth_uids uuid[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.members mb
    WHERE mb.auth_user_id = p_actor_auth_uid AND mb.space_id = p_space_id AND mb.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  SELECT coalesce(array_agg(mb.auth_user_id), '{}'::uuid[]) INTO v_auth_uids
  FROM public.members mb WHERE mb.space_id = p_space_id;
  -- 場を消すと、家庭・メンバー・招待・タグ・①②③・本がすべて CASCADE で消える。
  DELETE FROM public.spaces sp WHERE sp.id = p_space_id;
  RETURN ARRAY(
    SELECT u.uid FROM unnest(v_auth_uids) AS u(uid)
    WHERE NOT EXISTS (SELECT 1 FROM public.members mb3 WHERE mb3.auth_user_id = u.uid)
  );
END;
$$;


-- ============================================================
-- 7. 関数の実行権限（[設計 3-6]）
--   PostgreSQL は関数を作ると PUBLIC に実行権限を付け、Supabase は anon にも付ける。すべて外してから付け直す。
-- ============================================================
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA app_private FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app_private TO authenticated, service_role;
-- [v0.5] Y2: 最初のタグを入れる関数は、ログインした人の権限では使わせない（場を作る関数・運営者だけ）。
REVOKE ALL ON FUNCTION app_private.seed_default_tags(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.seed_default_tags(uuid) TO service_role;

-- 画面から呼ぶ関数（ログインした人だけ）
REVOKE ALL ON FUNCTION public.current_rules_version() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_my_spaces() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.search_problems(uuid, text, uuid, integer, integer, integer, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_age_counts(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_problem_kind(uuid, text) FROM PUBLIC, anon;                        -- [v0.4] X11
REVOKE ALL ON FUNCTION public.list_measures(uuid, text, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.suggest_problems(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.suggest_measures(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.suggest_books(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ensure_book(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_trial(uuid, uuid, text, uuid[], uuid, text, smallint, smallint, text, uuid, text, text, text, date, text, text, text, smallint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rename_problem(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rename_measure(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_problem_tags(uuid, uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_problem(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_measure(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_book(uuid) FROM PUBLIC, anon;   -- [v0.2] V5
REVOKE ALL ON FUNCTION public.export_visible_data(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_agreed_current_rules() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.record_rules_consent(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_invite(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_with_invite_code(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.household_deletion_preview(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.current_rules_version() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.list_my_spaces() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_problems(uuid, text, uuid, integer, integer, integer, text, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.list_age_counts(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_problem_kind(uuid, text) TO authenticated, service_role;                        -- [v0.4] X11
GRANT EXECUTE ON FUNCTION public.list_measures(uuid, text, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.suggest_problems(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.suggest_measures(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.suggest_books(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ensure_book(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_trial(uuid, uuid, text, uuid[], uuid, text, smallint, smallint, text, uuid, text, text, text, date, text, text, text, smallint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rename_problem(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rename_measure(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_problem_tags(uuid, uuid[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_problem(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_measure(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_book(uuid) TO authenticated, service_role;   -- [v0.2] V5
GRANT EXECUTE ON FUNCTION public.export_visible_data(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_agreed_current_rules() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_rules_consent(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_invite(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_with_invite_code(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.household_deletion_preview(uuid) TO authenticated, service_role;

-- service_role だけ（画面からは呼べない）
REVOKE ALL ON FUNCTION public.bootstrap_space(uuid, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.delete_member_data(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.delete_household_data(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.delete_space_data(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_space(uuid, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_member_data(uuid, uuid, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_household_data(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_space_data(uuid, uuid) TO service_role;


-- ============================================================
-- 8. 提出前の自己確認（列名衝突。設計部/CLAUDE.md。結果の表は [設計 14-3]）
--   [v0.2] 変えた関数について、2026-09-30 にやり直した（下の「v0.2 で変えた関数」）。
--   - RETURNS TABLE を持つ関数は8つ（list_my_spaces / search_problems / list_age_counts / list_measures /
--     suggest_problems / suggest_measures / suggest_books / household_deletion_preview。すべて LANGUAGE sql）。
--     出力列はすべて o_ で始まり、どの表にも o_ で始まる列は無い → 衝突なし。
--   - PL/pgSQL の関数（トリガー12・RPC 11〈v0.2 で delete_book を追加〉・service_role 4・app_private 2）の
--     引数は p_、変数は v_ で始まり、どの表にも p_ / v_ で始まる列は無い → 衝突なし。
--     本文の列参照はすべて「別名.列名」か NEW./OLD.。
--     例外として別名を付けられない位置: INSERT の列の並び（INSERT INTO t (col, …)）・UPDATE の SET の左辺・
--     RETURNING id・ON CONFLICT (…)。前の3つは同じ名前の変数・引数が無いので曖昧にならない。
--     ON CONFLICT は record_rules_consent の1か所だけで、#variable_conflict use_column を宣言部に置いた。
--   - v0.2 で変えた関数（1つずつ確認）:
--       list_my_spaces（sql）: 出力列を2つ足した（o_admin_member_id・o_admin_display_name）。o_ 始まり。
--         本文は mb・sp・hh・ad の別名つきだけ。同じ表 members を2回使うので、別名 mb と ad で分けた。
--       list_measures（sql）: 本文に足したのは t2.age_months と引数 p_age_years だけ（別名つき・p_ 始まり）。
--         jsonb のキー 'in_age' は列ではない。出力列は変えていない。
--       suggest_measures（sql）: CTE の列（id, name, created_at, nname, mid, best_score, hh_count, latest_on,
--         n_trials, has_score, t）は、すべて vm. / agg. / q. / tr. / me. の別名つきで参照。出力列は変えていない。
--         引数 p_text に DEFAULT NULL を足した（型の並び (uuid, text) は同じなので GRANT の書き方も同じ）。
--       delete_member_data（plpgsql）: 変数 v_delete_trials を足した。表に同じ名前の列は無い。
--         引数 p_delete_trials に DEFAULT NULL を足した（型の並び (uuid, uuid, boolean) は同じ）。
--       delete_book（plpgsql・新設）: 引数 p_book_id・変数 v_rows。本文は「DELETE FROM public.books bk
--         WHERE bk.id = p_book_id」だけ。RETURNS TABLE ではない。
--       トリガー7つ（households / members / invites / problems / measures / books / trials の before_write）:
--         足したのは「NEW.id IS DISTINCT FROM OLD.id」だけ（NEW./OLD. つき）。
--   - GRANT: 新しい表は無い（12の表のまま。GRANT・REVOKE は v0.1 のとおり）。
--     新しい関数 delete_book は、PUBLIC と anon から外して authenticated・service_role に付けた（7章）。
--   - [v0.3] 変えた関数（1つずつ確認。2026-09-30）:
--       save_trial（plpgsql）: 足したのは「v_problem_id := gen_random_uuid()」「v_measure_id := gen_random_uuid()」と、
--         INSERT の列の並びの id（別名を付けられない位置）。引数・変数に id という名前は無いので曖昧にならない。
--         RETURNS jsonb（表ではない）。引数の型の並びは同じなので GRANT の書き方も同じ。
--       households_before_write（plpgsql・トリガー）: 足したのは current_user と
--         app_private.is_admin_of(NEW.space_id) の判定だけ（NEW. つき）。
--       list_my_spaces（sql）: ORDER BY を mb.created_at, sp.id に（別名つき）。出力列は変えていない。
--   - [v0.3] W5 もう1つの点検（RETURNING と見える一覧の関数。[設計 6-1]・[設計 14-3]）:
--       「INSERT … RETURNING」「INSERT … ON CONFLICT」「画面の .insert().select()／.upsert()」は、
--       その表の SELECT のポリシーが**入れる行そのものを数える STABLE の関数**（visible_problem_ids()・
--       visible_measure_ids()）で決まるとき、必ず RLS の拒否になる。該当するのは problems と measures の2表だけ。
--   - [v0.5] 変えた・足した関数（1つずつ確認。2026-09-30。表に足した列 kind・grow_sort_order は p_／v_／o_ で始まらない）:
--       tags_before_insert（plpgsql・トリガー）: 変数 v_max_order・v_max_grow。本文は NEW. と tg. の別名つき。
--       problem_tags_before_insert（plpgsql・トリガー）: 変数 v_problem_kind・v_tag_kind を足した。pr.／tg. の別名つき。
--       problems_after_update_kind（plpgsql・トリガー・新設）: DELETE … pt USING … tg。pt.／tg.／NEW. つきだけ。
--       seed_default_tags（sql・新設）: INSERT の列の並び・UPDATE の SET の左辺（kind・grow_sort_order。別名を付けられない位置）
--         と同じ名前の引数は無い（引数は p_space_id）。本文の参照は x.／t0.／tg.／d. の別名つき。ON CONFLICT は使わない
--         （NOT EXISTS で入れる。#variable_conflict の心配が無い）。RETURNING も使わない。
--       bootstrap_space（plpgsql）: タグの INSERT を seed_default_tags の呼び出しに置き換えただけ。
--       list_age_band_counts は消した（v0.4 の確認は不要になった）。
--       export_visible_data（sql）: trials に LEFT JOIN members mbw を足しただけ（tr.／mbw. の別名つき。jsonb のキーは列ではない）。
--   - [v0.4] 変えた・足した関数（1つずつ確認。2026-09-30。表に足した列 kind・status・age_months_to・source_text は
--     どれも p_／v_／o_ で始まらない）:
--       search_problems（sql）: 出力に o_kind、引数に p_kind・p_age_years_to。本文は vp.／vm.／vt.／hit.／pt.／tg. の別名つき。
--       list_age_counts（sql）: generate_series の列は gs.y（別名つき）。出力列 o_age_years・o_problem_count は変えていない。
--       list_age_band_counts（sql・新設）: CTE の列 fy・ty・ord・pid・af・at は bd.／bx.／tp. の別名つき。出力は o_ 始まり。
--       list_measures（sql）: CTE の列（status・in_age・has_trying・latest_want_on など）は vt.／t2.／agg. の別名つき。
--         足した JOIN の別名 mb・hh。出力列は変えていない（o_trials の jsonb のキーは列ではない）。
--       suggest_problems（sql）: 出力に o_kind。本文は pr.／q. の別名つき。
--       suggest_measures（sql）: agg の列を足しただけ（tr.／agg. の別名つき）。
--       save_trial（plpgsql）: 引数を後ろに4つ（p_ 始まり）。INSERT の列の並びに kind・status・age_months_to・source_text
--         （別名を付けられない位置。同じ名前の引数・変数は無い）。
--       set_problem_kind（plpgsql・新設）: 引数 p_problem_id・p_kind、変数 v_rows。本文は pr. の別名つき。
--         SET の左辺 kind は別名を付けられない位置だが、同じ名前の引数・変数は無い（引数は p_kind）。
--       trials_before_write（plpgsql・トリガー）: 足したのは NEW.／OLD. つきの参照と app_private.today_jst() だけ。
--       app_private.age_overlaps（sql・新設）: 引数だけ（表を読まない）。
--     RETURNING・ON CONFLICT は増えていない（set_problem_kind は RETURNING を使わない。W5 の点検のまま）。
--       v0.2 にあった RETURNING・ON CONFLICT の8か所をすべて点検し、この形のものは save_trial の①②（W1 で直した）
--       だけだった（v0.3 では残り6か所）。残り（save_trial の③・ensure_book の本・join_with_invite_code／bootstrap_space の
--       members・spaces・households、record_rules_consent の ON CONFLICT）は、SELECT のポリシーが列か
--       members だけで決まる表、または持ち主の権限（RLS を通らない）の関数なので通る。
-- ============================================================
