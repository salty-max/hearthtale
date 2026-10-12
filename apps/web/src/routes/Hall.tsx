import { Link } from "@tanstack/react-router";
import { BookOpen } from "lucide-react";
import { Crest } from "@/components/Crest";
import { Skull } from "@/components/HardcoreMark";
import { Flourish } from "@/components/Flourish";
import { LoadError, Loading } from "@/components/PageState";
import { useHall } from "@/lib/api";
import { useLocale, useT } from "@/lib/i18n";
import { useTitle } from "@/lib/title";
import { classColour, raceClass, realmName } from "@/lib/wow";

/** The public Hall of the Fallen: Hardcore lives their owners chose to show, each with its epitaph. */
export function Hall() {
  const t = useT();
  const locale = useLocale();
  useTitle(t.hall.title);
  const { data, isPending, isError, refetch } = useHall();
  return (
    <section className="mx-auto max-w-3xl pb-4">
      <div className="mt-2 text-center">
        <Skull size={40} className="mx-auto drop-shadow-[0_0_10px_rgb(224_112_95/0.35)]" />
        <h1 className="title-gilded mt-2 text-4xl">{t.hall.title}</h1>
        <p className="mx-auto mt-2 max-w-xl text-lg text-parchment/75">{t.hall.intro}</p>
        <Flourish className="mt-4 text-gold/70" />
      </div>
      {isPending && <Loading />}
      {isError && <LoadError retry={() => void refetch()} />}
      {data && data.length === 0 && <p className="mt-6 text-center text-lg italic text-parchment/70">{t.hall.empty}</p>}
      <ul className="mt-6 space-y-4">
        {data?.map((e) => (
          <li key={e.id}>
            <article className="panel panel-link relative p-5">
              <div className="flex items-start gap-3">
                <Crest token={e.character.class} size={48} className="grayscale-[35%]" />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <Link
                      to="/hall/$id"
                      params={{ id: String(e.id) }}
                      search={{}}
                      className="font-[family-name:var(--font-display)] text-2xl after:absolute after:inset-0 after:rounded-lg"
                      style={{ color: classColour(e.character.class) }}
                    >
                      {e.character.name}
                    </Link>
                    {e.diedAt && (
                      <span className="ui inline-flex items-center gap-1.5 text-sm text-blood">
                        <Skull size={18} />
                        {new Intl.DateTimeFormat(locale, { dateStyle: "medium" }).format(new Date(e.diedAt * 1000))}
                      </span>
                    )}
                  </div>
                  <p className="ui text-parchment/80">
                    {t.library.level(e.character.level)} {raceClass(t, e.character)}
                    {realmName(t, e.character) && <span className="text-parchment/55"> · {realmName(t, e.character)}</span>}
                  </p>
                </div>
              </div>
              {e.epitaph && <p className="mt-4 border-l-2 border-blood/50 pl-4 text-lg italic text-parchment/85">{e.epitaph}</p>}
              <p className="ui mt-3 flex items-center gap-2 text-sm text-gold-bright">
                <BookOpen className="size-4" aria-hidden />
                {t.hall.read} · {t.library.chapters(e.chapters)}
              </p>
            </article>
          </li>
        ))}
      </ul>
    </section>
  );
}
