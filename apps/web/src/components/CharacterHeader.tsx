import type { PublicCharacter } from "@hearthtale/shared";
import { Crest } from "@/components/Crest";
import { HardcoreMark } from "@/components/HardcoreMark";
import { useFrame } from "@/lib/i18n";
import { aboutLine, classColour, realmName } from "@/lib/wow";

/** Who the book belongs to (the contents): the crest, the name in its class colour, level, race and class, realm. */
export function CharacterHeader({ character: c }: { character: PublicCharacter }) {
  const f = useFrame();
  return (
    <div className="text-center">
      <Crest token={c.class} size={56} className="mx-auto" />
      <p className="mt-2 font-display text-2xl font-semibold" style={{ color: classColour(c.class) }}>
        {c.name}
      </p>
      <p className="ui text-parchment/80">
        {aboutLine(f, c)}
        {realmName(c) && <span className="block text-sm text-parchment/55">{realmName(c)}</span>}
      </p>
      {(c.fallen || c.hardcore) && (
        <p className="mt-2">
          <HardcoreMark fallen={c.fallen} />
        </p>
      )}
    </div>
  );
}
