/**
 * 画面の文言を1か所にまとめたファイル（2026-09-30 開発部）。
 *
 * ■ 差し替えやすくするための約束
 * - 「決まった文」は画面のファイルに直接書かず、必ずここ（と fixedTexts.ts）から読む。
 * - 同意画面（A-4）・ログインの画面の1行（A-1）・預かり方の約束（A-5）の文は、要件定義書の枠から
 *   tools/copy-fixed-texts.mjs で「そのまま」写した src/constants/fixedTexts.ts を使う（手で打ち直さない）。
 *   要件定義書の版が上がったら、その道具を流し直すだけでよい。
 * - 同意画面（A-4）と「書き方の約束を読む」（E-2）は同じ CONSENT から出す（2か所で文がずれないように）。
 *
 * ■ いまの文の出どころ（2026-09-30 時点）
 * - 同意画面: 要件定義書 v0.6 7-1節の枠（確定）。
 * - ログインの画面の1行: 要件定義書 v0.6 7-2節 ①b（A13＝Resend の確認 7-2節の案1）。ワイヤーフレーム v0.3 A-1 のとおり句点で3段落に分ける。
 * - 預かり方の約束: 要件定義書 v0.6 8-6節の枠（確定。残る【】は制定日だけ → 画面では「未定」）。
 * - 常設の一文・欄のヒント: 要件定義書 7-2節 ②③。
 * - 中身（使う目的・見える人・保存先）が変わる直しをしたら RULES_VERSION を上げ、データ置き場の
 *   current_rules_version() を同じ配信で上げる（設計書 v0.3 8-2節）。言い回しだけなら上げない。
 */
import { FIXED } from "./fixedTexts";

/** 書き方の約束の版。データ置き場の public.current_rules_version()（いまは 1）と必ず同じにする。 */
export const RULES_VERSION = 1;

export const APP = {
  name: "子育てヒントノート",
  tagline: "〜 みんなで試したやり方 〜",
};

/** 文の中の「［預かり方の約束］」を、リンクの部分とそれ以外に分ける */
export type Piece = { text: string; link?: boolean };
const LINK = "［預かり方の約束］";
export function splitLink(s: string): Piece[] {
  const i = s.indexOf(LINK);
  if (i < 0) return [{ text: s }];
  // 画面には［ ］を出さず「預かり方の約束」の文字だけをリンクにする（ワイヤーフレーム v0.3 3-2節）
  return [{ text: s.slice(0, i) }, { text: "預かり方の約束", link: true }, { text: s.slice(i + LINK.length) }].filter((x) => x.text);
}

/** A-1 ログインの画面の文（要件 v0.6 7-2節 ①b）。句点ごとに段落（ワイヤーフレーム v0.3 A-1）。 */
export const LOGIN_PURPOSE: Piece[][] = splitSentences(FIXED.loginLine).map((x) => splitLink(x));

/** 句点で文に分ける（かっこの中の句点では分けない。例「（シンガポールの会社。東京のサーバ）」） */
function splitSentences(s: string): string[] {
  const out: string[] = [];
  let depth = 0;
  let cur = "";
  for (const ch of s) {
    cur += ch;
    if (ch === "（") depth++;
    else if (ch === "）") depth = Math.max(0, depth - 1);
    else if (ch === "。" && depth === 0) {
      out.push(cur);
      cur = "";
    }
  }
  if (cur.trim()) out.push(cur);
  return out;
}

/** A-1 の説明の3行（ワイヤーフレーム v0.3 A-1）。桁数は config.ts の OTP_LENGTH から入れる。 */
export const loginHelp = (digits: number) => [
  "パスワードはありません。",
  `メールに届く${digits}桁の番号で入ります。`,
  "初めての方・招待された方も、ここから。",
];

/**
 * 統括への確認 A15（同意画面・預かり方の約束に言葉を足すか・試したいの見える人の既定）。
 * **答えが出るまで推奨（1）で作る**（本部長 2026-09-30）。ここの1か所を変えるだけで切り替わる（ワイヤーフレーム v0.4 12-4節）。
 *   1 = 文を足す・試したいの既定は「みんな」／2 = 文を足す・試したいの既定は「自分の家庭だけ」／3 = 文を足さない（v0.6 の文）・既定は「みんな」
 */
export const A15_CHOICE = 1 as 1 | 2 | 3;
const USE_A15_TEXT = A15_CHOICE !== 3 && FIXED.a15 != null;
/** 「試したい」を選んだときの見える人の既定（要件 4-3b節・U-48） */
export const WANT_DEFAULT_VISIBILITY: "all" | "household" = A15_CHOICE === 2 ? "household" : "all";

