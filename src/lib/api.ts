/**
 * データ置き場の呼び出し（2026-09-30 開発部）。設計書 v0.3 14-2節「画面から呼ぶもの」のうち、最低限の画面で使うもの。
 * - ①②は必ず save_trial で作る。表 problems・measures に .insert().select()・.upsert() をしない（設計書 6-1節。必ず権限エラーになる）。
 * - ③の点数を直すときは表 trials を直接 UPDATE。結果は受け取らない（.select() を付けない）。
 */
import { supabase } from "./supabase";
import type { Kind, SourceType } from "@/constants/texts";

export type TrialStatus = "scored" | "trying" | "want";

export type Space = {
  o_space_id: string;
  o_space_name: string;
  o_household_id: string;
  o_household_name: string;
  o_member_id: string;
  o_role: "admin" | "member";
  o_max_households: number;
  o_max_members: number;
  o_admin_member_id: string | null;
  o_admin_display_name: string | null;
};

/** （v0.5）kind＝困りごと／育てたい／両方、grow_sort_order＝育てたいの並び（困りごとだけのタグは null） */
export type Tag = { id: string; name: string; sort_order: number; is_other: boolean; kind: "trouble" | "grow" | "both"; grow_sort_order: number | null };

export type ProblemRow = {
  o_problem_id: string;
  o_name: string;
  o_created_household_id: string | null;
  o_tag_ids: string[];
  o_measure_count: number;
  o_trial_count: number;
  o_sort_at: string;
  o_kind: Kind;
};

export type TrialJson = {
  trial_id: string;
  household_id: string;
  score: number | null;
  /** （v0.4）試した／試し中／試したい。「点数が空＝試し中」とは判定しない（試したいも点数が空。設計書 15-7節） */
  status: TrialStatus;
  age_months: number;
  age_months_to: number | null;
  source_type: SourceType;
  source_text: string | null;
  book_title: string | null;
  book_author: string | null;
  source_url: string | null;
  heard_from: string | null;
  note: string | null;
  tried_on: string;
  visibility: "all" | "household";
  created_by_member_id: string | null;
  /** 書いた人の呼び名（退会などで空なら null） */
  created_by_name: string | null;
  household_name: string | null;
  in_age: boolean;
};

export type MeasureRow = {
  o_measure_id: string;
  o_name: string;
  o_created_household_id: string | null;
  o_group: number;
  o_best_score: number | null;
  o_household_count: number;
  o_latest_tried_on: string | null;
  o_trial_count: number;
  o_trials: TrialJson[];
};

export type Suggest = { id: string; name: string; exact: boolean; kind?: Kind };

/** データ置き場の失敗を、画面が出し分けに使う「鍵の言葉」にする（設計書 6章の表） */
export class ApiError extends Error {
  constructor(public key: string, public code?: string, message?: string) {
    super(message ?? key);
  }
}

const KNOWN = [
  "not_member", "consent_required", "not_visible", "immutable_column", "future_date",
  "limit_households", "limit_members", "cross_space", "problem_required", "measure_required",
  "measure_problem_mismatch", "stale_version", "forbidden", "not_signed_in", "tag_kind_mismatch",
];

function toApiError(e: { message?: string; code?: string } | null | undefined): ApiError {
  const msg = e?.message ?? "";
  const key = KNOWN.find((k) => msg.includes(k));
  if (key) return new ApiError(key, e?.code, msg);
  if (e?.code === "23514") return new ApiError("check_violation", e.code, msg);
  if (e?.code === "23505") return new ApiError("unique_violation", e.code, msg);
  if (e?.code === "42501") return new ApiError("forbidden", e.code, msg);
  if (/fetch|network|Failed to fetch|NetworkError/i.test(msg)) return new ApiError("network", e?.code, msg);
  return new ApiError("unknown", e?.code, msg);
}

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw toApiError(error);
  return data as T;
}

// ---- ログイン・同意・参加 ----
export const listMySpaces = () => rpc<Space[]>("list_my_spaces");
export const hasAgreedCurrentRules = () => rpc<boolean>("has_agreed_current_rules");
export const recordRulesConsent = (version: number) => rpc<void>("record_rules_consent", { p_version: version });
export const joinWithInviteCode = (code: string, displayName: string) =>
  rpc<string>("join_with_invite_code", { p_code: code, p_display_name: displayName });

// ---- 見る ----
export async function listTags(spaceId: string): Promise<Tag[]> {
  const { data, error } = await supabase
    .from("tags")
    .select("id,name,sort_order,is_other,kind,grow_sort_order")
    .eq("space_id", spaceId)
    .order("sort_order");
  if (error) throw toApiError(error);
  return data as Tag[];
}

