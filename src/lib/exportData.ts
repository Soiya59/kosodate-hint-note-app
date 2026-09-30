/**
 * 書き出し（E-3・F-30）。export_visible_data の JSON から、読むための形（Markdown）と表の形（CSV）を作る。
 * 範囲は「自分に見える分」（RLS。他家庭の非公開の③とそれしか持たない①②は入らない）。メール・ログイン ID は入らない。
 */
import { KIND_WORDS, scoresFor, SOURCE_TYPES, type Kind, type SourceType } from "@/constants/texts";
import { ageRangeLabel } from "./format";

type J = {
  exported_at: string;
  space: { name: string } | null;
  households: { id: string; display_name: string }[];
  tags: { id: string; name: string }[];
  problems: { id: string; name: string; kind: Kind; tag_ids: string[] }[];
  measures: { id: string; problem_id: string; name: string }[];
  books: { id: string; title: string; author: string | null }[];
  trials: {
    id: string; measure_id: string; household_id: string; status: "scored" | "trying" | "want"; score: number | null;
    age_months: number; age_months_to: number | null; source_type: SourceType; book_id: string | null; source_url: string | null;
    heard_from: string | null; source_text: string | null; note: string | null; tried_on: string; visibility: "all" | "household";
    /** （v0.5・Y8）書いた人の呼び名（退会などで空なら null） */
    created_by_name?: string | null;
  }[];
};

const STATUS = { scored: "試した", trying: "試し中", want: "試したい" } as const;

function scoreText(t: J["trials"][number], kind?: Kind) {
  // ①が育てたいなら育てたいの言葉（C115）
  if (t.status === "scored") return `${t.score} ${scoresFor(kind).find((s) => s.v === t.score)?.label ?? ""}`;
  return STATUS[t.status];
}
function sourceText(t: J["trials"][number], books: Map<string, J["books"][number]>) {
  const label = SOURCE_TYPES.find((s) => s.v === t.source_type)?.label ?? t.source_type;
  const b = t.book_id ? books.get(t.book_id) : null;
  const detail = b ? `『${b.title}』${b.author ?? ""}` : t.source_url ?? t.heard_from ?? t.source_text ?? "";
  return detail ? `${label} ${detail}` : label;
}
const csvCell = (v: string | number | null | undefined) => {
  const s = v == null ? "" : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

export function buildExport(raw: Record<string, unknown>, myHouseholdId: string): { markdown: string; csv: string; count: number } {
  const j = raw as unknown as J;
  const hh = new Map(j.households.map((h) => [h.id, h.display_name]));
  const hhName = (id: string) => (id === myHouseholdId ? `うち（${hh.get(id) ?? ""}）` : hh.get(id) ?? "退会した家庭");
  /** 「呼び名（家庭名）」。書いた人が空なら家庭名だけ（画面と同じ見せ方） */
  const writer = (t: J["trials"][number]) => {
    const h = t.household_id === myHouseholdId ? "うち" : hh.get(t.household_id) ?? "退会した家庭";
    return t.created_by_name ? `${t.created_by_name}（${h}）` : hhName(t.household_id);
  };
  const tags = new Map(j.tags.map((t) => [t.id, t.name]));
  const books = new Map(j.books.map((b) => [b.id, b]));
  const date = j.exported_at.slice(0, 10);

  const md: string[] = [`# ${j.space?.name ?? "ノート"} の記録（${date} に書き出し）`, "", "子育てヒントノートから書き出した、あなたに見える記録です。ほかの家庭の記録は、許可なく外に出さないでください（書き方の約束6）。", ""];
  if (j.problems.length === 0) md.push("まだ記録はありません。");
  for (const p of j.problems) {
    const W = KIND_WORDS[p.kind ?? "trouble"];
    md.push(`## ${p.name}（${W.problem}）`);
    const tg = (p.tag_ids ?? []).map((t) => tags.get(t)).filter(Boolean);
    if (tg.length) md.push(`分類: ${tg.join("・")}`);
    md.push("");
    for (const m of j.measures.filter((x) => x.problem_id === p.id)) {
      md.push(`### ${m.name}（${W.measure}）`);
      const ts = j.trials.filter((t) => t.measure_id === m.id);
      if (ts.length === 0) md.push("- まだ記録がありません");
      for (const t of ts) {
        md.push(`- ${writer(t)}: ${scoreText(t, p.kind)}・${ageRangeLabel(t.age_months, t.age_months_to)}・${t.tried_on}・どこで知った: ${sourceText(t, books)}${t.visibility === "household" ? "・自分の家庭だけ" : ""}`);
        if (t.note) md.push(`  - 一言: ${t.note.replace(/\n/g, " ")}`);
      }
      md.push("");
    }
  }

  const header = ["種類", "困りごと・育てたいこと", "対策・やり方", "家庭", "書いた人", "状態", "点数", "点数の言葉", "年齢", "出典の種類", "出典の詳細", "一言", "日付", "見える人"];
  const rows = [header.join(",")];
  for (const t of j.trials) {
    const m = j.measures.find((x) => x.id === t.measure_id);
    const p = m ? j.problems.find((x) => x.id === m.problem_id) : undefined;
    const b = t.book_id ? books.get(t.book_id) : null;
    rows.push([
      KIND_WORDS[p?.kind ?? "trouble"].tab, p?.name, m?.name, hhName(t.household_id), t.created_by_name ?? "", STATUS[t.status], t.score,
      t.status === "scored" ? scoresFor(p?.kind).find((s) => s.v === t.score)?.label ?? "" : "",
      ageRangeLabel(t.age_months, t.age_months_to), SOURCE_TYPES.find((s) => s.v === t.source_type)?.label ?? t.source_type,
      b ? `${b.title}${b.author ? ` ${b.author}` : ""}` : t.source_url ?? t.heard_from ?? t.source_text ?? "",
      t.note, t.tried_on, t.visibility === "all" ? "みんな" : "自分の家庭だけ",
    ].map(csvCell).join(","));
  }
  // Excel で文字化けしないよう、CSV の先頭に BOM を付ける
  return { markdown: md.join("\n"), csv: "﻿" + rows.join("\r\n"), count: j.trials.length };
}