/** A-4 同意画面・E-2 書き方の約束（要件 v0.7 7-1節の枠の文を、そのまま。A15 の推奨なら要件の指示どおり言葉を足した文）。 */
export const CONSENT = {
  /** 「第1版」の数字は RULES_VERSION（＝current_rules_version()）から出す（ワイヤーフレーム v0.3 A-4） */
  title: (version: number) => FIXED.consent.titleLine.replace(/第[0-9]+版/, `第${version}版`),
  intro: FIXED.consent.intro,
  rulesHeading: FIXED.consent.rulesHeading,
  rules: (USE_A15_TEXT ? FIXED.a15!.rules : FIXED.consent.rules) as readonly string[],
  custodyHeading: FIXED.consent.custodyHeading,
  custody: ((USE_A15_TEXT ? FIXED.a15!.custody : FIXED.consent.custody) as readonly string[]).map((x) => splitLink(x)),
  agree: FIXED.consent.buttons[0],
  decline: FIXED.consent.buttons[1],
};

/** A-5 預かり方の約束（要件 v0.6 8-6節の枠の文を、そのまま）。制定日の【】は画面では「未定」（本部長 2026-09-30）。 */
export const PRIVACY = {
  title: FIXED.privacy.title,
  sections: (USE_A15_TEXT ? FIXED.a15!.privacySections : FIXED.privacy.sections) as readonly { h: string; lines: readonly string[] }[],
  enacted: FIXED.privacy.enacted.includes("【") ? "制定: 未定" : FIXED.privacy.enacted,
  contactEmail: "soiyalab.contact@gmail.com",
};

/** A-3 の預かるものの文（要件 v0.7 7-1節 C94 の文のまま。［ ］は A-5 へのリンク） */
export const JOIN_CUSTODY = splitLink("預かるのは、メールアドレス・呼び名・書いた記録です（くわしくは［預かり方の約束］）。子どもの名前・生年月日は聞きません。");
/** E-2 の題（要件 v0.7 7-1節 C93。同意した日は出さない） */
export const rulesReadTitle = (version: number) => `書き方の約束 第${version}版（同意済み）`;

/** 常設の一文（要件 v0.5 7-2節 ③。B-4・C-1 の下に固定）。 */
export const DISCLAIMER = "一般的な情報ではなく、わが家の記録です。診断・治療の代わりになりません。心配なときは医師・専門機関へ。";

/** 入力欄のヒント（要件 v0.5 7-2節 ②）。 */
export const HINTS = {
  name: "みんなに見えます。子どもの名前・園の名前は書かない",
  note: "本を閉じて、自分の言葉で。必ず効く、とは書かない",
  heard: "名前は書かない（保育士、祖父母など）",
  visibility: "家庭の中だけにしたい話は「自分の家庭だけ」に。本の題名はみんなに見えます。",
  scoreEncourage: "合わなかった記録も、ほかの家庭の参考になります。",
};

/** 点数（要件 v0.5 4-3節）。色で良し悪しを付けない。 */
export const SCORES: { v: number; label: string; guide: string }[] = [
  { v: 1, label: "効果なし", guide: "何も変わらなかった。悪くなった場合もここ" },
  { v: 2, label: "その場だけ", guide: "その日は変わったが、数日で元に戻った" },
  { v: 3, label: "少し効いた", guide: "よくなったが、波がある・続かなかった" },
  { v: 4, label: "効いた", guide: "はっきりよくなり、1〜2週間続いた" },
  { v: 5, label: "よく効いた", guide: "はっきりよくなり、1か月以上続いた" },
];
/** （v0.9・C115）①が育てたいのときの言葉と基準の1行（要件 v0.9 4-3節の表のまま。数字・並び・データは同じ） */
export const SCORES_GROW: { v: number; label: string; guide: string }[] = [
  { v: 1, label: "変わらなかった", guide: "様子は変わらなかった。後戻りした場合もここ" },
  { v: 2, label: "その場だけ", guide: "その日はできたが、数日で元に戻った" },
  { v: 3, label: "少し伸びた", guide: "伸びたが、波がある（できる日とできない日がある）" },
  { v: 4, label: "伸びた", guide: "1〜2週間、続けて見られた" },
  { v: 5, label: "身についた", guide: "1か月以上続き、自分からできる" },
];
/** ③が付いている①の種類で、どちらの組を使うかを決める（C115） */
export const scoresFor = (kind: "trouble" | "grow" | null | undefined) => (kind === "grow" ? SCORES_GROW : SCORES);
/** 見出し「3 効き目」／「3 伸び」 */
export const scoreHeading = (kind: "trouble" | "grow" | null | undefined) => (kind === "grow" ? "伸び" : "効き目");
/** （v0.9・C116）直すモードで試したいから直すときの知らせ（ワイヤーフレーム v0.6 C-1 の文のまま） */
export const WANT_EDIT = {
  tag: (short: string) => `今日（${short}）になります`,
  notice: "試したいから直すので、日付は今日になります。違う日にするときは、試した日を選び直してください。",
  sameDay: (label: string) => `前と同じ日（${label}）を選んでも、保存すると今日になります。その日にしたいときは、保存した後にもう一度直してください。`,
};
export const TRIAL_GUIDE = "まだ分からない。あとで点数に直せます";
export const WANT_GUIDE = "まだ試していない。この年齢で試したい";

