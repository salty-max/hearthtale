import type { BookChapter } from "@hearthtale/shared";
import { Link, useParams } from "@tanstack/react-router";
import { ChevronLeft, MapPin, Skull, Star } from "lucide-react";
import { Crest } from "@/components/Crest";
import { Flourish } from "@/components/Flourish";
import { LoadError, Loading } from "@/components/PageState";
import { SignIn } from "@/components/SignIn";
import { NotFound, NotSignedIn, useCharacterBook } from "@/lib/api";
import { dateRange } from "@/lib/dates";
import { levelPoints, roadOf } from "@/lib/road";
import { useLocale, useT } from "@/lib/i18n";
import { useTitle } from "@/lib/title";
import { classColour, raceClass } from "@/lib/wow";

const W = 640,
  H = 220,
  PAD = { l: 34, r: 12, t: 12, b: 26 };

function Chart({ chs, until }: { chs: BookChapter[]; until?: number }) {
  const t = useT();
  const pts = levelPoints(chs, until);
  if (pts.length < 2) return null;
  const xs = pts.map((p) => p.x),
    ys = pts.map((p) => p.y);
  const x0 = Math.min(...xs),
    x1 = Math.max(...xs) || x0 + 1;
  const y0 = Math.max(1, Math.min(...ys) - 1),
    y1 = Math.max(...ys) + 1;
  const sx = (x: number) => PAD.l + ((x - x0) / Math.max(1, x1 - x0)) * (W - PAD.l - PAD.r);
  const sy = (y: number) => H - PAD.b - ((y - y0) / Math.max(1, y1 - y0)) * (H - PAD.t - PAD.b);
  const line = pts.map((p) => `${sx(p.x).toFixed(1)},${sy(p.y).toFixed(1)}`).join(" ");
  const area = `${sx(pts[0].x)},${H - PAD.b} ${line} ${sx(pts[pts.length - 1].x)},${H - PAD.b}`;
  const step = Math.max(1, Math.ceil((y1 - y0) / 5));
  const ticks: number[] = [];
  for (let y = Math.ceil(y0 / step) * step; y <= y1; y += step) ticks.push(y);
  return (
    <figure className="panel p-4">
      <figcaption className="title text-lg">{t.road.chart}</figcaption>
      <svg viewBox={`0 0 ${W} ${H}`} className="mt-2 w-full" role="img" aria-label={t.road.chart}>
        <defs>
          <linearGradient id="road-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--color-gold)" stopOpacity="0.35" />
            <stop offset="100%" stopColor="var(--color-gold)" stopOpacity="0" />
          </linearGradient>
        </defs>
        {ticks.map((y) => (
          <g key={y}>
            <line x1={PAD.l} x2={W - PAD.r} y1={sy(y)} y2={sy(y)} stroke="currentColor" strokeOpacity="0.12" />
            <text x={PAD.l - 6} y={sy(y) + 4} textAnchor="end" fontSize="11" fill="currentColor" fillOpacity="0.55">
              {y}
            </text>
          </g>
        ))}
        <polygon points={area} fill="url(#road-fill)" />
        <polyline points={line} fill="none" stroke="var(--color-gold-bright)" strokeWidth="2.5" strokeLinejoin="round" />
        {chs.map((c, i) => {
          const p = pts[i * 2 + 1];
          return (
            <circle key={c.number} cx={sx(p.x)} cy={sy(p.y)} r={c.close ? 5 : 3.5} fill={c.close ? "var(--color-blood)" : "var(--color-gold-bright)"} stroke="var(--color-night)" strokeWidth="1.5">
              <title>{`${c.title ?? t.book.chapter(c.number)} · ${t.book.levels(c.from, c.to)}`}</title>
            </circle>
          );
        })}
      </svg>
    </figure>
  );
}

