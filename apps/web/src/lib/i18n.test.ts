import { describe, expect, test } from "bun:test";
import { CATALOGS, LANGS, strings } from "@/lib/i18n";

// Every key of English is in each catalog, and nothing is left empty.
function keys(o: unknown, prefix = ""): string[] {
  if (typeof o !== "object" || o === null) return [prefix];
  return Object.entries(o).flatMap(([k, v]) => keys(v, prefix ? `${prefix}.${k}` : k));
}

import { renderHook } from "@testing-library/react";
import { setSettings } from "@/lib/settings";
import { useLocale, useT } from "@/lib/i18n";

describe("i18n", () => {
  test("a language without a catalog reads English", () => {
    setSettings({ lang: "fr" });
    try {
      expect(renderHook(() => useT()).result.current.nav.library).toBe("Library");
      expect(renderHook(() => useLocale()).result.current).toBe("en-GB");
    } finally {
      setSettings({ lang: "en" });
    }
  });
  test("every catalog has every English string", () => {
    for (const lang of LANGS) expect(keys(strings(lang)).sort()).toEqual(keys(strings("en")).sort());
  });
  test("no empty string, a locale for each", () => {
    for (const lang of LANGS) {
      expect(JSON.stringify(strings(lang)).includes('""')).toBe(false);
      expect(CATALOGS[lang].locale).toBeTruthy();
    }
  });
});
