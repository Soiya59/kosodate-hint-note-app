/** デザイントークン（ワイヤーフレーム v0.2 3章。値はそのまま） */
export const colors = {
  bg: "#FBF9F4",
  surface: "#FFFFFF",
  border: "#E5E5E5",
  text: "#171717",
  textSub: "#666666",
  primary: "#2F6F62",
  primarySoft: "#E8F1EE",
  scoreInk: "#3D4A47",
  scoreBg: "#F3F1EC",
  trialInk: "#666666",
  notice: "#FFF8E1",
  error: "#B42318",
};

export const font = {
  title: { fontSize: 20, fontWeight: "700" as const },
  rowTitle: { fontSize: 17, fontWeight: "700" as const },
  body: { fontSize: 16 },
  code: { fontSize: 24, fontWeight: "700" as const, letterSpacing: 4 },
  sub: { fontSize: 14 },
};

export const space = { xs: 4, s: 8, m: 12, l: 16, xl: 24, xxl: 32 };
export const radius = { input: 8, card: 12 };
/** パソコンのブラウザでは中央に幅480px（ワイヤーフレーム 9-2節(2)〔Web版だけ〕） */
export const MAX_WIDTH = 480;
