import { frameLanguage, type Book, type SharedBook } from "@hearthtale/shared";
import { describe, expect, test } from "bun:test";
import { ogPage, ogText, ogTitle } from "@/lib/og";
import { cutBook, withoutNotes } from "@/lib/sharing";

const book: Book = {
  client: "classic",
  at: 1,
  level: 9,
  prologue: "Before.",
  chapters: [
    { number: 1, text: "I begin in Coldridge Valley.", from: 1, to: 4 },
    { number: 2, text: "I reached Kharanos.", from: 4, to: 7 },
  ],
  epitaph: "Pippa died by the hand of a Frostmane Shadowcaster.",
};
const who = { name: "Pippa", race: "Gnome", class: "MAGE", level: 6, hardcore: true, fallen: true };

describe("sharing", () => {
  test("a link covers the book or one part of it, nothing more", () => {
    expect(cutBook(book)).toBe(book);
    expect(cutBook(book, "2")).toMatchObject({ chapters: [{ number: 2 }] });
    expect(cutBook(book, "2")?.prologue).toBeUndefined();
    expect(cutBook(book, "2")?.epitaph).toBeUndefined();
    expect(cutBook(book, "epitaph")).toMatchObject({ chapters: [], epitaph: book.epitaph });
    expect(cutBook(book, "prologue")).toMatchObject({ chapters: [], prologue: "Before." });
    expect(cutBook(book, "3")).toBeNull();
    expect(cutBook(book, "x")).toBeNull();
    expect(cutBook({ ...book, epitaph: undefined }, "epitaph")).toBeNull();
  });
  test("a part keeps the book's language and the character's sex", () => {
    const fr: Book = { ...book, language: "frFR", sex: 3 };
    expect(cutBook(fr, "2")).toMatchObject({ language: "frFR", sex: 3 });
    expect(cutBook(fr, "epitaph")).toMatchObject({ language: "frFR", sex: 3 });
  });
  test("a visitor never reads the player's notes", () => {
    const noted: Book = { ...book, chapters: book.chapters.map((c) => ({ ...c, note: "Buy arrows before Kharanos." })) };
    const seen = withoutNotes(noted);
    expect(seen.chapters.map((c) => c.note)).toEqual([undefined, undefined]);
    expect(JSON.stringify(seen)).not.toContain("arrows");
    expect(JSON.stringify(cutBook(seen, "2"))).not.toContain("arrows");
    expect(seen.chapters.map((c) => c.text)).toEqual(book.chapters.map((c) => c.text));
    expect(noted.chapters[0].note).toBe("Buy arrows before Kharanos.");
  });
  test("the reader's language, from an Accept-Language header", () => {
    expect(frameLanguage("fr-CA,fr;q=0.9,en;q=0.8")).toBe("frFR");
    expect(frameLanguage("de-DE,en-GB;q=0.8,fr;q=0.5")).toBe("enUS");
    expect(frameLanguage("de-DE")).toBeUndefined();
    expect(frameLanguage("fr;q=0, en")).toBe("enUS");
    expect(frameLanguage(undefined)).toBeUndefined();
  });
  test("the preview card: who, which part, the opening lines", () => {
    const shared: SharedBook = { character: who, book: cutBook(book, "2")!, part: "2" };
    expect(ogTitle(shared)).toBe("Pippa, level 6 Gnome Mage (fallen) · Entry 2");
    expect(ogText(shared)).toBe("I reached Kharanos.");
    // (a French book: its frame in French, the woman's names, lang="fr")
    const fr: SharedBook = { character: { ...who, race: "Dwarf", class: "HUNTER" }, book: { ...cutBook(book, "2")!, language: "frFR", sex: 3 }, part: "2" };
    expect(ogTitle(fr)).toBe("Pippa, niveau 6 chasseresse naine (tombée) · Entrée 2");
    expect(ogPage(fr, "/s/abc", "https://hearthtale.app")).toContain('<html lang="fr">');
    // (the reader's language first, as the site would choose it: the labels its, the names the character's sex)
    expect(ogTitle(fr, "enUS")).toBe("Pippa, level 6 Dwarf Hunter (fallen) · Entry 2");
    expect(ogPage(fr, "/s/abc", "https://hearthtale.app", "enUS")).toContain('<html lang="en">');
    const woman: SharedBook = { ...shared, book: { ...shared.book, sex: 3 } };
    expect(ogTitle(woman, "frFR")).toBe("Pippa, niveau 6 mage gnome (tombée) · Entrée 2");
    expect(ogTitle(shared, "frFR")).toBe("Pippa, niveau 6 mage gnome (tombé) · Entrée 2");
    expect(ogText({ character: who, book }, 20)).toBe("Pippa died by the…");
    const html = ogPage({ character: { ...who, name: "<b>" }, book, part: "epitaph" }, "/s/abc", "https://hearthtale.app");
    expect(html).toContain('og:url" content="https://hearthtale.app/s/abc"');
    expect(html).not.toContain("<b>");
  });
});
