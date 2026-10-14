// The game data the writer's audit reads (addon/test/audit.lua): every creature,
// quest, item, object and place of Classic, from wow-data's Classic Era
// database, reduced to one Lua table in .cache/audit (gitignored).
//   bun scripts/audit-data.ts
// The database's sources (../wow-data): the client's tables (the places, the
// spells), Questie's world (quests, who gives them, where creatures live), the
// Classic database for the rest (cmangos classic-db, GPL-3.0). The names
// themselves are Blizzard's.
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { openDb } from "../../wow-data/src/db";

const DIR = path.join(import.meta.dir, "..", ".cache", "audit");

const lua = (v: unknown): string => {
  if (v === null || v === undefined || v === "") return "nil";
  if (typeof v === "number") return String(v);
  if (typeof v === "boolean") return v ? "true" : "nil";
  if (typeof v === "string") return JSON.stringify(v).replace(/\\u([0-9a-f]{4})/g, (_, h) => `\\u{${h}}`);
  if (Array.isArray(v)) return "{" + v.map(lua).join(",") + "}";
  return (
    "{" +
    Object.entries(v as object)
      .filter(([, x]) => x !== undefined && x !== null && x !== "")
      .map(([k, x]) => `${/^\d+$/.test(k) ? `[${k}]` : k}=${lua(x)}`)
      .join(",") +
    "}"
  );
};

mkdirSync(DIR, { recursive: true });
const db = openDb("classic");
type Row = Record<string, number | string | null>;
const all = (sql: string, ...args: (number | string)[]) => db.query(sql).all(...args) as Row[];
// (a thing's English name, the database's: the client's, Questie's, the Classic database's)
const names = (kind: string) =>
  new Map(all("SELECT id, name FROM name WHERE kind = ? AND locale = 'enUS'", kind).map((r) => [r.id as number, r.name as string]));
const groups = <T>(rows: Row[], key: string, value: (r: Row) => T) => {
  const m = new Map<number, T[]>();
  for (const r of rows) m.set(r[key] as number, [...(m.get(r[key] as number) ?? []), value(r)]);
  return m;
};

// ── creatures ────────────────────────────────────────────────────────────────
const creatureName = names("creature"),
  subName = names("creature_subname");
// (its spawns in the world: the Classic database's, one a guid)
const spawns = new Map(
  all("SELECT entity_id AS id, count(*) AS n FROM spawn WHERE kind = 'creature' AND source = 'classicdb' GROUP BY entity_id").map((r) => [
    r.id as number,
    r.n as number,
  ]),
);
// (a creature's land: the zone most of its spawns are in, as Questie has it;
// else the zone of its first spawn in the world, the smallest zone map
// holding it: the client's UiMapAssignment)
const unitZone = new Map<number, number>();
for (const r of all(
  `SELECT entity_id AS id, area_id AS zone, count(*) AS n FROM spawn WHERE kind = 'creature' AND source = 'questie' AND area_id IS NOT NULL
   GROUP BY entity_id, area_id ORDER BY entity_id, n DESC, area_id`,
))
  if (!unitZone.has(r.id as number)) unitZone.set(r.id as number, r.zone as number);
const worldZone = db.query(
  `SELECT a.AreaID AS zone FROM spawn s JOIN client_UiMapAssignment a ON a.MapID = s.map_id
     AND s.x BETWEEN a.Region_0 AND a.Region_3 AND s.y BETWEEN a.Region_1 AND a.Region_4
   JOIN client_UiMap u ON u.ID = a.UiMapID AND u.Type = 3
   WHERE s.kind = 'creature' AND s.entity_id = ? AND s.source = 'classicdb' AND a.AreaID > 0
   ORDER BY s.rowid, (a.Region_3 - a.Region_0) * (a.Region_4 - a.Region_1) LIMIT 1`,
);
const creatureRows = all("SELECT * FROM creature WHERE removed IS NOT 1 ORDER BY id");
const creatures: Record<number, object> = {};
for (const r of creatureRows) {
  const id = r.id as number;
  creatures[id] = {
    name: creatureName.get(id),
    sub: subName.get(id),
    rank: r.rank,
    type: r.type_id,
    family: r.family_id,
    min: r.min_level,
    max: r.max_level,
    spawns: spawns.get(id) ?? 0,
    npc: r.npc_flags,
    zone: unitZone.get(id) ?? (worldZone.get(id) as { zone: number } | null)?.zone,
  };
}

