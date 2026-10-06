import type { CharacterSummary } from "@hearthtale/shared";
import type { Strings } from "@/lib/i18n";

/** The game's class colours (on dark backgrounds only). */
export const CLASS_COLOURS: Record<string, string> = {
  WARRIOR: "#C69B6D",
  PALADIN: "#F48CBA",
  HUNTER: "#AAD372",
  ROGUE: "#FFF468",
  PRIEST: "#FFFFFF",
  SHAMAN: "#0070DD",
  MAGE: "#3FC7EB",
  WARLOCK: "#8788EE",
  DRUID: "#FF7C0A",
};

/** "Dwarf Hunter" ("Chasseur nain"), from the game's tokens. */
export function raceClass(t: Strings, c: Pick<CharacterSummary, "race" | "class">): string {
  return t.raceClass(t.races[c.race] ?? c.race, t.classes[c.class] ?? c.class);
}

/** "Nightslayer (US)". */
export function realmName(t: Strings, c: Pick<CharacterSummary, "realm" | "region">): string | undefined {
  if (!c.realm) return undefined;
  const region = c.region ? t.regions[c.region] : undefined;
  return region ? `${c.realm} (${region})` : c.realm;
}
