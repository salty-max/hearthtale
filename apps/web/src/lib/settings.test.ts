import { describe, expect, test } from "bun:test";
import { parseSettings, readerClasses } from "@/lib/settings";

describe("settings", () => {
  test("defaults, and saved values checked one by one", () => {
    expect(parseSettings(null)).toEqual({ lang: "", langChosen: false, size: "m", font: "book", theme: "parchment", spacing: "normal", site: "system" });
    // a language code is kept as saved once picked (lib/i18n.ts falls back to the browser's if it has no catalog)
    expect(parseSettings({ lang: "fr", langChosen: true, size: "xl", theme: "night", font: "comic", spacing: 3, site: "light" })).toEqual({
      lang: "fr",
      langChosen: true,
      size: "xl",
      font: "book",
      theme: "night",
      spacing: "normal",
      site: "light",
    });
  });
  test("a language saved before the picker showed is no choice: the browser's then", () => {
    expect(parseSettings({ lang: "en", site: "dark" }).lang).toBe("");
    expect(parseSettings({ lang: "en", langChosen: true }).lang).toBe("en");
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
