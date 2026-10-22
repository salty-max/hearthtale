// WoW Forever's own content (Zephras Isle, its new quests in the old lands,
// its new dungeons), for the Forever package and its tests: the game data
// the Forever playthrough reads (.cache/audit/game-forever.lua, beside
// Classic's game.lua), the names and texts scripts/names.ts reads for
// Forever's names, and the writer's knowledge of it (addon/Hearthtale/
// Forever.lua, with the names from names.ts). Classic's files are untouched.
//   bun scripts/forever-data.ts        (after scripts/audit-data.ts)
// Sources: wow-data's databases (../wow-data, the pinned builds and commits):
//   - Forever's: the client's tables (places, items, which quests exist),
//     Questie's Forever (its recorder's traces of the beta, merged: quests,
//     their givers, enders, levels, sides, classes, prerequisites and
//     objectives; creatures and where they live; what drops a quest's
//     items), its own quests' rewards (AllTheThings', frozen there);
//   - Classic Era's: the old world's places; the Classic database's dump
//     (as Knowledge.lua's and Names.lua's): what the old world already has.
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { decide, list, plainName } from "./names";
import type * as WowDb from "../../wow-data/src/db";
import type * as WowPins from "../../wow-data/src/pins";
import { familyPath } from "./root";

// through the family folder, from a worktree too (scripts/root.ts)
const { openDb } = (await import(familyPath("wow-data", "src", "db.ts"))) as typeof WowDb;
const { FOREVER } = (await import(familyPath("wow-data", "src", "pins.ts"))) as typeof WowPins;

const ROOT = path.join(import.meta.dir, "..");
const AUDIT = path.join(ROOT, ".cache", "audit");
// (the pins: ../wow-data/pins.json)
export const BUILD = FOREVER.build;


const fdb = openDb("forever"), cdb = openDb("classic");
type Row = Record<string, string>;
// a client table of Forever's, each value as text (as its CSV had them)
function table(name: string): Row[] {
  return (fdb.query(`SELECT * FROM "client_${name}" ORDER BY rowid`).all() as Record<string, unknown>[]).map((r) =>
    Object.fromEntries(Object.entries(r).map(([k, v]) => [k, v == null ? "" : String(v)])),
  );
}
const all = <T,>(db: typeof fdb, sql: string, ...p: (string | number)[]) => db.query(sql).all(...p) as T[];

const areas = table("AreaTable");
const sparse = table("ItemSparse");
const itemRows = table("Item");
const questIds = new Set(table("QuestV2").map((r) => Number(r.ID)));

// The old world, as Classic Era's database knows it (the one Knowledge.lua
// and Names.lua are made from): what is new is what it doesn't.
const ids = (table: string) => new Set(all<{ id: number }>(cdb, `SELECT id FROM ${table}`).map((r) => r.id));
const classic = {
  quests: ids("quest"),
  creatures: new Map(
    all<{ id: number; name: string }>(cdb, "SELECT c.id, n.name FROM creature c JOIN name n ON n.kind = 'creature' AND n.id = c.id AND n.locale = 'enUS'").map(
      (r) => [r.id, r.name],
    ),
  ),
  items: ids("item"),
  objects: ids("object"),
};
// (Classic Era's places: Forever's own are the others)
const classicZones = new Set(all<{ ID: number }>(cdb, "SELECT ID FROM client_AreaTable").map((r) => r.ID));

// ── places ──────────────────────────────────────────────────────────────────
const areaName = new Map<number, string>(), parentOf = new Map<number, number>();
// (the client's placeholders and test areas aren't places: as audit-data.ts)
const JUNK = /UNUSED|unused|^Jeff |TEST|DELETE|Delete ME|Test|\*\*\*|^GM |Programmer|Designer|Not Used|^zz/;
for (const a of areas) {
  if (JUNK.test(a.AreaName_lang)) continue;
  areaName.set(Number(a.ID), a.AreaName_lang);
  parentOf.set(Number(a.ID), Number(a.ParentAreaID));
}
const rootOf = (id: number) => {
  for (let i = 0; i < 6 && (parentOf.get(id) ?? 0) !== 0; i++) id = parentOf.get(id)!;
  return id;
};
// ── items ───────────────────────────────────────────────────────────────────
const itemInfo = new Map<number, { name: string; quality: number; class: number; sub: number; slot: number; classes: number }>();
const itemClass = new Map(itemRows.map((r) => [Number(r.ID), r]));
for (const r of sparse) {
  const id = Number(r.ID), base = itemClass.get(id);
  itemInfo.set(id, {
    name: r.Display_lang, quality: Number(r.OverallQualityID), class: Number(base?.ClassID ?? -1), sub: Number(base?.SubclassID ?? 0),
    slot: Number(r.InventoryType || base?.InventoryType || 0), classes: Number(r.AllowableClass ?? -1),
  });
}

