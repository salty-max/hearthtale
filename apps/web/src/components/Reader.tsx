import type { Book, PublicCharacter } from "@hearthtale/shared";
import { useRouter } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight, List } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { CharacterHeader } from "@/components/CharacterHeader";
import { Contents } from "@/components/Contents";
import { ContentsDrawer } from "@/components/ContentsDrawer";
import { Crest } from "@/components/Crest";
import { Flourish } from "@/components/Flourish";
import { LoadError } from "@/components/PageState";
import { PartLink } from "@/components/PartLink";
import { paragraphs, partTitle, parts, partSub } from "@/lib/book";
import { useLocale, useT } from "@/lib/i18n";
import { readerClasses, useSettings } from "@/lib/settings";
import { useTitle } from "@/lib/title";
import { classColour } from "@/lib/wow";

/**
 * The reader: one part of a book on its page (the prologue, a chapter as its
 * diary entry, or the epitaph), the previous and next parts below; the
 * contents in a drawer, or beside the page on a wide screen, as in the game.
 * The arrow keys and a swipe turn the pages.
 * Wherever the book comes from (my library, a share link, the Hall): `hrefFor`
 * gives each part's address, `lead` sits before the toolbar's title (a way
 * back), `actions` after it, `banner` above it all (a word for visitors), and
 * `onRead` hears which part is shown.
 */
