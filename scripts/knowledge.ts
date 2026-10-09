// What the game itself knows and the record doesn't, for the writer: which
// quests belong to a class and the spell they give ("Beginnings": a warlock's
// first imp), and who the quest givers are: their people (by the faction they
// serve, where it is one people's own: Gnomeregan's gnomes, Darnassus's night
// elves...) and their calling ("Warlock Trainer"). From the classic-db dump
// in .cache/audit (`bun scripts/audit-data.ts`), into
// addon/Hearthtale/Knowledge.lua.
//   bun scripts/knowledge.ts
import { readFileSync, writeFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";
import path from "node:path";
import { rows } from "./sql";

const DIR = path.join(import.meta.dir, "..", ".cache", "audit");
const OUT = path.join(import.meta.dir, "..", "addon", "Hearthtale", "Knowledge.lua");
const sql = gunzipSync(readFileSync(path.join(DIR, "classicdb.sql.gz"))).toString("utf8");

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

const quests: Record<number, { class?: string; spell?: string }> = {};
for (const r of rows(sql, "quest_template")) {
  const mask = r.RequiredClasses as number;
  const classes = CLASSES.filter(([bit]) => mask & bit).map(([, c]) => c);
  // (a spell taught, not one cast on me as a reward; riding is a skill)
  const taught = teaches.get(r.RewSpellCast as number) ?? teaches.get(r.RewSpell as number);
  const spell = taught ? spellName.get(taught) : undefined;
  const q: { class?: string; spell?: string } = {};
  if (classes.length === 1) q.class = classes[0];
  if (q.class && spell && spell !== "Riding") q.spell = spell;
  if (q.class) quests[r.entry as number] = q;
}

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
  const people = PEOPLE[r.Faction as number];
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

// The creatures a quest's item drops from, by the item's name ("Tough Wolf
// Meat": the wolves of Coldridge Valley), so the kills it took are told as
// the hunt for it. (At most MAX_DROPS: an item every creature drops says
// nothing about the hunt.)
const MAX_DROPS = 12;
const wanted = new Set<number>();
for (const r of rows(sql, "quest_template")) for (const k of [1, 2, 3, 4]) if (r[`ReqItemId${k}`]) wanted.add(r[`ReqItemId${k}`] as number);
const itemName = new Map<number, string>();
for (const r of rows(sql, "item_template")) if (wanted.has(r.entry as number)) itemName.set(r.entry as number, r.name as string);
const lootOf = new Map<number, string[]>();
for (const r of rows(sql, "creature_template"))
  if (r.LootId) lootOf.set(r.LootId as number, [...(lootOf.get(r.LootId as number) ?? []), r.Name as string]);
const drops = new Map<string, Set<string>>();
for (const r of rows(sql, "creature_loot_template")) {
  const name = itemName.get(r.item as number);
  if (!name) continue;
  const set = drops.get(name) ?? new Set<string>();
  for (const c of lootOf.get(r.entry as number) ?? []) set.add(c);
  drops.set(name, set);
}

const q = (s: string) => JSON.stringify(s);
const out = [
  "-- generated by scripts/knowledge.ts from cmangos classic-db (GPL-3.0): do not edit",
  "-- quests[id] = { class, spell }: a class's own quest and the spell it gives",
  "-- npcs[name] = { people, role, sex, beast }: a quest giver's people, calling, sex, a beast",
  "-- drops[item] = { creature, ... }: the creatures a quest's item drops from",
  "local _, ns = ...",
  "local K = { quests = {}, npcs = {}, drops = {} }",
  "ns.knowledge = K",
  "local quests, npcs, drops = K.quests, K.npcs, K.drops",
];
for (const [id, v] of Object.entries(quests).sort((a, b) => Number(a[0]) - Number(b[0])))
  out.push(`quests[${id}] = { class = ${q(v.class!)}${v.spell ? `, spell = ${q(v.spell)}` : ""} }`);
for (const [name, v] of [...npcs].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
  if (!v.people && !v.role && !v.sex && !v.beast) continue;
  const fields = [v.people && `people = ${q(v.people)}`, v.role && `role = ${q(v.role)}`,
    v.sex && `sex = ${q(v.sex)}`, v.beast && "beast = true"].filter(Boolean);
  out.push(`npcs[${q(name)}] = { ${fields.join(", ")} }`);
}
let dropped = 0;
for (const [item, set] of [...drops].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
  if (set.size === 0 || set.size > MAX_DROPS) continue;
  out.push(`drops[${q(item)}] = { ${[...set].sort().map(q).join(", ")} }`);
  dropped++;
}
writeFileSync(OUT, out.join("\n") + "\n");
console.log(`✓ ${Object.keys(quests).length} class quests, ${npcs.size} quest givers, ${dropped} quest items' sources → ${path.relative(process.cwd(), OUT)}`);
