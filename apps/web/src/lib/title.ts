import { useEffect } from "react";

/** The browser's tab and history: "Bristle — Brannok · Hearthtale", or the site's name alone. */
export function useTitle(...parts: (string | undefined | false)[]): void {
  const title = [...parts.filter(Boolean), "Hearthtale"].join(" · ");
  useEffect(() => {
    document.title = title;
  }, [title]);
}
