import { Link, Outlet } from "@tanstack/react-router";
import { AccountMenu } from "@/components/AccountMenu";
import { UpdatePrompt } from "@/components/UpdatePrompt";
import { useT } from "@/lib/i18n";
import { setSettings, useSettings, type Lang } from "@/lib/settings";

const LANGS: { lang: Lang; label: string }[] = [
  { lang: "en", label: "EN" },
  { lang: "fr", label: "FR" },
];

export function Layout() {
  const t = useT();
  const { lang } = useSettings();
  return (
    <div className="flex min-h-dvh flex-col">
      <a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:left-3 focus:top-3 focus:z-50 btn">
        {t.nav.skip}
      </a>
      <header className="flex flex-wrap items-center gap-x-4 gap-y-2 px-4 pt-[max(1rem,env(safe-area-inset-top))] pb-3">
        <Link to="/" className="title flex shrink-0 items-center gap-2 whitespace-nowrap text-xl">
          <img src="/favicon-32.png" alt="" className="size-7 rounded" />
          {t.nav.home}
        </Link>
        <nav className="ml-auto flex items-center gap-4">
          <Link to="/library" className="text-gold-bright hover:underline" activeProps={{ className: "underline" }}>
            {t.nav.library}
          </Link>
          <AccountMenu />
        </nav>
        <div role="group" aria-label={t.nav.language} className="flex gap-1 text-sm">
          {LANGS.map((l) => (
            <button
              key={l.lang}
              onClick={() => setSettings({ lang: l.lang })}
              aria-pressed={lang === l.lang}
              className={lang === l.lang ? "rounded px-2 py-1 text-gold-bright" : "rounded px-2 py-1 text-parchment/60 hover:text-parchment"}
            >
              {l.label}
            </button>
          ))}
        </div>
      </header>
      <main id="main" className="flex-1 px-4 pb-10">
        <Outlet />
      </main>
      <footer className="px-4 pb-[max(1.5rem,env(safe-area-inset-bottom))] text-center text-sm text-parchment/50">
        <a href="https://github.com/salty-max/hearthtale" className="underline-offset-2 hover:underline">
          {t.footer.source}
        </a>
        {" · "}
        {t.footer.notAffiliated}
      </footer>
      <UpdatePrompt />
    </div>
  );
}
