# 子育てヒントノート データ置き場のバックアップ（2026-09-30 開発部。要件 v0.7 8-4節・設計書 v0.4 7-4節・F-32）
# おやこポイントの C:\App_cursor\oyakopoint-app\tools\backup_supabase.ps1（読むだけ）を元に、このアプリ用に作った。
#
# 取るもの（どちらもテキストの SQL）:
#   schema.sql … 表・関数・権限などの作り
#   data.sql   … 全データ（public の12の表と、ログインのアカウント auth。メールアドレスが入る）
#   counts.txt … 表ごとの件数（data.sql から数える。戻したときに件数が一致するかを比べるため）
# 置き場所: 既定は C:\App_cursor\_backup\kosodate-hint-note\<日付>\（git の外・app のフォルダの外・共有クラウドの外）。
#   家族のメールアドレスと記録が入るので、GitHub やクラウドには置かないこと。
# 暗号化（要件 8-4節の条件6・7）: 保存先のドライブが BitLocker（Windows 11 Home では「デバイスの暗号化」）で
#   暗号化されていることを、書き出す前に確かめる。暗号化されていないドライブなら書き出さずに失敗にする（-SkipEncryptionCheck で外せる）。
#   2026-09-30 の開発部の読み取り（管理者の権限なし）では、このパソコンの C: は暗号化が「オン」だった（報告書 6章）。
# 残す日数: 既定 14日分。古いものは自動で消す。
# 失敗に気づく: 結果は <置き場所>\backup.log に1行ずつ書く（OK／FAILED）。失敗したら終了コード 1。
#
# 使い方（PowerShell。どちらもプログラムの置き場所から）:
#   本番（本番を作って supabase link した後。タスクスケジューラへの登録は統括の確認の後）:
#     powershell -ExecutionPolicy Bypass -File tools\backup_supabase.ps1
#   ローカルの Supabase（試し用）:
#     powershell -ExecutionPolicy Bypass -File tools\backup_supabase.ps1 -Target Local
#
# supabase CLI は途中経過を標準エラーに出す。Windows PowerShell 5.1 はそれをエラーと扱うので、止めずに続け、成否は終了コードで判断する。
param(
  [ValidateSet("Linked", "Local")] [string]$Target = "Linked",
  [string]$Root = "",
  [int]$KeepDays = 14,
  [string]$Label = "",
  [switch]$SkipEncryptionCheck,
  # 失敗したときに「失敗のお知らせ」のファイルを置く場所（既定は統括のデスクトップ。成功すると消える。中身にメールアドレスは入れない）
  [string]$NoticeDir = "",
  # 書き出さずに、古いものを消す処理だけを流す（2026-10-02 のテスト用。tools\test_backup_prune.ps1 が使う）
  [switch]$PruneOnly
)
$ErrorActionPreference = "Continue"
$AppDir = Split-Path -Parent $PSScriptRoot
if (-not $Root) {
  $Root = if ($Target -eq "Local") { "C:\App_cursor\_backup\kosodate-hint-note-local" } else { "C:\App_cursor\_backup\kosodate-hint-note" }
}
$Stamp = Get-Date -Format "yyyy-MM-dd"
$Name = if ($Label) { "$Stamp-$Label" } else { $Stamp }
$Dir = Join-Path $Root $Name
$Log = Join-Path $Root "backup.log"
# PowerShell からは npx が動かないことがあるため、アプリのフォルダの supabase CLI を直接呼ぶ（おやこポイントと同じ）
$Supabase = Join-Path $AppDir "node_modules\.bin\supabase.cmd"
$Flag = if ($Target -eq "Local") { "--local" } else { "--linked" }
# 件数を比べる表（設計書 2章の12の表）と、ログインの表
$Tables = @("public.spaces", "public.households", "public.members", "public.consents", "public.invites", "public.invite_attempts",
  "public.tags", "public.problems", "public.problem_tags", "public.measures", "public.books", "public.trials", "auth.users")

