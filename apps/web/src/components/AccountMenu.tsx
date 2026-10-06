import { Link } from "@tanstack/react-router";
import { LogOut } from "lucide-react";
import { useMe, useSignOut } from "@/lib/api";
import { useT } from "@/lib/i18n";

/** In the header: the signed-in BattleTag and a way out, or the way in. */
export function AccountMenu() {
  const t = useT();
  const { data: me } = useMe();
  const signOut = useSignOut();
  if (me === undefined) return null;
  if (!me)
    return (
      <Link to="/library" className="text-parchment/80 hover:text-parchment">
        {t.account.signInShort}
      </Link>
    );
  return (
    <span className="flex items-center gap-2 text-parchment/80">
      <span className="max-w-32 truncate">{me.battletag?.split("#")[0] ?? t.account.you}</span>
      <button onClick={() => signOut.mutate()} aria-label={t.account.signOut} title={t.account.signOut} className="rounded p-1 hover:text-parchment">
        <LogOut className="size-4" />
      </button>
    </span>
  );
}
