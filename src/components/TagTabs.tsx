/**
 * B-1 のタグのタブ（v0.9・C114・ワイヤーフレーム v0.6 B-1）。
 * 横に動かす1行をやめ、折り返して2行まで。入りきらないときは2行目の最後に［＋N］（N＝隠れている数）。
 * ［＋N］で全部を折り返して出し、最後に［閉じる］で2行に戻す。
 * 閉じているとき、選んでいるタグが2行に入らない位置なら、［すべて］のすぐ次に出す（全部を開いたときは元の位置）。
 * 幅は実際の見た目で測る（見えない所に一度並べて、1つずつの幅を知る）。Web・アプリで同じ作り。
 */
import React, { useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { Chip, styles } from "@/components/ui";
import { colors, space } from "@/theme";

type Item = { id: string | null; label: string };

export function TagTabs(props: { items: Item[]; selected: string | null; onSelect: (id: string | null) => void }) {
  const [width, setWidth] = useState(0);
  const [widths, setWidths] = useState<Record<string, number>>({});
  const [plusW, setPlusW] = useState(0);
  const [expanded, setExpanded] = useState(false);
  const key = (it: Item) => it.id ?? "__all";

  const layout = useMemo(() => {
    const all = props.items;
    const measured = width > 0 && plusW > 0 && all.every((it) => widths[key(it)] > 0);
    if (!measured) return { shown: all, hidden: 0, overflow: false };
    const pack = (order: Item[]) => {
      let line = 1;
      let x = 0;
      const placed: { it: Item; line: number; end: number }[] = [];
      for (const it of order) {
        const w = widths[key(it)];
        if (x + w > width) {
          line += 1;
          x = 0;
          if (line > 2) break;
        }
        x += w;
        placed.push({ it, line, end: x });
      }
      if (placed.length === order.length) return { shown: order, hidden: 0 };
      // 2行目の最後に［＋N］が入るまで、後ろから抜く
      while (placed.length > 0) {
        const last = placed[placed.length - 1];
        if (last.line < 2 || last.end + plusW <= width) break;
        placed.pop();
      }
      return { shown: placed.map((p) => p.it), hidden: order.length - placed.length };
    };
    let r = pack(all);
    if (r.hidden > 0 && props.selected != null && !r.shown.some((it) => it.id === props.selected)) {
      // 選んでいるタグが隠れる → ［すべて］の次に出す
      const sel = all.find((it) => it.id === props.selected);
      if (sel) r = pack([all[0], sel, ...all.slice(1).filter((it) => it.id !== props.selected)]);
    }
    return { ...r, overflow: r.hidden > 0 };
  }, [props.items, props.selected, width, widths, plusW]);

  const chip = (it: Item) => (
    <Chip key={key(it)} label={it.label} selected={props.selected === it.id} onPress={() => props.onSelect(it.id)} testID={`home-tag-${it.label}`} />
  );
  const small = (label: string, onPress: () => void, id: string) => (
    <Pressable accessibilityRole="button" onPress={onPress} style={[styles.chip, { borderColor: colors.border }]} testID={id}>
      <Text style={[styles.chipText, { color: colors.textSub }]}>{label}</Text>
    </Pressable>
  );

  return (
    <View onLayout={(e) => setWidth(Math.floor(e.nativeEvent.layout.width))} style={{ marginTop: space.s }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap" }} testID="home-tags">
        {expanded || !layout.overflow ? props.items.map(chip) : layout.shown.map(chip)}
        {layout.overflow && !expanded ? small(`＋${layout.hidden}`, () => setExpanded(true), "home-tags-more") : null}
        {layout.overflow && expanded ? small("閉じる", () => setExpanded(false), "home-tags-close") : null}
      </View>
      {/* 見えない所で1つずつの幅を測る（見える並びの後ろに置く）。
          （2026-10-01 直し）測るための1行は画面の幅より長い（2,000px を超える）。そのままだとページ全体が横に広がり、
          スマホのブラウザがページ全体を縮めて「左上に小さく」出していた（統括の気づき）。高さ0・はみ出しを切る入れ物に入れる */}
      <View pointerEvents="none" style={{ position: "absolute", left: 0, top: 0, width: "100%", height: 0, overflow: "hidden" }} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <View style={{ position: "absolute", opacity: 0, flexDirection: "row", left: 0, top: 0 }}>
        {props.items.map((it) => (
          <View key={key(it)} onLayout={(e) => { const w = Math.ceil(e.nativeEvent.layout.width); setWidths((m) => (m[key(it)] === w ? m : { ...m, [key(it)]: w })); }}>
            <Chip label={it.label} selected={props.selected === it.id} />
          </View>
        ))}
        <View onLayout={(e) => setPlusW(Math.ceil(e.nativeEvent.layout.width))}>{small("＋99", () => {}, "measure-plus")}</View>
      </View>
      </View>
    </View>
  );
}
