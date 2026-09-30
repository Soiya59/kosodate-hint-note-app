/** E-2 書き方の約束（読むだけ。ワイヤーフレーム v0.3 E-2）。本文は A-4 と同じ定数（RulesText）。ボタンの2行は出さない。 */
import React from "react";
import { Text } from "react-native";
import { RULES_VERSION, rulesReadTitle } from "@/constants/texts";
import { Header, Screen } from "@/components/ui";
import { RulesText } from "@/components/RulesText";
import { colors, font } from "@/theme";

export default function Rules() {
  // 題は「書き方の約束 第1版（同意済み）」（要件 v0.7 C93。同意した日は出さない）
  return (
    <Screen header={<Header fallback="/settings" />}>
      <Text style={[font.title, { color: colors.text }]}>{rulesReadTitle(RULES_VERSION)}</Text>
      <RulesText />
    </Screen>
  );
}
