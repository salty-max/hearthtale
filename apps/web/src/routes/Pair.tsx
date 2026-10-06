import { Link, useSearch } from "@tanstack/react-router";
import { Check, Monitor } from "lucide-react";
import { Loading } from "@/components/PageState";
import { SignIn } from "@/components/SignIn";
import { useConfirmPairing, useMe, usePairing } from "@/lib/api";
import { useT } from "@/lib/i18n";

/** Ravenpost opened this page: the signed-in account takes this computer's uploads. */
export function Pair() {
  const t = useT();
  const { code = "" } = useSearch({ from: "/pair" });
  const me = useMe();
  const pairing = usePairing(code);
  const confirm = useConfirmPairing();
  if (me.isPending || pairing.isPending) return <Loading />;
  if (!me.data)
    return (
      <section className="mx-auto mt-4 max-w-3xl">
        <h1 className="title text-3xl">{t.pair.title}</h1>
        <SignIn next={`/pair?code=${code}`} />
      </section>
    );
  const done = confirm.isSuccess;
  return (
    <section className="page mx-auto mt-6 max-w-md rounded-md px-6 py-8 text-center">
      <Monitor className="mx-auto size-10 text-[#7a5410]" aria-hidden />
      <h1 className="title mt-3 text-2xl text-[#7a5410]">{t.pair.title}</h1>
      {done ? (
        <>
          <p className="mt-4 flex items-center justify-center gap-2 text-lg">
            <Check className="size-5" aria-hidden />
            {t.pair.done}
          </p>
          <Link to="/library" className="btn mt-6">
            {t.nav.library}
          </Link>
        </>
      ) : !pairing.data?.pending || confirm.isError ? (
        <p className="mt-4 text-lg">{t.pair.expired}</p>
      ) : (
        <>
          <p className="mt-4 text-lg">{t.pair.ask(me.data.battletag?.split("#")[0] ?? t.account.you)}</p>
          <p className="mt-3 font-mono text-2xl tracking-widest">{code}</p>
          <p className="mt-2 text-ink-faded">{t.pair.check}</p>
          <button onClick={() => confirm.mutate(code)} disabled={confirm.isPending} className="btn mt-6">
            {t.pair.confirm}
          </button>
        </>
      )}
    </section>
  );
}
