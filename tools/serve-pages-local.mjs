// GitHub Pages の置き方をこのパソコンだけでまねる小さなサーバ（2026-10-01 開発部。確かめ用）。
//   dist/ を http://localhost:8090/kosodate-hint-note-app/ の下に置き、無い道は 404.html（＝画面の殻）を返す。
//   先に書き出す: EXPO_PUBLIC_BASE_URL=/kosodate-hint-note-app npx expo export -p web && cp dist/index.html dist/404.html
//   使い方: node tools/serve-pages-local.mjs  （止めるときは Ctrl+C）
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "dist");
const BASE = "/kosodate-hint-note-app";
const PORT = Number(process.env.PORT ?? 8090);
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".json": "application/json", ".png": "image/png", ".txt": "text/plain", ".ico": "image/x-icon", ".css": "text/css", ".webmanifest": "application/manifest+json", ".svg": "image/svg+xml" };

http.createServer((req, res) => {
  const url = new URL(req.url ?? "/", "http://localhost");
  if (!url.pathname.startsWith(BASE)) { res.writeHead(404); return res.end("not under " + BASE); }
  let rel = decodeURIComponent(url.pathname.slice(BASE.length)) || "/";
  if (rel.endsWith("/")) rel += "index.html";
  const file = path.join(root, rel);
  const send = (f, status) => {
    res.writeHead(status, { "Content-Type": types[path.extname(f)] ?? "application/octet-stream", "Cache-Control": "max-age=600" });
    fs.createReadStream(f).pipe(res);
  };
  if (file.startsWith(root) && fs.existsSync(file) && fs.statSync(file).isFile()) return send(file, 200);
  send(path.join(root, "404.html"), 404); // GitHub Pages と同じ: 無い道は 404.html
}).listen(PORT, "127.0.0.1", () => console.log(`http://localhost:${PORT}${BASE}/`));
