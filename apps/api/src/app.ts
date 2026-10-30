import type { Health, Me } from "@hearthtale/shared";
import { Hono, type Context, type MiddlewareHandler } from "hono";
import { bodyLimit } from "hono/body-limit";
import { deleteCookie, getCookie, setCookie } from "hono/cookie";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { accounts, type AccountRow } from "@/db/schema";
import { createSession, endSession, SESSION_COOKIE, SESSION_TTL_MS, sessionAccount, sweepSessions, TEST_BNET_ID } from "@/lib/accounts";
import { getCharacterBook, libraryOf, removeBook } from "@/lib/characters";
import { confirmPairing, isPairCode, linkFor, pairingPending, pollPairing, startPairing } from "@/lib/companion";
import { signInWithPassport } from "@/lib/ravenpost";
import { handleUpload, uploadAs, type Saved } from "@/lib/upload";
import { notifyNewEntries, subscribe, unsubscribe, vapid } from "@/lib/push";
import { waitUntil } from "@vercel/functions";
import { ogPage } from "@/lib/og";
import { createShare, hall, hallBook, listShares, revokeShare, setInHall, sharedBook } from "@/lib/sharing";
import { createLinkCode } from "@/lib/link";
import { appOrigin, finishLogin, isRegion, startLogin } from "@/lib/login";
import { log } from "@/lib/log";
import { limit } from "@/lib/ratelimit";
import { sweepTemp } from "@/lib/ephemeral";

type Env = { Variables: { account: AccountRow | null } };
export const app = new Hono<Env>();

const local = () => !process.env.VERCEL;

app.onError((err, c) => {
  log.error("http.error", { path: c.req.path, err: String(err) });
  return c.json({ error: "internal error" }, 500);
});

app.get("/api/health", (c) => c.json({ ok: true, version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev" } satisfies Health));

// Who's asking: the signed-in account, from the session cookie (null: nobody).
app.use("/api/*", async (c, next) => {
  c.set("account", await sessionAccount(getCookie(c, SESSION_COOKIE)));
  await next();
});

const signedIn: MiddlewareHandler<Env> = async (c, next) => {
  if (!c.get("account")) return c.json({ error: "sign in first" }, 401);
  await next();
};
/** Account writes: the cookie is SameSite=Lax, and a browser's Origin must be ours. */
const sameOrigin: MiddlewareHandler<Env> = async (c, next) => {
  const origin = c.req.header("origin");
  if (origin && origin !== appOrigin()) return c.json({ error: "forbidden" }, 403);
  await next();
};
const sessionCookie = (c: Context<Env>, token: string) =>
  setCookie(c, SESSION_COOKIE, token, {
    httpOnly: true,
    secure: appOrigin().startsWith("https:"),
    sameSite: "Lax",
    path: "/",
    maxAge: Math.floor(SESSION_TTL_MS / 1000),
  });

// ── sign-in ──────────────────────────────────────────────────────────────────
// (a browser on its way: past the limit, back to the library with a word)
const busy = (c: Context) => c.redirect("/library?signin=busy");
app.get("/api/auth/login", limit("login", 20, 10 * 60_000, busy), async (c) => {
  const region = c.req.query("region");
  if (!isRegion(region)) return c.json({ error: "bad region" }, 400);
  return c.redirect(await startLogin(region, c.req.query("next")));
});

app.get("/api/auth/callback", limit("callback", 20, 10 * 60_000, busy), async (c) => {
  const code = c.req.query("code");
  const state = c.req.query("state");
  if (!code || !state) return c.redirect("/library?signin=cancelled");
  try {
    const { session, next } = await finishLogin(code, state);
    if (!session) return c.redirect("/library?signin=failed");
    sessionCookie(c, session);
    return c.redirect(next ?? "/library");
  } catch (err) {
    log.warn("login.failed", { err: String(err) });
    return c.redirect("/library?signin=failed");
  }
});

app.post("/api/auth/logout", sameOrigin, async (c) => {
  await endSession(getCookie(c, SESSION_COOKIE));
  deleteCookie(c, SESSION_COOKIE, { path: "/" });
  return c.json({ ok: true });
});

// Local development only: sign in as the test account, which owns the test characters.
app.post("/api/auth/test", sameOrigin, async (c) => {
  if (!local()) return c.json({ error: "not found" }, 404);
  const [test] = await db.select().from(accounts).where(eq(accounts.bnetId, TEST_BNET_ID));
  if (!test) return c.json({ error: "no test account: run bun run db:seed" }, 404);
  sessionCookie(c, await createSession(test.id));
  return c.json({ ok: true });
});

app.get("/api/me", (c) => {
  const a = c.get("account");
  return c.json(a ? ({ battletag: a.battletag, regions: a.owned.map((o) => o.region), test: a.bnetId === TEST_BNET_ID || undefined } satisfies Me) : null);
});

// ── the library ──────────────────────────────────────────────────────────────
app.get("/api/library", signedIn, async (c) => c.json(await libraryOf(c.get("account")!.id)));

app.get("/api/characters/:id", signedIn, async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id <= 0) return c.json({ error: "not found" }, 404);
  const found = await getCharacterBook(id, c.get("account")!.id);
  return found ? c.json(found) : c.json({ error: "not found" }, 404);
});

// Removing one of my books: it and its links go; its uploads wait for a new link code.
app.delete("/api/characters/:id", signedIn, sameOrigin, async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id <= 0) return c.json({ error: "not found" }, 404);
  return (await removeBook(id, c.get("account")!.id)) ? c.json({ ok: true }) : c.json({ error: "not found" }, 404);
});

