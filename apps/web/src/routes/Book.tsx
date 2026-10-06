import { Link, useParams } from "@tanstack/react-router";
import { Skull, Star } from "lucide-react";
import { CharacterHeader } from "@/components/CharacterHeader";
import { LoadError, Loading } from "@/components/PageState";
import { NotFound, useCharacterBook } from "@/lib/api";
import { parts } from "@/lib/book";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";

/** A book's contents: the prologue, each chapter (where, its levels, its marks), the epitaph. */
export function Book() {
  const t = useT();
  const { lang } = useSettings();
  const { id } = useParams({ from: "/book/$id" });
  const { data, isPending, error, refetch } = useCharacterBook(Number(id));
  if (isPending) return <Loading />;
  if (error) return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  const { character, book } = data;
  const written = new Intl.DateTimeFormat(lang, { dateStyle: "long" }).format(new Date(book.at * 1000));
  return (
    <section className="mx-auto mt-4 max-w-2xl">
      <CharacterHeader character={character} />
      <nav aria-label={t.book.contents} className="page mt-6 rounded-md px-5 py-6 sm:px-8">
        <h2 className="title text-center text-xl text-[#7a5410]">{t.book.contents}</h2>
        <ol className="mt-4 divide-y divide-ink/15">
          {parts(book).map((p) => {
            const ch = p.kind === "chapter" ? book.chapters.find((c) => c.number === p.number) : undefined;
            const title = p.kind === "prologue" ? t.book.prologue : p.kind === "epitaph" ? t.book.epitaph : t.book.chapter(p.number);
            return (
              <li key={p.key}>
                <Link
                  to="/book/$id/$part"
                  params={{ id, part: p.key }}
                  className="flex items-center justify-between gap-3 py-3 hover:text-[#7a5410]"
                >
                  <span>
                    <span className={p.kind === "epitaph" ? "font-[family-name:var(--font-display)] text-lg text-fallen" : "font-[family-name:var(--font-display)] text-lg"}>
                      {title}
                    </span>
                    {ch && (
                      <span className="block text-ink-faded">
                        {ch.open ? t.book.stillWriting : ch.place} · {t.book.levels(ch.from, ch.to)}
                      </span>
                    )}
                  </span>
                  <span className="flex shrink-0 gap-1 text-ink-faded">
                    {ch?.close && <Skull className="size-4" aria-label={t.book.closeCall} />}
                    {ch?.rare && <Star className="size-4" aria-label={t.book.rare} />}
                  </span>
                </Link>
              </li>
            );
          })}
        </ol>
      </nav>
      <p className="mt-4 text-center text-sm text-parchment/50">{t.book.written(written, book.version)}</p>
    </section>
  );
}
