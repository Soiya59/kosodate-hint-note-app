// 通しの確認その3（ローカル専用・2026-09-30 開発部）: 招待の前に要る画面
//   E-6 招待コード（出す・一覧・取り消す）／E-5 家庭とメンバー（作る・名前を変える・家庭を消す・メンバーを外す）
//   ／管理者として他家庭の③を消す／③を直す・消す →「対策も消しますか」「困りごとも消しますか」／①を消せないときの文
//   ／書き出し（Markdown・CSV）／退会（Edge Function でログインの情報も消える）
// 前提: flow.mjs と同じ（ローカルの Supabase〈Edge Function を含む〉と開発サーバ）。最初に見本データを入れ直す。
// 使い方: APP_URL=http://localhost:8082 node tools/e2e/invite_prep.mjs
import { chromium } from "playwright-core";
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const out = path.join(here, "out");
fs.mkdirSync(out, { recursive: true });
const APP = process.env.APP_URL ?? "http://localhost:8082";
const MAIL = "http://127.0.0.1:55424";
const results = [];
const ok = (n) => { results.push(["OK", n]); console.log("OK  ", n); };
const sql = (q) => execSync(`docker exec supabase_db_kosodate-hint-note-app psql -U postgres -d postgres -Atc "${q.replace(/"/g, '\\"')}"`).toString().trim();

execSync(`docker exec -i supabase_db_kosodate-hint-note-app psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q`, {
  input: fs.readFileSync(path.join(root, "supabase", "local", "seed_local.sql")), stdio: ["pipe", "ignore", "inherit"],
});
ok("見本データを入れ直した");