// ── creatures and objects ───────────────────────────────────────────────────
type Creature = { name: string; sub?: string; spawns: number; zone?: number };
const creatures = new Map<number, Creature>();
const objects = new Map<number, string>();
// (where every creature lives, old or new: the zone most of Questie's points
// for it are in)
const npcZone = new Map<number, number>();
for (const r of all<{ id: number; zone: number }>(
  fdb,
  `SELECT entity_id AS id, area_id AS zone, count(*) AS n FROM spawn WHERE kind = 'creature' AND source = 'questie' AND area_id > 0
   GROUP BY entity_id, area_id ORDER BY entity_id, n DESC, area_id`,
))
  if (!npcZone.has(r.id)) npcZone.set(r.id, rootOf(r.zone));
// Forever's own creatures: Questie's (its traces record a creature wherever a
// player saw it: one that wanders is seen in many places close together; its
// spawns are the places apart)
const points = new Map<number, [number, number][][]>();
for (const r of all<{ id: number; zone: number; x: number; y: number }>(
  fdb,
  "SELECT entity_id AS id, area_id AS zone, ux AS x, uy AS y FROM spawn WHERE kind = 'creature' AND source = 'questie' AND ux IS NOT NULL ORDER BY entity_id, area_id, rowid",
)) {
  const byZone = points.get(r.id) ?? [];
  if (!points.has(r.id)) points.set(r.id, byZone);
  const last = byZone.at(-1) as ([number, number][] & { zone?: number }) | undefined;
  if (last && last.zone === r.zone) last.push([r.x, r.y]);
  else byZone.push(Object.assign([[r.x, r.y]] as [number, number][], { zone: r.zone }));
}
for (const r of all<{ id: number; name: string; sub: string | null }>(
  fdb,
  `SELECT c.id, n.name, s.name AS sub FROM creature c JOIN name n ON n.kind = 'creature' AND n.id = c.id AND n.locale = 'enUS'
   LEFT JOIN name s ON s.kind = 'creature_subname' AND s.id = c.id AND s.locale = 'enUS' ORDER BY c.id`,
)) {
  if (classic.creatures.has(r.id)) continue;
  const spawns = (points.get(r.id) ?? []).reduce((a, zone) => {
    const kept: [number, number][] = [];
    for (const [x, y] of zone) if (!kept.some(([kx, ky]) => Math.hypot(kx - x, ky - y) < 3)) kept.push([x, y]);
    return a + kept.length;
  }, 0);
  creatures.set(r.id, { name: r.name, ...(r.sub ? { sub: r.sub } : {}), spawns: Math.max(spawns, 1), zone: npcZone.get(r.id) });
}
for (const r of all<{ id: number; name: string }>(
  fdb,
  "SELECT o.id, n.name FROM object o JOIN name n ON n.kind = 'object' AND n.id = o.id AND n.locale = 'enUS' ORDER BY o.id",
))
  if (!classic.objects.has(r.id)) objects.set(r.id, r.name);

// ── quests ──────────────────────────────────────────────────────────────────
// (the old races' bits, and Forever's Skyborne: bit 32 the Alliance's, 33 the Horde's)
const ALLIANCE = 1 + 4 + 8 + 64, HORDE = 2 + 16 + 32 + 128;
const bitOf = (mask: number, b: number) => Math.floor(mask / 2 ** b) % 2 === 1;
const sideOf = (mask: number) => {
  const old = mask % 2 ** 32;
  const a = (old & ALLIANCE) !== 0 || bitOf(mask, 32), h = (old & HORDE) !== 0 || bitOf(mask, 33);
  return a && !h ? "alliance" : h && !a ? "horde" : undefined;
};
// (a quest for some of a side's old races, not all: theirs alone)
const raceMask = (mask: number) => {
  const old = mask % 2 ** 32 & (ALLIANCE | HORDE);
  return old && old !== ALLIANCE && old !== HORDE && ((old & ALLIANCE) === old || (old & HORDE) === old) ? old : undefined;
};
// "Slay 6 Windshaper Novice Seers in Shen'dar Highlands.": how many of a name a text asks
const countIn = (text: string, name: string) => {
  const stem = name.replace(/(y|f|fe|s)?$/i, "");
  const m = text.match(new RegExp(`(\\d+) ${stem.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`, "i"));
  return m ? Number(m[1]) : undefined;
};

