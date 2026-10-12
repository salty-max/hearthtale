import { useSyncExternalStore } from "react";

/**
 * What this device has read of each of my books (localStorage): how many
 * entries and the latest one's moment when the book was last opened, so the
 * library can mark what came since ("New"), and the part last read, so a book
 * opens where it was left (unless something new came). A book never seen
 * before is taken as read: the first visit marks nothing.
 */
export type Seen = { n: number; at?: number; part?: string };
const KEY = "hearthtale.seen";
const listeners = new Set<() => void>();

function load(): Record<string, Seen> {
  try {
    const v = JSON.parse(localStorage.getItem(KEY) ?? "null") as unknown;
    return v && typeof v === "object" ? (v as Record<string, Seen>) : {};
  } catch {
    return {};
  }
}
let all = load();
function save(): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(all));
  } catch {
    // this session only
  }
  for (const l of listeners) l();
}

export function seenOf(id: number): Seen | undefined {
  return all[id];
}

/** A book as the library lists it: new since last read? (Never seen here: no.) */
export function isNew(seen: Seen | undefined, n: number, at?: number): boolean {
  if (!seen) return false;
  return n > seen.n || (at !== undefined && seen.at !== undefined && at > seen.at);
}

/** The books never seen on this device, remembered as read (from an effect, after the list shows). */
export function rememberUnseen(books: { id: number; n: number; at?: number }[]): void {
  const fresh = books.filter((b) => !all[b.id]);
  if (fresh.length === 0) return;
  all = { ...all, ...Object.fromEntries(fresh.map((b) => [b.id, { n: b.n, at: b.at }])) };
  save();
}

/** Opened: everything in it now read; part: where the reader is. */
export function markRead(id: number, n: number, at?: number, part?: string): void {
  const s = all[id];
  if (s && s.n === n && s.at === at && s.part === (part ?? s.part)) return;
  all = { ...all, [id]: { n, at, part: part ?? s?.part } };
  save();
}

/** The part to open a book at: the first new entry, else where it was left. */
export function resumeAt(id: number, n: number): string | undefined {
  const s = all[id];
  if (!s) return undefined;
  if (n > s.n) return String(s.n + 1);
  return s.part;
}

export function useSeen(): Record<string, Seen> {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => all,
    () => all,
  );
}
