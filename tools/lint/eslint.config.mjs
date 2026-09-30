// フックの規則だけを見る ESLint の設定（2026-10-01 開発部）。
// おやこポイントの eslint.config.mjs（読むだけ）と同じ考え方: 本番で画面が出なくなる誤り
// （useState などを早期リターンの後ろで呼ぶ）を止める。型検査（tsc）ではこれを見つけられない。
// 本体の依存と版がぶつかるので、ESLint は tools/lint に別に入れた。
// 使い方（プログラムの置き場所で）: npm run lint
import reactHooks from "eslint-plugin-react-hooks";
import tsParser from "@typescript-eslint/parser";

export default [
  {
    files: ["app/**/*.{ts,tsx}", "src/**/*.{ts,tsx}"],
    plugins: { "react-hooks": reactHooks },
    languageOptions: {
      parser: tsParser,
      parserOptions: { ecmaFeatures: { jsx: true }, sourceType: "module" },
    },
    rules: {
      // フックを条件分岐・早期リターンの後ろで呼ばない。error のまま緩めない。
      "react-hooks/rules-of-hooks": "error",
      // 依存配列の漏れ（意図して外している所があるので warn）。
      "react-hooks/exhaustive-deps": "warn",
    },
  },
];
