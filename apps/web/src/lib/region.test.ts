import { describe, expect, test } from "bun:test";
import { guessRegion } from "@/lib/region";

describe("region", () => {
  test("from the visitor's time zone", () => {
    expect(guessRegion("Europe/Paris")).toBe("eu");
    expect(guessRegion("America/Chicago")).toBe("us");
    expect(guessRegion("Australia/Sydney")).toBe("us");
    expect(guessRegion("Pacific/Auckland")).toBe("us");
    expect(guessRegion("Asia/Seoul")).toBe("kr");
    expect(guessRegion("Asia/Taipei")).toBe("tw");
    expect(guessRegion("")).toBe("eu");
  });
});
