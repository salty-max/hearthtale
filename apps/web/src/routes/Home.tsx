import { Link } from "@tanstack/react-router";
import { useState } from "react";
import { paragraphs } from "@/lib/book";
import { useT } from "@/lib/i18n";
import { SAMPLES } from "@/lib/samples";
import { readerClasses, useSettings } from "@/lib/settings";
import { raceClass } from "@/lib/wow";

export function Home() {
  const t = useT();
  return (
    <>
      <article className="page mx-auto mt-6 max-w-2xl rounded-md px-6 py-10 text-center sm:px-12">
        <img src="/logo-160.png" alt="" width={160} height={160} className="mx-auto rounded-2xl" />
        <h1 className="title mt-6 text-4xl text-[#7a5410]">Hearthtale</h1>
        <p className="mt-2 text-xl italic text-ink-faded">{t.home.tagline}</p>
        <p className="mt-6 text-left text-lg leading-relaxed">{t.home.intro}</p>
        <p className="mt-4 text-left text-lg leading-relaxed">{t.home.soon}</p>
        <p className="mt-4 text-sm text-ink-faded">{t.home.games}</p>
        <Link to="/start" className="btn mt-8">
          {t.home.start}
        </Link>
      </article>
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
    <section aria-labelledby="samples-title" className="mx-auto mt-10 mb-6 max-w-2xl">
      <h2 id="samples-title" className="title text-center text-2xl">
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
            className={`rounded-md border px-3 py-1.5 text-left leading-tight transition-colors ${
              i === at ? "border-gold bg-leather-edge text-gold-bright" : "border-gold/40 text-parchment/80 hover:border-gold hover:text-gold-bright"
            }`}
          >
            <span className="block font-[family-name:var(--font-display)]">{x.name}</span>
            <span className="block text-xs opacity-80">
              {raceClass(t, x)}
              {x.part === "epitaph" ? ` · ${t.library.fallen}` : ""}
            </span>
          </button>
        ))}
      </div>
      <article className={`${cls.page} mt-5 rounded-md px-6 py-8 sm:px-12 sm:py-10`}>
        <header className="text-center">
          <h3 className={epitaph ? `title text-3xl ${fallenColour}` : "title page-title text-3xl"}>{epitaph ? s.name : (s.title ?? t.book.chapter(s.number ?? 0))}</h3>
          <p className="page-faded mt-1 italic">{sub}</p>
        </header>
        <div className={`mt-6 space-y-4 ${cls.text} ${epitaph ? "text-center italic" : ""}`}>
          {paragraphs(s.text).map((p, i) => (
            <p
              key={i}
              className={
                i === 0 && !epitaph
                  ? "first-letter:float-left first-letter:mr-1 first-letter:font-[family-name:var(--font-display)] first-letter:text-[3.2em] first-letter:leading-none first-letter:text-[var(--page-title)]"
                  : undefined
              }
            >
              {p}
            </p>
          ))}
        </div>
      </article>
    </section>
  );
}
