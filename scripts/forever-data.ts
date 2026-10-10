// WoW Forever's own content (Zephras Isle, its new quests in the old lands,
// its new dungeons), for the Forever package and its tests: the game data
// the Forever playthrough reads (.cache/audit/game-forever.lua, beside
// Classic's game.lua), the names and texts scripts/names.ts reads for
// Forever's names, and the writer's knowledge of it (addon/Hearthtale/
// Forever.lua, with the names from names.ts). Classic's files are untouched.
//   bun scripts/forever-data.ts        (after scripts/audit-data.ts)
// Sources, pinned (downloaded once into .cache/forever, gitignored):
//   - the beta client's own tables (wago.tools, product wow_classic_beta, one
//     build): places, items, which quests exist;
//   - AllTheThings' Forever database (MIT): quests, their givers, levels,
//     sides, classes, prerequisites, objectives and rewards;
//   - QuestieDB's traces of the beta (what Questie's recorder saw in 20,035
//     sessions): quests' enders and objectives, creatures and where they live,
//     what drops a quest's items.
// cmangos classic-db (GPL-3.0, .cache/audit) for the old world's creatures,
// pfQuest (MIT) for where the old world's NPCs stand.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { rows } from "./sql";
import { decide, list, plainName } from "./names";

const ROOT = path.join(import.meta.dir, "..");
const CACHE = path.join(ROOT, ".cache", "forever");
const AUDIT = path.join(ROOT, ".cache", "audit");
export const BUILD = "1.60.1.70291";
const ATT = "ATTWoWAddon/AllTheThings";
const ATT_COMMIT = "a21caf2a7ec636785505a7f4e7e4311d16ce28af";
const QUESTIEDB = "Questie/QuestieDB";
const QUESTIEDB_COMMIT = "7e87203312ef7ba309b96361fed90e492e145cff";
const PFQUEST = "shagu/pfQuest";
const PFQUEST_COMMIT = "104f35678ca39ab1fb78b655f815cc7016f5e0c8";
const UA = { "User-Agent": "Hearthtale/0.5 (addon data; github.com/salty-max/hearthtale)" };

async function fetchOnce(url: string, file: string) {
  const out = path.join(CACHE, file);
  if (!existsSync(out)) {
    mkdirSync(path.dirname(out), { recursive: true });
    const res = await fetch(url, { headers: UA });
    if (!res.ok) throw new Error(`${url}: ${res.status}`);
    writeFileSync(out, new Uint8Array(await res.arrayBuffer()));
  }
  return out;
}

// A client table, as CSV rows by column name.
function csv(text: string): Record<string, string>[] {
  const lines: string[][] = [];
  let row: string[] = [], cell = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++ }
      else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") { row.push(cell); cell = "" }
    else if (c === "\n") { row.push(cell.replace(/\r$/, "")); lines.push(row); row = []; cell = "" }
    else cell += c;
  }
  if (cell || row.length) { row.push(cell); lines.push(row) }
  const head = lines.shift()!;
  return lines.filter((l) => l.length > 1).map((l) => Object.fromEntries(head.map((h, i) => [h, l[i] ?? ""])));
}
async function table(name: string) {
  const file = await fetchOnce(`https://wago.tools/db2/${name}/csv?product=wow_classic_beta&build=${BUILD}`, `wago/${name}.${BUILD}.csv`);
  return csv(readFileSync(file, "utf8"));
}

// ── the sources ─────────────────────────────────────────────────────────────
mkdirSync(CACHE, { recursive: true });
const attTree = JSON.parse(readFileSync(await fetchOnce(
  `https://api.github.com/repos/${ATT}/git/trees/${ATT_COMMIT}?recursive=1`, `att-tree.${ATT_COMMIT.slice(0, 12)}.json`), "utf8"));
const attFiles = (attTree.tree as { path: string; type: string }[])
  .filter((f) => f.type === "blob" && /^\.contrib\/\.db\/forever\/(zones|dungeons & raids)\/.*\.lua$/.test(f.path)).map((f) => f.path);