/** One of my books, as a road: its figures, the level over the days, the places in order, each entry. */
export function Road() {
  const t = useT();
  const locale = useLocale();
  const { id } = useParams({ from: "/book/$id/road" });
  const { data, error, refetch } = useCharacterBook(Number(id));
  useTitle(t.road.title, data?.character.name);
  if (error) {
    if (error instanceof NotSignedIn) return <SignIn />;
    return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  }
  if (!data) return <Loading />;
  const { character: c, book } = data;
  const r = roadOf(book);
  const figures: [string, string][] = [
    [String(r.entries), t.road.entries],
    [r.from === r.to ? String(r.to) : `${r.from}–${r.to}`, t.road.levels],
    [String(r.days), t.road.days],
    [String(r.places.length), t.road.places],
    [String(r.closeCalls), t.road.closeCalls],
    [String(r.rares), t.road.rares],
  ];
  return (
    <section className="mx-auto max-w-4xl pb-4">
      <Link to="/book/$id" params={{ id }} className="ui inline-flex items-center gap-1 text-gold-bright hover:underline">
        <ChevronLeft className="size-4" aria-hidden />
        {c.name}
      </Link>
      <header className="mt-3 text-center">
        <Crest token={c.class} size={64} className="mx-auto" />
        <h1 className="title-gilded mt-3 text-4xl">{t.road.title}</h1>
        <p className="ui mt-1 text-parchment/80">
          <span style={{ color: classColour(c.class) }}>{c.name}</span> · {t.library.level(c.level)} {raceClass(t, c)}
        </p>
        <Flourish className="mt-4 text-gold/70" />
      </header>
      {r.entries === 0 ? (
        <p className="mt-6 text-center text-lg italic text-parchment/70">{t.road.empty}</p>
      ) : (
        <>
          <ul className="mt-6 grid grid-cols-3 gap-3 sm:grid-cols-6">
            {figures.map(([value, label]) => (
              <li key={label} className="panel px-2 py-3 text-center">
                <span className="title-gilded block text-3xl">{value}</span>
                <span className="ui block text-xs text-parchment/65">{label}</span>
              </li>
            ))}
          </ul>
          <div className="mt-5">
            <Chart chs={book.chapters} until={book.at} />
          </div>
          {r.places.length > 0 && (
            <div className="panel mt-5 p-4">
              <h2 className="title text-lg">{t.road.places_}</h2>
              <ol className="mt-3 flex flex-wrap items-center gap-x-1 gap-y-2">
                {r.places.map((p, i) => (
                  <li key={p} className="ui flex items-center gap-1 text-parchment/85">
                    {i > 0 && <span aria-hidden className="px-1 text-gold/60">›</span>}
                    <MapPin className="size-3.5 text-gold-bright" aria-hidden />
                    {p}
                  </li>
                ))}
              </ol>
            </div>
          )}
          <div className="panel mt-5 p-4">
            <h2 className="title text-lg">{t.road.timeline}</h2>
            <ol className="relative mt-4 ml-2 border-l border-gold/30">
              {book.chapters.map((ch) => (
                <li key={ch.number} className="relative pb-5 pl-5 last:pb-0">
                  <span aria-hidden className={`absolute top-1.5 -left-[5px] size-2.5 rounded-full ${ch.close ? "bg-blood" : "bg-gold"}`} />
                  <p className="ui text-xs text-parchment/55">{dateRange(ch.began, ch.open ? undefined : ch.ended, locale, t.book.to)}</p>
                  <Link
                    to="/book/$id/$part"
                    params={{ id, part: String(ch.number) }}
                    className="font-[family-name:var(--font-display)] text-lg text-gold-bright hover:underline"
                  >
                    {ch.title ?? t.book.chapter(ch.number)}
                  </Link>
                  <p className="flex flex-wrap items-center gap-x-2 text-parchment/70">
                    {[ch.title ? t.book.chapter(ch.number) : undefined, ch.open ? t.book.stillWriting : ch.place, t.book.levels(ch.from, ch.to)]
                      .filter(Boolean)
                      .join(" · ")}
                    {ch.close && <Skull className="size-3.5 text-blood" aria-label={t.book.closeCall} />}
                    {ch.rare && <Star className="size-3.5 text-gold-bright" aria-label={t.book.rare} />}
                  </p>
                </li>
              ))}
            </ol>
          </div>
        </>
      )}
    </section>
  );
}
