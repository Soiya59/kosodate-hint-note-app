/**
 * A-5 預かり方の約束（ワイヤーフレーム v0.3 A-5・要件 v0.6 F-05・8-6節）。
 * 入口の判定を通さず、ログインの前・ノートに入る前・同意の前にも開ける。データ置き場もログインの情報も使わない。
 * 文は src/constants/fixedTexts.ts（要件 8-6節の枠をそのまま写したもの）。A-1 から来たとき（?at=5）は「5.」の見出しまで送る。
 */
import React, { useRef } from "react";
import { Linking, ScrollView, Text, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { PRIVACY } from "@/constants/texts";
import { Button, Hanging, Header, LongHeading, Screen, styles } from "@/components/ui";
import { useApp } from "@/lib/app-state";
import { space } from "@/theme";

/** 行の中のメールアドレスと URL をリンクにする */
function Linked(props: { text: string }) {
  const { showToast } = useApp();
  const parts = props.text.split(/(https:\/\/[^\s）]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/);
  return (
    <>
      {parts.map((p, i) => {
        if (/^https:\/\//.test(p)) {
          return <Text key={i} style={styles.link} accessibilityRole="link" onPress={() => void Linking.openURL(p)}>{p}</Text>;
        }
        if (/@/.test(p) && /^[A-Za-z0-9._%+-]+@/.test(p)) {
          return (
            <Text key={i} style={styles.link} accessibilityRole="link" selectable
              onPress={() => Linking.openURL(`mailto:${p}`).catch(() => showToast("メールのアプリを開けませんでした。アドレスを選んでコピーしてください"))}>
              {p}
            </Text>
          );
        }
        return <Text key={i}>{p}</Text>;
      })}
    </>
  );
}

export default function Privacy() {
  const router = useRouter();
  const { at } = useLocalSearchParams<{ at?: string }>();
  const scrollRef = useRef<ScrollView>(null);
  const done = useRef(false);

  const back = () => {
    if (router.canGoBack()) router.back();
    else router.replace("/");
  };

  return (
    <Screen scroll={false} header={<Header title={PRIVACY.title} fallback="/" />}>
      <ScrollView ref={scrollRef} contentContainerStyle={{ padding: space.l, paddingBottom: space.xxl }} testID="privacy-scroll">
        {PRIVACY.sections.map((sec) => (
          <View
            key={sec.h}
            onLayout={(e) => {
              if (!done.current && at && sec.h.startsWith(`${at}.`)) {
                done.current = true;
                const y = e.nativeEvent.layout.y;
                setTimeout(() => scrollRef.current?.scrollTo({ y, animated: false }), 0);
              }
            }}
          >
            <LongHeading text={sec.h} />
            {sec.lines.map((line, i) => {
              if (line.startsWith("・")) return <Hanging key={i} mark="・"><Linked text={line.slice(1)} /></Hanging>;
              if (/^(預かるもの|預からないもの):$/.test(line)) {
                return <Text key={i} style={[styles.long, { fontWeight: "700", marginTop: space.m }]}>{line}</Text>;
              }
              return <Text key={i} selectable style={[styles.long, { marginBottom: space.xs }]}><Linked text={line} /></Text>;
            })}
          </View>
        ))}
        <Text style={[styles.sub, { marginTop: space.xl }]}>{PRIVACY.enacted}</Text>
        <Button kind="secondary" label="もとの画面に戻る" onPress={back} style={{ marginTop: space.xl, height: 48 }} />
      </ScrollView>
    </Screen>
  );
}