// ── quests ───────────────────────────────────────────────────────────────────
const relation = (role: string) =>
  groups(
    all("SELECT quest_id, entity_id FROM quest_relation WHERE role = ? AND kind = 'creature' ORDER BY quest_id, entity_id", role),
    "quest_id",
    (r) => r.entity_id as number,
  );
const starters = relation("start"),
  enders = relation("end");
const questName = names("quest");
const questText = new Map<string, string>();
for (const r of all("SELECT quest_id, field, text FROM quest_text WHERE locale = 'enUS'")) questText.set(`${r.quest_id}:${r.field}`, r.text as string);
// what it asks, as the quest log orders it: items, then creatures and objects (an object's id negative, as the game's)
const asked = groups(
  all("SELECT quest_id, kind, target_id, count FROM quest_objective WHERE kind IN ('item', 'creature', 'object') AND idx < 100 ORDER BY quest_id, kind, idx"),
  "quest_id",
  (r) => r,
);
const rewards = groups(
  all("SELECT quest_id, kind, ref_id, count FROM quest_reward WHERE kind IN ('choice', 'item', 'money') ORDER BY quest_id, kind = 'item', rowid"),
  "quest_id",
  (r) => r,
);
const quests: Record<number, object> = {};
for (const r of all("SELECT * FROM quest WHERE removed IS NOT 1 ORDER BY id")) {
  const id = r.id as number;
  const items: number[][] = [],
    targets: number[][] = [];
  for (const o of asked.get(id) ?? []) {
    if (o.kind === "item") items.push([o.target_id as number, (o.count as number) ?? 1]);
    else targets.push([(o.kind === "object" ? -1 : 1) * (o.target_id as number), (o.count as number) ?? 1]);
  }
  const texts = [1, 2, 3, 4].map((k) => questText.get(`${id}:objective${k}`) ?? "");
  const given = (rewards.get(id) ?? []).filter((w) => w.kind !== "money").map((w) => w.ref_id as number);
  const money = (rewards.get(id) ?? []).find((w) => w.kind === "money")?.count;
  const special = (r.special_flags as number) ?? 0;
  quests[id] = {
    title: questName.get(id),
    objectives: questText.get(`${id}:objectives`),
    texts,
    items,
    targets,
    src: r.src_item_id,
    classes: r.classes,
    rewards: given,
    money,
    repeatable: (special & 1) === 1 || null,
    // (an escort or an event: the game says when it is done, no objective counts it)
    event: ((special & 2) === 2 && items.length === 0 && targets.length === 0) || null,
    zone: r.zone_id ?? (r.sort_id ? -(r.sort_id as number) : null),
    min: r.min_level,
    level: r.level,
    races: r.races,
    prev: r.prev_id,
    next: r.next_in_chain,
    // (one quest of a group only: Volcor's escape through stealth or through force)
    exclusive: r.exclusive_group,
    starters: starters.get(id),
    enders: enders.get(id),
  };
}

// ── items and objects ────────────────────────────────────────────────────────
const itemName = names("item");
const items: Record<number, object> = {};
for (const r of all("SELECT * FROM item WHERE removed IS NOT 1 ORDER BY id"))
  items[r.id as number] = {
    name: itemName.get(r.id as number),
    quality: r.quality,
    class: r.class_id,
    sub: r.subclass_id,
    slot: r.inventory_type,
    classes: r.allowable_class,
    req: r.required_level || null,
  };
const objectName = names("object");
const objects: Record<number, string> = {};
const chests = new Map<number, number[]>(); // loot id = the objects that hold it
for (const r of all("SELECT id, type, loot_id FROM object WHERE removed IS NOT 1 ORDER BY id")) {
  const name = objectName.get(r.id as number);
  if (name) objects[r.id as number] = name;
  if (r.type === 3 && r.loot_id) chests.set(r.loot_id as number, [...(chests.get(r.loot_id as number) ?? []), r.id as number]);
}