export type SourceType = "book" | "web" | "tv" | "heard" | "notebook" | "own" | "other";
/**
 * 出典7つ（要件 v0.8 4-3節・C105。この順）。tab は B-3 の出典のタブの文字（「このノート」に縮める。ワイヤーフレーム v0.5 B-3）。
 * 「このノートで知った」は詳細の欄なし。［うちでも試した］から開いたときに選ばれた状態にする（要件 4-7節）。
 */
export const SOURCE_TYPES: { v: SourceType; label: string; tab: string }[] = [
  { v: "book", label: "本", tab: "本" },
  { v: "web", label: "Web・記事", tab: "Web・記事" },
  { v: "tv", label: "テレビ", tab: "テレビ" },
  { v: "heard", label: "人から聞いた", tab: "人から聞いた" },
  { v: "notebook", label: "このノートで知った", tab: "このノート" },
  { v: "own", label: "うちで考えた", tab: "うちで考えた" },
  { v: "other", label: "その他", tab: "その他" },
];
/** テレビ・その他の詳細の欄（要件 v0.7 4-3節の文のまま） */
export const SOURCE_TEXT_FIELD: Record<"tv" | "other", { label: string; hint: string }> = {
  tv: { label: "番組名など", hint: "番組名・コーナー名など" },
  other: { label: "何で知った", hint: "例: 雑誌、園のおたより、SNS。個人の名前は書かない" },
};
export const SOURCE_TEXT_MAX = 40;

/** ①の種類（要件 v0.7 4-1・4-2節）と、種類ごとの呼び名 */
export type Kind = "trouble" | "grow";
/** タグの種類（要件 v0.8 4-5節。both＝困りごとにも育てたいにも出る。ことば・その他） */
export type TagKind = "trouble" | "grow" | "both";
export const TAG_KIND_LABEL: Record<TagKind, string> = { trouble: "困りごと", grow: "育てたい", both: "両方" };
export const KIND_WORDS: Record<Kind, { tab: string; problem: string; measure: string }> = {
  trouble: { tab: "困りごと", problem: "困りごと", measure: "対策" },
  grow: { tab: "育てたい", problem: "育てたいこと", measure: "やり方" },
};

/** 範囲の幅の上限（か月。要件 5-4節「3年までの範囲にしてください」） */
export const AGE_RANGE_MAX_MONTHS = 36;

/**
 * 統括への確認 A16（対策の名前が長いとき）。**答えが出るまで推奨（2）で作る**。
 * 2 = 名前は短い見出し（40字）のまま、長い説明は「一言」へ案内（要件 4-2節・ワイヤーフレーム v0.4 C-1）。
 */
export const A16_CHOICE = 2 as 1 | 2;
export const MEASURE_MAX = 40;
export const MEASURE_GUIDE = "短い名前で（40字まで）。やり方のくわしい説明は下の『一言』へ";
export const MEASURE_LIMIT_NOTICE = "40字までです。くわしい説明は『一言』に書けます";

/** 「人から聞いた」の候補（要件 v0.5 4-3節。U-31 仮置き） */
export const HEARD_FROM = ["保育士", "園・学校の先生", "小児科・医師", "保健師・助産師", "祖父母", "ほかの親", "その他"];

/** データ置き場の鍵の言葉 → 画面の文（設計書 v0.3 6章の表・ワイヤーフレーム A-3） */
export const ERRORS: Record<string, string> = {
  not_member: "このノートに入っていません。",
  not_visible: "選んだ困りごと（対策）が見つかりません。選び直してください。",
  future_date: "今日より後の日付は選べません。",
  limit_households: "このノートに入れる家庭の数の上限です。",
  limit_members: "このノートに入れる人の数の上限です。",
  stale_version: "アプリを更新してください。",
  forbidden: "この操作はできません。",
  /** （v0.5）①の種類に合わないタグを付けようとした（ふつうは画面が合うタグだけを出すので起きない。設計書 6章） */
  tag_kind_mismatch: "選んだ分類が、この種類に合いません。分類を選び直してください。",
  network: "通信を確かめて、もう一度押してください。",
  unknown: "うまくいきませんでした。もう一度押してください。",
};

export const JOIN_RESULT: Record<string, string> = {
  invalid: "このコードは使えません（間違い・期限切れ・使用済み・取り消し）。招待した人に新しいコードをもらってください。",
  locked: "まちがいが続いたため、しばらく入れられません。1時間ほどたってから、もう一度お試しください。",
  full: "このノートの人数がいっぱいです。招待した人に伝えてください。",
  already_member: "このノートには、すでに入っています。",
};
