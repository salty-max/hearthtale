import { describe, expect, test } from "bun:test";
import { isReading } from "@/lib/reading";

describe("reading", () => {
  test("the pages that are a book being read", () => {
    for (const p of ["/book/3/2", "/book/3/prologue", "/s/abcDEF123", "/hall/4"]) expect(isReading(p)).toBe(true);
    for (const p of ["/book/3", "/book/3/road", "/library", "/hall", "/"]) expect(isReading(p)).toBe(false);
  });
});
