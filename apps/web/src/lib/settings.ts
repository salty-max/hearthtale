import { useSyncExternalStore } from "react";

/** Per-device settings, kept in localStorage: the language (lib/i18n.ts), the site's light or dark, and how books read. */
export type ReaderSize = "s" | "m" | "l" | "xl";
/** serif: the book's Garamond; game: the game's own kind of letters (Marcellus); sans: plain. */
export type ReaderFont = "serif" | "game" | "sans";
export type ReaderTheme = "parchment" | "sepia" | "night";
export type ReaderSpacing = "tight" | "normal" | "airy";
/** The site's frame: by day, by night, or as the device is set (lib/theme.ts). */
export type SiteTheme = "system" | "light" | "dark";
/** lang: a language code, checked against the catalogs where it is used (lib/i18n.ts: no import cycle). */
export type Settings = {
  lang: string;
  size: ReaderSize;
  font: ReaderFont;
  theme: ReaderTheme;
  spacing: ReaderSpacing;
  site: SiteTheme;
};

export const SIZES: ReaderSize[] = ["s", "m", "l", "xl"];
export const FONTS: ReaderFont[] = ["serif", "game", "sans"];
export const THEMES: ReaderTheme[] = ["parchment", "sepia", "night"];
export const SPACINGS: ReaderSpacing[] = ["tight", "normal", "airy"];
export const SITE_THEMES: SiteTheme[] = ["system", "light", "dark"];

const KEY = "hearthtale.settings";
const listeners = new Set<() => void>();

const pick = <T extends string>(v: unknown, allowed: T[], fallback: T): T => (allowed.includes(v as T) ? (v as T) : fallback);

/** The saved settings, each one checked (an unknown value falls back to its default). */
export function parseSettings(saved: unknown): Settings {
  const s = (saved && typeof saved === "object" ? saved : {}) as Record<string, unknown>;
  return {
    lang: typeof s.lang === "string" ? s.lang : "en",
    size: pick(s.size, SIZES, "m"),
    font: pick(s.font, FONTS, "serif"),
    theme: pick(s.theme, THEMES, "parchment"),
    spacing: pick(s.spacing, SPACINGS, "normal"),
    site: pick(s.site, SITE_THEMES, "system"),
  };
}

function initial(): Settings {
  try {
    return parseSettings(JSON.parse(localStorage.getItem(KEY) ?? "null"));
  } catch {
    return parseSettings(null); // no storage (private window): the defaults
  }
}

let current = initial();

export function getSettings(): Settings {
  return current;
}

export function setSettings(patch: Partial<Settings>): void {
  current = { ...current, ...patch };
  try {
    localStorage.setItem(KEY, JSON.stringify(current));
  } catch {
    // kept for this session only
  }
  for (const l of listeners) l();
}

export function useSettings(): Settings {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    getSettings,
    getSettings,
  );
}

/** How a book's text reads, from the settings: class names for the page and its text. */
export function readerClasses(s: Pick<Settings, "size" | "font" | "theme" | "spacing">): { page: string; text: string } {
  const size = { s: "text-lg", m: "text-xl", l: "text-2xl", xl: "text-[1.7rem]" }[s.size];
  const leading = { tight: "leading-snug", normal: "leading-relaxed", airy: "leading-loose" }[s.spacing];
  const font = s.font === "sans" ? "font-sans" : s.font === "game" ? "font-ui" : "font-book";
  return { page: `page page-${s.theme}`, text: `${size} ${leading} ${font}` };
}
