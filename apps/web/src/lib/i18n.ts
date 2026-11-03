import { frameFor, type Frame, type Language } from "@hearthtale/shared";
import { useSettings } from "@/lib/settings";

/**
 * Every visible string, per language: one catalog of the same shape each
 * (`typeof en`, so a missing or extra key fails to compile) in CATALOGS. The
 * interface's language only: each book keeps its own (its frame,
 * packages/shared/src/frame.ts).
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
    inFrench: "in French",
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
    closeCall: "Close call",
    rare: "Rare foe slain",
    nothingYet: "Nothing written yet.",
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
  },
  road: {
    title: "The road so far",
    // (the figures' labels, by their number)
    entries: (n: number): string => (n === 1 ? "entry" : "entries"),
    levels: (n: number): string => (n === 1 ? "level" : "levels"),
    days: (n: number): string => (n === 1 ? "day" : "days"),
    places: (n: number): string => (n === 1 ? "place" : "places"),
    closeCalls: (n: number): string => (n === 1 ? "close call" : "close calls"),
    rares: (n: number): string => (n === 1 ? "rare foe" : "rare foes"),
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
    languageHint: "The site's language. Each book keeps the language it was written in.",
    account: "Account",
    signedInAs: (who: string) => `Signed in as ${who}.`,
    about: "About",
    version: (v: string, commit: string, date: string) => `Hearthtale ${v} (site ${commit}, ${date}).`,
  },
  privacy: {
    title: "Privacy",
    updated: "Last updated 3 November 2026.",
    sections: [
      {
        title: "What the site keeps",
        text: "The site keeps your Battle.net account's id and BattleTag, to know which books are yours, and the characters the game says are yours (their name, realm, race, class, sex and level). It also keeps each book as the addon wrote it, with your own titles and notes, and the share links you make. If you turn notifications on, it keeps this device's notification address too.",
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

/**
 * French: vous, nothing agreeing with the reader, a no-break space (\u00a0)
 * before : ? ! and inside « », the addon's own terms (Salle des Défunts,
 * Extrême, réglages, code de liaison) and the game's names.
 */
