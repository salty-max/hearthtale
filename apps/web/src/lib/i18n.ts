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
    testIntro: "The test account: three lives played through the addon in its test game, each book exactly as the addon saved it at logout.",
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
  account: {
    signIn: "Se connecter avec Battle.net",
    signInShort: "Connexion",
    signInTitle: "Vos livres",
    signInWhy: "Connectez-vous avec Battle.net : vos personnages de Classic Era et de TBC Anniversary sont retrouvés tout seuls, et leurs livres ne sont qu'à vous.",
    region: "Région",
    regions: { us: "Amériques", eu: "Europe", kr: "Corée", tw: "Taïwan" },
    forever: "Les personnages de World of Warcraft: Forever se lient depuis la bibliothèque, avec un code tapé en jeu.",
    failed: "Battle.net ne nous a pas laissés entrer. Réessayez dans un instant.",
    cancelled: "Connexion annulée.",
    signOut: "Se déconnecter",
    you: "Vous",
    testAccount: "Utiliser le compte de test (développement uniquement)",
  },
  link: {
    title: "Lier un personnage",
    why: "Pour un personnage que Battle.net ne trouve pas (World of Warcraft: Forever) : obtenez un code, tapez-le en jeu, et son livre rejoint votre bibliothèque à son prochain envoi.",
    get: "Obtenir un code",
    type: "En jeu, tapez :",
    copy: "Copier",
    then: (until: string) => `Puis déconnectez-vous ou faites /reload. Le code est valable jusqu'à ${until}, une fois.`,
  },
  pair: {
    title: "Lier cet ordinateur",
    ask: (who: string) => `Ravenpost, sur cet ordinateur, demande à envoyer les livres de vos personnages dans la bibliothèque de ${who}. Le code qu'il affiche :`,
    check: "Vérifiez qu'il est le même que dans Ravenpost.",
    confirm: "Lier cet ordinateur",
    done: "C'est lié. Ravenpost envoie vos livres après chaque déconnexion ou /reload.",
    expired: "Ce code a expiré ou a déjà servi : recommencez depuis Ravenpost.",
  },
  library: {
    title: "Bibliothèque",
    testIntro: "Le compte de test : trois vies jouées par l'addon dans son jeu de test, chaque livre tel que l'addon l'a enregistré à la déconnexion. Les livres sont écrits en anglais.",
    empty: "Aucun livre sur cette étagère pour l'instant. Avec l'addon installé, les livres de vos personnages arrivent après une déconnexion ou un /reload.",
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
