import { useSyncExternalStore } from "react";

/** Per-device settings, kept in localStorage. */
export type Lang = "en" | "fr";
export type Settings = { lang: Lang };

const KEY = "hearthtale.settings";
const listeners = new Set<() => void>();

function initial(): Settings {
  const lang: Lang = typeof navigator !== "undefined" && navigator.language?.toLowerCase().startsWith("fr") ? "fr" : "en";
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) ?? "null") as Partial<Settings> | null;
    if (saved && (saved.lang === "en" || saved.lang === "fr")) return { lang: saved.lang };
  } catch {
    // no storage (private window): the defaults
  }
  return { lang };
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
