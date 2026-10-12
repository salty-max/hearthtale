import { Skull, Star } from "lucide-react";
import { useT } from "@/lib/i18n";

/** An entry's marks, in words beside their signs: a close call (in red), a rare foe slain (in gold). */
export function EntryMarks({ close, rare, className = "" }: { close?: boolean; rare?: boolean; className?: string }) {
  const t = useT();
  if (!close && !rare) return null;
  return (
    <span className={`flex flex-wrap gap-x-3 gap-y-0.5 text-sm font-medium ${className}`}>
      {close && (
        <span className="inline-flex items-center gap-1 text-blood">
          <Skull className="size-3.5" aria-hidden />
          {t.book.closeCall}
        </span>
      )}
      {rare && (
        <span className="inline-flex items-center gap-1 text-gold-bright">
          <Star className="size-3.5" aria-hidden />
          {t.book.rare}
        </span>
      )}
    </span>
  );
}
