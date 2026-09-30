/**
 * 端末の中だけに置くものの保存先（Web 版: ブラウザの localStorage）。
 * アプリにしたときは storage.native.ts（AsyncStorage）が使われる（要件 9-5節「保存先を差し替えられる形」）。
 * ここに置くもの: ログインの保存・今見ているノート・最近選んだ年齢・書きかけ。サーバーには送らない。
 */
import type { KV } from "./kv";

function ls(): Storage | null {
  try {
    return typeof window !== "undefined" ? window.localStorage : null;
  } catch {
    return null;
  }
}

export const storage: KV = {
  async getItem(key) {
    try {
      return ls()?.getItem(key) ?? null;
    } catch {
      return null;
    }
  },
  async setItem(key, value) {
    try {
      ls()?.setItem(key, value);
    } catch {
      /* 保存できない端末（プライベートモードなど）では覚えない */
    }
  },
  async removeItem(key) {
    try {
      ls()?.removeItem(key);
    } catch {
      /* 同上 */
    }
  },
};
