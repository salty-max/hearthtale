import { describe, expect, test } from "bun:test";
import { parseSettings, readerClasses } from "@/lib/settings";

describe("settings", () => {
  test("defaults, and saved values checked one by one", () => {
    expect(parseSettings(null, "fr")).toEqual({ lang: "fr", size: "m", font: "serif", theme: "parchment", spacing: "normal" });
    expect(parseSettings({ lang: "en", size: "xl", theme: "night", font: "comic", spacing: 3 }, "fr")).toEqual({
      lang: "en",
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
