/**
 * writing/*.md → addon/Hearthtale/Data_Classic.lua, Data_Forever.lua
 *
 * Each file holds the sentences of one kind of moment:
 *
 *   ---
 *   kind: close-deep
 *   ---
 *   - It came down to a breath {at}. ...
 *   - [night hc] Night had fallen over {sub} when ...
 *   - [client:forever] ...
 *
 * A sentence's [tags] are the conditions it needs (all of them; "!night" =
 * not at night): the writer gives each moment its tags (night, first, hc,
 * race:Dwarf, class:PALADIN...). Plain ASCII, like the siblings' content;
 * {slots} must be the kind's (KINDS) or the voice's, every kind must exist.
 * A sentence ends with . ! or ? (or a closing quote after one); a clause
 * (kinds c-*: "took a room at {inn}") starts in lower case, with no stop.
 *
 * writing/voices/<Race>/<kind>.md: a race's own sentences for a kind (its
 * journal's voice), used before the shared ones; same format, same slots.
 *
 * writing/scenery/<place>.md: the first time in a life the character enters a
 * place (a zone, a town, a dungeon), a few sentences describing it:
 *
 *   ---
 *   place: Dun Morogh          the game's name for it
 *   type: zone                 zone | town | dungeon
 *   home: Dwarf Gnome          the races whose home it is (optional)
 *   faction: alliance          whose land: alliance | horde | neutral
 *   ---
 *   - [home !night] ...        viewpoints: home, ally, foe, neutral; night
 *
 *   bun scripts/build.ts          write the data files
 *   bun scripts/build.ts --check  fail if one isn't up to date
 */
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..");
const WRITING = join(ROOT, "writing");
const CLIENTS = ["classic", "forever"];
const GAMES = CLIENTS.map((client) => ({ client, out: join(ROOT, `addon/Hearthtale/Data_${client[0].toUpperCase()}${client.slice(1)}.lua`) }));
const errors: string[] = [];
const fail = (file: string, msg: string) => errors.push(`${file}: ${msg}`);
const q = (s: string) => JSON.stringify(s);

// Each kind and the slots the writer (Writer.lua) fills for it.
const KINDS: Record<string, string[]> = {
  beginning: ["where", "at", "in"],
  opening: ["where", "at", "in"],
  zone: ["zone"],
  flight: ["from", "to"],
  "quests-many": ["n", "quest", "giver"],
  kills: ["n", "foes", "at", "in"],
  "kills-two": ["n1", "foes1", "n2", "foes2", "at", "in"],
  rare: ["foe", "at", "in"],
  "close-light": ["foe", "at", "in"],
  "close-deep": ["foe", "at", "in"],
  dungeon: ["dungeon", "boss", "mates"],
  "boss-final": ["boss", "dungeon"],
  closing: ["time", "gold"],
  prologue: ["at", "in", "zone", "quests", "inn", "played"],
  died: ["foe", "at", "in"],
  epitaph: ["name", "who", "level", "in", "at", "zone", "foe"],
  campfire: ["at", "in"],
  night: ["at", "in"],
  wake: ["at", "in"],
  rest: ["place", "at", "in"],
  power: ["spell"],
  mount: [],
  riding: [],
  petdied: ["pet", "at", "in"],
  remembrance: ["name", "played", "quests", "kills", "rare", "dungeon", "zones"],
  farewell: ["name"],
  // clauses: "I" and up to three of them make a sentence ("I reached
  // Kharanos, took a room at Thunderbrew Distillery and killed a boar.")
  "c-place": ["place"],
  "c-travel": ["place"],
  "c-return": ["place"],
  "c-kill": ["foe"],
  "c-first": ["kind"],
  "c-elite": ["foe"],
  "c-deed-kill": ["n", "foes", "giver", "ender"],
  "c-deed-item": ["n", "thing", "giver", "ender"],
  "c-deed-task": ["task", "giver", "ender"],
  "c-deed-word": ["giver", "ender"],
  "c-deliver": ["thing", "ender", "giver"],
  "c-quest": ["giver"],
  "c-trainer": ["spells"],
  "c-skill": ["skill", "rank"],
  "c-prof": ["prof", "rank"],
  "c-gear": ["item"],
  "c-loot": ["item"],
  "c-group": ["mates"],
  "c-report": ["ender"],
  "c-wear-found": [],
  "c-raid": ["n"],
  "c-made": ["things"],
  "pvp-one": ["name", "who", "at", "in"],
  "pvp-many": ["n", "side", "at", "in"],
  revived: ["by", "graveyard", "time", "at", "in"],
  summit: ["level", "at", "in"],
  "c-inn": ["inn"],
  "c-boss": ["boss", "dungeon"],
  "c-tame": ["pet", "family"],
  // remarks a routine clause may end with (Writer.lua's ROUTINE)
  "r-foe": [], "r-first": [], "r-item": [], "r-task": [], "r-gear": [], "r-lesson": [], "r-road": [], "r-inn": [],
  "r-company": [],
};
const VOICE = ["home", "kin", "faith", "weapon"];
const TAGS = ["home", "ally", "foe", "neutral", "night", "hc", "high", "low", "first", "elite", "lots", "many", "slow", "quick",
  "foe", "fall", "drowning", "lava", "nature", "beast", "people", "player", "inside", "rest", "fire", "last", "one", "aside", "plain", "back", "done", "grouped", "held", "plural", "trophy", "corpse", "healer", "self", "known", "more", "again", "onward", "teeth", "mechanical", "cloth", "meat", "explore", "escort", "new", "made", "form", "demon", "steed"];
