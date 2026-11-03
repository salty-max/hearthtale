/**
 * The words around a book's text: "Entry 3", "Prologue", the levels line, the
 * race and class, a push's sentence. They are the interface's, as in the game
 * (the window's labels follow the client, the journal's prose its own
 * language): the site's setting on a page and in an export, the device's
 * language for a push, the visitor's for a link preview. The book's language
 * only tags its own words (its prose, an entry's own title, its places).
 *
 * French terms are the addon's own (Text_frFR.lua): "Entrée %d", "Épitaphe";
 * the race and class names are the game's, a woman's where it has one.
 */
import type { Language } from "./index";

export type Sex = 2 | 3;

export type Frame = {
  /** The language code for a `lang` attribute, a feed, an EPUB. */
  lang: "en" | "fr";
  /** What dates and times are written in. */
  locale: string;
  language: Language;
  prologue: string;
  epitaph: string;
  contents: string;
  chapter: (n: number) => string;
  stillWriting: string;
  theEnd: string;
  levels: (from: number, to: number) => string;
  /** "5 to 7 Oct 2026": the word between two dates. */
  to: string;
  /** The label over a player's note in a margin. */
  note: string;
  /** "The journal of Brannok". */
  by: (name: string) => string;
  /** "The book": what a shared page names the whole book. */
  theBook: string;
  /** The mark of a Hardcore life ("Extrême" in French). */
  hardcore: string;
  /** "Level", for a line that starts with it (a preview card lowercases it). */
  levelWord: string;
  /** "Dwarf Hunter" ("chasseresse naine"). */
  raceClass: (race: string, cls: string, sex?: number) => string;
  /** "Level 12 Dwarf Hunter". */
  about: (level: number, race: string, cls: string, sex?: number) => string;
  /** " (fallen)" after a name, a woman's where the language agrees. */
  fallen: (sex?: number) => string;
  /** A push notification: "Brannok wrote “Bristle”", "Brannok wrote 3 new entries". */
  wrote: (name: string, title: string) => string;
  wroteMany: (name: string, n: number) => string;
  theLast: (title: string) => string;
};

// Race: [man, woman]. The 'Skyborne' name is the game's neuter one.
const FR_RACES: Record<string, [string, string]> = {
  Human: ["humain", "humaine"],
  Dwarf: ["nain", "naine"],
  NightElf: ["elfe de la nuit", "elfe de la nuit"],
  Gnome: ["gnome", "gnome"],
  Orc: ["orc", "orque"],
  Troll: ["troll", "trollesse"],
  Tauren: ["tauren", "taurène"],
  Scourge: ["mort-vivant", "morte-vivante"],
  Skyborne: ["éolide de l’Ordre suprême", "éolide de l’Ordre suprême"],
};
const FR_CLASSES: Record<string, [string, string]> = {
  WARRIOR: ["guerrier", "guerrière"],
  PALADIN: ["paladin", "paladin"],
  HUNTER: ["chasseur", "chasseresse"],
  ROGUE: ["voleur", "voleuse"],
  PRIEST: ["prêtre", "prêtresse"],
  SHAMAN: ["chaman", "chamane"],
  MAGE: ["mage", "mage"],
  WARLOCK: ["démoniste", "démoniste"],
  DRUID: ["druide", "druidesse"],
};
const EN_RACES: Record<string, string> = {
  Human: "Human", Dwarf: "Dwarf", NightElf: "Night Elf", Gnome: "Gnome", Orc: "Orc", Troll: "Troll",
  Tauren: "Tauren", Scourge: "Undead", Skyborne: "Skyborne",
};
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
const pick = (pair: [string, string] | undefined, sex?: number) => (pair ? pair[sex === 3 ? 1 : 0] : undefined);

const en: Frame = {
  lang: "en",
  locale: "en-GB",
  language: "enUS",
  prologue: "Prologue",
  epitaph: "Epitaph",
  contents: "Contents",
  chapter: (n) => `Entry ${n}`,
  stillWriting: "still being written",
  theEnd: "the end",
  levels: (a, b) => (a === b ? `level ${a}` : `levels ${a} to ${b}`),
  to: "to",
  note: "A note in the margin",
  by: (name) => `The journal of ${name}`,
  theBook: "The book",
  hardcore: "Hardcore",
  levelWord: "level",
  raceClass: (race, cls) => `${EN_RACES[race] ?? race} ${cap(cls.toLowerCase())}`,
  about: (level, race, cls) => `${cap(en.levelWord)} ${level} ${en.raceClass(race, cls)}`,
  fallen: () => " (fallen)",
  wrote: (name, title) => `${name} wrote “${title}”`,
  wroteMany: (name, n) => `${name} wrote ${n} new entries`,
  theLast: (title) => `the last: “${title}”`,
};

const fr: Frame = {
  lang: "fr",
  locale: "fr-FR",
  language: "frFR",
  prologue: "Prologue",
  epitaph: "Épitaphe",
  contents: "Sommaire",
  chapter: (n) => `Entrée ${n}`,
  stillWriting: "en cours d'écriture",
  theEnd: "la fin",
  levels: (a, b) => (a === b ? `niveau ${a}` : `niveaux ${a} à ${b}`),
  to: "au",
  note: "Une note dans la marge",
  by: (name) => `Le journal de ${name}`,
  theBook: "Le livre",
  hardcore: "Extrême",
  levelWord: "niveau",
  raceClass: (race, cls, sex) => [pick(FR_CLASSES[cls], sex) ?? cap(cls.toLowerCase()), pick(FR_RACES[race], sex) ?? race].join(" "),
  about: (level, race, cls, sex) => `${cap(fr.levelWord)} ${level} ${fr.raceClass(race, cls, sex)}`,
  fallen: (sex) => (sex === 3 ? " (tombée)" : " (tombé)"),
  wrote: (name, title) => `${name} a écrit «\u00a0${title}\u00a0»`,
  wroteMany: (name, n) => `${name} a écrit ${n} nouvelles entrées`,
  theLast: (title) => `la dernière\u00a0: «\u00a0${title}\u00a0»`,
};

/** A language's frame (none, or one without a frame: English). */
export function frameFor(language: Language | undefined): Frame {
  return language === "frFR" ? fr : en;
}

/** The `lang` tag of a book's own words: its language's (a book saved before it was kept: English). */
export function langOf(language: Language | undefined): Frame["lang"] {
  return frameFor(language).lang;
}

/** An Accept-Language header's first language that has a frame ("fr-CA,fr;q=0.9": frFR), else none; one refused (q=0) is skipped. */
export function frameLanguage(acceptLanguage: string | undefined): Language | undefined {
  for (const part of (acceptLanguage ?? "").split(",")) {
    const [tag, ...params] = part.split(";");
    if (params.some((p) => /^\s*q\s*=\s*0(\.0*)?\s*$/.test(p))) continue;
    const code = tag.trim().toLowerCase().split("-")[0];
    if (code === "fr") return "frFR";
    if (code === "en") return "enUS";
  }
  return undefined;
}
