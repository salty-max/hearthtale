// The French writing, a trial (branch french-slice): writes
// addon/Hearthtale/Text_frFR.lua from i18n/frFR/ (the lines, the deeds) and
// the game's own French names (places: the client's AreaTable and
// WMOAreaTable, ../addon-kit/.cache/i18n/; creatures: Yonder's, by id), each
// with what French puts before it: "dans la vallée des Frigères", "à
// Courbenclume", "un jeune troll Frostmane".
//   bun scripts/french.ts
import { readFileSync, writeFileSync } from "node:fs";

const KIT = "../addon-kit/.cache/i18n";
const YONDER = "../yonder";

// ── the lines and the deeds ──────────────────────────────────────────────────
const lines: Record<string, string> = {};
let english: string | null = null;
for (const raw of readFileSync("i18n/frFR/lines.md", "utf8").split("\n")) {
  const en = raw.match(/^- (.+)$/);
  const fr = raw.match(/^ {2}> (.+)$/);
  if (en) english = en[1];
  else if (fr && english) {
    lines[english] = fr[1];
    english = null;
  }
}
const deeds: Record<number, string> = {};
for (const raw of readFileSync("i18n/frFR/deeds.md", "utf8").split("\n")) {
  const m = raw.match(/^- (\d+) \| (.+)$/);
  if (m) deeds[Number(m[1])] = m[2];
}

// ── the client's tables ──────────────────────────────────────────────────────
function csv(path: string): string[][] {
  const rows: string[][] = [];
  for (const line of readFileSync(path, "utf8").split("\n")) {
    if (!line) continue;
    const row: string[] = [];
    let cell = "",
      quoted = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (quoted) {
        if (ch === '"' && line[i + 1] === '"') {
          cell += '"';
          i++;
        } else if (ch === '"') quoted = false;
        else cell += ch;
      } else if (ch === '"') quoted = true;
      else if (ch === ",") {
        row.push(cell);
        cell = "";
      } else cell += ch;
    }
    row.push(cell);
    rows.push(row);
  }
  return rows;
}
// { id: name } of one table, one language
function names(game: string, table: string, locale: string, column: string): Map<string, string> {
  const rows = csv(`${KIT}/${game}/${table}-${locale}.csv`);
  const head = rows[0];
  const id = head.indexOf("ID"),
    name = head.indexOf(column);
  return new Map(rows.slice(1).map((r) => [r[id], r[name]]));
}
// { English name: French name } of a game's places (areas, then the places
// inside buildings), the first id of a name winning
function places(game: string): Map<string, string> {
  const out = new Map<string, string>();
  for (const [table, column] of [
    ["AreaTable", "AreaName_lang"],
    ["WMOAreaTable", "AreaName_lang"],
  ]) {
    const en = names(game === "forever" ? "classic" : game, table, "enUS", column);
    const fr = names(game, table, "frFR", column);
    for (const [id, name] of en) {
      const f = fr.get(id);
      if (name && f && !out.has(name)) out.set(name, f);
    }
  }
  return out;
}

