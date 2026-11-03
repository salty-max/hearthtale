import { describe, expect, test } from "bun:test";
import { browserLang, CATALOGS, LANGS, strings } from "@/lib/i18n";

// Every key of English is in each catalog, and nothing is left empty.
function keys(o: unknown, prefix = ""): string[] {
  if (typeof o !== "object" || o === null) return [prefix];
  return Object.entries(o).flatMap(([k, v]) => keys(v, prefix ? `${prefix}.${k}` : k));
}

// Every text a catalog can show, the functions' too (called with sample words).
function texts(o: unknown): string[] {
  if (typeof o === "string") return [o];
  if (typeof o === "function") return [String((o as (...a: string[]) => unknown)("Ab", "Cd", "Ef"))];
  if (typeof o !== "object" || o === null) return [];
  return Object.values(o).flatMap(texts);
}

// The browser's languages, for one test.
function withBrowser(languages: string[], run: () => void) {
  const was = Object.getOwnPropertyDescriptor(navigator, "languages");
  Object.defineProperty(navigator, "languages", { value: languages, configurable: true });
  try {
    run();
  } finally {
    if (was) Object.defineProperty(navigator, "languages", was);
    else delete (navigator as unknown as Record<string, unknown>).languages;
  }
}

import { renderHook } from "@testing-library/react";
import { setSettings } from "@/lib/settings";
import { useLocale, useT } from "@/lib/i18n";

describe("i18n", () => {
  test("a language without a catalog reads the browser's, English when it has none", () => {
    setSettings({ lang: "xx" });
    try {
      withBrowser(["de-DE"], () => {
        expect(renderHook(() => useT()).result.current.nav.library).toBe("Library");
        expect(renderHook(() => useLocale()).result.current).toBe("en-GB");
      });
      withBrowser(["fr-FR"], () => expect(renderHook(() => useT()).result.current.nav.library).toBe("Bibliothèque"));
    } finally {
      setSettings({ lang: "en" });
    }
  });
  test("none chosen: the browser's language", () => {
    setSettings({ lang: "" });
    try {
      withBrowser(["fr-FR", "en"], () => expect(renderHook(() => useLocale()).result.current).toBe("fr-FR"));
    } finally {
      setSettings({ lang: "en" });
    }
  });
  test("French, chosen", () => {
    setSettings({ lang: "fr" });
    try {
      expect(renderHook(() => useT()).result.current.nav.library).toBe("Bibliothèque");
      expect(renderHook(() => useLocale()).result.current).toBe("fr-FR");
    } finally {
      setSettings({ lang: "en" });
    }
  });
  test("none chosen: the browser's first language with a catalog", () => {
    expect(browserLang(["fr-CA", "en"])).toBe("fr");
    expect(browserLang(["de-DE", "fr"])).toBe("fr");
    expect(browserLang(["de-DE"])).toBe("en");
    expect(browserLang([])).toBe("en");
  });
  test("French typography: a no-break space before : ? ! and inside « », no semicolon", () => {
    for (const text of texts(strings("fr"))) {
      expect(text).not.toMatch(/ [:?!»]/);
      expect(text).not.toMatch(/« /);
      expect(text).not.toContain(";");
    }
  });
  test("every catalog has every English string", () => {
    for (const lang of LANGS) expect(keys(strings(lang)).sort()).toEqual(keys(strings("en")).sort());
  });
  test("no empty string, a locale for each", () => {
    for (const lang of LANGS) {
      for (const text of texts(strings(lang))) expect(text.trim()).not.toBe("");
      expect(CATALOGS[lang].locale).toBeTruthy();
    }
  });
});
