-- ============================================================
-- 設計書 12-6節のうち: 権限の定義 TG-1〜TG-5
--   TG-1 anon は12の表を読めない／TG-2 anon は public の関数を呼べない／
--   TG-3 authenticated は service_role 用の関数を呼べない／TG-4 全表で RLS が有効／
--   TG-5 ポリシーの数と名前が設計書 3-2節の対応表と一致（おやこポイントの「定義のスナップショット」と同じ考え方）
--   ポリシーや関数を足した・消したときは、先に設計書を直してから、このファイルの一覧を直す（FAIL を消すためだけに直さない）。
-- ============================================================
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(24);
SELECT test_fx.build();

-- TG-1: anon で12の表を SELECT → すべて権限エラー
SELECT test_fx.as_anon();
SELECT throws_ok('SELECT 1 FROM public.spaces LIMIT 1',          '42501', NULL, 'TG-1: anon は spaces を読めない');
SELECT throws_ok('SELECT 1 FROM public.households LIMIT 1',      '42501', NULL, 'TG-1: anon は households を読めない');
SELECT throws_ok('SELECT 1 FROM public.members LIMIT 1',         '42501', NULL, 'TG-1: anon は members を読めない');
SELECT throws_ok('SELECT 1 FROM public.consents LIMIT 1',        '42501', NULL, 'TG-1: anon は consents を読めない');
SELECT throws_ok('SELECT 1 FROM public.invites LIMIT 1',         '42501', NULL, 'TG-1: anon は invites を読めない');
SELECT throws_ok('SELECT 1 FROM public.invite_attempts LIMIT 1', '42501', NULL, 'TG-1: anon は invite_attempts を読めない');
SELECT throws_ok('SELECT 1 FROM public.tags LIMIT 1',            '42501', NULL, 'TG-1: anon は tags を読めない');
SELECT throws_ok('SELECT 1 FROM public.problems LIMIT 1',        '42501', NULL, 'TG-1: anon は problems を読めない');
SELECT throws_ok('SELECT 1 FROM public.problem_tags LIMIT 1',    '42501', NULL, 'TG-1: anon は problem_tags を読めない');
SELECT throws_ok('SELECT 1 FROM public.measures LIMIT 1',        '42501', NULL, 'TG-1: anon は measures を読めない');
SELECT throws_ok('SELECT 1 FROM public.books LIMIT 1',           '42501', NULL, 'TG-1: anon は books を読めない');
SELECT throws_ok('SELECT 1 FROM public.trials LIMIT 1',          '42501', NULL, 'TG-1: anon は trials を読めない');

-- TG-2: anon で public の関数を呼ぶ → すべて権限エラー（v0.2 の delete_book を含む）
SELECT is(test_fx.callable_functions(), '{}'::text[], 'TG-2: anon は public の関数をどれも呼べない（全関数を NULL の引数で呼んで確かめた）');
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(p.proname ORDER BY p.proname) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'app_private' AND has_function_privilege('anon', p.oid, 'EXECUTE')), NULL::name[],
  'TG-2（補い）: anon は app_private の関数も実行できない');
SELECT is(has_schema_privilege('anon', 'app_private', 'USAGE'), false, 'TG-2（補い）: anon は app_private スキーマを使えない');
SELECT functions_are('public', ARRAY[
  'current_rules_version', 'list_my_spaces', 'search_problems', 'list_age_counts', 'list_measures',
  'suggest_problems', 'suggest_measures', 'suggest_books', 'ensure_book', 'save_trial',
  'rename_problem', 'rename_measure', 'set_problem_tags', 'delete_problem', 'delete_measure', 'delete_book',
  'export_visible_data', 'has_agreed_current_rules', 'record_rules_consent', 'create_invite',
  'join_with_invite_code', 'household_deletion_preview', 'set_problem_kind',
  'bootstrap_space', 'delete_member_data', 'delete_household_data', 'delete_space_data'],
  'TG-2（補い）: public の関数は設計書 14-2節・SQL 7章の28個だけ（v0.4 で2つ増えた）');
