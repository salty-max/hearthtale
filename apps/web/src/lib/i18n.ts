import { useSettings, type Lang } from "@/lib/settings";

/** Every visible string. `fr` is typed on the exact shape of `en`. */
const en = {
  nav: { home: "Hearthtale", skip: "Skip to content", language: "Language" },
  home: {
    tagline: "Your character's own journal, written as you play.",
    intro:
      "Hearthtale is a World of Warcraft addon. Every quest, every new foe, every place, every close call is written down as it happens, in your character's own voice, and a chapter closes when you rest at an inn or by a campfire. On Hardcore, a death closes the book with an epitaph.",
    soon: "Soon on this site: your journal, to read on your phone and to share.",
    games: "Classic Era, Hardcore, Season of Discovery, TBC Anniversary and World of Warcraft: Forever.",
    download: "Download the addon",
  },
  notFound: { title: "Lost in the mist", body: "There is no page here.", back: "Back to the hearth" },
  update: { available: "A new version of Hearthtale is ready.", reload: "Reload", close: "Close" },
  footer: { source: "Source code", notAffiliated: "Not affiliated with Blizzard Entertainment." },
};

const fr: typeof en = {
  nav: { home: "Hearthtale", skip: "Aller au contenu", language: "Langue" },
  home: {
    tagline: "Le journal de votre personnage, écrit pendant que vous jouez.",
    intro:
      "Hearthtale est un addon pour World of Warcraft. Chaque quête, chaque nouvel ennemi, chaque lieu, chaque mort évitée de justesse est écrit au moment où il arrive, avec la voix de votre personnage, et un chapitre se clôt quand vous vous reposez dans une auberge ou au coin d'un feu de camp. En Hardcore, la mort referme le livre sur une épitaphe.",
    soon: "Bientôt sur ce site : votre journal, à lire sur votre téléphone et à partager.",
    games: "Classic Era, Hardcore, Season of Discovery, TBC Anniversary et World of Warcraft: Forever.",
    download: "Télécharger l'addon",
  },
  notFound: { title: "Perdu dans la brume", body: "Il n'y a pas de page ici.", back: "Retour au coin du feu" },
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
