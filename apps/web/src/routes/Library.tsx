import type { CharacterSummary } from "@hearthtale/shared";
import { Link, useSearch } from "@tanstack/react-router";
import { BookOpen, Map as MapIcon, Sparkles, Upload } from "lucide-react";
import { useEffect } from "react";
import { Crest } from "@/components/Crest";
import { HardcoreMark } from "@/components/HardcoreMark";
import { LinkCharacter } from "@/components/LinkCharacter";
import { LoadError, Loading } from "@/components/PageState";
import { SignIn } from "@/components/SignIn";
import { useLibrary, useMe } from "@/lib/api";
import { ago } from "@/lib/dates";
import { useLocale, useT } from "@/lib/i18n";
import { isNew, rememberUnseen, useSeen } from "@/lib/seen";
import { useTitle } from "@/lib/title";
import { classColour, raceClass, realmName } from "@/lib/wow";

/** The signed-in account's characters, the last written to first, and a way to link more; signing in first. */
export function Library() {
  const t = useT();
  useTitle(t.library.title);
  const { signin } = useSearch({ from: "/library" });
  const me = useMe();
  const { data, isPending, isError, refetch } = useLibrary(!!me.data);
  // (books never seen on this device: taken as read, nothing marked new on a first visit)
  useEffect(() => {
    if (data) rememberUnseen(data.map((c) => ({ id: c.id, n: c.chapters, at: c.latest?.at })));
  }, [data]);
  if (me.isPending) return <Loading />;
  if (!me.data)
    return (
      <section className="mx-auto mt-4 max-w-md text-center">
        <h1 className="title-gilded text-4xl">{t.library.title}</h1>
        <SignIn problem={signin} />
      </section>
    );
  return (
    <section className="mx-auto mt-4 max-w-4xl">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 className="title-gilded text-4xl">{t.library.title}</h1>
        <Link to="/upload" className="btn">
          <Upload className="size-4" aria-hidden />
          {t.library.upload}
        </Link>
      </div>
      {me.data.test && <p className="mt-2 text-lg text-parchment/75">{t.library.testIntro}</p>}
      {isPending && <Loading />}
      {isError && <LoadError retry={() => void refetch()} />}
      {data && data.length === 0 && <p className="mt-6 text-lg text-parchment/75">{t.library.empty}</p>}
      <ul className="mt-6 grid gap-4 md:grid-cols-2">
        {data?.map((c) => (
          <li key={c.id}>
            <BookCard c={c} />
          </li>
        ))}
      </ul>
      <LinkCharacter />
    </section>
  );
}

/** A book on the shelf: who, how they stand, the latest entry, what came since this device last read it. */
function BookCard({ c }: { c: CharacterSummary }) {
  const t = useT();
  const locale = useLocale();
  const seen = useSeen()[c.id];
  const fresh = isNew(seen, c.chapters, c.latest?.at);
  const latest = c.latest;
  const latestTitle = latest ? (latest.title ?? t.book.chapter(latest.number)) : undefined;
  return (
    <article className="panel panel-link relative flex h-full flex-col p-4">
      {(c.fallen || c.hardcore) && <HardcoreMark fallen={c.fallen} className="absolute top-4 right-4 z-10" />}
      <div className="flex items-start gap-3">
        <Crest token={c.class} size={48} />
        <div className="min-w-0 flex-1">
          <div className={`flex flex-wrap items-center gap-x-2 gap-y-1 ${c.fallen || c.hardcore ? "pr-24" : ""}`}>
            <Link
              to="/book/$id"
              params={{ id: String(c.id) }}
              className="truncate font-display text-2xl after:absolute after:inset-0 after:rounded-lg"
              style={{ color: classColour(c.class) }}
            >
              {c.name}
            </Link>
            {fresh && (
              <span className="tag text-gold-bright">
                <Sparkles className="size-3" aria-hidden />
                {t.library.new}
              </span>
            )}
            {c.client === "forever" && <span className="tag text-parchment/70">{t.library.forever}</span>}
          </div>
          <p className="ui text-parchment/85">
            {t.library.level(c.level)} {raceClass(t, c)}
            {realmName(t, c) && <span className="text-parchment/55"> · {realmName(t, c)}</span>}
          </p>
        </div>
      </div>
      {latest && (
        <div className="mt-3 border-t border-gold/15 pt-3">
          <p className="ui text-xs tracking-widest text-parchment/55 uppercase">{t.library.latest}</p>
          <p className="truncate font-display text-xl text-gold-bright">{latestTitle}</p>
          <p className="truncate text-parchment/70">
            {[latest.title ? t.book.chapter(latest.number) : undefined, latest.open ? t.book.stillWriting : latest.place].filter(Boolean).join(" · ")}
          </p>
        </div>
      )}
      <div className="ui mt-auto flex flex-wrap items-center justify-between gap-2 pt-3 text-sm">
        <span className="flex items-center gap-2 font-narrow text-base text-parchment/60">
          <BookOpen className="size-4" aria-hidden />
          {t.library.chapters(c.chapters)} · {t.library.updated(ago(Date.parse(c.updatedAt), locale))}
        </span>
        {c.chapters > 0 && (
          <Link to="/book/$id/road" params={{ id: String(c.id) }} className="relative z-10 flex items-center gap-1 text-gold-bright hover:underline">
            <MapIcon className="size-4" aria-hidden />
            {t.library.road}
          </Link>
        )}
      </div>
    </article>
  );
}
