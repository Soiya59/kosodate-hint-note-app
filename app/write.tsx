/**
 * C-1 書く画面（新しく書く）。ワイヤーフレーム v0.4 C-1・C-2・C-5・要件 v0.7 4-7節・F-10〜F-18・設計書 v0.4 6章（save_trial）。
 * - ①②は必ず save_trial で作る（表に直接入れない。設計書 6-1節）。本は先に ensure_book。
 * - v0.7: 一番上に［困りごと］［育てたい］、効き目に［試したい］、年齢の範囲（C-2）、出典6つと詳細、②の欄の案内（A16 推奨）。
 * - 入り方: 空（B-1・B-2。?kind=grow なら育てたい）／?q=検索の言葉（新しい①として）／?problem=①（①入り・種類固定）
 *   ／?problem=①&measure=②（うちでも試した・種類固定）
 * - 書きかけはこの端末だけに保存（F-15）。最近選んだ年齢は最大3つ（範囲も1つとして覚える。F-16）。
 * - 直すモード（/trials/[id]/edit。2026-09-30 招待の前に要る画面）: 題は「直す」、1・2 は名前だけ表示（変えられない）、
 *   3〜6・日付・見える人は保存済みの値。3 効き目は7つのどれにも直せる。表 trials を UPDATE（結果は受け取らない）。書きかけは残さない。
 */
