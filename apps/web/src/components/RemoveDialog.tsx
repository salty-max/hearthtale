import type { CharacterSummary } from "@hearthtale/shared";
import { useNavigate } from "@tanstack/react-router";
import { Trash2 } from "lucide-react";
import { Dialog } from "@/components/Dialog";
import { useRemoveBook } from "@/lib/api";
import { useT } from "@/lib/i18n";

/**
 * Removing one of my books from the site, once confirmed: the book and its
 * share links go, and its companion's uploads are refused until a new link
 * code brings it back. Then the library.
 */
export function RemoveDialog({ open, onClose, character }: { open: boolean; onClose: () => void; character: CharacterSummary }) {
  const t = useT();
  const remove = useRemoveBook(character.id);
  const navigate = useNavigate();
  const confirm = () => remove.mutate(undefined, { onSuccess: () => void navigate({ to: "/library" }) });
  return (
    <Dialog open={open} onClose={onClose} title={t.remove.title}>
      <p className="mt-2 text-parchment/85">{t.remove.why(character.name)}</p>
      <p className="mt-2 text-parchment/70">{t.remove.companion}</p>
      <div className="mt-5 flex flex-wrap justify-end gap-2">
        <button onClick={onClose} className="btn">
          {t.remove.cancel}
        </button>
        <button onClick={confirm} disabled={remove.isPending} className="btn border-blood/60 text-blood hover:bg-blood/10">
          <Trash2 className="size-4" aria-hidden />
          {t.remove.confirm}
        </button>
      </div>
      {remove.isError && <p className="mt-2 text-blood">{t.remove.failed}</p>}
    </Dialog>
  );
}
