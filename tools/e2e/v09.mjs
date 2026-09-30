// 通しの確認その5（ローカル専用・2026-09-30 開発部）: 要件 v0.9・ワイヤーフレーム v0.6 の画面の直し
//   下のタブ［ノート］・見出し「ノート」／ホームのタグを2行まで・［＋N］・［閉じる］・選んだタグを［すべて］の次に
//   ／育てたいの「伸び」と札（C-1・B-3・B-4・C-3）・書き出し／直すモードの日付の知らせ（1か所・v0.6 の文）
// 使い方: APP_URL=http://localhost:8082 node tools/e2e/v09.mjs（最初に見本データを入れ直す）
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
const md = (d) => `${Number(d.slice(5, 7))}/${Number(d.slice(8))}`;

execSync(`docker exec -i supabase_db_kosodate-hint-note-app psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q`, {
  input: fs.readFileSync(path.join(root, "supabase", "local", "seed_local.sql")), stdio: ["pipe", "ignore", "inherit"],
});
ok("見本データを入れ直した");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const ctx = await browser.newContext({ viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true, acceptDownloads: true });
const page = await ctx.newPage();
const tid = (id) => page.getByTestId(id);
const shot = (n) => page.screenshot({ path: path.join(out, `${n}.png`) });
const tagLabels = () => page.locator('[data-testid="home-tags"] > *').allTextContents();

