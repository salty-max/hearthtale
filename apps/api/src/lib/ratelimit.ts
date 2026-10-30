import { sql } from "drizzle-orm";
import type { Context, MiddlewareHandler } from "hono";
import { db } from "@/db";
import { ephemeral } from "@/db/schema";
import { sweepTemp } from "@/lib/ephemeral";
import { log } from "@/lib/log";

/**
 * A small rate limit that fits serverless: a fixed window per caller, counted
 * in Postgres (the ephemeral table, kind "rate": every instance sees the same
 * count, no new service). The caller is its address, pseudonymised (a hash: an
 * IPv4 address could be found again, so a row lives a day at most), an IPv6
 * one by its /64 (one client holds a whole /64). A counter that fails lets the
 * request through: the limit guards the database, it must never be what breaks
 * a sign-in.
 */

export type Counter = { hit(key: string, expiresAt: Date): Promise<number> };

/** One statement: the window's row made or counted up, its count returned. */
const postgresCounter: Counter = {
  async hit(key, expiresAt) {
    const [row] = await db
      .insert(ephemeral)
      .values({ kind: "rate", key, data: { n: 1 }, expiresAt })
      .onConflictDoUpdate({
        target: [ephemeral.kind, ephemeral.key],
        set: { data: sql`jsonb_build_object('n', (${ephemeral.data}->>'n')::int + 1)` },
      })
      .returning({ n: sql<number>`(${ephemeral.data}->>'n')::int` });
    return Number(row.n);
  },
};

/** For the tests: counts in memory. */
export function memoryCounter(): Counter {
  const counts = new Map<string, number>();
  return {
    async hit(key) {
      const n = (counts.get(key) ?? 0) + 1;
      counts.set(key, n);
      return n;
    },
  };
}

let counter: Counter = postgresCounter;
/** Swap the counter (null: Postgres again). */
export function setCounter(c: Counter | null): void {
  counter = c ?? postgresCounter;
}

export function windowOf(windowMs: number, now = Date.now()): { index: number; endsAt: number } {
  const index = Math.floor(now / windowMs);
  return { index, endsAt: (index + 1) * windowMs };
}

/** The caller's address: Vercel sets x-real-ip and x-forwarded-for itself (a client's own are replaced). */
export function clientIp(headers: Headers): string {
  return headers.get("x-real-ip")?.trim() || headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "local";
}

/** The part of an address that names one client: an IPv6 address's first four groups (its /64). */
export function callerOf(ip: string): string {
  if (!ip.includes(":")) return ip;
  const [head, tail = ""] = ip.split("%")[0].split("::");
  const left = head ? head.split(":") : [];
  const right = ip.includes("::") && tail ? tail.split(":") : [];
  const groups = [...left, ...Array(Math.max(0, 8 - left.length - right.length)).fill("0"), ...right];
  return groups
    .slice(0, 4)
    .map((g) => g.toLowerCase().replace(/^0+(?=.)/, ""))
    .join(":") + "::/64";
}

async function hashOf(s: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
  return Buffer.from(bytes.subarray(0, 12)).toString("base64url");
}

/** At most `max` requests per caller in each `windowMs`, for the route named `name` (`refused`: the answer past it, JSON's 429 by default). */
export function limit(name: string, max: number, windowMs: number, refused?: (c: Context) => Response | Promise<Response>): MiddlewareHandler {
  return async (c, next) => {
    const { index, endsAt } = windowOf(windowMs);
    let n = 0;
    try {
      n = await counter.hit(`${name}:${await hashOf(callerOf(clientIp(c.req.raw.headers)))}:${index}`, new Date(endsAt));
    } catch (err) {
      log.warn("ratelimit.failed", { name, err: String(err) });
    }
    if (n > max) {
      // (someone hammering: the expired windows go now and then)
      if (Math.random() < 0.05) void sweepTemp().catch(() => {});
      c.header("Retry-After", String(Math.max(1, Math.ceil((endsAt - Date.now()) / 1000))));
      return refused ? refused(c) : c.json({ error: "too many requests" }, 429);
    }
    await next();
  };
}
