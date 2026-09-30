/**
 * 古い画面が残らないための手当て（Web 版。2026-10-01 開発部。やること 2f-34）。
 * - 画面のプログラムのファイル名は、中身が変わると名前も変わる（Expo の書き出しがハッシュを付ける）ので、古いファイルは使われない。
 * - 残りうるのは index.html と、スマホのブラウザが開いたままのタブ（前の画面をそのまま戻す）。GitHub Pages は見出し（キャッシュの指示）を変えられない。
 * - そこで、配信のたびに version.json（その配信の番号）を置き、画面を開いたとき・アプリに戻ったときに読みにいく。
 *   画面に埋め込んだ番号と違えば、1回だけ読み込み直す（同じ番号で何度も読み込み直さない）。
 * - 開発サーバ・通し確認では番号が無いので何もしない。書きかけは端末に残っているので、読み込み直しても消えない。
 */
const BUILD = process.env.EXPO_PUBLIC_APP_BUILD ?? "";
const BASE = process.env.EXPO_PUBLIC_BASE_URL ?? "";
const KEY = "khn.reloadedFor";

async function check() {
  try {
    const res = await fetch(`${BASE}/version.json?t=${Date.now()}`, { cache: "no-store" });
    if (!res.ok) return;
    const latest = ((await res.json()) as { build?: string }).build ?? "";
    if (!latest || latest === BUILD) return;
    if (window.sessionStorage.getItem(KEY) === latest) return; // 同じ番号では1回だけ
    window.sessionStorage.setItem(KEY, latest);
    // ただの読み込み直しでは、ブラウザが覚えている古い index.html（GitHub Pages は10分ほど覚えさせる）がまた出ることがある。
    // 住所に番号を付けて読み込み直し、新しい index.html を取りにいかせる（付けた番号は読み込んだ後に住所から消す）
    const u = new URL(window.location.href);
    u.searchParams.set("_v", latest.slice(0, 12));
    window.location.replace(u.toString());
  } catch {
    /* 通信が無いときなどは何もしない */
  }
}

export function startUpdateCheck(): () => void {
  if (!BUILD || typeof window === "undefined" || typeof document === "undefined") return () => {};
  // 読み込み直しのときに付けた番号を住所から消す（見た目だけ。画面の動きには使わない）
  try {
    const u = new URL(window.location.href);
    if (u.searchParams.has("_v")) {
      u.searchParams.delete("_v");
      window.history.replaceState(window.history.state, "", u.toString());
    }
  } catch { /* 何もしない */ }
  void check();
  const onVisible = () => {
    if (document.visibilityState === "visible") void check();
  };
  document.addEventListener("visibilitychange", onVisible);
  return () => document.removeEventListener("visibilitychange", onVisible);
}
