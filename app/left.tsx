/** E-4 の「退会しました」（ほかのノートが無いとき）。入口の判定の外。［閉じる］で A-1 へ。 */
import React from "react";
import { Text } from "react-native";
import { useRouter } from "expo-router";
import { Button, Screen } from "@/components/ui";
import { colors, font, space } from "@/theme";

export default function Left() {
  const router = useRouter();
  return (
    <Screen>
      <Text style={[font.title, { color: colors.text, marginTop: space.xxl }]} testID="left-title">退会しました</Text>
      <Button label="閉じる" onPress={() => router.replace("/login")} style={{ marginTop: space.xl }} testID="left-close" />
    </Screen>
  );
}
