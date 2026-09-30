/**
 * delete-space（2026-09-30 開発部。設計書 v0.4 7-2節・要件 8-5節・E-8〈P1〉）
 * その場の管理者がノートを丸ごと消す。画面（E-8）はまだ作っていない（P1。当面は運営者の手作業でも可）。
 *   入力: { space_id: uuid } → delete_space_data(本人, space_id) → 返ったログイン ID（もうどの場にも入っていない人）を消す
 * ---- 破壊的な操作についての注記: ノートの全データ・ログインを消す（元に戻せない）。実行前に報告書に記録した。
 */
import { adminClient, callerId, deleteLogins, errorKey, json, preflight } from "../_shared/common.ts";

Deno.serve(async (req: Request) => {
  const p = preflight(req);
  if (p) return p;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const admin = adminClient();
  const uid = await callerId(req, admin);
  if (!uid) return json({ error: "invalid_token" }, 401);

  let body: { space_id?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (typeof body.space_id !== "string") return json({ error: "space_id_required" }, 400);

  const { data, error } = await admin.rpc("delete_space_data", { p_actor_auth_uid: uid, p_space_id: body.space_id });
  if (error) {
    const key = errorKey(error);
    return json({ error: key }, key === "internal_error" ? 500 : key === "forbidden" ? 403 : 400);
  }
  const failed = await deleteLogins(admin, (data as string[] | null) ?? []);
  return json({ ok: true, logins_deleted: ((data as string[] | null) ?? []).length - failed.length, retry: failed.length > 0 });
});
