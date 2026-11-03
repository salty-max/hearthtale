import { langOf, type Book, type Frame, type PublicCharacter } from "@hearthtale/shared";
import { dateRange } from "@/lib/dates";

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

/** A part's title: an entry's own (else "Entry 3"), "Prologue", "Epitaph". The frame is the interface's: an entry's own title is the book's words. */
export function partTitle(f: Frame, book: Book, p: Part): string {
  if (p.kind === "prologue") return f.prologue;
  if (p.kind === "epitaph") return f.epitaph;
  return book.chapters.find((c) => c.number === p.number)?.title ?? f.chapter(p.number);
}

/** The `lang` of a part's title: the book's for an entry's own, else the interface's (the frame's). */
export function partLang(f: Frame, book: Book, p: Part): string {
  return p.kind === "chapter" && book.chapters.find((c) => c.number === p.number)?.title ? langOf(book.language) : f.lang;
}

/**
 * The line under an entry's title, as the addon's own header: "Entry 3 ·
 * Kharanos · levels 4 to 7 · 5 to 7 Oct 2026", "… · still being written", or
 * "… · the end" for a fallen life's last. In the interface's frame, the
 * place as the book has it.
 */
export function partSub(f: Frame, character: Pick<PublicCharacter, "fallen">, book: Book, p: Part): string | undefined {
  const pieces = partSubPieces(f, character, book, p);
  return pieces.length ? pieces.map((x) => x.text).join(" · ") : undefined;
}

/** The same line in its pieces, each the interface's but the place, the book's own word (`book: true`, for its `lang`). */
export function partSubPieces(f: Frame, character: Pick<PublicCharacter, "fallen">, book: Book, p: Part): { text: string; book?: true }[] {
  if (p.kind !== "chapter") return [];
  const ch = book.chapters.find((c) => c.number === p.number);
  if (!ch) return [];
  const last = ch.number === book.chapters[book.chapters.length - 1]?.number;
  const pieces: { text: string | undefined; book?: true }[] = [
    { text: ch.title ? f.chapter(ch.number) : undefined },
    { text: ch.open ? undefined : ch.place, book: true },
    { text: f.levels(ch.from, ch.to) },
    { text: dateRange(ch.began, ch.open ? undefined : ch.ended, f.locale, f.to) },
    { text: ch.open ? f.stillWriting : character.fallen && last && !book.chapters.some((c) => c.open) ? f.theEnd : undefined },
  ];
  return pieces.filter((x): x is { text: string; book?: true } => !!x.text);
}
