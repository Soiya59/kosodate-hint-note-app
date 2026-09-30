/**
 * E-4 退会（メンバー。このノートから。ワイヤーフレーム v0.4 E-4・要件 8-5節・F-31・設計書 7-2節）。
 * Edge Function delete-member に { 自分のメンバー ID, delete_trials }。既定は「消す」（U-19）。管理者は開くと E-1 へ戻す。
 * ほかのノートに入っていなければ、ログインの情報（メールアドレス）も消える → 端末の書きかけなども消して「退会しました」。
 */
import React, { useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { Button, Header, Screen, Sheet, styles } from "@/components/ui";
import { deleteMember } from "@/lib/api";
import { KEYS, useApp } from "@/lib/app-state";
import { storage } from "@/lib/storage";
import { supabase } from "@/lib/supabase";
import { colors, font, space } from "@/theme";

export default function Leave() {
  const router = useRouter();
  const { space: sp, spaces, refresh } = useApp();
  const [del, setDel] = useState(true); // 既定は「消す」
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const others = spaces.length > 1;

  useEffect(() => {
    if (sp?.o_role === "admin") router.replace("/settings");
  }, [sp, router]);

  const run = async () => {
    if (!sp) return;
    setBusy(true);
    setError(null);
    try {
      await deleteMember(sp.o_member_id, del);
      setConfirm(false);
      if (others) {
        await storage.removeItem(KEYS.currentSpace);
        await storage.removeItem(KEYS.draft);
        await refresh();
        router.replace("/");
      } else {
        // ログインの情報も消えたので、端末の中のもの（書きかけ・最近の年齢・今見ているノート・ログインの保存）を消す
        await Promise.all(Object.values(KEYS).map((k) => storage.removeItem(k)));
        router.replace("/left"); // 入口の判定の外の画面（「退会しました」）へ先に移ってから、ログインを消す
        await supabase.auth.signOut({ scope: "local" });
      }
    } catch {
      setError("退会できませんでした。もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  const radio = (v: boolean, label: string, id: string) => (
    <Pressable accessibilityRole="radio" accessibilityState={{ checked: del === v }} onPress={() => setDel(v)} style={{ flexDirection: "row", alignItems: "center", minHeight: 44 }} testID={id}>
      <Text style={[styles.body, { width: 28 }]}>{del === v ? "●" : "○"}</Text>
      <Text style={styles.body}>{label}</Text>
    </Pressable>
  );

  return (
    <Screen
      header={<Header title="このノートから退会する" fallback="/settings" />}
      footer={<Button label="退会する" onPress={() => setConfirm(true)} testID="leave-open" />}
      overlay={
        <Sheet visible={confirm} onClose={() => setConfirm(false)} title="本当に退会しますか">
          <Text style={[styles.body, { marginBottom: space.m }]}>元に戻せません。</Text>
          {error ? <Text style={styles.error}>{error}</Text> : null}
          <View style={{ flexDirection: "row", marginTop: space.s }}>
            <Button kind="secondary" label="やめる" onPress={() => setConfirm(false)} style={{ flex: 1, marginRight: space.s }} />
            <Button label={busy ? "退会しています…" : "退会する"} busy={busy} onPress={run} style={{ flex: 1 }} testID="leave-confirm" />
          </View>
        </Sheet>
      }
    >
      <Text style={styles.long}>退会すると、「{sp?.o_space_name ?? ""}」に入れなくなります。</Text>
      <Text style={[styles.label, { marginTop: space.l }]}>あなたが書いた記録を</Text>
      {radio(true, "消す", "leave-delete")}
      {radio(false, "家庭の記録として残す", "leave-keep")}
      <Text style={[styles.long, { marginTop: space.m }]}>困りごと・対策の名前は、みんなのものなので残ります。</Text>
      <Text style={styles.long}>{others ? "ほかのノートには、このまま入れます。" : "ほかのノートに入っていなければ、ログインの情報（メールアドレス）も消えます。"}</Text>
      <Text style={styles.long}>消した記録は、最大14日分のバックアップに残り、その後消えます。</Text>
      <Button kind="secondary" label="先に記録を書き出す" onPress={() => router.push("/settings/export")} style={{ marginTop: space.l, alignSelf: "flex-start" }} />
    </Screen>
  );
}
