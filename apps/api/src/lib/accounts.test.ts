import { describe, expect, test } from "bun:test";
import { gameOf, ownedEntry, owns, ownsByName, sexOf } from "@/lib/accounts";
import { foreverTuple } from "@/lib/bnet";
import { proof } from "@/lib/upload";
import { foreverChars } from "@/lib/ravenpost";
import type { ForeverChar, Owned } from "@/db/schema";

describe("accounts", () => {
  test("a character is the account's in its own region only", () => {
    const account = { owned: [{ region: "eu" as const, ids: [64379064, 12] }] };
    expect(owns(account, "classic1x", "eu", 5236, 64379064)).toBe(true);
    expect(owns(account, "classic1x", "us", 5236, 64379064)).toBe(false);
    expect(owns(account, "classic1x", "eu", 5236, 13)).toBe(false);
  });
  test("a character's sex, as Battle.net's sign-in gave it", () => {
    const account = { owned: [{ region: "eu" as const, ids: [11, 12, 13], women: [11], men: [12] }] };
    expect(sexOf(account, "classic1x", "eu", 5236, 11)).toBe(3);
    expect(sexOf(account, "classic1x", "eu", 5236, 12)).toBe(2);
    expect(sexOf(account, "classic1x", "eu", 5236, 13)).toBeUndefined();
    expect(sexOf(account, "classic1x", "us", 5236, 11)).toBeUndefined();
    expect(sexOf({ owned: [{ region: "eu", ids: [11] }] }, "classic1x", "eu", 5236, 11)).toBeUndefined();
  });
  test("a sign-in without sexes (Ravenpost's) keeps the ones Battle.net gave", () => {
    const before = { region: "eu" as const, ids: [11, 12], women: [11], men: [12] };
    expect(ownedEntry(before, { region: "eu", owned: [11, 12, 14] })).toEqual({ region: "eu", ids: [11, 12, 14], women: [11], men: [12] });
    expect(ownedEntry(before, { region: "eu", owned: [11], women: [], men: [11] })).toEqual({ region: "eu", ids: [11], women: [], men: [11] });
    expect(ownedEntry(undefined, { region: "eu", owned: [11] })).toEqual({ region: "eu", ids: [11] });
    // (only for the characters still owned)
    expect(ownedEntry(before, { region: "eu", owned: [11] })).toEqual({ region: "eu", ids: [11], women: [11], men: [] });
  });

  test("an entry stored before Forever is Classic, unchanged", () => {
    const stored: Owned = { region: "eu", ids: [64379064], women: [64379064] };
    expect(gameOf(stored)).toBe("classic1x");
    const account = { owned: [stored] };
    expect(owns(account, "classic1x", "eu", 6113, 64379064)).toBe(true);
    expect(owns(account, "forever", "eu", 6113, 64379064)).toBe(false);
    expect(ownedEntry(stored, { region: "eu", owned: [64379064] })).toEqual({ region: "eu", ids: [64379064], women: [64379064] });
  });
});

// The user's three Forever characters (probed 5 November 2026), realm 6946.
const list: ForeverChar[] = [
  [672976, "6946", "Oma Dion"],
  [550204, "6946", "Sealine Dion"],
  [717804, "6946", "Jeanne Dion"],
];
const guid = (realmId: number, id: number) => ({ realmId, characterId: id });
const forever = (extra: Partial<Owned> = {}): Pick<import("@/db/schema").AccountRow, "owned"> => ({
  owned: [{ region: "eu", ids: [111, 222], women: [111] }, { game: "forever", region: "eu", ids: list.map(([id]) => id), women: [550204], men: [672976], characters: list, ...extra }],
});

