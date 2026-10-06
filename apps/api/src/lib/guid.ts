import type { Region } from "@hearthtale/shared";

/** "Player-6113-03D658B8" → realm 6113, character 64379064 (the Battle.net API ids). */
export function parseGuid(guid: string): { realmId: number; characterId: number } | null {
  const m = /^Player-(\d+)-([0-9A-Fa-f]{1,16})$/.exec(guid);
  if (!m) return null;
  const characterId = parseInt(m[2], 16);
  return Number.isSafeInteger(characterId) ? { realmId: Number(m[1]), characterId } : null;
}

/** The game's GetCurrentRegion() numbers, as Battle.net regions (CN has no public API). */
const BY_NUMBER: Record<number, Region> = { 1: "us", 2: "kr", 3: "eu", 4: "tw" };

export function regionOf(n: number | null | undefined): Region | null {
  return n != null ? (BY_NUMBER[n] ?? null) : null;
}
export function regionNumber(r: Region): number {
  return Number(Object.entries(BY_NUMBER).find(([, v]) => v === r)?.[0]);
}
