import type { Book } from "@hearthtale/shared";
import { describe, expect, test } from "bun:test";
import { epub, fileName, markdown } from "@/lib/export";
import { strings } from "@/lib/i18n";
import { crc32, zip } from "@/lib/zip";

const t = strings("en");
const who = { name: "Brannok", race: "Dwarf", class: "HUNTER", level: 9, hardcore: true, fallen: false, realm: "Nightslayer", region: 1 };
const book: Book = {
  client: "classic",
  at: 1791000000,
  prologue: "Before <all> & after.",
  chapters: [
    { number: 1, title: "The Troll Cave", place: "Anvilmar", from: 1, to: 4, diary: "One.\n\nTwo.", note: "My own words." },
    { number: 2, place: "Kharanos", from: 4, to: 7, diary: "Three.", open: true },
  ],
};

describe("export", () => {
  test("a file's name, safe anywhere", () => {
    expect(fileName({ ...who, name: "Aélyndra" })).toBe("Aelyndra-journal");
  });
  test("as text: every part, in order, with the notes", () => {
    const md = markdown(t, "en-GB", who, book);
    expect(md).toContain("# The journal of Brannok");
    expect(md).toContain("*Level 9 Dwarf Hunter · Nightslayer (US)*");
    expect(md.indexOf("## Prologue")).toBeLessThan(md.indexOf("## The Troll Cave"));
    expect(md).toContain("*Entry 1 · Anvilmar · levels 1 to 4*");
    expect(md).toContain("> My own words.");
    expect(md).toContain("## Entry 2");
  });
  test("a zip: its signatures and its files' checksums", () => {
    expect(crc32(new TextEncoder().encode("hello"))).toBe(0x3610a686);
    const z = zip([{ name: "a.txt", data: "hello" }]);
    const v = new DataView(z.buffer);
    expect(v.getUint32(0, true)).toBe(0x04034b50);
    expect(v.getUint32(14, true)).toBe(0x3610a686);
    expect(v.getUint32(z.length - 22, true)).toBe(0x06054b50);
  });
  test("an EPUB: the mimetype first and stored, every part a page, the text escaped", () => {
    const e = epub(t, "en-GB", who, book, "1");
    const head = new TextDecoder().decode(e.slice(30, 30 + 8 + 20));
    expect(head).toBe("mimetypeapplication/epub+zip");
    const all = new TextDecoder().decode(e);
    expect(all).toContain("OEBPS/part-3.xhtml");
    expect(all).toContain("Before &lt;all&gt; &amp; after.");
    expect(all).toContain('properties="nav"');
  });
});
