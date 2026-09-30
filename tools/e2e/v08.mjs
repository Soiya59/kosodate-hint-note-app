// 通しの確認その4（ローカル専用・2026-09-30 開発部）: 要件 v0.8・設計書 v0.5・ワイヤーフレーム v0.5 の直し
//   タグの種類の出し分け（B-1・C-1・D-1）／E-7 で種類を選んで足す／出典7つ（うちでも試した＝このノートで知った・タブ「このノート」）
//   ／B-4 の日付の独立した行／直すモードの日付の決まり（試したいから直す）／書き出しの書いた人／年齢の一覧は1歳ごとだけ
// 前提と使い方は flow.mjs と同じ: APP_URL=http://localhost:8082 node tools/e2e/v08.mjs（最初に見本データを入れ直す）
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
const jst = (n) => new Date(Date.now() + 9 * 3600e3 + n * 86400e3).toISOString().slice(0, 10);

execSync(`docker exec -i supabase_db_kosodate-hint-note-app psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q`, {
  input: fs.readFileSync(path.join(root, "supabase", "local", "seed_local.sql")), stdio: ["pipe", "ignore", "inherit"],
});
ok("見本データを入れ直した");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const ctx = await browser.newContext({ viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true, acceptDownloads: true });
const page = await ctx.newPage();
const tid = (id) => page.getByTestId(id);
const shot = (n) => page.screenshot({ path: path.join(out, `${n}.png`) });

async function login(email) {
  const since = Date.now();
  await page.goto(APP);
  await tid("login-email").fill(email);
  await tid("login-send").click();
  await tid("login-code").waitFor();
  let c;
  for (let i = 0; i < 40 && !c; i++) {
    const j = await (await fetch(`${MAIL}/api/v1/messages`)).json();
    const m = j.messages.find((x) => x.To.some((t) => t.Address === email) && Date.parse(x.Created) >= since - 2000);
    c = m && (m.Snippet.match(/\b(\d{6})\b/) || [])[1];
    if (!c) await new Promise((r) => setTimeout(r, 500));
  }
  await tid("login-code").fill(c);
  await tid("home-search").waitFor({ timeout: 15000 });
}

