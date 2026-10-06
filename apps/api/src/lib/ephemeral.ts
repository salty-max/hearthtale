import { and, eq, gt, lt } from "drizzle-orm";
import { db } from "@/db";
import { ephemeral } from "@/db/schema";

/**
 * Short-lived key/value state in Postgres, so it survives any server instance
 * (serverless: each request may run somewhere else). Expired rows read as
 * missing and are swept now and then (sweepTemp).
 */

export async function putTemp(kind: string, key: string, data: unknown, ttlMs: number): Promise<void> {
  const expiresAt = new Date(Date.now() + ttlMs);
  await db
    .insert(ephemeral)
    .values({ kind, key, data, expiresAt })
    .onConflictDoUpdate({ target: [ephemeral.kind, ephemeral.key], set: { data, expiresAt } });
}

export async function getTemp<T>(kind: string, key: string): Promise<T | null> {
  const [row] = await db
    .select({ data: ephemeral.data })
    .from(ephemeral)
    .where(and(eq(ephemeral.kind, kind), eq(ephemeral.key, key), gt(ephemeral.expiresAt, new Date())));
  return (row?.data as T) ?? null;
}

/** Read and delete in one statement: a one-use value can't be used twice. */
export async function takeTemp<T>(kind: string, key: string): Promise<T | null> {
  const [row] = await db
    .delete(ephemeral)
    .where(and(eq(ephemeral.kind, kind), eq(ephemeral.key, key), gt(ephemeral.expiresAt, new Date())))
    .returning({ data: ephemeral.data });
  return (row?.data as T) ?? null;
}

export async function sweepTemp(): Promise<number> {
  const rows = await db.delete(ephemeral).where(lt(ephemeral.expiresAt, new Date())).returning({ key: ephemeral.key });
  return rows.length;
}
