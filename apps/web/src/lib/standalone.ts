/**
 * The installed app on iOS (home screen, black-translucent status bar) can get
 * a window that stops short of the screen's bottom. Nothing paints in that strip
 * but the page's background (the tab bar's colour, index.css), so it reads as
 * the bar: the bar then needs no room of its own for the home indicator. When
 * the strip is there, <html> gets the class `standalone-gap` (Layout.tsx).
 */
export function standaloneGap(screenH: number, screenW: number, innerH: number, innerW: number): number {
  const portrait = innerH >= innerW;
  const full = portrait ? Math.max(screenH, screenW) : Math.min(screenH, screenW);
  const gap = full - innerH;
  // A real gap is a strip, not a browser's whole toolbar.
  return gap > 0 && gap < 120 ? gap : 0;
}

export function fitStandalone(): void {
  const standalone = matchMedia("(display-mode: standalone)").matches || (navigator as { standalone?: boolean }).standalone === true;
  if (!standalone) return;
  const update = () => {
    const gap = standaloneGap(screen.height, screen.width, innerHeight, innerWidth);
    document.documentElement.classList.toggle("standalone-gap", gap > 0);
  };
  update();
  addEventListener("resize", update);
  addEventListener("orientationchange", update);
}
