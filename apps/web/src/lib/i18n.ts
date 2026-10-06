import { useSettings } from "@/lib/settings";

/**
 * Every visible string, per language. English only for now (the books are
 * written in English); another language is one more catalog of the same shape
 * (`typeof en`, so a missing or extra key fails to compile) in CATALOGS, and
 * the language setting appears on its own once there are two.
 */
const en = {
  nav: { home: "Hearthtale", start: "Get started", library: "Library", settings: "Settings", hall: "Hall", menu: "Menu", skip: "Skip to content", language: "Language" },
  home: {
    tagline: "Your character's own journal, written as you play.",
    intro:
      "Hearthtale is a World of Warcraft addon. Every quest, every new foe, every place, every close call is written down as it happens, in your character's own voice, and a chapter closes when you rest at an inn or by a campfire. On Hardcore, a death closes the book with an epitaph.",
    soon: "Your journal, read in the game or here, on your phone: install the addon and Ravenpost, then sign in.",
    start: "Get started",
    games: "Classic Era, Hardcore, Season of Discovery, TBC Anniversary and World of Warcraft: Forever.",
  },
  notFound: { title: "Lost in the mist", body: "There is no page here.", back: "Back to the hearth" },
  common: { loading: "Turning the pages…", loadError: "This page couldn't be loaded. Check your connection, then try again.", retry: "Try again" },
  account: {
    signIn: "Sign in with Battle.net",
    signInShort: "Sign in",
    signInTitle: "Your books",
    signInWhy: "Sign in with Battle.net: your Classic Era and TBC Anniversary characters are found on their own, and their books are yours alone.",
    region: "Region",
    regions: { us: "Americas", eu: "Europe", kr: "Korea", tw: "Taiwan" } as Record<string, string>,
    forever: "World of Warcraft: Forever characters are linked from the library, with a code typed in the game.",
    failed: "Battle.net didn't let us in. Try again in a moment.",
    cancelled: "Sign-in cancelled.",
    signOut: "Sign out",
    you: "You",
    testAccount: "Use the test account (development only)",
  },
  link: {
    title: "Link a character",
    why: "For a character Battle.net can't find (World of Warcraft: Forever): get a code, type it in the game, and its book joins your library at its next upload.",
    get: "Get a code",
    type: "In the game, type:",
    copy: "Copy",
    then: (until: string) => `Then log out or /reload. The code works until ${until}, once.`,
  },
  start: {
    title: "Get started",
    intro: "The addon writes your character's journal as you play; read it in the game with /ht. To read it here too, Ravenpost, a small app on your computer, sends each book to your library after you log out.",
    addonTitle: "1. The addon",
    addon: "Unzip it into the game's Interface/AddOns folder (one package per game).",
    classic: "Classic",
    classicDetail: "Classic Era, Hardcore, Season of Discovery, TBC Anniversary",
    forever: "Forever",
    foreverDetail: "World of Warcraft: Forever",
    ravenpostTitle: "2. Ravenpost",
    ravenpost: "The companion app that carries your books here (and WoWLocker's data, if you use it). It lives in the tray or the menu bar.",
    windows: "Windows",
    windowsDetail: "Windows 10 or 11",
    macos: "macOS",
    macosDetail: "macOS 11 or later: move it to Applications",
    windowsArm: "Windows on ARM",
    unsigned: "Not code-signed yet: Windows and macOS warn the first time you open it.",
    stepsTitle: "3. Link it",
    steps: [
      "Open Ravenpost: its settings page opens in your browser.",
      "Under Hearthtale, click Link Hearthtale: this site opens, sign in with Battle.net and confirm the code.",
      "Play, then log out or type /reload: a few seconds later, your book is in your library.",
    ],
    foreverLink: "World of Warcraft: Forever characters (and any Battle.net can't find): in the library, get a link code and type /ht link CODE in the game before you log out.",
    addonSource: "The addon's releases",
    ravenpostSource: "Ravenpost's releases",
  },
  pair: {
    title: "Link this computer",
    ask: (who: string) => `Ravenpost, on this computer, asks to send your characters' books to ${who}'s library. The code it shows:`,
    check: "Check it matches the one in Ravenpost.",
    confirm: "Link this computer",
    done: "Linked. Ravenpost sends your books after each logout or /reload.",
    expired: "This code has expired or was already used: start again from Ravenpost.",
  },
  library: {
    title: "Library",
    testIntro: "The test account: lives played through the addon in its test game, each book exactly as the addon saved it at logout.",
    empty: "No book on this shelf yet. With the addon installed, your characters' books arrive after you log out or /reload.",
    level: (n: number) => `Level ${n}`,
    chapters: (n: number) => (n === 1 ? "1 chapter" : `${n} chapters`),
    hardcore: "Hardcore",
    fallen: "Fallen",
  },
  book: {
    contents: "Contents",
    prologue: "Prologue",
    chapter: (n: number) => `Chapter ${n}`,
    epitaph: "Epitaph",
    stillWriting: "still being written",
    theEnd: "the end",
    levels: (a: number, b: number) => (a === b ? `level ${a}` : `levels ${a} to ${b}`),
    closeCall: "a close call",
    rare: "a rare foe slain",
    nothingYet: "Nothing written yet.",
    previous: "Previous",
    next: "Next",
    close: "Close",
    written: (date: string, version?: string) => `Written ${date}${version ? ` by Hearthtale ${version}` : ""}`,
    notFound: "This book isn't here.",
  },
  races: {
    Human: "Human", Dwarf: "Dwarf", NightElf: "Night Elf", Gnome: "Gnome", Draenei: "Draenei", Orc: "Orc", Troll: "Troll",
    Tauren: "Tauren", Scourge: "Undead", BloodElf: "Blood Elf", Skyborne: "Skyborne",
  } as Record<string, string>,
  classes: {
    WARRIOR: "Warrior", PALADIN: "Paladin", HUNTER: "Hunter", ROGUE: "Rogue", PRIEST: "Priest", SHAMAN: "Shaman",
    MAGE: "Mage", WARLOCK: "Warlock", DRUID: "Druid",
  } as Record<string, string>,
  regions: { 1: "US", 2: "KR", 3: "EU", 4: "TW", 5: "CN" } as Record<number, string>,
  /** "Dwarf Hunter" (French: "Chasseur nain"). */
  raceClass: (race: string, cls: string) => `${race} ${cls}`,
  share: {
    title: "Share",
    why: "Anyone with the link reads what it covers, and nothing else of yours. You can revoke it at any time.",
    thisPart: (part: string) => `Share ${part.toLowerCase()}`,
    wholeBook: "The whole book",
    copy: "Copy the link",
    send: "Send",
    made: "Your links",
    revoke: "Revoke",
    revokeHint: "A revoked link stops working at once.",
    hall: "Show this book in the Hall of the Fallen",
    hallWhy: "The public Hall, on hearthtale.app: anyone can read this fallen life's book there. You can take it back out.",
    gone: "This link doesn't lead to a book any more: it was revoked, or the book is gone.",
  },
  hall: {
    title: "Hall of the Fallen",
    intro: "Hardcore lives, ended, whose players chose to show them here: each with its epitaph, and its book to read.",
    empty: "No fallen book has been brought to the Hall yet.",
  },
  settings: {
    title: "Settings",
    reading: "Reading",
    preview:
      "I reached Kharanos, took a room at Thunderbrew Distillery, then took up skinning. Later that day, I walked into Shimmer Ridge and dealt with a Frostmane Snowstrider.",
    size: "Text size",
    font: "Typeface",
    fonts: { serif: "Book", sans: "Plain" } as Record<string, string>,
    paper: "Paper",
    themes: { parchment: "Parchment", sepia: "Sepia", night: "Night" } as Record<string, string>,
    spacing: "Line spacing",
    spacings: { tight: "Tight", normal: "Normal", airy: "Airy" } as Record<string, string>,
    language: "Language",
    languageHint: "The site's language (the books are written in English).",
    account: "Account",
    signedInAs: (who: string) => `Signed in as ${who}.`,
    about: "About",
    version: (v: string, commit: string, date: string) => `Hearthtale ${v} (site ${commit}, ${date}).`,
  },
  update: { available: "A new version of Hearthtale is ready.", reload: "Reload", close: "Close" },
  footer: { source: "Source code", notAffiliated: "Not affiliated with Blizzard Entertainment." },
};

export type Strings = typeof en;

/** The languages, with the locale their dates and times are written in. */
export const CATALOGS = { en: { strings: en, locale: "en-GB", name: "English" } } satisfies Record<string, { strings: Strings; locale: string; name: string }>;
export type Lang = keyof typeof CATALOGS;
export const LANGS = Object.keys(CATALOGS) as Lang[];
export const DEFAULT_LANG: Lang = "en";

export function isLang(v: unknown): v is Lang {
  return typeof v === "string" && v in CATALOGS;
}

export function strings(lang: Lang): Strings {
  return CATALOGS[lang].strings;
}

/** The chosen language, if it has a catalog (else English). */
export function useLang(): Lang {
  const lang = useSettings().lang;
  return isLang(lang) ? lang : DEFAULT_LANG;
}

/** The page's strings, in the chosen language. */
export function useT(): Strings {
  return strings(useLang());
}

/** The chosen language's locale, for dates and times. */
export function useLocale(): string {
  return CATALOGS[useLang()].locale;
}
