import type { CharacterSummary } from "@hearthtale/shared";
import { Flame, Skull } from "lucide-react";
import { useT } from "@/lib/i18n";
import { CLASS_COLOURS, raceClass, realmName } from "@/lib/wow";

/** Who the book belongs to (in the contents drawer): name in its class colour, level, race and class, realm. */
export function CharacterHeader({ character: c }: { character: CharacterSummary }) {
  const t = useT();
  return (
    <div className="text-center">
      <p className="font-[family-name:var(--font-display)] text-3xl" style={{ color: CLASS_COLOURS[c.class] }}>
        {c.name}
      </p>
      <p className="text-lg text-parchment/80">
        {t.library.level(c.level)} {raceClass(t, c)}
        {realmName(t, c) && <span className="text-parchment/55"> · {realmName(t, c)}</span>}
      </p>
      {(c.fallen || c.hardcore) && (
        <p className={c.fallen ? "mt-1 flex items-center justify-center gap-1 text-[#e0705f]" : "mt-1 flex items-center justify-center gap-1 text-ember"}>
          {c.fallen ? <Skull className="size-4" aria-hidden /> : <Flame className="size-4" aria-hidden />}
          {c.fallen ? t.library.fallen : t.library.hardcore}
        </p>
      )}
    </div>
  );
}