// ── what French puts before a name ───────────────────────────────────────────
// A place named by a common noun: its gender, number and preposition ("dans
// la vallée", "à la ferme", "au camp"); the noun is lower case in a sentence,
// as the game's own French writes it ("de la vallée des Frigères", "dans le
// marais des Chagrins").
const HEADS: Record<string, [string, string]> = {
  vallée: ["f", "dans"],
  ferme: ["f", "à"],
  repaire: ["m", "dans"],
  caverne: ["f", "dans"],
  grotte: ["f", "dans"],
  mine: ["f", "dans"],
  camp: ["m", "à"],
  campement: ["m", "à"],
  col: ["m", "à"],
  lac: ["m", "au bord"],
  bois: ["m", "dans"],
  forêt: ["f", "dans"],
  marais: ["m", "dans"],
  tour: ["f", "à"],
  porte: ["f", "à"],
  colline: ["f", "sur"],
  collines: ["fp", "dans"],
  pic: ["m", "sur"],
  mont: ["m", "sur"],
  gorge: ["f", "dans"],
  plaine: ["f", "dans"],
  plaines: ["fp", "dans"],
  pont: ["m", "sur"],
  place: ["f", "sur"],
  quartier: ["m", "dans"],
  fort: ["m", "à"],
  bastion: ["m", "à"],
  poste: ["m", "à"],
  village: ["m", "dans"],
  ville: ["f", "dans"],
  cité: ["f", "dans"],
  hameau: ["m", "dans"],
  domaine: ["m", "dans"],
  terres: ["fp", "dans"],
  ruines: ["fp", "dans"],
  crypte: ["f", "dans"],
  temple: ["m", "dans"],
  chapelle: ["f", "à"],
  abbaye: ["f", "à"],
  auberge: ["f", "à"],
  scierie: ["f", "à"],
  carrière: ["f", "à"],
  baie: ["f", "dans"],
  côte: ["f", "sur"],
  île: ["f", "sur"],
  rivière: ["f", "au bord de"],
  route: ["f", "sur"],
  cimetière: ["m", "dans"],
  donjon: ["m", "dans"],
  bourg: ["m", "dans"],
  comptoir: ["m", "à"],
  avant: ["m", "à"],
  halte: ["f", "à"],
  refuge: ["m", "au"],
  sanctuaire: ["m", "dans"],
  bassin: ["m", "dans"],
  étang: ["m", "au bord"],
  falaise: ["f", "sur"],
  falaises: ["fp", "sur"],
  grande: ["f", "à"],
};
function contract(s: string): string {
  return s
    .replace(/\bà le /g, "au ")
    .replace(/\bà les /g, "aux ")
    .replace(/\bde le /g, "du ")
    .replace(/\bde les /g, "des ")
    .replace(/\bau bord le /g, "au bord du ")
    .replace(/\bau bord la /g, "au bord de la ")
    .replace(/\bau bord l'/g, "au bord de l'")
    .replace(/\bau bord de le /g, "au bord du ")
    .replace(/\bau le /g, "au ")
    .replace(/\bau la /g, "à la ");
}
const VOWEL = /^[aeiouhéèêëàâîïôûAEIOUHÉÈÊÀÂÎÔÛ]/;
let guessed = 0;
// "dans la vallée des Frigères", or null for a name without a noun of its
// own (a town, a land: "à Kharanos", the writer's guess, counted)
function placeAt(name: string): { at: string; known: boolean } {
  const article = name.match(/^(Le|La|Les|L') ?(.*)$/);
  if (article) {
    const first = article[2].split(" ")[0].toLowerCase();
    const head = HEADS[first];
    const pre = head ? head[1] : "à";
    return { at: contract(`${pre} ${article[1].toLowerCase()}${article[1] === "L'" ? "" : " "}${article[2]}`), known: true };
  }
  const [first, ...rest] = name.split(" ");
  const head = HEADS[first.toLowerCase()];
  if (head && rest.length) {
    const [g, pre] = head;
    const lower = [first.toLowerCase(), ...rest].join(" ");
    const art = g.endsWith("p") ? "les " : VOWEL.test(first) ? "l'" : g === "f" ? "la " : "le ";
    return { at: contract(`${pre} ${art}${lower}`), known: true };
  }
  return { at: `à ${name}`, known: false };
}

// A creature as one of its kind: "un jeune troll Frostmane", its first word
// lower case when it is a word of the language (an adjective, a noun).
const NOUNS: Record<string, string> = {
  troll: "m",
  loup: "m",
  louve: "f",
  sanglier: "m",
  ours: "m",
  araignée: "f",
  kobold: "m",
  gnoll: "m",
  murloc: "m",
  novice: "m",
  chasseur: "m",
  chasseuse: "f",
  mystique: "m",
  ombrelame: "m",
  bandit: "m",
  voleur: "m",
  voleuse: "f",
  brigand: "m",
  pillard: "m",
  harpie: "f",
  centaure: "m",
  ogre: "m",
  gardien: "m",
  gardienne: "f",
  sentinelle: "f",
  matriarche: "f",
  serpent: "m",
  tigre: "m",
  raptor: "m",
  crocilisque: "m",
  vautour: "m",
  chouette: "f",
  chauve: "f",
  rat: "m",
  squelette: "m",
  goule: "f",
  zombie: "m",
  spectre: "m",
  élémentaire: "m",
  golem: "m",
  marin: "m",
  soldat: "m",
  défias: "m",
  tisseur: "m",
  rôdeur: "m",
  esprit: "m",
};
const ADJECTIVES = new Set(["jeune", "petit", "petite", "grand", "grande", "vieux", "vieille", "gros", "grosse", "sombre", "féroce", "sauvage", "vieil"]);
let unsure = 0;
function creatureOne(name: string): string {
  const words = name.split(" ");
  let i = 0;
  while (i < words.length - 1 && ADJECTIVES.has(words[i].toLowerCase())) i++;
  const head = words[i].toLowerCase().replace(/-.*/, "");
  let g = NOUNS[head];
  if (!g) {
    unsure++;
    g = "m";
  }
  const common = ADJECTIVES.has(words[0].toLowerCase()) || NOUNS[words[0].toLowerCase()] !== undefined;
  const text = common ? [words[0].toLowerCase(), ...words.slice(1)].join(" ") : name;
  return (g === "f" ? "une " : "un ") + text;
}

// ── the names, by game ───────────────────────────────────────────────────────
const lua = (s: string) => JSON.stringify(s);
function placeTable(map: Map<string, string>, only?: Map<string, string>): string {
  const out: string[] = [];
  for (const [en, fr] of map) {
    if (only && only.get(en) === fr) continue;
    const { at, known } = placeAt(fr);
    if (!known) guessed++;
    out.push(`    [${lua(en)}] = { name = ${lua(fr)}, at = ${lua(at)} },`);
  }
  return out.join("\n");
}
const forever = places("forever"),
  classic = places("classic");

const creatures: { id: number; name: string }[] = JSON.parse(readFileSync(`${YONDER}/data/creatures.json`, "utf8"));
const frCreatures = JSON.parse(readFileSync(`${YONDER}/i18n/frFR/creatures.json`, "utf8"));
function creatureTable(game: "forever" | "classic"): string {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const c of creatures) {
    const fr = game === "classic" ? frCreatures.classic[c.id] : frCreatures.forever[c.id];
    if (!fr || seen.has(c.name)) continue;
    if (game === "classic" && frCreatures.forever[c.id] === fr) continue;
    seen.add(c.name);
    out.push(`    [${lua(c.name)}] = { name = ${lua(fr)}, one = ${lua(creatureOne(fr))} },`);
  }
  return out.join("\n");
}

// the names an authored French line holds in Forever's words, Classic's
// where they differ ("Forgefer" is "Ironforge" on Classic)
const swaps: string[] = [];
for (const [en, fr] of forever) {
  const c = classic.get(en);
  if (c && c !== fr && fr.length > 3) swaps.push(`    [${lua(fr)}] = ${lua(c)},`);
}

const out = `-- Generated by scripts/french.ts (the French trial). Do not edit.
local _, ns = ...
ns.frenchText = {
  lines = {
${Object.entries(lines)
  .map(([en, fr]) => `    [${lua(en)}] = ${lua(fr)},`)
  .join("\n")}
  },
  deeds = {
${Object.entries(deeds)
  .map(([id, fr]) => `    [${id}] = ${lua(fr)},`)
  .join("\n")}
  },
  places = {
${placeTable(forever)}
  },
  placesClassic = {
${placeTable(classic, forever)}
  },
  creatures = {
${creatureTable("forever")}
  },
  creaturesClassic = {
${creatureTable("classic")}
  },
  classic = {
${swaps.join("\n")}
  },
}
`;
writeFileSync("addon/Hearthtale/Text_frFR.lua", out);
console.log(
  `addon/Hearthtale/Text_frFR.lua: ${Object.keys(lines).length} lines, ${Object.keys(deeds).length} deeds, ` +
    `${forever.size} places (${guessed} by the town rule, "à X"), creatures (${unsure} of an unknown gender, "un")`,
);
