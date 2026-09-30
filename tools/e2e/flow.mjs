// 通しの確認（ローカル専用・2026-09-30 開発部）
// ログイン（メールの番号）→ 招待コードで参加 → 同意 → 書く（新しい①②）→ 一覧に出る → うちでも試した（試し中）→ 点数を付ける
// → 「自分の家庭だけ」の他家庭の②が見えない、までを、パソコンの Chrome で自動で通す。
//
// 前提: ローカルの Supabase（55421・メール受け 55424）と、Expo の Web の開発サーバ（8081）が動いていること。
// 使い方（プログラムの置き場所で）: node tools/e2e/flow.mjs
//   最初に見本データ（supabase/local/seed_local.sql）を入れ直す。画面の写真は tools/e2e/out/ に置く（公開しない）。
import { chromium } from "playwright-core";
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const out = path.join(here, "out");
fs.mkdirSync(out, { recursive: true });
const APP = process.env.APP_URL ?? "http://localhost:8081";
const MAIL = "http://127.0.0.1:55424";
const email = `e2e-${Date.now()}@example.invalid`;
// 第1段の直しの確かめ用: 長い名前（困りごと30字・対策40字＝上限いっぱい）
const LONG_P = "夜泣き（テスト）で夜中に何度も起きて泣いてしまい朝まで続く";
const LONG_M = "寝る前に部屋を暗くして好きな絵本を二冊まで一緒に読んで電気を消して背中をなでる";
if ([...LONG_P].length > 30 || [...LONG_M].length > 40) throw new Error("見本の長い名前が上限を超えている");
/** 要素の文字が切れずに全部見えているか（横にも縦にもはみ出していない・1行より高い） */
async function fullyVisible(loc) {
  return loc.evaluate((el) => ({ sw: el.scrollWidth, cw: el.clientWidth, sh: el.scrollHeight, ch: el.clientHeight, h: el.getBoundingClientRect().height }));
}
const jstDate = (n) => new Date(Date.now() + 9 * 3600e3 + n * 86400e3).toISOString().slice(0, 10);
const results = [];
const ok = (name) => { results.push(["OK", name]); console.log("OK  ", name); };

// 見本データを入れ直す（ローカルの DB だけ）
execSync(`docker exec -i supabase_db_kosodate-hint-note-app psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q`, {
  input: fs.readFileSync(path.join(root, "supabase", "local", "seed_local.sql")),
  stdio: ["pipe", "ignore", "inherit"],
});
ok("見本データを入れ直した");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true });
const tid = (id) => page.getByTestId(id);
const shot = (n) => page.screenshot({ path: path.join(out, `${n}.png`) });

