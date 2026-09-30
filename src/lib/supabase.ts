/**
 * Supabase につなぐ部品（2026-09-30 開発部）。
 * - 使う鍵は公開用の鍵（publishable / anon）だけ。service_role・secret は画面に入れない（開発部 CLAUDE.md）。
 * - 値は .env.local（公開しない）の EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY から読む。
 * - 開発・通し確認ではローカルの Supabase（Docker）。本番の値は GitHub の repository variables から、配信のときだけ
 *   書き出しに入る（.github/workflows/deploy-pages.yml。ファイルには書かない）。公開用の鍵は画面に入る前提の鍵。
 * - detectSessionInUrl: false（URL から戻るログインの流れを使わない。設計書 v0.3 9-1節の3）。
 */
import "./polyfill";
import { createClient } from "@supabase/supabase-js";
import { Platform } from "react-native";
import { storage } from "./storage";

const envUrl = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "";
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? "";

/**
 * 開発のときだけの手当て: .env.local の URL が 127.0.0.1 / localhost のとき、
 * スマホ（同じ Wi-Fi）から http://<パソコンの IP>:8081 で開くと、スマホ自身の 127.0.0.1 を見に行ってしまう。
 * そこで、Web 版で、画面を開いた住所（window.location.hostname）がパソコン自身でないときは、
 * Supabase の住所もそのホスト名に置き換える（ポートはそのまま）。本番の URL（https://…）には何もしない。
 */
function resolveUrl(url: string): string {
  if (Platform.OS !== "web" || typeof window === "undefined") return url;
  try {
    const u = new URL(url);
    const local = u.hostname === "127.0.0.1" || u.hostname === "localhost";
    const pageHost = window.location.hostname;
    if (local && pageHost && pageHost !== "127.0.0.1" && pageHost !== "localhost") {
      u.hostname = pageHost;
      return u.toString().replace(/\/$/, "");
    }
  } catch {
    /* URL の形でなければそのまま */
  }
  return url;
}

export const supabaseConfigured = Boolean(envUrl && anonKey);

export const supabase = createClient(resolveUrl(envUrl || "http://127.0.0.1:55421"), anonKey || "missing-key", {
  auth: {
    storage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