SELECT is((SELECT array_agg(f ORDER BY f) FROM unnest(ARRAY[
  'current_rules_version', 'list_my_spaces', 'search_problems', 'list_age_counts', 'list_measures',
  'suggest_problems', 'suggest_measures', 'suggest_books', 'ensure_book', 'save_trial',
  'rename_problem', 'rename_measure', 'set_problem_tags', 'delete_problem', 'delete_measure', 'delete_book',
  'export_visible_data', 'has_agreed_current_rules', 'record_rules_consent', 'create_invite',
  'join_with_invite_code', 'household_deletion_preview', 'set_problem_kind']) f
  WHERE NOT has_function_privilege('authenticated', (SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                                     WHERE n.nspname = 'public' AND p.proname = f), 'EXECUTE')), NULL::text[],
  'TG-2（補い）: 画面から呼ぶ24の関数は、authenticated がすべて実行できる（権限を外しすぎていない）');

-- TG-3: authenticated で bootstrap_space・delete_*_data → 権限エラー
SELECT test_fx.as_user('u0a');
SELECT is(test_fx.callable_functions(ARRAY['bootstrap_space', 'delete_member_data', 'delete_household_data', 'delete_space_data']),
  '{}'::text[], 'TG-3: 管理者でも authenticated は bootstrap_space・delete_member_data・delete_household_data・delete_space_data を呼べない');
SELECT throws_ok(format($$SELECT public.delete_member_data(%L, %L, true)$$, test_fx.uid('u0a'), test_fx.id('m_b1')), '42501', NULL,
  'TG-3: 実際の引数でも delete_member_data は権限エラー');

-- TG-4: 全表で RLS が有効
SELECT test_fx.as_owner();
SELECT is((SELECT array_agg(c.relname::text ORDER BY c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity),
  ARRAY['books', 'consents', 'households', 'invite_attempts', 'invites', 'measures', 'members', 'problem_tags',
        'problems', 'spaces', 'tags', 'trials'],
  'TG-4: public の12の表すべてで RLS が有効');
SELECT tables_are('public', ARRAY['books', 'consents', 'households', 'invite_attempts', 'invites', 'measures', 'members',
                                  'problem_tags', 'problems', 'spaces', 'tags', 'trials'],
  'TG-4（補い）: public の表は12個だけ（RLS の無い表が増えていない）');

-- TG-5: ポリシーの数と名前（設計書 3-2節・SQL 4章。31個。v0.2 で増減なし）
SELECT is((SELECT count(*)::int FROM pg_policies WHERE schemaname = 'public'), 31, 'TG-5: ポリシーは31個');
SELECT is((SELECT array_agg(tablename || '.' || policyname || ':' || cmd ORDER BY tablename, policyname) FROM pg_policies WHERE schemaname = 'public'),
  ARRAY[
    'books.books_delete_unused:DELETE',
    'books.books_insert_member:INSERT',
    'books.books_select_same_space:SELECT',
    'books.books_update_admin_or_registrant:UPDATE',
    'consents.consents_select_own_or_admin:SELECT',
    'households.households_insert_admin:INSERT',
    'households.households_select_same_space:SELECT',
    'households.households_update_admin:UPDATE',
    'invites.invites_insert_admin:INSERT',
    'invites.invites_select_admin:SELECT',
    'invites.invites_update_admin:UPDATE',
    'measures.measures_delete_deletable:DELETE',
    'measures.measures_insert_under_visible_problem:INSERT',
    'measures.measures_select_visible:SELECT',
    'measures.measures_update_editable:UPDATE',
    'members.members_select_same_space:SELECT',
    'members.members_update_self:UPDATE',
    'problem_tags.problem_tags_delete_editable:DELETE',
    'problem_tags.problem_tags_insert_editable:INSERT',
    'problem_tags.problem_tags_select_visible:SELECT',
    'problems.problems_delete_deletable:DELETE',
    'problems.problems_insert_own_household:INSERT',
    'problems.problems_select_visible:SELECT',
    'problems.problems_update_editable:UPDATE',
    'spaces.spaces_select_member:SELECT',
    'tags.tags_insert_admin:INSERT',
    'tags.tags_select_same_space:SELECT',
    'trials.trials_delete_own_or_admin_public:DELETE',
    'trials.trials_insert_own_household:INSERT',
    'trials.trials_select_visible:SELECT',
    'trials.trials_update_own_household:UPDATE'
  ], 'TG-5: ポリシーの名前と操作が設計書の対応表と一致');
SELECT is((SELECT array_agg(DISTINCT r) FROM pg_policies, unnest(roles) r WHERE schemaname = 'public'), ARRAY['authenticated']::name[],
  'TG-5（補い）: どのポリシーも authenticated だけに向いている（anon 向けのポリシーが無い）');

SELECT * FROM finish();
ROLLBACK;
