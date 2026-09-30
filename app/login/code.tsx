/** A-2 ログインの番号を入れる。ワイヤーフレーム v0.2 A-2・設計書 v0.3 9-1節の3 */
import React, { useEffect, useRef, useState } from "react";
import { Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";
import { supabase } from "@/lib/supabase";
import { loginFlow } from "@/lib/login-flow";
import { toHalfWidth } from "@/lib/format";
import { OTP_EXPIRY_TEXT, OTP_LENGTH, OTP_RESEND_WAIT_SEC } from "@/constants/config";
import { Button, Header, Screen, styles } from "@/components/ui";
import { colors, font, radius, space } from "@/theme";

export default function LoginCode() {
  const router = useRouter();
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [now, setNow] = useState(Date.now());
  const inputRef = useRef<TextInput>(null);
  const email = loginFlow.email;

  useEffect(() => {
    if (!email) router.replace("/login");
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, [email, router]);

  const waitLeft = Math.max(0, OTP_RESEND_WAIT_SEC - Math.floor((now - loginFlow.sentAt) / 1000));

  const verify = async (token: string) => {
    if (token.length !== OTP_LENGTH) return setError(`${OTP_LENGTH}桁の番号を入れてください`);
    setBusy(true);
    setError(null);
    const { error: e } = await supabase.auth.verifyOtp({ email, token, type: "email" });
    setBusy(false);
    if (e) {
      setCode("");
      inputRef.current?.focus();
      if (e.status === 429) return setError("回数が多すぎます。しばらくたってから、もう一度お試しください");
      if (e.status && e.status < 500) {
        return setError(`番号が違うか、期限（${OTP_EXPIRY_TEXT}）が切れています。もう一度入れるか、番号を送り直してください。`);
      }
      return setError("確かめられませんでした。通信を確かめてください。");
    }
    // 成功: 入口の判定（_layout.tsx）が、同意 → 参加 → B-1 へ進める。A-1・A-2 は履歴に残さない（replace）。
  };

  const onChange = (t: string) => {
    const v = toHalfWidth(t).replace(/\D/g, "").slice(0, OTP_LENGTH);
    setCode(v);
    if (v.length === OTP_LENGTH) void verify(v); // そろったら自動で確かめる
  };

  const resend = async () => {
    const { error: e } = await supabase.auth.signInWithOtp({ email, options: { shouldCreateUser: true } });
    if (e) return setError("回数が多すぎます。しばらくたってから、もう一度お試しください");
    loginFlow.sentAt = Date.now();
    setNow(Date.now());
    setError(null);
  };

  return (
    <Screen header={<Header title="番号を入れる" fallback="/login" />}>
      <Text style={[styles.body, { marginBottom: space.l }]}>
        {email} に{"\n"}{OTP_LENGTH}桁の番号を送りました。
      </Text>
      <TextInput
        ref={inputRef}
        value={code}
        onChangeText={onChange}
        editable={!busy}
        autoFocus
        keyboardType="number-pad"
        inputMode="numeric"
        autoComplete="one-time-code"
        textContentType="oneTimeCode"
        maxLength={OTP_LENGTH + 4}
        placeholder={"_".repeat(OTP_LENGTH)}
        testID="login-code"
        style={{
          ...font.code, textAlign: "center", backgroundColor: colors.surface, borderWidth: 1,
          borderColor: error ? colors.error : colors.border, borderRadius: radius.input, height: 60, color: colors.text,
        }}
      />
      {error ? <Text style={[styles.error, { marginBottom: space.s }]}>{error}</Text> : null}
      <Button label={busy ? "確かめています…" : "ログイン"} onPress={() => verify(code)} busy={busy} style={{ marginTop: space.l }} testID="login-verify" />
      <Text style={[styles.sub, { marginTop: space.l, lineHeight: 20 }]}>
        届かないときは、迷惑メールのフォルダも見てください。差出人は「子育てヒントノート」です。
      </Text>
      <View style={{ flexDirection: "row", alignItems: "center", marginTop: space.l }}>
        <Button kind="secondary" label="番号をもう一度送る" disabled={waitLeft > 0} onPress={resend} />
        {waitLeft > 0 ? <Text style={[styles.sub, { marginLeft: space.m }]}>あと {waitLeft}秒</Text> : null}
      </View>
      <Button kind="text" label="メールアドレスを変える" onPress={() => router.replace("/login")} style={{ marginTop: space.s, alignSelf: "flex-start" }} />
    </Screen>
  );
}
