import { langOf, type Book, type PublicCharacter } from "@hearthtale/shared";
import { SubLine } from "@/components/SubLine";
import { paragraphs, partLang, partSubPieces, partTitle, parts } from "@/lib/book";
import { useFrame } from "@/lib/i18n";
import { realmName } from "@/lib/wow";

/** The whole book as it prints (Save as PDF): unseen on the screen; on paper, a title page and each part from a new page. The labels in the site's language, the book's words in its own. */
export function PrintBook({ character, book }: { character: PublicCharacter; book: Book }) {
  const f = useFrame();
  const bookLang = langOf(book.language);
  return (
    <div lang={bookLang} className="print-book font-book text-[12pt] leading-relaxed text-black">
      <header className="pt-[30vh] text-center">
        <h1 lang={f.lang} className="font-display text-[28pt] font-semibold">{f.by(character.name)}</h1>
        <p lang={f.lang} className="mt-2 italic">{[f.about(character.level, character.race, character.class, book.sex ?? character.sex), realmName(character)].filter(Boolean).join(" · ")}</p>
      </header>
      {parts(book).map((p) => {
        const ch = p.kind === "chapter" ? book.chapters.find((c) => c.number === p.number) : undefined;
        const text = p.kind === "prologue" ? book.prologue : p.kind === "epitaph" ? book.epitaph : (ch?.diary ?? ch?.text);
        const sub = partSubPieces(f, character, book, p);
        return (
          <section key={p.key} className="break-before-page pt-8">
            <h2 lang={partLang(f, book, p)} className="text-center font-display text-[20pt] font-semibold">{partTitle(f, book, p)}</h2>
            {sub.length > 0 && (
              <p lang={f.lang} className="mb-6 text-center italic">
                <SubLine pieces={sub} bookLang={bookLang} />
              </p>
            )}
            <div className={`space-y-3 ${p.kind === "epitaph" ? "text-center italic" : ""}`}>
              {paragraphs(text).map((para, i) => (
                <p key={i}>{para}</p>
              ))}
            </div>
            {ch?.note && (
              <aside className="mt-6 border-t pt-3 italic">
                <p lang={f.lang} className="text-[10pt] uppercase not-italic">
                  {f.note}
                </p>
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
