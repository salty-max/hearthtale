import type { Book } from "@hearthtale/shared";
import { describe, expect, test } from "bun:test";
import { finishedSince, newEntryMessage } from "@/lib/push";

const book = (chapters: Book["chapters"]): Book => ({ client: "classic", at: 1, chapters });
const ch = (number: number, open = false, title?: string) => ({ number, from: 1, to: 2, open: open || undefined, title, place: "Kharanos" });

describe("notifications", () => {
  test("the entries an upload finished that the book before hadn't", () => {
    expect(finishedSince(null, book([ch(1), ch(2)]))).toEqual([]); // (a first upload: nothing new to the player)
    expect(finishedSince(book([ch(1), ch(2, true)]), book([ch(1), ch(2, true)]))).toEqual([]);
    expect(finishedSince(book([ch(1), ch(2, true)]), book([ch(1), ch(2), ch(3, true)])).map((c) => c.number)).toEqual([2]);
    expect(finishedSince(book([ch(1)]), book([ch(1), ch(2), ch(3)])).map((c) => c.number)).toEqual([2, 3]);
  });
  test("what the device says", () => {
    expect(newEntryMessage("Brannok", 7, [ch(3, false, "Bristle")])).toEqual({
      title: "Brannok wrote “Bristle”",
      body: "Entry 3 · Kharanos",
      url: "/book/7/3",
      tag: "book-7",
    });
    expect(newEntryMessage("Brannok", 7, [ch(2), ch(3)]).title).toBe("Brannok wrote 2 new entries");
  });
});
