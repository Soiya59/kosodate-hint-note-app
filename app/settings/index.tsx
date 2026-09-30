/**
 * E-1 設定（ワイヤーフレーム v0.4 E-1）。
 * 作ったもの: あなた（呼び名・家庭・ノート・メール）、書き方の約束を読む（E-2）、預かり方の約束を読む（A-5）、
 *   管理者だけ: 招待コード（E-6 の最低限）、ログアウト（小窓つき）。
 *   呼び名を変える（D-4。2026-09-30 統括が触った後の直し 第1段で追加）。
 *   （招待の前に要る画面・2026-09-30）記録を書き出す（E-3）、家庭とメンバー（E-5）、招待コード（E-6）、退会（E-4）。
 *   （v0.8 の直し・2026-09-30）タグの追加（E-7。種類を選ぶ）。
 * 作らなかったもの: ホーム画面に置く方法、ノートの削除（E-8。Edge Function delete-space はある）。
 */
import React, { useState } from "react";
import { Pressable, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { BottomTabs, Button, Field, Screen, Sheet, styles } from "@/components/ui";
import { updateMyDisplayName } from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { supabase } from "@/lib/supabase";
import { colors, font, space } from "@/theme";

function Row(props: { label: string; value: string }) {
  return (
    <View style={[styles.row, { flexDirection: "row" }]}>
      <Text style={[styles.sub, { width: 72 }]}>{props.label}</Text>
      <Text style={[styles.body, { flex: 1 }]}>{props.value}</Text>
    </View>
  );
}

function Link(props: { label: string; onPress: () => void; testID?: string }) {
  return (
    <Pressable accessibilityRole="button" onPress={props.onPress} style={[styles.row, { flexDirection: "row", justifyContent: "space-between" }]} testID={props.testID}>
      <Text style={styles.body}>{props.label}</Text>
      <Text style={styles.sub}>›</Text>
    </Pressable>
  );
}

export default function Settings() {
  const router = useRouter();
  const { space: sp, email, signOut, households } = useApp();
  const [confirm, setConfirm] = useState(false);
  const me = sp;
  const isAdmin = me?.o_role === "admin";

  return (
    <Screen
      overlay={<>
      <Sheet visible={confirm} onClose={() => setConfirm(false)} title="ログアウトしますか">
        <Text style={[styles.body, { marginBottom: space.m }]}>
          次は、メールに届く番号で入ります。書きかけと、最近の年齢はこの端末から消えます。
        </Text>
        <View style={{ flexDirection: "row" }}>
          <Button kind="secondary" label="やめる" onPress={() => setConfirm(false)} style={{ flex: 1, marginRight: space.s }} />
          <Button label="ログアウト" onPress={() => { setConfirm(false); void signOut(); }} style={{ flex: 1 }} testID="logout-confirm" />
        </View>
      </Sheet>
      </>} footer={<BottomTabs current="settings" />}>
      <Text style={[font.title, { color: colors.text, marginBottom: space.m }]}>設定</Text>
      <Text style={[styles.label, { marginTop: space.s }]}>あなた</Text>
      <MyName />
      <Row label="家庭" value={me ? `うち（${households[me.o_household_id] ?? me.o_household_name}）` : ""} />
      <Row label="ノート" value={me?.o_space_name ?? ""} />
      <Row label="メール" value={email ?? ""} />
      <View style={{ height: space.l }} />
      <Link label="書き方の約束を読む" onPress={() => router.push("/settings/rules")} />
      <Link label="預かり方の約束を読む" onPress={() => router.push("/privacy")} testID="open-privacy" />
      <Link label="記録を書き出す" onPress={() => router.push("/settings/export")} testID="open-export" />
      {isAdmin ? (
        <View style={{ marginTop: space.l }}>
          <Text style={styles.label}>管理者だけ</Text>
          <Link label="家庭とメンバー" onPress={() => router.push("/settings/families")} testID="open-families" />
          <Link label="招待コード" onPress={() => router.push("/settings/invites")} testID="open-invites" />
          <Link label="タグの追加" onPress={() => router.push("/settings/tags")} testID="open-tags" />
        </View>
      ) : null}
      <View style={{ marginTop: space.xl }}>
        <Button kind="secondary" label="ログアウト" onPress={() => setConfirm(true)} testID="logout" />
        {isAdmin ? (
          <Text style={[styles.sub, { marginTop: space.m }]}>管理者は退会できません。やめるときは、ノートの削除になります。</Text>
        ) : (
          <Link label="このノートから退会する" onPress={() => router.push("/settings/leave")} testID="open-leave" />
        )}
      </View>
    </Screen>
  );
}

/** 呼び名と［変える］→ D-4 呼び名を変える（小窓。ワイヤーフレーム v0.3 D-4・要件 F-04b） */
function MyName() {
  const { space: sp, refresh, showToast } = useApp();
  const [name, setName] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const load = React.useCallback(() => {
    if (!sp) return;
    void supabase.from("members").select("display_name").eq("id", sp.o_member_id).maybeSingle()
      .then(({ data }) => setName((data?.display_name as string | undefined) ?? ""));
  }, [sp]);
  React.useEffect(load, [load]);

  const save = async () => {
    const v = draft.trim();
    if (!v) return setError("呼び名を入れてください");
    if (!sp) return;
    setBusy(true);
    setError(null);
    try {
      await updateMyDisplayName(sp.o_member_id, v);
      setOpen(false);
      setName(v);
      showToast("変えました");
      void refresh(); // 管理者の呼び名（断りの文・参加の表示に使う）も読み直す
    } catch {
      setError("変えられませんでした。もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={[styles.row, { flexDirection: "row", alignItems: "center" }]}>
      <Text style={[styles.sub, { width: 72 }]}>呼び名</Text>
      <Text style={[styles.body, { flex: 1 }]} testID="my-name">{name ?? ""}</Text>
      <Button kind="text" label="変える" onPress={() => { setDraft(name ?? ""); setError(null); setOpen(true); }} testID="rename-open" />
      <Sheet visible={open} onClose={() => setOpen(false)} title="呼び名を変える">
        <Field
          value={draft}
          onChangeText={(t) => setDraft(t.slice(0, 20))}
          maxLength={20}
          counter={`${draft.length}/20`}
          hint="ほかの人に見えます。本名でなくてよい"
          error={error}
          autoFocus
          testID="rename-input"
        />
        <View style={{ flexDirection: "row" }}>
          <Button kind="secondary" label="やめる" onPress={() => setOpen(false)} style={{ flex: 1, marginRight: space.s }} />
          <Button label={busy ? "変えています…" : "変える"} busy={busy} onPress={save} style={{ flex: 1 }} testID="rename-save" />
        </View>
      </Sheet>
    </View>
  );
}
