// The game data the writer's audit reads (addon/test/audit.lua): every creature,
// quest, item, object and place of Classic, from open databases, downloaded into
// .cache/audit (gitignored) and reduced to one Lua table.
//   bun scripts/audit-data.ts
// Sources (wow-data's): cmangos classic-db (GPL-3.0) for creatures, quests,
// items and objects; the client's AreaTable for the places; Questie's zones
// for where each creature lives. The names themselves are Blizzard's.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";
import { openDb } from "../../wow-data/src/db";
import { classicDump } from "../../wow-data/src/github";
import path from "node:path";
import { rows } from "./sql";

const DIR = path.join(import.meta.dir, "..", ".cache", "audit");


const lua = (v: unknown): string => {
  if (v === null || v === undefined || v === "") return "nil";
  if (typeof v === "number") return String(v);
  if (typeof v === "boolean") return v ? "true" : "nil";
  if (typeof v === "string") return JSON.stringify(v).replace(/\\u([0-9a-f]{4})/g, (_, h) => `\\u{${h}}`);
  if (Array.isArray(v)) return "{" + v.map(lua).join(",") + "}";
  return "{" + Object.entries(v as object).filter(([, x]) => x !== undefined && x !== null && x !== "")
    .map(([k, x]) => `${/^\d+$/.test(k) ? `[${k}]` : k}=${lua(x)}`).join(",") + "}";
};

mkdirSync(DIR, { recursive: true });
// (wow-data: the pinned sources) the Classic database (cmangos classic-db)
// and Classic Era's database: the client's areas (the places, the land each
// lies in: Coldridge Valley in Dun Morogh), and where every creature lives
const dump = await classicDump();
const db = openDb("classic");
const sql = gunzipSync(readFileSync(dump)).toString("utf8");

const spawns = new Map<number, number>();
for (const r of rows(sql, "creature")) spawns.set(r.id as number, (spawns.get(r.id as number) ?? 0) + 1);
// (a creature's land: the zone most of its spawns are in, as Questie has it;
// else the zone of its first spawn in the world, the smallest zone map
// holding it: the client's UiMapAssignment)
const unitZone = new Map<number, number>();
for (const r of db
  .query(
    `SELECT entity_id AS id, area_id AS zone, count(*) AS n FROM spawn WHERE kind = 'creature' AND source = 'questie' AND area_id IS NOT NULL
     GROUP BY entity_id, area_id ORDER BY entity_id, n DESC, area_id`,
  )
  .all() as { id: number; zone: number }[])
  if (!unitZone.has(r.id)) unitZone.set(r.id, r.zone);
const worldZone = db.query(
  `SELECT a.AreaID AS zone FROM spawn s JOIN client_UiMapAssignment a ON a.MapID = s.map_id
     AND s.x BETWEEN a.Region_0 AND a.Region_3 AND s.y BETWEEN a.Region_1 AND a.Region_4
   JOIN client_UiMap u ON u.ID = a.UiMapID AND u.Type = 3
   WHERE s.kind = 'creature' AND s.entity_id = ? AND s.source = 'classicdb' AND a.AreaID > 0
   ORDER BY s.rowid, (a.Region_3 - a.Region_0) * (a.Region_4 - a.Region_1) LIMIT 1`,
);
const creatures: Record<number, object> = {};
for (const r of rows(sql, "creature_template")) {
  creatures[r.Entry as number] = { name: r.Name, sub: r.SubName, rank: r.Rank, type: r.CreatureType, family: r.Family,
    min: r.MinLevel, max: r.MaxLevel, spawns: spawns.get(r.Entry as number) ?? 0, npc: r.NpcFlags,
    zone: unitZone.get(r.Entry as number) ?? (worldZone.get(r.Entry as number) as { zone: number } | null)?.zone };
}
const starters = new Map<number, number[]>(), enders = new Map<number, number[]>();
for (const [table, map] of [["creature_questrelation", starters], ["creature_involvedrelation", enders]] as const)
  for (const r of rows(sql, table)) map.set(r.quest as number, [...(map.get(r.quest as number) ?? []), r.id as number]);
