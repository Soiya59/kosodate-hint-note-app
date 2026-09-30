/** 端末の中の保存先の形（Web とアプリで同じ）。 */
export type KV = {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
};
