/**
 * アプリ版の書き出し: 端末の共有の画面に渡す（要件 9-5節）。
 * いまは標準の Share で文を渡すだけ（ファイルとして渡すには expo-file-system・expo-sharing が要る。アプリにするときに足す）。
 */
import { Share } from "react-native";

export async function saveFiles(files: { name: string; type: string; text: string }[]): Promise<void> {
  for (const f of files) {
    await Share.share({ title: f.name, message: f.text });
  }
}
