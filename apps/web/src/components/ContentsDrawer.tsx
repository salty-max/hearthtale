import type { CharacterSummary, Book } from "@hearthtale/shared";
import { X } from "lucide-react";
import { useEffect, useRef } from "react";
import { CharacterHeader } from "@/components/CharacterHeader";
import { Contents } from "@/components/Contents";
import { useLocale, useT } from "@/lib/i18n";

/**
 * The table of contents, in a drawer from the left. A modal <dialog>: Escape
 * closes it, focus stays inside while open and returns to the button after;
 * a tap on the backdrop or a pick closes it too.
 */
export function ContentsDrawer({
  open,
  onClose,
  id,
  character,
  book,
  current,
}: {
  open: boolean;
  onClose: () => void;
  id: string;
  character: CharacterSummary;
  book: Book;
  current?: string;
}) {
  const t = useT();
  const locale = useLocale();
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  const written = new Intl.DateTimeFormat(locale, { dateStyle: "long" }).format(new Date(book.at * 1000));
  return (
    <dialog
      ref={ref}
      aria-label={t.book.contents}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === ref.current) onClose(); // the backdrop
      }}
      className="drawer m-0 h-dvh max-h-dvh w-[22rem] max-w-[88vw] border-r border-leather-edge bg-leather p-0 text-parchment"
    >
      <div className="flex h-full flex-col">
        <div className="flex items-center justify-between px-4 pt-[max(1rem,env(safe-area-inset-top))]">
          <h2 className="title text-xl">{t.book.contents}</h2>
          <button onClick={onClose} aria-label={t.book.close} className="rounded p-2 text-parchment/70 hover:text-parchment">
            <X className="size-5" />
          </button>
        </div>
        <div className="px-4 pt-2 pb-4">
          <CharacterHeader character={character} />
        </div>
        <nav aria-label={t.book.contents} className="flex-1 overflow-y-auto">
          <Contents id={id} book={book} current={current} onPick={onClose} />
        </nav>
        <p className="px-4 pt-3 pb-[max(1rem,env(safe-area-inset-bottom))] text-center text-sm text-parchment/45">
          {t.book.written(written, book.version)}
        </p>
      </div>
    </dialog>
  );
}
