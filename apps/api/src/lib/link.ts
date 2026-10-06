import { putTemp, takeTemp } from "@/lib/ephemeral";
import { log } from "@/lib/log";

/**
 * Link codes, for the characters Battle.net can't list (Forever): the site
 * gives a signed-in account a short code, the player types `/ht link CODE` in
 * the game, the addon keeps it in its saved file, and the upload that carries
 * it attaches the character to the account. One use, thirty minutes.
 */

export const LINK_TTL_MS = 30 * 60_000;
// No 0/O, 1/I/L: read from a phone, typed in the game.
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export function newCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

export function isCode(s: unknown): s is string {
  return typeof s === "string" && /^[A-Za-z0-9]{6}$/.test(s);
}

export async function createLinkCode(accountId: number): Promise<{ code: string; expiresAt: string }> {
  const code = newCode();
  await putTemp("link", code, { accountId }, LINK_TTL_MS);
  return { code, expiresAt: new Date(Date.now() + LINK_TTL_MS).toISOString() };
}

/** An upload carrying a code: the account that asked for it (null: no such code, or used). One use. */
export async function takeLinkCode(code: unknown): Promise<number | null> {
  if (!isCode(code)) return null;
  const found = await takeTemp<{ accountId: number }>("link", code.toUpperCase());
  if (found) log.info("link.claimed", { account: found.accountId });
  return found?.accountId ?? null;
}
