import { describe, expect, test } from "bun:test";
import { parseSettings, readerClasses } from "@/lib/settings";

describe("settings", () => {
  test("defaults, and saved values checked one by one", () => {
    expect(parseSettings(null)).toEqual({ lang: "en", size: "m", font: "serif", theme: "parchment", spacing: "normal" });
    // a language code is kept as saved (lib/i18n.ts falls back to English if it has no catalog)
    expect(parseSettings({ lang: "fr", size: "xl", theme: "night", font: "comic", spacing: 3 })).toEqual({
      lang: "fr",
      size: "xl",
      font: "serif",
      theme: "night",
      spacing: "normal",
    });
  });
  test("how the text reads", () => {
    const c = readerClasses({ size: "l", font: "sans", theme: "sepia", spacing: "airy" });
    expect(c.page).toBe("page page-sepia");
    expect(c.text).toBe("text-2xl leading-loose font-sans");
  });
});