// What a quest's text asks when no source lists it ("Collect 10 Al'Aketh
// Windstone Charms…", "Destroy 10 Wind Hollows…", "Slay Skypriest Faladiel…"):
// only names the sources know exactly (a quest item, a creature, an object),
// with the number before them.
const plural = (n: string) => n.replace(/y$/, "ie").replace(/(s|x|ch|sh)$/, "$1e") + "s";
const known = { items: new Map<string, number>(), creatures: new Map<string, number>(), objects: new Map<string, number>() };
const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
function fromText(q: Quest, text: string) {
  const find = (names: Map<string, number>) => {
    const out: [number, number][] = [];
    for (const [name, id] of names) {
      if (name.length < 4) continue;
      // ("… bring her head to Danarii Bellowveil": who it is for, not what to fight or find)
      if (new RegExp(`\\b(to|for|with|from) ${escape(name)}`).test(text)) continue;
      const m = text.match(new RegExp(`(?:(\\d+) )?(?:${escape(plural(name))}|${escape(name)})\\b`));
      if (m) out.push([id, m[1] ? Number(m[1]) : 1]);
    }
    return out;
  };
  const verb = text.match(/^(\w+)/)?.[1]?.toLowerCase() ?? "";
  if (/^(collect|bring|gather|obtain|retrieve|recover|find|loot|acquire)$/.test(verb)) q.items.push(...find(known.items));
  if (/^(slay|kill|defeat|destroy|hunt|eliminate)$/.test(verb)) {
    for (const [id, n] of find(known.creatures)) { q.targets.push([id, n]); q.texts.push("") }
    for (const [id, n] of find(known.objects)) { q.targets.push([-id, n]); q.texts.push(objects.get(id) ?? "") }
  }
  // ("Slay Skypriest Faladiel … and collect Faladiel's Heart": both)
  if (/ and (collect|bring|retrieve|recover) /.test(text) && !q.items.length) q.items.push(...find(known.items));
}

type Quest = {
  title: string; objectives?: string; texts: string[]; items: [number, number][]; targets: [number, number][]; src?: number;
  classes?: number; rewards: number[]; zone?: number; min?: number; level?: number; races?: number; side?: string;
  prev?: number; starters?: number[]; enders?: number[]; repeatable?: boolean;
};
const quests = new Map<number, Quest>();
const itemSources = new Map<number, { creatures: Set<number>; objects: Set<number> }>();
const addSource = (item: number, kind: "creatures" | "objects", id: number) => {
  const s = itemSources.get(item) ?? { creatures: new Set(), objects: new Set() };
  s[kind].add(id);
  itemSources.set(item, s);
};
type QuestRow = { id: number; title: string; level: number | null; min: number | null; zone: number | null; races: number | null; classes: number | null; prev: number | null; text: string | null };
const own = all<QuestRow>(
  fdb,
  `SELECT q.id, n.name AS title, q.level, q.min_level AS min, q.zone_id AS zone, q.races, q.classes, q.prev_id AS prev,
     (SELECT text FROM quest_text t WHERE t.quest_id = q.id AND t.locale = 'enUS' AND t.field = 'objectives') AS text
   FROM quest q JOIN name n ON n.kind = 'quest' AND n.id = q.id AND n.locale = 'enUS' ORDER BY q.id`,
).filter((r) => !classic.quests.has(r.id) && questIds.has(r.id));
// (the quest items a text may name: those Forever's own quests ask for)
for (const r of all<{ id: number; name: string }>(
  fdb,
  `SELECT DISTINCT o.target_id AS id, n.name FROM quest_objective o JOIN name n ON n.kind = 'item' AND n.id = o.target_id AND n.locale = 'enUS'
   WHERE o.kind IN ('item', 'source')`,
))
  if (!classic.items.has(r.id)) known.items.set(r.name, r.id);
