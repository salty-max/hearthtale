import type { Book } from "@hearthtale/shared";
import { sql } from "drizzle-orm";
import { db } from "@/db";
import { initDb } from "@/db/local";
import { characters } from "@/db/schema";
import seed from "./seed/characters.json";

// Local test data: characters whose books were written by the addon itself,
// played in the test's fake game (addon/test/seed.lua writes seed/characters.json).
//   bun run db:seed
type Seed = {
  guid: string;
  name: string;
  realm?: string;
  region?: number;
  race: string;
  class: string;
  hardcore: boolean;
  fallen: boolean;
  book: Book;
};

const conn = initDb();
for (const c of seed as Seed[]) {
  const row = {
    guid: c.guid,
    name: c.name,
    realm: c.realm ?? null,
    region: c.region ?? null,
    race: c.race,
    class: c.class,
    client: c.book.client,
    level: c.book.level ?? 1,
    hardcore: c.hardcore,
    fallen: c.fallen,
    book: c.book,
  };
  await db
    .insert(characters)
    .values(row)
    .onConflictDoUpdate({ target: characters.guid, set: { ...row, updatedAt: sql`now()` } });
}
await conn.end();
console.log(`Seeded ${(seed as Seed[]).length} characters`);
