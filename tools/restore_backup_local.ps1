# バックアップから「ローカルの Supabase」へ戻す（戻せることの試し。2026-09-30 開発部。設計書 v0.4 7-4節の条件③④）
# 本番には戻さない（このスクリプトはローカルの Docker の DB だけに書く）。
#
# 手順: ①ローカルの DB を作り直す（npx supabase db reset。表の作りはマイグレーションから）
#       ②data.sql を流す ③表ごとの件数を counts.txt と比べる ④（-RunTests）権限の自動テストを流す
# 使い方: powershell -ExecutionPolicy Bypass -File tools\restore_backup_local.ps1 -Dir C:\App_cursor\_backup\kosodate-hint-note-local\2026-09-30 [-RunTests]
param(
  [Parameter(Mandatory = $true)] [string]$Dir,
  [switch]$RunTests
)
$ErrorActionPreference = "Continue"
$AppDir = Split-Path -Parent $PSScriptRoot
$Supabase = Join-Path $AppDir "node_modules\.bin\supabase.cmd"
$Container = "supabase_db_kosodate-hint-note-app"
Set-Location $AppDir

$expected = [ordered]@{}
foreach ($l in Get-Content (Join-Path $Dir "counts.txt") -Encoding utf8) { $p = $l -split "`t"; if ($p.Count -eq 2) { $expected[$p[0]] = [int]$p[1] } }

Write-Output "1) ローカルの DB を作り直します"
& $Supabase db reset 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Output "FAILED: db reset ($LASTEXITCODE)"; exit 1 }

Write-Output "2) data.sql を流します"
# Windows PowerShell 5.1 はパイプで日本語を渡すと文字が化けるので、ファイルを入れ物の中に写してから流す
docker cp (Join-Path $Dir "data.sql") "${Container}:/tmp/restore_data.sql" | Out-Null
docker exec $Container psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f /tmp/restore_data.sql 2>&1 | Out-Null
$rc = $LASTEXITCODE
docker exec $Container rm -f /tmp/restore_data.sql | Out-Null
if ($rc -ne 0) { Write-Output "FAILED: data.sql を流せませんでした ($rc)"; exit 1 }

Write-Output "3) 表ごとの件数を比べます"
$ok = $true
foreach ($t in $expected.Keys) {
  $n = [int](docker exec $Container psql -U postgres -d postgres -Atc "select count(*) from $t")
  $mark = if ($n -eq $expected[$t]) { "一致" } else { $ok = $false; "違う" }
  Write-Output ("   {0,-24} バックアップ {1,5} ／ 戻した後 {2,5}  {3}" -f $t, $expected[$t], $n, $mark)
}
if (-not $ok) { Write-Output "FAILED: 件数が一致しません"; exit 1 }
Write-Output "   件数はすべて一致"

if ($RunTests) {
  Write-Output "4) 権限の自動テストを流します"
  $out = & $Supabase test db 2>&1
  $out | Select-Object -Last 3 | ForEach-Object { Write-Output "   $_" }
  if (-not ($out -match "Result: PASS")) { Write-Output "FAILED: テスト"; exit 1 }
}
Write-Output "OK"
