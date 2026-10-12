import type { CharacterSummary } from "@hearthtale/shared";
import type { Strings } from "@/lib/i18n";

/** The game's classes, by their tokens. */
export const CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"] as const;

/**
 * A class's colour, the game's own by night, a darker one by day so it reads on
 * parchment (index.css: --class-<token>); the frame's own words for a class
 * the site doesn't know.
 */
export function classColour(token: string): string | undefined {
  return (CLASSES as readonly string[]).includes(token) ? `var(--class-${token.toLowerCase()})` : undefined;
}

/** A class's round crest, the game's own (public/classes, scripts/assets.py). */
export function crestOf(token: string): string | undefined {
  return (CLASSES as readonly string[]).includes(token) ? `/classes/${token.toLowerCase()}.png` : undefined;
}

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
