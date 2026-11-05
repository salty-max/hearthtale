import { and, eq, gt, inArray, lt } from "drizzle-orm";
import { db } from "@/db";
import type { Region } from "@hearthtale/shared";
import { accounts, characters, sessions, type AccountRow, type ForeverChar, type Game, type Owned } from "@/db/schema";
import { parseGuid, regionNumber } from "@/lib/guid";
import { log } from "@/lib/log";

/**
 * Accounts: a Battle.net login creates (or finds) the account and opens a
 * session. The session is a cookie holding a random token; only its SHA-256 is
 * stored. Logging in also proves which characters are the account's: their
 * books become its own (private to it).
 */

export const SESSION_COOKIE = "ht_session";
/** The test account (local development only): it owns the test characters (db:seed). */
export const TEST_BNET_ID = 0;
export const SESSION_TTL_MS = 180 * 86400_000;
/** A session used after this much of its life gets a fresh expiry. */
const RENEW_AFTER_MS = 86400_000;

export const random = (bytes: number) => Buffer.from(crypto.getRandomValues(new Uint8Array(bytes))).toString("base64url");

async function sha256(s: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Buffer.from(h).toString("hex");
}

/** Forever's pseudo-realms (one for the whole EU region, probed 5 November 2026): a Classic id is never proof for a GUID in one. */
export const FOREVER_REALMS: ReadonlySet<number> = new Set([6946]);

/** A stored entry's game (every entry from before Forever has none: Classic). */
export const gameOf = (o: Pick<Owned, "game">): Game => o.game ?? "classic1x";

export type Login = {
  bnetId: number;
  battletag: string | null;
  game?: Game;
  region: Region;
  owned: number[];
  /** Forever: the list's [id, realm, "Name Surname"]. */
  characters?: ForeverChar[];
  women?: number[];
  men?: number[];
};

/**
 * After a Battle.net login: the account (created on first login), owning
 * `owned` in `game` (Classic when none) and `region`; `women` and `men` among
 * them where Battle.net said (a sign-in without them, Ravenpost's, keeps what
 * was known).
 */
export async function loginAccount(login: Login): Promise<AccountRow> {
  const game = login.game ?? "classic1x";
  const same = (o: Owned) => o.region === login.region && gameOf(o) === game;
  const [found] = await db.select().from(accounts).where(eq(accounts.bnetId, login.bnetId));
  const entry = ownedEntry(found?.owned.find(same), login);
  const owned = [...(found?.owned ?? []).filter((o) => !same(o)), entry];
  const [acc] = found
    ? await db.update(accounts).set({ battletag: login.battletag, owned, lastSeenAt: new Date() }).where(eq(accounts.id, found.id)).returning()
    : await db.insert(accounts).values({ bnetId: login.bnetId, battletag: login.battletag, owned }).returning();
  // Its characters already here are now known to be its own (the GUID's realm decides the game, never the book's word).
  if (login.owned.length) {
    const rows = await db
      .select({ id: characters.id, guid: characters.guid, ownerId: characters.ownerId, bnetCharId: characters.bnetCharId, client: characters.client })
      .from(characters)
      .where(and(eq(characters.region, regionNumber(login.region)), inArray(characters.bnetCharId, login.owned)));
    const mine = rows.filter((r) => {
      const g = parseGuid(r.guid);
      if (!g) return false;
      // (Forever never takes a row another account holds)
      return game === "forever" ? entryOwns(entry, g.realmId, g.characterId) && (r.ownerId == null || r.ownerId === acc.id) : !FOREVER_REALMS.has(g.realmId) && r.client !== "forever";
    });
    if (mine.length) await db.update(characters).set({ ownerId: acc.id }).where(inArray(characters.id, mine.map((r) => r.id)));
    // (and their sex, where Battle.net said: a French page agrees with it until the book keeps its own)
    for (const [sex, ids] of [[3, entry.women], [2, entry.men]] as const) {
      const ofSex = mine.filter((r) => r.bnetCharId != null && ids?.includes(r.bnetCharId)).map((r) => r.id);
      if (ofSex.length) await db.update(characters).set({ sex }).where(inArray(characters.id, ofSex));
    }
    if (game === "forever") log.info("forever.claimed", { account: acc.id, listed: login.owned.length, rows: rows.length, owned: mine.length });
  }
  log.info("account.login", { account: acc.id, game, region: login.region, owned: login.owned.length, created: !found });
  return acc;
}

/** A sign-in that learned no characters: the account (created if new), its owned entries untouched. */
export async function touchAccount(bnetId: number, battletag: string | null): Promise<AccountRow> {
  const [found] = await db.select().from(accounts).where(eq(accounts.bnetId, bnetId));
  return found
    ? (await db.update(accounts).set({ battletag, lastSeenAt: new Date() }).where(eq(accounts.id, found.id)).returning())[0]
    : (await db.insert(accounts).values({ bnetId, battletag }).returning())[0];
}

