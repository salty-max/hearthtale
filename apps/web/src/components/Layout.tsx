import { Link, Outlet } from "@tanstack/react-router";
import { BookOpen, Compass, Settings as SettingsIcon } from "lucide-react";
import { UpdatePrompt } from "@/components/UpdatePrompt";
import { useT } from "@/lib/i18n";

/**
 * The app's frame, as a native app's: a top bar that never wraps, the page in
 * the middle (it alone scrolls), and on phones a tab bar at the bottom (on
 * wider screens, the same links sit in the top bar).
 */
export function Layout() {
  const t = useT();
  const tabs = [
    { to: "/library", label: t.nav.library, icon: BookOpen },
    { to: "/start", label: t.nav.start, icon: Compass },
    { to: "/settings", label: t.nav.settings, icon: SettingsIcon },
  ] as const;
  return (
    // Pinned to the whole screen (behind the home indicator too, in the installed app).
    <div className="fixed inset-0 flex flex-col">
      <a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:left-3 focus:top-3 focus:z-50 btn">
        {t.nav.skip}
      </a>
      <header className="flex shrink-0 items-center gap-4 border-b border-leather-edge/60 px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3">
        <Link to="/" className="title flex min-w-0 items-center gap-2 whitespace-nowrap text-xl">
          <img src="/favicon-32.png" alt="" className="size-7 shrink-0 rounded" />
          {t.nav.home}
        </Link>
        <nav aria-label={t.nav.menu} className="ml-auto hidden items-center gap-5 md:flex">
          {tabs.map((tab) => (
            <Link key={tab.to} to={tab.to} className="text-gold-bright hover:underline" activeProps={{ className: "underline" }}>
              {tab.label}
            </Link>
          ))}
        </nav>
      </header>
      <main id="main" className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3">
        <Outlet />
      </main>
      <nav
        aria-label={t.nav.menu}
        className="grid shrink-0 grid-cols-3 border-t border-leather-edge/60 bg-leather pb-[max(0.25rem,calc(env(safe-area-inset-bottom)-0.9rem))] md:hidden"
      >
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
      <UpdatePrompt />
    </div>
  );
}
