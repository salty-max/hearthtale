import type { Book } from "@hearthtale/shared";
import { describe, expect, test } from "bun:test";
import { latestOf } from "@/lib/characters";

const book = (chapters: Book["chapters"]): Book => ({ client: "classic", at: 1, chapters });

describe("library", () => {
  test("a card names the entry being written, else the last", () => {
    expect(latestOf(book([]))).toBeUndefined();
    expect(
      latestOf(
        book([
          { number: 1, from: 1, to: 4, title: "The Troll Cave", place: "Anvilmar", began: 10, ended: 20 },
          { number: 2, from: 4, to: 7, place: "Kharanos", began: 30, ended: 40 },
        ]),
      ),
    ).toEqual({ number: 2, title: undefined, place: "Kharanos", at: 40, open: undefined });
    expect(
      latestOf(
        book([
          { number: 1, from: 1, to: 4, began: 10, ended: 20 },
          { number: 2, from: 4, to: 5, title: "Bristle", began: 30, open: true },
        ]),
      ),
    ).toEqual({ number: 2, title: "Bristle", place: undefined, at: 30, open: true });
  });
});
