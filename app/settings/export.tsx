/** E-3 書き出し（ワイヤーフレーム v0.4 E-3・要件 F-30・設計書 7-3節）。範囲は管理者もメンバーも「自分に見える分」。 */
import React, { useState } from "react";
import { Text, View } from "react-native";
import { Button, Header, Screen, styles } from "@/components/ui";
import { exportVisibleData } from "@/lib/api";
import { buildExport } from "@/lib/exportData";
import { saveFiles } from "@/lib/saveFiles";
import { useApp } from "@/lib/app-state";
import { todayJst } from "@/lib/format";
import { colors, font, space } from "@/theme";

export default function Export() {
  const { space: sp, showToast } = useApp();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [empty, setEmpty] = useState(false);

  const run = async () => {
    if (!sp) return;
    setBusy(true);
    setError(null);
    try {
      const raw = await exportVisibleData(sp.o_space_id);
      const { markdown, csv, count } = buildExport(raw, sp.o_household_id);
      const d = todayJst();
      await saveFiles([
        { name: `kosodate-hint-note-${d}.md`, type: "text/markdown;charset=utf-8", text: markdown },
        { name: `kosodate-hint-note-${d}.csv`, type: "text/csv;charset=utf-8", text: csv },
      ]);
      setEmpty(count === 0);
      showToast("書き出しました（2つのファイル）");
    } catch {
      setError("書き出せませんでした。もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen header={<Header title="記録を書き出す" fallback="/settings" />}>
      <Text style={styles.long}>このノートで、あなたに見える記録を、この端末にファイルで保存します。</Text>
      <View style={{ marginTop: space.m }}>
        <Text style={styles.long}>・読むための形（Markdown）と、表の形（CSV）の2つ</Text>
        <Text style={styles.long}>・入るもの: 困りごと・対策・記録・本・タグ・家庭と呼び名（ほかの家庭の「みんな」の記録も入ります。「自分の家庭だけ」の記録は、うちのものだけ入ります）</Text>
        <Text style={styles.long}>・メールアドレスは入りません。</Text>
      </View>
      <Text style={[styles.long, { marginTop: space.m }]}>ほかの家庭の記録は、許可なく外に出さないでください（書き方の約束6）。</Text>
      {error ? <Text style={[styles.error, { marginTop: space.m }]}>{error}</Text> : null}
      <Button label={busy ? "作っています…" : "書き出す"} busy={busy} onPress={run} style={{ marginTop: space.l }} testID="export-run" />
      {empty ? <Text style={[styles.sub, { marginTop: space.s }]}>まだ記録はありません</Text> : null}
      <Text style={[font.sub, { color: colors.textSub, marginTop: space.m }]}>これはバックアップではありません。</Text>
    </Screen>
  );
}
