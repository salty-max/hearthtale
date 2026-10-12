import { Monitor, Moon, Sun } from "lucide-react";
import { useT } from "@/lib/i18n";
import { setSettings, SITE_THEMES, useSettings } from "@/lib/settings";

/** Day, night, or as the device: one button that turns from one to the next. */
export function ThemeToggle({ className = "" }: { className?: string }) {
  const t = useT();
  const { site } = useSettings();
  const next = SITE_THEMES[(SITE_THEMES.indexOf(site) + 1) % SITE_THEMES.length];
  const Icon = site === "light" ? Sun : site === "dark" ? Moon : Monitor;
  const label = t.nav.theme(t.settings.sites[site], t.settings.sites[next]);
  return (
    <button onClick={() => setSettings({ site: next })} aria-label={label} title={label} className={`rounded-md p-2 text-gold-bright hover:bg-gold/10 ${className}`}>
      <Icon className="size-5" aria-hidden />
    </button>
  );
}
