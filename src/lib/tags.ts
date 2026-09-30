/**
 * タグを種類で出し分けて並べる（要件 v0.8 4-5節・ワイヤーフレーム v0.5 B-1・C-1・D-1）。
 *   困りごと＝困りごと＋両方（sort_order の順）／育てたい＝育てたい＋両方（grow_sort_order の順）
 *   すべて＝全部（sort_order の順＝困りごと → 育てたいだけ → その他が最後に1つ）
 */
import type { Tag } from "./api";

export function tagsForKind(tags: Tag[], kind: "trouble" | "grow" | null): Tag[] {
  if (kind == null) return [...tags].sort((a, b) => a.sort_order - b.sort_order);
  if (kind === "trouble") return tags.filter((t) => t.kind !== "grow").sort((a, b) => a.sort_order - b.sort_order);
  return tags.filter((t) => t.kind !== "trouble").sort((a, b) => (a.grow_sort_order ?? 0) - (b.grow_sort_order ?? 0));
}

/** その①の種類に合うタグか（両方は常に合う） */
export const fitsKind = (t: Tag | undefined, kind: "trouble" | "grow") => !!t && (t.kind === "both" || t.kind === kind);
