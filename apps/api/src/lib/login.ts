import { accountProfile, authorizeUrl, BnetError, exchangeCode, FLAVOURS, foreverTuple, userInfo } from "@/lib/bnet";
import { REGIONS, type Region } from "@hearthtale/shared";
import { createSession, loginAccount, random, sweepSessions, touchAccount } from "@/lib/accounts";
import { putTemp, sweepTemp, takeTemp } from "@/lib/ephemeral";
import { log } from "@/lib/log";

/**
 * "Sign in with Battle.net": the account, its characters in the chosen region
 * (Classic Era: the game Battle.net can list), a session.
 * The access token is used once, right in the callback, then dropped.
 */

const TTL_MS = 10 * 60_000;
type PendingLogin = { region: Region; next?: string };

export function appOrigin(): string {
  return (process.env.APP_ORIGIN ?? "http://localhost:5175").replace(/\/$/, "");
}

/** Where Blizzard sends the user back: registered on develop.battle.net. */
export function redirectUri(): string {
  return `${appOrigin()}/api/auth/callback`;
}

export function isRegion(r: string | undefined): r is Region {
  return !!r && (REGIONS as string[]).includes(r);
}

/** A page of this site to return to after signing in ("/pair?code=…"), or undefined. */
export function safeNext(next: string | undefined): string | undefined {
  return next && next.startsWith("/") && !next.startsWith("//") && !next.includes("\\") && next.length < 200 ? next : undefined;
}

export async function startLogin(region: Region, next?: string): Promise<string> {
  const state = random(24);
  await putTemp("login", state, { region, next: safeNext(next) } satisfies PendingLogin, TTL_MS);
  // Now and then, the expired logins, codes and sessions go (there is no scheduler).
  if (Math.random() < 0.05) void Promise.all([sweepTemp(), sweepSessions()]).catch(() => {});
  return authorizeUrl(redirectUri(), state);
}

/** Handle Blizzard's redirect: the session token (null if Blizzard didn't say who signed in) and where to go. */
export async function finishLogin(code: string, state: string): Promise<{ session: string | null; next?: string }> {
  const pending = await takeTemp<PendingLogin>("login", state); // one use
  if (!pending) throw new Error("unknown or expired login state");
  const token = await exchangeCode(code, redirectUri());
  const { id: bnetId, battletag } = await userInfo(token).catch(() => ({ id: undefined, battletag: undefined }));
  if (!bnetId) return { session: null };
  let account: Awaited<ReturnType<typeof loginAccount>> | undefined;
  for (const flavour of FLAVOURS) {
    const owned: number[] = [];
    const characters: [number, string, string][] = [];
    // (each character's sex, as Battle.net gives it: a French page agrees with it until the book keeps its own)
    const women: number[] = [];
    const men: number[] = [];
    try {
      const profile = await accountProfile(flavour, pending.region, token);
      for (const acc of profile.wow_accounts ?? [])
        for (const c of acc.characters ?? []) {
          if (flavour === "forever") {
            const tuple = foreverTuple(c);
            if (!tuple) continue;
            characters.push(tuple);
          }
          owned.push(c.id);
          if (c.gender?.type === "FEMALE") women.push(c.id);
          else if (c.gender?.type === "MALE") men.push(c.id);
        }
    } catch (err) {
      // A game the account never played answers 404 (nothing owned); any other failure leaves that game's entry as it was.
      log.info("login.flavour", { flavour, status: err instanceof BnetError ? err.status : String(err) });
      if (!(err instanceof BnetError && err.status === 404)) continue;
    }
    const game = flavour;
    account = await loginAccount({ bnetId, battletag: battletag ?? null, game, region: pending.region, owned: game === "forever" ? characters.map(([id]) => id) : owned, characters: game === "forever" ? characters : undefined, women, men });
  }
  if (!account) account = await touchAccount(bnetId, battletag ?? null);
  return { session: await createSession(account.id), next: pending.next };
}
