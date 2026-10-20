// The client's own names in English, for a record kept in English whatever
// the client's language: addon/Hearthtale/Client_Classic.lua and
// Client_Forever.lua (each game's own file), from the client's tables as
// wow-data's databases hold them (Classic Era's and Forever's, each its pinned
// build; ../wow-data).
//   bun scripts/client.ts           (part of bun run audit)
//   bun scripts/client.ts --check   fails if the files are not what the
//                                   databases and the audit's data give
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
// - specIds: Forever's specializations by id, English (a chosen one kept in
//   English)
// - skillIds, typeIds, familyIds, taxiIds, treeIds, inside, mounts: by id,
//   English, the trades, secondary skills and ridings, the creature types and
//   families, the flight points, the talent trees, the places inside
//   buildings (i18n/enUS/subzones.json, the kit's) and the mounts' auras: the
//   saved file keeps the record's names by these ids (Record.lua's toIds)
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import type * as WowDb from "../../wow-data/src/db";
import { familyPath } from "./root";

// through the family folder, from a worktree too (scripts/root.ts)
const { openDb } = (await import(familyPath("wow-data", "src", "db.ts"))) as typeof WowDb;

const ROOT = path.join(import.meta.dir, "..");
const GAMES = {
  classic: { out: "Client_Classic.lua" },
  forever: { out: "Client_Forever.lua" },
};
const LOCALES = ["deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"];
const CHECK = process.argv.includes("--check");
const stale: string[] = [];
// (a file written, or with --check compared)
function write(name: string, text: string) {
  const file = path.join(ROOT, "addon/Hearthtale", name);
  if (!CHECK) return writeFileSync(file, text);
  if (!existsSync(file) || readFileSync(file, "utf8") !== text) stale.push(name);
}

// A client table at its game's pinned build, as the database holds it: its
// rows as the client's files write them (text). In another language, its name
// fields that language's (the database's names, the client's own).
const dbs = { classic: openDb("classic"), forever: openDb("forever") };
const NAMED: Record<string, { kind: string; field: string; female?: string }> = {
  SkillLine: { kind: "skill_line", field: "DisplayName_lang" },
  CreatureType: { kind: "creature_type", field: "Name_lang" },
  CreatureFamily: { kind: "creature_family", field: "Name_lang" },
  TaxiNodes: { kind: "taxi_node", field: "Name_lang" },
  ChrSpecialization: { kind: "specialization", field: "Name_lang", female: "FemaleName_lang" },
  TalentTab: { kind: "talent_tab", field: "Name_lang" },
};
async function table(game: keyof typeof GAMES, name: string, locale = "enUS"): Promise<Record<string, string>[]> {
  const db = dbs[game];
  const rows = (db.query(`SELECT * FROM client_${name} ORDER BY rowid`).all() as Record<string, unknown>[]).map((r) =>
    Object.fromEntries(Object.entries(r).map(([k, v]) => [k, v === null || v === undefined ? "" : String(v)])),
  );
  if (locale === "enUS") return rows;
  const n = NAMED[name];
  if (!n) throw new Error(`client_${name}: no names in ${locale}`);
  const names = new Map(
    (db.query("SELECT id, name, female FROM name WHERE kind = ? AND locale = ?").all(n.kind, locale) as { id: number; name: string; female: string | null }[]).map(
      (r) => [String(r.id), r],
    ),
  );
  return rows.map((r) => {
    const t = names.get(r.ID);
    return { ...r, [n.field]: t?.name ?? "", ...(n.female ? { [n.female]: t?.female ?? "" } : {}) };
  });
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

// The game's creatures and quests in English by id, from the audit's data
// (bun run audit: classic-db, and Forever's additions over it): { creatures:
// id = name, quests: id = { title, targets, items } }.
type Quest = { title: string; targets: number[]; items: number[] };
function audit(file: string, into: { creatures: Map<number, string>; quests: Map<number, Quest> }) {
  const where = path.join(ROOT, ".cache/audit", file);
  if (!existsSync(where)) throw new Error(`${where}: run bun run audit first`);
  const unquote = (s: string) => s.replace(/\\(.)/g, "$1");
  let block: string[] = [];
  for (const line of readFileSync(where, "utf8").split("\n")) {
    const end = line.match(/^end\)\(D\.(\w+)\)/);
    if (!end) {
      block.push(line);
      continue;
    }
    for (const row of block) {
      const id = Number(row.match(/^t\[(\d+)\]=/)?.[1]);
      if (!id) continue;
      if (end[1] === "creatures") {
        const name = row.match(/[{,]name="((?:[^"\\]|\\.)*)"/)?.[1];
        if (name) into.creatures.set(id, unquote(name));
      } else if (end[1] === "quests") {
        const title = row.match(/[{,]title="((?:[^"\\]|\\.)*)"/)?.[1];
        const ids = (field: string) =>
          [...(row.match(new RegExp(`${field}=\\{((?:\\{[^}]*\\},?)*)\\}`))?.[1] ?? "").matchAll(/\{(\d+)/g)].map((m) => Number(m[1]));
        if (title) into.quests.set(id, { title: unquote(title), targets: ids("targets"), items: ids("items") });
      }
    }
    block = [];
  }
}
const names = {
  classic: { creatures: new Map<number, string>(), quests: new Map<number, Quest>() },
  forever: { creatures: new Map<number, string>(), quests: new Map<number, Quest>() },
};
audit("game.lua", names.classic);
audit("game.lua", names.forever);
audit("game-forever.lua", names.forever);

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
  // (Forever's specializations, a chosen one: every language's name, its
  // English; by id, English)
  const specs = game === "forever" ? await translated("ChrSpecialization", "Name_lang", (r) => r.ClassID !== "0") : { en: new Map<string, string>(), out: new Map<string, string>() };
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
  // the mounts' auras (the aura that mounts, 78)
  const mounting = new Set((await table(game, "SpellEffect")).filter((r) => r.EffectAura === "78").map((r) => r.SpellID));
  const mounts = (await table(game, "SpellName")).filter((r) => mounting.has(r.ID) && r.Name_lang);
  const insideFile = path.join(ROOT, "i18n", "enUS", "subzones.json");
  const inside: Record<string, string> = existsSync(insideFile) ? JSON.parse(readFileSync(insideFile, "utf8"))[game] ?? {} : {};
  const byId = (m: Map<string, string>) =>
    [...m]
      .filter(([, n]) => n)
      .sort(([a], [b]) => Number(a) - Number(b))
      .map(([id, n]) => `    [${id}] = ${lua(n)},`)
      .join("\n");

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
  -- by id (the saved file keeps the record's names by them): the trades,
  -- secondary skills and ridings; the creature types and families; the
  -- flight points; the talent trees; the places inside buildings; the
  -- mounts' auras
  skillIds = {
${byId(skills.en)}
  },
  typeIds = {
${byId(types.en)}
  },
  familyIds = {
${byId(families.en)}
  },
  taxiIds = {
${byId(taxi.en)}
  },
  treeIds = {
${byId(treeNames.en)}
  },
  -- Forever's specializations by id, English (a chosen one kept in English)
  specIds = {
${byId(specs.en)}
  },
  inside = {
${byId(new Map(Object.entries(inside)))}
  },
  mounts = {
${ids(mounts, "Name_lang")}
  },
}
`;
  write(GAMES[game].out, out);

  // the names a client in another language gives in its own: creatures,
  // quests (their targets and items, by the quest log's order of each),
  // items (the client's own table; not the creatures' weapons)
  const items = (await table(game, "ItemSparse")).filter((r) => r.Display_lang && !/^Monster - /.test(r.Display_lang));
  const { creatures, quests } = names[game];
  const english = `-- Generated by scripts/client.ts: the game's creatures, quests and items in
