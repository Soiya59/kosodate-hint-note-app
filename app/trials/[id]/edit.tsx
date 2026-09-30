/** C-1 の直すモード（/trials/[id]/edit。ワイヤーフレーム v0.4 C-1「B-4 の［直す］」）。中身は書く画面と同じ部品。 */
import React from "react";
import { useLocalSearchParams } from "expo-router";
import { WriteScreen } from "../../write";

export default function EditTrial() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <WriteScreen editId={id} />;
}
