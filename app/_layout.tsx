/**
 * 画面全体の枠と、入口の判定（2026-09-30 開発部）。
 * ログインしていない → /login、どのノートにも入っていない → /join、同意がまだ → /consent、そろったら B-1（/）。
 * 順は src/lib/app-state.tsx の GATE_ORDER。/privacy（A-5 預かり方の約束）はログインの前にも開ける（要件 F-05）。
 */
import React, { useEffect } from "react";
import { Stack, useRouter, useSegments } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { View } from "react-native";
import { AppStateProvider, useApp } from "@/lib/app-state";
import { ErrorBox, Loading, Screen } from "@/components/ui";
import { colors } from "@/theme";
import { startUpdateCheck } from "@/lib/updateCheck";

const GATE_SCREENS = ["login", "consent", "join"];

function Gate() {
  const { status, refresh, returnTo } = useApp();
  const segments = useSegments();
  const router = useRouter();
  const first = (segments[0] as string | undefined) ?? "";

  useEffect(() => {
    if (status === "loading" || status === "error") return;
    if (first === "privacy" || first === "left") return; // 預かり方の約束・退会しました は、どの状態でも開ける
    const target =
      status === "signedOut" ? "login" : status === "needConsent" ? "consent" : status === "needJoin" ? "join" : null;
    if (target) {
      if (first !== target) router.replace(`/${target}` as never);
    } else if (GATE_SCREENS.includes(first)) {
      const back = returnTo.current;
      returnTo.current = null;
      router.replace((back ?? "/") as never);
    }
  }, [status, first, router, returnTo]);

  if (status === "loading") {
    return <View style={{ flex: 1, backgroundColor: colors.bg, justifyContent: "center" }}><Loading /></View>;
  }
  if (status === "error") {
    return <Screen><ErrorBox onRetry={() => void refresh()} /></Screen>;
  }
  return <Stack screenOptions={{ headerShown: false, animation: "none", contentStyle: { backgroundColor: colors.bg } }} />;
}

export default function RootLayout() {
  // 配信で画面が新しくなっていたら読み込み直す（Web 版だけ。古い画面が残らないように＝やること 2f-34）
  useEffect(() => startUpdateCheck(), []);
  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <AppStateProvider>
        <Gate />
      </AppStateProvider>
    </SafeAreaProvider>
  );
}
