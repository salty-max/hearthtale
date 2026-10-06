import { describe, expect, test } from "bun:test";
import { standaloneGap } from "@/lib/standalone";

describe("standalone gap", () => {
  test("the strip the window misses at the bottom", () => {
    expect(standaloneGap(932, 430, 885, 430)).toBe(47); // short by the status bar's height
    expect(standaloneGap(932, 430, 932, 430)).toBe(0); // fills the screen
    expect(standaloneGap(932, 430, 700, 430)).toBe(0); // a browser's toolbars: not ours to fill
    expect(standaloneGap(932, 430, 430, 932)).toBe(0); // landscape, full
  });
});
