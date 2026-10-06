import type { Book, BookChapter, Client, UploadResult } from "@hearthtale/shared";
import { eq, sql } from "drizzle-orm";
import { db } from "@/db";
import { accounts, characters, companionLinks, type CompanionLinkRow } from "@/db/schema";
import { owns } from "@/lib/accounts";
import { parseGuid, regionOf } from "@/lib/guid";
import { takeLinkCode } from "@/lib/link";
import { log } from "@/lib/log";

/**
 * An upload from a companion: each character's saved record (HearthtaleChar,
 * parsed from the game's saved file), its book written by the addon at logout
 * (addon/Hearthtale/Save.lua). A book is kept only for a proven owner: the
 * companion's account if it owns the character on Battle.net or already had
 * it, else the account of a link code in the record (`/ht link CODE`). Anything
 * else waits, unstored, for a link.
 */

export const MAX_CHARACTERS = 60;
const MAX_CHAPTERS = 2000;
const MAX_TEXT = 100_000;

export type ParsedCharacter = {
  guid: string;
  name: string;
  realm: string | null;
  region: number | null;
  race: string;
  class: string;
  hardcore: boolean;
  fallen: boolean;
  level: number;
  book: Book;
  linkCode: string | null;
};

const obj = (v: unknown): Record<string, unknown> | null => (v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null);
const str = (v: unknown, max = 200): string | undefined => (typeof v === "string" && v.length <= max ? v : undefined);
const int = (v: unknown): number | undefined => (typeof v === "number" && Number.isFinite(v) ? Math.trunc(v) : undefined);
const bool = (v: unknown): boolean => v === true;
/** A Lua list: an array, or an empty table (parsed as {}). */
const list = (v: unknown): unknown[] | null => (Array.isArray(v) ? v : obj(v) && Object.keys(v as object).length === 0 ? [] : null);

function chapter(v: unknown): BookChapter | null {
  const c = obj(v);
  const number = int(c?.number);
  if (!c || number == null || number < 1) return null;
  return {
    number,
    text: str(c.text, MAX_TEXT),
    place: str(c.place),
    from: int(c.from) ?? 1,
    to: int(c.to) ?? int(c.from) ?? 1,
    open: bool(c.open) || undefined,
    rare: bool(c.rare) || undefined,
    close: bool(c.close) || undefined,
    began: int(c.began),
    ended: int(c.ended),
  };
}

/** A book as the addon saved it, or null if it isn't one. */
export function parseBook(v: unknown): Book | null {
  const b = obj(v);
  const client = b?.client;
  const at = int(b?.at);
  const chapters = list(b?.chapters);
  if (!b || (client !== "classic" && client !== "forever") || at == null || !chapters || chapters.length > MAX_CHAPTERS) return null;
  const parsed = chapters.map(chapter);
  if (parsed.some((c) => !c)) return null;
  return {
    version: str(b.version, 20),
    client: client as Client,
    at,
    level: int(b.level),
    prologue: str(b.prologue, MAX_TEXT),
    epitaph: str(b.epitaph, MAX_TEXT),
    chapters: parsed as BookChapter[],
  };
}

/** One character's saved record (HearthtaleChar), or null if it can't be read. */
export function parseCharacter(v: unknown): ParsedCharacter | null {
  const c = obj(v);
  const guid = str(c?.guid, 60);
  const name = str(c?.name, 60);
  if (!c || !guid || !parseGuid(guid) || !name) return null;
  const book = parseBook(c.book);
  if (!book) return null;
  const link = obj(c.link);
  return {
    guid,
    name,
    realm: str(c.realm, 60) ?? null,
    region: int(c.region) ?? null,
    race: str(c.race, 30) ?? "",
    class: str(c.class, 30) ?? "",
    hardcore: bool(c.hardcore),
    fallen: bool(c.closed),
    level: book.level ?? 1,
    book,
    linkCode: str(link?.code, 10) ?? null,
  };
}

export async function handleUpload(link: CompanionLinkRow, body: unknown): Promise<UploadResult> {
  const result: UploadResult = { characters: [] };
  const [account] = await db.select().from(accounts).where(eq(accounts.id, link.accountId));
  const records = list(obj(body)?.characters) ?? [];
  for (const raw of records.slice(0, MAX_CHARACTERS)) {
    const c = parseCharacter(raw);
    if (!c) {
      result.characters.push({ guid: str(obj(raw)?.guid, 60) ?? "?", name: str(obj(raw)?.name, 60) ?? "?", status: "invalid" });
      continue;
    }
    const ids = parseGuid(c.guid)!;
    const region = regionOf(c.region);
    const [row] = await db.select({ id: characters.id, ownerId: characters.ownerId }).from(characters).where(eq(characters.guid, c.guid));
    let owner: number | null = null;
    if (row?.ownerId === link.accountId || (region && account && owns(account, region, ids.characterId))) owner = link.accountId;
    // A code typed in the game: used once, only when nothing else proves it.
    if (owner == null && c.linkCode) owner = await takeLinkCode(c.linkCode);
    if (owner == null) {
      result.characters.push({ guid: c.guid, name: c.name, status: "unlinked" });
      continue;
    }
    const values = {
      guid: c.guid,
      name: c.name,
      realm: c.realm,
      region: c.region,
      race: c.race,
      class: c.class,
      client: c.book.client,
      level: c.level,
      hardcore: c.hardcore,
      fallen: c.fallen,
      bnetCharId: ids.characterId,
      ownerId: owner,
      book: c.book,
    };
    const [saved] = await db
      .insert(characters)
      .values(values)
      .onConflictDoUpdate({ target: characters.guid, set: { ...values, updatedAt: sql`now()` } })
      .returning({ id: characters.id });
    result.characters.push({ guid: c.guid, name: c.name, status: "saved", chapters: c.book.chapters.length, characterId: saved.id });
  }
  await db.update(companionLinks).set({ lastUploadAt: new Date() }).where(eq(companionLinks.id, link.id));
  log.info("upload", { account: link.accountId, saved: result.characters.filter((r) => r.status === "saved").length, of: records.length });
  return result;
}
