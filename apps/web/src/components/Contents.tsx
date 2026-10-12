import type { Book } from "@hearthtale/shared";
import { Skull, Star } from "lucide-react";
import { PartLink } from "@/components/PartLink";
import { partTitle, parts } from "@/lib/book";
import { dateRange } from "@/lib/dates";
import { useLocale, useT } from "@/lib/i18n";

/** A book's table of contents: the prologue, each chapter (where, its levels, when, its marks), the epitaph. */
export function Contents({ hrefFor, book, current, onPick }: { hrefFor: (part: string) => string; book: Book; current?: string; onPick?: () => void }) {
  const t = useT();
  const locale = useLocale();
  return (
    <ol className="divide-y divide-parchment/10">
      {parts(book).map((p) => {
        const ch = p.kind === "chapter" ? book.chapters.find((c) => c.number === p.number) : undefined;
        const here = p.key === current;
        const when = ch && dateRange(ch.began, ch.open ? undefined : ch.ended, locale, t.book.to);
        return (
          <li key={p.key}>
            <PartLink
              href={hrefFor(p.key)}
              onClick={onPick}
              aria-current={here ? "page" : undefined}
              className={
                here
                  ? "flex items-center justify-between gap-3 border-l-2 border-gold bg-gold/10 px-4 py-3"
                  : "flex items-center justify-between gap-3 border-l-2 border-transparent px-4 py-3 hover:bg-parchment/5"
              }
            >
              <span className="min-w-0">
                <span
                  className={`block text-lg font-semibold ${
                    p.kind === "epitaph" ? "text-blood" : here ? "text-gold-bright" : "text-parchment"
                  }`}
                >
                  {partTitle(t, book, p)}
                </span>
                {ch && (
                  <span className="ui block text-sm text-parchment/60">
                    {ch.title && `${t.book.chapter(ch.number)} · `}
                    {ch.open ? t.book.stillWriting : ch.place} · {t.book.levels(ch.from, ch.to)}
                    {when && <span className="block font-narrow text-parchment/45">{when}</span>}
                  </span>
                )}
              </span>
              <span className="flex shrink-0 gap-1 text-parchment/50">
                {ch?.close && <Skull className="size-4" aria-label={t.book.closeCall} />}
                {ch?.rare && <Star className="size-4" aria-label={t.book.rare} />}
              </span>
            </PartLink>
          </li>
        );
      })}
    </ol>
  );
}