const RACES = ["Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Orc", "Troll", "Tauren", "Scourge", "BloodElf", "Skyborne"];
const ROUTINE = new Set("deed-kill deed-item deed-task deed-word deliver report kill first gear trainer inn travel return place group skill prof".split(" ").map((kind) => `c-${kind}`));
// The recap's kinds: one sentence of the recap holds a thought, the others are plain.
const RECAP = new Set(["quests-many", "kills", "kills-two", "closing"]);
const CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"];
const tagOk = (t: string) => {
  const [k, v] = t.replace(/^!/, "").split(":");
  if (v === undefined) return TAGS.includes(k);
  return (k === "race" && RACES.includes(v)) || (k === "class" && CLASSES.includes(v)) ||
    (k === "faction" && ["alliance", "horde"].includes(v)) || (k === "client" && CLIENTS.includes(v));
};

type Sentence = { text: string; tags: string[] };
type Parsed = { meta: string; sentences: Sentence[] };

/** One writing file: its front matter and its lines, checked. `kind`: the slots and rules to check against. */
function parseFile(file: string, kind: string | null): Parsed | null {
  const src = readFileSync(file, "utf8");
  // eslint-disable-next-line no-control-regex -- any character outside ASCII, on purpose
  const odd = src.match(/[^\x00-\x7f]/);
  if (odd) fail(file, `non-ASCII character "${odd[0]}": use ' and plain quotes`);
  const m = src.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) {
    fail(file, "no front matter");
    return null;
  }
  const own = kind ?? m[1].match(/^kind:\s*(\S+)/m)?.[1] ?? null;
  const sentences: Sentence[] = [];
  for (const line of m[2].split("\n")) {
    const l = line.match(/^- (?:\[([^\]]*)\]\s*)?(.+)$/);
    if (!l) continue;
    const sentence = { text: l[2].trim(), tags: (l[1] ?? "").split(/\s+/).filter(Boolean) };
    for (const t of sentence.tags) if (!tagOk(t)) fail(file, `unknown tag [${t}]: ${sentence.text}`);
    const slots = own === "scenery" ? [] : (KINDS[own ?? ""] ?? []);
    for (const [, slot] of sentence.text.matchAll(/\{([^}]*)\}/g))
      if (!slots.includes(slot) && !VOICE.includes(slot)) fail(file, `{${slot}} is not a slot of ${own}: ${sentence.text}`);
    if (own?.startsWith("c-") || own?.startsWith("r-")) {
      if (!/^[a-z]/.test(sentence.text) || /[.!?;:]$/.test(sentence.text)) fail(file, `a clause starts in lower case, with no stop: ${sentence.text}`);
    } else if (!/[.!?]"?$/.test(sentence.text)) fail(file, `no full stop: ${sentence.text}`);
    if (sentences.some((o) => o.text === sentence.text)) fail(file, `twice: ${sentence.text}`);
    sentences.push(sentence);
  }
  if (!sentences.length) fail(file, "no sentence");
  if (own && ROUTINE.has(own) && kind === null && sentences.length < 7) fail(file, "a routine kind needs at least seven ways to say it");
  if (own?.startsWith("r-")) {
    const least = kind === null ? 12 : 8; // shared, a race's own
    if (sentences.length < least) fail(file, `a pool of remarks needs at least ${least}`);
    for (const s of sentences) if (/^(and|but|then)\b/.test(s.text)) fail(file, `a remark follows a comma, not a conjunction: ${s.text}`);
    // a lesson may be several spells: "it" only for one ("…, keen to try it")
    if (own === "r-lesson")
      for (const s of sentences)
        if (/\b(it|its)\b/i.test(s.text) && !s.tags.includes("one")) fail(file, `"it" in a lesson's remark needs [one]: ${s.text}`);
    // after my own action ("I took up tailoring, …"), a past participle reads as
    // a second verb missing its "and": "…, practised until my arms complained"
    if (/^r-(road|lesson|company|task)$/.test(own))
      for (const s of sentences) {
        const first = s.text.split(/[ ,]/)[0];
        if (/^(\w+ed|done|made|found|built|taught|brought|kept|learnt)$/.test(first) && !/^(un\w+|pleased|surprised|relieved|tired|interested)$/.test(first))
          fail(file, `a remark after my own action can't start with a past participle: ${s.text}`);
      }
  }
  if (sentences.some((s) => s.tags.includes("plain")) && !(own && RECAP.has(own))) fail(file, "[plain] marks a recap's plain sentence");
  if (own && RECAP.has(own) && kind === null && sentences.filter((s) => s.tags.includes("plain")).length < 5)
    fail(file, "a recap kind needs at least five [plain] sentences");
  return { meta: m[1], sentences };
}

