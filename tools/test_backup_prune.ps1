# 古いバックアップを消す処理のテスト（2026-10-02 開発部。要件 8-4節の条件1・本部長の依頼4）
# 使い捨ての一時フォルダだけを使う。本番の保存先（C:\App_cursor\_backup\...）には触らない。
# 使い方: powershell -ExecutionPolicy Bypass -File tools\test_backup_prune.ps1
$ErrorActionPreference = "Stop"
$Script = Join-Path $PSScriptRoot "backup_supabase.ps1"
$T = Join-Path ([System.IO.Path]::GetTempPath()) ("khn-prune-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$Root = Join-Path $T "root"; $Outside = Join-Path $T "outside"; $Notice = Join-Path $T "notice"
New-Item -ItemType Directory -Force $Root, $Outside | Out-Null
$old = (Get-Date).AddDays(-30)
function Mk($dir, [bool]$backupShape, $when) {
  New-Item -ItemType Directory -Force $dir | Out-Null
  if ($backupShape) { Set-Content (Join-Path $dir "data.sql") "x"; Set-Content (Join-Path $dir "counts.txt") "x" } else { Set-Content (Join-Path $dir "memo.txt") "x" }
  (Get-Item $dir).LastWriteTime = $when
}
Mk (Join-Path $Root "2026-01-01") $true $old                 # 消える: 古い・日付の名前・バックアップの形
Mk (Join-Path $Root "2026-01-02") $false $old                # 残る: バックアップの形でない
Mk (Join-Path $Root "2026-01-03-before-restore") $true $old  # 残る: ラベルつきの手動の控え
Mk (Join-Path $Root "2026-09-30") $true (Get-Date).AddDays(-3) # 残る: 新しい
Mk (Join-Path $Root "old-notes") $true $old                  # 残る: 日付の名前でない
Set-Content (Join-Path $Root "2026-01-04") "file"            # 残る: フォルダでなくファイル
Mk (Join-Path $Outside "2026-01-05") $true $old              # 残る: Root の外（兄弟のフォルダ）
Mk (Join-Path $Root "2026-01-06") $true $old                 # 消える（下の入れ子の確かめ用に中に別のフォルダ）
New-Item -ItemType Directory -Force (Join-Path $Root "2026-01-06\2026-01-07") | Out-Null
# リンク（ジャンクション）: 名前は日付・古い・リンク先は Root の外。リンク先の中身を消してはいけない
$Target = Join-Path $Outside "linktarget"; Mk $Target $true $old
cmd /c mklink /J (Join-Path $Root "2026-01-08") $Target | Out-Null
(Get-Item (Join-Path $Root "2026-01-08") -Force).LastWriteTime = $old

& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -PruneOnly -Root $Root -KeepDays 14 | Out-Null

$fail = 0
function Expect($path, [bool]$exists) {
  $now = Test-Path -LiteralPath $path
  $ok = ($now -eq $exists)
  if (-not $ok) { $script:fail++ }
  Write-Output ("{0}  {1}  （期待: {2}）" -f $(if ($ok) { "OK  " } else { "NG  " }), (Split-Path $path -Leaf), $(if ($exists) { "残る" } else { "消える" }))
}
Expect (Join-Path $Root "2026-01-01") $false
Expect (Join-Path $Root "2026-01-06") $false
Expect (Join-Path $Root "2026-01-02") $true
Expect (Join-Path $Root "2026-01-03-before-restore") $true
Expect (Join-Path $Root "2026-09-30") $true
Expect (Join-Path $Root "old-notes") $true
Expect (Join-Path $Root "2026-01-04") $true
Expect (Join-Path $Outside "2026-01-05") $true
Expect (Join-Path $Root "2026-01-08") $true                  # リンクそのものも消さない
Expect (Join-Path $Target "data.sql") $true                  # リンク先の中身も消えない
Expect (Join-Path $Root "backup.log") $true

Remove-Item -Recurse -Force $T
if ($fail -eq 0) { Write-Output "ALL OK" } else { Write-Output "FAILED: $fail 件"; exit 1 }
