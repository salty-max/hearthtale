import { Link } from "@tanstack/react-router";
import { Skull } from "lucide-react";
import { LoadError, Loading } from "@/components/PageState";
import { useHall } from "@/lib/api";
import { useLocale, useT } from "@/lib/i18n";
import { CLASS_COLOURS, raceClass, realmName } from "@/lib/wow";

/** The public Hall of the Fallen: Hardcore lives their owners chose to show, each with its epitaph. */
export function Hall() {
  const t = useT();
  const locale = useLocale();
  const { data, isPending, isError, refetch } = useHall();
  return (
    <section className="mx-auto max-w-3xl pb-4">
      <h1 className="title text-3xl">{t.hall.title}</h1>
      <p className="mt-2 text-lg text-parchment/75">{t.hall.intro}</p>
      {isPending && <Loading />}
      {isError && <LoadError retry={() => void refetch()} />}
      {data && data.length === 0 && <p className="mt-6 text-lg italic text-parchment/70">{t.hall.empty}</p>}
      <ul className="mt-6 space-y-4">
        {data?.map((e) => (
          <li key={e.id}>
            <Link to="/hall/$id" params={{ id: String(e.id) }} search={{}} className="block rounded-md border border-leather-edge bg-leather/80 p-4 shadow-lg transition hover:border-gold">
              <div className="flex items-baseline justify-between gap-2">
                <span className="font-[family-name:var(--font-display)] text-2xl" style={{ color: CLASS_COLOURS[e.character.class] }}>
                  {e.character.name}
                </span>
                {e.diedAt && (
                  <span className="flex items-center gap-1 text-sm text-[#e0705f]">
                    <Skull className="size-4" aria-hidden />
                    {new Intl.DateTimeFormat(locale, { dateStyle: "medium" }).format(new Date(e.diedAt * 1000))}
                  </span>
                )}
              </div>
              <p className="text-parchment/80">
                {t.library.level(e.character.level)} {raceClass(t, e.character)}
                {realmName(t, e.character) && <span className="text-parchment/55"> · {realmName(t, e.character)}</span>}
              </p>
              {e.epitaph && <p className="mt-3 italic text-parchment/85">{e.epitaph}</p>}
              <p className="mt-2 text-sm text-gold-bright">{t.library.chapters(e.chapters)}</p>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
