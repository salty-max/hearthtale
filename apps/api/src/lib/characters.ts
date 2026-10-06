import type { CharacterBook, CharacterSummary } from "@hearthtale/shared";
import { and, asc, eq } from "drizzle-orm";
import { db } from "@/db";
import { characters, type CharacterRow } from "@/db/schema";

/** Books are private: an account sees its own characters, nobody else does. */

export function summary(row: CharacterRow): CharacterSummary {
  return {
    id: row.id,
    name: row.name,
    realm: row.realm ?? undefined,
    region: row.region ?? undefined,
    race: row.race,
    class: row.class,
    client: row.client,
    level: row.level,
    hardcore: row.hardcore,
    fallen: row.fallen,
    chapters: row.book.chapters.length,
    updatedAt: row.updatedAt.toISOString(),
  };
}

/** The account's characters, for its library. */
export async function libraryOf(accountId: number): Promise<CharacterSummary[]> {
  const rows = await db.select().from(characters).where(eq(characters.ownerId, accountId)).orderBy(asc(characters.name));
  return rows.map(summary);
}

/** A character's book, for its owner only (anyone else: as if it weren't there). */
export async function getCharacterBook(id: number, accountId: number): Promise<CharacterBook | null> {
  const [row] = await db
    .select()
    .from(characters)
    .where(and(eq(characters.id, id), eq(characters.ownerId, accountId)));
  return row ? { character: summary(row), book: row.book } : null;
}
