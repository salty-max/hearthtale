// The client's own names in English, for a record kept in English whatever
// the client's language: addon/Hearthtale/Client_Classic.lua and
// Client_Forever.lua (each game's own file), from the client's tables on
// wago.tools (Classic Era and Forever, the builds pinned by knowledge.ts and
// forever-data.ts).
//   bun scripts/client.ts
// - skills: every language's name of a trade, a secondary skill or a riding,
//   its English ("Minage", "Bergbau": "Mining"); riding: the ridings, by
//   their English names ("Mechanostrider Piloting" too)
// - types, families: creature types and families, every language's, English
// - classSpecs: Forever's specializations named after the class (one a
//   class, flag 4), in every language: no way chosen
// - trees: each class's talent trees in the game's order, English
// - areas: every area's English name by id (the game gives the client's own
//   by C_Map.GetAreaInfo: Record.lua turns a place back into English)
// - maps, encounters: dungeons and bosses by id, English
// - spells: the class and trade spells by id, English
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const ROOT = path.join(import.meta.dir, "..");
const CACHE = path.join(ROOT, ".cache", "client");
const UA = { "User-Agent": "Hearthtale/1.0 (addon; github.com/salty-max/hearthtale)" };
const GAMES = {
  classic: { product: "product=wow_classic_era&build=1.15.9.70003", out: "Client_Classic.lua" },
  forever: { product: "product=wow_classic_beta&build=1.60.1.70291", out: "Client_Forever.lua" },
};
const LOCALES = ["deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"];

function csv(text: string): Record<string, string>[] {
  const lines: string[][] = [];
  let row: string[] = [],
    cell = "",
    quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") {
      row.push(cell);
      cell = "";
    } else if (c === "\n") {
      row.push(cell);
      lines.push(row);
      row = [];
      cell = "";
    } else if (c !== "\r") cell += c;
  }
  if (cell || row.length) {
    row.push(cell);
    lines.push(row);
  }
  const head = lines[0] ?? [];
  return lines.slice(1).map((r) => Object.fromEntries(head.map((h, i) => [h, r[i] ?? ""])));
}
async function table(game: keyof typeof GAMES, name: string, locale = "enUS") {
  const file = path.join(CACHE, game, `${name}-${locale}.csv`);
  if (!existsSync(file)) {
    mkdirSync(path.dirname(file), { recursive: true });
    const loc = locale === "enUS" ? "" : `&locale=${locale}`;
    const res = await fetch(`https://wago.tools/db2/${name}/csv?${GAMES[game].product}${loc}`, { headers: UA });
    if (!res.ok) throw new Error(`${name} ${game} ${locale}: ${res.status}`);
    writeFileSync(file, await res.text());
  }
  return csv(readFileSync(file, "utf8"));
}

const lua = (s: string) => JSON.stringify(s);
const CLASSES: [number, string][] = [
  [1, "WARRIOR"],
  [2, "PALADIN"],
  [4, "HUNTER"],
  [8, "ROGUE"],
  [16, "PRIEST"],
  [64, "SHAMAN"],
  [128, "MAGE"],
  [256, "WARLOCK"],
  [1024, "DRUID"],
];