const fr: Strings = {
  nav: {
    home: "Hearthtale",
    start: "Commencer",
    library: "Bibliothèque",
    settings: "Réglages",
    hall: "Salle",
    menu: "Menu",
    skip: "Aller au contenu",
    language: "Langue",
    back: "Bibliothèque",
    theme: (now: string, next: string) => `Thème\u00a0: ${now}. Passer à ${next}.`,
  },
  footer: {
    source: "Code source",
    privacy: "Confidentialité",
    support: "Soutenir Hearthtale",
    notAffiliated: "Sans lien avec Blizzard Entertainment.",
    made: "Fait par et pour les joueurs.",
  },
  home: {
    tagline: "Le journal de votre personnage, écrit pendant que vous jouez.",
    intro:
      "Hearthtale est un addon pour World of Warcraft\u00a0: le journal de votre personnage, écrit pendant que vous jouez. Chaque fois que vous vous reposez dans une auberge ou près d'un feu de camp, la route depuis votre dernière halte devient une entrée, écrite par votre personnage lui-même. En mode Extrême, une mort clôt le livre sur une épitaphe.",
    soon: "Votre journal, à lire dans le jeu ou ici, sur votre téléphone\u00a0: installez l'addon et Ravenpost, puis connectez-vous.",
    start: "Commencer",
    sample: "Lire une page",
    hall: "Salle des Défunts",
    games: "Classic Era, le mode Extrême, la Saison de la découverte et World of Warcraft: Forever.",
    features: [
      { title: "Écrit pendant que vous jouez", text: "Quêtes, ennemis, amis, morts frôlées et feux de camp deviennent des entrées à chaque halte, d'après ce qui s'est vraiment passé." },
      { title: "De la voix de votre personnage", text: "Un nain écrit comme un nain, un Réprouvé comme un Réprouvé\u00a0: chaque race et chaque classe a ses propres mots." },
      { title: "Une vie à garder", text: "Lisez votre journal sur votre téléphone, partagez une entrée. En mode Extrême, la dernière page et l'épitaphe trouvent leur place dans la Salle." },
    ],
    samplesTitle: "Une page de chaque journal",
    samplesWhy: "Pages écrites par l'addon lui-même, d'après les premières soirées de personnages de test\u00a0: chacune avec sa propre voix, et les derniers mots d'un personnage tombé en mode Extrême.",
    inFrench: "en français",
  },
  notFound: { title: "Rien que la brume", body: "Il n'y a pas de page ici.", back: "Retour au foyer" },
  common: {
    loading: "Les pages se tournent…",
    loadError: "Cette page n'a pas pu être chargée. Vérifiez votre connexion, puis réessayez.",
    retry: "Réessayer",
    close: "Fermer",
  },
  account: {
    signIn: "Se connecter avec Battle.net",
    signInShort: "Connexion",
    signInTitle: "Vos livres",
    signInWhy: "Connectez-vous avec Battle.net\u00a0: vos personnages de Classic Era sont trouvés automatiquement, et personne d'autre que vous ne peut lire leurs livres.",
    perks: ["Le journal de chaque personnage, sur votre téléphone", "De nouvelles entrées après chaque déconnexion", "Le partage d'une entrée, ou du livre entier"],
    region: "Région",
    regions: { us: "Amériques et Océanie", eu: "Europe", kr: "Corée", tw: "Taïwan" } as Record<string, string>,
    forever: "Les personnages de World of Warcraft: Forever se relient avec un code tapé dans le jeu, depuis «\u00a0Relier un personnage\u00a0» en haut de la page.",
    failed: "La connexion avec Battle.net a échoué. Réessayez dans un instant.",
    cancelled: "Connexion annulée.",
    busy: "Trop de tentatives de connexion depuis cette adresse. Attendez quelques minutes, puis réessayez.",
    signOut: "Se déconnecter",
    you: "Vous",
    testAccount: "Utiliser le compte de test (développement uniquement)",
  },
  link: {
    title: "Relier un personnage",
    short: "Relier",
    why: "Pour un personnage que Battle.net ne trouve pas (World of Warcraft: Forever)\u00a0: un code tapé dans le jeu ajoute son livre à votre bibliothèque au prochain envoi.",
    get: "Obtenir un code",
    type: "Dans le jeu, tapez\u00a0:",
    copy: "Copier",
    copied: "Copié",
    again: "Nouveau code",
    then: (until: string) => `Déconnectez-vous ensuite ou tapez /reload. Le code est valable jusqu'à ${until} et ne sert qu'une fois.`,
  },
  start: {
    title: "Commencer",
    intro: "L'addon écrit le journal de votre personnage pendant que vous jouez. Lisez-le dans le jeu avec /ht. Pour le lire ici aussi, Ravenpost, une petite application sur votre ordinateur, envoie chaque livre dans votre bibliothèque après votre déconnexion.",
    addonTitle: "1. L'addon",
    addon: "Installez-le avec votre gestionnaire d'addons, ou décompressez-le dans le dossier Interface/AddOns du jeu. Un seul téléchargement pour tous les jeux\u00a0: chacun charge sa propre partie.",
    managers: "Avec un gestionnaire d'addons",
    zip: "Ou le zip",
    download: "Hearthtale",
    downloadDetail: "Classic Era, mode Extrême, Saison de la découverte, World of Warcraft: Forever",
    ravenpostTitle: "2. Ravenpost",
    ravenpost: "L'application compagnon qui apporte vos livres ici (et les données de WoWLocker, si vous l'utilisez). Elle reste active dans la zone de notification ou la barre des menus.",
    windows: "Windows",
    windowsDetail: "Windows 10 ou 11",
    macos: "macOS",
    macosDetail: "macOS 11 ou plus récent\u00a0: déplacez-la dans le dossier Applications",
    yours: "Pour votre ordinateur",
    windowsArm: "Windows sur ARM",
    unsigned:
      "Pas encore signée\u00a0: Windows et macOS vous avertissent à la première ouverture (Windows\u00a0: Informations complémentaires, puis Exécuter quand même). Si le Contrôle intelligent des applications de Windows 11 la bloque, désactivez-le dans Sécurité Windows, ou demandez de l'aide sur le GitHub du projet.",
    uploadInstead: "Vous préférez ne pas installer Ravenpost\u00a0? Envoyez plutôt votre fichier de sauvegarde depuis la bibliothèque.",
    stepsTitle: "3. Se connecter",
    steps: [
      "Ouvrez Ravenpost et cliquez sur «\u00a0Se connecter avec Battle.net\u00a0».",
      "Votre navigateur s'ouvre sur Battle.net. Une fois la connexion faite, Ravenpost est relié à Hearthtale\u00a0: il n'y a rien d'autre à confirmer.",
      "Jouez, puis déconnectez-vous ou tapez /reload. Quelques secondes plus tard, votre livre est dans votre bibliothèque.",
    ],
    foreverLink: "Pour les personnages de World of Warcraft: Forever, et tous ceux que Battle.net ne trouve pas, obtenez un code de liaison depuis «\u00a0Relier un personnage\u00a0» en haut de la page, une fois la connexion faite. Tapez ensuite /ht link CODE dans le jeu avant de vous déconnecter.",
    addonSource: "Les versions de l'addon",
    ravenpostSource: "Les versions de Ravenpost",
  },
  pair: {
    title: "Relier cet ordinateur",
    ask: (who: string) => `Ravenpost, sur cet ordinateur, demande à envoyer les livres de vos personnages dans la bibliothèque de ${who}. Le code affiché par Ravenpost\u00a0:`,
    check: "Vérifiez qu'il correspond à celui de Ravenpost.",
    confirm: "Relier cet ordinateur",
    done: "C'est relié. Ravenpost envoie vos livres après chaque déconnexion ou /reload.",
    expired: "Ce code a expiré ou a déjà servi\u00a0: recommencez depuis Ravenpost.",
  },
  library: {
    title: "Bibliothèque",
    testIntro: "Le compte de test\u00a0: des livres que l'addon a enregistrés dans une partie de test, tels qu'il les a écrits à la déconnexion.",
    empty: "Aucun livre sur cette étagère pour l'instant. Avec l'addon installé, les livres de vos personnages arrivent après une déconnexion ou un /reload.",
    chapters: (n: number) => (n < 2 ? `${n} entrée` : `${n} entrées`),
    hardcore: "Extrême",
    fallen: "Vie achevée",
    hardcoreWhy: "Une vie, un livre\u00a0: une mort le clôt sur une épitaphe, et il peut rejoindre la Salle des Défunts.",
    fallenWhy: "Cette vie est achevée\u00a0: son livre est clos, avec son épitaphe.",
    forever: "Forever",
    new: "Nouveau",
    latest: "Dernière",
    updated: (when: string) => `Mis à jour ${when}`,
    road: "La route jusqu'ici",
    upload: "Envoyer un fichier de sauvegarde",
  },
  book: {
    contents: "Sommaire",
    closeCall: "Mort frôlée",
    rare: "Ennemi rare abattu",
    nothingYet: "Rien d'écrit pour l'instant.",
    previous: "Précédent",
    next: "Suivant",
    close: "Fermer",
    of: (i: number, n: number) => `${i} sur ${n}`,
    more: "Plus",
    share: "Partager",
    download: "Télécharger",
    road: "La route jusqu'ici",
    remove: "Retirer du site",
    keys: "Utilisez ← et → pour tourner les pages.",
    written: (date: string, version?: string) => `Écrit le ${date}${version ? ` par Hearthtale ${version}` : ""}`,
    notFound: "Ce livre est introuvable.",
  },
  exports: {
    title: "Télécharger le livre",
    why: "Le livre entier, à garder\u00a0: chaque entrée telle qu'elle se lit ici, avec vos notes.",
    pdf: "Imprimer, ou enregistrer en PDF",
    pdfHint: "La fenêtre d'impression de votre navigateur\u00a0: choisissez «\u00a0Enregistrer au format PDF\u00a0».",
    epub: "EPUB",
    epubHint: "Pour les liseuses et Apple Books.",
    markdown: "Texte",
    markdownHint: "Texte brut (Markdown), lisible partout.",
  },
  road: {
    title: "La route jusqu'ici",
    // (0 and 1 take the singular in French)
    entries: (n: number) => (n < 2 ? "entrée" : "entrées"),
    levels: (n: number) => (n < 2 ? "niveau" : "niveaux"),
    days: (n: number) => (n < 2 ? "jour" : "jours"),
    places: (n: number) => (n < 2 ? "lieu" : "lieux"),
    closeCalls: (n: number) => (n < 2 ? "mort frôlée" : "morts frôlées"),
    rares: (n: number) => (n < 2 ? "ennemi rare" : "ennemis rares"),
    chart: "Les niveaux au fil des jours",
    timeline: "Les entrées, une à une",
    places_: "Par où la route est passée",
    empty: "La route commence avec la première entrée.",
    read: "Lire",
    day: (n: number) => (n < 2 ? `${n} jour` : `${n} jours`),
  },
  upload: {
    title: "Envoyer un fichier de sauvegarde",
    intro: "Pas de Ravenpost\u00a0? Envoyez vous-même le livre d'un personnage\u00a0: l'addon l'enregistre dans le dossier du jeu quand vous vous déconnectez.",
    where: "Où il se trouve\u00a0:",
    paths: [
      "Windows\u00a0: World of Warcraft\\_classic_era_\\WTF\\Account\\COMPTE\\ROYAUME\\PERSONNAGE\\SavedVariables\\Hearthtale.lua",
      "macOS\u00a0: World of Warcraft/_classic_era_/WTF/Account/COMPTE/ROYAUME/PERSONNAGE/SavedVariables/Hearthtale.lua",
      "Forever\u00a0: le même chemin, avec _forever_ au lieu de _classic_era_.",
    ],
    drop: "Déposez Hearthtale.lua ici",
    choose: "Choisir le fichier",
    reading: "Lecture du fichier…",
    found: (name: string, n: number) => `Livre de ${name}\u00a0: ${n < 2 ? `${n} entrée` : `${n} entrées`}.`,
    send: "L'ajouter à ma bibliothèque",
    sending: "Envoi…",
    saved: "Dans votre bibliothèque.",
    open: "Ouvrir le livre",
    unlinked: "Ce personnage n'est pas encore relié à votre compte. Obtenez un code de liaison depuis «\u00a0Relier un personnage\u00a0» en haut de la page, tapez /ht link CODE dans le jeu, déconnectez-vous, puis envoyez de nouveau le fichier.",
    invalid: "Ce fichier ne contient aucun livre que le site sache lire.",
    owned: "Un autre compte possède déjà ce personnage, et un code de liaison ne peut pas le déplacer. S'il est à vous, connectez-vous avec ce compte, ou demandez de l'aide sur le GitHub du projet.",
    removed: "Vous avez retiré ce livre du site\u00a0: un nouveau code de liaison le fait revenir.",
    notLua: "Ce n'est pas un fichier de sauvegarde de Hearthtale (Hearthtale.lua).",
    noBook: "Aucun livre de personnage dans ce fichier pour l'instant\u00a0: jouez, déconnectez-vous, puis réessayez.",
    tooBig: "Ce fichier est trop gros pour être un fichier de sauvegarde de Hearthtale.",
    failed: "L'envoi a échoué. Vérifiez votre connexion, puis réessayez.",
  },
  push: {
    title: "Notifications",
    why: "Une notification sur cet appareil quand l'un de vos personnages a une nouvelle entrée (après votre déconnexion).",
    on: "Me prévenir quand une nouvelle entrée arrive",
    unsupported: "Ce navigateur ne peut pas recevoir de notifications du site.",
    ios: "Sur iPhone et iPad\u00a0: ajoutez Hearthtale à votre écran d'accueil (Partager, puis Sur l'écran d'accueil), ouvrez-le depuis là, puis activez cette option.",
    denied: "Les notifications de ce site sont bloquées dans les réglages de votre navigateur.",
    signIn: "Connectez-vous pour recevoir les nouvelles entrées.",
    failed: "L'opération a échoué. Réessayez dans un instant.",
  },
  share: {
    title: "Partager",
    why: "Toute personne qui a le lien peut lire ce que vous partagez, et rien d'autre\u00a0: vos notes dans les marges restent les vôtres. Vous pouvez le révoquer à tout moment.",
    thisPart: (part: string) => `Partager «\u00a0${part}\u00a0»`,
    wholeBook: "Le livre entier",
    copy: "Copier le lien",
    copied: "Copié",
    send: "Envoyer",
    made: "Vos liens",
    revoke: "Révoquer",
    revokeHint: "Un lien révoqué cesse aussitôt de fonctionner.",
    hall: "Afficher ce livre dans la Salle des Défunts",
    hallWhy: "La Salle publique, sur hearthtale.app\u00a0: tout le monde peut y lire le livre de cette vie achevée, sans vos notes. Vous pouvez l'en retirer.",
    gone: "Ce lien ne mène plus à aucun livre\u00a0: il a été révoqué, ou le livre n'est plus là.",
    visitor: (name: string) => `Le journal de ${name}, écrit par Hearthtale au fil de ses parties de World of Warcraft.`,
    keepYours: "Commencer le vôtre",
  },
  remove: {
    title: "Retirer ce livre",
    why: (name: string) => `Le livre de ${name} quitte hearthtale.app, avec tous les liens que vous en avez partagés. Le journal lui-même reste dans le jeu.`,
    companion:
      "Ravenpost ne le fera pas revenir\u00a0: ses envois de ce personnage sont désormais refusés. Pour faire revenir le livre, obtenez un code de liaison depuis «\u00a0Relier un personnage\u00a0» en haut de la page et tapez /ht link CODE dans le jeu.",
    confirm: "Retirer le livre",
    cancel: "Le garder",
    failed: "Le livre n'a pas pu être retiré. Vérifiez votre connexion, puis réessayez.",
  },
  hall: {
    title: "Salle des Défunts",
    intro: "Ici reposent des vies en mode Extrême arrivées à leur terme, montrées parce que leurs joueurs l'ont voulu. Chacune a son épitaphe et son livre à lire.",
    empty: "Aucun livre clos n'a encore rejoint la Salle.",
    read: "Lire le livre",
  },
  settings: {
    title: "Réglages",
    appearance: "Apparence",
    site: "Le site",
    sites: { system: "Comme l'appareil", light: "Clair", dark: "Sombre" } as Record<string, string>,
    reading: "Lecture",
    preview:
      "J'ai atteint Kharanos et pris une chambre à la Distillerie Thunderbrew. Plus tard dans la journée, j'ai gagné la Crête scintillante et réglé son compte à un Marche-neige Frostmane.",
    size: "Taille du texte",
    font: "Police",
    fonts: { book: "Livre", plain: "Simple" } as Record<string, string>,
    paper: "Papier",
    themes: { parchment: "Parchemin", sepia: "Sépia", night: "Nuit" } as Record<string, string>,
    spacing: "Interligne",
    spacings: { tight: "Serré", normal: "Normal", airy: "Aéré" } as Record<string, string>,
    language: "Langue",
    languageHint: "La langue du site. Chaque livre garde la langue dans laquelle il a été écrit.",
    account: "Compte",
    signedInAs: (who: string) => `Compte\u00a0: ${who}.`,
    about: "À propos",
    version: (v: string, commit: string, date: string) => `Hearthtale ${v} (site ${commit}, ${date}).`,
  },
  privacy: {
    title: "Confidentialité",
    updated: "Dernière mise à jour le 3 novembre 2026.",
    sections: [
      {
        title: "Ce que le site garde",
        text: "Le site garde l'identifiant et le BattleTag de votre compte Battle.net, pour savoir quels livres sont à vous, et les personnages que le jeu vous attribue (leur nom, royaume, race, classe, sexe et niveau). Il garde aussi chaque livre tel que l'addon l'a écrit, avec vos propres titres et notes, et les liens de partage que vous créez. Si vous activez les notifications, il garde aussi l'adresse de notification de cet appareil.",
      },
      {
        title: "Ce qu'il ne garde jamais",
        text: "Votre mot de passe ou votre jeton d'accès Battle.net, votre adresse e-mail, votre position, ce que vous transportez ou votre or\u00a0: les données brutes de l'addon restent sur votre ordinateur, et Ravenpost n'envoie que le livre.",
      },
      {
        title: "Qui lit vos livres",
        text: "Personne d'autre que vous, sauf si vous partagez un lien (toute personne qui l'a peut lire ce qu'il donne à lire) ou si vous montrez un livre clos dans la Salle (tout le monde peut l'y lire). Vos notes dans les marges restent les vôtres dans tous les cas. Révoquez un lien, ou retirez un livre de la Salle, à tout moment.",
      },
      {
        title: "Cookies",
        text: "Un seul, pour maintenir votre connexion. Ni publicité ni pistage\u00a0: les visites sont comptées sans cookies (Vercel Web Analytics\u00a0: la page, le pays, le type d'appareil, jamais votre identité). Vos réglages de lecture restent dans ce navigateur.",
      },
      {
        title: "Retirer vos données",
        text: "Retirez un livre du site depuis son lecteur (Plus, puis Retirer du site)\u00a0: il part aussitôt, avec ses liens. Pour que tout soit supprimé, ouvrez un ticket (issue) sur la page GitHub du projet.",
      },
    ],
  },
  update: { available: "Une nouvelle version de Hearthtale est prête.", reload: "Recharger", close: "Fermer" },
};

