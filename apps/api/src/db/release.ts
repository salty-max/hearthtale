import { eq } from "drizzle-orm";
import { db } from "@/db";
import { databaseUrl, initDb } from "@/db/local";
import { accounts, characters } from "@/db/schema";
import { parseGuid } from "@/lib/guid";

// A character another account holds by a link code, released by hand after a
// player's report checks out (a code never moves an owned character, so on
// Forever, where Battle.net lists none, a squatted GUID has no other way back).
// Best handed to the verified owner's account (--to): their next upload is
// theirs with no code, and nobody can race them to a free row. Without --to the
// row and its book go, and the next link code attaches it.
//   bun run db:release Player-6113-0B4A2201                 (shows it)
//   bun run db:release Player-6113-0B4A2201 --to 42 --yes   (gives it to account 42)
//   bun run db:release Player-6113-0B4A2201 --yes           (deletes it)
// From the repository's root, Bun loads .env.local: that is Neon's production.
const args = process.argv.slice(2);
const [guid, yes] = [args[0], args.includes("--yes")];
const toArg = args.includes("--to") ? args[args.indexOf("--to") + 1] : undefined;
const to = toArg != null && /^\d+$/.test(toArg) ? Number(toArg) : undefined;
if (!guid || !parseGuid(guid) || (toArg !== undefined && to === undefined)) {
  console.error("usage: bun run db:release <Player-GUID> [--to <account id>] [--yes]");
  process.exit(1);
}
console.log(`database: ${new URL(databaseUrl()).host}`);
const conn = initDb();
const [row] = await db
  .select({ id: characters.id, name: characters.name, realm: characters.realm, owner: accounts.battletag, ownerId: characters.ownerId, updatedAt: characters.updatedAt, book: characters.book })
  .from(characters)
  .leftJoin(accounts, eq(accounts.id, characters.ownerId))
  .where(eq(characters.guid, guid));
if (!row) {
  console.log(`no character ${guid}`);
} else {
  console.log(`${row.name} (${row.realm ?? "?"}), held by ${row.owner ?? "nobody"} (account ${row.ownerId ?? "-"}), last upload ${row.updatedAt.toISOString()}, ${row.book.chapters.length} entries`);
  const [account] = to != null ? await db.select({ battletag: accounts.battletag }).from(accounts).where(eq(accounts.id, to)) : [];
  if (to != null && !account) console.log(`no account ${to}: nothing changed`);
  else if (!yes) console.log(to != null ? `nothing changed (--yes gives it to ${account.battletag ?? "?"}, account ${to})` : "nothing changed (--yes deletes it)");
  else if (to != null) {
    await db.update(characters).set({ ownerId: to }).where(eq(characters.id, row.id));
    console.log(`given to ${account.battletag ?? "?"} (account ${to}): their next upload replaces the book`);
  } else {
    await db.delete(characters).where(eq(characters.id, row.id));
    console.log("released: the next link code attaches it");
  }
}
await conn.end();