for (const game of Object.keys(GAMES) as (keyof typeof GAMES)[]) {
  // every language's name of a row, its English: a name meaning two English
  // ones in two languages is left out (none so far), counted
  const conflicts: string[] = [];
  async function translated(name: string, field: string, keep: (r: Record<string, string>) => boolean) {
    const en = new Map((await table(game, name)).filter(keep).map((r) => [r.ID, r[field]]));
    const out = new Map<string, string>();
    const bad = new Set<string>();
    const english_ = new Set(en.values()); // (a name English uses for another)
    for (const locale of LOCALES) {
      for (const r of await table(game, name, locale)) {
        const english = en.get(r.ID);
        for (const f of [field, "FemaleName_lang"]) {
          const local = r[f];
          if (!english || !local || local === english) continue;
          const had = out.get(local);
          if ((had && had !== english) || english_.has(local)) bad.add(local);
          else out.set(local, english);
        }
      }
    }
    for (const b of bad) {
      out.delete(b);
      conflicts.push(`${name} ${b}`);
    }
    return { en, out };
  }
  const skillLines = (r: Record<string, string>) => r.CategoryID === "9" || r.CategoryID === "11";
  const skills = await translated("SkillLine", "DisplayName_lang", skillLines);
  const riding = [...new Set(skills.en.values())].filter((n) => /Riding|Piloting|Horsemanship/.test(n)).sort();
  const types = await translated("CreatureType", "Name_lang", () => true);
  const families = await translated("CreatureFamily", "Name_lang", () => true);
  const taxi = await translated("TaxiNodes", "Name_lang", (r) => r.Name_lang !== "");
  // (Forever's specializations: one a class, named after it; Classic has
  // none), by id and by every language's names (a record's, to mend)
  const classSpecs = new Set<string>();
  const classSpecNames = new Set<string>();
  if (game === "forever") {
    for (const locale of ["enUS", ...LOCALES])
      for (const r of await table(game, "ChrSpecialization", locale))
        if (r.ClassID !== "0" && (Number(r.Flags) & 4) !== 0) {
          classSpecs.add(r.ID);
          for (const n of [r.Name_lang, r.FemaleName_lang]) if (n) classSpecNames.add(n);
        }
  }
  const treeNames = await translated("TalentTab", "Name_lang", () => true);
  const trees: Record<string, string[]> = {};
  for (const r of (await table(game, "TalentTab")).sort((a, b) => Number(a.OrderIndex) - Number(b.OrderIndex))) {
    for (const [mask, token] of CLASSES) {
      if (Number(r.ClassMask) === mask) (trees[token] ??= []).push(r.Name_lang);
    }
  }
  const areas = (await table(game, "AreaTable")).filter((r) => r.AreaName_lang);
  const maps = (await table(game, "Map")).filter((r) => r.InstanceType === "1" || r.InstanceType === "2");
  const encounters = (await table(game, "DungeonEncounter")).filter((r) => r.Name_lang);
  // the spells of a class's lines and of the trades (secondary skills, ridings)
  const lines = new Set(
    (await table(game, "SkillLine"))
      .filter((r) => r.CategoryID === "7" || skillLines(r))
      .map((r) => r.ID),
  );
  const wanted = new Set((await table(game, "SkillLineAbility")).filter((r) => lines.has(r.SkillLine)).map((r) => r.Spell));
  const spells = (await table(game, "SpellName")).filter((r) => wanted.has(r.ID) && r.Name_lang);

  const entries = (m: Map<string, string>) =>
    [...m]
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([k, v]) => `    [${lua(k)}] = ${lua(v)},`)
      .join("\n");
  const ids = (rows: Record<string, string>[], field: string) =>
    rows
      .sort((a, b) => Number(a.ID) - Number(b.ID))
      .map((r) => `    [${r.ID}] = ${lua(r[field])},`)
      .join("\n");
  const out = `-- Generated by scripts/client.ts: the client's own names in English, for a
-- record kept in English whatever the client's language. Do not edit.
local _, ns = ...
ns.client = {
  -- every language's name of a trade, a secondary skill or a riding: its English
  skills = {
${entries(skills.out)}
  },
  riding = {
${riding.map((n) => `    [${lua(n)}] = true,`).join("\n")}
  },
  -- creature types and families, every language's: English
  types = {
${entries(types.out)}
  },
  families = {
${entries(families.out)}
  },
  -- specializations named after the class: no way chosen
  classSpecs = {
${[...classSpecs]
  .sort((a, b) => Number(a) - Number(b))
  .map((id) => `    [${id}] = true,`)
  .join("\n")}
  },
  classSpecNames = {
${[...classSpecNames]
  .sort()
  .map((n) => `    [${lua(n)}] = true,`)
  .join("\n")}
  },
  -- flight masters' places, every language's: English
  taxi = {
${entries(taxi.out)}
  },
  -- talent trees, every language's: English
  treeNames = {
${entries(treeNames.out)}
  },
  -- each class's talent trees, in the game's order
  trees = {
${Object.entries(trees)
  .map(([k, v]) => `    ${k} = { ${v.map(lua).join(", ")} },`)
  .join("\n")}
  },
  -- every area by id (C_Map.GetAreaInfo gives the client's own name)
  areas = {
${ids(areas, "AreaName_lang")}
  },
  -- dungeons and raids by id (GetInstanceInfo's last), bosses by encounter id
  maps = {
${ids(maps, "MapName_lang")}
  },
  encounters = {
${ids(encounters, "Name_lang")}
  },
  -- the class and trade spells by id
  spells = {
${ids(spells, "Name_lang")}
  },
}
`;
  writeFileSync(path.join(ROOT, "addon/Hearthtale", GAMES[game].out), out);
  console.log(
    `${GAMES[game].out}: ${skills.out.size} skill names, ${riding.length} ridings, ${types.out.size + families.out.size} creature kinds, ` +
      `${taxi.out.size} flight names, ${classSpecs.size} class specs, ${Object.keys(trees).length} classes' trees, ${areas.length} areas, ${maps.length} instances, ` +
      `${encounters.length} bosses, ${spells.length} spells` +
      (conflicts.length ? `; ambiguous, left out: ${conflicts.join(", ")}` : ""),
  );
}