// Where a quest's item comes from: the creatures that drop it (as a quest
// drop), else the objects that hold it. (A loot row of the Classic database
// names a loot template, one of Questie's the creature or object itself.)
const lootOf = groups(
  all("SELECT id, loot_id FROM creature WHERE loot_id IS NOT NULL ORDER BY id"),
  "loot_id",
  (r) => r.id as number,
);
const wanted = new Set(Object.values(quests).flatMap((q) => (q as { items: number[][] }).items.map(([id]) => id)));
const sources: Record<number, { creatures?: number[]; objects?: number[] }> = {};
const add = (item: number, key: "creatures" | "objects", ids: number[]) => {
  const s = (sources[item] ??= {});
  s[key] = [...new Set([...(s[key] ?? []), ...ids])];
};
for (const r of all("SELECT item_id, source_id, source FROM loot WHERE kind = 'creature' AND item_id IS NOT NULL ORDER BY rowid")) {
  if (!wanted.has(r.item_id as number)) continue;
  add(r.item_id as number, "creatures", r.source === "questie" ? [r.source_id as number] : (lootOf.get(r.source_id as number) ?? []));
}
for (const r of all("SELECT item_id, source_id, source FROM loot WHERE kind = 'object' AND item_id IS NOT NULL ORDER BY rowid")) {
  if (!wanted.has(r.item_id as number) || sources[r.item_id as number]?.creatures) continue;
  add(r.item_id as number, "objects", r.source === "questie" ? [r.source_id as number] : (chests.get(r.source_id as number) ?? []));
}

