import { Link, Outlet, useRouterState } from "@tanstack/react-router";
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
 * The app's frame, as a native app's: a top bar that never wraps, the page in
 * the middle (it alone scrolls), and on phones a tab bar at the bottom (on
 * wider screens, the same links sit in the top bar); at its end, signed in,
 * linking a character, and day or night. The frame's backdrop: a
 * hearth's glow under a dark night, or a scribe's desk by day.
 */
export function Layout() {
  const t = useT();
  useSiteTheme();
  const me = useMe();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const reading = isReading(path);
  const tabs = [
    { to: "/library", label: t.nav.library, icon: BookOpen },
    { to: "/hall", label: t.nav.hall, icon: Skull },
    { to: "/start", label: t.nav.start, icon: Compass },
    { to: "/settings", label: t.nav.settings, icon: SettingsIcon },
  ] as const;
  return (
    // Pinned to the window. In the installed app on iOS the window can stop short
    // of the screen: nothing paints there but the page's background, the tab
    // bar's colour (index.css), so the strip reads as the bar (lib/standalone.ts).
    <div className="backdrop fixed inset-0 flex flex-col">
      <a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:left-3 focus:top-3 focus:z-50 btn">
        {t.nav.skip}
      </a>
      <header className="no-print relative z-30 flex shrink-0 items-center gap-4 bg-night/70 px-4 pt-[max(0.6rem,env(safe-area-inset-top))] pb-2.5 backdrop-blur-sm">
        <Link to="/" className="flex min-w-0 items-center gap-2.5 whitespace-nowrap">
          <img src="/logo-96.png" alt="" width={36} height={36} className="size-9 shrink-0 drop-shadow-[0_0_8px_rgb(232_199_90/0.35)]" />
          <span className="title-gilded text-2xl leading-none">{t.nav.home}</span>
        </Link>
        <nav aria-label={t.nav.menu} className="ui ml-auto hidden items-center gap-1 md:flex">
          {tabs.map((tab) => (
            <Link
              key={tab.to}
              to={tab.to}
              className="flex items-center gap-2 rounded-md px-3 py-1.5 text-parchment/80 hover:bg-gold/10 hover:text-gold-bright"
              activeProps={{ className: "bg-gold/10 text-gold-bright", "aria-current": "page" }}
            >
              <tab.icon className="size-4" aria-hidden />
              {tab.label}
            </Link>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-1 md:ml-1">
          {me.data && <LinkCharacter />}
          <ThemeToggle />
        </div>
        {/* the header's gilt edge */}
        <span aria-hidden className="absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-gold/60 to-transparent" />
      </header>
      <main id="main" className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3">
        {/* (a new page fades in; turning a book's page keeps the reader, only its text changes) */}
        <div key={pageOf(path)} className={reading ? "fade-in h-full" : "fade-in"}>
          <Outlet />
        </div>
        {!reading && <Footer />}
      </main>
      {!reading && (
        <nav
          aria-label={t.nav.menu}
          className="ui no-print relative grid shrink-0 grid-cols-4 bg-leather pb-[max(0.25rem,calc(env(safe-area-inset-bottom)-0.9rem))] [.standalone-gap_&]:pb-1 md:hidden"
        >
          <span aria-hidden className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-gold/50 to-transparent" />
          {tabs.map((tab) => (
            <Link
              key={tab.to}
              to={tab.to}
              className="flex flex-col items-center gap-0.5 pt-2 pb-1 text-xs text-parchment/60"
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
