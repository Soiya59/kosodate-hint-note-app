// アイコンの PNG を作る（2026-10-01 開発部）。
//   元の絵: tools/icons/icon.svg・icon-maskable.svg（UIUXデザイン部 `UIUXデザイン部/成果物/アプリのアイコン（2026-10-01）/` から写した）
//   出力: public/icons/ の PNG（マニフェスト・iPhone のホーム画面・ブラウザのタブ）と icon.svg（タブ用）
//   使い方（プログラムの置き場所で）: npm ci --prefix tools/icons && node tools/icons/make-icons.mjs
//   絵を差し替えたら、SVG を写し直してから流し直す。
import sharp from "sharp";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(here, "..", "..", "public", "icons");
fs.mkdirSync(out, { recursive: true });
const svg = (n) => fs.readFileSync(path.join(here, n));

const jobs = [
  // マニフェスト（Android の Chrome）: ふつうの形（角丸・四隅は透明）
  ["icon.svg", "icon-192.png", 192],
  ["icon.svg", "icon-512.png", 512],
  // マニフェスト: maskable（四隅まで塗る。端末が丸や角丸に切り抜く）
  ["icon-maskable.svg", "icon-maskable-192.png", 192],
  ["icon-maskable.svg", "icon-maskable-512.png", 512],
  // iPhone の Safari の「ホーム画面に追加」: 四隅まで塗った絵（iPhone が角を丸める。透明だと黒くなる）
  ["icon-maskable.svg", "apple-touch-icon.png", 180],
  // ブラウザのタブ
  ["icon.svg", "favicon-32.png", 32],
  ["icon.svg", "favicon-48.png", 48],
];
for (const [src, name, size] of jobs) {
  await sharp(svg(src), { density: 384 }).resize(size, size).png({ compressionLevel: 9 }).toFile(path.join(out, name));
  console.log("書きました:", name, `${size}x${size}`, fs.statSync(path.join(out, name)).size, "bytes");
}
// ブラウザのタブ用に SVG もそのまま置く（対応するブラウザはこちらを使う）
fs.copyFileSync(path.join(here, "icon.svg"), path.join(out, "icon.svg"));
console.log("写しました: icon.svg");
