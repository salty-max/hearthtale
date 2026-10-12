import { Link } from "@tanstack/react-router";
import { Flourish } from "@/components/Flourish";
import { useT } from "@/lib/i18n";

/** Under every page but the reader: where things are, and whose site it is. */
export function Footer() {
  const t = useT();
  return (
    <footer className="ui no-print mx-auto mt-14 max-w-3xl pb-6 text-center text-sm text-parchment/60">
      <Flourish className="text-gold/70" />
      <nav aria-label={t.footer.source} className="mt-3 flex flex-wrap justify-center gap-x-5 gap-y-1">
        <Link to="/start" className="hover:text-gold-bright">
          {t.nav.start}
        </Link>
        <Link to="/hall" className="hover:text-gold-bright">
          {t.hall.title}
        </Link>
        <Link to="/privacy" className="hover:text-gold-bright">
          {t.footer.privacy}
        </Link>
        <a href="https://github.com/salty-max/hearthtale" className="hover:text-gold-bright">
          {t.footer.source}
        </a>
        <a href="https://ko-fi.com/salty_max" className="hover:text-gold-bright">
          {t.footer.support}
        </a>
      </nav>
      <p className="mt-2">
        {t.footer.made} {t.footer.notAffiliated}
      </p>
    </footer>
  );
}
