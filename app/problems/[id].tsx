/**
 * B-3 対策の一覧（困りごとを開いた画面）。ワイヤーフレーム v0.4 B-3・要件 v0.7 6-3節・設計書 v0.4 5-2節（list_measures）。
 * v0.7: 行の③は「書いた人の呼び名（家庭名）［札］年齢」、試したいの札、出典のタブ7つ、年齢は範囲も、育てたいのとき「やり方」。
 * ［⋯］→ D-1（名前・タグ・種類を直す）。①を作った家庭のメンバーと管理者に常に出す（要件 2-5節 案A）。
 * （招待の前に要る画面・2026-09-30）［⋯］の［この困りごとを消す］（delete_problem。false なら要件 2-5節の断りの文）。
 */
import React, { useCallback, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import { KIND_WORDS, SOURCE_TYPES } from "@/constants/texts";
import { TRIALS_PER_ROW } from "@/constants/config";
import { Button, Chip, ErrorBox, Header, Loading, ScoreBadge, Screen, Sheet, styles } from "@/components/ui";
import { RenameSheet } from "@/components/RenameSheet";
import { deleteProblem, getProblem, listMeasures, type MeasureRow } from "@/lib/api";
import { deleteRefusal } from "@/lib/refusal";
import { tagsForKind } from "@/lib/tags";
import { ageRangeLabel } from "@/lib/format";
import { useApp } from "@/lib/app-state";
import { colors, font, radius, space } from "@/theme";

export default function ProblemMeasures() {
  const router = useRouter();
  const { id, age } = useLocalSearchParams<{ id: string; age?: string }>();
  const [ageF, setAgeF] = useState<{ from: number; to: number | null } | null>(age ? { from: Number(age), to: null } : null);
  const { tags, writerLabel, space: sp, showToast } = useApp();
  const [problem, setProblem] = useState<Awaited<ReturnType<typeof getProblem>> | undefined>(undefined);
  const [rows, setRows] = useState<MeasureRow[] | null>(null);
  const [source, setSource] = useState<string | null>(null);
  const [error, setError] = useState(false);
  const [renaming, setRenaming] = useState(false);
  const [menu, setMenu] = useState(false);
  const [confirmDel, setConfirmDel] = useState(false);
  const [refusal, setRefusal] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setError(false);
    try {
      const [p, m] = await Promise.all([getProblem(id), listMeasures(id, source, ageF?.from ?? null, ageF?.to ?? null)]);
      setProblem(p);
      setRows(m);
    } catch {
      setError(true);
    }
  }, [id, source, ageF]);
  // 表に出るたびに読み直す（B-4 で消した・書いたあとに戻ったとき）
  useFocusEffect(useCallback(() => { void load(); }, [load]));

  if (problem === null) {
    return (
      <Screen header={<Header fallback="/" />}>
        <Text style={[styles.body, { marginBottom: space.m }]}>この困りごとは見つかりません（消されたか、見えなくなりました）</Text>
        <Button kind="secondary" label="困りごとの一覧へ" onPress={() => router.replace("/")} />
      </Screen>
    );
  }

  const W = KIND_WORDS[problem?.kind ?? "trouble"];
  // ①のタグを、その①の種類のタブの順で（v0.5。育てたいは育てたいの並び）
  const own = new Set((problem?.problem_tags ?? []).map((pt) => pt.tag_id));
  const tagNames = tagsForKind(tags, problem?.kind ?? "trouble").filter((t) => own.has(t.id)).map((t) => t.name);
  const canEdit = !!problem && !!sp && (sp.o_role === "admin" || problem.created_household_id === sp.o_household_id);
  /** ［⋯］→［この困りごとを消す］。false なら、画面に見えている③（絞り込みなしの全行）で文を選ぶ（要件 2-5節・設計書 3-4節） */
  const runDelete = async () => {
    if (!problem || !sp) return;
    setBusy(true);
    try {
      const ok = await deleteProblem(problem.id);
      setConfirmDel(false);
      if (!ok) {
        const all = await listMeasures(problem.id).catch(() => []);
        const hh = all.flatMap((m) => m.o_trials.map((t) => t.household_id));
        return setRefusal(deleteRefusal({ isAdmin: sp.o_role === "admin", visibleHouseholdIds: hh, myHouseholdId: sp.o_household_id, adminName: sp.o_admin_display_name ?? "管理者" }));
      }
      showToast("消しました");
      router.dismissTo("/");
    } catch {
      setConfirmDel(false);
      setRefusal("消せませんでした。通信を確かめてください");
    } finally {
      setBusy(false);
    }
  };
  const ageText = ageF == null ? "" : ageF.to != null ? `${ageF.from}〜${ageF.to}歳` : `${ageF.from}歳`;

  return (
    <Screen
      header={<Header fallback="/" right={canEdit ? <Button kind="text" label="⋯" onPress={() => setMenu(true)} testID="problem-menu" /> : null} />}
      onFab={() => router.push({ pathname: "/write", params: { problem: id } })}
      overlay={<>
        <Sheet visible={menu} onClose={() => setMenu(false)} title={problem?.name ?? ""}>
          <Button kind="secondary" label="名前とタグを直す" onPress={() => { setMenu(false); setRenaming(true); }} testID="menu-rename" />
          <Button kind="secondary" label={`この${W.problem}を消す`} onPress={() => { setMenu(false); setConfirmDel(true); }} style={{ marginTop: space.s }} testID="menu-delete" />
        </Sheet>
        <Sheet visible={confirmDel} onClose={() => setConfirmDel(false)} title={`この${W.problem}を消す`}>
          <Text style={[styles.body, { marginBottom: space.m }]}>
            『{problem?.name}』を消しますか。記録が付いていないときだけ消せます。消すと元に戻せません。この{W.problem}の、記録のない{W.measure}も一緒に消えます。
          </Text>
          <View style={{ flexDirection: "row" }}>
            <Button kind="secondary" label="やめる" onPress={() => setConfirmDel(false)} style={{ flex: 1, marginRight: space.s }} />
            <Button kind="secondary" label={busy ? "消しています…" : "消す"} busy={busy} onPress={runDelete} style={{ flex: 1 }} testID="problem-delete-confirm" />
          </View>
        </Sheet>
        <Sheet visible={!!refusal} onClose={() => setRefusal(null)} title="消せませんでした">
          <Text style={[styles.body, { marginBottom: space.m }]} testID="refusal-text">{refusal}</Text>
          <Button kind="secondary" label="閉じる" onPress={() => setRefusal(null)} />
        </Sheet>
        {problem && renaming ? (
          <RenameSheet
            target={{ type: "problem", id: problem.id, name: problem.name, kind: problem.kind, tagIds: problem.problem_tags.map((x) => x.tag_id) }}
            onClose={() => setRenaming(false)}
            onDone={() => { setRenaming(false); void load(); }}
          />
        ) : null}
      </>}
    >
      <Text style={[font.title, { color: colors.text }]} testID="problem-title">{problem?.name ?? ""}</Text>
      <Text style={[styles.sub, { marginTop: space.xs }]}>{tagNames.map((t) => `[${t}]`).join(" ")}</Text>
      <Text style={[styles.sub, { marginTop: space.s }]}>家庭ごとに試した結果です。{"\n"}合う・合わないは子どもによって違います。</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginTop: space.m }}>
        <Chip label="すべて" selected={!source} onPress={() => setSource(null)} />
        {SOURCE_TYPES.map((s) => <Chip key={s.v} label={s.tab} selected={source === s.v} onPress={() => setSource(s.v)} testID={`tab-source-${s.v}`} />)}
      </ScrollView>
      {ageF != null ? (
        <View style={{ flexDirection: "row", alignItems: "center", alignSelf: "flex-start", backgroundColor: colors.primarySoft, borderRadius: radius.input, paddingLeft: space.m, marginTop: space.s }}>
          <Text style={styles.body}>{ageText}で絞り込み中</Text>
          <Button kind="text" label="×" onPress={() => setAgeF(null)} />
        </View>
      ) : null}
      {error ? <ErrorBox onRetry={load} /> : rows == null ? <Loading /> : rows.length === 0 ? (
        <View style={{ marginTop: space.l }}>
          {ageF != null ? (
            <>
              <Text style={[styles.body, { marginBottom: space.m }]}>{ageText}で試した{W.measure}は見えるものがありません。</Text>
              <Button kind="secondary" label="絞り込みを外す" onPress={() => setAgeF(null)} />
            </>
          ) : source ? (
            <Text style={styles.body}>この種類で知った{W.measure}はまだありません。</Text>
          ) : (
            <>
              <Text style={[styles.body, { marginBottom: space.m }]}>この{W.problem}には、まだ{W.measure}がありません。</Text>
              <Button label={`最初の${W.measure}を書く`} onPress={() => router.push({ pathname: "/write", params: { problem: id } })} />
            </>
          )}
        </View>
      ) : (
        <View style={{ marginTop: space.s }}>
          {rows.map((m) => {
            const shown = m.o_trials.slice(0, TRIALS_PER_ROW);
            const rest = m.o_trials.length - shown.length;
            return (
              <Pressable
                key={m.o_measure_id}
                accessibilityRole="button"
                style={styles.row}
                onPress={() => router.push({ pathname: "/measures/[id]", params: { id: m.o_measure_id } })}
                testID="measure-row"
              >
                <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                  <Text style={[font.rowTitle, { color: colors.text, flex: 1 }]}>{m.o_name}</Text>
                  <Text style={styles.sub}>›</Text>
                </View>
                {m.o_trials.length === 0 ? (
                  <Text style={[styles.sub, { marginTop: space.xs }]}>まだ記録がありません（うちだけに見えています）</Text>
                ) : (
                  shown.map((t) => (
                    <View key={t.trial_id} style={{ flexDirection: "row", alignItems: "center", marginTop: space.xs, flexWrap: "wrap" }} testID="trial-line">
                      <Text style={[styles.body, { marginRight: space.s }, t.in_age && { fontWeight: "700" }]}>{writerLabel(t)}</Text>
                      <ScoreBadge score={t.score} status={t.status} triedOn={t.tried_on} bold={t.in_age} kind={problem?.kind} />
                      <Text style={[styles.body, { marginLeft: space.s }, t.in_age && { fontWeight: "700" }]}>{ageRangeLabel(t.age_months, t.age_months_to)}</Text>
                      {t.visibility === "household" ? <Text style={[styles.sub, { marginLeft: space.s }]}>🔒うちだけ</Text> : null}
                    </View>
                  ))
                )}
                {rest > 0 ? <Text style={[styles.sub, { marginTop: space.xs }]}>ほか {rest}件</Text> : null}
              </Pressable>
            );
          })}
          <View style={{ height: 72 }} />
        </View>
      )}
    </Screen>
  );
}
