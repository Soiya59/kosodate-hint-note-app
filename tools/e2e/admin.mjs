// 通しの確認その2（ローカル専用）: 見本の管理者 kanri@example.invalid でログイン → 設定 → 招待コードを出す → 他家庭の非公開も自家庭のは見える
// 前提と使い方は flow.mjs と同じ。node tools/e2e/admin.mjs（見本データは入れ直さない。flow.mjs の後に流す）
import { chromium } from "playwright-core";
import path from "node:path";
import { fileURLToPath } from "node:url";

const out = path.join(path.dirname(fileURLToPath(import.meta.url)), "out");
const APP = process.env.APP_URL ?? "http://localhost:8081";
const MAIL = "http://127.0.0.1:55424";
const email = "kanri@example.invalid";

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true });
const tid = (id) => page.getByTestId(id);
try {
  const before = Date.now();
  await page.goto(APP);
  await tid("login-email").fill(email);
  await tid("login-send").click();
  await tid("login-code").waitFor();
  let code;
  for (let i = 0; i < 30 && !code; i++) {
    const j = await (await fetch(`${MAIL}/api/v1/messages`)).json();
    const m = j.messages.find((x) => x.To.some((t) => t.Address === email) && Date.parse(x.Created) >= before - 2000);
    code = m && (m.Snippet.match(/\b(\d{6})\b/) || [])[1];
    if (!code) await new Promise((r) => setTimeout(r, 500));
  }
  await tid("login-code").fill(code);
  await tid("home-search").waitFor({ timeout: 15000 });
  console.log("OK   見本の管理者（種データで作ったログイン）で番号ログイン → 同意済み・参加済みなので直接ホーム");
  await page.getByTestId("problem-row").filter({ hasText: "寝ない" }).click();
  await page.getByTestId("measure-row").filter({ hasText: "部屋を真っ暗にする" }).waitFor({ timeout: 10000 });
  console.log("OK   自家庭の「自分の家庭だけ」の②（部屋を真っ暗にする）は自家庭には見える");
  await page.goto(`${APP}/settings/invites`);
  await tid("invite-target-兄の家").click();
  await tid("invite-issue").click();
  const c = await tid("invite-code").textContent({ timeout: 10000 });
  if (!/^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/.test(c)) throw new Error(`コードの形が違う: ${c}`);
  console.log("OK   管理者が招待コードを出せた（8文字）");
  await page.screenshot({ path: path.join(out, "20_invite.png") });
} catch (e) {
  console.error("NG  ", e);
  await page.screenshot({ path: path.join(out, "zz_admin_error.png") }).catch(() => {});
  process.exitCode = 1;
} finally {
  await browser.close();
}
