import type { SharedBook } from "@hearthtale/shared";

/**
 * Link previews (Discord, Reddit, Slack…): crawlers asking for a shared page
 * get this tiny page with OpenGraph tags instead of the app, which they can't
 * run. Vercel routes them here by user agent (scripts/vercel-build.sh); a
 * person landing here by chance is sent on to the app.
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
const RACE: Record<string, string> = {
  Human: "Human", Dwarf: "Dwarf", NightElf: "Night Elf", Gnome: "Gnome", Orc: "Orc", Troll: "Troll",
  Tauren: "Tauren", Scourge: "Undead", Skyborne: "Skyborne",
};
const cap = (s: string) => s.charAt(0) + s.slice(1).toLowerCase();
const esc = (s: string) => s.replace(/[&<>"']/g, (ch) => `&#${ch.charCodeAt(0)};`);

/** The part a page shows, by name: "Entry 3", "Epitaph"… or the whole book. */
function partName(shared: SharedBook): string {
  const p = shared.part;
  if (p === undefined) return "The book";
  if (p === "prologue") return "Prologue";
  if (p === "epitaph") return "Epitaph";
  return `Entry ${p}`;
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

export function ogTitle(shared: SharedBook): string {
  const c = shared.character;
  return `${c.name}, level ${c.level} ${RACE[c.race] ?? c.race} ${cap(c.class)}${c.fallen ? " (fallen)" : ""} · ${partName(shared)}`;
}

export function ogPage(shared: SharedBook, path: string, origin: string): string {
  const url = `${origin}${path}`;
  const title = ogTitle(shared);
  const description = ogText(shared);
  const colour = CLASS_COLOUR[shared.character.class] ?? "#c9a227";
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
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
