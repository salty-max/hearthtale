import type { CharacterSummary, Frame } from "@hearthtale/shared";

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

/** "Dwarf Hunter" ("Chasseresse naine"), in a frame's language. */
export function raceClassLine(f: Frame, c: Pick<CharacterSummary, "race" | "class" | "sex">): string {
  return f.raceClass(c.race, c.class, c.sex);
}

/** "Level 12 Dwarf Hunter" ("Niveau 12 chasseur nain"), from the game's tokens, in a frame's language. */
export function aboutLine(f: Frame, c: Pick<CharacterSummary, "race" | "class" | "level" | "sex">): string {
  return f.about(c.level, c.race, c.class, c.sex);
}

const REGIONS: Record<number, string> = { 1: "US", 2: "KR", 3: "EU", 4: "TW", 5: "CN" };

/** "Nightslayer (US)". */
export function realmName(c: Pick<CharacterSummary, "realm" | "region">): string | undefined {
  if (!c.realm) return undefined;
  const region = c.region ? REGIONS[c.region] : undefined;
  return region ? `${c.realm} (${region})` : c.realm;
}
