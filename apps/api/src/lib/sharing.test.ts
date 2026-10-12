import type { Book, SharedBook } from "@hearthtale/shared";
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
  test("a visitor never reads the player's notes", () => {
    const noted: Book = { ...book, chapters: book.chapters.map((c) => ({ ...c, note: "Buy arrows before Kharanos." })) };
    const seen = withoutNotes(noted);
    expect(seen.chapters.map((c) => c.note)).toEqual([undefined, undefined]);
    expect(JSON.stringify(seen)).not.toContain("arrows");
    expect(JSON.stringify(cutBook(seen, "2"))).not.toContain("arrows");
    expect(seen.chapters.map((c) => c.text)).toEqual(book.chapters.map((c) => c.text));
    expect(noted.chapters[0].note).toBe("Buy arrows before Kharanos.");
  });
  test("the preview card: who, which part, the opening lines", () => {
    const shared: SharedBook = { character: who, book: cutBook(book, "2")!, part: "2" };
    expect(ogTitle(shared)).toBe("Pippa, level 6 Gnome Mage (fallen) · Entry 2");
    expect(ogText(shared)).toBe("I reached Kharanos.");
    expect(ogText({ character: who, book }, 20)).toBe("Pippa died by the…");
    const html = ogPage({ character: { ...who, name: "<b>" }, book, part: "epitaph" }, "/s/abc", "https://hearthtale.app");
    expect(html).toContain('og:url" content="https://hearthtale.app/s/abc"');
    expect(html).not.toContain("<b>");
  });
});
