/** A-4 同意画面と E-2 書き方の約束で共通の本文（要件 v0.6 7-1節の枠。同じ定数から出す＝ワイヤーフレーム E-2） */
import React from "react";
import { Text, View } from "react-native";
import { useRouter } from "expo-router";
import { CONSENT } from "@/constants/texts";
import { Hanging, LongHeading, Pieces, styles } from "@/components/ui";
import { space } from "@/theme";

export function RulesText() {
  const router = useRouter();
  const openPrivacy = () => router.push("/privacy");
  return (
    <View>
      <Text style={[styles.long, { marginTop: space.m }]}>{CONSENT.intro}</Text>
      <LongHeading text={CONSENT.rulesHeading} />
      {CONSENT.rules.map((r, i) => (
        <Hanging key={i} mark={`${i + 1}.`}>{r}</Hanging>
      ))}
      <LongHeading text={CONSENT.custodyHeading} />
      {CONSENT.custody.map((pieces, i) => (
        <Hanging key={i} mark="・"><Pieces pieces={pieces} onLink={openPrivacy} /></Hanging>
      ))}
    </View>
  );
}