const browser = await chromium.launch({ channel: "chrome", headless: true });
async function newPage() {
  const ctx = await browser.newContext({ viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true, acceptDownloads: true });
  return ctx.newPage();
}
async function code(email, since) {
  for (let i = 0; i < 40; i++) {
    const j = await (await fetch(`${MAIL}/api/v1/messages`)).json();
    const m = j.messages.find((x) => x.To.some((t) => t.Address === email) && Date.parse(x.Created) >= since - 2000);
    const c = m && (m.Snippet.match(/\b(\d{6})\b/) || [])[1];
    if (c) return c;
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error("メールが届かない: " + email);
}
async function login(page, email) {
  const since = Date.now();
  await page.goto(APP);
  await page.getByTestId("login-email").fill(email);
  await page.getByTestId("login-send").click();
  await page.getByTestId("login-code").waitFor();
  await page.getByTestId("login-code").fill(await code(email, since));
}
async function joinAndConsent(page, inviteCode, name) {
  await page.getByTestId("join-code").waitFor({ timeout: 15000 });
  await page.getByTestId("join-code").fill(inviteCode);
  await page.getByTestId("join-name").fill(name);
  await page.getByTestId("join-submit").click();
  await page.getByTestId("joined-next").click();
  await page.getByTestId("consent-agree").click();
  await page.getByTestId("home-search").waitFor({ timeout: 15000 });
}
const shot = (page, n) => page.screenshot({ path: path.join(out, `${n}.png`) });

try {
  // ===== 管理者（見本の統括） =====
  const admin = await newPage();
  const A = (id) => admin.getByTestId(id);
  await login(admin, "kanri@example.invalid");
  await A("home-search").waitFor({ timeout: 15000 });

  // E-6 招待コード
  await admin.goto(`${APP}/settings`);
  await A("open-invites").click();
  await A("invite-row").first().waitFor({ timeout: 10000 });
  const before = await A("invite-row").count();
  await A("invite-target-弟の家").click();
  await A("invite-issue").click();
  const issued = (await A("invite-code").textContent()).trim();
  if (!/^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/.test(issued)) throw new Error("コードの形が違う: " + issued);
  await shot(admin, "40_invite_code");
  await A("invite-close").click();
  await admin.waitForFunction((n) => document.querySelectorAll('[data-testid="invite-row"]').length === n, before + 1, { timeout: 10000 });
  await A("invite-revoke").last().click();
  await admin.waitForFunction((n) => document.querySelectorAll('[data-testid="invite-row"]').length === n, before, { timeout: 10000 });
  ok(`E-6: 家庭を選んでコードを出せた（${issued}・小窓は［閉じる］で閉じる）→ 使えるコードの一覧に出る → 取り消せる`);
  // もう一度出す（新しい家庭の人に使う）
  await A("invite-target-弟の家").click();
  await A("invite-issue").click();
  const code2 = (await A("invite-code").textContent()).trim();
  await A("invite-close").click();
  await shot(admin, "41_invites");

  // E-5 家庭とメンバー（作る・名前を変える・家庭を消す）
  await admin.goto(`${APP}/settings`);
  await A("open-families").click();
  await A("family-counts").waitFor({ timeout: 10000 });
  if (!(await A("family-counts").textContent()).includes("家庭 4 / 5")) throw new Error("件数の表示が違う");
  await A("household-create").click();
  await A("household-name").fill("テストの家");
  await A("household-save").click();
  await admin.getByText("テストの家（まだ誰もいません）").waitFor({ timeout: 10000 });
  if (!(await A("household-create").isDisabled())) throw new Error("上限（5家庭）で［＋家庭を作る］が押せてしまう");
  await admin.getByText("家庭は5つまでです").waitFor();
  await A("family-menu-テストの家").click();
  await A("household-rename").click();
  await A("household-name").fill("兄の家");
  await A("household-save").click();
  await admin.getByText("同じ名前の家庭があります").waitFor({ timeout: 10000 });
  await A("household-name").fill("テストの家2");
  await A("household-save").click();
  await admin.getByText("テストの家2（まだ誰もいません）").waitFor({ timeout: 10000 });
  await A("family-menu-テストの家2").click();
  await A("household-delete").click();
  const dtext = await A("household-delete-text").textContent();
  if (!dtext.includes("メンバー0人と、記録 0件が消えます")) throw new Error("家庭を消すときの件数の文が違う: " + dtext);
  await A("household-delete-confirm").click();
  await admin.getByText("テストの家2（まだ誰もいません）").waitFor({ state: "detached", timeout: 10000 });
  ok("E-5: 家庭を作る・上限（5家庭）で押せない・名前を変える（同じ名前は「同じ名前の家庭があります」）・家庭を消す（Edge Function delete-household。件数の確認つき）");
  await shot(admin, "42_families");

  // 管理者として他家庭の「みんな」の③を消す（兄の家の「寝る前に絵本」の③）
  await admin.goto(APP);
  await admin.getByTestId("problem-row").filter({ hasText: "寝ない" }).click();
  await admin.getByTestId("measure-row").filter({ hasText: "寝る前に絵本" }).click();
  const aniCard = admin.getByTestId("trial-card").filter({ hasText: "兄（見本）（兄の家）" });
  await aniCard.waitFor({ timeout: 10000 });
  await aniCard.getByTestId("trial-admin-delete").click();
  if (!(await A("delete-text").textContent()).includes("兄の家の記録を、管理者として消します。消す前に、書いた人に伝えてください。")) throw new Error("管理者として消す文が違う");
  await A("delete-confirm").click();
  await aniCard.waitFor({ state: "detached", timeout: 10000 });
  ok("管理者として他家庭の「みんな」の③を消せた（D-2 の管理者の文）");

  // ===== 新しい人（弟の家）: 参加 → 書く → 直す → 消す（対策も・困りごとも） → ①を消せない文 → 書き出し → 退会 =====
  const u = await newPage();
  const U = (id) => u.getByTestId(id);
  const uEmail = `e2e-leave-${Date.now()}@example.invalid`;
  await login(u, uEmail);
  await joinAndConsent(u, code2.toLowerCase(), "弟（テスト）");
  ok("管理者が出したコードで弟の家に参加できた");
  // 書く
  await U("fab-write").click();
  await U("write-problem").fill("消すテストの困りごと");
  await U("write-measure").fill("消すテストの対策");
  await U("score-4").click();
  await U("age-open").click();
  await U("age-24").click();
  await U("write-save").click();
  await U("trial-edit").waitFor({ timeout: 15000 });
  // 直す
  await U("trial-edit").click();
  await u.getByText("名前は困りごと・対策の画面の［⋯］から直せます。").waitFor({ timeout: 10000 });
  await U("score-2").click();
  await U("write-note").fill("直した一言");
  await U("write-save").click();
  const card = u.getByTestId("trial-card").filter({ hasText: "2 その場だけ" }).filter({ hasText: "直した一言" });
  await card.waitFor({ timeout: 10000 });
  ok("③を直す（C-1 の直すモード: 点数4→2・一言を足す）");
  await shot(u, "43_edited");
  // 消す → 対策も → 困りごとも
  await U("trial-delete").click();
  await U("delete-confirm").click();
  await U("ask-text").waitFor({ timeout: 10000 });
  if ((await U("ask-text").textContent()) !== "対策『消すテストの対策』も消しますか。") throw new Error("続けて聞く文が違う");
  await U("ask-delete").click();
  await u.getByText("困りごと『消すテストの困りごと』も消しますか。").waitFor({ timeout: 10000 });
  await U("ask-delete").click();
  await U("home-search").waitFor({ timeout: 10000 });
  if (sql("select count(*) from problems where name='消すテストの困りごと'") !== "0") throw new Error("①が消えていない");
  ok("③を消す →「対策『…』も消しますか」→ 消す →「困りごと『…』も消しますか」→ 消す（delete_measure・delete_problem）");
  // ①を消せないとき（自家庭の③だけが見えている）
  await U("fab-write").click();
  await U("write-problem").fill("消せないテストの困りごと");
  await U("write-measure").fill("消せないテストの対策");
  await U("score-3").click();
  await U("age-open").click();
  await U("age-36").click();
  await U("write-save").click();
  await U("trial-edit").waitFor({ timeout: 15000 });
  await u.goto(APP);
  await u.getByTestId("problem-row").filter({ hasText: "消せないテストの困りごと" }).click();
  await U("problem-menu").click();
  await U("menu-delete").click();
  await U("problem-delete-confirm").click();
  await U("refusal-text").waitFor({ timeout: 10000 });
  if ((await U("refusal-text").textContent()) !== "記録が付いているため、消せません。先に記録を消してください。") throw new Error("断りの文が違う: " + (await U("refusal-text").textContent()));
  ok("①を［⋯］から消そうとして記録が付いているとき:「記録が付いているため、消せません。先に記録を消してください。」");
  await shot(u, "44_refusal");
  // 書き出し
  await u.goto(`${APP}/settings`);
  await U("open-export").click();
  const downloads = [];
  u.on("download", (d) => downloads.push(d));
  await U("export-run").click();
  await u.waitForFunction(() => true);
  for (let i = 0; i < 20 && downloads.length < 2; i++) await new Promise((r) => setTimeout(r, 300));
  if (downloads.length !== 2) throw new Error("ファイルが2つ出ない: " + downloads.length);
  const texts = {};
  for (const d of downloads) {
    const f = path.join(out, d.suggestedFilename());
    await d.saveAs(f);
    texts[path.extname(f)] = fs.readFileSync(f, "utf8");
  }
  if (!texts[".csv"].includes("種類,困りごと・育てたいこと,対策・やり方,家庭") || !texts[".csv"].includes("消せないテストの対策")) throw new Error("CSV の中身が違う");
  if (!texts[".md"].includes("## 消せないテストの困りごと（困りごと）") || texts[".md"].includes("@")) throw new Error("Markdown の中身が違う（またはメールが入っている）");
  if (texts[".md"].includes("部屋を真っ暗にする")) throw new Error("他家庭の非公開が書き出しに入った");
  ok("E-3 書き出し: Markdown と CSV の2つ（見える分だけ・他家庭の非公開は入らない・メールは入らない）");
  // 退会（記録は消す＝既定）
  await u.goto(`${APP}/settings`);
  await U("open-leave").click();
  await U("leave-open").click();
  await U("leave-confirm").click();
  await U("left-title").waitFor({ timeout: 15000 });
  if (sql(`select count(*) from auth.users where email='${uEmail}'`) !== "0") throw new Error("ログインの情報が消えていない");
  if (sql("select count(*) from trials t join measures m on m.id=t.measure_id where m.name='消せないテストの対策'") !== "0") throw new Error("③が消えていない");
  if (sql("select count(*) from measures where name='消せないテストの対策'") !== "1") throw new Error("②（みんなのもの）は残るはず");
  ok("E-4 退会（既定＝記録を消す）→「退会しました」。ログインの情報（メールアドレス）も消え、③は消え、①②の名前は残る（Edge Function delete-member）");
  await shot(u, "45_left");

  // ===== 管理者がメンバーを外す（違う家庭に入った人を外す。既定＝家庭の記録として残す） =====
  const w = await newPage();
  const Wt = (id) => w.getByTestId(id);
  const wEmail = `e2e-wrong-${Date.now()}@example.invalid`;
  await login(w, wEmail);
  await joinAndConsent(w, "HNTB-2345", "まちがい（テスト）");
  await Wt("fab-write").click();
  await Wt("write-problem").fill("外すテストの困りごと");
  await Wt("write-measure").fill("外すテストの対策");
  await Wt("score-5").click();
  await Wt("age-open").click();
  await Wt("age-12").click();
  await Wt("write-save").click();
  await Wt("trial-edit").waitFor({ timeout: 15000 });
  await admin.goto(`${APP}/settings/families`);
  await A("remove-まちがい（テスト）").click();
  await A("remove-confirm").click();
  await A("remove-まちがい（テスト）").waitFor({ state: "detached", timeout: 10000 });
  if (sql(`select count(*) from auth.users where email='${wEmail}'`) !== "0") throw new Error("外した人のログインが消えていない");
  if (sql("select count(*) from trials t join measures m on m.id=t.measure_id where m.name='外すテストの対策'") !== "1") throw new Error("家庭の記録として残るはず");
  ok("E-5 メンバーを外す（既定＝家庭の記録として残す）→ ログインの情報は消え、③は姉の家の記録として残る（Edge Function delete-member）");
  // 残った③は書いた人が空 → 家庭名だけで出る
  await admin.goto(APP);
  await admin.getByTestId("problem-row").filter({ hasText: "外すテストの困りごと" }).click();
  const line = admin.getByTestId("trial-line").first();
  await line.waitFor({ timeout: 10000 });
  if (!(await line.textContent()).startsWith("姉の家")) throw new Error("書いた人が空のとき家庭名だけにならない: " + (await line.textContent()));
  ok("外した人の③は「姉の家」（家庭名だけ）で出る");
} catch (e) {
  results.push(["NG", String(e)]);
  console.error("NG  ", e);
  process.exitCode = 1;
} finally {
  await browser.close();
  fs.writeFileSync(path.join(out, "result_invite_prep.txt"), results.map((r) => r.join(" ")).join("\n"), "utf8");
}
