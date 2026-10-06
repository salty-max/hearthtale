import type { Book } from "@hearthtale/shared";

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