const mdFiles = (dir: string) => (existsSync(dir) ? readdirSync(dir).sort().filter((f) => f.endsWith(".md")) : []);

// The shared writing.
const kinds = new Map<string, Sentence[]>();
for (const f of mdFiles(WRITING)) {
  const file = join(WRITING, f);
  const parsed = parseFile(file, null);
  if (!parsed) continue;
  const kind = parsed.meta.match(/^kind:\s*(\S+)/m)?.[1];
  if (!kind) { fail(file, "kind: missing"); continue; }
  if (kinds.has(kind)) fail(file, `kind ${kind} twice`);
  if (!KINDS[kind]) fail(file, `unknown kind ${kind}`);
  kinds.set(kind, parsed.sentences);
}
for (const kind of Object.keys(KINDS)) if (!kinds.has(kind)) errors.push(`writing/${kind}.md: missing`);

// Each race's own voice: writing/voices/<Race>/<kind>.md.
const VOICES_DIR = join(WRITING, "voices");
const voices = new Map<string, Map<string, Sentence[]>>();
for (const race of existsSync(VOICES_DIR) ? readdirSync(VOICES_DIR).sort() : []) {
  if (race.startsWith(".")) continue;
  if (!RACES.includes(race)) { errors.push(`writing/voices/${race}: not a race (${RACES.join(", ")})`); continue; }
  const own = new Map<string, Sentence[]>();
  for (const f of mdFiles(join(VOICES_DIR, race))) {
    const file = join(VOICES_DIR, race, f);
    const kind = f.replace(/\.md$/, "");
    if (!KINDS[kind]) { fail(file, `unknown kind ${kind}`); continue; }
    const parsed = parseFile(file, kind);
    if (parsed) own.set(kind, parsed.sentences);
  }
  voices.set(race, own);
}

