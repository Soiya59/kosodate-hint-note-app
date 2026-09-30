/** 年齢・日付の表示（要件 v0.5 第5章・設計書 v0.3 第4章・5-2節の7） */

/** 月齢 → 「3歳」「3歳半」 */
export function ageLabel(months: number): string {
  const y = Math.floor(months / 12);
  return months % 12 === 6 ? `${y}歳半` : `${y}歳`;
}

/** 選べる年齢（0歳〜18歳の半年刻み・37個）。値は月齢。 */
export const AGE_CHOICES: number[] = Array.from({ length: 37 }, (_, i) => i * 6);

/** 日本時間の今日（YYYY-MM-DD）。端末の時計の地域に関係なく日本時間で計算する。 */
export function todayJst(): string {
  const d = new Date(Date.now() + 9 * 3600 * 1000);
  return d.toISOString().slice(0, 10);
}

/** 試し中の日数＝日本時間の今日 − 試した日 ＋ 1 */
export function trialDays(triedOn: string): number {
  const a = Date.parse(`${todayJst()}T00:00:00Z`);
  const b = Date.parse(`${triedOn}T00:00:00Z`);
  return Math.floor((a - b) / 86400000) + 1;
}

/** 2026-09-20 → 9/20 */
export function shortDate(d: string): string {
  const [, m, day] = d.split("-");
  return `${Number(m)}/${Number(day)}`;
}

export function isValidDate(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const t = Date.parse(`${s}T00:00:00Z`);
  return !Number.isNaN(t) && new Date(t).toISOString().slice(0, 10) === s;
}

/** 全角の数字・英字を半角に、空白を取る（番号・招待コードの入力のゆれ） */
export function toHalfWidth(s: string): string {
  return s.replace(/[０-９Ａ-Ｚａ-ｚ]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0)).replace(/[\s　]/g, "");
}

/** 年齢（範囲も）の表示: 「2歳」「1〜2歳」「1歳半〜3歳」（要件 v0.7 5-4節。半のときは両方に「歳」） */
export function ageRangeLabel(from: number, to?: number | null): string {
  if (to == null || to === from) return ageLabel(from);
  const a = ageLabel(from);
  const b = ageLabel(to);
  if (from % 12 === 0 && to % 12 === 0) return `${from / 12}〜${b}`;
  return `${a}〜${b}`;
}

/** 年齢の値（から・まで）。まで が null なら1つの年齢 */
export type AgeValue = { from: number; to: number | null };
export const sameAge = (a: AgeValue, b: AgeValue) => a.from === b.from && (a.to ?? null) === (b.to ?? null);
