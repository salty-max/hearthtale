import type { PairPoll, PairStart } from "@hearthtale/shared";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { companionLinks, type CompanionLinkRow } from "@/db/schema";
import { random } from "@/lib/accounts";
import { getTemp, putTemp, takeTemp } from "@/lib/ephemeral";
import { log } from "@/lib/log";

/**
 * Pairing a computer's companion (Ravenpost) with an account, device-code style:
 *
 *   1. companion → POST /api/companion/pair/start → { code, pollToken, url }; it opens `url`
 *   2. on that page (/pair?code=…) the user signs in and confirms: confirmPairing()
 *      creates the link and mints its token (only the token's hash is kept)
 *   3. companion → POST /api/companion/pair/poll → { token } once
 *   4. companion → POST /api/companion/upload (Bearer token) after each logout or /reload
 */

const PAIR_TTL_MS = 10 * 60_000;
// No 0/O or 1/I: the code may be read off one screen and checked on another.
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

// In the ephemeral table (any server instance can answer). The raw token sits
// there only between the confirmation and the companion's next poll.
type Pending = { pollTokenHash: string; result: { token: string; battletag: string | null } | null };

export async function sha256(s: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Buffer.from(h).toString("hex");
}

export function isPairCode(s: unknown): s is string {
  return typeof s === "string" && /^[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(s);
}

export async function startPairing(origin: string): Promise<PairStart> {
  const pick = crypto.getRandomValues(new Uint8Array(8));
  const raw = Array.from(pick, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join("");
  const code = `${raw.slice(0, 4)}-${raw.slice(4)}`;
  const pollToken = random(24);
  await putTemp("pair", code, { pollTokenHash: await sha256(pollToken), result: null } satisfies Pending, PAIR_TTL_MS);
  return { code, pollToken, url: `${origin}/pair?code=${code}`, expiresIn: PAIR_TTL_MS / 1000 };
}

/** Is this code waiting for a confirmation? */
export async function pairingPending(code: string): Promise<boolean> {
  const p = await getTemp<Pending>("pair", code);
  return !!p && !p.result;
}

/** The signed-in user confirms: the companion becomes the account's. */
export async function confirmPairing(code: string, account: { id: number; battletag: string | null }): Promise<boolean> {
  const p = await getTemp<Pending>("pair", code);
  if (!p || p.result) return false;
  const token = random(32);
  await db.insert(companionLinks).values({ tokenHash: await sha256(token), accountId: account.id });
  await putTemp("pair", code, { ...p, result: { token, battletag: account.battletag } } satisfies Pending, PAIR_TTL_MS);
  log.info("companion.paired", { account: account.id });
  return true;
}

export async function pollPairing(code: string, pollToken: string): Promise<PairPoll> {
  const p = await getTemp<Pending>("pair", code);
  if (!p || p.pollTokenHash !== (await sha256(pollToken))) return { status: "expired" };
  if (!p.result) return { status: "pending" };
  // The token is handed over exactly once: whoever deletes the row gets it.
  const taken = await takeTemp<Pending>("pair", code);
  return taken?.result ? { status: "paired", ...taken.result } : { status: "expired" };
}

export async function linkFor(token: string): Promise<CompanionLinkRow | null> {
  if (!token || token.length > 100) return null;
  const [link] = await db.select().from(companionLinks).where(eq(companionLinks.tokenHash, await sha256(token)));
  return link ?? null;
}
