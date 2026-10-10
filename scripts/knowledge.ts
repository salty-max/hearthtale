// What the game itself knows and the record doesn't, for the writer: which
// quests belong to a class and the spell they give ("Beginnings": a warlock's
// first imp), and who the quest givers are: their people (by their model's
// race, from the client's tables on wago.tools, or the faction they serve
// where it is one people's own: Gnomeregan's gnomes, Darnassus's night
// elves...) and their calling ("Warlock Trainer"). From the classic-db dump
// in .cache/audit (`bun scripts/audit-data.ts`), into
// addon/Hearthtale/Knowledge.lua.
//   bun scripts/knowledge.ts
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";
import path from "node:path";
import { rows } from "./sql";

const DIR = path.join(import.meta.dir, "..", ".cache", "audit");
const OUT = path.join(import.meta.dir, "..", "addon", "Hearthtale", "Knowledge.lua");
const sql = gunzipSync(readFileSync(path.join(DIR, "classicdb.sql.gz"))).toString("utf8");

// The race of a creature's model, from the client's own tables (wago.tools,
// Classic Era, one build pinned): what a person is when their faction serves
// several peoples (Stormwind's, Orgrimmar's) or another's (the gnomes who
// serve Ironforge).
const ERA_BUILD = "1.15.9.70003";
async function eraTable(name: string) {
  const file = path.join(DIR, "wago", `${name}.${ERA_BUILD}.csv`);
  if (!existsSync(file)) {
    mkdirSync(path.dirname(file), { recursive: true });
    const url = `https://wago.tools/db2/${name}/csv?product=wow_classic_era&build=${ERA_BUILD}`;
    const res = await fetch(url, { headers: { "User-Agent": "Hearthtale/0.5 (addon data; github.com/salty-max/hearthtale)" } });
    if (!res.ok) throw new Error(`${url}: ${res.status}`);
    writeFileSync(file, await res.text());
  }
  const [head, ...lines] = readFileSync(file, "utf8").trim().split("\n");
  const cols = head.split(",");
  return lines.map((l) => Object.fromEntries(l.split(",").map((v, i) => [cols[i], v])));
}
const RACE: Record<string, string> = { 1: "Human", 2: "Orc", 3: "Dwarf", 4: "NightElf", 5: "Scourge", 6: "Tauren", 7: "Gnome", 8: "Troll" };
const extended = new Map<string, string>();
for (const r of await eraTable("CreatureDisplayInfo")) extended.set(r.ID, r.ExtendedDisplayInfoID);
const raceOfExtra = new Map<string, string>();
for (const r of await eraTable("CreatureDisplayInfoExtra")) raceOfExtra.set(r.ID, r.DisplayRaceID);
const raceOf = (model: number) => RACE[raceOfExtra.get(extended.get(String(model)) ?? "") ?? ""];

// The factions that are one people's own (their faction template ids).
const PEOPLE: Record<number, string> = {
  875: "Gnome", // Gnomeregan Exiles
  55: "Dwarf", // Ironforge
  57: "Dwarf", // Ironforge's mountaineers
  80: "NightElf", // Darnassus
  79: "NightElf",
  104: "Tauren", // Thunder Bluff
  105: "Tauren",
  68: "Scourge", // Undercity
  71: "Scourge",
  126: "Troll", // Darkspear
};
// The factions of the capitals that serve several peoples: Stormwind's,
// Theramore's and Orgrimmar's (a person there is what their model is).
const CAPITALS = new Set([11, 12, 1077, 1078, 29, 85, 1074]);
// A quest giver's people: their model's race, in their people's own faction
// or a capital's; a human or an orc anywhere (no faction is theirs alone);
// else what their faction says. (Not by model alone: a Dark Iron is a dwarf
// to the client, a Zandalari a troll.)
function peopleOf(faction: number, model: number) {
  const race = raceOf(model), own = PEOPLE[faction];
  if (race && (own || CAPITALS.has(faction) || race === "Human" || race === "Orc")) return race;
  return own;
}
const CLASSES: [number, string][] = [
  [1, "WARRIOR"], [2, "PALADIN"], [4, "HUNTER"], [8, "ROGUE"], [16, "PRIEST"], [64, "SHAMAN"], [128, "MAGE"],
  [256, "WARLOCK"], [1024, "DRUID"],
];

