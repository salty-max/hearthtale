/**
 * When an entry was lived, as short as it reads (as the addon's own header):
 * "5 Oct 2026", "5 to 7 Oct 2026", "30 Sep to 2 Oct 2026",
 * "30 Dec 2026 to 2 Jan 2027". Unix seconds; to: nothing yet, the day it began.
 */
export function dateRange(from: number | undefined, to: number | undefined, locale: string, joiner = "to"): string | undefined {
  if (!from) return undefined;
  const a = new Date(from * 1000);
  const b = to ? new Date(to * 1000) : a;
  const day = (d: Date, o: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat(locale, o).format(d);
  const full: Intl.DateTimeFormatOptions = { day: "numeric", month: "short", year: "numeric" };
  if (a.toDateString() === b.toDateString()) return day(a, full);
  if (a.getFullYear() !== b.getFullYear()) return `${day(a, full)} ${joiner} ${day(b, full)}`;
  if (a.getMonth() !== b.getMonth()) return `${day(a, { day: "numeric", month: "short" })} ${joiner} ${day(b, full)}`;
  return `${day(a, { day: "numeric" })} ${joiner} ${day(b, full)}`;
}

/** "3 hours ago", "yesterday", "in 2 days": how long since a moment (ms). */
export function ago(at: number, locale: string, now = Date.now()): string {
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: "auto" });
  const s = Math.round((at - now) / 1000);
  const steps: [Intl.RelativeTimeFormatUnit, number][] = [
    ["year", 365 * 86400],
    ["month", 30 * 86400],
    ["week", 7 * 86400],
    ["day", 86400],
    ["hour", 3600],
    ["minute", 60],
  ];
  for (const [unit, size] of steps) {
    if (Math.abs(s) >= size) return rtf.format(Math.round(s / size), unit);
  }
  return rtf.format(0, "minute");
}
