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

export function databaseUrl(): string {
  return process.env.DATABASE_URL ?? "postgres://hearthtale:hearthtale@localhost:5435/hearthtale";
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