-- English by id, for a client in another language (Record.lua makes the
-- tables at its first need: an English client never does). Do not edit.
local _, ns = ...
function ns.englishNames()
  return {
    creatures = {
${[...creatures]
  .sort(([a], [b]) => a - b)
  .map(([id, n]) => `[${id}]=${lua(n)},`)
  .join("\n")}
    },
    quests = {
${[...quests]
  .sort(([a], [b]) => a - b)
  .map(
    ([id, q]) =>
      `[${id}]={title=${lua(q.title)}` +
      (q.targets.length ? `,targets={${q.targets.join(",")}}` : "") +
      (q.items.length ? `,items={${q.items.join(",")}}` : "") +
      "},",
  )
  .join("\n")}
    },
    items = {
${items
  .sort((a, b) => Number(a.ID) - Number(b.ID))
  .map((r) => `[${r.ID}]=${lua(r.Display_lang)},`)
  .join("\n")}
    },
  }
end
`;
  const englishOut = GAMES[game].out.replace("Client_", "English_");
  write(englishOut, english);
  console.log(`${englishOut}: ${creatures.size} creatures, ${quests.size} quests, ${items.length} items`);
  console.log(
    `${GAMES[game].out}: ${skills.out.size} skill names, ${riding.length} ridings, ${types.out.size + families.out.size} creature kinds, ` +
      `${taxi.out.size} flight names, ${classSpecs.size} class specs, ${Object.keys(trees).length} classes' trees, ${areas.length} areas, ${maps.length} instances, ` +
      `${encounters.length} bosses, ${spells.length} spells, ${Object.keys(inside).length} places inside, ${mounts.length} mounts` +
      (conflicts.length ? `; ambiguous, left out: ${conflicts.join(", ")}` : ""),
  );
}
if (CHECK) {
  if (stale.length) {
    console.error(`stale: ${stale.join(", ")} (bun scripts/client.ts writes them)`);
    process.exit(1);
  }
  console.log("✓ the client tables are what the pins give");
}