// The voices must stay apart: a remark's opening (its first three words) is
// shared by two races at most, and a pool holds two stock feelings ("glad",
// "pleased", "relieved", "curious", "surprised") at most. A race's remarks
// are its own way of seeing, not one template with a different tail.
const STOCK = /\b(glad|pleased|relieved|curious|surprised)\b/i;
const openings = new Map<string, Set<string>>();
for (const [race, own] of voices) {
  for (const [kind, sentences] of own) {
    if (!kind.startsWith("r-")) continue;
    const stock = sentences.filter((s) => STOCK.test(s.text));
    if (stock.length > 2) errors.push(`writing/voices/${race}/${kind}.md: ${stock.length} stock feelings (two at most): ${stock.map((s) => s.text).join(" | ")}`);
    for (const s of sentences) {
      const opening = s.text.toLowerCase().split(/\s+/).slice(0, 3).join(" ");
      openings.set(opening, (openings.get(opening) ?? new Set()).add(race));
    }
  }
}
for (const [opening, races] of openings)
  if (races.size > 2) errors.push(`writing/voices: "${opening}…" opens remarks of ${races.size} races (${[...races].join(", ")}): two at most`);

// The places: writing/scenery/<place>.md.
type Place = { place: string; type: string; home: string[]; faction: string; sentences: Sentence[] };
const SCENERY_DIR = join(WRITING, "scenery");
const scenery: Place[] = [];
for (const f of mdFiles(SCENERY_DIR)) {
  const file = join(SCENERY_DIR, f);
  const parsed = parseFile(file, "scenery");
  if (!parsed) continue;
  const get = (k: string) => parsed.meta.match(new RegExp(`^${k}:\\s*(.+)$`, "m"))?.[1].trim();
  const place = get("place");
  const type = get("type");
  const faction = get("faction");
  const home = (get("home") ?? "").split(/\s+/).filter(Boolean);
  if (!place) fail(file, "place: missing");
  if (!type || !["zone", "town", "dungeon"].includes(type)) fail(file, "type: zone, town or dungeon");
  if (!faction || !["alliance", "horde", "neutral"].includes(faction)) fail(file, "faction: alliance, horde or neutral");
  for (const r of home) if (!RACES.includes(r)) fail(file, `home: ${r} is not a race`);
  if (scenery.some((p) => p.place === place)) fail(file, `place ${place} twice`);
  if (place && type && faction) scenery.push({ place, type, home, faction, sentences: parsed.sentences });
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}

const lua = (list: Sentence[], client: string, indent: string) => {
  const mine = (s: Sentence) => !s.tags.some((t) => t.startsWith("client:") && t !== `client:${client}`);
  return list
    .filter(mine)
    .map((s) => {
      const tags = s.tags.filter((t) => !t.startsWith("client:"));
      return `${indent}{ ${q(s.text)}${tags.length ? `, tags = { ${tags.map(q).join(", ")} }` : ""} },`;
    })
    .join("\n");
};

function luaFor(client: string) {
  const writing = [...kinds.entries()].map(([kind, list]) => `    [${q(kind)}] = {\n${lua(list, client, "      ")}\n    },`).join("\n");
  const voiceBody = [...voices.entries()]
    .map(([race, own]) => `    [${q(race)}] = {\n${[...own.entries()].map(([kind, list]) => `      [${q(kind)}] = {\n${lua(list, client, "        ")}\n      },`).join("\n")}\n    },`)
    .join("\n");
  const placeBody = scenery
    .map(
      (p) =>
        `    [${q(p.place)}] = { type = ${q(p.type)}, faction = ${q(p.faction)}, home = { ${p.home.map((r) => `[${q(r)}] = true`).join(", ")} },\n${lua(p.sentences, client, "      ")}\n    },`,
    )
    .join("\n");
  return `-- Generated by scripts/build.ts from writing/: edit those, not this file.
local _, ns = ...
ns.data = {
  client = ${q(client)},
  writing = {
${writing}
  },
  voices = {
${voiceBody}
  },
  scenery = {
${placeBody}
  },
}
`;
}

let stale = false;
for (const g of GAMES) {
  const lua = luaFor(g.client);
  if (process.argv.includes("--check")) {
    const current = existsSync(g.out) ? readFileSync(g.out, "utf8") : "";
    if (current !== lua) { console.error(`✗ ${g.out} is out of date: run bun scripts/build.ts`); stale = true; }
    else console.log(`✓ ${g.out} up to date (${kinds.size} kinds)`);
  } else {
    writeFileSync(g.out, lua);
    console.log(`✓ ${g.client}: ${kinds.size} kinds → ${g.out}`);
  }
}
if (stale) process.exit(1);
