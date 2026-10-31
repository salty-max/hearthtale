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
      "Hearthtale is a World of Warcraft addon: your character's own journal, written as you play. Each time you rest at an inn or by a campfire, the stretch becomes an entry in your character's own voice. On Hardcore, a death closes the book with an epitaph.",
    soon: "Your journal, read in the game or here, on your phone: install the addon and Ravenpost, then sign in.",
    start: "Get started",
    sample: "Read a page",
    hall: "Hall of the Fallen",
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
    signInWhy: "Sign in with Battle.net: your Classic Era characters are found automatically, and only you can read their books.",
    perks: ["Every character's journal, on your phone", "New entries after each logout", "Share an entry, or the whole book"],
    region: "Region",
    regions: { us: "Americas & Oceania", eu: "Europe", kr: "Korea", tw: "Taiwan" } as Record<string, string>,
    forever: "World of Warcraft: Forever characters are linked with a code typed in the game, from \"Link a character\" at the top of the page.",
    failed: "The sign-in with Battle.net failed. Try again in a moment.",
    cancelled: "Sign-in cancelled.",
    busy: "Too many sign-ins from here just now. Wait a few minutes, then try again.",
    signOut: "Sign out",
    you: "You",
    testAccount: "Use the test account (development only)",
  },
  link: {
    title: "Link a character",
    short: "Link",
    why: "For a character Battle.net can't find (World of Warcraft: Forever): a code typed in the game brings its book to your library at its next upload.",
    get: "Get a code",
    type: "In the game, type:",
    copy: "Copy",
    copied: "Copied",
    again: "New code",
    then: (until: string) => `Then log out or /reload. The code works once, until ${until}.`,
  },
  start: {
    title: "Get started",
    intro: "The addon writes your character's journal as you play. Read it in the game with /ht. To read it here too, Ravenpost, a small app on your computer, sends each book to your library after you log out.",
    addonTitle: "1. The addon",
    addon: "Install it with your addon manager, or unzip it into the game's Interface/AddOns folder. One package for every game: each loads its own part.",
    managers: "With an addon manager",
    zip: "Or the zip",
    download: "Hearthtale",
    downloadDetail: "Classic Era, Hardcore, Season of Discovery, World of Warcraft: Forever",
    ravenpostTitle: "2. Ravenpost",
    ravenpost: "The companion app that carries your books here (and WoWLocker's data, if you use it). It keeps working from the tray or the menu bar.",
    windows: "Windows",
    windowsDetail: "Windows 10 or 11",
    macos: "macOS",
    macosDetail: "macOS 11 or later: move it to Applications",
    yours: "For your computer",
    windowsArm: "Windows on ARM",
    unsigned:
      "Not code-signed yet: Windows and macOS warn the first time you open it (Windows: More info, then Run anyway). If Smart App Control on Windows 11 blocks it, turn that off in Windows Security, or ask for help on the project's GitHub.",
    uploadInstead: "Rather not install Ravenpost? Upload your saved file from the library instead.",
    stepsTitle: "3. Sign in",
    steps: [
      "Open Ravenpost and click Sign in with Battle.net.",
      "Your browser opens on Battle.net. Once you're signed in, Ravenpost is linked to Hearthtale: there's nothing else to confirm.",
      "Play, then log out or type /reload. A few seconds later, your book is in your library.",
    ],
    foreverLink: "For World of Warcraft: Forever characters, and any Battle.net can't find, get a link code from \"Link a character\" at the top of the page while signed in. Then type /ht link CODE in the game before you log out.",
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
    testIntro: "The test account: books the addon saved in a test game, exactly as written at logout.",
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
    closeCall: "Close call",
    rare: "Rare foe slain",
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
      "Forever: the same, in _forever_ instead of _classic_era_.",
    ],
    drop: "Drop Hearthtale.lua here",
    choose: "Choose the file",
    reading: "Reading the file…",
    found: (name: string, n: number) => `${name}'s book: ${n === 1 ? "1 entry" : `${n} entries`}.`,
    send: "Add it to my library",
    sending: "Sending…",
    saved: "In your library.",
    open: "Open the book",
    unlinked: "This character isn't linked to your account yet. Get a link code from \"Link a character\" at the top of the page, type /ht link CODE in the game, log out, then upload the file again.",
    invalid: "This file holds no book the site can read.",
    owned: "Another account already holds this character, so a link code can't move it. If it is yours, sign in with that account, or ask for help on the project's GitHub.",
    removed: "You removed this book from the site: a new link code brings it back.",
    notLua: "This isn't a Hearthtale saved file (Hearthtale.lua).",
    noBook: "No character's book in this file yet: play, log out, then try again.",
    tooBig: "This file is too big to be a Hearthtale saved file.",
    failed: "The upload failed. Check your connection, then try again.",
  },
  push: {
    title: "Notifications",
    why: "A notification on this device when one of your characters has a new entry (after you log out).",
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
    why: "Anyone with the link can read what it covers, and nothing else of yours: your notes in the margins stay yours. You can revoke it at any time.",
    thisPart: (part: string) => `Share “${part}”`,
    wholeBook: "The whole book",
    copy: "Copy the link",
    copied: "Copied",
    send: "Send",
    made: "Your links",
    revoke: "Revoke",
    revokeHint: "A revoked link stops working at once.",
    hall: "Show this book in the Hall of the Fallen",
    hallWhy: "The public Hall, on hearthtale.app: anyone can read this fallen life's book there, without your notes. You can take it back out.",
    gone: "This link doesn't lead to a book any more: it was revoked, or the book is gone.",
    visitor: (name: string) => `${name}'s journal, written by Hearthtale as they played World of Warcraft.`,
    keepYours: "Start your own",
  },
  remove: {
    title: "Remove this book",
    why: (name: string) =>
      `${name}'s book leaves hearthtale.app, with every link you shared of it. The journal itself stays in the game.`,
    companion:
      "Ravenpost won't bring it back: its uploads of this character are refused from now on. To bring the book back, get a link code from \"Link a character\" at the top of the page and type /ht link CODE in the game.",
    confirm: "Remove the book",
    cancel: "Keep it",
    failed: "The book couldn't be removed. Check your connection, then try again.",
  },
  hall: {
    title: "Hall of the Fallen",
    intro: "Hardcore lives that have ended, shown here because their players chose to. Each has its epitaph and its book to read.",
    empty: "No fallen book has been brought to the Hall yet.",
    read: "Read the book",
  },
  settings: {
    title: "Settings",
    appearance: "Appearance",
    site: "The site",
    sites: { system: "Same as device", light: "Light", dark: "Dark" } as Record<string, string>,
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
    updated: "Last updated 15 October 2026.",
    sections: [
      {
        title: "What the site keeps",
        text: "The site keeps your Battle.net account's id and BattleTag, to know which books are yours, and the characters the game says are yours (their name, realm, race, class and level). It also keeps each book as the addon wrote it, with your own titles and notes, and the share links you make. If you turn notifications on, it keeps this device's notification address too.",
      },
      {
        title: "What it never keeps",
        text: "Your Battle.net password or access token, your email, your position, what you carry or your gold: the addon's raw record stays on your computer, and Ravenpost sends only the book.",
      },
      {
        title: "Who reads your books",
        text: "You alone, unless you share a link (anyone with it can read what it covers) or show a fallen book in the Hall (anyone can read it there). Your notes in the margins stay yours either way. Revoke a link, or take a book out of the Hall, at any time.",
      },
      {
        title: "Cookies",
        text: "One, to keep you signed in. No advertising and no tracking: visits are counted without cookies (Vercel Web Analytics: the page, the country, the kind of device, never who you are). Your reading settings stay in this browser.",
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