/** The languages, with the locale their dates and times are written in. */
export const CATALOGS = {
  en: { strings: en, locale: "en-GB", name: "English", language: "enUS" as const },
  fr: { strings: fr, locale: "fr-FR", name: "Français", language: "frFR" as const },
} satisfies Record<string, { strings: Strings; locale: string; name: string; language: Language }>;
export type Lang = keyof typeof CATALOGS;
export const LANGS = Object.keys(CATALOGS) as Lang[];
export const DEFAULT_LANG: Lang = "en";

export function isLang(v: unknown): v is Lang {
  return typeof v === "string" && v in CATALOGS;
}

export function strings(lang: Lang): Strings {
  return CATALOGS[lang].strings;
}

/** The browser's first language that has a catalog (fr-CA: fr), else English. */
export function browserLang(languages: readonly string[] = typeof navigator === "undefined" ? [] : (navigator.languages?.length ? navigator.languages : [navigator.language])): Lang {
  for (const l of languages) {
    const code = l.toLowerCase().split("-")[0];
    if (isLang(code)) return code;
  }
  return DEFAULT_LANG;
}

/** The chosen language, if it has a catalog; none chosen yet, the browser's. */
export function useLang(): Lang {
  const lang = useSettings().lang;
  return isLang(lang) ? lang : browserLang();
}

/** The page's strings, in the chosen language. */
export function useT(): Strings {
  return strings(useLang());
}

/** The chosen language's locale, for dates and times. */
export function useLocale(): string {
  return CATALOGS[useLang()].locale;
}

/** The interface's frame: every label around a book (its entries, levels, dates, race and class), in the site's language, as the game's window follows the client; the book's own words keep theirs (`langOf(book.language)` tags them). */
export function useFrame(): Frame {
  return frameFor(CATALOGS[useLang()].language);
}
