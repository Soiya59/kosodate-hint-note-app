/**
 * E-6 招待コード（管理者。ワイヤーフレーム v0.4 E-6・要件 F-01・設計書 8-1節）。
 * 家庭を選ぶ →［コードを出す］（create_invite）→ 小窓にコードを1回だけ出す（外を押しても閉じない。［閉じる］だけ）。
 * 使えるコード（使っていない・取り消していない・期限内）の一覧と［取り消す］（invites の revoked_at を UPDATE）。
 * データ置き場はコードそのものを持たないので、一覧にはコードの文字を出さない。期限はノートの設定値（7日）で決まる。
 */
import React, { useCallback, useEffect, useState } from "react";
import { Modal, Platform, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { Button, Chip, ErrorBox, Header, Loading, Screen, styles } from "@/components/ui";
import * as api from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { shortDate } from "@/lib/format";
import { colors, font, MAX_WIDTH, radius, space } from "@/theme";

export default function Invites() {
  const router = useRouter();
  const { space: sp, households, showToast } = useApp();
  const [target, setTarget] = useState<string | null>(null);
  const [invites, setInvites] = useState<api.InviteRow[] | null>(null);
  const [memberCount, setMemberCount] = useState(0);
  const [loadError, setLoadError] = useState(false);
  const [code, setCode] = useState<{ household: string; code: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!sp) return;
    setLoadError(false);
    try {
      const [iv, ms] = await Promise.all([api.listUsableInvites(sp.o_space_id), api.listMembers(sp.o_space_id)]);
      setInvites(iv);
      setMemberCount(ms.length);
    } catch {
      setLoadError(true);
    }
  }, [sp]);
  useEffect(() => {
    if (sp && sp.o_role !== "admin") router.replace("/settings");
    else void load();
  }, [sp, load, router]);

  if (!sp || sp.o_role !== "admin") return null;
  const full = memberCount >= sp.o_max_members;
  const hhEntries = Object.entries(households).sort(([a], [b]) => (a === sp.o_household_id ? -1 : b === sp.o_household_id ? 1 : 0));
  const hhLabel = (id: string) => (id === sp.o_household_id ? "うち" : households[id] ?? "");

  const issue = async () => {
    if (!target) return setError("どの家庭に入る人かを選んでください");
    setBusy(true);
    setError(null);
    try {
      const c = await api.createInvite(target);
      setCode({ household: households[target] ?? "", code: c.replace(/^(.{4})(.{4})$/, "$1-$2") });
      await load();
    } catch (e) {
      setError((e as { key?: string }).key === "forbidden" ? "この操作はできません" : "出せませんでした。もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  const copy = async () => {
    try {
      if (Platform.OS === "web" && navigator.clipboard) await navigator.clipboard.writeText(code!.code);
      showToast("コピーしました");
    } catch {
      showToast("コピーできませんでした。文字を選んでコピーしてください");
    }
  };

  return (
    <Screen header={<Header title="招待コード" fallback="/settings" />}
      overlay={
        code ? (
          // コードの小窓は、外を押しても・戻る操作でも閉じない（見失わないように。［閉じる］だけ）
          <Modal transparent visible animationType="none" onRequestClose={() => {}}>
            <View style={[styles.sheetBackdrop, { justifyContent: "center", alignItems: "center", padding: space.l }]}>
              <View style={{ width: "100%", maxWidth: MAX_WIDTH - 32, backgroundColor: colors.surface, borderRadius: radius.card, padding: space.l }}>
                <Text style={[font.rowTitle, { color: colors.text }]}>{code.household}の招待コード</Text>
                <Text selectable style={[font.code, { color: colors.text, textAlign: "center", marginVertical: space.l }]} testID="invite-code">{code.code}</Text>
                <Button label="コピー" onPress={copy} />
                <Text style={[styles.sub, { marginTop: space.m }]}>このコードは、いまだけ表示されます。閉じる前にコピーして、本人に送ってください。7日間・1回だけ使えます。</Text>
                <Button kind="secondary" label="閉じる" onPress={() => setCode(null)} style={{ marginTop: space.m }} testID="invite-close" />
              </View>
            </View>
          </Modal>
        ) : null
      }
    >
      <Text style={styles.label}>どの家庭に入る人ですか</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
        {hhEntries.map(([hid, name]) => (
          <Chip key={hid} label={hid === sp.o_household_id ? "うち" : name} selected={target === hid} onPress={() => setTarget(hid)} testID={`invite-target-${name}`} />
        ))}
      </View>
      <Button label={busy ? "出しています…" : "コードを出す"} busy={busy} disabled={full} onPress={issue} style={{ marginTop: space.m }} testID="invite-issue" />
      {full ? <Text style={[styles.sub, { marginTop: space.xs }]}>人数がいっぱいです（{sp.o_max_members}人まで）</Text> : null}
      {error ? <Text style={[styles.error, { marginTop: space.xs }]}>{error}</Text> : null}

      <Text style={[styles.label, { marginTop: space.xl }]}>使えるコード</Text>
      {loadError ? <ErrorBox onRetry={load} /> : invites == null ? <Loading /> : invites.length === 0 ? (
        <Text style={styles.sub}>使えるコードはありません</Text>
      ) : (
        invites.map((iv) => (
          <View key={iv.id} style={[styles.row, { flexDirection: "row", alignItems: "center", justifyContent: "space-between" }]} testID="invite-row">
            <Text style={styles.body}>{hhLabel(iv.household_id)}   {shortDate(new Date(Date.parse(iv.expires_at) + 9 * 3600e3).toISOString().slice(0, 10))}まで</Text>
            <Button kind="text" label="取り消す" testID="invite-revoke"
              onPress={async () => {
                try {
                  await api.revokeInvite(iv.id);
                  showToast("取り消しました");
                  await load();
                } catch {
                  showToast("取り消せませんでした。もう一度押してください");
                }
              }} />
          </View>
        ))
      )}
      <Text style={[styles.sub, { marginTop: space.l }]}>コードは1回だけ使えます。LINE などで本人に送ってください（アプリからは送りません）。</Text>
    </Screen>
  );
}
