import { Link } from "@tanstack/react-router";
import { BookOpen, Feather, Flame, Skull } from "lucide-react";
import { useState } from "react";
import { Crest } from "@/components/Crest";
import { Flourish } from "@/components/Flourish";
import { paragraphs } from "@/lib/book";
import { useT } from "@/lib/i18n";
import { SAMPLES } from "@/lib/samples";
import { readerClasses, useSettings } from "@/lib/settings";
import { useTitle } from "@/lib/title";
import { raceClass } from "@/lib/wow";

const FEATURE_ICONS = [Feather, BookOpen, Flame];

export function Home() {
  const t = useT();
  useTitle();
  return (
    <>
      <section className="mx-auto mt-6 max-w-3xl text-center">
        <img
          src="/logo-320.png"
          alt=""
          width={160}
          height={160}
          className="mx-auto size-36 drop-shadow-[0_0_28px_rgb(232_199_90/0.35)] sm:size-40"
        />
        <h1 className="title-gilded mt-5 text-5xl sm:text-6xl">Hearthtale</h1>
        <p className="mt-3 text-xl italic text-parchment/80 sm:text-2xl">{t.home.tagline}</p>
        <Flourish className="mt-5 text-gold/80" />
        <p className="mx-auto mt-5 max-w-2xl text-lg leading-relaxed text-parchment/85">{t.home.intro}</p>
        <div className="mt-7 flex flex-wrap justify-center gap-3">
          <Link to="/start" className="btn btn-primary text-lg">
            {t.home.start}
          </Link>
          <a href="#samples" className="btn text-lg">
            <BookOpen className="size-4" aria-hidden />
            {t.home.sample}
          </a>
          <Link to="/hall" className="btn text-lg">
            <Skull className="size-4" aria-hidden />
            {t.home.hall}
          </Link>
        </div>
        <p className="ui mt-4 text-sm text-parchment/60">{t.home.games}</p>
      </section>

      <ul className="mx-auto mt-10 grid max-w-4xl gap-4 sm:grid-cols-3">
        {t.home.features.map((f, i) => {
          const Icon = FEATURE_ICONS[i] ?? Feather;
          return (
            <li key={f.title} className="panel p-5 text-center">
              <Icon className="mx-auto size-7 text-gold-bright" aria-hidden />
              <h2 className="title mt-3 text-xl">{f.title}</h2>
              <p className="mt-2 text-parchment/80">{f.text}</p>
            </li>
          );
        })}
      </ul>
      <p className="mx-auto mt-6 max-w-2xl text-center text-lg text-parchment/75">{t.home.soon}</p>
      <Samples />
    </>
  );
}

/** A page of each sample journal, one voice at a time, as the reader shows it. */
function Samples() {
  const t = useT();
  const settings = useSettings();
  const [at, setAt] = useState(0);
  const s = SAMPLES[at];
  if (!s) return null;
  const cls = readerClasses(settings);
  const fallenColour = settings.theme === "night" ? "text-[#e0705f]" : "text-fallen";
  const epitaph = s.part === "epitaph";
  // "Entry 2 · Kharanos · levels 4 to 7", as the reader writes it
  const sub = epitaph
    ? [raceClass(t, s), t.library.hardcore, t.book.theEnd].join(" · ")
    : [s.title ? t.book.chapter(s.number ?? 0) : undefined, s.place, t.book.levels(s.from ?? 0, s.to ?? 0)].filter(Boolean).join(" · ");
  return (
    <section id="samples" aria-labelledby="samples-title" className="mx-auto mt-12 mb-6 max-w-2xl scroll-mt-4">
      <h2 id="samples-title" className="title-gilded text-center text-3xl">
        {t.home.samplesTitle}
      </h2>
      <p className="mt-2 text-center text-parchment/75 italic">{t.home.samplesWhy}</p>
      <div className="mt-5 flex flex-wrap justify-center gap-2">
        {SAMPLES.map((x, i) => (
          <button
            key={x.name}
            type="button"
            aria-pressed={i === at}
            onClick={() => setAt(i)}
            className={`flex items-center gap-2 rounded-md border px-2.5 py-1.5 text-left leading-tight transition-colors ${
              i === at ? "border-gold bg-gold/15 text-gold-bright" : "border-gold/30 text-parchment/80 hover:border-gold hover:text-gold-bright"
            }`}
          >
            <Crest token={x.class} size={26} />
            <span>
              <span className="block font-[family-name:var(--font-display)]">{x.name}</span>
              <span className="ui block text-xs opacity-80">
                {raceClass(t, x)}
                {x.part === "epitaph" ? ` · ${t.library.fallen}` : ""}
              </span>
            </span>
          </button>
        ))}
      </div>
      <article key={s.name} className={`${cls.page} fade-in mt-5 rounded-md px-6 py-8 sm:px-12 sm:py-10`}>
        <header className="text-center">
          <h3 className={epitaph ? `title text-3xl ${fallenColour}` : "title page-title text-3xl"}>{epitaph ? s.name : (s.title ?? t.book.chapter(s.number ?? 0))}</h3>
          <p className="page-faded mt-1 italic">{sub}</p>
          <Flourish className="page-title mt-3 opacity-70" />
        </header>
        <div className={`mt-5 space-y-4 ${cls.text} ${epitaph ? "text-center italic" : ""}`}>
          {paragraphs(s.text).map((p, i) => (
            <p key={i} className={i === 0 && !epitaph ? "drop-cap" : undefined}>
              {p}
            </p>
          ))}
        </div>
      </article>
    </section>
  );
}
