import type { Book } from "@hearthtale/shared";
import { describe, expect, test } from "bun:test";
import { current, paragraphs, parts } from "@/lib/book";

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
});