/** An entry after a login: its ids, the sexes Battle.net gave (none given: the ones known before), Forever's realms. */
export function ownedEntry(before: Owned | undefined, login: Pick<Login, "game" | "region" | "owned" | "characters" | "women" | "men">): Owned {
  const still = (ids?: number[]) => ids?.filter((id) => login.owned.includes(id));
  const women = login.women ?? still(before?.women);
  const men = login.men ?? still(before?.men);
  const forever = login.game === "forever";
  return { ...(forever && { game: "forever" as const }), region: login.region, ids: login.owned, ...(women && { women }), ...(men && { men }), ...(forever && login.characters && { characters: login.characters }) };
}

/** Does this entry list the character (id) in this realm? Forever: by the list's [id, realm, name] tuple only. */
function entryOwns(o: Owned, realmId: number, bnetCharId: number): boolean {
  if (gameOf(o) === "forever") return !!o.characters?.some(([id, realm]) => id === bnetCharId && realm === String(realmId));
  return o.ids.includes(bnetCharId);
}

function entryFor(account: Pick<AccountRow, "owned">, game: Game, region: Region): Owned | undefined {
  return account.owned.find((x) => x.region === region && gameOf(x) === game);
}

/**
 * A Battle.net character's sex, as the account's last Battle.net sign-in gave
 * it (2 a man, 3 a woman), else none. `realmId` is the GUID's realm part.
 */
export function sexOf(account: Pick<AccountRow, "owned">, game: Game, region: Region, realmId: number, bnetCharId: number): 2 | 3 | undefined {
  const o = entryFor(account, game, region);
  if (!o || !entryOwns(o, realmId, bnetCharId) || (game === "classic1x" && FOREVER_REALMS.has(realmId))) return undefined;
  return o.women?.includes(bnetCharId) ? 3 : o.men?.includes(bnetCharId) ? 2 : undefined;
}

/**
 * Does the account own this character (per its last login)? Classic: the id in
 * the region, but never in a Forever realm. Forever: the GUID's realm and id
 * both in the list (a Forever id and a Classic id are different numbers).
 */
export function owns(account: Pick<AccountRow, "owned">, game: Game, region: Region, realmId: number, bnetCharId: number): boolean {
  const o = entryFor(account, game, region);
  return !!o && entryOwns(o, realmId, bnetCharId) && (game === "forever" || !FOREVER_REALMS.has(realmId));
}

/**
 * The fallback if the GUID's reading is wrong: the character's full name
 * against the Forever list's, within the region. Off unless FOREVER_NAME_MATCH=1
 * (a name is no tie to a GUID: the caller never lets it take a row another
 * account holds).
 */
export function ownsByName(account: Pick<AccountRow, "owned">, region: Region, fullName: string): boolean {
  if (process.env.FOREVER_NAME_MATCH !== "1") return false;
  const want = fullName.trim().toLowerCase();
  return !!want && !!entryFor(account, "forever", region)?.characters?.some(([, , name]) => name.trim().toLowerCase() === want);
}

export async function createSession(accountId: number): Promise<string> {
  const token = random(32);
  await db.insert(sessions).values({ tokenHash: await sha256(token), accountId, expiresAt: new Date(Date.now() + SESSION_TTL_MS) });
  return token;
}

/** The account behind a session cookie (null: none, expired or revoked). */
export async function sessionAccount(token: string | undefined): Promise<AccountRow | null> {
  if (!token || token.length > 100) return null;
  const hash = await sha256(token);
  const [row] = await db
    .select({ a: accounts, expiresAt: sessions.expiresAt })
    .from(sessions)
    .innerJoin(accounts, eq(accounts.id, sessions.accountId))
    .where(and(eq(sessions.tokenHash, hash), gt(sessions.expiresAt, new Date())));
  if (!row) return null;
  // Sliding expiry, written at most once a day.
  if (row.expiresAt.getTime() - Date.now() < SESSION_TTL_MS - RENEW_AFTER_MS) {
    await db.update(sessions).set({ expiresAt: new Date(Date.now() + SESSION_TTL_MS) }).where(eq(sessions.tokenHash, hash));
    await db.update(accounts).set({ lastSeenAt: new Date() }).where(eq(accounts.id, row.a.id));
  }
  return row.a;
}

export async function endSession(token: string | undefined): Promise<void> {
  if (token) await db.delete(sessions).where(eq(sessions.tokenHash, await sha256(token)));
}

export async function sweepSessions(): Promise<number> {
  const gone = await db.delete(sessions).where(lt(sessions.expiresAt, new Date())).returning({ h: sessions.tokenHash });
  return gone.length;
}
