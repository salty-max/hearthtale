import { describe, expect, test } from "bun:test";
import seed from "@/db/seed/characters.json";
import { decide, parseBook, parseCharacter } from "@/lib/upload";

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
  test("the player's own note in an entry's margin", () => {
    const [ch] = parseBook({ client: "classic", at: 1, chapters: [{ number: 1, diary: "The entry.", note: "Cold, all of it." }] })!.chapters;
    expect(ch.note).toBe("Cold, all of it.");
    expect(parseBook({ client: "classic", at: 1, chapters: [{ number: 1, note: "x".repeat(3_000) }] })!.chapters[0].note).toBeUndefined();
  });
  test("a chapter's diary entry, kept beside its prose", () => {
    const [ch] = parseBook({ client: "classic", at: 1, chapters: [{ number: 1, text: "The chapter.", diary: "The entry." }] })!.chapters;
    expect(ch.diary).toBe("The entry.");
    expect(ch.text).toBe("The chapter.");
  });
});

describe("whose book", () => {
  const no = { removedHere: false, alreadyMine: false, ownsOnBnet: false };
  const code = (owner: number | null) => async () => owner;
  test("the companion's account, if it has the character or owns it on Battle.net", async () => {
    expect(await decide(7, { ...no, alreadyMine: true }, code(null))).toEqual({ owner: 7, status: "saved", lift: false });
    expect(await decide(7, { ...no, ownsOnBnet: true }, code(null))).toEqual({ owner: 7, status: "saved", lift: false });
  });
  test("else a link code's account, else it waits for a link", async () => {
    expect(await decide(7, no, code(9))).toEqual({ owner: 9, status: "saved", lift: false });
    expect(await decide(7, no, code(null))).toEqual({ owner: null, status: "unlinked", lift: false });
  });
  test("a book its owner removed waits for a new code, which brings it back", async () => {
    const removed = { removedHere: true, alreadyMine: true, ownsOnBnet: true };
    expect(await decide(7, removed, code(null))).toEqual({ owner: null, status: "removed", lift: false });
    expect(await decide(7, removed, code(7))).toEqual({ owner: 7, status: "saved", lift: true });
  });
});
