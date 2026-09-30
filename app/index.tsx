/**
 * B-1 困りごとの一覧（ホーム）。ワイヤーフレーム v0.4 B-1・要件 v0.7 6-1節・設計書 v0.4 5-1・5-3節（search_problems）。
 * v0.7: 一番上に［すべて］［困りごと］［育てたい］（既定はすべて・端末に覚えない）、育てたいの札、年齢のまとまりの絞り込み。
 * 道: /?age=3（1歳。v0.5 でまとまり〈ageTo〉はやめた＝ワイヤーフレーム v0.5 #10）
 */
import React, { useCallback, useEffect, useRef, useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import { KIND_WORDS, type Kind } from "@/constants/texts";
import { DEBOUNCE_MS, PAGE_SIZE } from "@/constants/config";
import { BottomTabs, Button, ErrorBox, Loading, Screen, styles } from "@/components/ui";
import { TagTabs } from "@/components/TagTabs";
import { searchProblems, type ProblemRow } from "@/lib/api";
import { tagsForKind } from "@/lib/tags";
import { useApp } from "@/lib/app-state";
import { colors, font, radius, space } from "@/theme";

export default function Home() {
  const router = useRouter();
  const { age } = useLocalSearchParams<{ age?: string }>();
  const ageYears = age != null && age !== "" ? Number(age) : null;
  const { space: sp, tags, listFilter, setListFilter, listKind, setListKind } = useApp();
  const [query, setQuery] = useState(listFilter.query);
  const [tagId, setTagId] = useState<string | null>(listFilter.tagId);
  // 種類（null＝すべて）。アプリを開いている間だけ持つ（E-7 の種類の既定にも使う）
  const kind = listKind;
  const shownTags = tagsForKind(tags, kind);
  const setKind = (k: Kind | null) => {
    setListKind(k);
    // 切り替えた種類に、選んでいたタグが無ければ［すべて］へ（ワイヤーフレーム v0.5 B-1）
    if (tagId && !tagsForKind(tags, k).some((t) => t.id === tagId)) setTagId(null);
  };
  const [rows, setRows] = useState<ProblemRow[] | null>(null);
  const [error, setError] = useState(false);
  const [more, setMore] = useState(false);
  const loadingMore = useRef(false);
  const reqId = useRef(0);

  const load = useCallback(
    async (q: string, t: string | null) => {
      if (!sp) return;
      const id = ++reqId.current;
      setError(false);
      try {
        const r = await searchProblems({ spaceId: sp.o_space_id, query: q, tagId: t, ageYears, kind, limit: PAGE_SIZE, offset: 0 });
        if (id !== reqId.current) return; // 古い問い合わせの答えは捨てる
        setRows(r);
        setMore(r.length === PAGE_SIZE);
      } catch {
        if (id === reqId.current) setError(true);
      }
    },
    [sp, ageYears, kind],
  );

  useEffect(() => {
    const h = setTimeout(() => {
      setListFilter({ query, tagId });
      void load(query, tagId);
    }, query === listFilter.query ? 0 : DEBOUNCE_MS);
    return () => clearTimeout(h);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query, tagId, load]);

  // ほかの画面から戻ったとき（書いた・消した後）に読み直す。最初の1回は上の effect が読む
  const firstFocus = useRef(true);
  useFocusEffect(useCallback(() => {
    if (firstFocus.current) { firstFocus.current = false; return; }
    void load(query, tagId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [load]));

  const loadMore = async () => {
    if (!sp || !rows || !more || loadingMore.current) return;
    loadingMore.current = true;
    try {
      const r = await searchProblems({ spaceId: sp.o_space_id, query, tagId, ageYears, kind, limit: PAGE_SIZE, offset: rows.length });
      setRows([...rows, ...r]);
      setMore(r.length === PAGE_SIZE);
    } finally {
      loadingMore.current = false;
    }
  };

  const tagName = (id: string) => tags.find((t) => t.id === id)?.name ?? "";
  const filtered = Boolean(query.trim() || tagId || ageYears != null);
  const ageText = ageYears == null ? "" : `${ageYears}歳`;
  const writeKind: Record<string, string> = kind === "grow" ? { kind: "grow" } : {};
  const W = KIND_WORDS[kind ?? "trouble"];

  const kindTabs: { k: Kind | null; label: string }[] = [
    { k: null, label: "すべて" }, { k: "trouble", label: KIND_WORDS.trouble.tab }, { k: "grow", label: KIND_WORDS.grow.tab },
  ];

  return (
    <Screen
      onEndReached={loadMore}
      onFab={() => router.push({ pathname: "/write", params: writeKind })}
      header={
        <View style={{ paddingHorizontal: space.l, paddingTop: space.m, borderBottomWidth: 1, borderBottomColor: colors.border }}>
          <Text style={[font.rowTitle, { color: colors.text, marginBottom: space.s }]} testID="home-title">ノート</Text>
          {/* 種類の切り替え（v0.4）。タグ・検索・年齢と同時に効く */}
          <View style={{ flexDirection: "row", marginBottom: space.s }}>
            {kindTabs.map((t) => (
              <Pressable key={t.label} accessibilityRole="tab" accessibilityState={{ selected: kind === t.k }}
                onPress={() => setKind(t.k)} style={[styles.segment, kind === t.k && styles.segmentOn]} testID={`home-kind-${t.k ?? "all"}`}>
                <Text style={[styles.body, kind === t.k && { color: colors.primary, fontWeight: "700" }]}>{t.label}{kind === t.k ? " ✓" : ""}</Text>
              </Pressable>
            ))}
          </View>
          <View style={{ flexDirection: "row", alignItems: "center" }}>
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder={kind === "grow" ? "育てたいこと・やり方の名前で探す" : "困りごと・対策の名前で探す"}
              placeholderTextColor="#999"
              style={[styles.input, { flex: 1 }]}
              testID="home-search"
            />
            {query ? <Button kind="text" label="×" onPress={() => setQuery("")} /> : null}
          </View>
          {/* タグは折り返して2行まで・［＋N］で全部・［閉じる］（v0.9・C114） */}
          <TagTabs items={[{ id: null, label: "すべて" }, ...shownTags.map((t) => ({ id: t.id, label: t.name }))]} selected={tagId} onSelect={setTagId} />
          {ageYears != null ? (
            <View style={{ flexDirection: "row", alignItems: "center", alignSelf: "flex-start", backgroundColor: colors.primarySoft, borderRadius: radius.input, paddingLeft: space.m, marginBottom: space.s }}>
              <Text style={styles.body} testID="home-age-filter">{ageText}で絞り込み中</Text>
              <Button kind="text" label="×" onPress={() => router.replace("/")} />
            </View>
          ) : null}
        </View>
      }
      footer={<BottomTabs current="home" />}
    >
      {error ? <ErrorBox onRetry={() => void load(query, tagId)} /> : rows == null ? <Loading /> : rows.length === 0 ? (
        filtered ? (
          <View style={{ padding: space.l }}>
            <Text style={[styles.body, { marginBottom: space.m }]}>見つかりません。言葉やタブを変えてください。</Text>
            <Button
              kind="secondary"
              label={query.trim() ? `この${W.problem}を書く` : "書く"}
              onPress={() => router.push({ pathname: "/write", params: query.trim() ? { q: query.trim(), ...writeKind } : writeKind })}
            />
          </View>
        ) : (
          <View style={{ padding: space.l }}>
            <Text style={[styles.body, { marginBottom: space.m }]} testID="home-empty">
              {kind === "grow" ? "育てたいことはまだありません。" : kind === "trouble" ? "困りごとはまだありません。" : "まだ何もありません。困っていることや育てたいことと、試したことを1つ書いてみましょう。"}
            </Text>
            <Button label={kind ? "書く" : "最初の1件を書く"} onPress={() => router.push({ pathname: "/write", params: writeKind })} />
          </View>
        )
      ) : (
        <View>
          {rows.map((r) => (
            <Pressable
              key={r.o_problem_id}
              accessibilityRole="button"
              style={styles.row}
              onPress={() => router.push({
                pathname: "/problems/[id]",
                params: { id: r.o_problem_id, ...(ageYears != null ? { age: String(ageYears) } : {}) },
              })}
              testID="problem-row"
            >
              <Text style={[font.rowTitle, { color: colors.text }]}>
                {r.o_name}
                {r.o_kind === "grow" ? <Text>{"  "}<Text style={styles.kindTag}>{KIND_WORDS.grow.tab}</Text></Text> : null}
              </Text>
              <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: space.xs }}>
                {r.o_tag_ids.slice(0, 3).map((t) => (
                  <Text key={t} style={[styles.sub, { marginRight: space.s }]}>[{tagName(t)}]</Text>
                ))}
                {r.o_tag_ids.length > 3 ? <Text style={styles.sub}>+{r.o_tag_ids.length - 3}</Text> : null}
              </View>
              <Text style={[styles.sub, { marginTop: space.xs }]}>{KIND_WORDS[r.o_kind ?? "trouble"].measure} {r.o_measure_count} ・ 記録 {r.o_trial_count}</Text>
            </Pressable>
          ))}
          {more ? <Text style={[styles.sub, { textAlign: "center", padding: space.m }]}>読み込んでいます…</Text> : null}
          <View style={{ height: 72 }} />
        </View>
      )}
    </Screen>
  );
}
