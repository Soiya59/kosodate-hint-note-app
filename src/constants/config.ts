/**
 * 動きの数字（2026-09-30 開発部）。本番の設定に合わせて1か所で直す（要件 v0.5 F-02・9-3節・C71・C72、設計書 v0.3 9-1節の3）。
 * - 2026-10-01 本部長: 本番から最初に届いた番号は8桁だった（Supabase の既定）。統括「6桁でよい」で、統括が本番の管理画面
 *   （Authentication → Sign In / Providers → Email → OTP Length）を 6 にした。ローカル（supabase/config.toml）も otp_length = 6。otp_expiry = 3600。
 */
export const OTP_LENGTH = 6;
/** 番号の期限（画面の文に出す） */
export const OTP_EXPIRY_TEXT = "1時間";
/** 番号をもう一度送れるまでの秒数（ワイヤーフレーム A-2） */
export const OTP_RESEND_WAIT_SEC = 60;

/** 困りごとの一覧を1回に取る件数（設計書 5-1節。上限200） */
export const PAGE_SIZE = 50;
/** 打つのが止まってから問い合わせるまで（ミリ秒。ワイヤーフレーム 9-1節の7） */
export const DEBOUNCE_MS = 300;
/** 対策の一覧の1行に出す③の数（要件 6-3節） */
export const TRIALS_PER_ROW = 4;
/** 最近選んだ年齢を覚える数（要件 F-16） */
export const RECENT_AGES = 3;