const quests: Record<number, object> = {};
for (const r of rows(sql, "quest_template")) {
  const items = [], targets = [], texts = [];
  for (let k = 1; k <= 4; k++) {
    if (r[`ReqItemId${k}`]) items.push([r[`ReqItemId${k}`], r[`ReqItemCount${k}`]]);
    if (r[`ReqCreatureOrGOId${k}`]) targets.push([r[`ReqCreatureOrGOId${k}`], r[`ReqCreatureOrGOCount${k}`]]);
    texts.push(r[`ObjectiveText${k}`] ?? "");
  }
  const rewards = [];
  for (let k = 1; k <= 6; k++) if (r[`RewChoiceItemId${k}`]) rewards.push(r[`RewChoiceItemId${k}`]);
  for (let k = 1; k <= 4; k++) if (r[`RewItemId${k}`]) rewards.push(r[`RewItemId${k}`]);
  quests[r.entry as number] = { title: r.Title, objectives: r.Objectives, texts, items, targets, src: r.SrcItemId || null,
    classes: r.RequiredClasses || null, rewards, money: (r.RewOrReqMoney as number) > 0 ? r.RewOrReqMoney : null,
    repeatable: ((r.SpecialFlags as number) & 1) === 1 || null,
    // (an escort or an event: the game says when it is done, no objective counts it)
    event: ((r.SpecialFlags as number) & 2) === 2 && items.length === 0 && targets.length === 0 || null,
    zone: r.ZoneOrSort, min: r.MinLevel, level: r.QuestLevel, races: r.RequiredRaces, prev: r.PrevQuestId || null,
    next: r.NextQuestInChain || null,
    // (one quest of a group only: Volcor's escape through stealth or through force)
    exclusive: (r.ExclusiveGroup as number) > 0 ? r.ExclusiveGroup : null, starters: starters.get(r.entry as number), enders: enders.get(r.entry as number) };
}
const items: Record<number, object> = {};
for (const r of rows(sql, "item_template"))
  items[r.entry as number] = { name: r.name, quality: r.Quality, class: r.class, sub: r.subclass, slot: r.InventoryType,
    classes: (r.AllowableClass as number) > 0 && (r.AllowableClass as number) !== 32767 ? r.AllowableClass : null, req: r.RequiredLevel || null };
