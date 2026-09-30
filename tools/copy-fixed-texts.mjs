// 決まった文（同意画面・ログインの画面の1行・預かり方の約束）を、要件定義書の枠から「そのまま」写す道具（2026-09-30 開発部）。
// 手で打ち直さない・言い換えないため（ワイヤーフレーム v0.3 0-0節・A-4・A-5「枠から全部を貼り直す」）。
//
// 使い方（プログラムの置き場所で）:
//   node tools/copy-fixed-texts.mjs "C:\App_cursor\kosodate-hint-note\企画部\成果物\子育てヒントノート_要件定義書_v0.6（2026-09-30）.md"
// → src/constants/fixedTexts.ts を書き直す（このファイルは手で直さない）。
// 要件定義書の版が上がったら、新しい版のファイルを渡して流し直す。
import fs from "node:fs";
import path from "node:path";

const src = process.argv[2];
if (!src) {
  console.error("要件定義書の .md の場所を渡してください");
  process.exit(1);
}
const md = fs.readFileSync(src, "utf8").replace(/\r\n/g, "\n");

function blockAfter(heading) {
  const i = md.indexOf(heading);
  if (i < 0) throw new Error(`見出しが見つかりません: ${heading}`);
  const a = md.indexOf("```\n", i);
  const b = md.indexOf("\n```", a + 4);
  return md.slice(a + 4, b).split("\n");
}

// ---- 7-1 同意画面 ----
const c = blockAfter("### 7-1.");
const nonEmpty = c.filter((l) => l.trim() !== "");
const consent = {
  titleLine: nonEmpty[0],
  intro: nonEmpty[1],
  rulesHeading: nonEmpty[2],
  rules: nonEmpty.filter((l) => /^\d+\. /.test(l)).map((l) => l.replace(/^\d+\. /, "")),
  custodyHeading: nonEmpty.find((l) => l === "預かることと、見える人"),
  custody: nonEmpty.filter((l) => l.startsWith("・")).map((l) => l.slice(1)),
  buttons: nonEmpty.filter((l) => l.startsWith("［")).map((l) => l.replace(/^［|］$/g, "")),
};
if (consent.rules.length !== 6 || consent.custody.length !== 8 || consent.buttons.length !== 2) {
  throw new Error("7-1節の枠の形が想定と違います（約束6・預かること8・ボタン2）");
}

// ---- 7-2 ①b ログインの画面の1行 ----
const row = md.split("\n").find((l) => l.startsWith("| ①b ログインの画面"));
const m = row && row.match(/v0\.6（A13[^）]*）: 「([^」]+)」/);
if (!m) throw new Error("7-2節 ①b の文が見つかりません");
const loginLine = m[1];

// ---- 8-6 預かり方の約束 ----
const p = blockAfter("### 8-6.");
const privacy = { title: p[0].trim(), sections: [], enacted: "" };
for (const line of p.slice(1)) {
  if (line.trim() === "") continue;
  if (/^\d+\. /.test(line)) privacy.sections.push({ h: line.trim(), lines: [] });
  else if (line.startsWith("制定")) privacy.enacted = line.trim();
  else privacy.sections[privacy.sections.length - 1].lines.push(line.replace(/^ {3}/, ""));
}
if (privacy.sections.length !== 10) throw new Error("8-6節の見出しが10個ではありません");

// ---- （v0.7）A15 の推奨（1）の文: 要件の「A15 の推奨（1）なら…次のとおり」の箇条から、機械的に当てる ----
// 箇条の「」の中の ** は太字の印なので外す。見つからなければ止まる（文を手で打ち直さないため）。
const strip = (x) => x.replace(/\*\*/g, "");
function a15Bullets(anchor) {
  const i = md.indexOf(anchor);
  if (i < 0) return null;
  return md.slice(i).split("\n").slice(1, 4).filter((l) => /^\s+- /.test(l));
}
let a15 = null;
const cb = a15Bullets("**同意画面の文の直し（統括への確認 A15");
const pb = a15Bullets("**（v0.7）A15 の推奨（1）なら");
if (cb && pb) {
  const m1 = strip(cb[0]).match(/約束1の最後「([^」]+)」→「([^」]+)」/);
  const m2 = strip(cb[1]).match(/2行目の後に1行「・([^」]+)」/);
  const m3 = strip(pb[0]).match(/2の「(.+)」→「(.+)」\s*$/);
  const m4 = strip(pb[1]).match(/4の2行目の後に「・([^」]+)」/);
  if (!m1 || !m2 || !m3 || !m4) throw new Error("A15 の箇条の形が想定と違います");
  const rules = [...consent.rules];
  if (!rules[0].endsWith(m1[1])) throw new Error("約束1の最後が見つかりません");
  rules[0] = rules[0].slice(0, -m1[1].length) + m1[2];
  const custody = [...consent.custody];
  custody.splice(2, 0, m2[1]);
  const sections = privacy.sections.map((x) => ({ h: x.h, lines: [...x.lines] }));
  const s2 = sections[1].lines;
  const k = s2.findIndex((l) => l.includes(m3[1]));
  if (k < 0) throw new Error("預かり方の約束2の元の文が見つかりません");
  s2[k] = s2[k].replace(m3[1], m3[2]);
  sections[3].lines.splice(2, 0, "・" + m4[1]);
  a15 = { rules, custody, privacySections: sections };
}

const out = `// このファイルは tools/copy-fixed-texts.mjs が要件定義書から自動で作る。手で直さない。
// 出どころ: ${path.basename(src)}（7-1節の枠・7-2節 ①b・8-6節の枠）
// 作った日: ${new Date(Date.now() + 9 * 3600 * 1000).toISOString().slice(0, 10)}（日本時間）
/* eslint-disable */
export const FIXED = ${JSON.stringify({ source: path.basename(src), consent, loginLine, privacy, a15 }, null, 2)} as const;
`;
const dest = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..", "src", "constants", "fixedTexts.ts");
fs.writeFileSync(dest, out, "utf8");
console.log("書きました:", dest);
console.log("A15 の文:", a15 ? "あり" : "なし（この版の要件には無い）");
console.log("約束", consent.rules.length, "・預かること", consent.custody.length, "・預かり方の約束の見出し", privacy.sections.length);
