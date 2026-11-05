import { REGIONS, type Region } from "@hearthtale/shared";
import { createPublicKey, verify } from "node:crypto";
import { db } from "@/db";
import { companionLinks, type AccountRow, type ForeverChar } from "@/db/schema";
import { loginAccount, random, touchAccount } from "@/lib/accounts";
import { sha256 } from "@/lib/companion";
import { getTemp, putTemp } from "@/lib/ephemeral";
import { log } from "@/lib/log";

/**
 * Signing in through Ravenpost: one Battle.net sign-in links every site it
 * carries for. Ravenpost's inbox (salty-max/ravenpost, inbox/) signs the
 * player in and hands Ravenpost a passport: the account's Battle.net id,
 * BattleTag and the characters it owns in each region, signed with the
 * inbox's Ed25519 key; ten minutes, once. Ravenpost hands it on here at once
 * (POST /api/companion/signin), and gets its upload token as a pairing would.
 * Only the public key is here: it checks a passport, it can't make one.
 */
const PUBLIC_KEY = `-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAAog81ED5lbPfcqS53IWB3ON5z1j5wu1TeUoefrEUFlQ=
-----END PUBLIC KEY-----`;
// (the inbox's key for this computer only, INBOX_DEV: never trusted on Vercel)
const DEV_PUBLIC_KEY = `-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAgiDVP8BHwyQ9D6WYy8rla/Ih/n67iDY66l0WEMqCv1M=
-----END PUBLIC KEY-----`;

export type Passport = { aud: string; bnetId: number; battletag: string; owned: { region: string; game?: string; ids: number[]; characters?: unknown[] }[]; iat: number; exp: number; jti: string };

/** A Forever entry's tuples, kept only if well formed (a realm of digits, a short name, an id the entry lists). */
export function foreverChars(v: unknown, ids: number[]): ForeverChar[] {
  if (!Array.isArray(v)) return [];
  const out: ForeverChar[] = [];
  for (const t of v.slice(0, 500)) {
    if (!Array.isArray(t) || t.length < 3) continue;
    const [id, realm, name] = t;
    if (Number.isSafeInteger(id) && ids.includes(id) && typeof realm === "string" && /^\d{1,9}$/.test(realm) && typeof name === "string" && name.length > 0 && name.length <= 80) out.push([id, realm, name]);
  }
  return out;
}

const keys = () => [PUBLIC_KEY, ...(process.env.VERCEL ? [] : [DEV_PUBLIC_KEY])].map((k) => createPublicKey(k));
const isRegion = (r: unknown): r is Region => typeof r === "string" && (REGIONS as string[]).includes(r);

/** The passport's account, if a key of the inbox signed it and it's for the sites, still fresh. */
export function readPassport(passport: unknown): Passport | null {
  if (typeof passport !== "string" || passport.length > 20_000) return null;
  const [body, sig] = passport.split(".");
  if (!body || !sig) return null;
  const signed = keys().some((k) => {
    try {
      return verify(null, Buffer.from(body), k, Buffer.from(sig, "base64url"));
    } catch {
      return false;
    }
  });
  if (!signed) return null;
  try {
    const p = JSON.parse(Buffer.from(body, "base64url").toString()) as Passport;
    const fresh = typeof p.exp === "number" && p.exp > Date.now() / 1000;
    const shaped = p.aud === "sites" && Number.isSafeInteger(p.bnetId) && typeof p.jti === "string" && Array.isArray(p.owned);
    return fresh && shaped ? p : null;
  } catch {
    return null;
  }
}

/** A passport into the account (its characters per region) and a new upload token for its Ravenpost. */
export async function signInWithPassport(passport: unknown): Promise<{ token: string; battletag: string | null } | null> {
  const p = readPassport(passport);
  if (!p) return null;
  // (once: a passport seen before is refused)
  if (await getTemp("passport", p.jti)) return null;
  await putTemp("passport", p.jti, true, 15 * 60_000);
  const battletag = p.battletag || null;
  let account: AccountRow | undefined;
  for (const o of p.owned) {
    const game = o.game ?? "classic1x";
    if (!isRegion(o.region) || !Array.isArray(o.ids) || (game !== "classic1x" && game !== "forever")) continue;
    const ids = o.ids.filter((id) => Number.isSafeInteger(id));
    // Forever's proof is the tuples [id, realm, "Name Surname"], each shaped and its id among `ids`.
    const characters = game === "forever" ? foreverChars(o.characters, ids) : undefined;
    account = await loginAccount({ bnetId: p.bnetId, battletag, game, region: o.region, owned: characters ? characters.map(([id]) => id) : ids, characters });
  }
  if (!account) {
    // (no characters Battle.net lists: the account, its owned characters untouched)
    account = await touchAccount(p.bnetId, battletag);
  }
  const token = random(32);
  await db.insert(companionLinks).values({ tokenHash: await sha256(token), accountId: account.id });
  log.info("companion.signin", { account: account.id, regions: p.owned.length });
  return { token, battletag };
}
