/**
 * C-2 年齢を選ぶ（下から出る枠。ワイヤーフレーム v0.4 C-2・要件 v0.7 5-4節）。
 * ［1つの年齢］は押すと閉じる（1タップ）。［範囲にする］は「から」→「まで」→［◯〜◯歳 にする］。
 * 「まで」は「から」以下と「から」＋3年を超える年齢を押せない（表の制約 chk_trials_age_range と同じ）。
 */
import React, { useEffect, useState } from "react";
import { Text, View } from "react-native";
import { AGE_RANGE_MAX_MONTHS } from "@/constants/texts";
import { Button, Chip, Sheet, styles } from "@/components/ui";
import { AGE_CHOICES, ageLabel, ageRangeLabel, type AgeValue } from "@/lib/format";
import { space } from "@/theme";

export function AgePicker(props: {
  visible: boolean;
  onClose: () => void;
  title: string;
  value: AgeValue | null;
  onPick: (v: AgeValue) => void;
}) {
  const [range, setRange] = useState(false);
  const [from, setFrom] = useState<number | null>(null);
  const [to, setTo] = useState<number | null>(null);
  const [editing, setEditing] = useState<"from" | "to">("from");

  useEffect(() => {
    if (!props.visible) return;
    const isRange = props.value?.to != null;
    setRange(isRange);
    setFrom(isRange ? props.value!.from : null);
    setTo(isRange ? props.value!.to : null);
    setEditing("from");
  }, [props.visible, props.value]);

  const disabledTo = (m: number) => from == null || m <= from || m - from > AGE_RANGE_MAX_MONTHS;

  return (
    <Sheet visible={props.visible} onClose={props.onClose} title={props.title}>
      <View style={{ flexDirection: "row", marginBottom: space.s }}>
        <Chip label={range ? "1つの年齢" : "1つの年齢 ✓"} selected={!range} onPress={() => { setRange(false); setFrom(null); setTo(null); }} testID="age-mode-single" />
        <Chip label={range ? "範囲にする ✓" : "範囲にする"} selected={range} onPress={() => { setRange(true); setEditing("from"); }} testID="age-mode-range" />
      </View>
      {range ? (
        <View style={{ flexDirection: "row", alignItems: "center", marginBottom: space.s }}>
          <Text style={styles.sub}>から </Text>
          <Chip label={from == null ? "▼" : `${ageLabel(from)} ▼`} selected={editing === "from"} onPress={() => setEditing("from")} testID="age-edit-from" />
          <Text style={styles.sub}>まで </Text>
          <Chip label={to == null ? "▼" : `${ageLabel(to)} ▼`} selected={editing === "to"} onPress={() => from != null && setEditing("to")} testID="age-edit-to" />
        </View>
      ) : null}
      {range ? <Text style={[styles.sub, { marginBottom: space.xs }]}>（{editing === "from" ? "「から」を選ぶ" : "「まで」を選ぶ"}）</Text> : null}
      <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
        {AGE_CHOICES.map((m) => {
          const dis = range && editing === "to" && disabledTo(m);
          const sel = range ? (editing === "from" ? from === m : to === m) : props.value?.to == null && props.value?.from === m;
          return (
            <View key={m} style={{ width: "25%", opacity: dis ? 0.35 : 1 }}>
              <Chip
                label={ageLabel(m)}
                selected={sel}
                testID={range ? `age-${editing}-${m}` : `age-${m}`}
                onPress={() => {
                  if (dis) return;
                  if (!range) return props.onPick({ from: m, to: null });
                  if (editing === "from") {
                    setFrom(m);
                    if (to != null && (to <= m || to - m > AGE_RANGE_MAX_MONTHS)) setTo(null);
                    setEditing("to"); // 「から」を選ぶと自動で「まで」へ
                  } else setTo(m);
                }}
              />
            </View>
          );
        })}
      </View>
      {range ? (
        <View style={{ marginTop: space.s }}>
          <Text style={styles.sub}>3年までの範囲で選べます。</Text>
          <Button
            label={from != null && to != null ? `${ageRangeLabel(from, to)} にする` : "から・まで を選んでください"}
            disabled={from == null || to == null}
            onPress={() => from != null && to != null && props.onPick({ from, to })}
            style={{ marginTop: space.s }}
            testID="age-range-ok"
          />
        </View>
      ) : null}
    </Sheet>
  );
}
