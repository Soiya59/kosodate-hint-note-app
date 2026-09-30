/**
 * 共通の部品（2026-09-30 開発部）。ワイヤーフレーム v0.2 3章のトークンで作る。
 * Web だけで成り立つ操作（ホバー・右クリック・ブラウザの戻る頼み）は使わない（要件 9-5節）。
 */
import React from "react";
import {
  ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
  type StyleProp, type TextInputProps, type ViewStyle,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { colors, font, MAX_WIDTH, radius, space } from "@/theme";
import { scoresFor } from "@/constants/texts";
import { trialDays } from "@/lib/format";
import { useApp } from "@/lib/app-state";

/** 画面の枠: 安全な余白・パソコンでは中央に幅480px・下に固定の欄（footer） */
export function Screen(props: {
  children: React.ReactNode;
  header?: React.ReactNode;
  footer?: React.ReactNode;
  scroll?: boolean;
  onEndReached?: () => void;
  /** 縦に動く中身を外から動かすとき（書く画面の［一言へ］） */
  scrollRef?: React.RefObject<ScrollView | null>;
  /** 画面の上に重ねるもの（下から出る枠・小窓）。縦に動く中身の外に置く */
  overlay?: React.ReactNode;
  /** 右下に浮かせる［＋ 書く］を押したとき（B-1・B-2・B-3） */
  onFab?: () => void;
}) {
  const insets = useSafeAreaInsets();
  const { toast } = useApp();
  const body = props.scroll === false ? (
    <View style={{ flex: 1 }}>{props.children}</View>
  ) : (
    <ScrollView
      ref={props.scrollRef}
      style={{ flex: 1 }}
      contentContainerStyle={{ padding: space.l, paddingBottom: space.xxl }}
      keyboardShouldPersistTaps="handled"
      scrollEventThrottle={200}
      onScroll={(e) => {
        if (!props.onEndReached) return;
        const { layoutMeasurement, contentOffset, contentSize } = e.nativeEvent;
        if (layoutMeasurement.height + contentOffset.y >= contentSize.height - 200) props.onEndReached();
      }}
    >
      {props.children}
    </ScrollView>
  );
  return (
    <View style={[styles.outer, { paddingTop: insets.top }]}>
      <View style={styles.inner}>
        {props.header}
        {body}
        {props.footer ? <View style={[styles.footer, { paddingBottom: Math.max(insets.bottom, space.s) }]}>{props.footer}</View> : null}
        {props.onFab ? <Fab onPress={props.onFab} bottom={(props.footer ? 68 : 16) + insets.bottom} /> : null}
        {props.overlay}
        {toast ? (
          <View pointerEvents="none" style={[styles.toast, { bottom: 96 + insets.bottom }]}>
            <Text style={styles.toastText}>{toast}</Text>
          </View>
        ) : null}
      </View>
    </View>
  );
}

/** 左上の［‹ 戻る］（または［× 閉じる］）。履歴が無いときは代わりの画面へ。 */
export function Header(props: { title?: string; back?: "back" | "close" | false; fallback?: string; right?: React.ReactNode; onBack?: () => void }) {
  const router = useRouter();
  const goBack = () => {
    if (props.onBack) props.onBack();
    else if (router.canGoBack()) router.back();
    else router.replace((props.fallback ?? "/") as never);
  };
  return (
    <View style={styles.header}>
      {props.back === false ? <View style={{ width: 8 }} /> : (
        <Pressable accessibilityRole="button" onPress={goBack} style={styles.headerBtn} hitSlop={8}>
          <Text style={styles.headerBtnText}>{props.back === "close" ? "× 閉じる" : "‹ 戻る"}</Text>
        </Pressable>
      )}
      <Text style={styles.headerTitle} numberOfLines={1}>{props.title ?? ""}</Text>
      <View style={{ minWidth: 72, alignItems: "flex-end" }}>{props.right}</View>
    </View>
  );
}

export function Button(props: {
  label: string;
  onPress?: () => void;
  kind?: "primary" | "secondary" | "text";
  disabled?: boolean;
  busy?: boolean;
  style?: StyleProp<ViewStyle>;
  testID?: string;
}) {
  const kind = props.kind ?? "primary";
  const disabled = props.disabled || props.busy;
  return (
    <Pressable
      accessibilityRole="button"
      testID={props.testID}
      disabled={disabled}
      onPress={props.onPress}
      style={({ pressed }) => [
        kind === "primary" ? styles.btnPrimary : kind === "secondary" ? styles.btnSecondary : styles.btnText,
        disabled && { opacity: 0.5 },
        pressed && { opacity: 0.8 },
        props.style,
      ]}
    >
      {props.busy ? <ActivityIndicator color={kind === "primary" ? "#fff" : colors.primary} style={{ marginRight: 8 }} /> : null}
      <Text style={kind === "primary" ? styles.btnPrimaryText : styles.btnSecondaryText}>{props.label}</Text>
    </Pressable>
  );
}

export function Chip(props: { label: string; selected?: boolean; onPress?: () => void; testID?: string }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected: !!props.selected }}
      testID={props.testID}
      onPress={props.onPress}
      style={[styles.chip, props.selected && styles.chipOn]}
    >
      <Text style={[styles.chipText, props.selected && { color: colors.primary, fontWeight: "700" }]}>{props.label}</Text>
    </Pressable>
  );
}