for (const [id, c] of creatures) known.creatures.set(c.name, id);
for (const [id, o] of objects) known.objects.set(o, id);
// (what it needs done first: one of Questie's alternatives, Forever's own
// first, "Call of Earth" after 92466 rather than the orcs' 1516; AllTheThings'
// where Questie has none; else the quest whose next in chain it is)
const ownIds = new Set(own.map((r) => r.id));
const prevOf = (id: number) => {
  const ps = all<{ prev: number }>(fdb, "SELECT prev_id AS prev FROM quest_prereq WHERE quest_id = ? AND prev_id > 0 ORDER BY rowid", id).map((x) => x.prev);
  const before = all<{ id: number }>(fdb, "SELECT id FROM quest WHERE next_in_chain = ? ORDER BY id", id).map((x) => x.id);
  return ps.find((p) => ownIds.has(p)) ?? ps[0] ?? before.find((p) => ownIds.has(p)) ?? before[0];
};
for (const r of own) {
  const q: Quest = { title: r.title, texts: [], items: [], targets: [], rewards: [] };
  const text = (r.text ?? "").replace(/\s+/g, " ").trim();
  if (text) q.objectives = text;
  // what it asks, as Questie lists it (the creatures a quest involves, the
  // ones to speak to or escort too: a kill only where the text asks to slay
  // it; the others, the quest's own words, as the quest log shows a task)
  const asks = all<{ kind: string; target: number }>(
    fdb,
    "SELECT kind, target_id AS target FROM quest_objective WHERE quest_id = ? ORDER BY CASE kind WHEN 'creature' THEN 0 WHEN 'object' THEN 1 ELSE 2 END, idx",
    r.id,
  );
  const byCreature = asks.filter((a) => a.kind === "creature");
  const slays = /^(slay|kill|defeat|destroy|hunt|eliminate|cull|thin)\b/i.test(text) || / and (slay|kill|defeat) /i.test(text);
  for (const { target: cid } of byCreature) {
    const name = creatures.get(cid)?.name ?? classic.creatures.get(cid) ?? "";
    // ("… bring her head to Danarii Bellowveil": who it is for, not whom to fight)
    const recipient = name && new RegExp(`\\b(to|for|with|from) ${escape(name)}`).test(text);
    const asked = !recipient && ((slays && name && new RegExp(`\\b${escape(name)}`).test(text)) || (slays && byCreature.length === 1));
    if (asked) {
      q.targets.push([cid, countIn(text, name) ?? 1]);
      q.texts.push("");
    } else if (!q.texts.includes(text) && text) {
      q.targets.push([0, 1]);
      q.texts.push(text.replace(/\.\s*$/, ""));
    }
  }
  for (const { target: oid } of asks.filter((a) => a.kind === "object"))
    if (!q.targets.some(([x]) => x === -oid)) {
      q.targets.push([-oid, 1]);
      q.texts.push(objects.get(oid) ?? "");
    }
  for (const { target: iid } of asks.filter((a) => a.kind === "item" || a.kind === "source")) {
    if (q.items.some(([x]) => x === iid)) continue;
    const name = itemInfo.get(iid)?.name ?? "";
    q.items.push([iid, countIn(text, name) ?? 1]);
  }
  if (!q.targets.length && !q.items.length && text) fromText(q, text);
  // who gives it and who takes it back (an object's id negative)
  const rel = all<{ role: string; kind: string; id: number }>(
    fdb,
    "SELECT role, kind, entity_id AS id FROM quest_relation WHERE quest_id = ? ORDER BY role, kind, entity_id",
    r.id,
  );
  const starters = rel.filter((x) => x.role === "start" && x.kind === "creature").map((x) => x.id);
  const objectStarters = rel.filter((x) => x.role === "start" && x.kind === "object").map((x) => -x.id);
  const enders = rel.filter((x) => x.role === "end" && x.kind === "creature").map((x) => x.id);
  q.starters = starters.length ? starters : objectStarters.length ? objectStarters : undefined;
  q.enders = enders.length ? enders : undefined;
  q.classes = r.classes || undefined;
  q.races = r.races ? raceMask(r.races) : undefined;
  q.side = r.races ? sideOf(r.races) : undefined;
  q.min = r.min || undefined;
  q.level = r.level && r.level > 0 ? r.level : undefined;
  q.prev = prevOf(r.id) ?? (r.prev || undefined);
  q.rewards = all<{ item: number }>(fdb, "SELECT ref_id AS item FROM quest_reward WHERE quest_id = ? AND kind IN ('item', 'choice')", r.id)
    .map((x) => x.item)
    .filter((i) => itemInfo.has(i));
  // where: its zone, else the land its giver stands in
  const giver = q.starters?.[0] && q.starters[0] > 0 ? q.starters[0] : q.enders?.[0];
  q.zone = r.zone && r.zone > 0 ? rootOf(r.zone) : giver ? npcZone.get(giver) ?? creatures.get(giver)?.zone : undefined;
  quests.set(r.id, q);
}
// what drops a quest's items, as Questie saw it
for (const r of all<{ kind: string; source: number; item: number }>(
  fdb,
  "SELECT kind, source_id AS source, item_id AS item FROM loot WHERE source = 'questie' AND kind IN ('creature', 'object') AND item_id IS NOT NULL",
))
  addSource(r.item, r.kind === "object" ? "objects" : "creatures", r.source);

