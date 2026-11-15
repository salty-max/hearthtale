import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { setDb, schema, type DB } from "@/db";

// The process's Postgres connection, from DATABASE_URL (the local `bun run db`
// container by default; in production Neon's pooled connection, set by the
// Vercel integration).

/** A connection through a transaction pooler. */
export function pooled(url: string): boolean {
  return /-pooler\./.test(url) || /:6543\//.test(url);
}

type Env = Record<string, string | undefined>;

const LOCAL_URL = "postgres://hearthtale:hearthtale@localhost:5435/hearthtale";

export function databaseUrl(env: Env = process.env): string {
  return env.DATABASE_URL ?? LOCAL_URL;
}

/** The connection migrate.ts opens: MIGRATE_URL, else Neon's direct connection
 *  (DATABASE_URL_UNPOOLED, set by the Vercel integration), else DATABASE_URL.
 *  Migrations need a real session, which a transaction pooler isn't. */
export function migrationUrl(env: Env = process.env): string {
  return env.MIGRATE_URL || env.DATABASE_URL_UNPOOLED || databaseUrl(env);
}

// The guard. The db scripts (migrate, seed, release) run on this machine's
// Postgres unless the command says otherwise: DATABASE_URL may hold Neon's
// production (a shell export, or the .env.local that `vercel link` and
// `vercel env pull` write), and nothing else tells a local run from one there.

/** The flag that lets migrate and release reach a database off this machine. */
export const PRODUCTION_FLAG = "--prod";

/** What postgres.js will dial, as the client itself parsed it. */
type Dialled = { host: string[]; port: number[]; path?: string | false };

function loopback(host: string): boolean {
  return host === "localhost" || /^127(\.\d{1,3}){3}$/.test(host);
}

/** Where the client connects: a socket, or every host it was given. Read from
 *  the client's own options, never from a parse of the URL here: they disagree
 *  (`host-a,evil.com`, an encoded comma, PGHOST for a URL with no host), and a
 *  driver update that reads more of the url stays covered. */
export function isLocal(o: Dialled): boolean {
  if (o.path) return true;
  return o.host.length > 0 && o.host.every(loopback);
}

export function whereIs(o: Dialled): string {
  return o.path ? `socket ${o.path}` : o.host.map((h, i) => `${h}:${o.port[i]}`).join(",");
}

export type Verdict = { ok: true; where: string; production: boolean } | { ok: false; where: string; message: string };

/** Whether a script may open this connection: always on this machine, elsewhere
 *  only with --prod (never, when the script takes no such flag). The message
 *  names the host and never the credentials. */
export function checkDatabase(o: Dialled, argv: string[], allowProduction = true): Verdict {
  const where = whereIs(o);
  if (isLocal(o)) return { ok: true, where, production: false };
  if (allowProduction && argv.includes(PRODUCTION_FLAG)) return { ok: true, where, production: true };
  const how = allowProduction
    ? `To run there on purpose, add ${PRODUCTION_FLAG} to the command (docs/site.md, "Database scripts").`
    : `This script is local only (its test data would reach the real site): it has no ${PRODUCTION_FLAG}.`;
  return {
    ok: false,
    where,
    message: [
      `refusing: ${where} is not a database on this machine.`,
      "The db scripts use the local container (bun run db: localhost:5435). DATABASE_URL, DATABASE_URL_UNPOOLED or MIGRATE_URL",
      "(set in the shell, or written to a .env.local by `vercel link` or `vercel env pull`) points elsewhere.",
      how,
    ].join("\n"),
  };
}

/** A db script's first line after it builds its client (no query has run yet):
 *  says where it is going, and exits 1 instead of going somewhere it wasn't asked to. */
export function requireDatabase(sql: { options: Dialled }, argv = process.argv.slice(2), allowProduction = true): void {
  const verdict = checkDatabase(sql.options, argv, allowProduction);
  if (!verdict.ok) {
    console.error(verdict.message);
    process.exit(1);
  }
  console.log(`database: ${verdict.where}${verdict.production ? ` (not on this machine: ${PRODUCTION_FLAG})` : ""}`);
}

/** Open a connection and register it as the app's db. Returns the raw client
 *  so scripts can `await sql.end()` and let the process exit. */
export function initDb(url = databaseUrl()): ReturnType<typeof postgres> {
  const serverless = !!process.env.VERCEL;
  const sql = postgres(url, {
    onnotice: () => {},
    // A transaction pooler (Neon's "-pooler" host, Supabase's port 6543) can't
    // keep prepared statements.
    prepare: !pooled(url),
    // A serverless instance needs few connections and must let them go fast.
    ...(serverless ? { max: 3, idle_timeout: 20, connect_timeout: 10 } : {}),
  });
  setDb(drizzle(sql, { schema }) as unknown as DB);
  return sql;
}
