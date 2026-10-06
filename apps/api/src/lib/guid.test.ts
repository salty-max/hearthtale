import { describe, expect, test } from "bun:test";
import { parseGuid, regionNumber, regionOf } from "@/lib/guid";

describe("guid", () => {
  test("a GUID gives the Battle.net realm and character ids", () => {
    expect(parseGuid("Player-6113-03D658B8")).toEqual({ realmId: 6113, characterId: 64379064 });
    expect(parseGuid("Creature-0-4170-0-12-1-00000001")).toBeNull();
    expect(parseGuid("Player-6113-")).toBeNull();
  });
  test("the game's region numbers", () => {
    expect(regionOf(3)).toBe("eu");
    expect(regionOf(1)).toBe("us");
    expect(regionOf(5)).toBeNull();
    expect(regionOf(undefined)).toBeNull();
    expect(regionNumber("eu")).toBe(3);
  });
});