describe("Forever ownership", () => {
  test("realm and id both from the list: the GUID Player-6946-0008653C is Sealine's", () => {
    expect(parseInt("0008653C", 16)).toBe(550204);
    for (const [id] of list) expect(owns(forever(), "forever", "eu", 6946, id)).toBe(true);
    expect(proof(forever(), "eu", guid(6946, 550204), "Sealine Dion", null)).toEqual({ game: "forever", by: "guid" });
  });
  test("a GUID whose realm differs does not match, and the name fallback is off by default", () => {
    expect(owns(forever(), "forever", "eu", 6113, 550204)).toBe(false);
    expect(owns(forever(), "forever", "us", 6946, 550204)).toBe(false);
    expect(proof(forever(), "eu", guid(6946, 999), "Sealine Dion", null)).toEqual({ game: "forever", by: null });
    expect(ownsByName(forever(), "eu", "Sealine Dion")).toBe(false);
  });
  test("a Classic id is never proof for a Forever GUID, nor a Forever id for a Classic one", () => {
    // (111 is Classic's id; 550204 is Forever's)
    expect(proof(forever(), "eu", guid(6946, 111), "Anyone", null)).toEqual({ game: "forever", by: null });
    expect(proof(forever(), "eu", guid(6113, 111), "Anyone", null)).toEqual({ game: "classic1x", by: "guid" });
    expect(proof(forever(), "eu", guid(6113, 550204), "Anyone", null)).toEqual({ game: "classic1x", by: null });
  });
  test("the name fallback, only when switched on, same region, never over another account's row", () => {
    process.env.FOREVER_NAME_MATCH = "1";
    try {
      expect(ownsByName(forever(), "eu", " sealine dion ")).toBe(true);
      expect(ownsByName(forever(), "us", "Sealine Dion")).toBe(false);
      expect(proof(forever(), "eu", guid(6946, 1), "Sealine Dion", null)).toEqual({ game: "forever", by: "name" });
      expect(proof({ ...forever(), id: 7 } as never, "eu", guid(6946, 1), "Sealine Dion", 8)).toEqual({ game: "forever", by: null });
      expect(proof({ ...forever(), id: 7 } as never, "eu", guid(6946, 550204), "Sealine Dion", 8)).toEqual({ game: "forever", by: null });
      expect(proof({ ...forever(), id: 7 } as never, "eu", guid(6946, 550204), "Sealine Dion", 7)).toEqual({ game: "forever", by: "guid" });
    } finally {
      delete process.env.FOREVER_NAME_MATCH;
    }
  });
  test("a row kept as Forever is never taken on a Classic id, in any realm", () => {
    const account = { owned: [{ region: "us" as const, ids: [550204] }] };
    expect(proof(account, "us", guid(7777, 550204), "x", 5, "forever")).toEqual({ game: "classic1x", by: null });
    expect(proof(account, "us", guid(7777, 550204), "x", 5, "classic")).toEqual({ game: "classic1x", by: "guid" });
  });
  test("an old Classic-only passport: no Forever, nothing changes", () => {
    const account = { owned: [{ region: "eu" as const, ids: [111] }] };
    expect(proof(account, "eu", guid(6946, 111), "Oma Dion", null)).toEqual({ game: "forever", by: null });
    expect(proof(account, "eu", guid(6113, 111), "x", null)).toEqual({ game: "classic1x", by: "guid" });
  });
  test("a Forever entry keeps its own sexes, apart from Classic's", () => {
    expect(sexOf(forever(), "forever", "eu", 6946, 550204)).toBe(3);
    expect(sexOf(forever(), "forever", "eu", 6946, 672976)).toBe(2);
    expect(sexOf(forever(), "forever", "eu", 6113, 550204)).toBeUndefined();
    expect(sexOf(forever(), "classic1x", "eu", 6113, 111)).toBe(3);
  });
  test("the entry written after a Forever login", () => {
    expect(ownedEntry(undefined, { game: "forever", region: "eu", owned: [550204], characters: [list[1]] })).toEqual({ game: "forever", region: "eu", ids: [550204], characters: [list[1]] });
  });
  test("the passport's tuples: only well-formed ones whose id the entry lists", () => {
    const ids = [550204, 672976];
    expect(foreverChars([[550204, "6946", "Sealine Dion"], [672976, "6946", "Oma Dion"]], ids)).toHaveLength(2);
    expect(foreverChars([[1, "6946", "Not Listed"], [550204, 6946, "Number Realm"], [550204, "6946; x", "Bad"], [550204, "6946"], "x", [550204, "6946", ""]], ids)).toEqual([]);
    expect(foreverChars(undefined, ids)).toEqual([]);
  });
  test("the site's sign-in reads the realm from the list's own link, or the character isn't owned", () => {
    const c = { id: 550204, name: "Sealine", surname: "Dion", protected_character: { href: "https://eu.api.blizzard.com/profile/user/wow/protected-character/6946-550204?namespace=profile-forever-eu" } };
    expect(foreverTuple(c)).toEqual([550204, "6946", "Sealine Dion"]);
    expect(foreverTuple({ ...c, protected_character: { href: ".../protected-character/6946-1" } })).toBeNull();
    expect(foreverTuple({ ...c, protected_character: undefined })).toBeNull();
  });
});
