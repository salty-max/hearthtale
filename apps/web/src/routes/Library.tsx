import { Link } from "@tanstack/react-router";
import { BookOpen, Flame, Skull } from "lucide-react";
import { LoadError, Loading } from "@/components/PageState";
import { useCharacters } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { CLASS_COLOURS, raceClass, realmName } from "@/lib/wow";

export function Library() {
  const t = useT();
  const { data, isPending, isError, refetch } = useCharacters();
  return (
    <section className="mx-auto mt-4 max-w-3xl">
      <h1 className="title text-3xl">{t.library.title}</h1>
      <p className="mt-2 text-lg text-parchment/75">{t.library.intro}</p>
      {isPending && <Loading />}
      {isError && <LoadError retry={() => void refetch()} />}
      {data && data.length === 0 && <p className="mt-8 text-lg italic text-parchment/70">{t.library.empty}</p>}
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
    </section>
  );
}