/**
 * 入力欄。grow を付けると「改行はできないが、長い文は折り返して全文が見える」欄になる
 * （困りごと・対策の名前。統括「対策は長文になることがある」2026-09-30 の直し）。
 */
type FieldProps = TextInputProps & { label?: string; hint?: string; error?: string | null; counter?: string; grow?: boolean };
export const Field = React.forwardRef<TextInput, FieldProps>(function Field(props, ref) {
  const { label, hint, error, counter, style, grow, ...rest } = props;
  const [h, setH] = React.useState(48);
  const growProps: TextInputProps = grow
    ? {
        multiline: true,
        blurOnSubmit: true,
        returnKeyType: "done",
        onChangeText: (t) => rest.onChangeText?.(t.replace(/[\r\n]+/g, "")),
        onContentSizeChange: (e) => setH(Math.max(48, Math.ceil(e.nativeEvent.contentSize.height) + 2)),
      }
    : {};
  return (
    <View style={{ marginBottom: space.m }}>
      {label ? <Text style={styles.label}>{label}</Text> : null}
      <TextInput
        ref={ref}
        placeholderTextColor="#999"
        {...rest}
        {...growProps}
        style={[
          styles.input,
          rest.multiline && !grow && { minHeight: 88, textAlignVertical: "top" },
          grow && { height: h, paddingVertical: 12, lineHeight: 24, textAlignVertical: "top" },
          style,
        ]}
      />
      <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
        <View style={{ flex: 1 }}>
          {error ? <Text style={styles.error}>{error}</Text> : null}
          {hint ? <Text style={styles.hint}>{hint}</Text> : null}
        </View>
        {counter ? <Text style={styles.hint}>{counter}</Text> : null}
      </View>
    </View>
  );
});