export async function listHouseholds(spaceId: string): Promise<{ id: string; display_name: string }[]> {
  const { data, error } = await supabase.from("households").select("id,display_name").eq("space_id", spaceId);
  if (error) throw toApiError(error);
  return data ?? [];
}

export const searchProblems = (p: {
  spaceId: string; query?: string; tagId?: string | null; ageYears?: number | null; ageYearsTo?: number | null;
  kind?: Kind | null; limit: number; offset: number;
}) =>
  rpc<ProblemRow[]>("search_problems", {
    p_space_id: p.spaceId,
    p_query: p.query || null,
    p_tag_id: p.tagId ?? null,
    p_age_years: p.ageYears ?? null,
    p_limit: p.limit,
    p_offset: p.offset,
    p_kind: p.kind ?? null,
    p_age_years_to: p.ageYearsTo ?? null,
  });

/** 年齢の一覧（1歳ごと。範囲の③は入る歳それぞれに数える）。v0.5 でまとまりの関数は消えた（設計書 Y7） */
export const listAgeCounts = (spaceId: string) =>
  rpc<{ o_age_years: number; o_problem_count: number }[]>("list_age_counts", { p_space_id: spaceId });

export const listMeasures = (problemId: string, sourceType?: string | null, ageYears?: number | null, ageYearsTo?: number | null) =>
  rpc<MeasureRow[]>("list_measures", {
    p_problem_id: problemId,
    p_source_type: sourceType ?? null,
    p_age_years: ageYears ?? null,
    p_age_years_to: ageYearsTo ?? null,
  });

export async function getProblem(id: string) {
  const { data, error } = await supabase
    .from("problems")
    .select("id,name,kind,space_id,created_household_id,problem_tags(tag_id)")
    .eq("id", id)
    .maybeSingle();
  if (error) throw toApiError(error);
  return data as null | {
    id: string; name: string; kind: Kind; space_id: string; created_household_id: string | null; problem_tags: { tag_id: string }[];
  };
}

export async function getMeasure(id: string) {
  const { data, error } = await supabase
    .from("measures")
    .select("id,name,problem_id,created_household_id,problems(name,kind)")
    .eq("id", id)
    .maybeSingle();
  if (error) throw toApiError(error);
  if (!data) return null;
  type P = { name: string; kind: Kind };
  const raw = (data as { problems: P | P[] | null }).problems;
  const p = Array.isArray(raw) ? raw[0] : raw;
  const problemName = p?.name;
  return {
    id: data.id as string,
    name: data.name as string,
    problem_id: data.problem_id as string,
    created_household_id: data.created_household_id as string | null,
    problem_name: problemName ?? "",
    problem_kind: (p?.kind ?? "trouble") as Kind,
  };
}

// ---- 候補（F-17） ----
export async function suggestProblems(spaceId: string, text: string): Promise<Suggest[]> {
  const rows = await rpc<{ o_problem_id: string; o_name: string; o_is_exact: boolean; o_kind: Kind }[]>("suggest_problems", {
    p_space_id: spaceId, p_text: text,
  });
  return rows.map((r) => ({ id: r.o_problem_id, name: r.o_name, exact: r.o_is_exact, kind: r.o_kind }));
}
export async function suggestMeasures(problemId: string, text: string): Promise<Suggest[]> {
  const rows = await rpc<{ o_measure_id: string; o_name: string; o_is_exact: boolean }[]>("suggest_measures", {
    p_problem_id: problemId, p_text: text,
  });
  return rows.map((r) => ({ id: r.o_measure_id, name: r.o_name, exact: r.o_is_exact }));
}
export async function suggestBooks(spaceId: string, text: string) {
  const rows = await rpc<{ o_book_id: string; o_title: string; o_author: string | null; o_is_exact: boolean }[]>(
    "suggest_books", { p_space_id: spaceId, p_text: text },
  );
  return rows.map((r) => ({ id: r.o_book_id, title: r.o_title, author: r.o_author, exact: r.o_is_exact }));
}

// ---- 書く ----
export const ensureBook = (spaceId: string, title: string, author: string | null) =>
  rpc<string>("ensure_book", { p_space_id: spaceId, p_title: title, p_author: author });

export type SaveTrialInput = {
  spaceId: string;
  problemId: string | null;
  problemName: string | null;
  tagIds: string[] | null;
  measureId: string | null;
  measureName: string | null;
  score: number | null;
  ageMonths: number;
  ageMonthsTo: number | null;
  problemKind: Kind | null;
  status: TrialStatus;
  sourceType: SourceType;
  sourceText: string | null;
  bookId: string | null;
  sourceUrl: string | null;
  heardFrom: string | null;
  note: string | null;
  triedOn: string | null;
  visibility: "all" | "household";
};