for (const f of attFiles)
  await fetchOnce(`https://raw.githubusercontent.com/${ATT}/${ATT_COMMIT}/${f.split("/").map(encodeURIComponent).join("/")}`,
    `att/${f.replace(/^\.contrib\/\.db\/forever\//, "")}`);
for (const f of ["foreverQuestTraces", "foreverNpcTraces", "foreverObjectTraces", "foreverItemTraces"])
  await fetchOnce(`https://raw.githubusercontent.com/${QUESTIEDB}/${QUESTIEDB_COMMIT}/src/corrections/Forever/traces/${f}.lua`, `questiedb/${f}.lua`);
const unitsFile = await fetchOnce(`https://raw.githubusercontent.com/${PFQUEST}/${PFQUEST_COMMIT}/db/units.lua`, `pfquest-units.${PFQUEST_COMMIT.slice(0, 12)}.lua`);
const read = spawnSync("luajit", [path.join(ROOT, "scripts", "forever-read.lua"), CACHE], { maxBuffer: 1 << 28 });
if (read.status !== 0) throw new Error(`forever-read.lua: ${read.stderr}`);

type Objective = { index?: number; text?: string; provider?: (string | number)[]; cr?: number; crs?: number[] };
type AttQuest = {
  id: number; file: string; title?: string; map?: string; qg?: number[]; qgNames?: string; provider?: (string | number)[];
  races?: string | string[]; classes?: string[] | { fn: string; args: unknown[] }; lvl?: number | number[];
  prev?: number[]; repeatable?: boolean; objectives: Objective[]; rewards: number[];
  found: { item: number; from: string; id: number; name?: string }[];
};
type Trace = Record<string, unknown>;
const sources = JSON.parse(read.stdout.toString("utf8")) as {
  att: { quests: Record<string, AttQuest>; npcs: Record<string, { name: string; map?: string }> };
  traces: { quests: Record<string, Trace>; npcs: Record<string, Trace>; objects: Record<string, Trace>; items: Record<string, Trace> };
};

const areas = await table("AreaTable");
const sparse = await table("ItemSparse");
const itemRows = await table("Item");
const questIds = new Set((await table("QuestV2")).map((r) => Number(r.ID)));

