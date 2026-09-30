/**
 * B-4 対策の詳しい画面（ワイヤーフレーム v0.4 B-4・C-3・C-4・要件 v0.7 6-4節・4-3b節）。
 * カードの並びは list_measures の o_trials（B-3 の行の中と同じ並び）をそのまま使う。
 * v0.7: 見出しは「書いた人の呼び名（家庭名）」、試したいのカードに［試し始めた］（C-4）［点数を付ける］（C-3 の試したいの形）、
 *   テレビ・その他の詳細、「◯/◯に書いた」、育てたいのとき「やり方」。試し中の判定は status（点数が空＝試し中、にしない）。
 * 自家庭のカード: ［点数を付ける］・［試し始めた］・［消す］（D-2）。［⋯］→ D-1（②の名前を直す）。
 * （招待の前に要る画面・2026-09-30）［直す］（C-1 の直すモード）・［⋯］→ ②を消す・管理者として消す・「対策も消しますか」「困りごとも消しますか」。
 */
import React, { useCallback, useEffect, useState } from "react";
import { Linking, Pressable, Text, View } from "react-native";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import { pendingGlow } from "@/lib/glow";
import { DISCLAIMER, ERRORS, HINTS, KIND_WORDS, scoresFor, SOURCE_TYPES } from "@/constants/texts";
import { Button, ErrorBox, Header, Loading, ScoreBadge, Screen, Sheet, styles } from "@/components/ui";
import { AgePicker } from "@/components/AgePicker";
import { RenameSheet } from "@/components/RenameSheet";
import { deleteMeasure, deleteProblem, deleteTrial, getMeasure, getProblem, listMeasures, scoreWant, setTrialScore, startTrying, type TrialJson } from "@/lib/api";
import { deleteRefusal } from "@/lib/refusal";
import { ageRangeLabel, shortDate, todayJst, trialDays, type AgeValue } from "@/lib/format";
import { useApp } from "@/lib/app-state";
import { colors, font, space } from "@/theme";