export const saveTrial = (i: SaveTrialInput) =>
  rpc<{ problem_id: string; measure_id: string; trial_id: string }>("save_trial", {
    p_space_id: i.spaceId,
    p_problem_id: i.problemId,
    p_problem_name: i.problemName,
    p_tag_ids: i.tagIds,
    p_measure_id: i.measureId,
    p_measure_name: i.measureName,
    p_score: i.score,
    p_age_months: i.ageMonths,
    p_source_type: i.sourceType,
    p_book_id: i.bookId,
    p_source_url: i.sourceUrl,
    p_heard_from: i.heardFrom,
    p_note: i.note,
    p_tried_on: i.triedOn,
    p_visibility: i.visibility,
    p_problem_kind: i.problemKind,
    p_status: i.status,
    p_age_months_to: i.ageMonthsTo,
    p_source_text: i.sourceText,
  });

/** 試し中 → 点数（C-3）。表 trials を直接 UPDATE（RLS。自家庭の③だけ）。結果は受け取らない。 */
export async function setTrialScore(trialId: string, score: number) {
  const { error, count } = await supabase.from("trials").update({ score }, { count: "exact" }).eq("id", trialId);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("not_visible");
}

/** （v0.4）試したい → 試し中（C-4）。日付はトリガーが今日にする。結果は受け取らない（.select() を付けない。設計書 15-7節） */
export async function startTrying(trialId: string, ageMonths: number, ageMonthsTo: number | null) {
  const { error, count } = await supabase
    .from("trials")
    .update({ status: "trying", age_months: ageMonths, age_months_to: ageMonthsTo }, { count: "exact" })
    .eq("id", trialId);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("not_visible");
}

/** （v0.4）試したい → 点数（C-3 の試したいの形）。年齢も確かめて送る。日付はトリガーが今日にする */
export async function scoreWant(trialId: string, score: number, ageMonths: number, ageMonthsTo: number | null) {
  const { error, count } = await supabase
    .from("trials")
    .update({ score, age_months: ageMonths, age_months_to: ageMonthsTo }, { count: "exact" })
    .eq("id", trialId);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("not_visible");
}

// ---- ①②の名前・タグ・種類を直す（D-1。true/false だけが返る。要件 2-5節） ----
export const renameProblem = (id: string, name: string) => rpc<boolean>("rename_problem", { p_problem_id: id, p_name: name });
export const renameMeasure = (id: string, name: string) => rpc<boolean>("rename_measure", { p_measure_id: id, p_name: name });
export const setProblemTags = (id: string, tagIds: string[]) => rpc<boolean>("set_problem_tags", { p_problem_id: id, p_tag_ids: tagIds });
export const setProblemKind = (id: string, kind: Kind) => rpc<boolean>("set_problem_kind", { p_problem_id: id, p_kind: kind });

/** ③を消す（D-2）。表 trials を直接 DELETE（RLS）。同意がなくても消せる（要件 F-03）。 */
export async function deleteTrial(trialId: string) {
  const { error, count } = await supabase.from("trials").delete({ count: "exact" }).eq("id", trialId);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("not_visible");
}

// ---- 自分の呼び名（D-4。要件 F-04b） ----
/** 表 members の自分の行の display_name だけを UPDATE（設計書 v0.3 14-2節「自分の表示名」・RLS members_update_self）。結果は受け取らない。 */
export async function updateMyDisplayName(memberId: string, name: string) {
  const { error, count } = await supabase.from("members").update({ display_name: name }, { count: "exact" }).eq("id", memberId);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("forbidden");
}

// ---- 消す（D-2）・直す（C-1 の直すモード） ----
export const deleteProblem = (id: string) => rpc<boolean>("delete_problem", { p_problem_id: id });
export const deleteMeasure = (id: string) => rpc<boolean>("delete_measure", { p_measure_id: id });

