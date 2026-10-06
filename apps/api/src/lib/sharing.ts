import type { Book, HallEntry, PublicCharacter, Share, SharedBook } from "@hearthtale/shared";
import { and, desc, eq } from "drizzle-orm";
import { db } from "@/db";
import { characters, shares, type CharacterRow } from "@/db/schema";
import { random } from "@/lib/accounts";
import { appOrigin } from "@/lib/login";

/**
 * Sharing: a link reads the whole book or one part of it, nothing else of the
 * account's; the owner makes and revokes them. A fallen book can be shown in
 * the public Hall of the Fallen, by its owner's choice.
 */

export function publicCharacter(row: CharacterRow): PublicCharacter {
  return {
    name: row.name,
    realm: row.realm ?? undefined,
    region: row.region ?? undefined,
    race: row.race,
    class: row.class,
    level: row.level,
    hardcore: row.hardcore,
    fallen: row.fallen,
  };
}

/** The book cut to one part ("prologue", a chapter's number, "epitaph"), or whole; null if there's no such part. */
export function cutBook(book: Book, part?: string): Book | null {
  if (part === undefined) return book;
  const base = { version: book.version, client: book.client, at: book.at, level: book.level, chapters: [] };
  if (part === "prologue") return book.prologue ? { ...base, prologue: book.prologue } : null;
  if (part === "epitaph") return book.epitaph ? { ...base, epitaph: book.epitaph } : null;
  const ch = /^\d+$/.test(part) ? book.chapters.find((c) => c.number === Number(part)) : undefined;
  return ch ? { ...base, chapters: [ch] } : null;
}

export const shareUrl = (token: string) => `${appOrigin()}/s/${token}`;

const toShare = (s: { token: string; part: string | null; createdAt: Date }): Share => ({
  token: s.token,
  part: s.part ?? undefined,
  url: shareUrl(s.token),
  createdAt: s.createdAt.toISOString(),
});

async function ownBook(id: number, accountId: number): Promise<CharacterRow | null> {
  const [row] = await db
    .select()
    .from(characters)
    .where(and(eq(characters.id, id), eq(characters.ownerId, accountId)));
  return row ?? null;
}

export async function listShares(id: number, accountId: number): Promise<Share[] | null> {
  if (!(await ownBook(id, accountId))) return null;
  const rows = await db.select().from(shares).where(eq(shares.characterId, id)).orderBy(desc(shares.createdAt));
  return rows.map(toShare);
}

/** A new link to the book or one of its parts; null if it isn't the account's or has no such part. */
export async function createShare(id: number, accountId: number, part?: string): Promise<Share | null> {
  const row = await ownBook(id, accountId);
  if (!row || !cutBook(row.book, part)) return null;
  const [s] = await db
    .insert(shares)
    .values({ token: random(12), characterId: id, part: part ?? null })
    .returning();
  return toShare(s);
}

/** Revoke: the link stops working. False if it isn't one of the account's. */
export async function revokeShare(token: string, accountId: number): Promise<boolean> {
  const [s] = await db
    .select({ token: shares.token })
    .from(shares)
    .innerJoin(characters, eq(characters.id, shares.characterId))
    .where(and(eq(shares.token, token), eq(characters.ownerId, accountId)));
  if (!s) return false;
  await db.delete(shares).where(eq(shares.token, token));
  return true;
}

/** What a link shows (null: no such link, revoked, or its part is gone). */
export async function sharedBook(token: string): Promise<SharedBook | null> {
  if (!/^[\w-]{8,40}$/.test(token)) return null;
  const [found] = await db
    .select({ s: shares, c: characters })
    .from(shares)
    .innerJoin(characters, eq(characters.id, shares.characterId))
    .where(eq(shares.token, token));
  if (!found) return null;
  const book = cutBook(found.c.book, found.s.part ?? undefined);
  return book ? { character: publicCharacter(found.c), book, part: found.s.part ?? undefined } : null;
}

/** The owner shows a fallen book in the Hall, or takes it out. False if it isn't the account's or isn't fallen. */
export async function setInHall(id: number, accountId: number, inHall: boolean): Promise<boolean> {
  const row = await ownBook(id, accountId);
  if (!row || (inHall && !row.fallen)) return false;
  await db.update(characters).set({ inHall }).where(eq(characters.id, id));
  return true;
}

export async function hall(): Promise<HallEntry[]> {
  const rows = await db
    .select()
    .from(characters)
    .where(and(eq(characters.inHall, true), eq(characters.fallen, true)))
    .orderBy(desc(characters.updatedAt))
    .limit(200);
  return rows.map((r) => ({
    id: r.id,
    character: publicCharacter(r),
    epitaph: r.book.epitaph,
    chapters: r.book.chapters.length,
    diedAt: r.book.chapters[r.book.chapters.length - 1]?.ended,
  }));
}

export async function hallBook(id: number): Promise<SharedBook | null> {
  const [row] = await db
    .select()
    .from(characters)
    .where(and(eq(characters.id, id), eq(characters.inHall, true), eq(characters.fallen, true)));
  return row ? { character: publicCharacter(row), book: row.book } : null;
}
