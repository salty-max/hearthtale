import { Check, Copy, Link2, RefreshCw } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { useLinkCode } from "@/lib/api";
import { useLocale, useT } from "@/lib/i18n";

/**
 * Linking a character Battle.net can't list (Forever), from the top bar: a
 * button opening a code to type in the game, asked for as it opens (a new one
 * at will, or once the last has run out). Escape or a click elsewhere closes
 * it; the code stays while the page does.
 */
export function LinkCharacter() {
  const t = useT();
  const locale = useLocale();
  const link = useLinkCode();
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const id = useId();
  const fresh = () => {
    setCopied(false);
    link.mutate();
  };
  const toggle = () => {
    const spent = !link.data || Date.parse(link.data.expiresAt) <= Date.now();
    if (!open && spent && !link.isPending) fresh();
    setOpen((o) => !o);
  };
  useEffect(() => {
    if (!open) return;
    const away = (e: PointerEvent) => {
      if (!box.current?.contains(e.target as Node)) setOpen(false);
    };
    const esc = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      setOpen(false);
      box.current?.querySelector<HTMLButtonElement>("[aria-controls]")?.focus();
    };
    document.addEventListener("pointerdown", away);
    document.addEventListener("keydown", esc);
    return () => {
      document.removeEventListener("pointerdown", away);
      document.removeEventListener("keydown", esc);
    };
  }, [open]);
  const command = link.data ? `/ht link ${link.data.code}` : "";
  const until = link.data ? new Date(link.data.expiresAt).toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" }) : "";
  return (
    // (on a phone the panel spans the top bar, on a wider screen it hangs from the button)
    <div ref={box} className="md:relative">
      <button onClick={toggle} aria-expanded={open} aria-controls={id} className={`btn px-3 py-1.5 text-sm ${open ? "border-gold-bright" : ""}`}>
        <Link2 className="size-4" aria-hidden />
        <span className="hidden sm:inline">{t.link.title}</span>
        <span className="sm:hidden">{t.link.short}</span>
      </button>
      {open && (
        <div id={id} role="dialog" aria-label={t.link.title} className="panel fade-in absolute inset-x-3 top-full z-40 mt-2 p-4 md:inset-x-auto md:right-0 md:w-[23rem]">
          <h2 className="title text-lg">{t.link.title}</h2>
          <p className="mt-1 text-sm text-parchment/75">{t.link.why}</p>
          {link.data && (
            <>
              <p className="mt-3 text-sm">{t.link.type}</p>
              <code className="mt-1.5 block truncate rounded bg-night px-3 py-2 font-mono text-lg tracking-wider text-gold-bright">{command}</code>
              <div className="mt-2.5 flex flex-wrap gap-2">
                <button onClick={() => void navigator.clipboard?.writeText(command).then(() => setCopied(true))} className="btn btn-primary px-3 py-1.5 text-sm">
                  {copied ? <Check className="size-4" aria-hidden /> : <Copy className="size-4" aria-hidden />}
                  {copied ? t.link.copied : t.link.copy}
                </button>
                <button onClick={fresh} disabled={link.isPending} className="btn px-3 py-1.5 text-sm">
                  <RefreshCw className={`size-4${link.isPending ? " animate-spin" : ""}`} aria-hidden />
                  {t.link.again}
                </button>
              </div>
              <p className="mt-2 text-sm text-parchment/60">{t.link.then(until)}</p>
            </>
          )}
          {!link.data && link.isPending && <p className="mt-3 text-sm text-parchment/60">{t.common.loading}</p>}
          {link.isError && (
            <p className="mt-3 flex items-center justify-between gap-2 text-sm text-blood">
              {t.common.loadError}
              <button onClick={fresh} className="btn px-3 py-1 text-sm">
                {t.link.get}
              </button>
            </p>
          )}
        </div>
      )}
    </div>
  );
}
