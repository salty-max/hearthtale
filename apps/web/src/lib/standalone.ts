/**
 * The installed app on iOS (home screen, black-translucent status bar) can get
 * a window that stops short of the screen's bottom: a strip under the tab bar
 * that no fixed element reaches. Measure it (the screen's height against the
 * window's, installed app only) into --standalone-gap; the frame stretches
 * over it (components/Layout.tsx).
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
    document.documentElement.style.setProperty("--standalone-gap", `${gap}px`);
  };
  update();
  addEventListener("resize", update);
  addEventListener("orientationchange", update);
}
