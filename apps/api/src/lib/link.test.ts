import { describe, expect, test } from "bun:test";
import { isCode, newCode } from "@/lib/link";

describe("link codes", () => {
  test("six characters, none easy to misread", () => {
    for (let i = 0; i < 200; i++) {
      const c = newCode();
      expect(isCode(c)).toBe(true);
      expect(/[01OIL]/.test(c)).toBe(false);
    }
  });
  test("anything else is no code", () => {
    expect(isCode("abc")).toBe(false);
    expect(isCode("ABCDEFG")).toBe(false);
    expect(isCode(42)).toBe(false);
    expect(isCode("k7q2mx")).toBe(true); // typed in lower case: fine
  });
});

import { safeNext } from "@/lib/login";
describe("after signing in", () => {
  test("only a page of this site to return to", () => {
    expect(safeNext("/pair?code=ABCD-EFGH")).toBe("/pair?code=ABCD-EFGH");
    expect(safeNext("https://evil.example")).toBeUndefined();
    expect(safeNext("//evil.example")).toBeUndefined();
    expect(safeNext(undefined)).toBeUndefined();
  });
});