app.post("/api/link-codes", signedIn, sameOrigin, limit("link-codes", 20, 10 * 60_000), async (c) => c.json(await createLinkCode(c.get("account")!.id)));

// ── sharing ──────────────────────────────────────────────────────────────────
const idOf = (c: Context<Env>) => {
  const id = Number(c.req.param("id"));
  return Number.isInteger(id) && id > 0 ? id : null;
};

app.get("/api/characters/:id/shares", signedIn, async (c) => {
  const id = idOf(c);
  const list = id ? await listShares(id, c.get("account")!.id) : null;
  return list ? c.json(list) : c.json({ error: "not found" }, 404);
});

app.post("/api/characters/:id/shares", signedIn, sameOrigin, async (c) => {
  const id = idOf(c);
  const { part } = await c.req.json<{ part?: unknown }>().catch(() => ({ part: undefined }));
  if (part !== undefined && typeof part !== "string") return c.json({ error: "bad part" }, 400);
  const share = id ? await createShare(id, c.get("account")!.id, part) : null;
  return share ? c.json(share) : c.json({ error: "not found" }, 404);
});

app.delete("/api/shares/:token", signedIn, sameOrigin, async (c) =>
  (await revokeShare(c.req.param("token"), c.get("account")!.id)) ? c.json({ ok: true }) : c.json({ error: "not found" }, 404),
);

app.put("/api/characters/:id/hall", signedIn, sameOrigin, async (c) => {
  const id = idOf(c);
  const { inHall } = await c.req.json<{ inHall?: unknown }>().catch(() => ({ inHall: undefined }));
  if (typeof inHall !== "boolean") return c.json({ error: "bad request" }, 400);
  return id && (await setInHall(id, c.get("account")!.id, inHall)) ? c.json({ ok: true }) : c.json({ error: "not found" }, 404);
});

// Public: a shared link, the Hall of the Fallen.
app.get("/api/shared/:token", async (c) => {
  const found = await sharedBook(c.req.param("token"));
  return found ? c.json(found) : c.json({ error: "not found" }, 404);
});
app.get("/api/hall", async (c) => c.json(await hall()));
app.get("/api/hall/:id", async (c) => {
  const id = idOf(c);
  const found = id ? await hallBook(id) : null;
  return found ? c.json(found) : c.json({ error: "not found" }, 404);
});

// Link previews: Vercel sends crawlers here for /s/:token and /hall/:id
// (scripts/vercel-build.sh); /api/og/… for trying one by hand.
const preview = (find: (key: string) => Promise<Parameters<typeof ogPage>[0] | null>, path: (key: string) => string) => async (c: Context<Env>) => {
  const key = c.req.param("key") ?? "";
  const found = await find(key);
  if (!found) return c.redirect("/");
  c.header("Cache-Control", "public, max-age=300");
  return c.html(ogPage(found, path(key), appOrigin()));
};
const sharePreview = preview(sharedBook, (t) => `/s/${t}`);
const hallPreview = preview(async (k) => (/^\d+$/.test(k) ? hallBook(Number(k)) : null), (k) => `/hall/${k}`);
app.get("/s/:key", sharePreview);
app.get("/api/og/s/:key", sharePreview);
app.get("/hall/:key", hallPreview);
app.get("/api/og/hall/:key", hallPreview);

// ── the companion (Ravenpost) ────────────────────────────────────────────────
app.post("/api/companion/pair/start", limit("pair-start", 10, 10 * 60_000), async (c) => c.json(await startPairing(appOrigin())));

app.get("/api/companion/pair/:code", limit("pair-check", 60, 60_000), async (c) => {
  const code = c.req.param("code");
  return c.json({ pending: isPairCode(code) && (await pairingPending(code)) });
});

app.post("/api/companion/pair/confirm", signedIn, sameOrigin, limit("pair-confirm", 20, 10 * 60_000), async (c) => {
  const { code } = await c.req.json<{ code?: string }>().catch(() => ({ code: undefined }));
  if (!isPairCode(code)) return c.json({ error: "not found" }, 404);
  const a = c.get("account")!;
  return (await confirmPairing(code, { id: a.id, battletag: a.battletag })) ? c.json({ ok: true }) : c.json({ error: "expired" }, 404);
});

