import type { Book } from "@hearthtale/shared";
import { describe, expect, test } from "bun:test";
import { levelPoints, roadOf } from "@/lib/road";

const day = 86400;
const book: Book = {
  client: "classic",
  at: 1,
  chapters: [
    { number: 1, from: 1, to: 4, place: "Anvilmar", began: 0, ended: day / 2, close: true },
    { number: 2, from: 4, to: 7, place: "Kharanos", began: day, ended: 2 * day, rare: true },
    { number: 3, from: 7, to: 9, place: "Kharanos", began: 3 * day, open: true },
  ],
};

describe("the road so far", () => {
  test("its figures", () => {
    expect(roadOf(book)).toEqual({ entries: 3, from: 1, to: 9, days: 3, places: ["Anvilmar", "Kharanos"], closeCalls: 1, rares: 1 });
    expect(roadOf({ ...book, chapters: [] })).toMatchObject({ entries: 0, days: 0, places: [] });
  });
  test("the level over time, each entry from its start to its end (else by its order)", () => {
    expect(levelPoints(book.chapters).map((p) => [p.x, p.y])).toEqual([
      [0, 1],
      [day / 2, 4],
      [day, 4],
      [2 * day, 7],
      [3 * day, 7],
      [3 * day, 9],
    ]);
    // (the entry still being written: to the book's last saving)
    expect(levelPoints(book.chapters, 4 * day).at(-1)).toMatchObject({ x: 4 * day, y: 9 });
    const untimed = book.chapters.map(({ began: _, ended: __, ...c }) => c);
    expect(levelPoints(untimed).map((p) => p.x)).toEqual([0, 1, 1, 2, 2, 3]);
  });
});
