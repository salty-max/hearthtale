import { describe, expect, test } from "bun:test";
import seed from "@/db/seed/characters.json";
import { parseBook, parseCharacter } from "@/lib/upload";

// The test characters: the addon's own saved records (addon/test/seed.lua).
const brannok = (seed as { book: unknown }[])[0];
const record = (over: Record<string, unknown> = {}) => ({
  guid: "Player-6113-0B4A2201",
  name: "Brannok",
  race: "Dwarf",
  class: "HUNTER",
  realm: "Nightslayer",
  region: 1,
  hardcore: true,
  book: brannok.book,
  ...over,
});

describe("upload", () => {
  test("a record the addon saved reads whole", () => {
    const c = parseCharacter(record({ link: { code: "K7Q2MX", at: 1 } }))!;
    expect(c.name).toBe("Brannok");
    expect(c.region).toBe(1);
    expect(c.book.chapters.length).toBe(3);
    expect(c.book.chapters[2].open).toBe(true);
    expect(c.level).toBe(9);
    expect(c.linkCode).toBe("K7Q2MX");
    expect(c.fallen).toBe(false);
  });
  test("a fallen life is told so", () => {
    expect(parseCharacter(record({ closed: true }))!.fallen).toBe(true);
  });
  test("what isn't a character's record is refused", () => {
    expect(parseCharacter(null)).toBeNull();
    expect(parseCharacter(record({ guid: "Creature-0-1" }))).toBeNull();
    expect(parseCharacter(record({ name: 42 }))).toBeNull();
    expect(parseCharacter(record({ book: undefined }))).toBeNull();
  });
  test("a book: its client, its time, its chapters", () => {
    expect(parseBook({ client: "classic", at: 1, chapters: {} })!.chapters).toEqual([]); // Lua's empty table
    expect(parseBook({ client: "retail", at: 1, chapters: [] })).toBeNull();
    expect(parseBook({ client: "classic", chapters: [] })).toBeNull();
    expect(parseBook({ client: "classic", at: 1, chapters: [{ text: "no number" }] })).toBeNull();
    expect(parseBook({ client: "classic", at: 1, chapters: [{ number: 1, text: "x".repeat(200_000) }] })!.chapters[0].text).toBeUndefined();
  });
});
