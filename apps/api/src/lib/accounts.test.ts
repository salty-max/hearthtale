import { describe, expect, test } from "bun:test";
import { owns } from "@/lib/accounts";

describe("accounts", () => {
  test("a character is the account's in its own region only", () => {
    const account = { owned: [{ region: "eu" as const, ids: [64379064, 12] }] };
    expect(owns(account, "eu", 64379064)).toBe(true);
    expect(owns(account, "us", 64379064)).toBe(false);
    expect(owns(account, "eu", 13)).toBe(false);
  });
});
