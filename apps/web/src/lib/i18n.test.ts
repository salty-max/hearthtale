import { describe, expect, test } from "bun:test";
import { strings } from "@/lib/i18n";

// Every key of one language is a key of the other, and nothing is left empty.
function keys(o: unknown, prefix = ""): string[] {
  if (typeof o !== "object" || o === null) return [prefix];
  return Object.entries(o).flatMap(([k, v]) => keys(v, prefix ? `${prefix}.${k}` : k));
}

describe("i18n", () => {
  test("French has every English string", () => {
    expect(keys(strings("fr")).sort()).toEqual(keys(strings("en")).sort());
  });
  test("no empty string", () => {
    for (const lang of ["en", "fr"] as const) {
      const flat = JSON.stringify(strings(lang));
      expect(flat.includes('""')).toBe(false);
    }
  });
});
