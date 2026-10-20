// What the game itself knows and the record doesn't, for the writer: which
// quests belong to a class and the spell they give ("Beginnings": a warlock's
// first imp), and who the quest givers are: their people (by their model's
// race, from the client's own tables, or the faction they serve where it is
// one people's own: Gnomeregan's gnomes, Darnassus's night elves...) and
// their calling ("Warlock Trainer"). From wow-data's Classic Era database
// (../wow-data), into addon/Hearthtale/Knowledge.lua.
//   bun scripts/knowledge.ts
import { writeFileSync } from "node:fs";
import path from "node:path";
import type * as WowDb from "../../wow-data/src/db";
import { familyPath } from "./root";

// through the family folder, from a worktree too (scripts/root.ts)
const { openDb } = (await import(familyPath("wow-data", "src", "db.ts"))) as typeof WowDb;

const DIR = path.join(import.meta.dir, "..", ".cache", "audit");
const OUT = path.join(import.meta.dir, "..", "addon", "Hearthtale", "Knowledge.lua");
const db = openDb("classic");
type Row = Record<string, number | string | null>;
const all = (sql: string, ...args: (number | string)[]) => db.query(sql).all(...args) as Row[];

// The race of a creature's model, from the client's own tables (Classic Era's,
// one build pinned): what a person is when their faction serves several
// peoples (Stormwind's, Orgrimmar's) or another's (the gnomes who serve
// Ironforge); and its sex (the client's: the writer's "he" or "she").
const RACE: Record<string, string> = { 1: "Human", 2: "Orc", 3: "Dwarf", 4: "NightElf", 5: "Scourge", 6: "Tauren", 7: "Gnome", 8: "Troll" };
const model = new Map<number, { race?: string; gender: number }>();
for (const r of all(
  `SELECT d.ID, d.Gender, x.DisplayRaceID FROM client_CreatureDisplayInfo d
   LEFT JOIN client_CreatureDisplayInfoExtra x ON x.ID = d.ExtendedDisplayInfoID`,
))
  model.set(r.ID as number, { race: RACE[String(r.DisplayRaceID ?? "")], gender: r.Gender as number });
const raceOf = (display: number) => model.get(display)?.race;

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

const spellName = new Map(all("SELECT ID, Name_lang FROM client_SpellName").map((r) => [r.ID as number, r.Name_lang as string]));
// (a spell that teaches another: the one taught, the first of several: Bear
// Form, not the Growl and Maul taught with it: the client's SpellEffect, Effect 36)
const teaches = new Map<number, number>();
for (const r of all("SELECT SpellID, EffectTriggerSpell FROM client_SpellEffect WHERE Effect = 36 AND EffectTriggerSpell > 0 ORDER BY SpellID, EffectIndex"))
  if (!teaches.has(r.SpellID as number)) teaches.set(r.SpellID as number, r.EffectTriggerSpell as number);

const questNpcs = new Set(all("SELECT DISTINCT entity_id FROM quest_relation WHERE kind = 'creature'").map((r) => r.entity_id as number));

// (a shaman's initiation into an element: its totem, given at the end)
const TOTEMS: Record<number, string> = { 5175: "earth", 5176: "fire", 5177: "water", 5178: "air" };
const rewards = new Map<number, Row[]>();
for (const r of all("SELECT quest_id, kind, ref_id FROM quest_reward WHERE kind IN ('spell', 'cast', 'item') ORDER BY quest_id, rowid"))
  rewards.set(r.quest_id as number, [...(rewards.get(r.quest_id as number) ?? []), r]);
const questRows = all("SELECT id, classes, prev_id, next_in_chain, special_flags, src_item_id FROM quest WHERE removed IS NOT 1 ORDER BY id");
const quests: Record<number, { class?: string; spell?: string; totem?: string }> = {};
for (const r of questRows) {
  const mask = (r.classes as number) ?? 0;
  const classes = CLASSES.filter(([bit]) => mask & bit).map(([, c]) => c);
  const given = rewards.get(r.id as number) ?? [];
  const of = (kind: string) => given.find((g) => g.kind === kind)?.ref_id as number | undefined;
  // (a spell taught, not one cast on me as a reward; riding is a skill)
  const taught = teaches.get(of("cast") ?? 0) ?? teaches.get(of("spell") ?? 0);
  const spell = taught ? spellName.get(taught) : undefined;
  const q: { class?: string; spell?: string; totem?: string } = {};
  if (classes.length === 1) q.class = classes[0];
  if (q.class && spell && spell !== "Riding") q.spell = spell;
  for (const g of given) if (g.kind === "item" && TOTEMS[g.ref_id as number]) q.totem = TOTEMS[g.ref_id as number];
  if (q.class) quests[r.id as number] = q;
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
const asked = new Map<number, Row[]>();
for (const r of all("SELECT quest_id, kind, target_id FROM quest_objective WHERE kind IN ('creature', 'object', 'item') AND idx < 100"))
  asked.set(r.quest_id as number, [...(asked.get(r.quest_id as number) ?? []), r]);
for (const r of questRows) {
  const id = r.id as number;
  link(Math.abs(Number(r.prev_id ?? 0)), id);
  link(id, Number(r.next_in_chain ?? 0));
  // (work in it: a creature, a thing to fetch, an escort or an event)
  let work = (((r.special_flags as number) ?? 0) & 2) === 2;
  for (const o of asked.get(id) ?? []) {
    if (o.kind !== "item") work = true;
    else if (o.target_id !== r.src_item_id) work = true;
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
const SEX: Record<number, string> = { 0: "male", 1: "female" };
const creatureName = new Map(all("SELECT id, name FROM name WHERE kind = 'creature' AND locale = 'enUS'").map((r) => [r.id as number, r.name as string]));
const subName = new Map(all("SELECT id, name FROM name WHERE kind = 'creature_subname' AND locale = 'enUS'").map((r) => [r.id as number, r.name as string]));
const npcs = new Map<string, { people?: string; role?: string; sex?: string; beast?: boolean }>();
for (const r of all("SELECT id, faction_id, display_ids, type_id FROM creature WHERE removed IS NOT 1 ORDER BY id")) {
  if (!questNpcs.has(r.id as number)) continue;
  const name = creatureName.get(r.id as number);
  if (!name) continue;
  const display = Number(String(r.display_ids ?? "").split(",")[0]) || 0;
  const people = peopleOf((r.faction_id as number) ?? 0, display);
  const role = subName.get(r.id as number) || undefined;
  const sex = SEX[model.get(display)?.gender ?? 2];
  const beast = r.type_id === 1 || undefined;
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
  "-- generated by scripts/knowledge.ts from wow-data's Classic Era database: do not edit",
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