// ── the playthrough's game data: Forever's additions to game.lua ────────────
const lua = (v: unknown): string => {
  if (v === null || v === undefined || v === "") return "nil";
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  if (typeof v === "string") return JSON.stringify(v).replace(/\\u([0-9a-f]{4})/g, (_, h) => `\\u{${h}}`);
  if (Array.isArray(v)) return "{" + v.map(lua).join(",") + "}";
  return "{" + Object.entries(v as object).filter(([, x]) => x !== undefined && x !== null && x !== "")
    .map(([k, x]) => `${/^\d+$/.test(k) ? `[${k}]` : k}=${lua(x)}`).join(",") + "}";
};
const wantedItems = new Set<number>();
for (const q of quests.values()) {
  for (const [i] of q.items) wantedItems.add(i);
  for (const r of q.rewards) wantedItems.add(r);
}
const out = ["-- generated by scripts/forever-data.ts: do not edit (Forever's additions to game.lua)",
  "local D = { creatures = {}, quests = {}, items = {}, objects = {}, zones = {}, sources = {}, parents = {} }"];
const chunk = (name: string, entries: [number, unknown][]) => {
  for (let i = 0; i < entries.length; i += 1000) {
    out.push(";(function(t)");
    for (const [id, v] of entries.slice(i, i + 1000)) out.push(`t[${id}]=${lua(v)}`);
    out.push(`end)(D.${name})`);
  }
};
chunk("creatures", [...creatures].map(([id, c]) => [id, { name: c.name, sub: c.sub, spawns: c.spawns, zone: c.zone }]));
chunk("quests", [...quests].map(([id, q]) => [id, q]));
chunk("items", [...wantedItems].filter((i) => itemInfo.has(i) && !classic.items.has(i))
  .map((i) => [i, (({ classes: _, ...rest }) => rest)(itemInfo.get(i)!)]));
chunk("objects", [...objects]);
chunk("zones", [...areaName].filter(([id]) => !classicZones.has(id)).map(([id, n]) => [id, n]));
// (the land each new place lies in: Thendal Grove is on Zephras Isle)
chunk("parents", [...parentOf].filter(([id, p]) => !classicZones.has(id) && p > 0 && areaName.has(id)).map(([id, p]) => [id, p]));
chunk("sources", [...itemSources].filter(([i]) => wantedItems.has(i)).map(([i, s]) => [i, {
  creatures: s.creatures.size ? [...s.creatures] : undefined, objects: s.objects.size && !s.creatures.size ? [...s.objects] : undefined,
}]));
out.push("return D");
writeFileSync(path.join(AUDIT, "game-forever.lua"), out.join("\n"));

// ── names: Forever's own, for scripts/names.ts --forever ────────────────────
const nameOf = (id: number) => creatures.get(id)?.name ?? classic.creatures.get(id);
writeFileSync(path.join(AUDIT, "names-forever.json"), JSON.stringify({
  zones: [...areaName].filter(([id]) => !classicZones.has(id)).map(([, n]) => n),
  creatures: [...creatures.values()].map((c) => ({ name: c.name, spawns: c.spawns, npc: c.sub ? 1 : 0, sub: c.sub })),
  items: [...wantedItems].map((i) => itemInfo.get(i)?.name).filter(Boolean),
  questNpcs: [...new Set([...quests.values()].flatMap((q) => [...(q.starters ?? []), ...(q.enders ?? [])])
    .filter((id) => id > 0).map(nameOf).filter(Boolean))],
  questItems: [...new Map([...quests.values()].flatMap((q) => q.items)
    .map(([i, n]) => [itemInfo.get(i)?.name, n] as const).filter(([name]) => name)).entries()]
    .map(([name, most]) => ({ name, most })),
}));
writeFileSync(path.join(AUDIT, "corpus-forever.txt"),
  [...quests.values()].flatMap((q) => [q.title, q.objectives ?? "", ...q.texts]).filter((s) => s).map((s) => s.replace(/\s+/g, " ")).join("\n"));