// The old world, as cmangos knows it: what is new is what it doesn't.
const sql = gunzipSync(readFileSync(path.join(AUDIT, "classicdb.sql.gz"))).toString("utf8");
const classic = { quests: new Set<number>(), creatures: new Map<number, string>(), items: new Set<number>(), objects: new Set<number>() };
for (const r of rows(sql, "quest_template")) classic.quests.add(r.entry as number);
for (const r of rows(sql, "creature_template")) classic.creatures.set(r.Entry as number, r.Name as string);
for (const r of rows(sql, "item_template")) classic.items.add(r.entry as number);
for (const r of rows(sql, "gameobject_template")) classic.objects.add(r.entry as number);
const classicZones = new Set<number>();
for (const m of readFileSync(path.join(AUDIT, "pfquest-zones.lua"), "utf8").matchAll(/\[(\d+)\] = "/g)) classicZones.add(Number(m[1]));

// ── places ──────────────────────────────────────────────────────────────────
// An ATT map constant ("MAP.ZEPHRAS_ISLE", "MAP.THE_BARRENS") is the zone of
// that name in the client's AreaTable (a zone: no parent).
const norm = (s: string) => s.toLowerCase().replace(/^the /, "").replace(/[^a-z0-9]+/g, " ").trim();
const zoneByName = new Map<string, number>(), areaName = new Map<number, string>(), parentOf = new Map<number, number>();
// (the client's placeholders and test areas aren't places: as audit-data.ts)
const JUNK = /UNUSED|unused|^Jeff |TEST|DELETE|Delete ME|Test|\*\*\*|^GM |Programmer|Designer|Not Used|^zz/;
for (const a of areas) {
  if (JUNK.test(a.AreaName_lang)) continue;
  areaName.set(Number(a.ID), a.AreaName_lang);
  parentOf.set(Number(a.ID), Number(a.ParentAreaID));
}
// (a zone's name first, then a place's: "Northshire Valley" is in Elwynn Forest)
for (const top of [true, false])
  for (const a of areas)
    if ((a.ParentAreaID === "0") === top && !zoneByName.has(norm(a.AreaName_lang))) zoneByName.set(norm(a.AreaName_lang), Number(a.ID));
const rootOf = (id: number) => {
  for (let i = 0; i < 6 && (parentOf.get(id) ?? 0) !== 0; i++) id = parentOf.get(id)!;
  return id;
};
const unmapped = new Set<string>();
const zoneOf = (map?: string) => {
  if (!map?.startsWith("MAP.") || /^MAP\.(EASTERN_KINGDOMS|KALIMDOR|AZEROTH)$/.test(map)) return undefined;
  const id = zoneByName.get(norm(map.slice(4).replace(/_/g, " ")));
  if (!id) unmapped.add(map);
  return id && rootOf(id);
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
const nameRole = (s: string) => {
  const m = s.match(/^(.*?)\s*<([^>]+)>\s*$/);
  return m ? { name: m[1].trim(), sub: m[2].trim() } : { name: s.trim() };
};
// (an old NPC's land, from pfQuest (MIT): its first spawn's zone)
const npcZone = new Map<number, number>();
for (const m of readFileSync(unitsFile, "utf8").matchAll(/\n {2}\[(\d+)\] = \{\n {4}\["coords"\] = \{\n {6}\[1\] = \{ [-\d.]+, [-\d.]+, (\d+),/g))
  npcZone.set(Number(m[1]), Number(m[2]));
for (const [id, n] of Object.entries(sources.traces.npcs)) if (typeof n.zoneID === "number" && n.zoneID > 0) npcZone.set(Number(id), rootOf(n.zoneID));
for (const [id, n] of Object.entries(sources.traces.npcs)) {
  if (classic.creatures.has(Number(id)) || typeof n.name !== "string") continue;
  // (the traces record a creature wherever a player saw it: one that wanders
  // is seen in many places close together; its spawns are the places apart)
  const spawns = Object.values((n.spawns ?? {}) as Record<string, [number, number][]>).reduce((a, points) => {
    const kept: [number, number][] = [];
    for (const [x, y] of points) if (!kept.some(([kx, ky]) => Math.hypot(kx - x, ky - y) < 3)) kept.push([x, y]);
    return a + kept.length;
  }, 0);
  creatures.set(Number(id), { name: n.name as string, spawns: Math.max(spawns, 1), zone: n.zoneID as number | undefined });
}
for (const [id, o] of Object.entries(sources.traces.objects))
  if (!classic.objects.has(Number(id)) && typeof o.name === "string") objects.set(Number(id), o.name as string);
// (ATT names the givers it lists: "Ayessa Dawnsinger", "Alamar Grimm <Warlock Trainer>")
for (const q of Object.values(sources.att.quests)) {
  const names = (q.qgNames ?? "").split(/,\s*/);
  (q.qg ?? []).forEach((id, i) => {
    const n = names[i] ? nameRole(names[i]) : undefined;
    if (!n || classic.creatures.has(id)) return;
    const c = creatures.get(id) ?? { name: n.name, spawns: 1, zone: zoneOf(q.map) };
    if (n.sub) c.sub = n.sub;
    creatures.set(id, c);
  });
  for (const o of q.objectives)
    if (o.provider?.[0] === "n" && !classic.creatures.has(Number(o.provider[1])) && !creatures.has(Number(o.provider[1])) && o.text)
      creatures.set(Number(o.provider[1]), { name: o.text.replace(/^\d+\/\d+\s*/, "").replace(/\s+(slain|defeated|killed)$/, ""), spawns: 2 });
}
for (const [id, n] of Object.entries(sources.att.npcs))
  if (!classic.creatures.has(Number(id)) && !creatures.has(Number(id))) creatures.set(Number(id), { ...nameRole(n.name), spawns: 1, zone: zoneOf(n.map) });

// ── quests ──────────────────────────────────────────────────────────────────
const CLASS: Record<string, number> = { WARRIOR: 1, PALADIN: 2, HUNTER: 4, ROGUE: 8, PRIEST: 16, SHAMAN: 64, MAGE: 128, WARLOCK: 256, DRUID: 1024 };
const RACE: Record<string, number> = { HUMAN: 1, ORC: 2, DWARF: 4, NIGHTELF: 8, UNDEAD: 16, SCOURGE: 16, TAUREN: 32, GNOME: 64, TROLL: 128 };
const classMask = (c: AttQuest["classes"]) => {
  if (!c) return undefined;
  if (Array.isArray(c)) return c.reduce((m, k) => m | (CLASS[String(k)] ?? 0), 0) || undefined;
  if (c.fn === "exclude") return undefined; // all but some: no class of its own
  return undefined;
};
const sideOf = (r: AttQuest["races"]) => (r === "HORDE_ONLY" ? "horde" : r === "ALLIANCE_ONLY" ? "alliance" : undefined);
const raceMask = (r: AttQuest["races"]) =>
  Array.isArray(r) ? r.reduce((m, k) => m | (RACE[String(k)] ?? 0), 0) || undefined : undefined;
// "0/6 Windshaper Novice Seer defeated", "0/1 Head of the Baron": the count and the line's words
const parseLine = (s?: string) => {
  const m = s?.match(/^(\d+)\/(\d+)\s+(.*)$/);
  return m ? { n: Number(m[2]), words: m[3].trim() } : s ? { n: 1, words: s.trim() } : undefined;
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
for (const [id, it] of Object.entries(sources.traces.items)) if (typeof it.name === "string") known.items.set(it.name as string, Number(id));
for (const [id, c] of creatures) known.creatures.set(c.name, id);
for (const [id, o] of objects) known.objects.set(o, id);
const tracedIds = Object.keys(sources.traces.quests).map(Number);
const ids = new Set([...Object.keys(sources.att.quests).map(Number), ...tracedIds].filter((id) => !classic.quests.has(id) && questIds.has(id)));
for (const id of [...ids].sort((a, b) => a - b)) {
  const a = sources.att.quests[id] as AttQuest | undefined;
  const t = (sources.traces.quests[id] ?? {}) as Trace;
  const title = (t.name as string | undefined) ?? a?.title;
  if (!title) continue;
  const q: Quest = { title, texts: [], items: [], targets: [], rewards: [] };
  const objectivesText = (t.objectivesText as string[] | undefined) ?? [];
  if (objectivesText.length) q.objectives = objectivesText.join(" ");
  // what it asks: ATT's lines first (with their counts), then what the traces add
  const seen = new Set<string>();
  for (const o of a?.objectives ?? []) {
    const line = parseLine(o.text);
    const [kind, oid] = (o.provider ?? []) as [string, number];
    if (kind === "n" && oid) {
      seen.add(`n${oid}`);
      const name = creatures.get(oid)?.name ?? classic.creatures.get(oid);
      // (a kill in the quest's own words, "… defeated": its text, as the quest log shows it)
      const own = line && name && line.words !== `${name} slain` ? line.words : "";
      q.targets.push([oid, line?.n ?? 1]);
      q.texts.push(own);
    } else if (kind === "i" && oid) {
      seen.add(`i${oid}`);
      q.items.push([oid, line?.n ?? 1]);
      for (const c of [o.cr, ...(o.crs ?? [])]) if (c) addSource(oid, "creatures", c);
    } else if (kind === "o" && oid) {
      seen.add(`o${oid}`);
      q.targets.push([-oid, line?.n ?? 1]);
      q.texts.push(line?.words ?? "");
      if (!objects.has(oid) && o.text) objects.set(oid, line?.words ?? o.text);
    } else if (line) {
      q.texts.push(line.words); // an event: "Listen to Elaadrin"
      q.targets.push([0, line.n]);
    }
  }
  const structured = (t.objectives ?? []) as unknown[][];
  const [byCreature, byObject, byItem] = [structured[0], structured[1], structured[2]] as ([number, string?][] | undefined)[];
  const text = objectivesText.join(" ");
  // (the traces list every creature a quest involves, the ones to speak to or
  // escort too: a kill only where the text asks to slay it; the others, the
  // quest's own words, as the quest log shows a task)
  const slays = /^(slay|kill|defeat|destroy|hunt|eliminate|cull|thin)\b/i.test(text) || / and (slay|kill|defeat) /i.test(text);
  for (const [cid] of byCreature ?? []) {
    if (seen.has(`n${cid}`)) continue;
    const name = creatures.get(cid)?.name ?? classic.creatures.get(cid) ?? "";
    // ("… bring her head to Danarii Bellowveil": who it is for, not whom to fight)
    const recipient = name && new RegExp(`\\b(to|for|with|from) ${escape(name)}`).test(text);
    const asked = !recipient && (slays && name && new RegExp(`\\b${escape(name)}`).test(text) || slays && (byCreature ?? []).length === 1);
    if (asked) {
      q.targets.push([cid, countIn(text, name) ?? 1]);
      q.texts.push("");
    } else if (!q.texts.includes(text) && text) {
      q.targets.push([0, 1]);
      q.texts.push(text.replace(/\.\s*$/, ""));
    }
  }
  for (const [oid] of byObject ?? []) if (!seen.has(`o${oid}`) && !q.targets.some(([x]) => x === -oid)) {
    q.targets.push([-oid, 1]);
    q.texts.push(objects.get(oid) ?? "");
  }
  for (const [iid] of byItem ?? []) {
    if (seen.has(`i${iid}`)) continue;
    const name = itemInfo.get(iid)?.name ?? "";
    q.items.push([iid, countIn(text, name) ?? 1]);
  }
  if (!q.targets.length && !q.items.length && text) fromText(q, text);
  for (const f of a?.found ?? []) addSource(f.item, f.from === "o" ? "objects" : "creatures", f.id);
  // who gives it and who takes it back
  const started = (t.startedBy as number[][] | undefined) ?? [];
  const finished = (t.finishedBy as number[][] | undefined) ?? [];
  q.starters = a?.qg?.length ? a.qg : started[0]?.length ? started[0] : undefined;
  if (!q.starters && a?.provider?.[0] === "o") q.starters = [-(a.provider[1] as number)];
  q.enders = finished[0]?.length ? finished[0] : undefined;
  q.classes = classMask(a?.classes);
  q.races = raceMask(a?.races);
  q.side = sideOf(a?.races);
  const lvl = Array.isArray(a?.lvl) ? a!.lvl[0] : a?.lvl;
  q.min = (t.requiredLevel as number | undefined) ?? lvl;
  q.level = (t.questLevel as number | undefined) ?? lvl;
  q.prev = a?.prev?.[0];
  q.repeatable = a?.repeatable || undefined;
  q.rewards = (a?.rewards ?? []).filter((r) => itemInfo.has(r));
  // where: ATT's map, else the land its giver stands in
  const giver = q.starters?.[0] && q.starters[0] > 0 ? q.starters[0] : q.enders?.[0];
  q.zone = zoneOf(a?.map) ?? (giver ? npcZone.get(giver) ?? creatures.get(giver)?.zone : undefined);
  quests.set(id, q);
}
// what drops a quest's items, as the traces saw it
for (const [id, it] of Object.entries(sources.traces.items)) {
  for (const c of (it.npcDrops ?? []) as number[]) addSource(Number(id), "creatures", c);
  for (const o of (it.objectDrops ?? []) as number[]) addSource(Number(id), "objects", o);
}

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
  `-- (beta build ${BUILD}), loaded by Forever's TOC alone (Hearthtale_Camelot.toc):`,
  "-- what Knowledge.lua and Names.lua know of the old world, for Forever's new",
  "-- quests, creatures and places. From the beta client's tables (wago.tools),",
  "-- AllTheThings' Forever database (MIT) and QuestieDB's traces of the beta.",
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
if (unmapped.size) console.log(`  (maps with no zone: ${[...unmapped].sort().join(", ")})`);
