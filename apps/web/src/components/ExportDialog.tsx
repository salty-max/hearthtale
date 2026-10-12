import type { Book, PublicCharacter } from "@hearthtale/shared";
import { BookMarked, FileText, Printer } from "lucide-react";
import type { ReactNode } from "react";
import { Dialog } from "@/components/Dialog";
import { epub, fileName, markdown, save } from "@/lib/export";
import { useLocale, useT } from "@/lib/i18n";

/** Downloading one of my books: printed (or saved as a PDF), an EPUB, or text. */
export function ExportDialog({ open, onClose, character, book, id }: { open: boolean; onClose: () => void; character: PublicCharacter; book: Book; id: number }) {
  const t = useT();
  const locale = useLocale();
  const choice = (icon: ReactNode, label: string, hint: string, go: () => void) => (
    <li>
      <button
        onClick={() => {
          go();
          onClose();
        }}
        className="flex w-full items-center gap-3 rounded-md border border-gold/30 p-3 text-left hover:border-gold hover:bg-gold/10"
      >
        <span className="text-gold-bright">{icon}</span>
        <span>
          <span className="ui block text-gold-bright">{label}</span>
          <span className="block text-sm text-parchment/65">{hint}</span>
        </span>
      </button>
    </li>
  );
  return (
    <Dialog open={open} onClose={onClose} title={t.exports.title}>
      <p className="mt-2 text-parchment/75">{t.exports.why}</p>
      <ul className="mt-4 space-y-2">
        {/* (the print window opens once the dialog is closed, so it isn't printed too) */}
        {choice(<Printer className="size-5" aria-hidden />, t.exports.pdf, t.exports.pdfHint, () => setTimeout(() => window.print(), 50))}
        {choice(<BookMarked className="size-5" aria-hidden />, t.exports.epub, t.exports.epubHint, () =>
          save(`${fileName(character)}.epub`, epub(t, locale, character, book, String(id)), "application/epub+zip"),
        )}
        {choice(<FileText className="size-5" aria-hidden />, t.exports.markdown, t.exports.markdownHint, () =>
          save(`${fileName(character)}.md`, markdown(t, locale, character, book), "text/markdown;charset=utf-8"),
        )}
      </ul>
    </Dialog>
  );
}
