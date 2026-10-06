import { Check, Copy, Link2 } from "lucide-react";
import { useState } from "react";
import { useLinkCode } from "@/lib/api";
import { useLocale, useT } from "@/lib/i18n";

/** A code to type in the game, for a character Battle.net can't list (Forever). */
export function LinkCharacter() {
  const t = useT();
  const locale = useLocale();
  const link = useLinkCode();
  const [copied, setCopied] = useState(false);
  const command = link.data ? `/ht link ${link.data.code}` : "";
  const until = link.data ? new Date(link.data.expiresAt).toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" }) : "";
  return (
    <section className="mt-8 rounded-md border border-leather-edge bg-leather/60 p-4">
      <h2 className="title text-xl">{t.link.title}</h2>
      <p className="mt-1 text-parchment/75">{t.link.why}</p>
      {!link.data ? (
        <button onClick={() => link.mutate()} disabled={link.isPending} className="btn mt-3">
          <Link2 className="size-4" aria-hidden />
          {t.link.get}
        </button>
      ) : (
        <div className="mt-3">
          <p>{t.link.type}</p>
          <div className="mt-2 flex flex-wrap items-center gap-2">
            <code className="whitespace-nowrap rounded bg-night px-3 py-2 font-mono text-lg tracking-wider text-gold-bright">{command}</code>
            <button
              onClick={() => {
                void navigator.clipboard?.writeText(command).then(() => setCopied(true));
              }}
              aria-label={t.link.copy}
              className="rounded p-2 text-parchment/70 hover:text-parchment"
            >
              {copied ? <Check className="size-5" /> : <Copy className="size-5" />}
            </button>
          </div>
          <p className="mt-2 text-sm text-parchment/60">{t.link.then(until)}</p>
        </div>
      )}
      {link.isError && <p className="mt-2 text-[#e0705f]">{t.common.loadError}</p>}
    </section>
  );
}
