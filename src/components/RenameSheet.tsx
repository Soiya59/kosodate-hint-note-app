/**
 * D-1 名前を直す（小窓。ワイヤーフレーム v0.4 D-1・要件 v0.7 2-5節・4-1節）。
 * ①: 種類・名前・タグを1つの小窓で直す（rename_problem・set_problem_tags・set_problem_kind。どれも同じ判定で true/false）。
 * ②: 名前だけ（rename_measure）。欄の下に②の案内（A16 推奨。この小窓には一言の欄が無いので［一言へ］は出さない）。
 * できないとき（false）は、要件 2-5節の文をそのまま出して［閉じる］だけにする（見える③・見えない③で同じ文）。
 */
import React, { useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { ERRORS, HINTS, KIND_WORDS, MEASURE_GUIDE, MEASURE_LIMIT_NOTICE, MEASURE_MAX, type Kind } from "@/constants/texts";
import { Button, Chip, Field, Sheet, styles } from "@/components/ui";
import * as api from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { fitsKind, tagsForKind } from "@/lib/tags";
import { colors, space } from "@/theme";

type Target =
  | { type: "problem"; id: string; name: string; kind: Kind; tagIds: string[] }
  | { type: "measure"; id: string; name: string; kind: Kind };

export function RenameSheet(props: { target: Target | null; onClose: () => void; onDone: () => void }) {
  const { tags, space: sp, showToast, refresh } = useApp();
  const [mismatch, setMismatch] = useState(false);
  const t = props.target;
  const [name, setName] = useState("");
  const [kind, setKind] = useState<Kind>("trouble");
  const [tagIds, setTagIds] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [refused, setRefused] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!t) return;
    setName(t.name);
    setKind(t.kind);
    setTagIds(t.type === "problem" ? t.tagIds : []);
    setRefused(false);
    setError(null);
    setMismatch(false);
  }, [t]);

  if (!t) return null;
  const max = t.type === "problem" ? 30 : MEASURE_MAX;
  const W = KIND_WORDS[t.type === "problem" ? kind : t.kind];
  const admin = sp?.o_admin_display_name ?? "管理者";
  // （v0.5）いまの種類に合うタグだけを見せる・送る。種類を戻せば元の選択に戻る（小窓の中ではまだ外していない）
  const effectiveTags = tagIds.filter((id) => fitsKind(tags.find((x) => x.id === id), kind));
  const goneNames = t.type === "problem" && kind !== t.kind
    ? t.tagIds.filter((id) => !fitsKind(tags.find((x) => x.id === id), kind)).map((id) => tags.find((x) => x.id === id)?.name ?? "")
    : [];
  const becomesOther = t.type === "problem" && kind !== t.kind && goneNames.length > 0 && t.tagIds.every((id) => !fitsKind(tags.find((x) => x.id === id), kind));

  const save = async () => {
    const v = name.trim();
    if (!v) return setError("名前を入れてください");
    setBusy(true);
    setError(null);
    try {
      let ok = true;
      if (t.type === "problem") {
        if (ok && v !== t.name) ok = await api.renameProblem(t.id, v);
        // （v0.5）種類を変えるときは先に種類を変える（合わないタグはデータ置き場が外す＝設計書 Y4）。そのあと新しい種類に合うタグだけを送る
        if (ok && kind !== t.kind) ok = await api.setProblemKind(t.id, kind);
        const want = effectiveTags;
        const serverAfterKind = kind !== t.kind ? t.tagIds.filter((id) => fitsKind(tags.find((x) => x.id === id), kind)) : t.tagIds;
        const same = want.length === serverAfterKind.length && want.every((x) => serverAfterKind.includes(x));
        if (ok && !same && (want.length > 0 || kind === t.kind)) ok = await api.setProblemTags(t.id, want);
      } else if (v !== t.name) {
        ok = await api.renameMeasure(t.id, v);
      }
      if (!ok) return setRefused(true);
      showToast("直しました");
      props.onDone();
    } catch (e) {
      const key = (e as { key?: string }).key;
      if (key === "tag_kind_mismatch") {
        // 種類の行の下に文を出し、タグを読み直して合わない選択を外す（ワイヤーフレーム v0.6 #9）
        setMismatch(true);
        void refresh();
        setTagIds((ids) => ids.filter((id) => fitsKind(tags.find((x) => x.id === id), kind)));
        return;
      }
      setError(key === "check_violation" ? `${max}字までです` : key === "forbidden" ? "この操作はできません" : "直せませんでした。通信を確かめてください");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Sheet visible onClose={props.onClose} title={t.type === "problem" ? "名前とタグを直す" : `${W.measure}の名前を直す`}>
      {refused ? (
        <View>
          <Text style={[styles.body, { marginBottom: space.m }]} testID="rename-refused">
            この名前には、ほかの家庭の記録も付いているため、管理者（{admin}さん）だけが直せます。直したいときは{admin}さんに伝えてください。
          </Text>
          <Button kind="secondary" label="閉じる" onPress={props.onClose} />
        </View>
      ) : (
        <View>
          {t.type === "problem" ? (
            <View style={{ flexDirection: "row", alignItems: "center", marginBottom: space.m }}>
              <Text style={[styles.sub, { marginRight: space.s }]}>種類</Text>
              {(["trouble", "grow"] as Kind[]).map((k) => (
                <Pressable key={k} onPress={() => setKind(k)} style={[styles.segment, kind === k && styles.segmentOn]} testID={`d1-kind-${k}`}>
                  <Text style={[styles.body, kind === k && { color: colors.primary, fontWeight: "700" }]}>{KIND_WORDS[k].tab}{kind === k ? " ✓" : ""}</Text>
                </Pressable>
              ))}
            </View>
          ) : null}
          {mismatch ? <Text style={[styles.error, { marginTop: -space.s, marginBottom: space.s }]} testID="d1-mismatch">{ERRORS.tag_kind_mismatch}</Text> : null}
          {goneNames.length ? (
            <Text style={[styles.sub, { color: colors.text, marginTop: -space.s, marginBottom: space.m }]} testID="d1-gone-tags">
              合わないタグ（{goneNames.join("・")}）は外れます。{becomesOther ? "（タグが無くなるので『その他』が付きます）" : ""}
            </Text>
          ) : null}
          <Field
            value={name}
            onChangeText={(x) => setName([...x].slice(0, max).join(""))}
            maxLength={max}
            grow
            counter={`${[...name].length}/${max}`}
            hint={t.type === "measure" ? `${MEASURE_GUIDE}\n${HINTS.name}` : HINTS.name}
            error={error}
            testID="d1-name"
          />
          {t.type === "measure" && [...name].length >= MEASURE_MAX ? (
            <Text style={[styles.body, { marginTop: -space.s, marginBottom: space.m }]}>{MEASURE_LIMIT_NOTICE}</Text>
          ) : null}
          {t.type === "problem" ? (
            <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: space.m }}>
              {tagsForKind(tags, kind).map((tg) => (
                <Chip key={tg.id} label={tg.name} selected={tagIds.includes(tg.id)}
                  onPress={() => setTagIds(tagIds.includes(tg.id) ? tagIds.filter((x) => x !== tg.id) : [...tagIds, tg.id])} />
              ))}
            </View>
          ) : null}
          <View style={{ flexDirection: "row" }}>
            <Button kind="secondary" label="やめる" onPress={props.onClose} style={{ flex: 1, marginRight: space.s }} />
            <Button label={busy ? "直しています…" : "直す"} busy={busy} onPress={save} style={{ flex: 1 }} testID="d1-save" />
          </View>
        </View>
      )}
    </Sheet>
  );
}
