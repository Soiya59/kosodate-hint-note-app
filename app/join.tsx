/** A-3 招待コードを入れる（ワイヤーフレーム v0.4 A-3（預かるものの文は要件 v0.7 C94）・要件 v0.6 F-01・設計書 v0.3 8-1節） */
import React, { useState } from "react";
import { Text, View } from "react-native";
import { useRouter } from "expo-router";
import { JOIN_CUSTODY, JOIN_RESULT } from "@/constants/texts";
import { Button, Field, Header, Pieces, Screen, styles } from "@/components/ui";
import { joinWithInviteCode, listMySpaces, type Space } from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { font, colors, space } from "@/theme";

export default function Join() {
  const { refresh, signOut } = useApp();
  const router = useRouter();
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [errCode, setErrCode] = useState<string | null>(null);
  const [errName, setErrName] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [joined, setJoined] = useState<null | { space: Space | null }>(null);

  // 見せ方だけ4文字ごとに「-」。送るときは、データ置き場が全角・小文字・空白・「-」をそろえる（設計書 8-1節）
  const shown = code.toUpperCase().replace(/[^A-Z0-9]/g, "").replace(/^(.{4})(.+)$/, "$1-$2");

  const submit = async () => {
    const c = code.trim();
    const n = name.trim();
    setErrCode(c ? null : "招待コードを入れてください");
    setErrName(n ? null : "呼び名を入れてください");
    if (!c || !n) return;
    setBusy(true);
    setError(null);
    try {
      const r = await joinWithInviteCode(c, n);
      if (r === "joined") {
        let sp: Space | null = null;
        try {
          sp = (await listMySpaces())[0] ?? null; // 参加が早い順。身内の段階はノートが1冊
        } catch {
          sp = null;
        }
        setJoined({ space: sp });
      } else {
        setError(JOIN_RESULT[r] ?? JOIN_RESULT.invalid);
      }
    } catch (e) {
      const key = (e as { key?: string }).key;
      setError(key === "check_violation" ? "呼び名は20字までです" : "参加できませんでした。通信を確かめて、もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  if (joined) {
    // v0.3: 2秒の知らせではなく、読んでから［次へ］（家庭の取り違えに気づけるように）
    const sp = joined.space;
    return (
      <Screen>
        <View style={{ marginTop: space.xxl }}>
          <Text style={[font.rowTitle, { color: colors.text }]} testID="joined-title">
            {sp ? `「${sp.o_household_name}」として参加しました。` : "参加しました。"}
          </Text>
          <Text style={[styles.long, { marginTop: space.l }]}>
            {sp?.o_admin_display_name
              ? `違う家庭のときは、管理者（${sp.o_admin_display_name}さん）に伝えてください`
              : "違う家庭のときは、招待した人に伝えてください"}
          </Text>
          <Button label="次へ" onPress={() => void refresh()} style={{ marginTop: space.xl }} testID="joined-next" />
        </View>
      </Screen>
    );
  }

  return (
    <Screen header={<Header back={false} title="招待コードを入れる" right={<Button kind="text" label="ログアウト" onPress={() => void signOut()} />} />}>
      <Text style={[styles.body, { marginBottom: space.m }]}>招待した人から届いた、8文字のコードを入れてください。</Text>
      <Field
        value={code}
        onChangeText={setCode}
        autoCapitalize="characters"
        autoCorrect={false}
        placeholder="____-____"
        error={errCode}
        hint={code ? `入れたコード: ${shown}` : undefined}
        testID="join-code"
      />
      <Field
        label="あなたの呼び名（ほかの人に見えます）"
        value={name}
        onChangeText={(t) => setName(t.slice(0, 20))}
        maxLength={20}
        placeholder=""
        hint="例: パパ、ゆうこ。本名でなくてよい"
        counter={`${name.length}/20`}
        error={errName}
        testID="join-name"
      />
      {/* 要件 v0.7 7-1節 C94 の文。「預かり方の約束」は A-5 へのリンク（ログインの後・参加の前でも開ける） */}
      <Text style={[styles.long, { marginBottom: space.l }]} testID="join-custody">
        <Pieces pieces={JOIN_CUSTODY} onLink={() => router.push("/privacy")} />
      </Text>
      {error ? <Text style={[styles.error, { marginBottom: space.m }]} testID="join-error">{error}</Text> : null}
      <Button label={busy ? "参加しています…" : "参加する"} onPress={submit} busy={busy} testID="join-submit" />
    </Screen>
  );
}
