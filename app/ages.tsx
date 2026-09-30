/**
 * B-2 年齢の一覧（ワイヤーフレーム v0.5 B-2・要件 v0.8 6-2節・C106）。
 * 1歳ごとの行だけ（v0.4 のまとまりはやめた。設計書 v0.5 Y7 で list_age_band_counts も消えた）。
 * 範囲の③は、入る歳それぞれに数える（list_age_counts のまま）。種類で分けない・試したいも数える。
 */
import React, { useCallback, useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { BottomTabs, Button, ErrorBox, Loading, Screen, styles } from "@/components/ui";
import { listAgeCounts } from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { colors, font, space } from "@/theme";

export default function Ages() {
  const router = useRouter();
  const { space: sp } = useApp();
  const [rows, setRows] = useState<{ o_age_years: number; o_problem_count: number }[] | null>(null);
  const [error, setError] = useState(false);

  const load = useCallback(async () => {
    if (!sp) return;
    setError(false);
    try {
      setRows(await listAgeCounts(sp.o_space_id));
    } catch {
      setError(true);
    }
  }, [sp]);
  useEffect(() => void load(), [load]);

  return (
    <Screen footer={<BottomTabs current="ages" />} onFab={() => router.push("/write")}>
      <Text style={[font.title, { color: colors.text }]}>年齢の一覧</Text>
      <Text style={[styles.sub, { marginTop: space.xs, marginBottom: space.m }]}>その歳で試した記録がある、困りごと・育てたいことの数です。</Text>
      {error ? <ErrorBox onRetry={load} /> : rows == null ? <Loading /> : rows.length === 0 ? (
        <View>
          <Text style={[styles.body, { marginBottom: space.m }]}>まだ記録がありません。書くと、試したときの年齢ごとにここに並びます。</Text>
          <Button label="書く" onPress={() => router.push("/write")} />
        </View>
      ) : (
        rows.map((r) => (
          <Pressable
            key={r.o_age_years}
            accessibilityRole="button"
            style={[styles.row, { flexDirection: "row", justifyContent: "space-between", minHeight: 48, alignItems: "center" }]}
            onPress={() => router.replace({ pathname: "/", params: { age: String(r.o_age_years) } })}
            testID={`year-${r.o_age_years}`}
          >
            <Text style={styles.body}>{r.o_age_years}歳</Text>
            <Text style={styles.body}>{r.o_problem_count}件  ›</Text>
          </Pressable>
        ))
      )}
    </Screen>
  );
}
