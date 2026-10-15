/**
 * i18n/<locale>/ → addon/Hearthtale/Text_<locale>.lua, one for every language
 * the game has (the game's names in it, and its translation where there is
 * one): each client loads its own, through Text_[TextLocale].lua in the TOCs,
 * and English stays wherever a translation says nothing (Locale.lua). The
 * interface's words: the journal itself is written in English on every
 * client.
 *
 *   i18n/<locale>/meta.json    { "plural": "one" | "fr" | "ru" | "none",
 *                              "flagged": true }  (flagged: a
 *                              first translation, no native reader's yet)
 *   i18n/<locale>/words.json   { "English": "translation" }: every L["..."]
 *                              and plural(n, "one", "many") of the addon, its
 *                              kit's included; i18n/words.json lists them
 *   i18n/<locale>/races.json   the races by their tokens, masculine and
 *                              feminine (scripts/race_names.ts <locale>)
 *   i18n/<locale>/subzones.json the places inside buildings by their ids,
 *                              { forever, classic }, every language's, English
 *                              one of them (enGB: enUS's), complete
 *                              (../addon-kit/subzones.py <locale>): the
 *                              recorder finds a building's id by the name the
 *                              client gives (Record.lua)
 *
 * A language without its own words may borrow another's translation (esMX:
 * esES).
 *
 *   bun scripts/locales.ts            write the Text files
 *   bun scripts/locales.ts --check    fail if one isn't up to date, a word has
 *                                     no translation or a semicolon
 *   bun scripts/locales.ts --keys     write i18n/words.json, every word to translate
 */
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = new URL("..", import.meta.url).pathname;
const I18N = join(ROOT, "i18n");
const ADDON = join(ROOT, "addon/Hearthtale");
const LOCALES = ["enUS", "enGB", "deDE", "frFR", "esES", "esMX", "ruRU", "ptBR", "itIT", "koKR", "zhCN", "zhTW"];
const ENGLISH = new Set(["enUS", "enGB"]);
const BORROWS: Record<string, string> = { esMX: "esES" };
// (the game's names: a language the client names nothing in its own, another's)
const NAMES_OF: Record<string, string> = { enGB: "enUS" };
const translated = (locale: string) => existsSync(join(I18N, locale, "words.json"));
// The game's names in a language: the places inside buildings by their ids,
// each game's.
function namesLua(locale: string): string[] {
  const file = join(I18N, NAMES_OF[locale] ?? locale, "subzones.json");
  if (!existsSync(file)) throw new Error(`${relative(ROOT, file)} is missing: python3 ../addon-kit/subzones.py ${NAMES_OF[locale] ?? locale}`);
  const t: { forever?: Record<string, string>; classic?: Record<string, string> } = json(file);
  const races: Record<string, [string, string]> = json(join(I18N, NAMES_OF[locale] ?? locale, "races.json"));
  const lines = ["-- the places inside buildings by their ids, the races by their tokens, this language's names", "ns.gameNames({"];
  lines.push("  races = {");
  for (const [token, [m, f]] of Object.entries(races).sort(([a], [b]) => a.localeCompare(b))) lines.push(`    ${token} = { ${q(m)}, ${q(f)} },`);
  lines.push("  },");
  for (const [key, list] of [
    ["inside", t.forever],
    ["insideClassic", t.classic],
  ] as const) {
    lines.push(`  ${key} = {`);
    for (const [id, n] of Object.entries(list ?? {}).sort(([a], [b]) => Number(a) - Number(b))) lines.push(`    [${id}] = ${q(n)},`);
    lines.push("  },");
  }
  lines.push("})");
  return lines;
}
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// (the writer's files: the journal's English, no L)
const WRITER = new Set(["Names.lua", "Knowledge.lua", "Language.lua", "Lines.lua", "Diary.lua", "Forever.lua"]);
// every L["..."] and plural(n, "one", "many") of the addon's own files and its
// kit's; the kit's month names (K.day)
function keys(): string[] {
  const found = new Set<string>(MONTHS);
  const unq = (s: string) => s.replace(/\\(["\\n])/g, (_, c) => (c === "n" ? "\n" : c));
  for (const f of readdirSync(ADDON).sort()) {
    if (!f.endsWith(".lua") || /^(Text|Data|Client|English)_/.test(f) || WRITER.has(f)) continue;
    const src = readFileSync(join(ADDON, f), "utf8");
    for (const m of src.matchAll(/\bL\[\s*"((?:[^"\\]|\\.)*)"\s*\]/g)) found.add(unq(m[1]));
    for (const m of src.matchAll(/plural\([^,()]+(?:\([^()]*\))?,\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\s*\)/g)) {
      found.add(unq(m[1]));
      found.add(unq(m[2]));
    }
  }
  return [...found].sort();
}

const q = (s: string) => `"${s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
const json = (file: string) => (existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {});

function luaFor(locale: string): string {
  const from = translated(locale) ? locale : BORROWS[locale] && translated(BORROWS[locale]) ? BORROWS[locale] : null;
  const lines = [`-- Generated by scripts/locales.ts from i18n/: edit those, not this file.`, "local _, ns = ...", ...namesLua(locale)];
  if (ENGLISH.has(locale) || !from) {
    lines.push(`-- (${ENGLISH.has(locale) ? "English: the words as the addon writes them" : "no translation yet: English"})`);
    return `${lines.join("\n")}\n`;
  }
  const meta = json(join(I18N, from, "meta.json"));
  const words: Record<string, string> = json(join(I18N, from, "words.json"));
  lines.push("ns.translate({", `  locale = ${q(locale)},`, `  plural = ${q(meta.plural ?? "one")},`);
  lines.push("  words = {");
  for (const [k, v] of Object.entries(words)
    .filter(([, v]) => v)
    .sort(([a], [b]) => a.localeCompare(b)))
    lines.push(`    [${q(k)}] = ${q(v)},`);
  lines.push("  },", "})");
  return `${lines.join("\n")}\n`;
}

const args = process.argv.slice(2);
const all = keys();
if (args[0] === "--keys") {
  writeFileSync(join(I18N, "words.json"), `${JSON.stringify(Object.fromEntries(all.map((k) => [k, ""])), null, 2)}\n`);
  console.log(`✓ i18n/words.json: ${all.length} words to translate`);
  process.exit(0);
}
const check = args.includes("--check");
let bad = false;
for (const locale of LOCALES) {
  const out = join(ADDON, `Text_${locale}.lua`);
  const lua = luaFor(locale);
  if (check) {
    if ((existsSync(out) ? readFileSync(out, "utf8") : "") !== lua) {
      console.error(`✗ ${relative(ROOT, out)} is out of date: run bun run locales`);
      bad = true;
    }
  } else writeFileSync(out, lua);
  if (!translated(locale)) continue;
  const words: Record<string, string> = json(join(I18N, locale, "words.json"));
  const meta = json(join(I18N, locale, "meta.json"));
  const missing = all.filter((k) => !words[k]);
  const unused = Object.keys(words).filter((k) => !all.includes(k));
  console.log(`${locale}: ${all.length - missing.length}/${all.length} words${meta.flagged ? ", flagged" : ""}`);
  if (missing.length) {
    console.error(`  ✗ no translation: ${missing.join(" | ")}`);
    if (check) bad = true;
  }
  if (unused.length) console.log(`  words no longer used: ${unused.join(" | ")}`);
  // (no semicolons in what players read, in any language: the gender token's own aside)
  for (const v of Object.values(words))
    if (v.replace(/\$g[^:;]*:[^;]*;/g, "").includes(";")) {
      console.error(`  ✗ a semicolon: ${v}`);
      bad = true;
    }
}
for (const k of all)
  if (k.includes(";")) {
    console.error(`✗ a semicolon: ${k}`);
    bad = true;
  }
if (bad) process.exit(1);
