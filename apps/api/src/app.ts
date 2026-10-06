import type { Health, Me } from "@hearthtale/shared";
import { Hono, type Context, type MiddlewareHandler } from "hono";
import { deleteCookie, getCookie, setCookie } from "hono/cookie";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { accounts, type AccountRow } from "@/db/schema";
import { createSession, endSession, SESSION_COOKIE, SESSION_TTL_MS, sessionAccount, TEST_BNET_ID } from "@/lib/accounts";
import { getCharacterBook, libraryOf } from "@/lib/characters";
import { createLinkCode } from "@/lib/link";
import { appOrigin, finishLogin, isRegion, startLogin } from "@/lib/login";
import { log } from "@/lib/log";

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
app.get("/api/auth/login", async (c) => {
  const region = c.req.query("region");
  if (!isRegion(region)) return c.json({ error: "bad region" }, 400);
  return c.redirect(await startLogin(region));
});

app.get("/api/auth/callback", async (c) => {
  const code = c.req.query("code");
  const state = c.req.query("state");
  if (!code || !state) return c.redirect("/library?signin=cancelled");
  try {
    const token = await finishLogin(code, state);
    if (!token) return c.redirect("/library?signin=failed");
    sessionCookie(c, token);
    return c.redirect("/library");
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

app.post("/api/link-codes", signedIn, sameOrigin, async (c) => c.json(await createLinkCode(c.get("account")!.id)));

app.all("/api/*", (c) => c.json({ error: "not found" }, 404));