// A class trainer's lessons, by the level they open at: class = { [level] =
// { spell, ... } } (a lesson's spell teaches another: the one taught, the
// client's own SpellEffect, Effect 36; a new spell only: a rank of one known,
// or of a talent, needs it first)
const CLASS_IDS: Record<number, string> = { 1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST", 7: "SHAMAN", 8: "MAGE", 9: "WARLOCK", 11: "DRUID" };
const spellName = new Map(all("SELECT ID, Name_lang FROM client_SpellName").map((r) => [r.ID as number, r.Name_lang as string]));
const teaches = new Map<number, number>();
for (const r of all("SELECT SpellID, EffectTriggerSpell FROM client_SpellEffect WHERE Effect = 36 AND EffectTriggerSpell > 0 ORDER BY SpellID, EffectIndex"))
  if (!teaches.has(r.SpellID as number)) teaches.set(r.SpellID as number, r.EffectTriggerSpell as number);
const lessons: Record<string, Record<number, string[]>> = {};
for (const r of all(
  `SELECT c.trainer_class AS class, t.spell_id AS spell, t.level FROM trainer_spell t JOIN creature c ON c.id = t.npc_id
   WHERE c.trainer_type = 0 AND t.level > 0 AND t.req_spell_id IS NULL ORDER BY c.trainer_class, t.level, t.npc_id, t.rowid`,
)) {
  const cls = CLASS_IDS[r.class as number];
  const spell = spellName.get(teaches.get(r.spell as number) ?? (r.spell as number));
  if (!cls || !spell) continue;
  const byLevel = (lessons[cls] ??= {});
  const list = (byLevel[r.level as number] ??= []);
  if (!list.includes(spell)) list.push(spell);
}

// The places (the client's areas, its placeholders and tests left out) and
// the land each lies in (its zone): parents[area] = zone.
const zones: Record<number, string> = {};
const parents: Record<number, number> = {};
for (const a of all("SELECT ID, AreaName_lang, ParentAreaID FROM client_AreaTable ORDER BY ID")) {
  const name = String(a.AreaName_lang ?? "").trim();
  if (name && !/UNUSED|^Jeff |TEST|DELETE|Delete ME|Test|\*\*\*|^GM |Programmer|Designer|Not Used/.test(name)) zones[Number(a.ID)] = name;
  if (Number(a.ParentAreaID) > 0) parents[Number(a.ID)] = Number(a.ParentAreaID);
}

// (in chunks: a Lua function holds at most 65536 constants)
const out = [
  "-- generated by scripts/audit-data.ts: do not edit",
  "local D = { creatures = {}, quests = {}, items = {}, objects = {}, zones = {}, sources = {}, parents = {}, lessons = {} }",
];
for (const [name, table] of Object.entries({ creatures, quests, items, objects, zones, sources, parents, lessons })) {
  const entries = Object.entries(table);
  for (let i = 0; i < entries.length; i += 1000) {
    out.push(`;(function(t)`);
    for (const [id, v] of entries.slice(i, i + 1000)) out.push(`t[${/^\d+$/.test(id) ? id : JSON.stringify(id)}]=${lua(v)}`);
    out.push(`end)(D.${name})`);
  }
}
out.push("return D");

// The items Classic Era's world hands out (dropped, sold, asked or given by a
// quest, made by a trade, worn by a new character): the names' corpus counts
// these, not the client's every item (Season of Discovery's people would pass
// for roles: "a Dalton's Horn").
const met = new Set(
  all(
    `SELECT item_id AS id FROM loot WHERE item_id IS NOT NULL UNION SELECT item_id FROM vendor
     UNION SELECT target_id FROM quest_objective WHERE kind IN ('item', 'source')
     UNION SELECT ref_id FROM quest_reward WHERE kind IN ('item', 'choice') UNION SELECT src_item_id FROM quest WHERE src_item_id IS NOT NULL
     UNION SELECT EffectItemType FROM client_SpellEffect WHERE Effect = 24 AND EffectItemType > 0
     UNION SELECT ItemID_0 FROM client_CharStartOutfit UNION SELECT ItemID_1 FROM client_CharStartOutfit UNION SELECT ItemID_2 FROM client_CharStartOutfit UNION SELECT ItemID_3 FROM client_CharStartOutfit UNION SELECT ItemID_4 FROM client_CharStartOutfit UNION SELECT ItemID_5 FROM client_CharStartOutfit UNION SELECT ItemID_6 FROM client_CharStartOutfit UNION SELECT ItemID_7 FROM client_CharStartOutfit UNION SELECT ItemID_8 FROM client_CharStartOutfit UNION SELECT ItemID_9 FROM client_CharStartOutfit UNION SELECT ItemID_10 FROM client_CharStartOutfit UNION SELECT ItemID_11 FROM client_CharStartOutfit UNION SELECT ItemID_12 FROM client_CharStartOutfit UNION SELECT ItemID_13 FROM client_CharStartOutfit UNION SELECT ItemID_14 FROM client_CharStartOutfit UNION SELECT ItemID_15 FROM client_CharStartOutfit UNION SELECT ItemID_16 FROM client_CharStartOutfit UNION SELECT ItemID_17 FROM client_CharStartOutfit UNION SELECT ItemID_18 FROM client_CharStartOutfit UNION SELECT ItemID_19 FROM client_CharStartOutfit UNION SELECT ItemID_20 FROM client_CharStartOutfit UNION SELECT ItemID_21 FROM client_CharStartOutfit UNION SELECT ItemID_22 FROM client_CharStartOutfit UNION SELECT ItemID_23 FROM client_CharStartOutfit`,
  ).map((r) => r.id as number),
);

// The game's own writing (quest texts, what creatures say), for the names'
// articles (scripts/names.ts): one text a line.
const corpus: string[] = [];
for (const [id, title] of [...questName].sort((a, b) => a[0] - b[0])) {
  corpus.push(title);
  for (const f of ["details", "objectives", "reward", "request", "end"]) {
    const t = questText.get(`${id}:${f}`);
    if (t) corpus.push(t);
  }
}
for (const r of all("SELECT text, text_female FROM speech WHERE locale = 'enUS' ORDER BY id"))
  for (const t of [r.text, r.text_female]) if (t) corpus.push(t as string);
writeFileSync(path.join(DIR, "corpus.txt"), corpus.map((t) => t.replace(/\s+/g, " ")).join("\n"));
writeFileSync(
  path.join(DIR, "names.json"),
  JSON.stringify({
    zones: Object.values(zones),
    creatures: Object.values(creatures).map((c) => c as { name: string; spawns: number; npc: number; sub?: string }),
    items: Object.entries(items)
      .filter(([id]) => met.has(Number(id)))
      .map(([, i]) => (i as { name: string }).name),
    // the creatures who give quests or take them back
    questNpcs: [
      ...new Set(
        [...starters.values(), ...enders.values()]
          .flat()
          .map((id) => (creatures[id] as { name?: string } | undefined)?.name)
          .filter(Boolean),
      ),
    ],
    // quest items asked for, and the most of each asked (its plural, when more than one)
    questItems: Object.entries(
      Object.values(quests)
        .flatMap((q) => (q as { items: number[][] }).items)
        .reduce((m, [id, n]) => ({ ...m, [id]: Math.max(m[id] ?? 0, n) }), {} as Record<number, number>),
    )
      .map(([id, n]) => ({ name: (items[Number(id)] as { name: string } | undefined)?.name, most: n }))
      .filter((i) => i.name),
  }),
);
writeFileSync(path.join(DIR, "game.lua"), out.join("\n"));
console.log(
  `✓ ${Object.keys(creatures).length} creatures, ${Object.keys(quests).length} quests, ${Object.keys(items).length} items, ` +
    `${Object.keys(objects).length} objects, ${Object.keys(zones).length} places → .cache/audit/game.lua`,
);
console.log(`✓ ${corpus.length} texts of the game's own writing → .cache/audit/corpus.txt`);
