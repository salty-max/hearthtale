import type { Book, PublicCharacter } from "@hearthtale/shared";
import { dateRange } from "@/lib/dates";
import type { Strings } from "@/lib/i18n";

/** A part of a book, in reading order: the prologue, each chapter, the epitaph. */
export type Part = { key: string; kind: "prologue" } | { key: string; kind: "chapter"; number: number } | { key: string; kind: "epitaph" };

export function parts(book: Book): Part[] {
  const out: Part[] = [];
  if (book.prologue) out.push({ key: "prologue", kind: "prologue" });
  for (const ch of book.chapters) out.push({ key: String(ch.number), kind: "chapter", number: ch.number });
  if (book.epitaph) out.push({ key: "epitaph", kind: "epitaph" });
  return out;
}

/** The text of a part, as paragraphs. */
export function paragraphs(text: string | undefined): string[] {
  return (text ?? "").split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
}

/** The part to open first: the chapter being written, else the last one. */
export function current(book: Book): string | undefined {
  const open = book.chapters.find((c) => c.open);
  if (open) return String(open.number);
  const all = parts(book);
  return all[all.length - 1]?.key;
}

/** A part's title: an entry's own (else "Entry 3"), "Prologue", "Epitaph". */
export function partTitle(t: Strings, book: Book, p: Part): string {
  if (p.kind === "prologue") return t.book.prologue;
  if (p.kind === "epitaph") return t.book.epitaph;
  return book.chapters.find((c) => c.number === p.number)?.title ?? t.book.chapter(p.number);
}

/**
 * The line under an entry's title, as the addon's own header: "Entry 3 ·
 * Kharanos · levels 4 to 7 · 5 to 7 Oct 2026", "… · still being written", or
 * "… · the end" for a fallen life's last.
 */
export function partSub(t: Strings, locale: string, character: Pick<PublicCharacter, "fallen">, book: Book, p: Part): string | undefined {
  if (p.kind !== "chapter") return undefined;
  const ch = book.chapters.find((c) => c.number === p.number);
  if (!ch) return undefined;
  const last = ch.number === book.chapters[book.chapters.length - 1]?.number;
  return [
    ch.title ? t.book.chapter(ch.number) : undefined,
    ch.open ? undefined : ch.place,
    t.book.levels(ch.from, ch.to),
    dateRange(ch.began, ch.open ? undefined : ch.ended, locale, t.book.to),
    ch.open ? t.book.stillWriting : character.fallen && last && !book.chapters.some((c) => c.open) ? t.book.theEnd : undefined,
  ]
    .filter(Boolean)
    .join(" · ");
}