New-Item -ItemType Directory -Force $Root | Out-Null
function Write-Log($m) { Add-Content -Path $Log -Value ("{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Target, $m) -Encoding utf8 }

function Test-Encrypted($path) {
  # 管理者の権限なしで読める「BitLocker の保護の状態」（1 = オン）。Windows 11 Home のデバイスの暗号化もこれで分かる
  $drive = ([System.IO.Path]::GetPathRoot((Resolve-Path $path).Path)).TrimEnd('\')
  $v = (New-Object -ComObject Shell.Application).NameSpace("$drive\").Self.ExtendedProperty('System.Volume.BitLockerProtection')
  return @{ Drive = $drive; Value = $v; Ok = ($v -eq 1) }
}

if (-not $NoticeDir) { $NoticeDir = [Environment]::GetFolderPath("Desktop") }
$Notice = Join-Path $NoticeDir "【バックアップ失敗】子育てヒントノート.txt"

# 古いバックアップを消す（2026-10-02 に安全のための条件を足した）。消すのは次の全部に当てはまるものだけ:
#   ・$Root の直下の、名前がちょうど「yyyy-MM-dd」のフォルダ（ラベルつきの手動の控え「2026-10-02-before-…」は消さない）
#   ・フォルダの中に data.sql と counts.txt がある（バックアップの形をしている）
#   ・ショートカット（リンク・ジャンクション）ではない（リンク先の別のフォルダを消さないため）
#   ・最後に書き込まれた日が $KeepDays 日より前
#   ・今回書き出したフォルダ（$keepDir）ではない
function Remove-OldBackups($rootDir, $days, $keepDir) {
  $rootFull = [System.IO.Path]::GetFullPath($rootDir).TrimEnd('\')
  Get-ChildItem -LiteralPath $rootFull -Directory -Force | Where-Object {
    $_.Name -match '^\d{4}-\d{2}-\d{2}$' -and
    -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -and
    ([System.IO.Path]::GetDirectoryName($_.FullName).TrimEnd('\') -eq $rootFull) -and
    $_.FullName -ne $keepDir -and
    $_.LastWriteTime -lt (Get-Date).AddDays(-$days) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "data.sql")) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "counts.txt"))
  } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
    Write-Log "removed old $($_.Name)"
  }
}

if ($PruneOnly) { Remove-OldBackups $Root $KeepDays ""; Write-Output "PRUNE-ONLY done"; exit 0 }

try {
  if (-not $SkipEncryptionCheck) {
    $e = Test-Encrypted $Root
    if (-not $e.Ok) { throw "保存先 $($e.Drive) が暗号化されていません（BitLockerProtection=$($e.Value)）。書き出しを止めました" }
  }
  New-Item -ItemType Directory -Force $Dir | Out-Null
  Set-Location $AppDir
  & $Supabase db dump $Flag -f (Join-Path $Dir "schema.sql") 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "schema dump failed ($LASTEXITCODE)" }
  & $Supabase db dump $Flag --data-only --use-copy -s "public,auth" -f (Join-Path $Dir "data.sql") 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "data dump failed ($LASTEXITCODE)" }
  $s = (Get-Item (Join-Path $Dir "schema.sql")).Length
  $d = (Get-Item (Join-Path $Dir "data.sql")).Length
  if ($s -lt 10000 -or $d -lt 1000) { throw "dump too small (schema=$s data=$d)" }

  # 表ごとの件数（data.sql の COPY の行を数える）
  $counts = [ordered]@{}; foreach ($t in $Tables) { $counts[$t] = 0 }
  $cur = $null
  foreach ($line in [System.IO.File]::ReadLines((Join-Path $Dir "data.sql"))) {
    if ($cur) { if ($line -eq '\.') { $cur = $null } else { $counts[$cur]++ }; continue }
    if ($line -match '^COPY "?(\w+)"?\."?(\w+)"? ') { $k = "$($Matches[1]).$($Matches[2])"; if ($counts.Contains($k)) { $cur = $k } }
  }
  ($counts.GetEnumerator() | ForEach-Object { "{0}`t{1}" -f $_.Key, $_.Value }) | Set-Content -Path (Join-Path $Dir "counts.txt") -Encoding utf8
  Write-Log ("OK {0} schema={1} data={2} trials={3} users={4}" -f $Name, $s, $d, $counts["public.trials"], $counts["auth.users"])

  Remove-OldBackups $Root $KeepDays $Dir
  # 最後の結果（統括が1か所で見られる）。成功したら失敗のお知らせを消す
  Set-Content -Path (Join-Path $Root "last_result.txt") -Value ("{0} OK {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Name) -Encoding utf8
  if (Test-Path -LiteralPath $Notice) { Remove-Item -LiteralPath $Notice -Force }
  Write-Output "OK: $Dir"
} catch {
  $msg = $_.Exception.Message
  Write-Log "FAILED $Name $msg"
  # 途中まで書いた不完全なフォルダ（counts.txt が無い）は残さない
  if ((Test-Path -LiteralPath $Dir) -and -not (Test-Path -LiteralPath (Join-Path $Dir "counts.txt"))) { Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue }
  Set-Content -Path (Join-Path $Root "last_result.txt") -Value ("{0} FAILED {1} {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Name, $msg) -Encoding utf8
  try {
    New-Item -ItemType Directory -Force $NoticeDir | Out-Null
    Set-Content -Path $Notice -Encoding utf8 -Value @(
      "子育てヒントノートのバックアップに失敗しました。",
      "日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
      "理由: $msg",
      "くわしい記録: $Log",
      "（次に成功すると、このファイルは自動で消えます）"
    )
  } catch { }
  Write-Output "FAILED: $msg"
  exit 1
}
