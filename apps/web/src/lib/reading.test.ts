import { describe, expect, test } from "bun:test";
import { isReading, pageOf } from "@/lib/reading";

describe("reading", () => {
  test("the pages that are a book being read", () => {
    for (const p of ["/book/3/2", "/book/3/prologue", "/s/abcDEF123", "/hall/4"]) expect(isReading(p)).toBe(true);
    for (const p of ["/book/3", "/book/3/road", "/library", "/hall", "/"]) expect(isReading(p)).toBe(false);
  });
  test("one page for all of a book's parts, so turning one keeps the reader", () => {
    expect(pageOf("/book/3/2")).toBe("/book/3");
    expect(pageOf("/book/3/epitaph")).toBe("/book/3");
    expect(pageOf("/book/3")).toBe("/book/3");
    expect(pageOf("/book/3/road")).toBe("/book/3/road");
    expect(pageOf("/library")).toBe("/library");
  });
});
