import { X } from "lucide-react";
import { useEffect, useRef, type ReactNode } from "react";
import { useT } from "@/lib/i18n";

/**
 * A centred modal <dialog>: Escape closes it, focus stays inside while open
 * and returns after; a tap on the backdrop closes it too.
 */
export function Dialog({ open, onClose, title, children, wide }: { open: boolean; onClose: () => void; title: string; children: ReactNode; wide?: boolean }) {
  const t = useT();
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog
      ref={ref}
      aria-label={title}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
      className={`drawer-centre m-auto max-h-[85dvh] ${wide ? "w-[34rem]" : "w-[28rem]"} max-w-[92vw] overflow-y-auto border-0 bg-transparent p-0 text-parchment`}
    >
      {/* (the panel inside: a modal dialog keeps the browser's own fixed place) */}
      <div className="panel p-5">
        <div className="flex items-center justify-between gap-3">
          <h2 className="title text-xl">{title}</h2>
          <button onClick={onClose} aria-label={t.common.close} className="rounded p-1.5 text-parchment/70 hover:text-parchment">
            <X className="size-5" />
          </button>
        </div>
        {children}
      </div>
    </dialog>
  );
}
