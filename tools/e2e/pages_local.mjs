// GitHub Pages の形（道の先頭 /kosodate-hint-note-app）で書き出した画面を、このパソコンだけのサーバで開いて確かめる（2026-10-01 開発部）。
// 前提: tools/serve-pages-local.mjs が動いている（dist/ は EXPO_PUBLIC_BASE_URL=/kosodate-hint-note-app・EXPO_PUBLIC_APP_BUILD=local-test-1 で書き出し済み）。
// Supabase にはつながなくてよい（ログインの画面・預かり方の約束・道の動き・検索避け・古い画面の手当てだけを見る）。
import { chromium } from "playwright-core";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const dist = path.resolve(here, "..", "..", "dist");
const BASE = "http://localhost:8090/kosodate-hint-note-app";
const ok = (n) => console.log("OK  ", n);
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 375, height: 812 }, isMobile: true });
try {
  // 1. 先頭を開くと、ログインの画面（道は /kosodate-hint-note-app/login）
  await page.goto(`${BASE}/`);
  await page.getByTestId("login-email").waitFor({ timeout: 20000 });
  if (!page.url().startsWith(`${BASE}/login`)) throw new Error("道が base path の下でない: " + page.url());
  ok(`先頭を開くとログインの画面（${page.url().replace("http://localhost:8090", "")}）`);
  // 2. 画面の中の移動（預かり方の約束のリンク）も base path の下
  await page.getByText("預かり方の約束", { exact: true }).first().click();
  await page.getByText("1. 運営しているのは").waitFor({ timeout: 10000 });
  if (!page.url().startsWith(`${BASE}/privacy`)) throw new Error("画面の中の移動が base path の下でない: " + page.url());
  ok(`画面の中の移動も base path の下（${new URL(page.url()).pathname}）`);
  // 3. 無い道を直接開く（404.html＝画面の殻）→ 画面が出る
  const r = await page.goto(`${BASE}/privacy`);
  await page.getByText("1. 運営しているのは").waitFor({ timeout: 20000 });
  ok(`道を直接開いても画面が出る（GitHub Pages と同じく 404.html を返す。状態 ${r.status()}）`);
  // 4. 検索避け
  const robots = await page.locator('meta[name="robots"]').getAttribute("content");
  if (!robots?.includes("noindex")) throw new Error("noindex が無い");
  ok(`検索避け: <meta name="robots" content="${robots}">`);
  // 5. 古い画面の手当て: version.json の番号を変えると、画面は1回だけ読み込み直す
  let loads = 0;
  page.on("load", () => { loads += 1; });
  fs.writeFileSync(path.join(dist, "version.json"), '{"build":"local-test-2"}');
  await page.goto(`${BASE}/login`);
  await page.getByTestId("login-email").waitFor({ timeout: 20000 });
  await page.waitForTimeout(2500);
  if (loads < 2) throw new Error("番号が違うのに読み込み直さない（load " + loads + " 回）");
  await page.waitForTimeout(1500);
  const loadsAfter = loads;
  await page.waitForTimeout(2000);
  if (loads !== loadsAfter) throw new Error("読み込み直しが止まらない");
  ok(`古い画面の手当て: 配信の番号（version.json）が画面の番号と違うと、1回だけ読み込み直す（load ${loadsAfter} 回で止まる）`);
  fs.writeFileSync(path.join(dist, "version.json"), '{"build":"local-test-1"}');
} catch (e) {
  console.error("NG  ", e);
  process.exitCode = 1;
} finally {
  await browser.close();
}
