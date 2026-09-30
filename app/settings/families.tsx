/**
 * E-5 家庭とメンバー（管理者。ワイヤーフレーム v0.4 E-5・要件 v0.7 2-3節・8-5節・C92・設計書 7-1・7-2節）。
 * - メンバーを外す（Edge Function delete-member。「書いた記録を 家庭の記録として残す／消す」。既定は「残す」）
 *   ＝違う家庭に入ってしまった人を外し、正しい家庭のコードを出し直す用途（C92）
 * - 家庭を作る（表 households に INSERT）・名前を変える（UPDATE）・消す（Edge Function delete-household。件数は household_deletion_preview）
 * - エラーの文はデータ置き場の返事で分ける: limit_households＝上限／23505＝同じ名前／42501（forbidden）＝この操作はできません（W2）
 * 管理者以外が開くと E-1 へ戻す。
 */
import React, { useCallback, useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { Button, ErrorBox, Field, Header, Loading, Screen, Sheet, styles } from "@/components/ui";
import * as api from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { colors, font, space } from "@/theme";

type Dialog =
  | { kind: "remove"; member: api.MemberRow }
  | { kind: "create" }
  | { kind: "menu"; id: string; name: string }
  | { kind: "rename"; id: string; name: string }
  | { kind: "delete"; id: string; name: string; trials: number; members: number };

function errText(key: string | undefined, max: number): string {
  if (key === "limit_households") return `家庭は${max}つまでです`;
  if (key === "unique_violation") return "同じ名前の家庭があります";
  if (key === "forbidden") return "この操作はできません";
  if (key === "check_violation") return "名前は20字までです";
  if (key === "cannot_delete_own_household") return "管理者の家庭は消せません";
  return "うまくいきませんでした。もう一度押してください";
}

export default function Families() {
  const router = useRouter();
  const { space: sp, refresh, showToast } = useApp();
  const [households, setHouseholds] = useState<{ id: string; display_name: string }[] | null>(null);
  const [members, setMembers] = useState<api.MemberRow[]>([]);
  const [error, setError] = useState(false);
  const [dialog, setDialog] = useState<Dialog | null>(null);
  const [keep, setKeep] = useState(true); // 外すときの既定は「家庭の記録として残す」
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [dError, setDError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!sp) return;
    setError(false);
    try {
      const [h, m] = await Promise.all([api.listHouseholds(sp.o_space_id), api.listMembers(sp.o_space_id)]);
      setHouseholds(h);
      setMembers(m);
    } catch {
      setError(true);
    }
  }, [sp]);
  useEffect(() => {
    if (sp && sp.o_role !== "admin") router.replace("/settings");
    else void load();
  }, [sp, load, router]);

  const open = (d: Dialog) => { setDialog(d); setDError(null); setKeep(true); setName(d.kind === "rename" ? d.name : ""); };
  const done = async (msg: string) => { setDialog(null); showToast(msg); await load(); void refresh(); };
  const act = async (f: () => Promise<unknown>, msg: string) => {
    setBusy(true);
    setDError(null);
    try {
      await f();
      await done(msg);
    } catch (e) {
      setDError(errText((e as { key?: string }).key, sp?.o_max_households ?? 5));
    } finally {
      setBusy(false);
    }
  };

  if (!sp) return null;
  const full = (households?.length ?? 0) >= sp.o_max_households;
  // 家庭の並び: 自家庭を先に
  const hhList = [...(households ?? [])].sort((a, b) => (a.id === sp.o_household_id ? -1 : b.id === sp.o_household_id ? 1 : 0));

  return (
    <Screen
      header={<Header title="家庭とメンバー" fallback="/settings" />}
      overlay={
        dialog ? (
          <Sheet
            visible
            onClose={() => setDialog(null)}
            title={
              dialog.kind === "remove" ? `${dialog.member.display_name}さんをノートから外します`
                : dialog.kind === "create" ? "家庭を作る"
                : dialog.kind === "menu" ? dialog.name
                : dialog.kind === "rename" ? "家庭の名前を変える"
                : `${dialog.name}を消します`
            }
          >
            {dialog.kind === "remove" ? (
              <View>
                <Text style={styles.label}>{dialog.member.display_name}さんが書いた記録を</Text>
                {[{ v: true, l: "家庭の記録として残す", id: "remove-keep" }, { v: false, l: "消す", id: "remove-delete" }].map((o) => (
                  <Pressable key={o.id} onPress={() => setKeep(o.v)} style={{ flexDirection: "row", alignItems: "center", minHeight: 44 }} testID={o.id}>
                    <Text style={[styles.body, { width: 28 }]}>{keep === o.v ? "●" : "○"}</Text>
                    <Text style={styles.body}>{o.l}</Text>
                  </Pressable>
                ))}
                <Text style={[styles.sub, { marginTop: space.s }]}>残すと、{households?.find((h) => h.id === dialog.member.household_id)?.display_name ?? "家庭"}の記録として読めます。消すと元に戻せません。</Text>
                {dError ? <Text style={styles.error}>{dError}</Text> : null}
                <View style={{ flexDirection: "row", marginTop: space.m }}>
                  <Button kind="secondary" label="やめる" onPress={() => setDialog(null)} style={{ flex: 1, marginRight: space.s }} />
                  <Button label={busy ? "外しています…" : "外す"} busy={busy} style={{ flex: 1 }} testID="remove-confirm"
                    onPress={() => act(() => api.deleteMember(dialog.member.id, !keep), "外しました")} />
                </View>
              </View>
            ) : dialog.kind === "create" || dialog.kind === "rename" ? (
              <View>
                <Field value={name} onChangeText={(t) => setName(t.slice(0, 20))} maxLength={20} counter={`${name.length}/20`} placeholder="例: 兄の家" error={dError} autoFocus testID="household-name" />
                <View style={{ flexDirection: "row" }}>
                  <Button kind="secondary" label="やめる" onPress={() => setDialog(null)} style={{ flex: 1, marginRight: space.s }} />
                  <Button
                    label={busy ? (dialog.kind === "create" ? "作っています…" : "変えています…") : dialog.kind === "create" ? "作る" : "変える"}
                    busy={busy}
                    style={{ flex: 1 }}
                    testID="household-save"
                    onPress={() => {
                      const v = name.trim();
                      if (!v) return setDError("名前を入れてください");
                      void act(
                        () => (dialog.kind === "create" ? api.createHousehold(sp.o_space_id, v) : api.renameHousehold(dialog.id, v)),
                        dialog.kind === "create" ? "作りました" : "名前を変えました",
                      );
                    }}
                  />
                </View>
              </View>
            ) : dialog.kind === "menu" ? (
              <View>
                <Button kind="secondary" label="名前を変える" onPress={() => open({ kind: "rename", id: dialog.id, name: dialog.name })} testID="household-rename" />
                {dialog.id !== sp.o_household_id ? (
                  <Button kind="secondary" label="この家庭を消す" style={{ marginTop: space.s }} testID="household-delete"
                    onPress={async () => {
                      try {
                        const pv = await api.householdDeletionPreview(dialog.id);
                        open({ kind: "delete", id: dialog.id, name: dialog.name, trials: pv.o_trial_count, members: pv.o_member_count });
                      } catch {
                        setDError("うまくいきませんでした。もう一度押してください");
                      }
                    }} />
                ) : null}
                {dError ? <Text style={styles.error}>{dError}</Text> : null}
              </View>
            ) : (
              <View>
                {/* 記録の件数は非公開を含む合計を1つの数で出し、内訳を出さない（要件 8-2節・B5） */}
                <Text style={[styles.long, { marginBottom: space.m }]} testID="household-delete-text">
                  {dialog.name}のメンバー{dialog.members}人と、記録 {dialog.trials}件が消えます。ほかの家庭の記録が付いた困りごと・対策は残ります。消す前に書き出しておくと安心です。
                </Text>
                {dError ? <Text style={styles.error}>{dError}</Text> : null}
                <Button kind="secondary" label="書き出す" onPress={() => { setDialog(null); router.push("/settings/export"); }} />
                <View style={{ flexDirection: "row", marginTop: space.s }}>
                  <Button kind="secondary" label="やめる" onPress={() => setDialog(null)} style={{ flex: 1, marginRight: space.s }} />
                  <Button kind="secondary" label={busy ? "消しています…" : "消す"} busy={busy} style={{ flex: 1 }} testID="household-delete-confirm"
                    onPress={() => act(() => api.deleteHousehold(dialog.id), "消しました")} />
                </View>
              </View>
            )}
          </Sheet>
        ) : null
      }
    >
      {error ? <ErrorBox onRetry={load} /> : households == null ? <Loading /> : (
        <View>
          <Text style={[styles.sub, { marginBottom: space.m }]} testID="family-counts">
            家庭 {households.length} / {sp.o_max_households} ・ メンバー {members.length} / {sp.o_max_members}
          </Text>
          {hhList.map((h) => {
            const ms = members.filter((m) => m.household_id === h.id);
            return (
              <View key={h.id} style={styles.row} testID="family-row">
                <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
                  <Text style={[font.rowTitle, { color: colors.text, flex: 1 }]}>
                    {h.id === sp.o_household_id ? `うち（${h.display_name}）` : h.display_name}{ms.length === 0 ? "（まだ誰もいません）" : ""}
                  </Text>
                  <Button kind="text" label="⋯" onPress={() => open({ kind: "menu", id: h.id, name: h.display_name })} testID={`family-menu-${h.display_name}`} />
                </View>
                {ms.map((m) => (
                  <View key={m.id} style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", minHeight: 44, paddingLeft: space.m }}>
                    <Text style={styles.body}>{m.display_name}{m.role === "admin" ? "（管理者）" : ""}</Text>
                    {m.role !== "admin" ? <Button kind="text" label="外す" onPress={() => open({ kind: "remove", member: m })} testID={`remove-${m.display_name}`} /> : null}
                  </View>
                ))}
              </View>
            );
          })}
          <Button label="＋ 家庭を作る" disabled={full} onPress={() => open({ kind: "create" })} style={{ marginTop: space.l }} testID="household-create" />
          {full ? <Text style={[styles.sub, { marginTop: space.xs }]}>家庭は{sp.o_max_households}つまでです</Text> : null}
        </View>
      )}
    </Screen>
  );
}