try {
  const since = Date.now();
  await page.goto(APP);
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
  await tid("home-search").waitFor({ timeout: 15000 });

  // 見出し・下のタブ
  if ((await tid("home-title").textContent()) !== "ノート") throw new Error("見出しが「ノート」でない");
  await page.getByRole("tab", { name: "ノート" }).waitFor();
  ok("下のタブ［ノート］［年齢］［設定］・ホームの見出し「ノート」");

  // タグは2行まで・［＋N］・［閉じる］
  await tid("home-tags-more").waitFor({ timeout: 10000 });
  const box = await tid("home-tags").boundingBox();
  const collapsed = await tagLabels();
  const more = (await tid("home-tags-more").textContent()).trim();
  const hidden = Number(more.replace("＋", ""));
  if (!(hidden > 0) || box.height > 44 * 2 + 8 * 3 + 4) throw new Error(`2行に収まっていない: 高さ${box.height}・${more}`);
  if (collapsed.length - 1 + hidden !== 25) throw new Error(`数が合わない（すべて＋24個）: ${collapsed.length - 1}＋${hidden}`);
  await shot("60_tags_2lines");
  await tid("home-tags-more").click();
  await tid("home-tags-close").waitFor();
  if ((await tagLabels()).length !== 26) throw new Error("［＋N］で全部が出ない");
  await shot("61_tags_all");
  ok(`ホームのタグは折り返して2行まで（2行の中に${collapsed.length - 1}個・［${more}］）→［＋N］で全部（25個＋［閉じる］）`);
  // 隠れていたタグを選んで閉じる → ［すべて］の次に出る
  await tid("home-tag-自分でする力").click();
  await tid("home-tags-close").click();
  const after = await tagLabels();
  if (after[0] !== "すべて" || after[1] !== "自分でする力") throw new Error("選んだタグが［すべて］の次に出ない: " + after.slice(0, 3));
  await shot("62_tags_selected_front");
  await tid("home-tag-すべて").click();
  if ((await tagLabels())[1] === "自分でする力") throw new Error("［すべて］に戻したのに並びが戻らない");
  ok("閉じたとき、選んだタグ（自分でする力）が隠れる位置なら［すべて］の次に出る。［すべて］を選ぶと元の並び");

  // 育てたいの「伸び」
  await tid("fab-write").click();
  await tid("kind-grow").click();
  if ((await tid("score-heading").textContent()) !== "3 伸び ＊") throw new Error("見出しが「伸び」でない");
  const row4 = await tid("score-4").textContent();
  if (!row4.includes("4 伸びた") || !row4.includes("1〜2週間、続けて見られた")) throw new Error("育てたいの札・基準の1行が違う: " + row4);
  const row1 = await tid("score-1").textContent();
  if (!row1.includes("1 変わらなかった") || !row1.includes("後戻りした場合もここ")) throw new Error("1の言葉が違う");
  await tid("kind-trouble").click();
  if ((await tid("score-heading").textContent()) !== "3 効き目 ＊" || !(await tid("score-4").textContent()).includes("4 効いた")) throw new Error("困りごとに戻すと効き目の組に戻らない");
  await tid("kind-grow").click();
  await tid("write-problem").fill("伸びテストの①");
  await tid("write-measure").fill("伸びテストの②");
  await tid("score-4").click();
  await tid("age-open").click();
  await tid("age-36").click();
  await shot("63_write_grow_scores");
  await tid("write-save").click();
  await page.getByTestId("trial-card").filter({ hasText: "4 伸びた" }).waitFor({ timeout: 15000 });
  ok("C-1: ①が育てたいのとき見出し「3 伸び」・札「1 変わらなかった〜5 身についた」・基準の1行（困りごとに戻すと効き目の組）→ B-4 のカード「4 伸びた」");
  // うちでも試した（試し中）→ C-3 も伸びの組
  await tid("also-tried").click();
  await tid("score-trial").waitFor();
  await tid("score-trial").click();
  await tid("age-open").click();
  await tid("age-48").click();
  await tid("write-save").click();
  await tid("score-open").waitFor({ timeout: 15000 });
  await tid("score-open").click();
  if (!(await tid("c3-score-5").textContent()).includes("5 身についた")) throw new Error("C-3 が伸びの組でない");
  await tid("c3-score-5").click();
  await tid("c3-save").click();
  await page.getByTestId("trial-card").filter({ hasText: "5 身についた" }).waitFor({ timeout: 10000 });
  ok("C-3（点数を付ける）も伸びの組（5 身についた）");
  // B-3 の行も
  await page.goto(APP);
  await page.getByTestId("problem-row").filter({ hasText: "伸びテストの①" }).click();
  await page.getByTestId("trial-line").filter({ hasText: "4 伸びた" }).waitFor({ timeout: 10000 });
  ok("B-3: 育てたいの①の行の札も「4 伸びた」");

  // 直すモードの日付の知らせ（1か所・v0.6 の文）
  await page.goto(APP);
  await tid("fab-write").click();
  await tid("write-problem").fill("知らせテストの①");
  await tid("write-measure").fill("知らせテストの②");
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
  await tid("score-3").waitFor();
  await tid("score-3").click();
  if ((await tid("summary-date").textContent()) !== `今日（${md(jst(0))}）になります`) throw new Error("日付の札が「今日（M/D）になります」でない: " + (await tid("summary-date").textContent()));
  if ((await tid("want-date-notice").count()) !== 1 || (await page.getByTestId("want-date-notice-score").count()) !== 0) throw new Error("知らせが1か所でない");
  if ((await tid("want-date-notice").textContent()) !== "試したいから直すので、日付は今日になります。違う日にするときは、試した日を選び直してください。") throw new Error("知らせの文が違う");
  await shot("64_edit_notice");
  // 前と同じ日を選び直す
  await tid("more-open").click();
  await tid("date-other").click();
  if (jst(-3).slice(0, 7) !== jst(0).slice(0, 7)) await tid("cal-prev").click();
  await tid("cal-" + jst(-3)).click();
  const label = `${Number(jst(-3).slice(5, 7))}月${Number(jst(-3).slice(8))}日`;
  if ((await tid("want-date-notice").textContent()) !== `前と同じ日（${label}）を選んでも、保存すると今日になります。その日にしたいときは、保存した後にもう一度直してください。`) throw new Error("前と同じ日の文が違う: " + (await tid("want-date-notice").textContent()));
  // 別の日を選ぶ → 知らせは消え、札はその日
  await tid("date-昨日").click();
  if (await tid("want-date-notice").count()) throw new Error("別の日を選んだのに知らせが残る");
  if ((await tid("summary-date").textContent()) !== "昨日") throw new Error("札が選んだ日でない");
  // 試したいに戻す → 元の日付
  await tid("score-want").click();
  if ((await tid("summary-date").textContent()) !== label) throw new Error("試したいに戻したのに元の日付に戻らない");
  ok("直すモード: 試したいから直すと札「今日（M/D）になります」＋日付の行の下に1行だけ（v0.6 の文）／前と同じ日は別の文／別の日なら消える／試したいに戻すと元の日付");

  // 書き出しの言葉
  await page.goto(`${APP}/settings/export`);
  const downloads = [];
  page.on("download", (d) => downloads.push(d));
  await tid("export-run").click();
  for (let i = 0; i < 20 && downloads.length < 2; i++) await new Promise((r) => setTimeout(r, 300));
  const texts = {};
  for (const d of downloads) { const f = path.join(out, "v09-" + d.suggestedFilename()); await d.saveAs(f); texts[path.extname(f)] = fs.readFileSync(f, "utf8"); }
  if (!texts[".md"]?.includes("4 伸びた") || !texts[".md"].includes("4 効いた")) throw new Error("Markdown の点数の言葉が種類ごとでない");
  if (!texts[".csv"]?.includes("点数の言葉") || !texts[".csv"].includes("伸びた")) throw new Error("CSV に点数の言葉が無い");
  ok("書き出し: 点数の言葉を①の種類で（育てたい＝「4 伸びた」・困りごと＝「4 効いた」）。CSV に「点数の言葉」の列");
} catch (e) {
  results.push(["NG", String(e)]);
  console.error("NG  ", e);
  await shot("zz_v09_error").catch(() => {});
  process.exitCode = 1;
} finally {
  await browser.close();
  fs.writeFileSync(path.join(out, "result_v09.txt"), results.map((r) => r.join(" ")).join("\n"), "utf8");
}
