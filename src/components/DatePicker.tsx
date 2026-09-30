/**
 * 試した日を選ぶ（2026-09-30 開発部。統括が触った後の直し 第1段）。
 * 文字で打つ欄をやめ、［今日］［昨日］［おととい］の1タップと、［ほかの日…］で開く月のカレンダーにした。
 * 今日（日本時間）より先の日は押せない（要件 4-3節・K-6）。ブラウザの日付の部品に頼らず自前で作るので、
 * Web でもアプリでも同じに動く（要件 9-5節）。
 */
import React, { useState } from "react";
import { Pressable, Text, View } from "react-native";
import { Chip, Sheet, styles } from "@/components/ui";
import { todayJst } from "@/lib/format";
import { colors, font, space } from "@/theme";

function addDays(ymd: string, n: number): string {
  const t = Date.parse(`${ymd}T00:00:00Z`) + n * 86400000;
  return new Date(t).toISOString().slice(0, 10);
}

export function dateLabel(ymd: string): string {
  const today = todayJst();
  if (ymd === today) return "今日";
  if (ymd === addDays(today, -1)) return "昨日";
  if (ymd === addDays(today, -2)) return "おととい";
  const [y, m, d] = ymd.split("-").map(Number);
  return y === Number(today.slice(0, 4)) ? `${m}月${d}日` : `${y}年${m}月${d}日`;
}

const WEEK = ["日", "月", "火", "水", "木", "金", "土"];

export function DatePicker(props: { value: string; onChange: (ymd: string) => void; title?: string }) {
  const today = todayJst();
  const [open, setOpen] = useState(false);
  const [ym, setYm] = useState(props.value.slice(0, 7)); // 表示している月 YYYY-MM
  const quick = [today, addDays(today, -1), addDays(today, -2)];

  const [y, m] = ym.split("-").map(Number);
  const first = new Date(Date.UTC(y, m - 1, 1));
  const daysInMonth = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const cells: (string | null)[] = [
    ...Array.from({ length: first.getUTCDay() }, () => null),
    ...Array.from({ length: daysInMonth }, (_, i) => `${ym}-${String(i + 1).padStart(2, "0")}`),
  ];
  const shiftMonth = (n: number) => {
    const d = new Date(Date.UTC(y, m - 1 + n, 1));
    setYm(d.toISOString().slice(0, 7));
  };
  const canNext = ym < today.slice(0, 7);

  return (
    <View>
      <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
        {quick.map((d) => (
          <Chip key={d} label={dateLabel(d)} selected={props.value === d} onPress={() => props.onChange(d)} testID={`date-${dateLabel(d)}`} />
        ))}
        <Chip
          label={quick.includes(props.value) ? "ほかの日…" : `${dateLabel(props.value)}（変える）`}
          selected={!quick.includes(props.value)}
          onPress={() => { setYm(props.value.slice(0, 7)); setOpen(true); }}
          testID="date-other"
        />
      </View>
      <Sheet visible={open} onClose={() => setOpen(false)} title={props.title ?? "試した日"}>
        <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: space.s }}>
          <Pressable onPress={() => shiftMonth(-1)} style={{ minWidth: 44, minHeight: 44, justifyContent: "center" }} testID="cal-prev">
            <Text style={[styles.body, { color: colors.primary }]}>‹ 前の月</Text>
          </Pressable>
          <Text style={[font.rowTitle, { color: colors.text }]}>{y}年{m}月</Text>
          <Pressable disabled={!canNext} onPress={() => shiftMonth(1)} testID="cal-next" style={{ minWidth: 44, minHeight: 44, justifyContent: "center", alignItems: "flex-end", opacity: canNext ? 1 : 0.3 }}>
            <Text style={[styles.body, { color: colors.primary }]}>次の月 ›</Text>
          </Pressable>
        </View>
        <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
          {WEEK.map((w) => (
            <View key={w} style={{ width: `${100 / 7}%`, alignItems: "center", paddingVertical: space.xs }}>
              <Text style={styles.sub}>{w}</Text>
            </View>
          ))}
          {cells.map((d, i) => {
            if (!d) return <View key={`e${i}`} style={{ width: `${100 / 7}%`, height: 44 }} />;
            const future = d > today;
            const sel = d === props.value;
            return (
              <Pressable
                key={d}
                disabled={future}
                accessibilityRole="button"
                accessibilityState={{ disabled: future, selected: sel }}
                onPress={() => { props.onChange(d); setOpen(false); }}
                style={{ width: `${100 / 7}%`, height: 44, alignItems: "center", justifyContent: "center" }}
                testID={`cal-${d}`}
              >
                <View style={[{ width: 38, height: 38, borderRadius: 19, alignItems: "center", justifyContent: "center" }, sel && { backgroundColor: colors.primary }, d === today && !sel && { borderWidth: 1, borderColor: colors.primary }]}>
                  <Text style={[styles.body, { color: future ? "#C8C8C8" : sel ? "#fff" : colors.text }]}>{Number(d.slice(8))}</Text>
                </View>
              </Pressable>
            );
          })}
        </View>
        <Text style={[styles.sub, { marginTop: space.s }]}>今日より先の日は選べません。</Text>
      </Sheet>
    </View>
  );
}
