import { describe, expect, test } from "bun:test";
import { ownedEntry, owns, sexOf } from "@/lib/accounts";

describe("accounts", () => {
  test("a character is the account's in its own region only", () => {
    const account = { owned: [{ region: "eu" as const, ids: [64379064, 12] }] };
    expect(owns(account, "eu", 64379064)).toBe(true);
    expect(owns(account, "us", 64379064)).toBe(false);
    expect(owns(account, "eu", 13)).toBe(false);
  });
  test("a character's sex, as Battle.net's sign-in gave it", () => {
    const account = { owned: [{ region: "eu" as const, ids: [11, 12, 13], women: [11], men: [12] }] };
    expect(sexOf(account, "eu", 11)).toBe(3);
    expect(sexOf(account, "eu", 12)).toBe(2);
    expect(sexOf(account, "eu", 13)).toBeUndefined();
    expect(sexOf(account, "us", 11)).toBeUndefined();
    expect(sexOf({ owned: [{ region: "eu", ids: [11] }] }, "eu", 11)).toBeUndefined();
  });
  test("a sign-in without sexes (Ravenpost's) keeps the ones Battle.net gave", () => {
    const before = { region: "eu" as const, ids: [11, 12], women: [11], men: [12] };
    expect(ownedEntry(before, { region: "eu", owned: [11, 12, 14] })).toEqual({ region: "eu", ids: [11, 12, 14], women: [11], men: [12] });
    expect(ownedEntry(before, { region: "eu", owned: [11], women: [], men: [11] })).toEqual({ region: "eu", ids: [11], women: [], men: [11] });
    expect(ownedEntry(undefined, { region: "eu", owned: [11] })).toEqual({ region: "eu", ids: [11] });
    // (only for the characters still owned)
    expect(ownedEntry(before, { region: "eu", owned: [11] })).toEqual({ region: "eu", ids: [11], women: [11], men: [] });
  });
});
