import type { Book, CharacterSummary, Share } from "@hearthtale/shared";
import { Check, Copy, Link2, Share2, Trash2, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useCreateShare, useRevokeShare, useSetInHall, useShares } from "@/lib/api";
import { useLocale, useT } from "@/lib/i18n";

/**
 * Sharing one of my books: a link to this part or to the whole book (anyone
 * with it reads that, nothing else), the links already made (each can be
 * revoked), and for a fallen book, the public Hall of the Fallen.
 */
export function ShareDialog({ open, onClose, character, book, part }: { open: boolean; onClose: () => void; character: CharacterSummary; book: Book; part: string }) {
  const t = useT();
  const locale = useLocale();
  const ref = useRef<HTMLDialogElement>(null);
  const shares = useShares(character.id);
  const create = useCreateShare(character.id);
  const revoke = useRevokeShare(character.id);
  const hall = useSetInHall(character.id);
  const [copied, setCopied] = useState<string | null>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  const partName = (p?: string) =>
    p === undefined ? t.share.wholeBook : p === "prologue" ? t.book.prologue : p === "epitaph" ? t.book.epitaph : t.book.chapter(Number(p));
  const copy = (s: Share) => void navigator.clipboard?.writeText(s.url).then(() => setCopied(s.token));
  const send = (s: Share) => {
    if (navigator.share) void navigator.share({ title: `${character.name}: ${partName(s.part)}`, url: s.url }).catch(() => {});
    else copy(s);
  };
  const made = create.data;
  const several = book.chapters.length + (book.prologue ? 1 : 0) + (book.epitaph ? 1 : 0) > 1;

  return (
    <dialog
      ref={ref}
      aria-label={t.share.title}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
      className="drawer-centre m-auto max-h-[85dvh] w-[28rem] max-w-[92vw] overflow-y-auto rounded-md border border-leather-edge bg-leather p-0 text-parchment"
    >
      <div className="p-5">
        <div className="flex items-center justify-between">
          <h2 className="title text-xl">{t.share.title}</h2>
          <button onClick={onClose} aria-label={t.book.close} className="rounded p-1.5 text-parchment/70 hover:text-parchment">
            <X className="size-5" />
          </button>
        </div>
        <p className="mt-2 text-parchment/75">{t.share.why}</p>

        <div className="mt-4 flex flex-wrap gap-2">
          <button onClick={() => create.mutate(part)} disabled={create.isPending} className="btn">
            <Link2 className="size-4" aria-hidden />
            {t.share.thisPart(partName(part))}
          </button>
          {several && (
            <button onClick={() => create.mutate(undefined)} disabled={create.isPending} className="btn">
              <Link2 className="size-4" aria-hidden />
              {t.share.wholeBook}
            </button>
          )}
        </div>
        {made && (
          <div className="mt-3 rounded-md border border-gold/40 bg-night/60 p-3">
            <p className="break-all font-mono text-sm text-gold-bright">{made.url}</p>
            <div className="mt-2 flex gap-2">
              <button onClick={() => copy(made)} className="btn">
                {copied === made.token ? <Check className="size-4" aria-hidden /> : <Copy className="size-4" aria-hidden />}
                {t.share.copy}
              </button>
              {typeof navigator !== "undefined" && "share" in navigator && (
                <button onClick={() => send(made)} className="btn">
                  <Share2 className="size-4" aria-hidden />
                  {t.share.send}
                </button>
              )}
            </div>
          </div>
        )}
        {create.isError && <p className="mt-2 text-[#e0705f]">{t.common.loadError}</p>}

        {(shares.data?.length ?? 0) > 0 && (
          <>
            <h3 className="title mt-6 text-lg">{t.share.made}</h3>
            <ul className="mt-2 divide-y divide-parchment/10">
              {shares.data!.map((s) => (
                <li key={s.token} className="flex items-center justify-between gap-2 py-2">
                  <span>
                    {partName(s.part)}
                    <span className="block text-sm text-parchment/55">{new Intl.DateTimeFormat(locale, { dateStyle: "medium" }).format(new Date(s.createdAt))}</span>
                  </span>
                  <span className="flex shrink-0 gap-1">
                    <button onClick={() => copy(s)} aria-label={t.share.copy} title={t.share.copy} className="rounded p-2 text-parchment/70 hover:text-parchment">
                      {copied === s.token ? <Check className="size-4" /> : <Copy className="size-4" />}
                    </button>
                    <button onClick={() => revoke.mutate(s.token)} aria-label={t.share.revoke} title={t.share.revoke} className="rounded p-2 text-parchment/70 hover:text-[#e0705f]">
                      <Trash2 className="size-4" />
                    </button>
                  </span>
                </li>
              ))}
            </ul>
            <p className="mt-1 text-sm text-parchment/55">{t.share.revokeHint}</p>
          </>
        )}

        {character.fallen && (
          <label className="mt-6 flex cursor-pointer items-start gap-3 rounded-md border border-leather-edge p-3">
            <input type="checkbox" checked={!!character.inHall} disabled={hall.isPending} onChange={(e) => hall.mutate(e.target.checked)} className="mt-1 size-4 accent-[#c9a227]" />
            <span>
              {t.share.hall}
              <span className="block text-sm text-parchment/60">{t.share.hallWhy}</span>
            </span>
          </label>
        )}
      </div>
    </dialog>
  );
}