/** 点数の札: 数字と言葉を一緒に。1〜5 は同じ色（ワイヤーフレーム 3-4節） */
export function ScoreBadge(props: { score: number | null; status?: "scored" | "trying" | "want"; triedOn?: string; bold?: boolean; kind?: "trouble" | "grow" | null }) {
  // （v0.4）試したいは細い実線の枠・背景なし・日数なし（ワイヤーフレーム v0.4 3-4節）。判定は status で（点数が空＝試し中、にしない）
  if (props.status === "want") {
    return (
      <View style={[styles.badge, { borderColor: colors.trialInk, backgroundColor: "transparent" }]}>
        <Text style={[styles.badgeText, { color: colors.trialInk }, props.bold && { fontWeight: "700" }]}>試したい</Text>
      </View>
    );
  }
  if (props.status === "trying" || (props.status == null && props.score == null)) {
    const d = props.triedOn ? `・${trialDays(props.triedOn)}日目` : "";
    return (
      <View style={[styles.badge, styles.badgeTrial]}>
        <Text style={[styles.badgeText, { color: colors.trialInk }, props.bold && { fontWeight: "700" }]}>試し中{d}</Text>
      </View>
    );
  }
  // ①が育てたいなら育てたいの組（1 変わらなかった〜5 身についた。C115）
  const s = scoresFor(props.kind).find((x) => x.v === props.score);
  return (
    <View style={styles.badge}>
      <Text style={[styles.badgeText, props.bold && { fontWeight: "700" }]}>
        <Text style={{ fontWeight: "700" }}>{props.score}</Text> {s?.label}
      </Text>
    </View>
  );
}

type Piece = { text: string; link?: boolean };

/** 文の中のリンク（primary・下線。［ ］は出さない。ワイヤーフレーム v0.3 3-2節） */
export function Pieces(props: { pieces: readonly Piece[]; onLink?: () => void }) {
  return (
    <>
      {props.pieces.map((p, i) =>
        p.link ? (
          <Text key={i} accessibilityRole="link" onPress={props.onLink} style={styles.link} suppressHighlighting={false}>
            {p.text}
          </Text>
        ) : (
          <Text key={i}>{p.text}</Text>
        ),
      )}
    </>
  );
}

/** 段落の並び（行の高さ 1.7 倍・段落の間 12px） */
export function Paragraphs(props: { paragraphs: readonly (readonly Piece[])[]; onLink?: () => void }) {
  return (
    <View>
      {props.paragraphs.map((ps, i) => (
        <Text key={i} style={[styles.long, i > 0 && { marginTop: space.m }]}>
          <Pieces pieces={ps} onLink={props.onLink} />
        </Text>
      ))}
    </View>
  );
}

/** 長い文の見出し（rowTitle・上24px・下8px） */
export function LongHeading(props: { text: string }) {
  return <Text style={[font.rowTitle, { color: colors.text, marginTop: space.xl, marginBottom: space.s }]}>{props.text}</Text>;
}

/** 箇条（「1.」「・」）。2行目以降を頭の後ろにそろえる（ぶら下げ） */
export function Hanging(props: { mark: string; children: React.ReactNode }) {
  return (
    <View style={{ flexDirection: "row", marginBottom: space.xs }}>
      <Text style={[styles.long, { minWidth: props.mark.length > 1 ? 24 : 16 }]}>{props.mark}</Text>
      <Text style={[styles.long, { flex: 1 }]}>{props.children}</Text>
    </View>
  );
}

export function Notice(props: { text: string }) {
  return <View style={styles.notice}><Text style={styles.body}>{props.text}</Text></View>;
}

export function ErrorBox(props: { text?: string; onRetry?: () => void }) {
  return (
    <View style={{ alignItems: "center", padding: space.xl }}>
      <Text style={[styles.body, { textAlign: "center", marginBottom: space.m }]}>
        {props.text ?? "読み込めませんでした。通信を確かめてください。"}
      </Text>
      {props.onRetry ? <Button kind="secondary" label="もう一度" onPress={props.onRetry} /> : null}
    </View>
  );
}

export function Loading() {
  return <View style={{ padding: space.xl }}><ActivityIndicator color={colors.primary} /></View>;
}

