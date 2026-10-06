import { Link, useParams } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight, List } from "lucide-react";
import { useState } from "react";
import { ContentsDrawer } from "@/components/ContentsDrawer";
import { LoadError, Loading } from "@/components/PageState";
import { NotFound, useCharacterBook } from "@/lib/api";
import { paragraphs, parts } from "@/lib/book";
import { useT } from "@/lib/i18n";
import { CLASS_COLOURS } from "@/lib/wow";

/**
 * The reader: one part of a book on its page (the prologue, a chapter or the
 * epitaph), the contents in a drawer, the previous and next parts below.
 */
export function Chapter() {
  const t = useT();
  const { id, part } = useParams({ from: "/book/$id/$part" });
  const [contents, setContents] = useState(false);
  const { data, isPending, error, refetch } = useCharacterBook(Number(id));
  if (isPending) return <Loading />;
  if (error) return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
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
  return (
    <section className="mx-auto mt-2 max-w-2xl">
      <div className="flex items-center justify-between gap-3">
        <button onClick={() => setContents(true)} className="btn" aria-haspopup="dialog" aria-expanded={contents}>
          <List className="size-4" aria-hidden />
          {t.book.contents}
        </button>
        <span className="truncate font-[family-name:var(--font-display)] text-lg" style={{ color: CLASS_COLOURS[character.class] }}>
          {character.name}
        </span>
      </div>
      <ContentsDrawer open={contents} onClose={() => setContents(false)} id={id} character={character} book={book} current={part} />
      <article className="page mt-3 rounded-md px-6 py-8 sm:px-12 sm:py-10">
        <header className="text-center">
          <h1 className={here.kind === "epitaph" ? "title text-3xl text-fallen" : "title text-3xl text-[#7a5410]"}>{title}</h1>
          {sub && <p className="mt-1 italic text-ink-faded">{sub}</p>}
        </header>
        <div className={here.kind === "epitaph" ? "mt-6 space-y-4 text-center text-xl italic leading-relaxed" : "mt-6 space-y-4 text-xl leading-relaxed"}>
          {paragraphs(text).length === 0 && <p className="italic text-ink-faded">{t.book.nothingYet}</p>}
          {paragraphs(text).map((p, i) => (
            <p key={i} className={i === 0 && here.kind === "chapter" ? "first-letter:float-left first-letter:mr-1 first-letter:font-[family-name:var(--font-display)] first-letter:text-5xl first-letter:leading-none first-letter:text-[#7a5410]" : undefined}>
              {p}
            </p>
          ))}
        </div>
      </article>
      <nav className="mt-4 flex items-center justify-between gap-2 text-gold-bright">
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
