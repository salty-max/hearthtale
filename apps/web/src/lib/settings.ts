import { useSyncExternalStore } from "react";

/** Per-device settings, kept in localStorage: the language and how books read. */
export type Lang = "en" | "fr";
export type ReaderSize = "s" | "m" | "l" | "xl";
export type ReaderFont = "serif" | "sans";
export type ReaderTheme = "parchment" | "sepia" | "night";
export type ReaderSpacing = "tight" | "normal" | "airy";
export type Settings = { lang: Lang; size: ReaderSize; font: ReaderFont; theme: ReaderTheme; spacing: ReaderSpacing };

export const SIZES: ReaderSize[] = ["s", "m", "l", "xl"];
export const FONTS: ReaderFont[] = ["serif", "sans"];
export const THEMES: ReaderTheme[] = ["parchment", "sepia", "night"];
export const SPACINGS: ReaderSpacing[] = ["tight", "normal", "airy"];

const KEY = "hearthtale.settings";
const listeners = new Set<() => void>();

const pick = <T extends string>(v: unknown, allowed: T[], fallback: T): T => (allowed.includes(v as T) ? (v as T) : fallback);

/** The saved settings, each one checked (an unknown value falls back to its default). */
export function parseSettings(saved: unknown, lang: Lang): Settings {
  const s = (saved && typeof saved === "object" ? saved : {}) as Record<string, unknown>;
  return {
    lang: pick(s.lang, ["en", "fr"], lang),
    size: pick(s.size, SIZES, "m"),
    font: pick(s.font, FONTS, "serif"),
    theme: pick(s.theme, THEMES, "parchment"),
    spacing: pick(s.spacing, SPACINGS, "normal"),
  };
}

function initial(): Settings {
  const lang: Lang = typeof navigator !== "undefined" && navigator.language?.toLowerCase().startsWith("fr") ? "fr" : "en";
  try {
    return parseSettings(JSON.parse(localStorage.getItem(KEY) ?? "null"), lang);
  } catch {
    return parseSettings(null, lang); // no storage (private window): the defaults
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
  const font = s.font === "sans" ? "font-sans" : "font-book";
  return { page: `page page-${s.theme}`, text: `${size} ${leading} ${font}` };
}
