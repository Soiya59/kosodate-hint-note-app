/** A-1 ログイン（メールアドレス）。ワイヤーフレーム v0.3 A-1・要件 v0.6 F-02・7-2節 ①b（A13） */
import React, { useState } from "react";
import { Text, View } from "react-native";
import { useRouter } from "expo-router";
import { supabase } from "@/lib/supabase";
import { loginFlow } from "@/lib/login-flow";
import { APP, LOGIN_PURPOSE, loginHelp } from "@/constants/texts";
import { OTP_LENGTH } from "@/constants/config";
import { Button, Field, Paragraphs, Screen, styles } from "@/components/ui";
import { colors, font, space } from "@/theme";

export default function LoginEmail() {
  const router = useRouter();
  const [email, setEmail] = useState(loginFlow.email);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const send = async () => {
    const v = email.trim();
    if (!v) return setError("メールアドレスを入れてください");
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) return setError("メールアドレスの形を確かめてください");
    setError(null);
    setBusy(true);
    const { error: e } = await supabase.auth.signInWithOtp({ email: v, options: { shouldCreateUser: true } });
    setBusy(false);
    if (e) {
      if (e.status === 429 || /rate|many/i.test(e.message)) {
        return setError("番号を送る回数が多すぎます。しばらくたってから、もう一度押してください");
      }
      return setError("送れませんでした。通信を確かめて、もう一度押してください");
    }
    loginFlow.email = v;
    loginFlow.sentAt = Date.now();
    router.push("/login/code");
  };

  return (
    <Screen>
      <View style={{ marginTop: space.xxl, marginBottom: space.xl, alignItems: "center" }}>
        <Text style={[font.title, { color: colors.text, fontSize: 24 }]}>{APP.name}</Text>
        <Text style={[styles.sub, { marginTop: space.s }]}>{APP.tagline}</Text>
      </View>
      {/* 要件 v0.6 7-2節 ①b（A13）: メールアドレスを入れる前に読める位置。文は texts.ts の LOGIN_PURPOSE（要件の文のまま・句点で3段落） */}
      <View style={[styles.card, { padding: space.m }]} testID="login-purpose">
        <Paragraphs paragraphs={LOGIN_PURPOSE} onLink={() => router.push({ pathname: "/privacy", params: { at: "5" } })} />
      </View>
      <Field
        label="メールアドレス"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        autoCorrect={false}
        keyboardType="email-address"
        autoComplete="email"
        textContentType="emailAddress"
        inputMode="email"
        onSubmitEditing={send}
        error={error}
        testID="login-email"
      />
      <Button label={busy ? "送っています…" : "ログインの番号を送る"} onPress={send} busy={busy} testID="login-send" />
      <View style={{ marginTop: space.xl }}>
        {loginHelp(OTP_LENGTH).map((l) => <Text key={l} style={styles.body}>{l}</Text>)}
      </View>
    </Screen>
  );
}
