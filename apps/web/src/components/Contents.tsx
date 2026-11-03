import { langOf, type Book } from "@hearthtale/shared";
import { EntryMarks } from "@/components/EntryMarks";
import { PartLink } from "@/components/PartLink";
import { partLang, partTitle, parts } from "@/lib/book";
import { dateRange } from "@/lib/dates";
import { useFrame } from "@/lib/i18n";

/** A book's table of contents: the prologue, each chapter (where, its levels, when, its marks), the epitaph; the labels in the site's language, the book's own titles and places in its. */
export function Contents({ hrefFor, book, current, onPick }: { hrefFor: (part: string) => string; book: Book; current?: string; onPick?: () => void }) {
  const f = useFrame();
  const bookLang = langOf(book.language);
  return (
    <ol className="divide-y divide-parchment/10">
      {parts(book).map((p) => {
        const ch = p.kind === "chapter" ? book.chapters.find((c) => c.number === p.number) : undefined;
        const here = p.key === current;
        const when = ch && dateRange(ch.began, ch.open ? undefined : ch.ended, f.locale, f.to);
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
                  lang={partLang(f, book, p)}
                  className={`block font-display text-lg font-semibold ${
                    p.kind === "epitaph" ? "text-blood" : here ? "text-gold-bright" : "text-parchment"
                  }`}
                >
                  {partTitle(f, book, p)}
                </span>
                {ch && (
                  <span className="ui block text-sm text-parchment/60">
                    {ch.title && `${f.chapter(ch.number)} · `}
                    {ch.open ? f.stillWriting : <span lang={bookLang}>{ch.place}</span>} · {f.levels(ch.from, ch.to)}
                    {when && <span className="block text-parchment/45">{when}</span>}
                    <EntryMarks close={ch.close} rare={ch.rare} className="mt-1" />
                  </span>
                )}
              </span>
            </PartLink>
          </li>
        );
      })}
    </ol>
  );
}