try {
  await login("kanri@example.invalid");

  // B-1: タグのタブを種類で出し分け
  await tid("home-kind-trouble").click();
  await page.getByText("寝る", { exact: true }).first().waitFor();
  if (await page.getByText("自己肯定感", { exact: true }).count()) throw new Error("困りごとで育てたいのタグが出た");
  await page.getByText("寝る", { exact: true }).first().click();
  await tid("home-kind-grow").click();
  await page.getByText("自己肯定感", { exact: true }).first().waitFor();
  if (await page.getByText("寝る", { exact: true }).count()) throw new Error("育てたいで困りごとのタグが出た");
  await page.getByTestId("problem-row").filter({ hasText: "自分でやろうとする力" }).waitFor({ timeout: 10000 }); // 寝るの選択は［すべて］に戻った
  await shot("50_home_grow_tags");
  ok("B-1: タグのタブを種類で出し分け（困りごと＝寝る…／育てたい＝自己肯定感…）。選んでいたタグが無い種類に切り替えたら［すべて］へ");

  // E-7: B-1 で育てたいを選んでいる → 種類の既定は育てたい → 足す（下のタブで移る。道を打ち直すとアプリが開き直され、選択は消える＝端末に覚えない）
  await page.getByRole("tab", { name: "設定" }).click();
  await tid("open-tags").click();
  await tid("tags-grow").waitFor();
  if (!(await tid("tags-grow").textContent()).startsWith("自己肯定感／やり抜く力")) throw new Error("育てたいの並びが違う: " + (await tid("tags-grow").textContent()));
  if ((await tid("tags-both").textContent()) !== "ことば／その他") throw new Error("両方のタグが違う");
  if (!(await tid("tag-kind-grow").textContent()).includes("✓")) throw new Error("E-7 の種類の既定が B-1 の種類（育てたい）でない: " + (await tid("tag-kind-grow").evaluate((e) => e.outerHTML.slice(0, 200))));
  await tid("tag-name").fill("早寝早起き");
  await tid("tag-add").click();
  await page.waitForFunction(() => document.querySelector('[data-testid="tags-grow"]')?.textContent?.endsWith("早寝早起き"), null, { timeout: 10000 });
  await tid("tag-name").fill("寝る");
  await tid("tag-add").click();
  await page.getByText("同じ名前のタグがあります").waitFor({ timeout: 10000 });
  await shot("51_tags_add");
  ok("E-7: いまのタグを3つの見出しで・種類の既定は B-1 の種類（育てたい）・育てたいのタグを足すと育てたいの最後（その他の前）・同じ名前は断る");

  // C-1: 分類を①の種類で出し分け・種類を切り替えたら合わないタグを外す
  await page.goto(APP);
  await tid("home-kind-trouble").click();
  await tid("fab-write").click();
  await tid("write-problem").fill("種類テストの①");
  await tid("write-tag-寝る").click();
  await tid("write-tag-ことば").click();
  await tid("kind-grow").click();
  if ((await tid("removed-tags").textContent()) !== "種類を変えたので、合わないタグ（寝る）を外しました。") throw new Error("外した知らせが違う");
  if (await tid("write-tag-寝る").count()) throw new Error("育てたいで寝るが出ている");
  await tid("write-tag-集中力").click();
  await tid("write-measure").fill("種類テストの②");
  await tid("score-4").click();
  await tid("age-open").click();
  await tid("age-36").click();
  await shot("52_write_kind_tags");
  await tid("write-save").click();
  await tid("measure-title").waitFor({ timeout: 15000 });
  ok("C-1: 分類は①の種類で出し分け・種類を切り替えると「種類を変えたので、合わないタグ（寝る）を外しました。」・育てたいの①に［集中力・ことば］で保存できた");

  // D-1: 種類を変える前の知らせ → 直すと合わないタグが外れる
  await page.goto(APP);
  await page.getByTestId("problem-row").filter({ hasText: "種類テストの①" }).click();
  await tid("problem-title").waitFor();
  await tid("problem-menu").click();
  await tid("menu-rename").click();
  await tid("d1-kind-trouble").click();
  if (!(await tid("d1-gone-tags").textContent()).startsWith("合わないタグ（集中力）は外れます。")) throw new Error("D-1 の知らせが違う: " + (await tid("d1-gone-tags").textContent()));
  await shot("53_d1_kind");
  await tid("d1-save").click();
  await page.getByText("[ことば]", { exact: true }).last().waitFor({ timeout: 10000 });
  ok("D-1: 種類を変えると「合わないタグ（集中力）は外れます。」→［直す］で集中力が外れ、ことばが残った");

  // 出典7つ: ［うちでも試した］は「このノートで知った」が選ばれた状態
  await page.goto(APP);
  await page.getByTestId("problem-row").filter({ hasText: "寝ない" }).click();
  await page.getByTestId("measure-row").filter({ hasText: "寝る前に絵本" }).click();
  await tid("also-tried").click();
  await tid("source-notebook").waitFor();
  await tid("source-notebook").filter({ hasText: "このノートで知った✓" }).waitFor({ timeout: 5000 }).catch(() => { throw new Error("うちでも試したで「このノートで知った」が選ばれていない"); });
  await tid("score-3").click();
  await tid("age-open").click();
  await tid("age-24").click();
  await tid("write-save").click();
  const nb = page.getByTestId("trial-card").filter({ hasText: "どこで知った: このノートで知った" });
  await nb.waitFor({ timeout: 15000 });
  ok("出典7つ: ［うちでも試した］から開くと「このノートで知った」が選ばれた状態 → カード「どこで知った: このノートで知った」");
  // B-4 の日付の独立した行
  const dates = await page.getByTestId("trial-date").allTextContents();
  if (dates.length < 2 || !dates.every((d) => /\d/.test(d))) throw new Error("日付の行がない: " + dates);
  ok("B-4: 日付はどのカードでも札と年齢の下の独立した1行");
  // B-3 のタブ「このノート」
  await page.goto(APP);
  await page.getByTestId("problem-row").filter({ hasText: "寝ない" }).click();
  await tid("tab-source-notebook").waitFor({ timeout: 10000 });
  if ((await tid("tab-source-notebook").textContent()) !== "このノート") throw new Error("タブの文字が違う");
  await tid("tab-source-notebook").click();
  await page.getByTestId("measure-row").filter({ hasText: "寝る前に絵本" }).waitFor({ timeout: 10000 });
  ok("B-3: 出典のタブ8つ（文字は「このノート」）で絞れる");

  // 直すモードの日付の決まり（設計書 v0.5 6章）: 試したい（3日前に書いた）を日付を触らずに点数へ → 今日
  await page.goto(APP);
  await tid("fab-write").click();
  await tid("write-problem").fill("日付テストの①");
  await tid("write-measure").fill("日付テストの②");
  await tid("score-want").click();
  await tid("age-open").click();
  await tid("age-24").click();
  await tid("more-open").click();
  await tid("date-other").click();
  if (jst(-3).slice(0, 7) !== jst(0).slice(0, 7)) await tid("cal-prev").click();
  await tid("cal-" + jst(-3)).click();
  await tid("write-save").click();
  await tid("trial-edit").waitFor({ timeout: 15000 });
  await tid("trial-edit").click();
  await tid("score-4").waitFor();
  await tid("score-4").click();
  if (!(await tid("summary-date").textContent()).startsWith("今日（")) throw new Error("試したいから直したのに日付が今日にならない");
  if (!(await tid("want-date-notice").textContent()).startsWith("試したいから直すので、日付は今日になります。")) throw new Error("知らせが違う（v0.9 の文）");
  await shot("54_edit_want_date");
  await tid("write-save").click();
  await page.getByTestId("trial-date").filter({ hasText: jst(0) }).first().waitFor({ timeout: 10000 });
  ok("直すモード: 試したい（3日前）を日付を触らずに点数へ →「今日（M/D）になります」と知らせ、保存すると今日");
  // 日付を選び直したら、その日付
  await page.goto(APP);
  await tid("fab-write").click();
  await tid("write-problem").fill("日付テストの③");
  await tid("write-measure").fill("日付テストの④");
  await tid("score-want").click();
  await tid("age-open").click();
  await tid("age-24").click();
  await tid("more-open").click();
  await tid("date-other").click();
  if (jst(-3).slice(0, 7) !== jst(0).slice(0, 7)) await tid("cal-prev").click();
  await tid("cal-" + jst(-3)).click();
  await tid("write-save").click();
  await tid("trial-edit").waitFor({ timeout: 15000 });
  await tid("trial-edit").click();
  await tid("score-trial").waitFor();
  await tid("score-trial").click();
  await tid("more-open").click();
  await tid("date-昨日").click();
  if (await tid("want-date-notice").count()) throw new Error("日付を選び直したのに知らせが残っている");
  await tid("write-save").click();
  await page.getByTestId("trial-date").filter({ hasText: `${Number(jst(-1).slice(5, 7))}/${Number(jst(-1).slice(8))}から` }).first().waitFor({ timeout: 10000 });
  ok("直すモード: 試したいを試し中に直し、日付を選び直したら（昨日）その日付");

  // 書き出しに書いた人の呼び名
  await page.goto(`${APP}/settings/export`);
  const downloads = [];
  page.on("download", (d) => downloads.push(d));
  await tid("export-run").click();
  for (let i = 0; i < 20 && downloads.length < 2; i++) await new Promise((r) => setTimeout(r, 300));
  const texts = {};
  for (const d of downloads) { const f = path.join(out, "v08-" + d.suggestedFilename()); await d.saveAs(f); texts[path.extname(f)] = fs.readFileSync(f, "utf8"); }
  if (!texts[".csv"]?.includes("書いた人") || !texts[".csv"].includes("兄（見本）")) throw new Error("CSV に書いた人が無い");
  if (!texts[".md"]?.includes("兄（見本）（兄の家）") || !texts[".md"].includes("統括（見本）（うち）")) throw new Error("Markdown に「呼び名（家庭名）」が無い");
  ok("書き出し: Markdown に「呼び名（家庭名）」、CSV に「書いた人」の列（設計書 v0.5 Y8）");

  // 年齢の一覧は1歳ごとだけ
  await page.goto(`${APP}/ages`);
  await tid("year-2").waitFor({ timeout: 10000 });
  if (await page.getByTestId(/^band-/).count()) throw new Error("まとまりの行が残っている");
  ok("年齢の一覧は1歳ごとだけ（まとまりの行は無い）");
} catch (e) {
  results.push(["NG", String(e)]);
  console.error("NG  ", e);
  await shot("zz_v08_error").catch(() => {});
  process.exitCode = 1;
} finally {
  await browser.close();
  fs.writeFileSync(path.join(out, "result_v08.txt"), results.map((r) => r.join(" ")).join("\n"), "utf8");
}
