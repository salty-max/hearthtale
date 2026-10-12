import { useT } from "@/lib/i18n";

/** The game's skull (as a deadly foe's unit frame shows it), as the addon's book marks a Hardcore life. */
export function Skull({ size = 16, className = "" }: { size?: number; className?: string }) {
  return <img src="/ui/skull.png" alt="" width={size} height={size} className={`inline-block shrink-0 ${className}`} decoding="async" />;
}

/**
 * A Hardcore life's mark, as the addon's book draws it beside the portrait:
 * the game's skull and the word in the title's face, "Fallen" in red once its
 * book is closed; what it means on hover.
 */
export function HardcoreMark({ fallen, className = "" }: { fallen: boolean; className?: string }) {
  const t = useT();
  return (
    <span
      title={fallen ? t.library.fallenWhy : t.library.hardcoreWhy}
      className={`inline-flex items-center gap-1.5 font-display text-base font-semibold leading-none ${fallen ? "text-blood" : "text-gold"} ${className}`}
    >
      <Skull size={20} className="drop-shadow-[0_1px_2px_rgb(0_0_0/0.5)]" />
      {fallen ? t.library.fallen : t.library.hardcore}
    </span>
  );
}
