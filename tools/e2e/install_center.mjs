// インストール（PWA）と中央寄せの確かめ（2026-10-01 開発部）。
// 前提: 書き出し（EXPO_PUBLIC_BASE_URL=/kosodate-hint-note-app）を tools/serve-pages-local.mjs（ポート 8090）で出していること。
//   使い捨てのローカルの Supabase（例 kosodate-ci-check・API 56421・メール受け 56424）に見本データを入れてあること。
//   使い方: MAIL=http://127.0.0.1:56424 node tools/e2e/install_center.mjs
import { chromium } from "playwright-core";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const BASE = "http://localhost:8090/kosodate-hint-note-app";
const MAIL = process.env.MAIL ?? "http://127.0.0.1:56424";
const ok = (n) => console.log("OK  ", n);
// シークレット（incognito）ではインストールできない決まりなので、使い捨ての普通の利用者の設定で開く
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "khn-pwa-"));
const ctx = await chromium.launchPersistentContext(profile, { channel: "chrome", headless: true, viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
const browser = { close: async () => { await ctx.close(); fs.rmSync(profile, { recursive: true, force: true }); } };
const page = ctx.pages()[0] ?? (await ctx.newPage());
const tid = (id) => page.getByTestId(id);
try {
  // 1. マニフェスト・アイコンが読める
  await page.goto(`${BASE}/`);
  await tid("login-email").waitFor({ timeout: 20000 });
  const href = await page.locator('link[rel="manifest"]').getAttribute("href");
  const man = await (await page.request.get(`http://localhost:8090${href}`)).json();
  if (man.start_url !== "/kosodate-hint-note-app/" || man.scope !== "/kosodate-hint-note-app/" || man.display !== "standalone") throw new Error("マニフェストの中身が違う");
  for (const ic of man.icons) {
    const r = await page.request.get(`http://localhost:8090${ic.src}`);
    if (r.status() !== 200 || !(r.headers()["content-type"] ?? "").includes("png")) throw new Error("アイコンが読めない: " + ic.src);
  }
  const apple = await page.locator('link[rel="apple-touch-icon"]').getAttribute("href");
  if ((await page.request.get(`http://localhost:8090${apple}`)).status() !== 200) throw new Error("apple-touch-icon が読めない");
  ok(`マニフェスト（${href}）: name「${man.name}」・short_name「${man.short_name}」・start_url/scope ${man.scope}・display ${man.display}・アイコン ${man.icons.length} 個（192/512 の any と maskable）と apple-touch-icon が読める`);

  // 2. Chrome の「インストールできるか」の判定（DevTools と同じ仕組み）
  const cdp = await ctx.newCDPSession(page);
  const inst = await cdp.send("Page.getInstallabilityErrors");
  const errs = (inst.installabilityErrors ?? []).map((e) => e.errorId);
  if (errs.length) throw new Error("インストールできない理由: " + errs.join(", "));
  const appMan = await cdp.send("Page.getAppManifest");
  if ((appMan.errors ?? []).length) throw new Error("マニフェストの誤り: " + JSON.stringify(appMan.errors));
  ok("Chrome の判定（Page.getInstallabilityErrors）: インストールできない理由は0件・マニフェストの誤りも0件");

  // 3. ログインしてホームへ（見本の管理者）
  const since = Date.now();
  await tid("login-email").fill("kanri@example.invalid");
  await tid("login-send").click();
  await tid("login-code").waitFor();
  let c;
  for (let i = 0; i < 40 && !c; i++) {
    const j = await (await fetch(`${MAIL}/api/v1/messages`)).json();
    const m = j.messages.find((x) => x.To.some((t) => t.Address === "kanri@example.invalid") && Date.parse(x.Created) >= since - 2000);
    c = m && (m.Snippet.match(/\b(\d{6})\b/) || [])[1];
    if (!c) await new Promise((r) => setTimeout(r, 500));
  }
  await tid("login-code").fill(c);
  await tid("home-search").waitFor({ timeout: 20000 });
  await page.waitForTimeout(800);

  // 4. スマホの幅: 横にはみ出さない（はみ出すと、ブラウザが全体を縮めて「左上に小さく」出る）
  const m375 = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth, bw: document.body.scrollWidth }));
  if (m375.sw > m375.cw || m375.bw > m375.cw) throw new Error(`375px で横にはみ出している: ${JSON.stringify(m375)}`);
  await page.screenshot({ path: "tools/e2e/out/70_home_375.png" });
  ok(`スマホの幅（375px）: ホームが横にはみ出さない（ページの幅 ${m375.sw}px ＝ 画面の幅 ${m375.cw}px）`);

  // 5. 広い画面: 中央に寄る（ホーム・年齢・設定）
  await page.setViewportSize({ width: 1280, height: 900 });
  for (const [name, go] of [["ホーム", null], ["年齢の一覧", "/ages"], ["設定", "/settings"]]) {
    if (go) await page.getByRole("tab", { name: name === "年齢の一覧" ? "年齢" : "設定" }).click();
    await page.waitForTimeout(600);
    const box = await page.evaluate(() => {
      const el = [...document.querySelectorAll('[data-testid="screen-inner"]')].find((e) => e.getBoundingClientRect().width > 0 && e.offsetParent !== null);
      const r = el.getBoundingClientRect();
      return { left: Math.round(r.left), right: Math.round(window.innerWidth - r.right), width: Math.round(r.width), sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth };
    });
    if (Math.abs(box.left - box.right) > 2 || box.width > 480 || box.sw > box.cw) throw new Error(`${name} が中央に寄らない: ${JSON.stringify(box)}`);
    ok(`広い画面（1280px）: ${name}は幅 ${box.width}px で中央（左右の余白 ${box.left}px／${box.right}px）`);
  }
  await page.screenshot({ path: "tools/e2e/out/71_settings_1280.png" });
  await page.getByRole("tab", { name: "ノート" }).click();
  await page.waitForTimeout(600);
  await page.screenshot({ path: "tools/e2e/out/72_home_1280.png" });
} catch (e) {
  console.error("NG  ", e);
  process.exitCode = 1;
} finally {
  await browser.close();
}
