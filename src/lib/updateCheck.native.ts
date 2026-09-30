/** アプリ版では、画面の更新はストア・アプリの仕組みで行うので何もしない（Web 版は updateCheck.ts）。 */
export function startUpdateCheck(): () => void {
  return () => {};
}