const spellName = new Map<number, string>();
for (const r of rows(sql, "spell_template")) spellName.set(r.Id as number, r.SpellName as string);
// (a spell that teaches another: the one taught)
const teaches = new Map<number, number>();
for (const r of rows(sql, "spell_template"))
  for (const k of [1, 2, 3]) if (r[`Effect${k}`] === 36 && r[`EffectTriggerSpell${k}`]) teaches.set(r.Id as number, r[`EffectTriggerSpell${k}`] as number);

const questNpcs = new Set<number>();
for (const table of ["creature_questrelation", "creature_involvedrelation"])
  for (const r of rows(sql, table)) questNpcs.add(r.id as number);

// (a shaman's initiation into an element: its totem, given at the end)
const TOTEMS: Record<number, string> = { 5175: "earth", 5176: "fire", 5177: "water", 5178: "air" };
const quests: Record<number, { class?: string; spell?: string; totem?: string }> = {};
for (const r of rows(sql, "quest_template")) {
  const mask = r.RequiredClasses as number;
  const classes = CLASSES.filter(([bit]) => mask & bit).map(([, c]) => c);
  // (a spell taught, not one cast on me as a reward; riding is a skill)
  const taught = teaches.get(r.RewSpellCast as number) ?? teaches.get(r.RewSpell as number);
  const spell = taught ? spellName.get(taught) : undefined;
  const q: { class?: string; spell?: string; totem?: string } = {};
  if (classes.length === 1) q.class = classes[0];
  if (q.class && spell && spell !== "Riding") q.spell = spell;
  for (let k = 1; k <= 4; k++) if (TOTEMS[r[`RewItemId${k}`] as number]) q.totem = TOTEMS[r[`RewItemId${k}`] as number];
  if (q.class) quests[r.entry as number] = q;
}

// Quest chains: for each quest of one, the chain's first quest (chains[id])
// and whether it ends it (ends[id]): a diary goes back to a story left off.
// Only a link one to one: a quest that opens several (or needs several) is a
// prerequisite, not the same story going on.
const succ = new Map<number, Set<number>>(), pred = new Map<number, Set<number>>();
const link = (a: number, b: number) => {
  if (a <= 0 || b <= 0 || a === b) return;
  if (!succ.has(a)) succ.set(a, new Set());
  if (!pred.has(b)) pred.set(b, new Set());
  succ.get(a)!.add(b);
  pred.get(b)!.add(a);
};
const hasWork = new Map<number, boolean>();
for (const r of rows(sql, "quest_template")) {
  const id = r.entry as number;
  link(Math.abs(Number(r.PrevQuestId)), id);
  link(id, Number(r.NextQuestInChain));
  // (work in it: a creature, a thing to fetch, an escort or an event)
  let work = ((r.SpecialFlags as number) & 2) === 2;
  for (let k = 1; k <= 4; k++) {
    if (r[`ReqCreatureOrGOId${k}`]) work = true;
    if (r[`ReqItemId${k}`] && r[`ReqItemId${k}`] !== r.SrcItemId) work = true;
  }
  hasWork.set(id, work);
}
const nextOf = (id: number) => {
  const s = succ.get(id);
  if (!s || s.size !== 1) return undefined;
  const [n] = s;
  return pred.get(n)!.size === 1 ? n : undefined;
};
const prevOf = (id: number) => {
  const p = pred.get(id);
  if (!p || p.size !== 1) return undefined;
  const [x] = p;
  return nextOf(x) === id ? x : undefined;
};
const chains = new Map<number, number>();
for (const id of new Set([...succ.keys(), ...pred.keys()])) {
  if (nextOf(id) === undefined && prevOf(id) === undefined) continue;
  const seen = new Set<number>();
  let x = id;
  while (prevOf(x) !== undefined && !seen.has(x)) {
    seen.add(x);
    x = prevOf(x)!;
  }
  chains.set(id, x);
}
// (a chain's end: its last quest, or the last with work in it before a
// return or a delivery: Athrikus Narassin slain, not the walk back to Delgren)
const idleAfter = (id: number): boolean => {
  const seen = new Set<number>();
  for (let n = nextOf(id); n !== undefined && !seen.has(n); n = nextOf(n)) {
    seen.add(n);
    if (hasWork.get(n)) return false;
  }
  return true;
};
const ends = (id: number) => nextOf(id) === undefined || (hasWork.get(id) === true && idleAfter(id));

