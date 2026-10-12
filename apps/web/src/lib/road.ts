import type { Book, BookChapter } from "@hearthtale/shared";

/** What a book's entries add up to: how many, the levels, the days, the places, the close calls, the rares. */
export function roadOf(book: Book) {
  const chs = book.chapters;
  const first = chs[0];
  const last = chs[chs.length - 1];
  const start = first?.began;
  const end = last ? (last.ended ?? last.began) : undefined;
  const places: string[] = [];
  for (const c of chs) if (c.place && !places.includes(c.place)) places.push(c.place);
  return {
    entries: chs.length,
    from: first?.from ?? 0,
    to: last?.to ?? 0,
    days: start !== undefined && end !== undefined ? Math.max(1, Math.ceil((end - start) / 86400)) : chs.length > 0 ? 1 : 0,
    places,
    closeCalls: chs.filter((c) => c.close).length,
    rares: chs.filter((c) => c.rare).length,
  };
}

/**
 * The level over time, each entry from its start to its end (the one still
 * being written: to the book's last saving, `until`): points (x: seconds,
 * else its order) for the chart.
 */
export function levelPoints(chs: BookChapter[], until?: number): { x: number; y: number; ch: BookChapter }[] {
  const timed = chs.every((c) => c.began !== undefined);
  return chs.flatMap((c, i) => {
    const a = timed ? c.began! : i;
    const b = timed ? (c.ended ?? (c.open && until !== undefined && until > a ? until : a)) : i + 1;
    return [
      { x: a, y: c.from, ch: c },
      { x: b, y: c.to, ch: c },
    ];
  });
}