// Ravenpost signed in once with Battle.net through its inbox: its passport for an upload token.
app.post("/api/companion/signin", limit("signin", 20, 10 * 60_000), async (c) => {
  const { passport } = await c.req.json<{ passport?: unknown }>().catch(() => ({ passport: undefined }));
  const linked = await signInWithPassport(passport);
  return linked ? c.json(linked) : c.json({ error: "not a passport" }, 401);
});

app.post("/api/companion/pair/poll", limit("pair-poll", 120, 60_000), async (c) => {
  const { code, pollToken } = await c.req.json<{ code?: string; pollToken?: string }>().catch(() => ({ code: undefined, pollToken: undefined }));
  if (!isPairCode(code) || typeof pollToken !== "string") return c.json({ status: "expired" });
  return c.json(await pollPairing(code, pollToken));
});

app.post(
  "/api/companion/upload",
  // (one character a request, sixty at most in a saved file)
  limit("companion-upload", 120, 60_000),
  // Vercel takes 4.5 MB at most: the companion sends one character per request.
  bodyLimit({ maxSize: 4 * 1024 * 1024, onError: (c) => c.json({ error: "too large" }, 413) }),
  async (c) => {
    const token = (c.req.header("authorization") ?? "").replace(/^Bearer\s+/i, "");
    const link = await linkFor(token);
    if (!link) return c.json({ error: "unknown or revoked companion" }, 401);
    const body = await c.req.json().catch(() => null);
    const { result, saved } = await handleUpload(link, body);
    tell(saved);
    return c.json(result);
  },
);

// A saved file brought by hand (no companion): the same upload, as the signed-in account's.
app.post(
  "/api/upload",
  signedIn,
  sameOrigin,
  limit("upload", 30, 60_000),
  bodyLimit({ maxSize: 4 * 1024 * 1024, onError: (c) => c.json({ error: "too large" }, 413) }),
  async (c) => {
    const body = await c.req.json().catch(() => null);
    const { result, saved } = await uploadAs(c.get("account")!.id, body);
    tell(saved);
    return c.json(result);
  },
);

/** The new entries of an upload, told to their owners' devices once the answer has gone. */
function tell(saved: Saved[]): void {
  const work = Promise.all(saved.map((s) => notifyNewEntries(s.owner, s.characterId, s.name, s.entries))).catch((err) =>
    log.warn("push.notify", { err: String(err) }),
  );
  waitUntil(work);
}

// ── notifications (Web Push) ─────────────────────────────────────────────────
app.get("/api/push/key", (c) => {
  const keys = vapid();
  return keys ? c.json({ key: keys.publicKey }) : c.json({ error: "not found" }, 404);
});

const pushSub = (v: unknown): { endpoint: string; p256dh: string; auth: string } | null => {
  const o = v && typeof v === "object" ? (v as Record<string, unknown>) : null;
  const keys = o?.keys && typeof o.keys === "object" ? (o.keys as Record<string, unknown>) : null;
  const endpoint = o?.endpoint;
  if (typeof endpoint !== "string" || endpoint.length > 1000 || !/^https:\/\//.test(endpoint)) return null;
  if (typeof keys?.p256dh !== "string" || typeof keys.auth !== "string" || keys.p256dh.length > 200 || keys.auth.length > 100) return null;
  return { endpoint, p256dh: keys.p256dh, auth: keys.auth };
};

app.post("/api/push/subscriptions", signedIn, sameOrigin, limit("push-subscribe", 20, 10 * 60_000), async (c) => {
  const sub = pushSub(await c.req.json().catch(() => null));
  if (!sub) return c.json({ error: "bad subscription" }, 400);
  await subscribe(c.get("account")!.id, sub);
  return c.json({ ok: true });
});

app.delete("/api/push/subscriptions", signedIn, sameOrigin, async (c) => {
  const { endpoint } = await c.req.json<{ endpoint?: unknown }>().catch(() => ({ endpoint: undefined }));
  if (typeof endpoint !== "string") return c.json({ error: "bad request" }, 400);
  await unsubscribe(c.get("account")!.id, endpoint);
  return c.json({ ok: true });
});

// ── upkeep ───────────────────────────────────────────────────────────────────
// Vercel's daily cron (config.json, scripts/vercel-build.sh) sends CRON_SECRET
// as a bearer: the expired logins, codes, counters and sessions go.
app.get("/api/cron/sweep", async (c) => {
  const secret = process.env.CRON_SECRET;
  if (!secret) return c.json({ error: "not found" }, 404);
  if (c.req.header("authorization") !== `Bearer ${secret}`) return c.json({ error: "forbidden" }, 401);
  const [temp, sessions] = await Promise.all([sweepTemp(), sweepSessions()]);
  log.info("sweep", { temp, sessions });
  return c.json({ temp, sessions });
});

app.all("/api/*", (c) => c.json({ error: "not found" }, 404));
