import type { Region } from "@hearthtale/shared";
import { log } from "@/lib/log";

/**
 * Battle.net: "Sign in with Battle.net" (OAuth authorization code) and the
 * signed-in account's character list. The user's token is used once, in the
 * login callback, then dropped.
 */

type FetchFn = (input: string, init?: RequestInit) => Promise<Response>;
let fetchImpl: FetchFn = (input, init) => fetch(input, init);
export function setFetch(f: FetchFn): void {
  fetchImpl = f;
}

export function credentials(): { id: string; secret: string } | null {
  const id = process.env.BNET_CLIENT_ID;
  const secret = process.env.BNET_CLIENT_SECRET;
  return id && secret ? { id, secret } : null;
}
function required(): { id: string; secret: string } {
  const c = credentials();
  if (!c) throw new Error("BNET_CLIENT_ID / BNET_CLIENT_SECRET not set");
  return c;
}

export class BnetError extends Error {
  constructor(
    readonly path: string,
    readonly status: number,
  ) {
    super(`GET ${path} → ${status}`);
  }
}

export function authorizeUrl(redirectUri: string, state: string): string {
  const q = new URLSearchParams({
    client_id: required().id,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: "wow.profile",
    state,
  });
  return `https://oauth.battle.net/authorize?${q}`;
}

/** Exchange a one-time code for the user's access token. */
export async function exchangeCode(code: string, redirectUri: string): Promise<string> {
  const c = required();
  const res = await fetchImpl("https://oauth.battle.net/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${c.id}:${c.secret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: redirectUri }).toString(),
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`oauth code exchange → ${res.status}`);
  return ((await res.json()) as { access_token: string }).access_token;
}

/** The signed-in Battle.net account: `id` is stable, the BattleTag can change. */
export async function userInfo(userToken: string): Promise<{ id?: number; battletag?: string }> {
  const res = await fetchImpl("https://oauth.battle.net/userinfo", {
    headers: { Authorization: `Bearer ${userToken}` },
    signal: AbortSignal.timeout(15_000),
  });
  return res.ok ? ((await res.json()) as { id?: number; battletag?: string }) : {};
}

/** The games whose characters Battle.net can list: Classic Era (Hardcore, SoD). */
export const FLAVOURS = ["classic1x"] as const;
export type Flavour = (typeof FLAVOURS)[number];

export type RawAccountProfile = {
  wow_accounts?: { characters?: { id: number; name: string; level: number; realm: { slug: string; name: string } }[] }[];
};

const RETRY_DELAYS_MS = [1_000, 3_000];

/** The account's characters in one game and region. 404: never played there. */
export async function accountProfile(flavour: Flavour, region: Region, userToken: string): Promise<RawAccountProfile> {
  const path = "/profile/user/wow";
  const url = `https://${region}.api.blizzard.com${path}?namespace=profile-${flavour}-${region}&locale=en_GB`;
  for (let attempt = 0; ; attempt++) {
    let status = 0;
    try {
      const res = await fetchImpl(url, { headers: { Authorization: `Bearer ${userToken}` }, signal: AbortSignal.timeout(20_000) });
      if (res.ok) return (await res.json()) as RawAccountProfile;
      status = res.status;
      if (status === 429) log.warn("bnet.rate_limited", { path, attempt: attempt + 1 });
    } catch (err) {
      if (attempt >= RETRY_DELAYS_MS.length) throw err;
    }
    const retryable = status === 0 || status === 429 || status >= 500;
    if (!retryable || attempt >= RETRY_DELAYS_MS.length) throw new BnetError(path, status);
    await new Promise((r) => setTimeout(r, RETRY_DELAYS_MS[attempt]));
  }
}