// ── the writer's knowledge of it: addon/Hearthtale/Forever.lua ─────────────
// What Knowledge.lua knows of the old world, for Forever's own quests: a
// class's own quest, its chains.
const knowledge: string[] = [];
const qs = (s: string) => JSON.stringify(s);
const CLASS: Record<string, number> = { WARRIOR: 1, PALADIN: 2, HUNTER: 4, ROGUE: 8, PRIEST: 16, SHAMAN: 64, MAGE: 128, WARLOCK: 256, DRUID: 1024 };
const CLASSES = Object.entries(CLASS);
const TOTEM_ITEMS: Record<number, string> = { 5175: "earth", 5176: "fire", 5177: "water", 5178: "air" };
// (a shaman's rite, as the game titles it, "Call of Fire": the shaman's own,
// never a story, whatever classes the beta's data leaves out. Its totem,
// where no step of it is known to give one, at its end: the last of a run
// of its steps, when that one brings the rite's prize home, "Bring the
// Torch of Eternal Flame to Bruegs Kindleborn")
const RITE = /^Call of (Earth|Fire|Water|Air)$/;
const riteTotem = new Map<number, string>();
{
  const runs: number[][] = [];
  for (const [id, q] of [...quests].filter(([, q]) => RITE.test(q.title ?? "")).sort((x, y) => x[0] - y[0])) {
    const run = runs.at(-1), prev = run?.at(-1);
    if (run && prev !== undefined && id - prev < 50 && quests.get(prev)!.title === q.title) run.push(id);
    else runs.push([id]);
  }
  for (const run of runs) {
    if (run.some((id) => quests.get(id)!.rewards.some((r) => TOTEM_ITEMS[r]))) continue;
    const end = run.at(-1)!, q = quests.get(end)!;
    if (/^Bring /.test(q.objectives ?? "")) riteTotem.set(end, q.title!.match(RITE)![1].toLowerCase());
  }
}
for (const [id, q] of [...quests].sort((x, y) => x[0] - y[0])) {
  const cls = CLASSES.filter(([, bit]) => (q.classes ?? 0) & bit).map(([c]) => c);
  // (a shaman's initiation into an element: its totem, given at the end)
  const totem = TOTEM_ITEMS[q.rewards.find((r) => TOTEM_ITEMS[r]) ?? 0] ?? riteTotem.get(id);
  const rite = RITE.test(q.title ?? "");
  if (cls.length === 1 || totem || rite)
    knowledge.push(
      `K.quests[${id}] = { class = ${qs(totem || rite ? "SHAMAN" : cls[0])}${totem ? `, totem = ${qs(totem)}` : ""} }`,
    );
}
// (their chains, as Knowledge.lua's: chains[id] the first quest, ends[id] the
// last; a link one to one only, a prerequisite of several is no story going on)
const fSucc = new Map<number, number[]>(), fPred = new Map<number, number[]>();
for (const [id, q] of quests)
  if (q.prev && q.prev > 0 && quests.has(q.prev)) {
    fSucc.set(q.prev, [...(fSucc.get(q.prev) ?? []), id]);
    fPred.set(id, [...(fPred.get(id) ?? []), q.prev]);
  }
const fNext = (id: number) => {
  const s = fSucc.get(id);
  return s && s.length === 1 && fPred.get(s[0])!.length === 1 ? s[0] : undefined;
};
const fBack = (id: number) => {
  const p = fPred.get(id);
  return p && p.length === 1 && fNext(p[0]) === id ? p[0] : undefined;
};
for (const id of [...quests.keys()].sort((x, y) => x - y)) {
  if (fNext(id) === undefined && fBack(id) === undefined) continue;
  const seen = new Set<number>();
  let x = id;
  while (fBack(x) !== undefined && !seen.has(x)) {
    seen.add(x);
    x = fBack(x)!;
  }
  knowledge.push(`K.chains[${id}] = ${x}`);
  if (fNext(id) === undefined) knowledge.push(`K.ends[${id}] = true`);
}
const roles = new Map<string, string>();
for (const c of creatures.values()) if (c.sub && !roles.has(c.name)) roles.set(c.name, c.sub);
// (Forever's quest givers' callings, for the playthrough alone)
writeFileSync(path.join(AUDIT, "npcs-forever.lua"), [
  "-- generated by scripts/forever-data.ts: Forever's quest givers' callings",
  "return {",
  ...[...roles].sort((a, b) => (a[0] < b[0] ? -1 : 1)).map(([name, role]) => `  [${qs(name)}] = { role = ${qs(role)} },`),
  "}",
].join("\n") + "\n");

