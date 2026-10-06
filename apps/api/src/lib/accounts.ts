import { and, eq, gt, inArray, lt } from "drizzle-orm";
import { db } from "@/db";
import type { Region } from "@hearthtale/shared";
import { accounts, characters, sessions, type AccountRow } from "@/db/schema";
import { regionNumber } from "@/lib/guid";
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

/** After a Battle.net login: the account (created on first login), owning `owned` in `region`. */
export async function loginAccount(login: { bnetId: number; battletag: string | null; region: Region; owned: number[] }): Promise<AccountRow> {
  const [found] = await db.select().from(accounts).where(eq(accounts.bnetId, login.bnetId));
  const owned = [...(found?.owned ?? []).filter((o) => o.region !== login.region), { region: login.region, ids: login.owned }];
  const [acc] = found
    ? await db.update(accounts).set({ battletag: login.battletag, owned, lastSeenAt: new Date() }).where(eq(accounts.id, found.id)).returning()
    : await db.insert(accounts).values({ bnetId: login.bnetId, battletag: login.battletag, owned }).returning();
  // Its characters already here are now known to be its own.
  if (login.owned.length) {
    await db
      .update(characters)
      .set({ ownerId: acc.id })
      .where(and(eq(characters.region, regionNumber(login.region)), inArray(characters.bnetCharId, login.owned)));
  }
  log.info("account.login", { account: acc.id, region: login.region, owned: login.owned.length, created: !found });
  return acc;
}

/** Does the account own this Battle.net character (per its last login)? */
export function owns(account: Pick<AccountRow, "owned">, region: Region, bnetCharId: number): boolean {
  return account.owned.some((o) => o.region === region && o.ids.includes(bnetCharId));
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
