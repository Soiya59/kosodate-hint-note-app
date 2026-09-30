/**
 * delete-household（2026-09-30 開発部。設計書 v0.4 7-2節・要件 8-5節）
 * その場の管理者が家庭を消す（E-5）。その家庭のメンバー・③（非公開を含む）・招待が消える。
 * 他家庭の③が付いた①②は残る。管理者の家庭は消せない（cannot_delete_own_household）。
 *   入力: { household_id: uuid } → delete_household_data(本人, household_id) → 返ったログイン ID を消す
 * ---- 破壊的な操作についての注記: 家庭・メンバー・③・ログインを消す（元に戻せない）。実行前に報告書に記録した。
 */
import { adminClient, callerId, deleteLogins, errorKey, json, preflight } from "../_shared/common.ts";

Deno.serve(async (req: Request) => {
  const p = preflight(req);
  if (p) return p;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const admin = adminClient();
  const uid = await callerId(req, admin);
  if (!uid) return json({ error: "invalid_token" }, 401);

  let body: { household_id?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (typeof body.household_id !== "string") return json({ error: "household_id_required" }, 400);

  const { data, error } = await admin.rpc("delete_household_data", { p_actor_auth_uid: uid, p_household_id: body.household_id });
  if (error) {
    const key = errorKey(error);
    return json({ error: key }, key === "internal_error" ? 500 : key === "forbidden" ? 403 : 400);
  }
  const failed = await deleteLogins(admin, (data as string[] | null) ?? []);
  return json({ ok: true, logins_deleted: ((data as string[] | null) ?? []).length - failed.length, retry: failed.length > 0 });
});
