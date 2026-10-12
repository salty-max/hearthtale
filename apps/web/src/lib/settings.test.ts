import { describe, expect, test } from "bun:test";
import { parseSettings, readerClasses } from "@/lib/settings";

describe("settings", () => {
  test("defaults, and saved values checked one by one", () => {
    expect(parseSettings(null)).toEqual({ lang: "en", size: "m", font: "book", theme: "parchment", spacing: "normal", site: "system" });
    // a language code is kept as saved (lib/i18n.ts falls back to English if it has no catalog)
    expect(parseSettings({ lang: "fr", size: "xl", theme: "night", font: "comic", spacing: 3, site: "light" })).toEqual({
      lang: "fr",
      size: "xl",
      font: "book",
      theme: "night",
      spacing: "normal",
      site: "light",
    });
  });
  test("the typefaces' old names keep their choice", () => {
    expect(parseSettings({ font: "serif" }).font).toBe("book");
    expect(parseSettings({ font: "sans" }).font).toBe("plain");
    expect(parseSettings({ font: "plain" }).font).toBe("plain");
  });
  test("how the text reads", () => {
    const c = readerClasses({ size: "l", font: "plain", theme: "sepia", spacing: "airy" });
    expect(c.page).toBe("page page-sepia font-sans");
    expect(c.text).toBe("text-xl leading-loose font-sans");
    expect(readerClasses({ size: "m", font: "book", theme: "parchment", spacing: "normal" }).text).toBe("text-xl leading-relaxed font-book");
  });
});
