import { Link, useParams } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight, List } from "lucide-react";
import { useState } from "react";
import { ContentsDrawer } from "@/components/ContentsDrawer";
import { LoadError, Loading } from "@/components/PageState";
import { NotFound, NotSignedIn, useCharacterBook } from "@/lib/api";
import { SignIn } from "@/components/SignIn";
import { paragraphs, parts } from "@/lib/book";
import { useT } from "@/lib/i18n";
import { readerClasses, useSettings } from "@/lib/settings";
import { CLASS_COLOURS } from "@/lib/wow";

/**
 * The reader: one part of a book on its page (the prologue, a chapter or the
 * epitaph), the contents in a drawer, the previous and next parts below.
 */
export function Chapter() {
  const t = useT();
  const { id, part } = useParams({ from: "/book/$id/$part" });
  const [contents, setContents] = useState(false);
  const settings = useSettings();
  const { data, error, refetch } = useCharacterBook(Number(id));
  if (error) {
    if (error instanceof NotSignedIn) return <SignIn />;
    return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  }
  if (!data) return <Loading />;
  const { character, book } = data;
  const all = parts(book);
  const at = all.findIndex((p) => p.key === part);
  const here = all[at];
  if (!here) return <LoadError message={t.book.notFound} />;
  const prev = all[at - 1];
  const next = all[at + 1];
  const ch = here.kind === "chapter" ? book.chapters.find((c) => c.number === here.number) : undefined;
  const title = here.kind === "prologue" ? t.book.prologue : here.kind === "epitaph" ? t.book.epitaph : t.book.chapter(here.number);
  const text = here.kind === "prologue" ? book.prologue : here.kind === "epitaph" ? book.epitaph : ch?.text;
  // "Anvilmar · levels 1 to 4", or "levels 7 to 9 · still being written"
  const sub = ch
    ? [
        ch.open ? undefined : ch.place,
        t.book.levels(ch.from, ch.to),
        ch.open ? t.book.stillWriting : character.fallen && ch.number === book.chapters.length ? t.book.theEnd : undefined,
      ]
        .filter(Boolean)
        .join(" · ")
    : undefined;
  const label = (p: (typeof all)[number]) =>
    p.kind === "prologue" ? t.book.prologue : p.kind === "epitaph" ? t.book.epitaph : t.book.chapter(p.number);
  const cls = readerClasses(settings);
  const fallenColour = settings.theme === "night" ? "text-[#e0705f]" : "text-fallen";
  return (
    <section className="mx-auto flex h-full max-w-2xl flex-col">
      <div className="flex shrink-0 items-center justify-between gap-3">
        <button onClick={() => setContents(true)} className="btn" aria-haspopup="dialog" aria-expanded={contents}>
          <List className="size-4" aria-hidden />
          {t.book.contents}
        </button>
        <span className="truncate font-[family-name:var(--font-display)] text-lg" style={{ color: CLASS_COLOURS[character.class] }}>
          {character.name}
        </span>
      </div>
      <ContentsDrawer open={contents} onClose={() => setContents(false)} id={id} character={character} book={book} current={part} />
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
        </div>
      </article>
      <nav className="flex shrink-0 items-center justify-between gap-2 pt-3 text-gold-bright">
        {prev ? (
          <Link to="/book/$id/$part" params={{ id, part: prev.key }} className="flex items-center gap-1 hover:underline">
            <ChevronLeft className="size-4" aria-hidden />
            {label(prev)}
          </Link>
        ) : (
          <span />
        )}
        <button onClick={() => setContents(true)} className="flex items-center gap-1 hover:underline" aria-haspopup="dialog">
          <List className="size-4" aria-hidden />
          {t.book.contents}
        </button>
        {next ? (
          <Link to="/book/$id/$part" params={{ id, part: next.key }} className="flex items-center gap-1 hover:underline">
            {label(next)}
            <ChevronRight className="size-4" aria-hidden />
          </Link>
        ) : (
          <span />
        )}
      </nav>
    </section>
  );
}
