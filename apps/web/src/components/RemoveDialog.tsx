import type { CharacterSummary } from "@hearthtale/shared";
import { useNavigate } from "@tanstack/react-router";
import { Trash2, X } from "lucide-react";
import { useEffect, useRef } from "react";
import { useRemoveBook } from "@/lib/api";
import { useT } from "@/lib/i18n";

/**
 * Removing one of my books from the site, once confirmed: the book and its
 * share links go, and its companion's uploads are refused until a new link
 * code brings it back. Then the library.
 */
export function RemoveDialog({ open, onClose, character }: { open: boolean; onClose: () => void; character: CharacterSummary }) {
  const t = useT();
  const ref = useRef<HTMLDialogElement>(null);
  const remove = useRemoveBook(character.id);
  const navigate = useNavigate();
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  const confirm = () => remove.mutate(undefined, { onSuccess: () => void navigate({ to: "/library" }) });

  return (
    <dialog
      ref={ref}
      aria-label={t.remove.title}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
      className="drawer-centre m-auto max-h-[85dvh] w-[28rem] max-w-[92vw] overflow-y-auto rounded-md border border-leather-edge bg-leather p-0 text-parchment"
    >
      <div className="p-5">
        <div className="flex items-center justify-between">
          <h2 className="title text-xl">{t.remove.title}</h2>
          <button onClick={onClose} aria-label={t.book.close} className="rounded p-1.5 text-parchment/70 hover:text-parchment">
            <X className="size-5" />
          </button>
        </div>
        <p className="mt-2 text-parchment/85">{t.remove.why(character.name)}</p>
        <p className="mt-2 text-parchment/70">{t.remove.companion}</p>
        <div className="mt-5 flex flex-wrap justify-end gap-2">
          <button onClick={onClose} className="btn">
            {t.remove.cancel}
          </button>
          <button onClick={confirm} disabled={remove.isPending} className="btn border-[#e0705f]/60 text-[#e0705f] hover:bg-[#e0705f]/10">
            <Trash2 className="size-4" aria-hidden />
            {t.remove.confirm}
          </button>
        </div>
        {remove.isError && <p className="mt-2 text-[#e0705f]">{t.remove.failed}</p>}
      </div>
    </dialog>
  );
}
