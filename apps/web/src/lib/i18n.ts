import { useSettings, type Lang } from "@/lib/settings";

/** Every visible string. `fr` is typed on the exact shape of `en`. */
const en = {
  nav: { home: "Hearthtale", library: "Library", skip: "Skip to content", language: "Language" },
  home: {
    tagline: "Your character's own journal, written as you play.",
    intro:
      "Hearthtale is a World of Warcraft addon. Every quest, every new foe, every place, every close call is written down as it happens, in your character's own voice, and a chapter closes when you rest at an inn or by a campfire. On Hardcore, a death closes the book with an epitaph.",
    soon: "Soon on this site: your journal, to read on your phone and to share.",
    games: "Classic Era, Hardcore, Season of Discovery, TBC Anniversary and World of Warcraft: Forever.",
    download: "Download the addon",
  },
  notFound: { title: "Lost in the mist", body: "There is no page here.", back: "Back to the hearth" },
  common: { loading: "Turning the pages…", loadError: "This page couldn't be loaded. Check your connection, then try again.", retry: "Try again" },
  library: {
    title: "Library",
    intro: "Test characters for now: three lives played through the addon in its test game, each book exactly as the addon saved it at logout.",
    empty: "No book on this shelf yet.",
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
  update: { available: "A new version of Hearthtale is ready.", reload: "Reload", close: "Close" },
  footer: { source: "Source code", notAffiliated: "Not affiliated with Blizzard Entertainment." },
};

const fr: typeof en = {
  nav: { home: "Hearthtale", library: "Bibliothèque", skip: "Aller au contenu", language: "Langue" },
  home: {
    tagline: "Le journal de votre personnage, écrit pendant que vous jouez.",
    intro:
      "Hearthtale est un addon pour World of Warcraft. Chaque quête, chaque nouvel ennemi, chaque lieu, chaque mort évitée de justesse est écrit au moment où il arrive, avec la voix de votre personnage, et un chapitre se clôt quand vous vous reposez dans une auberge ou au coin d'un feu de camp. En Hardcore, la mort referme le livre sur une épitaphe.",
    soon: "Bientôt sur ce site : votre journal, à lire sur votre téléphone et à partager.",
    games: "Classic Era, Hardcore, Season of Discovery, TBC Anniversary et World of Warcraft: Forever.",
    download: "Télécharger l'addon",
  },
  notFound: { title: "Perdu dans la brume", body: "Il n'y a pas de page ici.", back: "Retour au coin du feu" },
  common: { loading: "On tourne les pages…", loadError: "Cette page n'a pas pu être chargée. Vérifiez votre connexion, puis réessayez.", retry: "Réessayer" },
  library: {
    title: "Bibliothèque",
    intro: "Des personnages de test pour l'instant : trois vies jouées par l'addon dans son jeu de test, chaque livre tel que l'addon l'a enregistré à la déconnexion. Les livres sont écrits en anglais.",
    empty: "Aucun livre sur cette étagère pour l'instant.",
    level: (n: number) => `Niveau ${n}`,
    chapters: (n: number) => (n === 1 ? "1 chapitre" : `${n} chapitres`),
    hardcore: "Hardcore",
    fallen: "Livre refermé",
  },
  book: {
    contents: "Sommaire",
    prologue: "Prologue",
    chapter: (n: number) => `Chapitre ${n}`,
    epitaph: "Épitaphe",
    stillWriting: "en cours d'écriture",
    theEnd: "fin",
    levels: (a: number, b: number) => (a === b ? `niveau ${a}` : `niveaux ${a} à ${b}`),
    closeCall: "une mort évitée de justesse",
    rare: "un ennemi rare vaincu",
    nothingYet: "Rien d'écrit pour l'instant.",
    previous: "Précédent",
    next: "Suivant",
    close: "Fermer",
    written: (date: string, version?: string) => `Écrit le ${date}${version ? ` par Hearthtale ${version}` : ""}`,
    notFound: "Ce livre n'est pas ici.",
  },
  races: {
    Human: "Humain", Dwarf: "Nain", NightElf: "Elfe de la nuit", Gnome: "Gnome", Draenei: "Draeneï", Orc: "Orc", Troll: "Troll",
    Tauren: "Tauren", Scourge: "Mort-vivant", BloodElf: "Elfe de sang", Skyborne: "Skyborne",
  },
  classes: {
    WARRIOR: "Guerrier", PALADIN: "Paladin", HUNTER: "Chasseur", ROGUE: "Voleur", PRIEST: "Prêtre", SHAMAN: "Chaman",
    MAGE: "Mage", WARLOCK: "Démoniste", DRUID: "Druide",
  },
  regions: { 1: "US", 2: "KR", 3: "EU", 4: "TW", 5: "CN" },
  raceClass: (race: string, cls: string) => `${cls} ${race.toLowerCase()}`,
  update: { available: "Une nouvelle version de Hearthtale est prête.", reload: "Recharger", close: "Fermer" },
  footer: { source: "Code source", notAffiliated: "Sans lien avec Blizzard Entertainment." },
};

const STRINGS: Record<Lang, typeof en> = { en, fr };
export type Strings = typeof en;

export function strings(lang: Lang): Strings {
  return STRINGS[lang];
}

export function useT(): Strings {
  return STRINGS[useSettings().lang];
}
