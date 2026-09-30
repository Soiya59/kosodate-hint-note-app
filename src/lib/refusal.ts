/**
 * ①②を消せなかったときの断りの文（要件 2-5節の文言のまま・ワイヤーフレーム v0.4 8章の表）。
 * 文を選ぶ材料は「画面に今見えている③」だけ（見えない③の有無で文は変わらない）。
 */
export function deleteRefusal(p: { isAdmin: boolean; visibleHouseholdIds: string[]; myHouseholdId: string; adminName: string }): string {
  const onlyOwn = p.visibleHouseholdIds.length > 0 && p.visibleHouseholdIds.every((h) => h === p.myHouseholdId);
  if (p.isAdmin || onlyOwn) return "記録が付いているため、消せません。先に記録を消してください。";
  return `ほかの家庭の記録も付いているため、消せません。名前を直したいときは管理者（${p.adminName}さん）に伝えてください。`;
}