const objects: Record<number, string> = {};
const chests = new Map<number, number[]>(); // loot id = the objects that hold it
for (const r of rows(sql, "gameobject_template")) {
  objects[r.entry as number] = r.name as string;
  if (r.type === 3 && r.data1) chests.set(r.data1 as number, [...(chests.get(r.data1 as number) ?? []), r.entry as number]);
}
// Where a quest's item comes from: the creatures that drop it (as a quest
// drop), else the objects that hold it.
const lootOf = new Map<number, number[]>();
for (const r of rows(sql, "creature_template")) if (r.LootId) lootOf.set(r.LootId as number, [...(lootOf.get(r.LootId as number) ?? []), r.Entry as number]);
const wanted = new Set(Object.values(quests).flatMap((q) => (q as { items: number[][] }).items.map(([id]) => id)));
const sources: Record<number, { creatures?: number[]; objects?: number[] }> = {};
for (const r of rows(sql, "creature_loot_template")) {
  if (!wanted.has(r.item as number)) continue;
  const s = (sources[r.item as number] ??= {});
  s.creatures = [...new Set([...(s.creatures ?? []), ...(lootOf.get(r.entry as number) ?? [])])];
}
for (const r of rows(sql, "gameobject_loot_template")) {
  if (!wanted.has(r.item as number) || sources[r.item as number]?.creatures) continue;
  const s = (sources[r.item as number] ??= {});
  s.objects = [...new Set([...(s.objects ?? []), ...(chests.get(r.entry as number) ?? [])])];
}
// A class trainer's lessons, by the level they open at: class = { [level] = { spell, ... } }
// (a trainer's spell teaches another: the one taught, as knowledge.ts reads it)
const CLASS_IDS: Record<number, string> = { 1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST", 7: "SHAMAN", 8: "MAGE", 9: "WARLOCK", 11: "DRUID" };
const spellName = new Map<number, string>();
const teaches = new Map<number, number>();
for (const r of rows(sql, "spell_template")) {
  spellName.set(r.Id as number, r.SpellName as string);
  for (const k of [1, 2, 3]) if (r[`Effect${k}`] === 36 && r[`EffectTriggerSpell${k}`]) teaches.set(r.Id as number, r[`EffectTriggerSpell${k}`] as number);
}
const templateClass = new Map<number, string>();
for (const r of rows(sql, "creature_template"))
  if (r.TrainerType === 0 && CLASS_IDS[r.TrainerClass as number] && r.TrainerTemplateId) templateClass.set(r.TrainerTemplateId as number, CLASS_IDS[r.TrainerClass as number]);
const lessons: Record<string, Record<number, string[]>> = {};
for (const r of rows(sql, "npc_trainer_template")) {
  const cls = templateClass.get(r.entry as number);
  const spell = spellName.get(teaches.get(r.spell as number) ?? (r.spell as number));
  // (a new spell only: a rank of one known, or of a talent, needs it first)
  if (!cls || !spell || !(r.reqlevel as number) || (r.ReqAbility1 as number)) continue;
  const byLevel = (lessons[cls] ??= {});
  const list = (byLevel[r.reqlevel as number] ??= []);
  if (!list.includes(spell)) list.push(spell);
}
// The places (the client's areas, its placeholders and tests left out) and
// the land each lies in (its zone): parents[area] = zone.
const zones: Record<number, string> = {};
const parents: Record<number, number> = {};
for (const a of db.query("SELECT ID, AreaName_lang, ParentAreaID FROM client_AreaTable ORDER BY ID").all() as Record<string, number | string>[]) {
  const name = String(a.AreaName_lang ?? "").trim();
  if (name && !/UNUSED|^Jeff |TEST|DELETE|Delete ME|Test|\*\*\*|^GM |Programmer|Designer|Not Used/.test(name)) zones[Number(a.ID)] = name;
  if (Number(a.ParentAreaID) > 0) parents[Number(a.ID)] = Number(a.ParentAreaID);
}

// (in chunks: a Lua function holds at most 65536 constants)
const out = ["-- generated by scripts/audit-data.ts: do not edit",
  "local D = { creatures = {}, quests = {}, items = {}, objects = {}, zones = {}, sources = {}, parents = {}, lessons = {} }"];
for (const [name, table] of Object.entries({ creatures, quests, items, objects, zones, sources, parents, lessons })) {
  const entries = Object.entries(table);
  for (let i = 0; i < entries.length; i += 1000) {
    out.push(`;(function(t)`);
    for (const [id, v] of entries.slice(i, i + 1000)) out.push(`t[${/^\d+$/.test(id) ? id : JSON.stringify(id)}]=${lua(v)}`);
    out.push(`end)(D.${name})`);
  }
}
out.push("return D");

// The game's own writing (quest texts, what creatures say), for the names'
// articles (scripts/names.ts): one text a line.
const corpus: string[] = [];
for (const r of rows(sql, "quest_template"))
  for (const f of ["Title", "Details", "Objectives", "OfferRewardText", "RequestItemsText", "EndText"]) if (r[f]) corpus.push(r[f] as string);
for (const r of rows(sql, "broadcast_text")) for (const f of ["Text", "Text1"]) if (r[f]) corpus.push(r[f] as string);
writeFileSync(path.join(DIR, "corpus.txt"), corpus.map((t) => t.replace(/\s+/g, " ")).join("\n"));
writeFileSync(path.join(DIR, "names.json"), JSON.stringify({
  zones: Object.values(zones),
  creatures: Object.values(creatures).map((c) => c as { name: string; spawns: number; npc: number; sub?: string }),
  items: Object.values(items).map((i) => (i as { name: string }).name),
  // the creatures who give quests or take them back
  questNpcs: [...new Set([...starters.values(), ...enders.values()].flat()
    .map((id) => (creatures[id] as { name?: string } | undefined)?.name).filter(Boolean))],
  // quest items asked for, and the most of each asked (its plural, when more than one)
  questItems: Object.entries(Object.values(quests).flatMap((q) => (q as { items: number[][] }).items)
    .reduce((m, [id, n]) => ({ ...m, [id]: Math.max(m[id] ?? 0, n) }), {} as Record<number, number>))
    .map(([id, n]) => ({ name: (items[Number(id)] as { name: string } | undefined)?.name, most: n })).filter((i) => i.name),
}));
writeFileSync(path.join(DIR, "game.lua"), out.join("\n"));
console.log(`✓ ${Object.keys(creatures).length} creatures, ${Object.keys(quests).length} quests, ${Object.keys(items).length} items, ` +
  `${Object.keys(objects).length} objects, ${Object.keys(zones).length} places → .cache/audit/game.lua`);
console.log(`✓ ${corpus.length} texts of the game's own writing → .cache/audit/corpus.txt`);
