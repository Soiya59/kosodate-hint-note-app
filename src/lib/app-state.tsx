/**
 * アプリ全体の状態（2026-09-30 開発部）: ログイン・同意・参加の判定、今見ているノート、タグと家庭の名前、短い知らせ。
 *
 * 入口の判定の順（GATE_ORDER）: ワイヤーフレーム v0.3 2章（本部長採点100点・2026-09-30）と設計書 v0.3 8-1節のとおり
 * 「ログイン → 招待コードで参加 → 同意」。本部長の依頼文（2026-09-30）は「ログイン → 同意 → 参加」の順で書かれていたが、
 * 確定した画面の仕様に合わせた。入れ替えるときは、この配列の順を変えるだけでよい
 * （同意はログインごとなので、どちらの順でもデータ置き場は同じに動く）。
 */
import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import { storage } from "./storage";
import * as api from "./api";

export const GATE_ORDER: ("consent" | "join")[] = ["join", "consent"];

export type Status = "loading" | "signedOut" | "needConsent" | "needJoin" | "ready" | "error";

export const KEYS = {
  currentSpace: "khn.currentSpace",
  recentAges: "khn.recentAges",
  draft: "khn.draft",
};

type Ctx = {
  status: Status;
  session: Session | null;
  email: string | null;
  spaces: api.Space[];
  space: api.Space | null;
  tags: api.Tag[];
  households: Record<string, string>;
  refresh: () => Promise<void>;
  signOut: () => Promise<void>;
  householdLabel: (id: string | null | undefined) => string;
  /** （v0.4）③の書いた人の見せ方: 「呼び名（家庭名）」、自家庭は「呼び名（うち）」、書いた人が空なら家庭名だけ（要件 6-3節） */
  writerLabel: (t: { household_id: string; household_name: string | null; created_by_name: string | null }) => string;
  toast: string | null;
  showToast: (msg: string) => void;
  /** 困りごとの一覧の検索の言葉・タグ（アプリを開いている間は保つ。ワイヤーフレーム 2章） */
  listFilter: { query: string; tagId: string | null };
  setListFilter: (f: { query: string; tagId: string | null }) => void;
  /** B-1 で選んでいる種類（null＝すべて）。アプリを開いている間だけ持つ（端末に覚えない）。E-7 の種類の既定に使う */
  listKind: "trouble" | "grow" | null;
  setListKind: (k: "trouble" | "grow" | null) => void;
  /** 同意画面（約束の改訂後）から戻る先。書く画面の保存で consent_required が返ったときに使う（ワイヤーフレーム 3-5節） */
  returnTo: React.MutableRefObject<string | null>;
};

const AppCtx = createContext<Ctx | null>(null);

export function AppStateProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<Status>("loading");
  const [session, setSession] = useState<Session | null>(null);
  const [spaces, setSpaces] = useState<api.Space[]>([]);
  const [space, setSpace] = useState<api.Space | null>(null);
  const [tags, setTags] = useState<api.Tag[]>([]);
  const [households, setHouseholds] = useState<Record<string, string>>({});
  const [toast, setToast] = useState<string | null>(null);
  const [listFilter, setListFilter] = useState<{ query: string; tagId: string | null }>({ query: "", tagId: null });
  const [listKind, setListKind] = useState<"trouble" | "grow" | null>(null);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const returnTo = useRef<string | null>(null);

  const showToast = useCallback((msg: string) => {
    setToast(msg);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2000);
  }, []);

  const evaluate = useCallback(async (s: Session | null) => {
    if (!s) {
      setStatus("signedOut");
      setSpaces([]);
      setSpace(null);
      return;
    }
    try {
      const [agreed, mySpaces] = await Promise.all([api.hasAgreedCurrentRules(), api.listMySpaces()]);
      setSpaces(mySpaces);
      for (const g of GATE_ORDER) {
        if (g === "consent" && !agreed) return setStatus("needConsent");
        if (g === "join" && mySpaces.length === 0) return setStatus("needJoin");
      }
      // 今見ているノート: 端末に覚えたもの、なければ参加が早いノート（要件 F-04。list_my_spaces は参加した順）
      const saved = await storage.getItem(KEYS.currentSpace);
      const cur = mySpaces.find((x) => x.o_space_id === saved) ?? mySpaces[0];
      await storage.setItem(KEYS.currentSpace, cur.o_space_id);
      const [t, hh] = await Promise.all([api.listTags(cur.o_space_id), api.listHouseholds(cur.o_space_id)]);
      setSpace(cur);
      setTags(t);
      setHouseholds(Object.fromEntries(hh.map((h) => [h.id, h.display_name])));
      setStatus("ready");
    } catch {
      setStatus("error");
    }
  }, []);

  const sessionRef = useRef<Session | null>(null);

  useEffect(() => {
    let alive = true;
    supabase.auth.getSession().then(({ data }) => {
      if (!alive) return;
      sessionRef.current = data.session;
      setSession(data.session);
      void evaluate(data.session);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      const prevUser = sessionRef.current?.user.id;
      sessionRef.current = s;
      setSession(s);
      // トークンの更新だけのときは、判定をやり直さない（画面がちらつかないように）
      if (event === "SIGNED_OUT" || (event === "SIGNED_IN" && prevUser !== s?.user.id)) {
        setStatus("loading");
        // この知らせの中で supabase を直接呼ぶと止まることがある（supabase-js の注意）。次の番に回す。
        setTimeout(() => void evaluate(s), 0);
      }
    });
    return () => {
      alive = false;
      sub.subscription.unsubscribe();
    };
  }, [evaluate]);

  const refresh = useCallback(async () => {
    await evaluate(sessionRef.current);
  }, [evaluate]);

  const signOut = useCallback(async () => {
    // 端末の中だけのもの（書きかけ・最近の年齢・今見ているノート）も消す（ワイヤーフレーム E-1 のログアウト）
    await Promise.all(Object.values(KEYS).map((k) => storage.removeItem(k)));
    setListFilter({ query: "", tagId: null });
    setListKind(null);
    await supabase.auth.signOut();
  }, []);

  const householdLabel = useCallback(
    (id: string | null | undefined) => {
      if (!id) return "退会した家庭";
      if (space && id === space.o_household_id) return "うち";
      return households[id] ?? "ほかの家庭";
    },
    [space, households],
  );

  const writerLabel = useCallback(
    (t: { household_id: string; household_name: string | null; created_by_name: string | null }) => {
      const hh = space && t.household_id === space.o_household_id ? "うち" : (t.household_name ?? householdLabel(t.household_id));
      return t.created_by_name ? `${t.created_by_name}（${hh}）` : hh;
    },
    [space, householdLabel],
  );

  const value = useMemo<Ctx>(
    () => ({
      status, session, email: session?.user.email ?? null, spaces, space, tags, households,
      refresh, signOut, householdLabel, writerLabel, toast, showToast, listFilter, setListFilter, listKind, setListKind, returnTo,
    }),
    [status, session, spaces, space, tags, households, refresh, signOut, householdLabel, writerLabel, toast, showToast, listFilter, listKind],
  );

  return <AppCtx.Provider value={value}>{children}</AppCtx.Provider>;
}

export function useApp(): Ctx {
  const v = useContext(AppCtx);
  if (!v) throw new Error("AppStateProvider がありません");
  return v;
}
