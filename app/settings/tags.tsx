/**
 * E-7 タグの追加（管理者。ワイヤーフレーム v0.5 E-7・要件 v0.8 4-5節・設計書 v0.5 Y5）。
 * いまのタグを種類ごとに3つの見出し（困りごと／育てたい／両方）で並べ、新しいタグの種類を選んで足す。
 * 種類の既定は B-1 でいま選んでいる種類（［すべて］なら困りごと）。並び順はデータ置き場のトリガーが種類ごとに決める。
 * 名前・種類の変更と削除は作らない（N-20）。管理者以外が開くと E-1 へ戻す。
 */
import React, { useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { TAG_KIND_LABEL, type TagKind } from "@/constants/texts";
import { Button, Field, Header, LongHeading, Screen, styles } from "@/components/ui";
import { createTag } from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { tagsForKind } from "@/lib/tags";
import { colors, space } from "@/theme";

export default function TagsAdd() {
  const router = useRouter();
  const { space: sp, tags, listKind, refresh, showToast } = useApp();
  const [kind, setKind] = useState<TagKind>(listKind ?? "trouble");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (sp && sp.o_role !== "admin") router.replace("/settings");
  }, [sp, router]);
  if (!sp || sp.o_role !== "admin") return null;

  const trouble = tagsForKind(tags, "trouble").filter((t) => t.kind === "trouble");
  const grow = tagsForKind(tags, "grow").filter((t) => t.kind === "grow");
  const both = tagsForKind(tags, null).filter((t) => t.kind === "both");

  const add = async () => {
    const v = name.trim();
    if (!v) return setError("名前を入れてください");
    setBusy(true);
    setError(null);
    try {
      await createTag(sp.o_space_id, v, kind);
      setName("");
      showToast("追加しました");
      await refresh(); // タグを読み直す（B-1 のタブにもすぐ出る）
    } catch (e) {
      const key = (e as { key?: string }).key;
      setError(key === "unique_violation" ? "同じ名前のタグがあります" : key === "forbidden" ? "この操作はできません" : key === "check_violation" ? "名前は10字までです" : "追加できませんでした。通信を確かめてください");
    } finally {
      setBusy(false);
    }
  };

  const group = (title: string, list: { id: string; name: string }[], id: string) => (
    <View>
      <LongHeading text={title} />
      <Text style={styles.long} testID={id}>{list.map((t) => t.name).join("／")}</Text>
    </View>
  );

  return (
    <Screen header={<Header title="タグの追加" fallback="/settings" />}>
      <Text style={styles.sub}>いまのタグ（この順でタブに並びます）</Text>
      {group("困りごと", trouble, "tags-trouble")}
      {group("育てたい", grow, "tags-grow")}
      {group("両方（困りごとにも育てたいにも出る）", both, "tags-both")}
      <View style={{ height: 1, backgroundColor: colors.border, marginVertical: space.l }} />
      <Text style={styles.label}>新しいタグの種類</Text>
      <View style={{ flexDirection: "row", marginBottom: space.m }}>
        {(["trouble", "grow", "both"] as TagKind[]).map((k) => (
          <Pressable key={k} accessibilityRole="radio" accessibilityState={{ checked: kind === k }} onPress={() => setKind(k)}
            style={[styles.segment, kind === k && styles.segmentOn]} testID={`tag-kind-${k}`}>
            <Text style={[styles.body, kind === k && { color: colors.primary, fontWeight: "700" }]}>{TAG_KIND_LABEL[k]}{kind === k ? " ✓" : ""}</Text>
          </Pressable>
        ))}
      </View>
      <Field label="新しいタグ" value={name} onChangeText={(t) => setName(t.slice(0, 10))} maxLength={10} counter={`${name.length}/10`} error={error} testID="tag-name" />
      <Button label={busy ? "追加しています…" : "追加する"} busy={busy} onPress={add} testID="tag-add" />
      <Text style={[styles.sub, { marginTop: space.m }]}>追加したタグは、選んだ種類の「その他」の前に入ります。</Text>
      <Text style={styles.sub}>このノートだけに入ります。</Text>
      <Text style={styles.sub}>名前・種類の変更と削除は、いまはできません。</Text>
    </Screen>
  );
}