export function Reader({
  character,
  book,
  part,
  hrefFor,
  lead,
  actions,
  banner,
  onRead,
}: {
  character: PublicCharacter;
  book: Book;
  part: string;
  hrefFor: (part: string) => string;
  lead?: ReactNode;
  actions?: ReactNode;
  banner?: ReactNode;
  onRead?: (part: string) => void;
}) {
  const t = useT();
  const locale = useLocale();
  const router = useRouter();
  const [contents, setContents] = useState(false);
  const settings = useSettings();
  const all = parts(book);
  const at = all.findIndex((p) => p.key === part);
  const here = all[at];
  const prev = all[at - 1];
  const next = all[at + 1];
  const title = here ? partTitle(t, book, here) : "";
  useTitle(title, character.name);
  useEffect(() => {
    if (here) onRead?.(here.key);
  }, [here, onRead]);

  // The arrow keys turn the pages (not while typing, nor under a dialog).
  useEffect(() => {
    const turn = (e: KeyboardEvent) => {
      if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
      const el = e.target instanceof Element ? e.target : null;
      if (el?.closest("input, textarea, select, [contenteditable=true], dialog[open]") || document.querySelector("dialog[open]")) return;
      const to = e.key === "ArrowLeft" ? prev : e.key === "ArrowRight" ? next : undefined;
      if (!to) return;
      e.preventDefault();
      void router.navigate({ href: hrefFor(to.key) });
    };
    window.addEventListener("keydown", turn);
    return () => window.removeEventListener("keydown", turn);
  }, [prev, next, hrefFor, router]);

  // A swipe across the page turns it (a mostly sideways one, long enough).
  const touch = useRef<{ x: number; y: number } | null>(null);
  const swipe = {
    onTouchStart: (e: React.TouchEvent) => {
      touch.current = { x: e.touches[0].clientX, y: e.touches[0].clientY };
    },
    onTouchEnd: (e: React.TouchEvent) => {
      const s = touch.current;
      touch.current = null;
      if (!s) return;
      const dx = e.changedTouches[0].clientX - s.x;
      const dy = e.changedTouches[0].clientY - s.y;
      if (Math.abs(dx) < 70 || Math.abs(dy) > Math.abs(dx) * 0.6) return;
      const to = dx > 0 ? prev : next;
      if (to) void router.navigate({ href: hrefFor(to.key) });
    },
  };

  if (!here) return <LoadError message={t.book.notFound} />;
  const several = all.length > 1;
  const ch = here.kind === "chapter" ? book.chapters.find((c) => c.number === here.number) : undefined;
  // (a chapter as its diary entry; a book saved before entries were, its prose)
  const text = here.kind === "prologue" ? book.prologue : here.kind === "epitaph" ? book.epitaph : (ch?.diary ?? ch?.text);
  const sub = partSub(t, locale, character, book, here);
  const cls = readerClasses(settings);
  const fallenColour = settings.theme === "night" ? "text-[#e0705f]" : "text-fallen";
  return (
    <section className="no-print mx-auto flex h-full max-w-6xl gap-6">
      {several && (
        <aside aria-label={t.book.contents} className="panel hidden w-80 shrink-0 flex-col overflow-hidden xl:flex">
          <div className="px-4 pt-5 pb-4">
            <CharacterHeader character={character} />
          </div>
          <nav aria-label={t.book.contents} className="min-h-0 flex-1 overflow-y-auto border-t border-gold/15">
            <Contents hrefFor={hrefFor} book={book} current={part} />
          </nav>
        </aside>
      )}
      <div className="mx-auto flex h-full w-full max-w-2xl min-w-0 flex-col">
        {banner}
        <div className="flex shrink-0 items-center justify-between gap-3">
          <span className="flex items-center gap-2">
            {lead}
            {several && (
              <button onClick={() => setContents(true)} className="btn px-3 py-1.5 xl:hidden" aria-haspopup="dialog" aria-expanded={contents}>
                <List className="size-4" aria-hidden />
                <span className="hidden sm:inline">{t.book.contents}</span>
              </button>
            )}
          </span>
          <span className="flex min-w-0 items-center gap-2">
            <Crest token={character.class} size={26} />
            <span className="truncate font-display text-lg" style={{ color: classColour(character.class) }}>
              {character.name}
            </span>
            {actions}
          </span>
        </div>
        {several && (
          <ContentsDrawer open={contents} onClose={() => setContents(false)} hrefFor={hrefFor} character={character} book={book} current={part} />
        )}
        {/* The page stays still; only its text scrolls (a new part starts at its top). */}
        <article className={`${cls.page} mt-3 flex min-h-0 flex-1 flex-col overflow-hidden rounded-md`} {...swipe}>
          <div key={part} className="fade-in min-h-0 flex-1 overflow-y-auto overscroll-contain px-6 py-8 sm:px-12 sm:py-10">
            <header className="text-center">
              <h1 className={here.kind === "epitaph" ? `title text-3xl sm:text-4xl ${fallenColour}` : "title page-title text-3xl sm:text-4xl"}>{title}</h1>
              {sub && <p className="page-faded mt-1.5 italic">{sub}</p>}
              <Flourish className="page-title mt-3 opacity-70" />
            </header>
            <div className={`mt-5 space-y-4 ${cls.text} ${here.kind === "epitaph" ? "text-center italic" : ""}`}>
              {paragraphs(text).length === 0 && <p className="page-faded italic">{t.book.nothingYet}</p>}
              {paragraphs(text).map((p, i) => (
                <p key={i} className={i === 0 && here.kind === "chapter" ? "drop-cap" : undefined}>
                  {p}
                </p>
              ))}
            </div>
            {/* The player's own note, set apart from the journal's words. */}
            {ch?.note && (
              <aside className={`mt-8 border-t border-current/15 pt-4 ${cls.text}`}>
                <p className="page-faded ui text-sm tracking-wide uppercase">{t.book.note}</p>
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
          <nav aria-label={t.book.contents} className="ui grid shrink-0 grid-cols-[1fr_auto_1fr] items-center gap-2 pt-3 pb-[max(0rem,env(safe-area-inset-bottom))] text-gold-bright">
            {prev ? (
              <PartLink href={hrefFor(prev.key)} className="flex min-w-0 items-center gap-1 hover:underline" title={t.book.keys}>
                <ChevronLeft className="size-4 shrink-0" aria-hidden />
                <span className="truncate">{partTitle(t, book, prev)}</span>
              </PartLink>
            ) : (
              <span />
            )}
            <span className="font-narrow text-parchment/55">{t.book.of(at + 1, all.length)}</span>
            {next ? (
              <PartLink href={hrefFor(next.key)} className="flex min-w-0 items-center justify-end gap-1 hover:underline" title={t.book.keys}>
                <span className="truncate">{partTitle(t, book, next)}</span>
                <ChevronRight className="size-4 shrink-0" aria-hidden />
              </PartLink>
            ) : (
              <span />
            )}
          </nav>
        )}
      </div>
    </section>
  );
}
