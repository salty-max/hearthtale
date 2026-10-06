import type { Book } from "@hearthtale/shared";
import { Link } from "@tanstack/react-router";
import { Skull, Star } from "lucide-react";
import { parts } from "@/lib/book";
import { useT } from "@/lib/i18n";

/** A book's table of contents: the prologue, each chapter (where, its levels, its marks), the epitaph. */
export function Contents({ id, book, current, onPick }: { id: string; book: Book; current?: string; onPick?: () => void }) {
  const t = useT();
  return (
    <ol className="divide-y divide-parchment/10">
      {parts(book).map((p) => {
        const ch = p.kind === "chapter" ? book.chapters.find((c) => c.number === p.number) : undefined;
        const title = p.kind === "prologue" ? t.book.prologue : p.kind === "epitaph" ? t.book.epitaph : t.book.chapter(p.number);
        const here = p.key === current;
        return (
          <li key={p.key}>
            <Link
              to="/book/$id/$part"
              params={{ id, part: p.key }}
              onClick={onPick}
              aria-current={here ? "page" : undefined}
              className={
                here
                  ? "flex items-center justify-between gap-3 border-l-2 border-gold bg-gold/10 px-4 py-3"
                  : "flex items-center justify-between gap-3 border-l-2 border-transparent px-4 py-3 hover:bg-parchment/5"
              }
            >
              <span>
                <span
                  className={
                    p.kind === "epitaph"
                      ? "font-[family-name:var(--font-display)] text-lg text-[#e0705f]"
                      : here
                        ? "font-[family-name:var(--font-display)] text-lg text-gold-bright"
                        : "font-[family-name:var(--font-display)] text-lg text-parchment"
                  }
                >
                  {title}
                </span>
                {ch && (
                  <span className="block text-parchment/60">
                    {ch.open ? t.book.stillWriting : ch.place} · {t.book.levels(ch.from, ch.to)}
                  </span>
                )}
              </span>
              <span className="flex shrink-0 gap-1 text-parchment/50">
                {ch?.close && <Skull className="size-4" aria-label={t.book.closeCall} />}
                {ch?.rare && <Star className="size-4" aria-label={t.book.rare} />}
              </span>
            </Link>
          </li>
        );
      })}
    </ol>
  );
}