export default function MeasureDetail() {
  const router = useRouter();
  const { id, hl } = useLocalSearchParams<{ id: string; hl?: string }>();
  const { space: sp, writerLabel, showToast, returnTo, refresh } = useApp();
  const [measure, setMeasure] = useState<Awaited<ReturnType<typeof getMeasure>> | undefined>(undefined);
  const [trials, setTrials] = useState<TrialJson[] | null>(null);
  const [error, setError] = useState(false);
  const [glow, setGlow] = useState<string | null>(hl ?? null);
  const [scoring, setScoring] = useState<TrialJson | null>(null);
  const [starting, setStarting] = useState<TrialJson | null>(null);
  const [picked, setPicked] = useState<number | null>(null);
  const [age, setAge] = useState<AgeValue | null>(null);
  const [agePicker, setAgePicker] = useState(false);
  const [deleting, setDeleting] = useState<TrialJson | null>(null);
  const [renaming, setRenaming] = useState(false);
  const [menu, setMenu] = useState(false);
  const [confirmDelMeasure, setConfirmDelMeasure] = useState(false);
  /** 「対策も消しますか」「困りごとも消しますか」（D-2 の続けて聞く） */
  const [ask, setAsk] = useState<null | { type: "measure" | "problem"; id: string; name: string }>(null);
  const [refusal, setRefusal] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [sheetError, setSheetError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(false);
    try {
      const m = await getMeasure(id);
      setMeasure(m);
      if (!m) return;
      const rows = await listMeasures(m.problem_id);
      setTrials(rows.find((r) => r.o_measure_id === id)?.o_trials ?? []);
    } catch {
      setError(true);
    }
  }, [id]);
  // 表に出るたびに読み直す（直すモードから戻ったとき・ほかの画面で書いたとき）
  useFocusEffect(
    useCallback(() => {
      void load();
      if (pendingGlow.id) {
        setGlow(pendingGlow.id);
        pendingGlow.id = null;
      }
    }, [load]),
  );
  useEffect(() => {
    if (!glow) return;
    const t = setTimeout(() => setGlow(null), 1500);
    return () => clearTimeout(t);
  }, [glow]);

  const W = KIND_WORDS[measure?.problem_kind ?? "trouble"];
  const mine = (t: TrialJson) => sp && t.household_id === sp.o_household_id;
  const canEdit = !!measure && !!sp && (sp.o_role === "admin" || measure.created_household_id === sp.o_household_id);

  const openScore = (t: TrialJson) => { setScoring(t); setPicked(null); setAge({ from: t.age_months, to: t.age_months_to }); setSheetError(null); };
  const openStart = (t: TrialJson) => { setStarting(t); setAge({ from: t.age_months, to: t.age_months_to }); setSheetError(null); };

  const handleError = (e: unknown, fallback: string) => {
    const key = (e as { key?: string }).key;
    if (key === "consent_required") {
      returnTo.current = `/measures/${id}`;
      void refresh();
      return;
    }
    setSheetError(key === "forbidden" ? ERRORS.forbidden : key === "check_violation" ? "3年までの範囲にしてください" : fallback);
  };

  const saveScore = async () => {
    if (!scoring || picked == null) return;
    setBusy(true);
    setSheetError(null);
    try {
      if (scoring.status === "want") await scoreWant(scoring.trial_id, picked, age!.from, age!.to);
      else await setTrialScore(scoring.trial_id, picked);
      const tid = scoring.trial_id;
      setScoring(null);
      showToast("点数を付けました");
      await load();
      setGlow(tid);
    } catch (e) {
      handleError(e, "保存できませんでした。もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  const saveStart = async () => {
    if (!starting || !age) return;
    setBusy(true);
    setSheetError(null);
    try {
      await startTrying(starting.trial_id, age.from, age.to); // .select() を付けない（設計書 15-7節）
      const tid = starting.trial_id;
      setStarting(null);
      showToast("試し中にしました");
      await load();
      setGlow(tid);
    } catch (e) {
      handleError(e, "保存できませんでした。もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  const isAdmin = sp?.o_role === "admin";
  const adminName = sp?.o_admin_display_name ?? "管理者";

  /** ②を消せたあと: 自家庭が作った①で、自分に見える③が0件なら「困りごとも消しますか」、そうでなければ B-3 へ */
  const afterMeasureGone = async () => {
    if (!measure) return router.dismissTo("/");
    const pr = await getProblem(measure.problem_id).catch(() => null);
    if (!pr) return router.dismissTo("/");
    const rows = await listMeasures(pr.id).catch(() => []);
    const visible = rows.reduce((n, r) => n + r.o_trials.length, 0);
    if (visible === 0 && sp && pr.created_household_id === sp.o_household_id) {
      setAsk({ type: "problem", id: pr.id, name: pr.name });
      return;
    }
    router.dismissTo({ pathname: "/problems/[id]", params: { id: pr.id } });
  };

  const doDelete = async () => {
    if (!deleting) return;
    const wasMine = mine(deleting);
    setBusy(true);
    setSheetError(null);
    try {
      await deleteTrial(deleting.trial_id);
      setDeleting(null);
      showToast("消しました");
      const m = await getMeasure(id);
      if (!m) {
        // 管理者が他家庭の最後の「みんな」の③を消して、②が見えなくなった（ワイヤーフレーム D-2 の注）。①も見えなければ B-1
        const pr = measure ? await getProblem(measure.problem_id).catch(() => null) : null;
        if (pr) router.dismissTo({ pathname: "/problems/[id]", params: { id: pr.id } });
        else router.dismissTo("/");
        return;
      }
      const rows = await listMeasures(m.problem_id);
      const left = rows.find((r) => r.o_measure_id === id)?.o_trials ?? [];
      setTrials(left);
      // 自家庭の③を消して、自分に見える③が0件になり、②を自家庭が作っていたら聞く（管理者が他家庭の③を消したときは聞かない）
      if (wasMine && left.length === 0 && sp && m.created_household_id === sp.o_household_id) {
        setAsk({ type: "measure", id: m.id, name: m.name });
      }
    } catch (e) {
      const key = (e as { key?: string }).key;
      setSheetError(key === "forbidden" ? ERRORS.forbidden : "消せませんでした。通信を確かめてください");
    } finally {
      setBusy(false);
    }
  };

  const runAsk = async () => {
    if (!ask) return;
    setBusy(true);
    try {
      if (ask.type === "measure") {
        const ok = await deleteMeasure(ask.id);
        setAsk(null);
        if (!ok) return setRefusal(deleteRefusal({ isAdmin, visibleHouseholdIds: [], myHouseholdId: sp?.o_household_id ?? "", adminName }));
        showToast("消しました");
        await afterMeasureGone();
      } else {
        const ok = await deleteProblem(ask.id);
        setAsk(null);
        if (!ok) return setRefusal(deleteRefusal({ isAdmin, visibleHouseholdIds: [], myHouseholdId: sp?.o_household_id ?? "", adminName }));
        showToast("消しました");
        router.dismissTo("/");
      }
    } catch {
      setAsk(null);
      setRefusal("消せませんでした。通信を確かめてください");
    } finally {
      setBusy(false);
    }
  };

  /** ［⋯］→［この対策を消す］ */
  const runDeleteMeasure = async () => {
    if (!measure) return;
    setBusy(true);
    try {
      const ok = await deleteMeasure(measure.id);
      setConfirmDelMeasure(false);
      if (!ok) {
        return setRefusal(deleteRefusal({ isAdmin, visibleHouseholdIds: (trials ?? []).map((t) => t.household_id), myHouseholdId: sp?.o_household_id ?? "", adminName }));
      }
      showToast("消しました");
      router.dismissTo({ pathname: "/problems/[id]", params: { id: measure.problem_id } });
    } catch {
      setConfirmDelMeasure(false);
      setRefusal("消せませんでした。通信を確かめてください");
    } finally {
      setBusy(false);
    }
  };

  if (measure === null) {
    return (
      <Screen header={<Header fallback="/" />}>
        <Text style={[styles.body, { marginBottom: space.m }]}>この{W.measure}は見つかりません（消されたか、見えなくなりました）</Text>
        <Button kind="secondary" label="困りごとの一覧へ" onPress={() => router.dismissTo("/")} />
      </Screen>
    );
  }

  const today = todayJst();
  const ageTag = (label: string) => (
    <View style={{ flexDirection: "row", alignItems: "center", marginTop: space.m }}>
      <Text style={[styles.sub, { marginRight: space.xs }]}>{label}</Text>
      <Text style={styles.valueTag} testID="sheet-age">{age ? ageRangeLabel(age.from, age.to) : ""}</Text>
      <Button kind="text" label="変える" onPress={() => setAgePicker(true)} testID="sheet-age-change" />
    </View>
  );

  return (
    <Screen
      header={<Header fallback={measure ? `/problems/${measure.problem_id}` : "/"} right={canEdit ? <Button kind="text" label="⋯" onPress={() => setMenu(true)} testID="measure-menu" /> : null} />}
      footer={
        <View>
          <Text style={[styles.sub, { marginBottom: space.s }]}>{DISCLAIMER}</Text>
          <Button
            label="うちでも試した"
            disabled={!measure}
            onPress={() => measure && router.push({ pathname: "/write", params: { problem: measure.problem_id, measure: measure.id } })}
            testID="also-tried"
          />
        </View>
      }
      overlay={<>
        {/* C-3 点数を付ける（試し中・試したいから） */}
        <Sheet visible={!!scoring} onClose={() => setScoring(null)} title="点数を付ける">
          {scoring ? (
            <View>
              <Text style={[styles.sub, { marginBottom: space.m }]}>
                {scoring.status === "want"
                  ? `${measure?.name}・${ageRangeLabel(scoring.age_months, scoring.age_months_to)}で試したい`
                  : `${measure?.name}・${ageRangeLabel(scoring.age_months, scoring.age_months_to)}のとき・試し中・${trialDays(scoring.tried_on)}日目`}
              </Text>
              {scoresFor(measure?.problem_kind).map((s) => (
                <Pressable key={s.v} onPress={() => setPicked(s.v)} style={[styles.row, { flexDirection: "row", alignItems: "center" }, picked === s.v && { backgroundColor: colors.primarySoft }]} testID={`c3-score-${s.v}`}>
                  <Text style={[styles.body, { width: 24 }]}>{picked === s.v ? "●" : "○"}</Text>
                  <ScoreBadge score={s.v} status="scored" kind={measure?.problem_kind} />
                  <Text style={[styles.sub, { flex: 1, marginLeft: space.s }]}>{s.guide}</Text>
                </Pressable>
              ))}
              <Text style={[styles.sub, { marginTop: space.s }]}>{HINTS.scoreEncourage}</Text>
              {scoring.status === "want" ? (
                <>
                  {ageTag("試した年齢")}
                  <Text style={[styles.sub, { marginTop: space.xs }]}>日付は今日（{shortDate(today)}）になります。</Text>
                </>
              ) : (
                <Text style={[styles.sub, { marginTop: space.xs }]}>日付は試し始めた日（{shortDate(scoring.tried_on)}）のままです。</Text>
              )}
              {sheetError ? <Text style={styles.error}>{sheetError}</Text> : null}
              <View style={{ flexDirection: "row", marginTop: space.l }}>
                <Button kind="secondary" label="やめる" onPress={() => setScoring(null)} style={{ flex: 1, marginRight: space.s }} />
                <Button label={busy ? "保存中…" : "保存"} disabled={picked == null} busy={busy} onPress={saveScore} style={{ flex: 1 }} testID="c3-save" />
              </View>
            </View>
          ) : null}
        </Sheet>

        {/* C-4 試し始めた（試したいから） */}
        <Sheet visible={!!starting} onClose={() => setStarting(null)} title="試し始めた">
          {starting ? (
            <View>
              <Text style={styles.sub}>{measure?.name}・{ageRangeLabel(starting.age_months, starting.age_months_to)}で試したい</Text>
              {ageTag("始めた年齢")}
              <Text style={[styles.sub, { marginTop: space.xs }]}>「試し中」になり、日付は今日（{shortDate(today)}）になります。</Text>
              {sheetError ? <Text style={styles.error}>{sheetError}</Text> : null}
              <View style={{ flexDirection: "row", marginTop: space.l }}>
                <Button kind="secondary" label="やめる" onPress={() => setStarting(null)} style={{ flex: 1, marginRight: space.s }} />
                <Button label={busy ? "保存中…" : "試し始めた"} busy={busy} onPress={saveStart} style={{ flex: 1 }} testID="c4-save" />
              </View>
            </View>
          ) : null}
        </Sheet>

        <AgePicker
          visible={agePicker}
          onClose={() => setAgePicker(false)}
          title={starting ? "何歳で始めた" : "何歳のとき"}
          value={age}
          onPick={(v) => { setAge(v); setAgePicker(false); }}
        />

        {/* D-2 消す確認（③） */}
        <Sheet visible={!!deleting} onClose={() => setDeleting(null)} title={deleting && !mine(deleting) ? "管理者として消す" : "この記録を消しますか"}>
          <Text style={[styles.body, { marginBottom: space.m }]} testID="delete-text">
            {deleting && !mine(deleting)
              ? `${deleting.household_name ?? "ほかの家庭"}の記録を、管理者として消します。消す前に、書いた人に伝えてください。元に戻せません。`
              : "この記録を消しますか。消すと元に戻せません。"}
          </Text>
          {sheetError ? <Text style={styles.error}>{sheetError}</Text> : null}
          <View style={{ flexDirection: "row", marginTop: space.m }}>
            <Button kind="secondary" label="やめる" onPress={() => setDeleting(null)} style={{ flex: 1, marginRight: space.s }} />
            <Button kind="secondary" label={busy ? "消しています…" : "消す"} busy={busy} onPress={doDelete} style={{ flex: 1 }} testID="delete-confirm" />
          </View>
        </Sheet>

        {/* ［⋯］の中身（②を作った家庭のメンバーと管理者に常に出す） */}
        <Sheet visible={menu} onClose={() => setMenu(false)} title={measure?.name ?? ""}>
          <Button kind="secondary" label="名前を直す" onPress={() => { setMenu(false); setRenaming(true); }} testID="menu-rename" />
          <Button kind="secondary" label={`この${W.measure}を消す`} onPress={() => { setMenu(false); setConfirmDelMeasure(true); }} style={{ marginTop: space.s }} testID="menu-delete" />
        </Sheet>
        <Sheet visible={confirmDelMeasure} onClose={() => setConfirmDelMeasure(false)} title={`この${W.measure}を消す`}>
          <Text style={[styles.body, { marginBottom: space.m }]}>『{measure?.name}』を消しますか。記録が付いていないときだけ消せます。消すと元に戻せません。</Text>
          <View style={{ flexDirection: "row" }}>
            <Button kind="secondary" label="やめる" onPress={() => setConfirmDelMeasure(false)} style={{ flex: 1, marginRight: space.s }} />
            <Button kind="secondary" label={busy ? "消しています…" : "消す"} busy={busy} onPress={runDeleteMeasure} style={{ flex: 1 }} testID="measure-delete-confirm" />
          </View>
        </Sheet>
        <Sheet visible={!!ask} onClose={() => setAsk(null)} title="続けて消しますか">
          {ask ? (
            <View>
              <Text style={[styles.body, { marginBottom: space.m }]} testID="ask-text">
                {ask.type === "measure" ? `${W.measure}『${ask.name}』も消しますか。` : `${W.problem}『${ask.name}』も消しますか。`}
              </Text>
              <View style={{ flexDirection: "row" }}>
                <Button kind="secondary" label="残す" onPress={() => setAsk(null)} style={{ flex: 1, marginRight: space.s }} testID="ask-keep" />
                <Button kind="secondary" label={busy ? "消しています…" : ask.type === "measure" ? `${W.measure}も消す` : `${W.problem}も消す`} busy={busy} onPress={runAsk} style={{ flex: 1 }} testID="ask-delete" />
              </View>
            </View>
          ) : null}
        </Sheet>
        <Sheet visible={!!refusal} onClose={() => setRefusal(null)} title="消せませんでした">
          <Text style={[styles.body, { marginBottom: space.m }]} testID="refusal-text">{refusal}</Text>
          <Button kind="secondary" label="閉じる" onPress={() => setRefusal(null)} />
        </Sheet>
        {measure && renaming ? (
          <RenameSheet
            target={{ type: "measure", id: measure.id, name: measure.name, kind: measure.problem_kind }}
            onClose={() => setRenaming(false)}
            onDone={() => { setRenaming(false); void load(); }}
          />
        ) : null}
      </>}
    >
      <Text style={styles.sub}>{measure?.problem_name ?? ""}</Text>
      <Text style={[font.title, { color: colors.text, marginBottom: space.m }]} testID="measure-title">{measure?.name ?? ""}</Text>
      {error ? <ErrorBox onRetry={load} /> : trials == null ? <Loading /> : trials.length === 0 ? (
        <Text style={styles.body}>この{W.measure}には、まだ記録がありません。</Text>
      ) : (
        trials.map((t) => (
          <View key={t.trial_id} style={[styles.card, glow === t.trial_id && { backgroundColor: colors.primarySoft }]} testID="trial-card">
            <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
              <Text style={[font.rowTitle, { color: colors.text, flex: 1 }]} testID="trial-writer">{writerLabel(t)}</Text>
              {t.visibility === "household" ? <Text style={styles.sub}>🔒うちだけ</Text> : null}
            </View>
            <View style={{ flexDirection: "row", alignItems: "center", marginTop: space.s, flexWrap: "wrap" }}>
              <ScoreBadge score={t.score} status={t.status} triedOn={t.tried_on} kind={measure?.problem_kind} />
              <Text style={[styles.body, { marginLeft: space.s }]}>
                {ageRangeLabel(t.age_months, t.age_months_to)}{t.status === "want" ? "で試したい" : "のとき"}
              </Text>
            </View>
            <Text style={[styles.sub, { marginTop: space.xs }]} testID="trial-date">
              {t.status === "trying" ? `${shortDate(t.tried_on)}から` : t.status === "want" ? `${shortDate(t.tried_on)}に書いた` : t.tried_on}
            </Text>
            <SourceLine t={t} />
            {t.note ? <Text style={[styles.body, { marginTop: space.s }]}>{t.note}</Text> : null}
            {mine(t) ? (
              <View style={{ marginTop: space.m }}>
                {t.status === "trying" ? (
                  <Button label="点数を付ける" onPress={() => openScore(t)} testID="score-open" />
                ) : null}
                {t.status === "want" ? (
                  // 2つを横に同じ形で（どちらかを強く見せない＝促さない。ワイヤーフレーム v0.4 B-4）
                  <View style={{ flexDirection: "row" }}>
                    <Button kind="secondary" label="試し始めた" onPress={() => openStart(t)} style={{ flex: 1, marginRight: space.s, height: 48 }} testID="start-open" />
                    <Button kind="secondary" label="点数を付ける" onPress={() => openScore(t)} style={{ flex: 1, height: 48 }} testID="want-score-open" />
                  </View>
                ) : null}
                <View style={{ flexDirection: "row", justifyContent: "flex-end", marginTop: space.s }}>
                  <Button kind="text" label="直す" onPress={() => router.push({ pathname: "/trials/[id]/edit", params: { id: t.trial_id } })} testID="trial-edit" />
                  <Button kind="text" label="消す" onPress={() => { setDeleting(t); setSheetError(null); }} testID="trial-delete" />
                </View>
              </View>
            ) : isAdmin && t.visibility === "all" ? (
              // 管理者: 他家庭の「みんな」のカードを消せる（本人に連絡するのが原則）
              <View style={{ flexDirection: "row", justifyContent: "flex-end", marginTop: space.s }}>
                <Button kind="text" label="管理者として消す" onPress={() => { setDeleting(t); setSheetError(null); }} testID="trial-admin-delete" />
              </View>
            ) : null}
          </View>
        ))
      )}
    </Screen>
  );
}

function SourceLine({ t }: { t: TrialJson }) {
  const label = SOURCE_TYPES.find((s) => s.v === t.source_type)?.label ?? "";
  let detail: string | null = null;
  if (t.source_type === "book" && t.book_title) detail = `『${t.book_title}』${t.book_author ?? ""}`;
  if (t.source_type === "heard" && t.heard_from) detail = `（${t.heard_from}）`;
  if ((t.source_type === "tv" || t.source_type === "other") && t.source_text) detail = t.source_text;
  return (
    <View style={{ marginTop: space.s }}>
      <Text style={styles.body} testID="trial-source">どこで知った: {label}{detail ? `  ${detail}` : ""}</Text>
      {t.source_type === "web" && t.source_url ? (
        <Text style={[styles.link, styles.body]} onPress={() => void Linking.openURL(t.source_url!)} numberOfLines={1}>
          {t.source_url.length > 40 ? `${t.source_url.slice(0, 40)}…` : t.source_url}
        </Text>
      ) : null}
    </View>
  );
}
