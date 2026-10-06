import { Link, useSearch } from "@tanstack/react-router";
import { BookOpen, Flame, Skull } from "lucide-react";
import { LinkCharacter } from "@/components/LinkCharacter";
import { LoadError, Loading } from "@/components/PageState";
import { SignIn } from "@/components/SignIn";
import { useLibrary, useMe } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { CLASS_COLOURS, raceClass, realmName } from "@/lib/wow";

/** The signed-in account's characters, and a way to link more; signing in first. */
export function Library() {
  const t = useT();
  const { signin } = useSearch({ from: "/library" });
  const me = useMe();
  const { data, isPending, isError, refetch } = useLibrary(!!me.data);
  if (me.isPending) return <Loading />;
  if (!me.data)
    return (
      <section className="mx-auto mt-4 max-w-3xl">
        <h1 className="title text-3xl">{t.library.title}</h1>
        <SignIn problem={signin} />
      </section>
    );
  return (
    <section className="mx-auto mt-4 max-w-3xl">
      <h1 className="title text-3xl">{t.library.title}</h1>
      {me.data.test && <p className="mt-2 text-lg text-parchment/75">{t.library.testIntro}</p>}
      {isPending && <Loading />}
      {isError && <LoadError retry={() => void refetch()} />}
      {data && data.length === 0 && <p className="mt-6 text-lg text-parchment/75">{t.library.empty}</p>}
      <ul className="mt-6 grid gap-4 sm:grid-cols-2">
        {data?.map((c) => (
          <li key={c.id}>
            <Link
              to="/book/$id"
              params={{ id: String(c.id) }}
              className="block rounded-md border border-leather-edge bg-leather/80 p-4 shadow-lg transition hover:border-gold"
            >
              <div className="flex items-baseline justify-between gap-2">
                <span className="font-[family-name:var(--font-display)] text-2xl" style={{ color: CLASS_COLOURS[c.class] }}>
                  {c.name}
                </span>
                {c.fallen ? (
                  <span className="flex items-center gap-1 text-sm text-[#e0705f]">
                    <Skull className="size-4" aria-hidden />
                    {t.library.fallen}
                  </span>
                ) : (
                  c.hardcore && (
                    <span className="flex items-center gap-1 text-sm text-ember">
                      <Flame className="size-4" aria-hidden />
                      {t.library.hardcore}
                    </span>
                  )
                )}
              </div>
              <p className="mt-1 text-lg">
                {t.library.level(c.level)} {raceClass(t, c)}
              </p>
              <p className="text-parchment/60">{realmName(t, c)}</p>
              <p className="mt-3 flex items-center gap-2 text-gold-bright">
                <BookOpen className="size-4" aria-hidden />
                {t.library.chapters(c.chapters)}
              </p>
            </Link>
          </li>
        ))}
      </ul>
      <LinkCharacter />
    </section>
  );
}
