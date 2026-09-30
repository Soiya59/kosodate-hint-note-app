/**
 * delete-member（2026-09-30 開発部。設計書 v0.4 7-2節・要件 8-5節・F-31）
 * 本人の退会（E-4）と、その場の管理者がメンバーを外す（E-5）の両方。
 *   入力: { member_id: uuid, delete_trials: boolean | null }
 *   1. ログインの証明から本人を確かめる
 *   2. service_role で delete_member_data(本人, member_id, delete_trials) を呼ぶ
 *      delete_trials は受け取ったまま渡す（null も null のまま。関数の中の既定＝本人は「消す」・管理者が外すは「残す」。V4）
 *      同じ場か・本人か管理者か・対象が管理者でないかは関数の中で確かめる
 *   3. ログイン ID が返ったら（もうどの場にも入っていない）ログインを消す
 *   4. { ok: true, login_deleted } を返す
 * ---- 破壊的な操作についての注記: メンバーの行・（選べば）その人の③・ログインを消す（元に戻せない）。
 *      開発部/成果物/招待の前に要る画面（2026-09-30）.md に実行前に記録した。
 */
import { adminClient, callerId, deleteLogins, errorKey, json, preflight } from "../_shared/common.ts";

Deno.serve(async (req: Request) => {
  const p = preflight(req);
  if (p) return p;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const admin = adminClient();
  const uid = await callerId(req, admin);
  if (!uid) return json({ error: "invalid_token" }, 401);

  let body: { member_id?: unknown; delete_trials?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (typeof body.member_id !== "string") return json({ error: "member_id_required" }, 400);
  const deleteTrials = typeof body.delete_trials === "boolean" ? body.delete_trials : null;

  const { data, error } = await admin.rpc("delete_member_data", {
    p_actor_auth_uid: uid,
    p_member_id: body.member_id,
    p_delete_trials: deleteTrials,
  });
  if (error) {
    const key = errorKey(error);
    return json({ error: key }, key === "internal_error" ? 500 : key === "forbidden" ? 403 : 400);
  }
  const failed = await deleteLogins(admin, [data as string | null]);
  if (failed.length) return json({ ok: true, login_deleted: false, retry: true }, 200); // やり直せば消える（設計書 7-2節）
  return json({ ok: true, login_deleted: data != null });
});