// The quest givers and enders by name (as the record knows them): their
// people and calling, their sex (their model's: the writer's "he" or "she")
// and whether they are a beast (who takes nothing "into their hands"); a
// name two creatures share, only what both agree on.
const genderOf = new Map<number, number>();
for (const r of rows(sql, "creature_model_info")) genderOf.set(r.modelid as number, r.gender as number);
const SEX: Record<number, string> = { 0: "male", 1: "female" };
const npcs = new Map<string, { people?: string; role?: string; sex?: string; beast?: boolean }>();
for (const r of rows(sql, "creature_template")) {
  if (!questNpcs.has(r.Entry as number)) continue;
  const name = r.Name as string;
  const people = peopleOf(r.Faction as number, r.ModelId1 as number);
  const role = (r.SubName as string | null) || undefined;
  const sex = SEX[genderOf.get(r.ModelId1 as number) ?? 2];
  const beast = r.CreatureType === 1 || undefined;
  const seen = npcs.get(name);
  if (!seen) npcs.set(name, { people, role, sex, beast });
  else {
    if (seen.people !== people) seen.people = undefined;
    if (seen.role !== role) seen.role = undefined;
    if (seen.sex !== sex) seen.sex = undefined;
    if (seen.beast !== beast) seen.beast = undefined;
  }
}

const q = (s: string) => JSON.stringify(s);
const out = [
  "-- generated by scripts/knowledge.ts from cmangos classic-db (GPL-3.0): do not edit",
  "-- quests[id] = { class, spell, totem }: a class's own quest, the spell it gives, a shaman's element",
  "-- chains[id] = the first quest of its chain; ends[id]: the last of one",
  "local _, ns = ...",
  "local K = { quests = {}, chains = {}, ends = {} }",
  "ns.knowledge = K",
  "local quests, chains, ends = K.quests, K.chains, K.ends",
];
// (the quest givers, for the playthrough alone: .cache/audit/npcs.lua)
const npcLines = ["-- generated by scripts/knowledge.ts: the quest givers' people, calling, sex, a beast", "return {"];
for (const [id, v] of Object.entries(quests).sort((a, b) => Number(a[0]) - Number(b[0])))
  out.push(`quests[${id}] = { class = ${q(v.class!)}${v.spell ? `, spell = ${q(v.spell)}` : ""}${v.totem ? `, totem = ${q(v.totem)}` : ""} }`);
for (const [name, v] of [...npcs].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
  if (!v.people && !v.role && !v.sex && !v.beast) continue;
  const fields = [v.people && `people = ${q(v.people)}`, v.role && `role = ${q(v.role)}`,
    v.sex && `sex = ${q(v.sex)}`, v.beast && "beast = true"].filter(Boolean);
  npcLines.push(`  [${q(name)}] = { ${fields.join(", ")} },`);
}
npcLines.push("}");
writeFileSync(path.join(DIR, "npcs.lua"), npcLines.join("\n") + "\n");
for (const [id, root] of [...chains].sort((a, b) => a[0] - b[0])) {
  out.push(`chains[${id}] = ${root}`);
  if (ends(id)) out.push(`ends[${id}] = true`);
}
writeFileSync(OUT, out.join("\n") + "\n");
console.log(`✓ ${Object.keys(quests).length} class quests, ${chains.size} quests in chains → ${path.relative(process.cwd(), OUT)} (${npcs.size} quest givers → .cache/audit/npcs.lua)`);
