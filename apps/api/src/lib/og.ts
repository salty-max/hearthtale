import { frameFor, type Language, type SharedBook } from "@hearthtale/shared";

/**
 * Link previews (Discord, Reddit, Slack…): crawlers asking for a shared page
 * get this tiny page with OpenGraph tags instead of the app, which they can't
 * run. Vercel routes them here by user agent (scripts/vercel-build.sh); a
 * person landing here by chance is sent on to the app. The card's labels are
 * in the reader's language (the crawler's Accept-Language, as the site would
 * choose it), else the book's: whoever it was shared with likely reads it.
 */

const CLASS_COLOUR: Record<string, string> = {
  WARRIOR: "#c69b6d",
  PALADIN: "#f48cba",
  HUNTER: "#aad372",
  ROGUE: "#fff468",
  PRIEST: "#ffffff",
  SHAMAN: "#0070dd",
  MAGE: "#3fc7eb",
  WARLOCK: "#8788ee",
  DRUID: "#ff7c0a",
};
const esc = (s: string) => s.replace(/[&<>"']/g, (ch) => `&#${ch.charCodeAt(0)};`);

/** The part a page shows, by name: an entry's title ("Entry 3" untitled), "Epitaph"… or the whole book. */
function partName(shared: SharedBook, language?: Language): string {
  const p = shared.part;
  const f = frameFor(language ?? shared.book.language);
  if (p === undefined) return f.theBook;
  if (p === "prologue") return f.prologue;
  if (p === "epitaph") return f.epitaph;
  return shared.book.chapters.find((c) => String(c.number) === String(p))?.title ?? f.chapter(Number(p));
}

/** The opening lines of what's shared, for the card. */
export function ogText(shared: SharedBook, max = 220): string {
  const b = shared.book;
  // (a chapter's diary entry before its prose: the shorter telling, read first)
  const first = b.chapters[0];
  const text = b.epitaph && (shared.part === "epitaph" || shared.part === undefined && shared.character.fallen) ? b.epitaph : (b.prologue ?? first?.diary ?? first?.text ?? b.epitaph ?? "");
  const flat = text.replace(/\s+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max - 1).replace(/\s+\S*$/, "")}…` : flat;
}

export function ogTitle(shared: SharedBook, language?: Language): string {
  const c = shared.character;
  const f = frameFor(language ?? shared.book.language);
  const about = `${f.levelWord} ${c.level} ${f.raceClass(c.race, c.class, shared.book.sex ?? c.sex)}`;
  return `${c.name}, ${about}${c.fallen ? f.fallen(shared.book.sex ?? c.sex) : ""} · ${partName(shared, language)}`;
}

export function ogPage(shared: SharedBook, path: string, origin: string, language?: Language): string {
  const url = `${origin}${path}`;
  const title = ogTitle(shared, language);
  const description = ogText(shared);
  const colour = CLASS_COLOUR[shared.character.class] ?? "#c9a227";
  return `<!doctype html>
<html lang="${frameFor(language ?? shared.book.language).lang}"><head><meta charset="utf-8">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<meta property="og:type" content="article">
<meta property="og:site_name" content="Hearthtale">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(url)}">
<meta property="og:image" content="${esc(origin)}/pwa-512.png">
<meta name="twitter:card" content="summary">
<meta name="theme-color" content="${colour}">
<meta http-equiv="refresh" content="0; url=${esc(url)}">
</head><body><a href="${esc(url)}">${esc(title)}</a></body></html>`;
}
