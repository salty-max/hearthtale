import { useEffect } from "react";
import { useSettings, type SiteTheme } from "@/lib/settings";

/**
 * The site's frame by day or by night: the setting, or the device's own
 * (followed as it changes). public/theme.js sets it before the first paint;
 * this keeps it, and the browser's bar colour, in step afterwards.
 */
export const BAR = { dark: "#120d09", light: "#eee1c2" } as const;

export function resolveTheme(site: SiteTheme, prefersLight: boolean): "light" | "dark" {
  if (site === "system") return prefersLight ? "light" : "dark";
  return site;
}

function apply(theme: "light" | "dark"): void {
  document.documentElement.dataset.theme = theme;
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", BAR[theme]);
}

export function useSiteTheme(): void {
  const { site } = useSettings();
  useEffect(() => {
    const media = window.matchMedia?.("(prefers-color-scheme: light)");
    const update = () => apply(resolveTheme(site, media?.matches ?? false));
    update();
    media?.addEventListener?.("change", update);
    return () => media?.removeEventListener?.("change", update);
  }, [site]);
}