/** 下のタブ（B-1・B-2・E-1 だけに出す。ワイヤーフレーム 2章） */
export function BottomTabs(props: { current: "home" | "ages" | "settings" }) {
  const router = useRouter();
  const tabs: { k: typeof props.current; label: string; href: string }[] = [
    { k: "home", label: "ノート", href: "/" },
    { k: "ages", label: "年齢", href: "/ages" },
    { k: "settings", label: "設定", href: "/settings" },
  ];
  return (
    <View style={styles.tabs}>
      {tabs.map((t) => (
        <Pressable
          key={t.k}
          accessibilityRole="tab"
          accessibilityState={{ selected: props.current === t.k }}
          onPress={() => { if (props.current !== t.k) router.replace(t.href as never); }}
          style={styles.tab}
        >
          <Text style={[styles.tabText, props.current === t.k && { color: colors.primary, fontWeight: "700" }]}>{t.label}</Text>
        </Pressable>
      ))}
    </View>
  );
}

/** 右下に浮かせる［＋ 書く］ */
export function Fab(props: { onPress: () => void; bottom?: number }) {
  return (
    <Pressable accessibilityRole="button" onPress={props.onPress} style={[styles.fab, { bottom: props.bottom ?? 72 }]} testID="fab-write">
      <Text style={styles.btnPrimaryText}>＋ 書く</Text>
    </Pressable>
  );
}

/**
 * 下から出る枠（C-2・C-3・確認の小窓）。React Native の Modal を使うので、Web・アプリで同じに動き、
 * 縦に動く中身のどこに置いても画面全体の上に出る。Android の戻る操作でも閉じる（ワイヤーフレーム 9-2節(1)）。
 */
export function Sheet(props: { visible: boolean; onClose: () => void; title: string; children: React.ReactNode }) {
  if (!props.visible) return null;
  return (
    <Modal transparent visible animationType="none" onRequestClose={props.onClose}>
    <View style={[styles.sheetBackdrop, { alignItems: "center" }]}>
      <Pressable style={{ flex: 1, alignSelf: "stretch" }} onPress={props.onClose} accessibilityLabel="閉じる" />
      <View style={styles.sheet}>
        <View style={{ flexDirection: "row", alignItems: "center", marginBottom: space.m }}>
          <Text style={[font.rowTitle, { flex: 1, color: colors.text }]}>{props.title}</Text>
          <Pressable onPress={props.onClose} hitSlop={8} style={styles.headerBtn}><Text style={styles.headerBtnText}>閉じる</Text></Pressable>
        </View>
        <ScrollView style={{ maxHeight: 460 }} keyboardShouldPersistTaps="handled">{props.children}</ScrollView>
      </View>
    </View>
    </Modal>
  );
}

