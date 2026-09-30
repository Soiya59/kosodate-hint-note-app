/** アプリ（iOS・Android）での保存先。Web 版は storage.ts。中身の形は同じ（要件 9-5節）。 */
import AsyncStorage from "@react-native-async-storage/async-storage";
import type { KV } from "./kv";

export const storage: KV = {
  getItem: (key) => AsyncStorage.getItem(key),
  setItem: (key, value) => AsyncStorage.setItem(key, value),
  removeItem: (key) => AsyncStorage.removeItem(key),
};
