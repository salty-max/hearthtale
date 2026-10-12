import type { PublicCharacter } from "@hearthtale/shared";
import { Flame, Skull } from "lucide-react";
import { Crest } from "@/components/Crest";
import { useT } from "@/lib/i18n";
import { classColour, raceClass, realmName } from "@/lib/wow";

/** Who the book belongs to (the contents): the crest, the name in its class colour, level, race and class, realm. */
export function CharacterHeader({ character: c }: { character: PublicCharacter }) {
  const t = useT();
  return (
    <div className="text-center">
      <Crest token={c.class} size={56} className="mx-auto" />
      <p className="mt-2 font-[family-name:var(--font-display)] text-3xl" style={{ color: classColour(c.class) }}>
        {c.name}
      </p>
      <p className="ui text-parchment/80">
        {t.library.level(c.level)} {raceClass(t, c)}
        {realmName(t, c) && <span className="block text-sm text-parchment/55">{realmName(t, c)}</span>}
      </p>
      {(c.fallen || c.hardcore) && (
        <p className="mt-2">
          <span className={`tag ${c.fallen ? "text-blood" : "text-ember"}`}>
            {c.fallen ? <Skull className="size-3" aria-hidden /> : <Flame className="size-3" aria-hidden />}
            {c.fallen ? t.library.fallen : t.library.hardcore}
          </span>
        </p>
      )}
    </div>
  );
}
