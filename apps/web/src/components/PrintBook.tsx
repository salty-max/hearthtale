import type { Book, PublicCharacter } from "@hearthtale/shared";
import { paragraphs, partSub, partTitle, parts } from "@/lib/book";
import { useLocale, useT } from "@/lib/i18n";
import { raceClass, realmName } from "@/lib/wow";

/** The whole book as it prints (Save as PDF): unseen on the screen; on paper, a title page and each part from a new page. */
export function PrintBook({ character, book }: { character: PublicCharacter; book: Book }) {
  const t = useT();
  const locale = useLocale();
  return (
    <div className="print-book font-book text-[12pt] leading-relaxed text-black">
      <header className="pt-[30vh] text-center">
        <h1 className="font-display text-[28pt]">{t.exports.by(character.name)}</h1>
        <p className="mt-2 italic">{[`${t.library.level(character.level)} ${raceClass(t, character)}`, realmName(t, character)].filter(Boolean).join(" · ")}</p>
      </header>
      {parts(book).map((p) => {
        const ch = p.kind === "chapter" ? book.chapters.find((c) => c.number === p.number) : undefined;
        const text = p.kind === "prologue" ? book.prologue : p.kind === "epitaph" ? book.epitaph : (ch?.diary ?? ch?.text);
        const sub = partSub(t, locale, character, book, p);
        return (
          <section key={p.key} className="break-before-page pt-8">
            <h2 className="text-center font-display text-[20pt]">{partTitle(t, book, p)}</h2>
            {sub && <p className="mb-6 text-center italic">{sub}</p>}
            <div className={`space-y-3 ${p.kind === "epitaph" ? "text-center italic" : ""}`}>
              {paragraphs(text).map((para, i) => (
                <p key={i}>{para}</p>
              ))}
            </div>
            {ch?.note && (
              <aside className="mt-6 border-t pt-3 italic">
                <p className="text-[10pt] uppercase not-italic">{t.book.note}</p>
                {ch.note
                  .split(/\n+/)
                  .filter((l) => l.trim())
                  .map((l, i) => (
                    <p key={i}>{l}</p>
                  ))}
              </aside>
            )}
          </section>
        );
      })}
    </div>
  );
}