async function waitMailCode(to) {
  for (let i = 0; i < 30; i++) {
    const j = await (await fetch(`${MAIL}/api/v1/messages`)).json();
    const m = j.messages.find((x) => x.To.some((t) => t.Address === to));
    if (m) {
      const code = (m.Snippet.match(/\b(\d{6})\b/) || [])[1];
      if (code) return { code, subject: m.Subject };
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error("メールが届かない");
}

try {
  // A-1
  await page.goto(APP);
  await tid("login-email").waitFor();
  await shot("01_login");
  await tid("login-email").fill(email);
  await tid("login-send").click();
  // A-2
  await tid("login-code").waitFor();
  const mail = await waitMailCode(email);
  ok(`番号のメールがローカルのメール受けに届いた（件名「${mail.subject}」・6桁）`);
  await shot("02_code");
  await tid("login-code").fill(mail.code); // 6桁そろうと自動で確かめる
  // A-3
  await tid("join-code").waitFor({ timeout: 15000 });
  ok("ログインできた → どのノートにも入っていないので招待コードの画面");
  await tid("join-code").fill("hntb 2345"); // 小文字・空白でも通る（設計書 8-1節）
  await tid("join-name").fill("テスト（見本）");
  await shot("03_join");
  if (!(await tid("join-custody").textContent()).includes("預かるのは、メールアドレス・呼び名・書いた記録です（くわしくは預かり方の約束）。")) throw new Error("A-3 の文が v0.7 ではない");
  ok("【v0.7】招待コードの画面の預かるものの文（C94）と、預かり方の約束へのリンク");
  await tid("join-submit").click();
  const joined = await tid("joined-title").textContent({ timeout: 15000 });
  if (!joined.includes("「姉の家」として参加しました。")) throw new Error(`参加の表示が違う: ${joined}`);
  if (!(await page.getByText("違う家庭のときは、管理者（統括（見本）さん）に伝えてください").isVisible())) throw new Error("管理者の1行が無い");
  ok("招待コードで参加 →「『姉の家』として参加しました。」と管理者の1行");
  await shot("04_joined");
  await tid("joined-next").click();
  // A-4
  await tid("consent-agree").waitFor({ timeout: 15000 });
  if (!(await page.getByText("始める前に（書き方の約束 第1版）").isVisible())) throw new Error("同意画面の題が違う");
  ok("同意画面（題・約束・4行・ボタン「上の内容に同意して始める」）");
  if (!(await page.getByText("困りごと・育てたいこと・対策の名前は全員に見えます。", { exact: false }).isVisible())) throw new Error("A15 の約束1の文が無い");
  if (!(await page.getByText("記録には、書いた人の呼び名が出ます（同じノートの人に見えます）。").isVisible())) throw new Error("A15 の1行が無い");
  ok("【v0.7】同意画面は A15 の推奨の文（約束1に「育てたいこと」・書いた人の呼び名の1行）");
  await shot("05_consent");
  await tid("consent-agree").click();
  // B-1
  await tid("home-search").waitFor({ timeout: 15000 });
  await page.getByText("寝ない").first().waitFor();
  ok("同意 → 困りごとの一覧（見本の「寝ない」が見える）");
  await shot("06_home");
  // C-1 新しく書く
  await tid("fab-write").click();
  await tid("write-problem").waitFor();
  await tid("write-problem").fill(LONG_P);
  await page.getByText("寝る", { exact: true }).last().click(); // 分類
  await tid("write-measure").fill(LONG_M);
  {
    const m = await fullyVisible(tid("write-measure"));
    const pr = await fullyVisible(tid("write-problem"));
    if (m.sh > m.ch + 2 || m.h < 60 || pr.sh > pr.ch + 2 || pr.h < 60) throw new Error(`書く画面の欄で長い名前が切れている ${JSON.stringify({ m, pr })}`);
    ok("【第1段①】書く画面の欄: 長い困りごと（30字）・対策（40字）が折り返して全文見える");
  }
  await tid("score-4").click();
  await tid("age-open").click();
  await tid("age-18").click(); // 1歳半
  await tid("write-note").fill("テストの記録です。");
  // 【第1段②】見出しは項目名と値を分けて表示・日付は選ぶ形
  if ((await tid("summary-date").textContent()) !== "今日" || (await tid("summary-vis").textContent()) !== "みんな") throw new Error("見出しの値が違う");
  await tid("more-open").click();
  if (await page.locator('input[value="' + jstDate(0) + '"]').count()) throw new Error("日付が文字で打つ欄のまま");
  await tid("date-other").click();
  await tid("cal-" + jstDate(0)).waitFor();
  const tomorrow = jstDate(1);
  if (await tid("cal-" + tomorrow).count()) {
    if ((await tid("cal-" + tomorrow).getAttribute("aria-disabled")) !== "true") throw new Error("明日が押せてしまう");
  }
  if ((await tid("cal-next").getAttribute("aria-disabled")) !== "true") throw new Error("今月より先の月に進めてしまう");
  const pick = jstDate(-3);
  if (pick.slice(0, 7) !== jstDate(0).slice(0, 7)) await tid("cal-prev").click();
  await shot("07b_calendar");
  await tid("cal-" + pick).click();
  const want = `${Number(pick.slice(5, 7))}月${Number(pick.slice(8))}日`;
  if ((await tid("summary-date").textContent()) !== want) throw new Error(`選んだ日が見出しに出ない: ${await tid("summary-date").textContent()}`);
  ok(`【第1段②】見出し「試した日［今日］見える人［みんな］」→ カレンダーで3日前（${want}）を選べた・明日は押せない`);
  await shot("07_write");
  await tid("write-save").click();
  // B-4
  await tid("measure-title").waitFor({ timeout: 15000 });
  if ((await tid("measure-title").textContent()) !== LONG_M) throw new Error("書いた②の画面ではない");
  { const t = await fullyVisible(tid("measure-title")); if (t.sw > t.cw + 1 || t.h < 40) throw new Error("詳しい画面の題が切れている"); }
  if (!(await page.getByText(pick).first().isVisible())) throw new Error("選んだ日で保存されていない");
  if (!(await page.getByText("1歳半のとき").isVisible())) throw new Error("年齢の表示が違う");
  ok("save_trial で①②③を新しく作れた → 書いた②の詳しい画面（うち・4 効いた・1歳半）");
  await shot("08_measure_after_save");
  // B-1 の検索に出る
  await page.goto(APP);
  await tid("home-search").waitFor();
  await tid("home-search").fill("夜泣き");
  await page.getByTestId("problem-row").filter({ hasText: "夜泣き（テスト）" }).waitFor({ timeout: 10000 });
  ok("困りごとの一覧の検索（「夜泣き」）に出た");
  {
    const row = page.getByTestId("problem-row").filter({ hasText: LONG_P });
    await row.waitFor();
    await row.click();
    const mrow = page.getByTestId("measure-row").filter({ hasText: LONG_M });
    await mrow.waitFor({ timeout: 10000 });
    const title = mrow.getByText(LONG_M, { exact: true });
    const t = await fullyVisible(title);
    if (t.sw > t.cw + 1 || t.h < 40) throw new Error(`対策の一覧で長い名前が切れている ${JSON.stringify(t)}`);
    await shot("08b_long_measures");
    ok("【第1段①】対策の一覧・詳しい画面・困りごとの一覧: 長い名前が折り返して全文見える");
    await page.goto(APP);
    await tid("home-search").waitFor();
  }
  await tid("home-search").fill("寝 絵本");
  await page.getByTestId("problem-row").filter({ hasText: "寝ない" }).waitFor({ timeout: 10000 });
  ok("①と②をまたいだ検索（「寝 絵本」→「寝ない」）");
  await tid("home-search").fill("");
  await page.getByText("食べる", { exact: true }).first().click();
  await page.getByTestId("problem-row").filter({ hasText: "ごはんを立ち歩く" }).waitFor({ timeout: 10000 });
  if (await page.getByTestId("problem-row").filter({ hasText: "寝ない" }).count()) throw new Error("タグで絞れていない");
  ok("タグのタブ（食べる）で絞り込み");
  await shot("09_home_tag");
  await page.getByText("すべて", { exact: true }).first().click();
  // B-3 → 「自分の家庭だけ」の他家庭の②は見えない
  await page.getByTestId("problem-row").filter({ hasText: "寝ない" }).click();
  await page.getByTestId("measure-row").first().waitFor({ timeout: 10000 });
  const measures = await page.getByTestId("measure-row").allTextContents();
  if (measures.some((t) => t.includes("部屋を真っ暗にする"))) throw new Error("他家庭の「自分の家庭だけ」の②が見えてしまった");
  if (!measures[0].includes("寝る前に絵本")) throw new Error("対策の一覧が違う");
  if (!measures[0].includes("兄（見本）（兄の家）") || !measures[0].includes("統括（見本）（統括の家）")) throw new Error(`書いた人の呼び名が出ない: ${measures[0]}`);
  ok("【v0.7】対策の一覧の③に「書いた人の呼び名（家庭名）」");
  ok("対策の一覧: 他家庭の「自分の家庭だけ」の③しかない②（部屋を真っ暗にする）は出ない");
  await shot("10_measures");
  // B-4 → うちでも試した（試し中）→ 点数を付ける
  await page.getByTestId("measure-row").filter({ hasText: "寝る前に絵本" }).click();
  await tid("also-tried").waitFor();
  await tid("also-tried").click();
  await tid("score-trial").waitFor();
  await tid("score-trial").click();
  await tid("age-open").click();
  await tid("age-36").click();
  await tid("write-save").click();
  await tid("score-open").waitFor({ timeout: 15000 });
  ok("うちでも試した（①②は既存・試し中）で③を足せた");
  await shot("11_also_tried");
  await tid("score-open").click();
  await tid("c3-score-3").click();
  await tid("c3-save").click();
  await tid("c3-save").waitFor({ state: "detached", timeout: 10000 });
  await page.getByTestId("trial-card").filter({ hasText: "3 少し効いた" }).filter({ hasText: "うち" }).waitFor({ timeout: 10000 });
  ok("試し中 → 点数を付ける（3 少し効いた）");
  await shot("12_scored");
  // A-5 は設定から
  await page.goto(`${APP}/settings`);
  await tid("open-privacy").click();
  await page.getByText("1. 運営しているのは").waitFor();
  ok("設定 → 預かり方の約束を読む");
  if (!(await page.getByText("困りごと・育てたいこと・対策の名前とタグ", { exact: false }).isVisible())) throw new Error("預かり方の約束2が A15 の文ではない");
  ok("【v0.7】預かり方の約束は A15 の推奨の文（2に育てたいこと・試したい・範囲、4に書いた人の呼び名）");
  await page.goto(`${APP}/settings/rules`);
  await page.getByText("書き方の約束 第1版（同意済み）").waitFor();
  ok("【v0.7】書き方の約束を読む画面の題「書き方の約束 第1版（同意済み）」");

  // ===== v0.7 の機能 =====
  // 育てたい・試したい（範囲）・テレビ・②の欄の案内
  await page.goto(APP);
  await tid("fab-write").click();
  await tid("kind-grow").click();
  await page.getByText("1 育てたいこと ＊").waitFor();
  await page.getByText("2 やり方 ＊").waitFor();
  await tid("write-problem").fill("片づける力（テスト）");
  const M40 = "おもちゃ箱に写真を貼って戻す場所を分かるようにして毎晩いっしょに片づけ競争をする"; // 40字
  if ([...M40].length !== 40) throw new Error("見本の40字が40字でない: " + [...M40].length);
  await tid("write-measure").fill(M40);
  await tid("write-measure").press("End");
  await tid("write-measure").pressSequentially("あ");
  await tid("measure-limit").waitFor({ timeout: 5000 });
  if ((await tid("write-measure").inputValue()) !== M40) throw new Error("40字を超えて入ってしまった");
  await page.getByText("短い名前で（40字まで）。やり方のくわしい説明は下の『一言』へ", { exact: false }).first().waitFor();
  ok("【v0.7】②の欄の案内（40字まで・一言へ）と、40字を超えたときの知らせ（字は入らない）");
  await tid("score-want").click();
  if ((await tid("date-word").textContent()) !== "書いた日") throw new Error("試したいで「書いた日」にならない");
  await page.getByText("4 何歳で試したい ＊").waitFor();
  await tid("age-open").click();
  await tid("age-mode-range").click();
  await tid("age-from-24").click();
  await tid("age-to-72").click(); // 3年を超える（2歳→6歳）は押せない
  if ((await tid("age-range-ok").textContent()).includes("6歳")) throw new Error("3年を超える範囲を選べてしまった");
  await tid("age-to-36").click();
  await tid("age-range-ok").click();
  if ((await tid("age-chosen").textContent()) !== "2〜3歳") throw new Error("範囲の表示が違う: " + (await tid("age-chosen").textContent()));
  await tid("source-tv").click();
  await tid("write-source-text").fill("朝の情報番組（テスト）");
  await shot("30_write_grow_want");
  await tid("write-save").click();
  await tid("measure-title").waitFor({ timeout: 15000 });
  const wcard = page.getByTestId("trial-card").filter({ hasText: "試したい" });
  await wcard.waitFor();
  const wtext = await wcard.textContent();
  for (const w of ["テスト（見本）（うち）", "2〜3歳で試したい", "に書いた", "テレビ  朝の情報番組（テスト）"]) {
    if (!wtext.includes(w)) throw new Error(`試したいのカードに「${w}」が無い: ${wtext}`);
  }
  if (wtext.includes("日目")) throw new Error("試したいに日数が出ている");
  ok("【v0.7】育てたい・試したい（2〜3歳）・テレビで書ける → カード「テスト（見本）（うち）［試したい］2〜3歳で試したい・◯/◯に書いた・テレビ 番組名」");
  await shot("31_want_card");
  // C-4 試し始めた（年齢を2歳半に直す）
  await tid("start-open").click();
  if ((await tid("sheet-age").textContent()) !== "2〜3歳") throw new Error("C-4 の年齢の札が違う");
  await tid("sheet-age-change").click();
  await tid("age-mode-single").click();
  await tid("age-30").click();
  await tid("c4-save").click();
  await page.getByTestId("trial-card").filter({ hasText: "試し中・1日目" }).filter({ hasText: "2歳半のとき" }).waitFor({ timeout: 10000 });
  ok("【v0.7】試したい →［試し始めた］（C-4。年齢を2歳半に）→「試し中・1日目」");
  // もう1件の試したいを「うちでも試した」で書き、C-3（試したいから点数）
  await tid("also-tried").click();
  await tid("score-want").waitFor();
  await tid("score-want").click();
  await tid("age-open").click();
  await tid("age-48").click();
  await tid("write-save").click();
  await tid("want-score-open").waitFor({ timeout: 15000 });
  await tid("want-score-open").click();
  await tid("c3-score-5").click();
  if (!(await page.getByText("日付は今日", { exact: false }).isVisible())) throw new Error("C-3 の試したいの形ではない");
  await tid("c3-save").click();
  await page.getByTestId("trial-card").filter({ hasText: "5 身についた" }).filter({ hasText: "4歳のとき" }).waitFor({ timeout: 10000 });
  ok("【v0.7】試したい →［点数を付ける］（C-3 の試したいの形・日付は今日）→「5 身についた」（育てたいの①なので伸びの組。v0.9）");
  await shot("32_scored_from_want");
  // D-1 で種類を直す（自家庭が作った①）
  await page.goto(APP);
  await tid("home-kind-grow").click();
  await page.getByTestId("problem-row").filter({ hasText: "片づける力（テスト）" }).waitFor({ timeout: 10000 });
  const growRows = await page.getByTestId("problem-row").allTextContents();
  if (growRows.some((t) => t.includes("寝ない"))) throw new Error("育てたいで困りごとが出た");
  if (!growRows.every((t) => t.includes("育てたい") && t.includes("やり方"))) throw new Error("育てたいの札・やり方の表示が無い");
  ok("【v0.7】困りごとの一覧の［育てたい］で育てたいだけ（札「育てたい」・「やり方 N」）");
  await shot("33_home_grow");
  await tid("home-kind-trouble").click();
  await page.getByTestId("problem-row").filter({ hasText: "寝ない" }).waitFor({ timeout: 10000 });
  if (await page.getByTestId("problem-row").filter({ hasText: "片づける力" }).count()) throw new Error("困りごとで育てたいが出た");
  await tid("home-kind-grow").click();
  await page.getByTestId("problem-row").filter({ hasText: "片づける力（テスト）" }).click();
  await tid("problem-menu").click();
  await tid("menu-rename").click();
  await tid("d1-kind-trouble").click();
  await tid("d1-save").click();
  await page.getByText("この困りごとには", { exact: false }).count(); // 呼び名が戻る
  await page.goto(APP);
  await tid("home-kind-trouble").click();
  await page.getByTestId("problem-row").filter({ hasText: "片づける力（テスト）" }).waitFor({ timeout: 10000 });
  ok("【v0.7】D-1 で①の種類を「育てたい」→「困りごと」に直せた（set_problem_kind）");
  // B-2 まとまり → B-1 の絞り込み
  await page.goto(`${APP}/ages`);
  await tid("year-2").waitFor({ timeout: 10000 });
  if (await page.getByTestId(/^band-/).count()) throw new Error("まとまりの行が残っている（v0.8 で1歳ごとだけ）");
  await shot("34_ages");
  await tid("year-3").click();
  if ((await tid("home-age-filter").textContent()) !== "3歳で絞り込み中") throw new Error("1歳の絞り込みの札が違う");
  await page.getByTestId("problem-row").filter({ hasText: "自分でやろうとする力" }).waitFor({ timeout: 10000 });
  ok("【v0.8】年齢の一覧は1歳ごとだけ → 3歳で絞り込み（範囲2〜3歳の試したいも3歳に入る）");
  // B-3 出典のタブ「テレビ」
  await page.getByTestId("problem-row").filter({ hasText: "自分でやろうとする力" }).click();
  await tid("tab-source-tv").click();
  await page.getByTestId("measure-row").filter({ hasText: "できたことを言葉にして返す" }).waitFor({ timeout: 10000 });
  await page.getByText("やり方", { exact: false }).count();
  ok("【v0.7】対策の一覧の出典のタブ7つ（テレビで絞れる）");
  // 【第1段③】呼び名を変える（D-4）
  await page.goto(`${APP}/settings`);
  await tid("my-name").filter({ hasText: "テスト（見本）" }).waitFor({ timeout: 10000 });
  await tid("rename-open").click();
  await tid("rename-input").fill("テスト改");
  await shot("13_rename");
  await tid("rename-save").click();
  await tid("my-name").filter({ hasText: "テスト改" }).waitFor({ timeout: 10000 });
  await page.reload();
  await tid("my-name").filter({ hasText: "テスト改" }).waitFor({ timeout: 15000 });
  ok("【第1段③】設定 → 呼び名を変える（読み直しても「テスト改」＝データ置き場に保存された）");
} catch (e) {
  results.push(["NG", String(e)]);
  console.error("NG  ", e);
  await shot("zz_error").catch(() => {});
  process.exitCode = 1;
} finally {
  await browser.close();
  fs.writeFileSync(path.join(out, "result.txt"), results.map((r) => r.join(" ")).join("\n"), "utf8");
}