// How the game writes Forever's own names (Names.lua's rules, over Classic's
// texts and Forever's together); the old world's names stay as Names.lua has them.
type Data = Parameters<typeof decide>[0];
const classicNames = JSON.parse(readFileSync(path.join(AUDIT, "names.json"), "utf8")) as Data;
const foreverNames = JSON.parse(readFileSync(path.join(AUDIT, "names-forever.json"), "utf8")) as Data;
const merged: Data = {
  zones: [...classicNames.zones, ...foreverNames.zones],
  creatures: [...classicNames.creatures, ...foreverNames.creatures],
  questItems: [...classicNames.questItems, ...foreverNames.questItems],
  items: [...classicNames.items, ...foreverNames.items],
  questNpcs: [...classicNames.questNpcs, ...foreverNames.questNpcs],
};
const names = decide(merged, readFileSync(path.join(AUDIT, "corpus.txt"), "utf8") + "\n" +
  readFileSync(path.join(AUDIT, "corpus-forever.txt"), "utf8"));
const old = new Set([...classicNames.zones, ...classicNames.creatures.map((c) => c.name), ...classicNames.questNpcs,
  ...classicNames.items, ...classicNames.questItems.map((i) => i.name)]);
const fresh = (l: string[]) => l.filter((n) => !old.has(n));
const oldOwners = new Set(classicNames.items.flatMap((n) => [...n.matchAll(/(?:^| )([A-Z][a-z]+)'s /g)].map((m) => m[1])));
const section = (field: string, l: string[]) => (l.length ? [`add(N.${field}, {`, list(l), "})"] : []);
writeFileSync(path.join(ROOT, "addon", "Hearthtale", "Forever.lua"), [
  "-- Generated by scripts/forever-data.ts: do not edit. WoW Forever's own content",
  `-- (build ${BUILD}), loaded by Forever's TOC alone (Hearthtale_Camelot.toc):`,
  "-- what Knowledge.lua and Names.lua know of the old world, for Forever's new",
  "-- quests, creatures and places. From wow-data's Forever database: the",
  "-- client's tables, Questie's Forever, its quests' rewards (AllTheThings').",
  "local _, ns = ...",
  "local K, N = ns.knowledge, ns.names",
  "local function add(t, names)",
  "  for k, v in pairs(names) do",
  "    t[k] = v",
  "  end",
  "end",
  ...knowledge,
  ...section("placeThe", fresh(names.placeThe)),
  ...section("placeBare", fresh(names.placeBare)),
  ...section("creatureThe", fresh(names.creatureThe)),
  ...section("creatureBare", fresh(names.creatureBare)),
  // (a giver the old texts never name: "the" only for a role through and through, "the Strange Hermit")
  ...section("npcThe", fresh(names.npcThe).filter(plainName)),
  ...section("roles", names.roles.filter((r) => !oldOwners.has(r))),
  ...(names.plurals.filter(([n]) => !old.has(n)).length
    ? ["add(N.plural, {", ...names.plurals.filter(([n]) => !old.has(n)).sort()
      .map(([n, p]) => `  [${JSON.stringify(n)}] = ${JSON.stringify(p)},`), "})"]
    : []),
].join("\n") + "\n");

const told = [...quests.values()];
console.log(`✓ Forever (build ${BUILD}): ${told.length} quests (${told.filter((q) => q.targets.length || q.items.length).length} with objectives, ` +
  `${told.filter((q) => q.enders).length} with their enders, ${told.filter((q) => q.zone).length} placed), ${creatures.size} creatures, ` +
  `${objects.size} objects, ${[...itemSources].filter(([i]) => wantedItems.has(i)).length} quest items' sources → .cache/audit/game-forever.lua`);
