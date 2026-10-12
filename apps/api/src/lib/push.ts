import type { Book } from "@hearthtale/shared";
import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { pushSubscriptions } from "@/db/schema";
import { log } from "@/lib/log";
import { sendPush, type Vapid } from "@/lib/webpush";

/**
 * Telling a player's devices that a character wrote a new entry (after a
 * logout's upload): the browsers they turned it on in (Settings), by Web Push
 * (lib/webpush.ts, from WoWLocker). Without the site's VAPID keys
 * (VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT), there is none.
 */
export function vapid(): Vapid | null {
  const publicKey = process.env.VAPID_PUBLIC_KEY;
  const privateKey = process.env.VAPID_PRIVATE_KEY;
  if (!publicKey || !privateKey) return null;
  return { publicKey, privateKey, subject: process.env.VAPID_SUBJECT ?? "https://hearthtale.app" };
}

const MAX_PER_ACCOUNT = 20;

export async function subscribe(accountId: number, sub: { endpoint: string; p256dh: string; auth: string }): Promise<void> {
  await db
    .insert(pushSubscriptions)
    .values({ accountId, ...sub })
    .onConflictDoUpdate({ target: pushSubscriptions.endpoint, set: { accountId, p256dh: sub.p256dh, auth: sub.auth } });
  // (a few devices each; the oldest give way)
  const all = await db.select({ endpoint: pushSubscriptions.endpoint, createdAt: pushSubscriptions.createdAt }).from(pushSubscriptions).where(eq(pushSubscriptions.accountId, accountId));
  if (all.length > MAX_PER_ACCOUNT) {
    all.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
    for (const old of all.slice(0, all.length - MAX_PER_ACCOUNT)) await db.delete(pushSubscriptions).where(eq(pushSubscriptions.endpoint, old.endpoint));
  }
}

export async function unsubscribe(accountId: number, endpoint: string): Promise<void> {
  await db.delete(pushSubscriptions).where(and(eq(pushSubscriptions.accountId, accountId), eq(pushSubscriptions.endpoint, endpoint)));
}

/** The entries a new upload finished that the book before it hadn't (none for a first upload: nothing is new to the player). */
export function finishedSince(before: Book | null | undefined, after: Book): Book["chapters"] {
  if (!before) return [];
  const done = new Set(before.chapters.filter((c) => !c.open).map((c) => c.number));
  return after.chapters.filter((c) => !c.open && !done.has(c.number));
}

/** "Brannok wrote “Bristle”": one notification for the newest finished entry (and how many more). */
export function newEntryMessage(name: string, characterId: number, entries: Book["chapters"]) {
  const last = entries[entries.length - 1];
  const title = last.title ?? `Entry ${last.number}`;
  return {
    title: entries.length > 1 ? `${name} wrote ${entries.length} new entries` : `${name} wrote “${title}”`,
    body: [last.title ? `Entry ${last.number}` : undefined, last.place, entries.length > 1 ? `the last: “${title}”` : undefined].filter(Boolean).join(" · "),
    url: `/book/${characterId}/${last.number}`,
    tag: `book-${characterId}`,
  };
}

export async function notifyNewEntries(accountId: number, characterId: number, name: string, entries: Book["chapters"]): Promise<void> {
  const keys = vapid();
  if (!keys || entries.length === 0) return;
  const subs = await db.select().from(pushSubscriptions).where(eq(pushSubscriptions.accountId, accountId));
  const message = newEntryMessage(name, characterId, entries);
  for (const s of subs) {
    try {
      const res = await sendPush({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, message, keys, { ttl: 24 * 3600 });
      if (res.gone) await db.delete(pushSubscriptions).where(eq(pushSubscriptions.endpoint, s.endpoint));
      else if (!res.ok) log.warn("push.failed", { status: res.status });
    } catch (err) {
      log.warn("push.error", { err: String(err) });
    }
  }
}
