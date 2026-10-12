import type { Region } from "@hearthtale/shared";

/**
 * The Battle.net region a visitor most likely plays in, from their clock's
 * time zone: the Americas and Oceania are one region (US), Korea and Taiwan
 * their own, the rest Europe's.
 */
export function guessRegion(timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone ?? ""): Region {
  if (timeZone === "Asia/Seoul") return "kr";
  if (timeZone === "Asia/Taipei") return "tw";
  if (/^(America|US|Canada|Brazil|Chile|Mexico|Pacific|Australia|Antarctica)\//.test(timeZone)) return "us";
  if (timeZone === "Pacific/Auckland" || timeZone.startsWith("NZ")) return "us";
  return "eu";
}
