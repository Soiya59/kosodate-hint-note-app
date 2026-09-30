// Expo の設定（2026-10-01 開発部）。中身は app.json、ここでは配信のときだけ変わる所を足す。
// - GitHub Pages では画面が https://soiya59.github.io/kosodate-hint-note-app/ の下に置かれるので、
//   配信のときだけ道の先頭（baseUrl）を EXPO_PUBLIC_BASE_URL から入れる（例 /kosodate-hint-note-app）。
//   開発サーバ・通し確認では空（道の先頭は /）。値は .github/workflows/deploy-pages.yml が渡す。
module.exports = ({ config }) => {
  const baseUrl = process.env.EXPO_PUBLIC_BASE_URL || "";
  return {
    ...config,
    experiments: { ...(config.experiments ?? {}), ...(baseUrl ? { baseUrl } : {}) },
  };
};