import React, { useEffect, useMemo, useRef, useState } from "react";
import { Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import {
  DISCLAIMER, ERRORS, HEARD_FROM, HINTS, KIND_WORDS, MEASURE_GUIDE, MEASURE_LIMIT_NOTICE, MEASURE_MAX, scoreHeading, scoresFor, WANT_EDIT,
  SOURCE_TEXT_FIELD, SOURCE_TEXT_MAX, SOURCE_TYPES, TRIAL_GUIDE, WANT_DEFAULT_VISIBILITY, WANT_GUIDE,
  type Kind, type SourceType,
} from "@/constants/texts";
import { DEBOUNCE_MS, RECENT_AGES } from "@/constants/config";
import { Button, Chip, Field, Header, Notice, ScoreBadge, Screen, Sheet, styles } from "@/components/ui";
import { DatePicker, dateLabel } from "@/components/DatePicker";
import { AgePicker } from "@/components/AgePicker";
import * as api from "@/lib/api";
import { ageRangeLabel, isValidDate, sameAge, todayJst, type AgeValue } from "@/lib/format";
import { KEYS, useApp } from "@/lib/app-state";
import { storage } from "@/lib/storage";
import { fitsKind, tagsForKind } from "@/lib/tags";
import { pendingGlow } from "@/lib/glow";
import { colors, space } from "@/theme";

type Choice = number | "trial" | "want";
type Form = {
  kind: Kind;
  problemId: string | null;
  problemText: string;
  tagIds: string[];
  measureId: string | null;
  measureText: string;
  score: Choice | null;
  age: AgeValue | null;
  source: SourceType;
  bookId: string | null;
  bookTitle: string;
  bookAuthor: string;
  url: string;
  heard: string;
  sourceText: string;
  note: string;
  triedOn: string;
  visibility: "all" | "household";
  /** 見える人を自分で選んだか（選んでいなければ、試したいを選んだときに既定へ合わせる） */
  visTouched: boolean;
};

const empty = (): Form => ({
  kind: "trouble", problemId: null, problemText: "", tagIds: [], measureId: null, measureText: "", score: null, age: null,
  source: "own", bookId: null, bookTitle: "", bookAuthor: "", url: "", heard: "", sourceText: "", note: "",
  triedOn: todayJst(), visibility: "all", visTouched: false,
});

/** 前の版の書きかけ（年齢が数だった）も読めるようにそろえる */
function normalizeDraft(x: Partial<Form> & { ageMonths?: number | null }): Form {
  const f = { ...empty(), ...x } as Form;
  if (!x.age && typeof x.ageMonths === "number") f.age = { from: x.ageMonths, to: null };
  return f;
}
function normalizeRecent(raw: unknown): AgeValue[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((r) => (typeof r === "number" ? { from: r, to: null } : (r as AgeValue))).filter((r) => r && typeof r.from === "number");
}

function useDebounced<T>(value: T, ms: number): T {
  const [v, setV] = useState(value);
  useEffect(() => {
    const h = setTimeout(() => setV(value), ms);
    return () => clearTimeout(h);
  }, [value, ms]);
  return v;
}

export default function Write() {
  return <WriteScreen />;
}

export function WriteScreen(props: { editId?: string }) {
  const editId = props.editId;
  const router = useRouter();
  const params = useLocalSearchParams<{ problem?: string; measure?: string; q?: string; resume?: string; kind?: string }>();
  const { space: sp, tags, showToast, refresh, returnTo } = useApp();
  const [f, setF] = useState<Form>(() => ({ ...empty(), problemText: params.q ?? "", kind: params.kind === "grow" ? "grow" : "trouble" }));
  const set = (patch: Partial<Form>) => setF((x) => ({ ...x, ...patch }));
  const [lockedMeasure, setLockedMeasure] = useState(false);
  const [recent, setRecent] = useState<AgeValue[]>([]);
  const [draft, setDraft] = useState<Form | null>(null);
  const [agePicker, setAgePicker] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const [pSug, setPSug] = useState<api.Suggest[] | null>(null);
  const [mSug, setMSug] = useState<api.Suggest[] | null>(null);
  const [bSug, setBSug] = useState<{ id: string; title: string; author: string | null }[] | null>(null);
  const [mFocus, setMFocus] = useState(false);
  const [mLimit, setMLimit] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saveError, setSaveError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [dup, setDup] = useState<null | { kind: "problem" | "measure"; id: string; name: string }>(null);
  const [editMissing, setEditMissing] = useState(false);
  /** 種類を変えて外したタグの名前（「種類を変えたので、合わないタグ（◯◯）を外しました。」） */
  const [removedTags, setRemovedTags] = useState<string[]>([]);
  /** 直すモード: 開いたときの状態と日付（試したいから直すと日付が今日になる決まり＝設計書 v0.5 6章） */
  const [orig, setOrig] = useState<null | { status: api.TrialStatus; triedOn: string }>(null);
  const skipDup = useRef(false);
  const touched = useRef(false);
  const scrollRef = useRef<ScrollView>(null);
  const noteRef = useRef<TextInput>(null);
  const noteY = useRef(0);
  const W = KIND_WORDS[f.kind];
  const isWant = f.score === "want";

  // ---- 最初の状態（入り方ごと）と、書きかけ・最近の年齢 ----
  useEffect(() => {
    void (async () => {
      const r = await storage.getItem(KEYS.recentAges);
      try { setRecent(normalizeRecent(r ? JSON.parse(r) : [])); } catch { setRecent([]); }
      if (editId) {
        const t = await api.getTrial(editId).catch(() => null);
        if (!t) { setEditMissing(true); return; }
        const m = await api.getMeasure(t.measure_id).catch(() => null);
        setF({
          ...empty(),
          kind: m?.problem_kind ?? "trouble",
          problemId: m?.problem_id ?? null, problemText: m?.problem_name ?? "",
          measureId: t.measure_id, measureText: m?.name ?? "",
          score: t.status === "want" ? "want" : t.status === "trying" ? "trial" : t.score,
          age: { from: t.age_months, to: t.age_months_to },
          source: t.source_type,
          bookId: t.book_id, bookTitle: t.books?.title ?? "", bookAuthor: t.books?.author ?? "",
          url: t.source_url ?? "", heard: t.heard_from ?? "", sourceText: t.source_text ?? "", note: t.note ?? "",
          triedOn: t.tried_on, visibility: t.visibility, visTouched: true,
        });
        setLockedMeasure(true);
        setOrig({ status: t.status, triedOn: t.tried_on });
        return;
      }
      if (params.problem) {
        const p = await api.getProblem(params.problem).catch(() => null);
        if (p) set({ problemId: p.id, problemText: p.name, kind: p.kind });
        if (params.measure) {
          const m = await api.getMeasure(params.measure).catch(() => null);
          // ［うちでも試した］から開いたときは「このノートで知った」が選ばれた状態（要件 v0.8 4-7節・C105）
          if (m) { set({ measureId: m.id, measureText: m.name, source: "notebook" }); setLockedMeasure(true); }
        }
        return;
      }
      if (params.q) return;
      const d = await storage.getItem(KEYS.draft);
      if (d) {
        try {
          const parsed = JSON.parse(d) as { spaceId: string; form: Partial<Form> };
          if (parsed.spaceId === sp?.o_space_id) {
            if (params.resume) setF(normalizeDraft(parsed.form));
            else setDraft(normalizeDraft(parsed.form));
          }
        } catch { /* 壊れた書きかけは使わない */ }
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!touched.current || !sp || editId) return; // 直すモードでは書きかけを残さない
    const h = setTimeout(() => void storage.setItem(KEYS.draft, JSON.stringify({ spaceId: sp.o_space_id, form: f })), 500);
    return () => clearTimeout(h);
  }, [f, sp]);
  const edit = (patch: Partial<Form>) => { touched.current = true; set(patch); };

  // ---- 候補（F-17）。①は両方の種類から出し、育てたいの①には札（ワイヤーフレーム v0.4 12-4節 #1） ----
  const pText = useDebounced(f.problemText, DEBOUNCE_MS);
  useEffect(() => {
    if (!sp || f.problemId || !pText.trim()) return setPSug(null);
    let alive = true;
    api.suggestProblems(sp.o_space_id, pText).then((r) => alive && setPSug(r)).catch(() => alive && setPSug([]));
    return () => { alive = false; };
  }, [pText, f.problemId, sp]);

  const mText = useDebounced(f.measureText, DEBOUNCE_MS);
  useEffect(() => {
    if (!f.problemId || f.measureId || !mFocus) return setMSug(null);
    let alive = true;
    api.suggestMeasures(f.problemId, mText).then((r) => alive && setMSug(r)).catch(() => alive && setMSug([]));
    return () => { alive = false; };
  }, [mText, f.problemId, f.measureId, mFocus]);

  const bText = useDebounced(f.bookTitle, DEBOUNCE_MS);
  useEffect(() => {
    if (!sp || f.source !== "book" || f.bookId || !bText.trim()) return setBSug(null);
    let alive = true;
    api.suggestBooks(sp.o_space_id, bText).then((r) => alive && setBSug(r)).catch(() => alive && setBSug([]));
    return () => { alive = false; };
  }, [bText, f.bookId, f.source, sp]);

  const newProblem = !f.problemId && f.problemText.trim() !== "";
  const kindLocked = !!f.problemId; // ①を選んだら（B-3・B-4 から開いたときも）種類はその①のまま
  const ageWord = isWant ? "何歳で試したい" : "何歳のとき";
  const missing = useMemo(() => {
    const m: string[] = [];
    if (!f.problemId && !f.problemText.trim()) m.push(W.problem);
    if (!f.measureId && !f.measureText.trim()) m.push(W.measure);
    if (f.score == null) m.push(scoreHeading(f.kind));
    if (f.age == null) m.push(ageWord);
    return m;
  }, [f, W, ageWord]);

  const close = () => {
    if (touched.current && !editId) showToast("書きかけはこの端末に残っています");
    if (router.canGoBack()) router.back();
    else router.replace("/");
  };

  const pickScore = (v: Choice) => {
    const patch: Partial<Form> = { score: v };
    // 試したいを選んだとき、見える人をまだ自分で選んでいなければ既定（A15 推奨＝みんな。texts.ts の1か所）に合わせる
    if (v === "want" && !f.visTouched) patch.visibility = WANT_DEFAULT_VISIBILITY;
    if (v !== "want" && f.score === "want" && !f.visTouched) patch.visibility = "all";
    // 直すモードで「試したい」を試し中・試したに直すとき、日付を選び直していなければ今日になる（設計書 v0.5 6章・本部長判断）。
    // 画面でも先に今日にして見せる（違う日にしたいときは、試した日を選び直す）
    if (editId && orig?.status === "want" && v !== "want" && f.triedOn === orig.triedOn) patch.triedOn = todayJst();
    if (editId && orig?.status === "want" && v === "want") patch.triedOn = orig.triedOn;
    edit(patch);
  };
  // （v0.9・C116・ワイヤーフレーム v0.6 C-1）直すモードで試したいから試し中・点数に直したとき:
  //   日付の札は「今日（9/30）になります」、日付の行の下に1行だけ知らせる（効き目の下には出さない）。別の日を選んだら消える。
  const today = todayJst();
  const fromWant = !!editId && orig?.status === "want" && f.score !== "want" && f.score != null;
  const becomesToday = fromWant && (f.triedOn === today || f.triedOn === orig!.triedOn);
  const wantDateNotice = !becomesToday
    ? null
    : f.triedOn === orig!.triedOn && orig!.triedOn !== today
      ? WANT_EDIT.sameDay(dateLabel(orig!.triedOn))
      : WANT_EDIT.notice;
  const [tagMismatch, setTagMismatch] = useState(false);

  const validate = (): boolean => {
    const e: Record<string, string> = {};
    if (!f.problemId && !f.problemText.trim()) e.problem = `${W.problem}を入れてください`;
    if (!f.measureId && !f.measureText.trim()) e.measure = `${W.measure}を入れてください`;
    if (f.score == null) e.score = `${scoreHeading(f.kind)}を選んでください`;
    if (f.age == null) e.age = `${ageWord}かを選んでください`;
    if (f.source === "web" && f.url.trim() && !/^https:\/\/\S+$/.test(f.url.trim())) e.url = "https:// で始まるアドレスを入れてください";
    if (!isValidDate(f.triedOn)) e.date = "日付を選んでください";
    else if (f.triedOn > todayJst()) e.date = ERRORS.future_date;
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const save = async () => {
    if (!sp || !validate()) return;
    setSaveError(null);
    setBusy(true);
    try {
      if (editId) {
        let editBookId = f.bookId;
        if (f.source === "book" && !editBookId && f.bookTitle.trim()) {
          editBookId = await api.ensureBook(sp.o_space_id, f.bookTitle.trim(), f.bookAuthor.trim() || null);
        }
        // 出典の種類に合わない詳細は空にして送る（chk_trials_source_detail）
        await api.updateTrial(editId, {
          status: f.score === "want" ? "want" : f.score === "trial" ? "trying" : "scored",
          score: typeof f.score === "number" ? f.score : null,
          age_months: f.age!.from,
          age_months_to: f.age!.to,
          source_type: f.source,
          book_id: f.source === "book" ? editBookId : null,
          source_url: f.source === "web" && f.url.trim() ? f.url.trim() : null,
          heard_from: f.source === "heard" && f.heard.trim() ? f.heard.trim() : null,
          source_text: (f.source === "tv" || f.source === "other") && f.sourceText.trim() ? f.sourceText.trim() : null,
          note: f.note.trim() || null,
          tried_on: f.triedOn,
          visibility: f.visibility,
        });
        showToast("直しました");
        // 開く前の B-4 に戻る（B-4 は表に出たときに読み直し、直したカードを光らせる）
        pendingGlow.id = editId;
        if (router.canGoBack()) router.back();
        else router.replace({ pathname: "/measures/[id]", params: { id: f.measureId!, hl: editId } });
        return;
      }
      // 同じ名前の見える①②があれば聞く（止めない）。①は同じ種類の中だけ（要件 4-1節「同じ名前が別の種類にあってよい」）
      if (!skipDup.current) {
        if (!f.problemId) {
          const hit = (await api.suggestProblems(sp.o_space_id, f.problemText)).find((x) => x.exact && (x.kind ?? "trouble") === f.kind);
          if (hit) { setDup({ kind: "problem", id: hit.id, name: hit.name }); return; }
        } else if (!f.measureId) {
          const hit = (await api.suggestMeasures(f.problemId, f.measureText)).find((x) => x.exact);
          if (hit) { setDup({ kind: "measure", id: hit.id, name: hit.name }); return; }
        }
      }
      skipDup.current = false;
      let bookId = f.bookId;
      if (f.source === "book" && !bookId && f.bookTitle.trim()) {
        bookId = await api.ensureBook(sp.o_space_id, f.bookTitle.trim(), f.bookAuthor.trim() || null);
      }
      const status: api.TrialStatus = f.score === "want" ? "want" : f.score === "trial" ? "trying" : "scored";
      const r = await api.saveTrial({
        spaceId: sp.o_space_id,
        problemId: f.problemId,
        problemName: f.problemId ? null : f.problemText.trim(),
        problemKind: f.problemId ? null : f.kind,
        tagIds: f.problemId ? null : f.tagIds,
        measureId: f.measureId,
        measureName: f.measureId ? null : f.measureText.trim(),
        score: typeof f.score === "number" ? f.score : null,
        status,
        ageMonths: f.age!.from,
        ageMonthsTo: f.age!.to,
        sourceType: f.source,
        bookId: f.source === "book" ? bookId : null,
        sourceUrl: f.source === "web" && f.url.trim() ? f.url.trim() : null,
        heardFrom: f.source === "heard" && f.heard.trim() ? f.heard.trim() : null,
        sourceText: (f.source === "tv" || f.source === "other") && f.sourceText.trim() ? f.sourceText.trim() : null,
        note: f.note.trim() || null,
        triedOn: f.triedOn,
        visibility: f.visibility,
      });
      const nextRecent = [f.age!, ...recent.filter((x) => !sameAge(x, f.age!))].slice(0, RECENT_AGES);
      await storage.setItem(KEYS.recentAges, JSON.stringify(nextRecent));
      await storage.removeItem(KEYS.draft);
      showToast("書きました");
      router.replace({ pathname: "/measures/[id]", params: { id: r.measure_id, hl: r.trial_id } });
    } catch (e) {
      const key = (e as { key?: string }).key ?? "unknown";
      if (key === "consent_required") {
        await storage.setItem(KEYS.draft, JSON.stringify({ spaceId: sp.o_space_id, form: f }));
        returnTo.current = "/write?resume=1";
        await refresh();
        return;
      }
      if (key === "not_visible") {
        set({ problemId: null, measureId: null, problemText: "", measureText: "" });
        setSaveError(`選んだ${W.problem}（${W.measure}）が見つかりません。選び直してください。`);
      } else if (key === "future_date") setSaveError(ERRORS.future_date);
      else if (key === "check_violation") {
        if (f.age?.to != null && f.age.to - f.age.from > 36) setSaveError("3年までの範囲にしてください");
        else setSaveError("字数や形を確かめてください（名前30字・40字、一言200字、詳細40字まで）。");
      } else if (key === "forbidden") setSaveError(ERRORS.forbidden);
      else if (key === "tag_kind_mismatch") {
        // 分類のボタンの下に文を出し、タグを読み直して合わない選択を外す（ワイヤーフレーム v0.6 #9）
        setTagMismatch(true);
        await refresh();
        set({ tagIds: f.tagIds.filter((id) => fitsKind(tags.find((t) => t.id === id), f.kind)) });
      }
      else setSaveError("保存できませんでした。通信を確かめて、もう一度［保存］を押してください。書いた内容はこの端末に残っています。");
    } finally {
      setBusy(false);
    }
  };

  const scoreRow = (v: Choice, label: React.ReactNode, guide: string) => (
    <Pressable
      key={String(v)}
      accessibilityRole="radio"
      accessibilityState={{ checked: f.score === v }}
      onPress={() => pickScore(v)}
      style={[{ flexDirection: "row", alignItems: "center", minHeight: 48, paddingVertical: space.xs }, f.score === v && { backgroundColor: colors.primarySoft }]}
      testID={`score-${v}`}
    >
      <Text style={[styles.body, { width: 28, textAlign: "center" }]}>{f.score === v ? "●" : "○"}</Text>
      {label}
      <Text style={[styles.sub, { flex: 1, marginLeft: space.s }]}>{guide}</Text>
    </Pressable>
  );

  return (
    <Screen
      scrollRef={scrollRef}
      overlay={<>
        <AgePicker
          visible={agePicker}
          onClose={() => setAgePicker(false)}
          title={ageWord}
          value={f.age}
          onPick={(v) => { edit({ age: v }); setAgePicker(false); }}
        />
        <Sheet visible={!!dup} onClose={() => setDup(null)} title="すでにあります">
          {dup ? (
            <View>
              <Text style={[styles.body, { marginBottom: space.m }]}>「{dup.name}」はすでにあります。そちらを使いますか。</Text>
              <View style={{ flexDirection: "row" }}>
                <Button kind="secondary" label="そちらを使う" style={{ flex: 1, marginRight: space.s }}
                  onPress={() => {
                    if (dup.kind === "problem") edit({ problemId: dup.id, problemText: dup.name, tagIds: [] });
                    else edit({ measureId: dup.id, measureText: dup.name });
                    setDup(null);
                  }} />
                <Button label="新しく作る" style={{ flex: 1 }} onPress={() => { skipDup.current = true; setDup(null); void save(); }} />
              </View>
            </View>
          ) : null}
        </Sheet>
      </>}
      header={<Header back="close" title={editId ? "直す" : "書く"} onBack={close} />}
      footer={
        <View>
          <Text style={[styles.sub, { marginBottom: space.xs }]}>{DISCLAIMER}</Text>
          {missing.length ? <Text style={[styles.sub, { marginBottom: space.xs }]}>あと{missing.length}つ: {missing.join("・")}</Text> : null}
          {saveError ? <Text style={[styles.error, { marginBottom: space.xs }]} testID="save-error">{saveError}</Text> : null}
          <Button label={busy ? "保存中…" : "保存"} busy={busy} disabled={editMissing} onPress={save} testID="write-save" />
        </View>
      }
    >
      {editMissing ? <Notice text="この記録は見つかりません（消されたか、見えなくなりました）" /> : null}
      {editId ? <Text style={[styles.sub, { marginBottom: space.s }]}>名前は{W.problem}・{W.measure}の画面の［⋯］から直せます。</Text> : null}
      {draft ? (
        <View style={{ marginBottom: space.m }}>
          <Notice text="書きかけがあります" />
          <View style={{ flexDirection: "row" }}>
            <Button kind="secondary" label="続きを書く" onPress={() => { setF(draft); touched.current = true; setDraft(null); }} style={{ marginRight: space.s }} />
            <Button kind="text" label="消す" onPress={() => { void storage.removeItem(KEYS.draft); setDraft(null); }} />
          </View>
        </View>
      ) : null}

      {/* 種類の切り替え（v0.4。既定は困りごと。①を選んだら、その①の種類で押せなくなる） */}
      <View style={{ flexDirection: "row", marginBottom: space.m, opacity: kindLocked ? 0.6 : 1 }}>
        {(["trouble", "grow"] as Kind[]).map((k) => (
          <Pressable
            key={k}
            disabled={kindLocked}
            accessibilityRole="radio"
            accessibilityState={{ checked: f.kind === k, disabled: kindLocked }}
            onPress={() => {
              if (k === f.kind) return;
              // 新しい種類に合わないタグの選択を外す（ことば・その他は両方なので外れない。ワイヤーフレーム v0.5 C-1）
              const keep = f.tagIds.filter((id) => fitsKind(tags.find((t) => t.id === id), k));
              const gone = f.tagIds.filter((id) => !keep.includes(id)).map((id) => tags.find((t) => t.id === id)?.name ?? "");
              setRemovedTags(gone);
              edit({ kind: k, tagIds: keep });
            }}
            style={[styles.segment, f.kind === k && styles.segmentOn]}
            testID={`kind-${k}`}
          >
            <Text style={[styles.body, f.kind === k && { color: colors.primary, fontWeight: "700" }]}>{KIND_WORDS[k].tab}{f.kind === k ? " ✓" : ""}</Text>
          </Pressable>
        ))}
      </View>

      {/* 1 困りごと／育てたいこと */}
      <Text style={styles.label}>1 {W.problem} ＊</Text>
      {f.problemId ? (
        <View style={[styles.input, { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingVertical: space.s }]}>
          <Text style={[styles.body, { flex: 1 }]} testID="problem-selected">{f.problemText} ✓登録済み</Text>
          {!params.problem && !editId ? <Button kind="text" label="変える" onPress={() => edit({ problemId: null, measureId: null, measureText: "" })} /> : null}
        </View>
      ) : (
        <Field value={f.problemText} onChangeText={(t) => edit({ problemText: t.slice(0, 30) })} maxLength={30} grow hint={HINTS.name} error={errors.problem} testID="write-problem" />
      )}
      {pSug && !f.problemId ? (
        <View style={[styles.card, { padding: space.s }]}>
          {pSug.map((s) => (
            <Pressable key={s.id} style={{ minHeight: 44, justifyContent: "center", paddingHorizontal: space.s }}
              onPress={() => { edit({ problemId: s.id, problemText: s.name, kind: s.kind ?? "trouble" }); setMFocus(true); }} testID="problem-suggest">
              <Text style={styles.body}>
                {s.name}{s.kind === "grow" ? "  " : ""}
                {s.kind === "grow" ? <Text style={styles.kindTag}>{KIND_WORDS.grow.tab}</Text> : null}
              </Text>
            </Pressable>
          ))}
          {!pSug.some((s) => s.exact && (s.kind ?? "trouble") === f.kind) ? (
            <Text style={[styles.sub, { padding: space.s }]}>＋「{f.problemText.trim()}」を新しい{W.problem}にする（このまま次へ）</Text>
          ) : null}
        </View>
      ) : null}
      {newProblem ? (
        <View style={{ marginBottom: space.m }}>
          <Text style={styles.sub}>分類（なくてよい。選ばなければ「その他」）</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: space.xs }}>
            {tagsForKind(tags, f.kind).map((t) => (
              <Chip key={t.id} label={t.name} selected={f.tagIds.includes(t.id)} testID={`write-tag-${t.name}`}
                onPress={() => { setRemovedTags([]); setTagMismatch(false); edit({ tagIds: f.tagIds.includes(t.id) ? f.tagIds.filter((x) => x !== t.id) : [...f.tagIds, t.id] }); }} />
            ))}
          </View>
          {removedTags.length ? (
            <Text style={[styles.sub, { color: colors.text }]} testID="removed-tags">種類を変えたので、合わないタグ（{removedTags.join("・")}）を外しました。</Text>
          ) : null}
          {tagMismatch ? <Text style={styles.error} testID="tag-mismatch">{ERRORS.tag_kind_mismatch}</Text> : null}
        </View>
      ) : null}

      {/* 2 対策／やり方（A16 推奨: 短い名前で。長い説明は一言へ） */}
      <Text style={[styles.label, { marginTop: space.m }]}>2 {W.measure} ＊</Text>
      {f.measureId ? (
        <View style={[styles.input, { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingVertical: space.s }]}>
          <Text style={[styles.body, { flex: 1 }]} testID="measure-selected">{f.measureText} ✓登録済み</Text>
          {!lockedMeasure ? <Button kind="text" label="変える" onPress={() => edit({ measureId: null })} /> : null}
        </View>
      ) : (
        <View>
          <Field
            value={f.measureText}
            onChangeText={(t) => {
              // 40字に達した後に打った字は入らない。そのとき案内を出す（次に40字を下回るまで出したまま）
              if ([...t].length > MEASURE_MAX || ([...f.measureText].length >= MEASURE_MAX && [...t].length >= MEASURE_MAX && t !== f.measureText)) setMLimit(true);
              const v = [...t].slice(0, MEASURE_MAX).join("");
              if ([...v].length < MEASURE_MAX) setMLimit(false);
              edit({ measureText: v });
            }}
            onKeyPress={(e) => { if ([...f.measureText].length >= MEASURE_MAX && e.nativeEvent.key.length === 1) setMLimit(true); }}
            onFocus={() => setMFocus(true)}
            maxLength={MEASURE_MAX + 20}
            grow
            hint={`${MEASURE_GUIDE}\n${HINTS.name}`}
            error={errors.measure}
            testID="write-measure"
          />
          {mLimit ? (
            <Text style={[styles.body, { marginTop: -space.s, marginBottom: space.m }]} testID="measure-limit">
              {MEASURE_LIMIT_NOTICE}{"  "}
              <Text style={styles.link} accessibilityRole="link" onPress={() => { scrollRef.current?.scrollTo({ y: noteY.current, animated: true }); noteRef.current?.focus(); }}>一言へ</Text>
            </Text>
          ) : null}
        </View>
      )}
      {mSug && mSug.length > 0 && !f.measureId ? (
        <View style={[styles.card, { padding: space.s }]}>
          {mSug.map((s) => (
            <Pressable key={s.id} style={{ minHeight: 44, justifyContent: "center", paddingHorizontal: space.s }} onPress={() => edit({ measureId: s.id, measureText: s.name })} testID="measure-suggest">
              <Text style={styles.body}>{s.name}</Text>
            </Pressable>
          ))}
        </View>
      ) : null}

      {/* 3 効き目（7つ。試したいは試し中の下） */}
      {/* ①が育てたいのときは見出し「伸び」と育てたいの組の言葉・基準の1行（C115） */}
      <Text style={[styles.label, { marginTop: space.m }]} testID="score-heading">3 {scoreHeading(f.kind)} ＊</Text>
      {scoresFor(f.kind).map((s) => scoreRow(s.v, <ScoreBadge score={s.v} status="scored" kind={f.kind} />, s.guide))}
      {scoreRow("trial", <ScoreBadge score={null} status="trying" />, TRIAL_GUIDE)}
      {scoreRow("want", <ScoreBadge score={null} status="want" />, WANT_GUIDE)}
      <Text style={[styles.sub, { marginTop: space.xs }]}>{HINTS.scoreEncourage}</Text>
      {errors.score ? <Text style={styles.error}>{errors.score}</Text> : null}

      {/* 4 何歳のとき／何歳で試したい（最近の年齢は範囲も） */}
      <Text style={[styles.label, { marginTop: space.l }]}>4 {ageWord} ＊</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
        {recent.map((a) => (
          <Chip key={`${a.from}-${a.to}`} label={ageRangeLabel(a.from, a.to)} selected={!!f.age && sameAge(f.age, a)} onPress={() => edit({ age: a })} />
        ))}
        {f.age && !recent.some((a) => sameAge(a, f.age!)) ? <Chip label={ageRangeLabel(f.age.from, f.age.to)} selected testID="age-chosen" /> : null}
        <Chip label={recent.length ? "ほかの年齢…" : "年齢を選ぶ"} onPress={() => setAgePicker(true)} testID="age-open" />
      </View>
      {errors.age ? <Text style={styles.error}>{errors.age}</Text> : null}

      {/* 5 どこで知った（6つ。幅が狭ければ折り返す） */}
      <Text style={[styles.label, { marginTop: space.l }]}>5 どこで知った ＊</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
        {SOURCE_TYPES.map((s) => (
          <Chip key={s.v} label={f.source === s.v ? `${s.label}✓` : s.label} selected={f.source === s.v} onPress={() => edit({ source: s.v })} testID={`source-${s.v}`} />
        ))}
      </View>
      {f.source === "book" ? (
        <View>
          {f.bookId ? (
            <View style={[styles.input, { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: space.m, paddingVertical: space.s }]}>
              <Text style={[styles.body, { flex: 1 }]}>『{f.bookTitle}』{f.bookAuthor}</Text>
              <Button kind="text" label="変える" onPress={() => edit({ bookId: null })} />
            </View>
          ) : (
            <Field label="題名" value={f.bookTitle} onChangeText={(t) => edit({ bookTitle: t.slice(0, 100) })} maxLength={100} grow />
          )}
          {bSug && bSug.length > 0 && !f.bookId ? (
            <View style={[styles.card, { padding: space.s }]}>
              {bSug.map((b) => (
                <Pressable key={b.id} style={{ minHeight: 44, justifyContent: "center", paddingHorizontal: space.s }} onPress={() => edit({ bookId: b.id, bookTitle: b.title, bookAuthor: b.author ?? "" })}>
                  <Text style={styles.body}>『{b.title}』{b.author ?? ""}</Text>
                </Pressable>
              ))}
            </View>
          ) : null}
          {!f.bookId ? <Field label="著者（分かれば）" value={f.bookAuthor} onChangeText={(t) => edit({ bookAuthor: t.slice(0, 60) })} maxLength={60} /> : null}
        </View>
      ) : null}
      {f.source === "web" ? (
        <Field label="URL" value={f.url} onChangeText={(t) => edit({ url: t.slice(0, 500) })} autoCapitalize="none" keyboardType="url" placeholder="https://" error={errors.url} />
      ) : null}
      {f.source === "tv" || f.source === "other" ? (
        <Field
          label={SOURCE_TEXT_FIELD[f.source].label}
          value={f.sourceText}
          onChangeText={(t) => edit({ sourceText: [...t].slice(0, SOURCE_TEXT_MAX).join("") })}
          maxLength={SOURCE_TEXT_MAX}
          grow
          hint={SOURCE_TEXT_FIELD[f.source].hint}
          counter={`${[...f.sourceText].length}/${SOURCE_TEXT_MAX}`}
          testID="write-source-text"
        />
      ) : null}
      {f.source === "heard" ? (
        <View>
          <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
            {HEARD_FROM.map((h) => <Chip key={h} label={h} selected={f.heard === h} onPress={() => edit({ heard: f.heard === h ? "" : h })} />)}
          </View>
          <Field value={HEARD_FROM.includes(f.heard) ? "" : f.heard} onChangeText={(t) => edit({ heard: t.slice(0, 20) })} maxLength={20} placeholder="または 自由に（20字）" hint={HINTS.heard} />
        </View>
      ) : null}

      {/* 6 一言 */}
      <View onLayout={(e) => { noteY.current = e.nativeEvent.layout.y; }}>
        <Field
          ref={noteRef}
          label="6 一言（なくてよい）"
          value={f.note}
          onChangeText={(t) => edit({ note: t.slice(0, 200) })}
          maxLength={200}
          multiline
          hint={HINTS.note}
          counter={`${f.note.length}/200`}
          style={{ marginTop: space.s }}
          testID="write-note"
        />
      </View>

      {/* 試した日（試したいのときは書いた日）・見える人。項目名と値の札（開発部の第1段・ワイヤーフレーム v0.4 3-1節） */}
      <Pressable
        accessibilityRole="button"
        onPress={() => setMoreOpen(!moreOpen)}
        style={{ flexDirection: "row", alignItems: "center", flexWrap: "wrap", minHeight: 48, marginTop: space.s }}
        testID="more-open"
      >
        <Text style={[styles.sub, { marginRight: space.xs }]} testID="date-word">{isWant ? "書いた日" : "試した日"}</Text>
        <Text style={styles.valueTag} testID="summary-date">{becomesToday ? WANT_EDIT.tag(`${Number(today.slice(5, 7))}/${Number(today.slice(8))}`) : dateLabel(f.triedOn)}</Text>
        <Text style={[styles.sub, { marginLeft: space.m, marginRight: space.xs }]}>見える人</Text>
        <Text style={styles.valueTag} testID="summary-vis">{f.visibility === "all" ? "みんな" : "自分の家庭だけ"}</Text>
        <Text style={[styles.body, { color: colors.primary, marginLeft: "auto", paddingLeft: space.s }]}>{moreOpen ? "閉じる" : "変える"}</Text>
      </Pressable>
      {wantDateNotice ? <Text style={[styles.sub, { color: colors.text }]} testID="want-date-notice">{wantDateNotice}</Text> : null}
      {moreOpen || errors.date ? (
        <View style={{ marginTop: space.s }}>
          <Text style={styles.label}>{isWant ? "書いた日" : "試した日"}</Text>
          <DatePicker value={f.triedOn} onChange={(d) => edit({ triedOn: d })} title={isWant ? "書いた日" : "試した日"} />
          {errors.date ? <Text style={styles.error}>{errors.date}</Text> : null}
          <Text style={[styles.label, { marginTop: space.m }]}>見える人</Text>
          <View style={{ flexDirection: "row" }}>
            <Chip label="みんな" selected={f.visibility === "all"} onPress={() => edit({ visibility: "all", visTouched: true })} />
            <Chip label="自分の家庭だけ" selected={f.visibility === "household"} onPress={() => edit({ visibility: "household", visTouched: true })} testID="vis-household" />
          </View>
          <Text style={styles.sub}>{HINTS.visibility}</Text>
        </View>
      ) : null}
    </Screen>
  );
}
