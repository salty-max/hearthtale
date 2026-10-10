import type { Book, PublicCharacter } from "@hearthtale/shared";
import { ChevronLeft, ChevronRight, List } from "lucide-react";
import { useState, type ReactNode } from "react";
import { ContentsDrawer } from "@/components/ContentsDrawer";
import { LoadError } from "@/components/PageState";
import { PartLink } from "@/components/PartLink";
import { paragraphs, parts } from "@/lib/book";
import { useT } from "@/lib/i18n";
import { readerClasses, useSettings } from "@/lib/settings";
import { CLASS_COLOURS } from "@/lib/wow";

/**
 * The reader: one part of a book on its page (the prologue, a chapter as its
 * diary entry, or the epitaph), the contents in a drawer, the previous and
 * next parts below.
 * Wherever the book comes from (my library, a share link, the Hall): `hrefFor`
 * gives each part's address, `actions` sit in the toolbar.
 */
export function Reader({
  character,
  book,
  part,
  hrefFor,
  actions,
}: {
  character: PublicCharacter;
  book: Book;
  part: string;
  hrefFor: (part: string) => string;
  actions?: ReactNode;
}) {
  const t = useT();
  const [contents, setContents] = useState(false);
  const settings = useSettings();
  const all = parts(book);
  const at = all.findIndex((p) => p.key === part);
  const here = all[at];
  if (!here) return <LoadError message={t.book.notFound} />;
  const prev = all[at - 1];
  const next = all[at + 1];
  const several = all.length > 1;
  const ch = here.kind === "chapter" ? book.chapters.find((c) => c.number === here.number) : undefined;
  const title = here.kind === "prologue" ? t.book.prologue : here.kind === "epitaph" ? t.book.epitaph : (ch?.title ?? t.book.chapter(here.number));
  // (a chapter as its diary entry; a book saved before entries were, its prose)
  const text = here.kind === "prologue" ? book.prologue : here.kind === "epitaph" ? book.epitaph : (ch?.diary ?? ch?.text);
  // "Anvilmar · levels 1 to 4", or "levels 7 to 9 · still being written"
  const sub = ch
    ? [
        ch.title ? t.book.chapter(ch.number) : undefined,
        ch.open ? undefined : ch.place,
        t.book.levels(ch.from, ch.to),
        ch.open ? t.book.stillWriting : character.fallen && ch.number === book.chapters[book.chapters.length - 1]?.number && !book.chapters.some((c) => c.open) ? t.book.theEnd : undefined,
      ]
        .filter(Boolean)
        .join(" · ")
    : undefined;
  const label = (p: (typeof all)[number]) =>
    p.kind === "prologue"
      ? t.book.prologue
      : p.kind === "epitaph"
        ? t.book.epitaph
        : (book.chapters.find((c) => c.number === p.number)?.title ?? t.book.chapter(p.number));
  const cls = readerClasses(settings);
  const fallenColour = settings.theme === "night" ? "text-[#e0705f]" : "text-fallen";
  return (
    <section className="mx-auto flex h-full max-w-2xl flex-col">
      <div className="flex shrink-0 items-center justify-between gap-3">
        {several ? (
          <button onClick={() => setContents(true)} className="btn" aria-haspopup="dialog" aria-expanded={contents}>
            <List className="size-4" aria-hidden />
            {t.book.contents}
          </button>
        ) : (
          <span />
        )}
        <span className="flex min-w-0 items-center gap-3">
          <span className="truncate font-[family-name:var(--font-display)] text-lg" style={{ color: CLASS_COLOURS[character.class] }}>
            {character.name}
          </span>
          {actions}
        </span>
      </div>
      {several && (
        <ContentsDrawer open={contents} onClose={() => setContents(false)} hrefFor={hrefFor} character={character} book={book} current={part} />
      )}
      {/* The page stays still; only its text scrolls (a new part starts at its top). */}
      <article className={`${cls.page} mt-3 flex min-h-0 flex-1 flex-col overflow-hidden rounded-md`}>
        <div key={part} className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-6 py-8 sm:px-12 sm:py-10">
          <header className="text-center">
            <h1 className={here.kind === "epitaph" ? `title text-3xl ${fallenColour}` : "title page-title text-3xl"}>{title}</h1>
            {sub && <p className="page-faded mt-1 italic">{sub}</p>}
          </header>
          <div className={`mt-6 space-y-4 ${cls.text} ${here.kind === "epitaph" ? "text-center italic" : ""}`}>
            {paragraphs(text).length === 0 && <p className="page-faded italic">{t.book.nothingYet}</p>}
            {paragraphs(text).map((p, i) => (
              <p
                key={i}
                className={
                  i === 0 && here.kind === "chapter"
                    ? "first-letter:float-left first-letter:mr-1 first-letter:font-[family-name:var(--font-display)] first-letter:text-[3.2em] first-letter:leading-none first-letter:text-[var(--page-title)]"
                    : undefined
                }
              >
                {p}
              </p>
            ))}
          </div>
          {/* The player's own note, set apart from the journal's words. */}
          {ch?.note && (
            <aside className={`mt-8 border-t border-current/15 pt-4 ${cls.text}`}>
              <p className="page-faded text-sm tracking-wide uppercase">{t.book.note}</p>
              <div className="mt-2 space-y-3 italic">
                {ch.note
                  .split(/\n+/)
                  .filter((line) => line.trim())
                  .map((line, i) => (
                    <p key={i}>{line}</p>
                  ))}
              </div>
            </aside>
          )}
        </div>
      </article>
      {several && (
        <nav className="flex shrink-0 items-center justify-between gap-2 pt-3 text-gold-bright">
          {prev ? (
            <PartLink href={hrefFor(prev.key)} className="flex items-center gap-1 hover:underline">
              <ChevronLeft className="size-4" aria-hidden />
              {label(prev)}
            </PartLink>
          ) : (
            <span />
          )}
          <button onClick={() => setContents(true)} className="flex items-center gap-1 hover:underline" aria-haspopup="dialog">
            <List className="size-4" aria-hidden />
            {t.book.contents}
          </button>
          {next ? (
            <PartLink href={hrefFor(next.key)} className="flex items-center gap-1 hover:underline">
              {label(next)}
              <ChevronRight className="size-4" aria-hidden />
            </PartLink>
          ) : (
            <span />
          )}
        </nav>
      )}
    </section>
  );
}