export const styles = StyleSheet.create({
  outer: { flex: 1, backgroundColor: colors.bg, alignItems: "center" },
  inner: { flex: 1, width: "100%", maxWidth: MAX_WIDTH, backgroundColor: colors.bg },
  header: { flexDirection: "row", alignItems: "center", paddingHorizontal: space.s, height: 52, borderBottomWidth: 1, borderBottomColor: colors.border },
  headerBtn: { minHeight: 44, minWidth: 44, justifyContent: "center", paddingHorizontal: space.s },
  headerBtnText: { ...font.body, color: colors.primary },
  headerTitle: { ...font.rowTitle, color: colors.text, flex: 1, textAlign: "center" },
  footer: { borderTopWidth: 1, borderTopColor: colors.border, backgroundColor: colors.surface, paddingHorizontal: space.l, paddingTop: space.s },
  btnPrimary: { backgroundColor: colors.primary, height: 48, borderRadius: radius.input, alignItems: "center", justifyContent: "center", flexDirection: "row", paddingHorizontal: space.l },
  btnSecondary: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.primary, minHeight: 44, borderRadius: radius.input, alignItems: "center", justifyContent: "center", flexDirection: "row", paddingHorizontal: space.l },
  btnText: { minHeight: 44, alignItems: "center", justifyContent: "center", flexDirection: "row", paddingHorizontal: space.s },
  btnPrimaryText: { ...font.body, color: "#fff", fontWeight: "700" },
  btnSecondaryText: { ...font.body, color: colors.primary },
  chip: { borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, borderRadius: 999, paddingHorizontal: space.m, minHeight: 36, justifyContent: "center", marginRight: space.s, marginBottom: space.s },
  /** 区切りのボタン（種類の切り替え。横いっぱいに等分・高さ44px） */
  segment: { flex: 1, minHeight: 44, alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface },
  segmentOn: { backgroundColor: colors.primarySoft, borderColor: colors.primary },
  chipOn: { backgroundColor: colors.primarySoft, borderColor: colors.primary },
  chipText: { ...font.sub, color: colors.text },
  label: { ...font.body, fontWeight: "700", color: colors.text, marginBottom: space.xs },
  input: { ...font.body, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, borderRadius: radius.input, paddingHorizontal: space.m, minHeight: 48, color: colors.text },
  hint: { ...font.sub, color: colors.textSub, marginTop: space.xs },
  error: { ...font.sub, color: colors.error, marginTop: space.xs },
  body: { ...font.body, color: colors.text, lineHeight: 24 },
  /** 値を目立たせる札（書く画面の「今日」「みんな」） */
  /** 種類の札「育てたい」（灰色の枠・背景なし。緑を使わない。ワイヤーフレーム v0.4 3-1節） */
  kindTag: { ...font.sub, fontWeight: "400", color: colors.textSub, borderWidth: 1, borderColor: colors.border, borderRadius: radius.input, paddingHorizontal: space.s, paddingVertical: 1, overflow: "hidden" },
  valueTag: { ...font.body, fontWeight: "700", color: colors.primary, backgroundColor: colors.primarySoft, borderRadius: radius.input, paddingHorizontal: space.s, paddingVertical: 2, overflow: "hidden" },
  long: { ...font.body, color: colors.text, lineHeight: 27 },
  link: { color: colors.primary, textDecorationLine: "underline" },
  sub: { ...font.sub, color: colors.textSub },
  badge: { borderWidth: 1, borderColor: colors.scoreInk, backgroundColor: colors.scoreBg, borderRadius: radius.input, paddingHorizontal: space.s, paddingVertical: 2, alignSelf: "flex-start" },
  badgeTrial: { borderStyle: "dashed", borderColor: colors.trialInk, backgroundColor: colors.surface },
  badgeText: { ...font.body, color: colors.scoreInk },
  notice: { backgroundColor: colors.notice, padding: space.m, borderRadius: radius.input, marginBottom: space.m },
  tabs: { flexDirection: "row", borderTopWidth: 1, borderTopColor: colors.border, backgroundColor: colors.surface },
  tab: { flex: 1, minHeight: 52, alignItems: "center", justifyContent: "center" },
  tabText: { ...font.body, color: colors.textSub },
  fab: { position: "absolute", right: space.l, backgroundColor: colors.primary, borderRadius: 28, height: 52, paddingHorizontal: space.xl, justifyContent: "center", elevation: 3, shadowColor: "#000", shadowOpacity: 0.15, shadowRadius: 6, shadowOffset: { width: 0, height: 2 } },
  card: { backgroundColor: colors.surface, borderRadius: radius.card, borderWidth: 1, borderColor: colors.border, padding: space.l, marginBottom: space.m },
  row: { paddingVertical: space.m, borderBottomWidth: 1, borderBottomColor: colors.border },
  toast: { position: "absolute", left: space.l, right: space.l, backgroundColor: "#333", borderRadius: radius.input, padding: space.m, alignItems: "center" },
  toastText: { ...font.body, color: "#fff" },
  sheetBackdrop: { position: "absolute", left: 0, right: 0, top: 0, bottom: 0, backgroundColor: "rgba(0,0,0,0.35)", justifyContent: "flex-end" },
  sheet: { width: "100%", maxWidth: MAX_WIDTH, backgroundColor: colors.surface, borderTopLeftRadius: radius.card, borderTopRightRadius: radius.card, padding: space.l, paddingBottom: space.xl },
});
