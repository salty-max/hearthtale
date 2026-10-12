import { useSettings } from "@/lib/settings";

/**
 * Every visible string, per language. English only for now (the books are
 * written in English); another language is one more catalog of the same shape
 * (`typeof en`, so a missing or extra key fails to compile) in CATALOGS, and
 * the language setting appears on its own once there are two.
 */
const en = {
  nav: {
    home: "Hearthtale",
    start: "Get started",
    library: "Library",
    settings: "Settings",
    hall: "Hall",
    menu: "Menu",
    skip: "Skip to content",
    language: "Language",
    back: "Library",
    theme: (now: string, next: string) => `Theme: ${now}. Switch to ${next}.`,
  },
  footer: {
    source: "Source code",
    privacy: "Privacy",
    support: "Support Hearthtale",
    notAffiliated: "Not affiliated with Blizzard Entertainment.",
    made: "Made by a player, for players.",
  },
  home: {
    tagline: "Your character's own journal, written as you play.",
    intro:
      "Hearthtale is a World of Warcraft addon: your character's own journal, written as you play. Each time you rest at an inn or by a campfire, the stretch becomes a diary entry in your character's own voice. On Hardcore, a death closes the book with an epitaph.",
    soon: "Your journal, read in the game or here, on your phone: install the addon and Ravenpost, then sign in.",
    start: "Get started",
    sample: "Read a page",
    hall: "The Hall of the Fallen",
    games: "Classic Era, Hardcore, Season of Discovery and World of Warcraft: Forever.",
    features: [
      { title: "Written as you play", text: "Quests, foes, friends, close calls and campfires become entries at each rest, from what really happened." },
      { title: "In your character's voice", text: "A dwarf writes like a dwarf, a Forsaken like a Forsaken: every race and class has words of its own." },
      { title: "A life worth keeping", text: "Read it on your phone, share an entry, and on Hardcore, the last page and an epitaph in the Hall." },
    ],
    samplesTitle: "A page from the journals",
    samplesWhy: "Written by the addon itself, from test characters' first evenings: each in its own voice, and the last words of one who fell on Hardcore.",
  },
  notFound: { title: "Lost in the mist", body: "There is no page here.", back: "Back to the hearth" },
  common: {
    loading: "Turning the pages…",
    loadError: "This page couldn't be loaded. Check your connection, then try again.",
    retry: "Try again",
    close: "Close",
  },
  account: {
    signIn: "Sign in with Battle.net",
    signInShort: "Sign in",
    signInTitle: "Your books",
    signInWhy: "Sign in with Battle.net: your Classic Era characters are found on their own, and their books are yours alone.",
    perks: ["Every character's journal, on your phone", "New entries after each logout", "Share an entry, or the whole book"],
    region: "Region",
    regions: { us: "Americas & Oceania", eu: "Europe", kr: "Korea", tw: "Taiwan" } as Record<string, string>,
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
    again: "Get a new code",
    then: (until: string) => `Then log out or /reload. The code works until ${until}, once.`,
  },
  start: {
    title: "Get started",
    intro: "The addon writes your character's journal as you play; read it in the game with /ht. To read it here too, Ravenpost, a small app on your computer, sends each book to your library after you log out.",
    addonTitle: "1. The addon",
    addon: "Install it with your addon manager, or unzip it into the game's Interface/AddOns folder. One package for every game: each loads its own part.",
    managers: "With an addon manager",
    zip: "Or the zip",
    download: "Hearthtale",
    downloadDetail: "Classic Era, Hardcore, Season of Discovery, World of Warcraft: Forever",
    ravenpostTitle: "2. Ravenpost",
    ravenpost: "The companion app that carries your books here (and WoWLocker's data, if you use it). It lives in the tray or the menu bar.",
    windows: "Windows",
    windowsDetail: "Windows 10 or 11",
    macos: "macOS",
    macosDetail: "macOS 11 or later: move it to Applications",
    yours: "For your computer",
    windowsArm: "Windows on ARM",
    unsigned: "Not code-signed yet: Windows and macOS warn the first time you open it.",
    uploadInstead: "Rather not install Ravenpost? Upload your saved file from the library instead.",
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
    chapters: (n: number) => (n === 1 ? "1 entry" : `${n} entries`),
    hardcore: "Hardcore",
    fallen: "Fallen",
    hardcoreWhy: "One life, one book: a death closes it with an epitaph, and it may join the Hall of the Fallen.",
    fallenWhy: "This life has ended: its book is closed, with its epitaph.",
    forever: "Forever",
    new: "New",
    latest: "Latest",
    updated: (when: string) => `Updated ${when}`,
    road: "The road so far",
    upload: "Upload a saved file",
  },
  book: {
    contents: "Contents",
    prologue: "Prologue",
    chapter: (n: number) => `Entry ${n}`,
    epitaph: "Epitaph",
    stillWriting: "still being written",
    theEnd: "the end",
    levels: (a: number, b: number) => (a === b ? `level ${a}` : `levels ${a} to ${b}`),
    closeCall: "a close call",
    rare: "a rare foe slain",
    nothingYet: "Nothing written yet.",
    note: "A note in the margin",
    previous: "Previous",
    next: "Next",
    close: "Close",
    of: (i: number, n: number) => `${i} of ${n}`,
    more: "More",
    share: "Share",
    download: "Download",
    road: "The road so far",
    remove: "Remove from the site",
    keys: "Use ← and → to turn the pages.",
    to: "to",
    written: (date: string, version?: string) => `Written ${date}${version ? ` by Hearthtale ${version}` : ""}`,
    notFound: "This book isn't here.",
  },
  exports: {
    title: "Download the book",
    why: "The whole book, to keep: every entry as it reads here, with your notes.",
    pdf: "Print, or save as PDF",
    pdfHint: "Your browser's print window: choose “Save as PDF”.",
    epub: "EPUB",
    epubHint: "For e-readers and Apple Books.",
    markdown: "Text",
    markdownHint: "Plain text (Markdown), for anywhere.",
    by: (name: string) => `The journal of ${name}`,
  },
  road: {
    title: "The road so far",
    entries: "entries",
    levels: "levels",
    days: "days",
    places: "places",
    closeCalls: "close calls",
    rares: "rare foes",
    chart: "Levels over the days",
    timeline: "Entry by entry",
    places_: "Where the road went",
    empty: "The road starts with the first entry.",
    read: "Read",
    day: (n: number) => (n === 1 ? "1 day" : `${n} days`),
  },
  upload: {
    title: "Upload a saved file",
    intro: "No Ravenpost? Bring a character's book yourself: the addon saves it in the game's folder when you log out.",
    where: "Where it is:",
    paths: [
      "Windows: World of Warcraft\\_classic_era_\\WTF\\Account\\ACCOUNT\\REALM\\CHARACTER\\SavedVariables\\Hearthtale.lua",
      "macOS: World of Warcraft/_classic_era_/WTF/Account/ACCOUNT/REALM/CHARACTER/SavedVariables/Hearthtale.lua",
      "Forever: the same, in _classic_beta_ (or the game's own folder).",
    ],
    drop: "Drop Hearthtale.lua here",
    choose: "Choose the file",
    reading: "Reading the file…",
    found: (name: string, n: number) => `${name}'s book: ${n === 1 ? "1 entry" : `${n} entries`}.`,
    send: "Add it to my library",
    sending: "Sending…",
    saved: "In your library.",
    open: "Open the book",
    unlinked: "This character isn't yours yet: get a link code in the library, type /ht link CODE in the game, log out, then upload the file again.",
    invalid: "This file holds no book the site can read.",
    removed: "You removed this book from the site: a new link code brings it back.",
    notLua: "This isn't a Hearthtale saved file (Hearthtale.lua).",
    noBook: "No character's book in this file yet: play, log out, then try again.",
    tooBig: "This file is too big to be a Hearthtale saved file.",
    failed: "The upload failed. Check your connection, then try again.",
  },
  push: {
    title: "Notifications",
    why: "A word on this device when one of your characters writes a new entry (after you log out).",
    on: "Tell me when a new entry arrives",
    unsupported: "This browser can't receive notifications from the site.",
    ios: "On iPhone and iPad: add Hearthtale to your Home Screen (Share, then Add to Home Screen), open it from there, then turn this on.",
    denied: "Notifications are blocked for this site in your browser's settings.",
    signIn: "Sign in to be told of new entries.",
    failed: "That didn't work. Try again in a moment.",
  },
  races: {
    Human: "Human",
    Dwarf: "Dwarf",
    NightElf: "Night Elf",
    Gnome: "Gnome",
    Orc: "Orc",
    Troll: "Troll",
    Tauren: "Tauren",
    Scourge: "Undead",
    Skyborne: "Skyborne",
  } as Record<string, string>,
  classes: {
    WARRIOR: "Warrior",
    PALADIN: "Paladin",
    HUNTER: "Hunter",
    ROGUE: "Rogue",
    PRIEST: "Priest",
    SHAMAN: "Shaman",
    MAGE: "Mage",
    WARLOCK: "Warlock",
    DRUID: "Druid",
  } as Record<string, string>,
  regions: { 1: "US", 2: "KR", 3: "EU", 4: "TW", 5: "CN" } as Record<number, string>,
  /** "Dwarf Hunter" (French: "Chasseur nain"). */
  raceClass: (race: string, cls: string) => `${race} ${cls}`,
  share: {
    title: "Share",
    why: "Anyone with the link reads what it covers, and nothing else of yours. You can revoke it at any time.",
    thisPart: (part: string) => `Share “${part}”`,
    wholeBook: "The whole book",
    copy: "Copy the link",
    copied: "Copied",
    send: "Send",
    made: "Your links",
    revoke: "Revoke",
    revokeHint: "A revoked link stops working at once.",
    hall: "Show this book in the Hall of the Fallen",
    hallWhy: "The public Hall, on hearthtale.app: anyone can read this fallen life's book there. You can take it back out.",
    gone: "This link doesn't lead to a book any more: it was revoked, or the book is gone.",
    visitor: (name: string) => `${name}'s journal, written by Hearthtale as they played World of Warcraft.`,
    keepYours: "Keep your own",
  },
  remove: {
    title: "Remove this book",
    why: (name: string) =>
      `${name}'s book leaves hearthtale.app, with every link you shared of it. The journal itself stays in the game.`,
    companion:
      "Ravenpost won't bring it back: its uploads of this character are refused from now on. To have the book here again, get a link code in your library and type /ht link CODE in the game.",
    confirm: "Remove the book",
    cancel: "Keep it",
    failed: "The book couldn't be removed. Check your connection, then try again.",
  },
  hall: {
    title: "Hall of the Fallen",
    intro: "Hardcore lives, ended, whose players chose to show them here: each with its epitaph, and its book to read.",
    empty: "No fallen book has been brought to the Hall yet.",
    read: "Read the book",
  },
  settings: {
    title: "Settings",
    appearance: "Appearance",
    site: "The site",
    sites: { system: "As the device", light: "Day", dark: "Night" } as Record<string, string>,
    reading: "Reading",
    preview:
      "I reached Kharanos, took a room at Thunderbrew Distillery, then took up skinning. Later that day, I walked into Shimmer Ridge and dealt with a Frostmane Snowstrider.",
    size: "Text size",
    font: "Typeface",
    fonts: { book: "Book", plain: "Plain" } as Record<string, string>,
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
  privacy: {
    title: "Privacy",
    updated: "Last updated 12 October 2026.",
    sections: [
      {
        title: "What the site keeps",
        text: "Your Battle.net account's id and BattleTag, to know which books are yours; the characters the game says are yours (their name, realm, race, class and level); each book as the addon wrote it, with your own titles and notes; the share links you make; and, if you turn them on, this device's notification address.",
      },
      {
        title: "What it never keeps",
        text: "Your Battle.net password or access token, your email, your position, what you carry or your gold: the addon's raw record stays on your computer, and Ravenpost sends only the book.",
      },
      {
        title: "Who reads your books",
        text: "You alone, unless you share a link (anyone with it reads what it covers) or show a fallen book in the Hall (anyone can read it there). Revoke a link, or take a book out of the Hall, at any time.",
      },
      {
        title: "Cookies",
        text: "One, to keep you signed in. No advertising, no tracking, no analytics. Your reading settings stay in this browser.",
      },
      {
        title: "Leaving",
        text: "Remove a book from the site in its reader (More, then Remove from the site): it goes at once, with its links. To have everything removed, open an issue on the project's GitHub page.",
      },
    ],
  },
  update: { available: "A new version of Hearthtale is ready.", reload: "Reload", close: "Close" },
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
