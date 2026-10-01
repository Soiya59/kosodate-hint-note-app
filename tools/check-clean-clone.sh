#!/usr/bin/env bash
# push の前の確かめ（2026-10-01 開発部）: いまのコミットを「きれいな複製」に取り出し、Actions と同じ順で流す。
#   手元の node_modules は昔の install の残りで、きれいな状態の npm ci の失敗（ERESOLVE）に気づけないことがある
#   （2026-10-01 の1回目の Actions の失敗）。push の前にこれを流す。
# 使い方（Git Bash。プログラムの置き場所で）: bash tools/check-clean-clone.sh [--db]
#   --db を付けると、使い捨てのローカルの Supabase（別のプロジェクト名・別のポート）で権限表の自動テストも流す。
#   統括のローカルの DB（kosodate-hint-note-app のコンテナ）には触らない。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone -q "$ROOT" "$WORK/repo"
cd "$WORK/repo"
echo "== npm ci";              npm ci --no-audit --no-fund
echo "== npm ci (tools/lint)"; npm ci --prefix tools/lint --no-audit --no-fund
echo "== lint";                npm run lint
echo "== tsc";                 npx tsc --noEmit
if [ "${1:-}" = "--db" ]; then
  sed -i 's/^project_id = "kosodate-hint-note-app"/project_id = "kosodate-ci-check"/; s/\b554\([0-9][0-9]\)\b/564\1/g; s/^inspector_port = 8093/inspector_port = 8094/' supabase/config.toml
  echo "== 権限表の自動テスト（使い捨て・kosodate-ci-check）"
  npx supabase start -x realtime,storage-api,imgproxy,studio,edge-runtime,logflare,vector,supavisor,postgres-meta,mailpit >/dev/null
  trap 'npx supabase stop --no-backup >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
  npx supabase test db
fi
echo "== 書き出し（道の先頭つき・見本の値）"
MSYS_NO_PATHCONV=1 EXPO_PUBLIC_SUPABASE_URL=https://example.invalid EXPO_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_dummy \
  EXPO_PUBLIC_BASE_URL=/kosodate-hint-note-app EXPO_PUBLIC_APP_BUILD=check npx expo export -p web >/dev/null
grep -q 'src="/kosodate-hint-note-app/_expo/' dist/index.html
echo "OK: きれいな複製で Actions と同じ順が通った"
