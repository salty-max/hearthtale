import type { Book } from "@hearthtale/shared";
import { describe, expect, test } from "bun:test";
import { current, paragraphs, partSub, partTitle, parts } from "@/lib/book";
import { dateRange } from "@/lib/dates";
import { strings } from "@/lib/i18n";

const t = strings("en");

const book: Book = {
  client: "classic",
  at: 0,
  prologue: "Before.",
  chapters: [
    { number: 1, text: "One.\n\nTwo.", from: 1, to: 4 },
    { number: 2, text: "Three.", from: 4, to: 6, open: true },
  ],
};

describe("book", () => {
  test("its parts in reading order", () => {
    expect(parts(book).map((p) => p.key)).toEqual(["prologue", "1", "2"]);
    expect(parts({ ...book, epitaph: "The end." }).map((p) => p.key)).toEqual(["prologue", "1", "2", "epitaph"]);
  });
  test("paragraphs split on blank lines", () => {
    expect(paragraphs("One.\n\nTwo.\n\n\nThree.")).toEqual(["One.", "Two.", "Three."]);
    expect(paragraphs(undefined)).toEqual([]);
  });
  test("opens on the chapter being written, else the last part", () => {
    expect(current(book)).toBe("2");
    expect(current({ ...book, chapters: [book.chapters[0]], epitaph: "The end." })).toBe("epitaph");
  });
  test("a part's title and the line under it, dated as the addon writes it", () => {
    const dated: Book = {
      ...book,
      chapters: [
        { number: 1, title: "The Troll Cave", place: "Anvilmar", from: 1, to: 4, began: Date.UTC(2026, 9, 5, 12) / 1000, ended: Date.UTC(2026, 9, 7, 12) / 1000 },
        { number: 2, place: "Kharanos", from: 4, to: 6, began: Date.UTC(2026, 9, 8, 12) / 1000, open: true },
      ],
    };
    const [, one, two] = parts(dated);
    expect(partTitle(t, dated, one)).toBe("The Troll Cave");
    expect(partTitle(t, dated, two)).toBe("Entry 2");
    expect(partSub(t, "en-GB", { fallen: false }, dated, one)).toBe("Entry 1 · Anvilmar · levels 1 to 4 · 5 to 7 Oct 2026");
    expect(partSub(t, "en-GB", { fallen: false }, dated, two)).toBe("levels 4 to 6 · 8 Oct 2026 · still being written");
    expect(partSub(t, "en-GB", { fallen: true }, { ...dated, chapters: [dated.chapters[0]] }, one)).toMatch(/ · the end$/);
  });
  test("dates as short as they read", () => {
    const d = (y: number, m: number, day: number) => Date.UTC(y, m, day, 12) / 1000;
    expect(dateRange(d(2026, 9, 5), d(2026, 9, 5), "en-GB")).toBe("5 Oct 2026");
    expect(dateRange(d(2026, 8, 30), d(2026, 9, 2), "en-GB")).toMatch(/^30 Sept? to 2 Oct 2026$/);
    expect(dateRange(d(2026, 11, 30), d(2027, 0, 2), "en-GB")).toBe("30 Dec 2026 to 2 Jan 2027");
    expect(dateRange(undefined, undefined, "en-GB")).toBeUndefined();
  });
});
