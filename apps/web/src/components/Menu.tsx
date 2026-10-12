import { useEffect, useId, useRef, useState, type ReactNode } from "react";

export type MenuItem = { label: string; icon?: ReactNode; onSelect: () => void; danger?: boolean };

/**
 * A button that opens a short list of actions (a book's More): Escape, a click
 * elsewhere or a choice closes it; the arrows move between its items.
 */
export function Menu({ label, icon, items }: { label: string; icon: ReactNode; items: MenuItem[] }) {
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const id = useId();
  useEffect(() => {
    if (!open) return;
    const away = (e: PointerEvent) => {
      if (!box.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", away);
    box.current?.querySelector<HTMLButtonElement>("[role=menuitem]")?.focus();
    return () => document.removeEventListener("pointerdown", away);
  }, [open]);
  const keys = (e: React.KeyboardEvent) => {
    const all = [...(box.current?.querySelectorAll<HTMLButtonElement>("[role=menuitem]") ?? [])];
    const at = all.indexOf(document.activeElement as HTMLButtonElement);
    if (e.key === "Escape") {
      setOpen(false);
      box.current?.querySelector<HTMLButtonElement>("[aria-haspopup]")?.focus();
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      all[(at + 1) % all.length]?.focus();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      all[(at - 1 + all.length) % all.length]?.focus();
    }
  };
  return (
    <div ref={box} className="relative" onKeyDown={keys}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={id}
        aria-label={label}
        title={label}
        className="rounded-md p-1.5 text-gold-bright hover:bg-gold/10"
      >
        {icon}
      </button>
      {open && (
        <div id={id} role="menu" aria-label={label} className="panel fade-in absolute right-0 z-30 mt-1 min-w-56 py-1">
          {items.map((item) => (
            <button
              key={item.label}
              role="menuitem"
              onClick={() => {
                setOpen(false);
                item.onSelect();
              }}
              className={`ui flex w-full items-center gap-3 px-4 py-2 text-left hover:bg-gold/10 focus:bg-gold/10 focus:outline-none ${item.danger ? "text-blood" : "text-parchment"}`}
            >
              {item.icon}
              {item.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
