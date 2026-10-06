import { Link } from "@tanstack/react-router";
import { useT } from "@/lib/i18n";

export function Home() {
  const t = useT();
  return (
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
  );
}
