import type { CharacterBook, CharacterSummary } from "@hearthtale/shared";
import { asc, eq } from "drizzle-orm";
import { db } from "@/db";
import { characters, type CharacterRow } from "@/db/schema";

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

export async function listCharacters(): Promise<CharacterSummary[]> {
  const rows = await db.select().from(characters).orderBy(asc(characters.name));
  return rows.map(summary);
}

export async function getCharacterBook(id: number): Promise<CharacterBook | null> {
  const [row] = await db.select().from(characters).where(eq(characters.id, id));
  return row ? { character: summary(row), book: row.book } : null;
}
