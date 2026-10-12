import { useT } from "@/lib/i18n";

/** The game's skull (as a deadly foe's unit frame shows it), as the addon's book marks a Hardcore life. */
export function Skull({ size = 16, className = "" }: { size?: number; className?: string }) {
  return <img src="/ui/skull.png" alt="" width={size} height={size} className={`inline-block shrink-0 ${className}`} decoding="async" />;
}

/** A Hardcore life's mark, as in the game: the skull and the word, "Fallen" once its book is closed. */
export function HardcoreMark({ fallen, className = "" }: { fallen: boolean; className?: string }) {
  const t = useT();
  return (
    <span className={`tag ${fallen ? "text-blood" : "text-ember"} ${className}`}>
      <Skull size={16} className="-my-0.5" />
      {fallen ? t.library.fallen : t.library.hardcore}
    </span>
  );
}
