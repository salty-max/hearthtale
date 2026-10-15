import { Link, Outlet, useRouterState } from "@tanstack/react-router";
import { useEffect } from "react";
import { BookOpen, Compass, Settings as SettingsIcon, Skull } from "lucide-react";
import { Footer } from "@/components/Footer";
import { LinkCharacter } from "@/components/LinkCharacter";
import { ThemeToggle } from "@/components/ThemeToggle";
import { UpdatePrompt } from "@/components/UpdatePrompt";
import { useMe } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { isReading, pageOf } from "@/lib/reading";
import { useSiteTheme } from "@/lib/theme";

/**
 * The app's frame: a top bar that never wraps, the page, and on phones a tab
 * bar at the bottom (on wider screens, the same links sit in the top bar); at
 * its end, signed in, linking a character, and day or night. The frame's
 * backdrop: a hearth's glow under a dark night, or a scribe's desk by day.
 * A page scrolls as a page, the bars pinned (as Ravenpost's inbox and
 * WoWLocker: the installed app on iOS then fills the screen); a book being
 * read fills a frame of its own instead, only its text scrolling, no tab bar
 * (html.reading).
 */
export function Layout() {
  const t = useT();
  useSiteTheme();
  const me = useMe();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const reading = isReading(path);
  useEffect(() => {
    document.documentElement.classList.toggle("reading", reading);
  }, [reading]);
  const tabs = [
    { to: "/library", label: t.nav.library, icon: BookOpen },
    { to: "/hall", label: t.nav.hall, icon: Skull },
    { to: "/start", label: t.nav.start, icon: Compass },
    { to: "/settings", label: t.nav.settings, icon: SettingsIcon },
  ] as const;
  return (
    <div className={reading ? "backdrop fixed inset-0 flex flex-col" : "flex min-h-dvh flex-col"}>
      {/* (the backdrop behind a scrolling page stays put, the window's) */}
      {!reading && <div aria-hidden className="backdrop fixed inset-0 -z-10" />}
      <a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:left-3 focus:top-3 focus:z-50 btn">
        {t.nav.skip}
      </a>
      <header
        className={`no-print z-30 flex shrink-0 items-center gap-4 bg-night/70 px-4 pt-[max(0.6rem,env(safe-area-inset-top))] pb-2.5 backdrop-blur-sm ${reading ? "relative" : "sticky top-0"}`}
      >
        <Link to="/" className="flex min-w-0 items-center gap-2.5 whitespace-nowrap">
          <img src="/logo-96.png" alt="" width={36} height={36} className="size-9 shrink-0 drop-shadow-[0_0_8px_rgb(232_199_90/0.35)]" />
          <span className="title-gilded text-2xl leading-none">{t.nav.home}</span>
        </Link>
        <nav aria-label={t.nav.menu} className="ui ml-auto hidden items-center gap-1 md:flex">
          {tabs.map((tab) => (
            <Link
              key={tab.to}
              to={tab.to}
              className="flex items-center gap-2 rounded-md px-3 py-1.5 hover:bg-gold/10 hover:text-gold-bright"
              inactiveProps={{ className: "text-parchment/80" }}
              activeProps={{ className: "bg-gold/10 text-gold-bright", "aria-current": "page" }}
            >
              <tab.icon className="size-4" aria-hidden />
              {tab.label}
            </Link>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-2 md:ml-1">
          {me.data && <LinkCharacter />}
          <ThemeToggle />
        </div>
        {/* the header's gilt edge */}
        <span aria-hidden className="absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-gold/60 to-transparent" />
      </header>
      <main
        id="main"
        className={reading ? "min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3" : "flex-1 px-4 pt-3 pb-[calc(5rem+env(safe-area-inset-bottom))] md:pb-3"}
      >
        {/* (a new page fades in; turning a book's page keeps the reader, only its text changes) */}
        <div key={pageOf(path)} className={reading ? "fade-in h-full" : "fade-in"}>
          <Outlet />
        </div>
        {!reading && <Footer />}
      </main>
      {!reading && (
        // (the phone's tab bar, as Ravenpost's inbox draws it: the night's own
        // colour under a hairline, small labels, the page's tab in gold, the
        // home indicator's room below it)
        <nav
          aria-label={t.nav.menu}
          className="ui no-print fixed inset-x-0 bottom-0 z-30 flex justify-around border-t border-leather-edge/70 bg-night/90 px-1.5 pt-1.5 pb-[calc(0.375rem+env(safe-area-inset-bottom))] backdrop-blur-md [.standalone-gap_&]:pb-1.5 md:hidden"
        >
          {tabs.map((tab) => (
            <Link
              key={tab.to}
              to={tab.to}
              className="flex min-w-14 flex-col items-center gap-[3px] rounded-lg px-2 py-1 text-[10px] font-medium transition-colors"
              inactiveProps={{ className: "text-parchment/50" }}
              activeProps={{ className: "text-gold-bright", "aria-current": "page" }}
            >
              <tab.icon className="size-5" aria-hidden />
              {tab.label}
            </Link>
          ))}
        </nav>
      )}
      <UpdatePrompt />
    </div>
  );
}