export type TrialRow = {
  id: string; measure_id: string; household_id: string; score: number | null; status: TrialStatus;
  age_months: number; age_months_to: number | null; source_type: SourceType; book_id: string | null;
  source_url: string | null; heard_from: string | null; source_text: string | null; note: string | null;
  tried_on: string; visibility: "all" | "household"; books: { title: string; author: string | null } | null;
};
export async function getTrial(id: string): Promise<TrialRow | null> {
  const { data, error } = await supabase
    .from("trials")
    .select("id,measure_id,household_id,score,status,age_months,age_months_to,source_type,book_id,source_url,heard_from,source_text,note,tried_on,visibility,books(title,author)")
    .eq("id", id)
    .maybeSingle();
  if (error) throw toApiError(error);
  if (!data) return null;
  const b = (data as { books: unknown }).books;
  return { ...(data as unknown as TrialRow), books: (Array.isArray(b) ? b[0] : b) ?? null } as TrialRow;
}
/** ③を直す（表 trials を直接 UPDATE。RLS＝自家庭の③だけ。結果は受け取らない）。出典の種類に合わない詳細は空にして送る（chk_trials_source_detail） */
export async function updateTrial(id: string, patch: Partial<Omit<TrialRow, "id" | "books" | "measure_id" | "household_id">>) {
  const { error, count } = await supabase.from("trials").update(patch, { count: "exact" }).eq("id", id);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("not_visible");
}

// ---- Edge Function（削除・退会。設計書 7-2節。ログインの情報を消すため service_role が要るので、Supabase の上で動かす） ----
async function callFunction(name: string, body: Record<string, unknown>): Promise<Record<string, unknown>> {
  const { data, error } = await supabase.functions.invoke(name, { body });
  if (error) {
    let key = "unknown";
    try {
      const ctx = (error as { context?: Response }).context;
      if (ctx && typeof ctx.json === "function") key = ((await ctx.json()) as { error?: string }).error ?? "unknown";
    } catch { /* 中身が読めないときは unknown */ }
    if (/fetch|network/i.test(error.message) && key === "unknown") key = "network";
    throw new ApiError(key, undefined, error.message);
  }
  return (data ?? {}) as Record<string, unknown>;
}
/** 退会（本人）・メンバーを外す（管理者）。deleteTrials は画面の選択を必ず送る（既定: 本人＝消す・管理者が外す＝残す） */
export const deleteMember = (memberId: string, deleteTrials: boolean) => callFunction("delete-member", { member_id: memberId, delete_trials: deleteTrials });
export const deleteHousehold = (householdId: string) => callFunction("delete-household", { household_id: householdId });

// ---- 管理者（E-5 家庭とメンバー・E-6 招待コード） ----
export type MemberRow = { id: string; household_id: string; display_name: string; role: "admin" | "member" };
export async function listMembers(spaceId: string): Promise<MemberRow[]> {
  const { data, error } = await supabase.from("members").select("id,household_id,display_name,role").eq("space_id", spaceId).order("created_at");
  if (error) throw toApiError(error);
  return (data ?? []) as MemberRow[];
}
/** 家庭を作る（その場の管理者。表 households に INSERT。結果は受け取らない） */
export async function createHousehold(spaceId: string, name: string) {
  const { error } = await supabase.from("households").insert({ space_id: spaceId, display_name: name });
  if (error) throw toApiError(error);
}
export async function renameHousehold(id: string, name: string) {
  const { error, count } = await supabase.from("households").update({ display_name: name }, { count: "exact" }).eq("id", id);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("forbidden");
}
export async function householdDeletionPreview(id: string) {
  const rows = await rpc<{ o_trial_count: number; o_member_count: number }[]>("household_deletion_preview", { p_household_id: id });
  return rows[0] ?? { o_trial_count: 0, o_member_count: 0 };
}
export const createInvite = (householdId: string) => rpc<string>("create_invite", { p_household_id: householdId });
export type InviteRow = { id: string; household_id: string; expires_at: string };
/** 使えるコード（使っていない・取り消していない・期限内）。コードの文字は持っていない（設計書 8-1節） */
export async function listUsableInvites(spaceId: string): Promise<InviteRow[]> {
  const { data, error } = await supabase
    .from("invites")
    .select("id,household_id,expires_at")
    .eq("space_id", spaceId)
    .is("used_at", null)
    .is("revoked_at", null)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false });
  if (error) throw toApiError(error);
  return (data ?? []) as InviteRow[];
}
export async function revokeInvite(id: string) {
  const { error, count } = await supabase.from("invites").update({ revoked_at: new Date().toISOString() }, { count: "exact" }).eq("id", id);
  if (error) throw toApiError(error);
  if (count === 0) throw new ApiError("forbidden");
}

/** （v0.5）タグを足す（E-7・管理者）。種類を送る。並び順はデータ置き場のトリガーが種類ごとに決める。結果は受け取らない */
export async function createTag(spaceId: string, name: string, kind: "trouble" | "grow" | "both") {
  const { error } = await supabase.from("tags").insert({ space_id: spaceId, name, kind });
  if (error) throw toApiError(error);
}

// ---- 書き出し（E-3。F-30） ----
export const exportVisibleData = (spaceId: string) => rpc<Record<string, unknown>>("export_visible_data", { p_space_id: spaceId });
