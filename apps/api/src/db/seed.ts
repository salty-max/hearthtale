import type { Book } from "@hearthtale/shared";
import { eq, sql } from "drizzle-orm";
import { db } from "@/db";
import { initDb } from "@/db/local";
import { accounts, characters } from "@/db/schema";
import { TEST_BNET_ID } from "@/lib/accounts";
import { parseGuid } from "@/lib/guid";
import seed from "./seed/characters.json";

// Local test data: characters whose books were written by the addon itself,
// played in the test's fake game (addon/test/seed.lua writes seed/characters.json),
// owned by the test account ("Sign in as the test account", local only).
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
await db.insert(accounts).values({ bnetId: TEST_BNET_ID, battletag: "Test#0000" }).onConflictDoNothing();
const [test] = await db.select().from(accounts).where(eq(accounts.bnetId, TEST_BNET_ID));
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
    bnetCharId: parseGuid(c.guid)?.characterId ?? null,
    ownerId: test.id,
    book: c.book,
  };
  await db
    .insert(characters)
    .values(row)
    .onConflictDoUpdate({ target: characters.guid, set: { ...row, updatedAt: sql`now()` } });
}
await conn.end();
console.log(`Seeded ${(seed as Seed[]).length} characters, owned by the test account`);
