/** 書き出したファイルを保存する（Web 版: ダウンロード）。アプリ版は saveFiles.native.ts（共有の画面）。要件 9-5節 */
export async function saveFiles(files: { name: string; type: string; text: string }[]): Promise<void> {
  for (const f of files) {
    const blob = new Blob([f.text], { type: f.type });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = f.name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}
