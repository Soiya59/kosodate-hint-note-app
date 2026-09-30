/** A-4 書き方の約束への同意（ワイヤーフレーム v0.3 A-4・要件 v0.6 7-1節・F-03・設計書 v0.3 8-2節） */
import React, { useState } from "react";
import { Text, View } from "react-native";
import { CONSENT, RULES_VERSION } from "@/constants/texts";
import { Button, Screen, styles } from "@/components/ui";
import { RulesText } from "@/components/RulesText";
import { recordRulesConsent } from "@/lib/api";
import { useApp } from "@/lib/app-state";
import { colors, font, space } from "@/theme";

export default function Consent() {
  const { refresh, signOut } = useApp();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const agree = async () => {
    setBusy(true);
    setError(null);
    try {
      await recordRulesConsent(RULES_VERSION); // 連打しても1件（データ置き場の側で ON CONFLICT DO NOTHING）
      await refresh(); // 入口の判定が B-1 へ進める
    } catch {
      setError("記録できませんでした。もう一度押してください");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen
      footer={
        <View>
          {error ? <Text style={[styles.error, { marginBottom: space.s }]}>{error}</Text> : null}
          <Button label={busy ? "送信中…" : CONSENT.agree} onPress={agree} busy={busy} testID="consent-agree" />
          <Button kind="text" label={CONSENT.decline} onPress={() => void signOut()} style={{ marginTop: space.xs }} />
        </View>
      }
    >
      <Text style={[font.title, { color: colors.text }]}>{CONSENT.title(RULES_VERSION)}</Text>
      <View style={{ height: 1, backgroundColor: colors.border, marginTop: space.m }} />
      <RulesText />
    </Screen>
  );
}
