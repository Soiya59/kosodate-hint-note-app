/**
 * Edge Function の共通の部品（2026-09-30 開発部。設計書 v0.4 7-2節）。
 * - 画面から送られてきたログインの証明（Authorization: Bearer <JWT>）で本人を確かめる（auth.getUser）。
 * - service_role の鍵は Edge Function の中（Supabase が用意する環境変数）だけで使う。画面・リポジトリには置かない。
 * - Deno（Supabase Edge Runtime）で動く。app 側の tsc の対象外（tsconfig.json で supabase/** を外している）。
 */
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

export function preflight(req: Request): Response | null {
  return req.method === "OPTIONS" ? new Response("ok", { headers: cors }) : null;
}

function env(name: string): string {
  return Deno.env.get(name) ?? "";
}

/** service_role のクライアント（RLS を通らない。関数の中で本人・権限を確かめてから使う） */
export function adminClient(): SupabaseClient {
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  return createClient(env("SUPABASE_URL"), key, { auth: { persistSession: false, autoRefreshToken: false } });
}

/** 送られてきたログインの証明から、本人のログイン ID を得る。無い・古いなら null */
export async function callerId(req: Request, admin: SupabaseClient): Promise<string | null> {
  const h = req.headers.get("Authorization") ?? "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}

/** データ置き場の関数の失敗を、画面が出し分けに使う鍵の言葉にする */
export function errorKey(e: { message?: string; code?: string } | null): string {
  const m = e?.message ?? "";
  for (const k of ["admin_cannot_leave", "cannot_delete_own_household", "forbidden", "not_found"]) if (m.includes(k)) return k;
  if (e?.code === "42501") return "forbidden";
  return "internal_error";
}

/** 戻ってきたログイン ID を消す（同意の記録・招待の試行も外部キーで一緒に消える）。失敗したら ID を返す */
export async function deleteLogins(admin: SupabaseClient, ids: (string | null)[]): Promise<string[]> {
  const failed: string[] = [];
  for (const id of ids) {
    if (!id) continue;
    const { error } = await admin.auth.admin.deleteUser(id);
    if (error) failed.push(id);
  }
  return failed;
}
