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
  "close-light": ["foe", "hp", "at", "in"],
  "close-deep": ["foe", "hp", "at", "in"],
  dungeon: ["dungeon", "boss", "mates"],
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
  "c-quest": ["quest", "giver"],
  "c-trainer": ["spells"],
  "c-skill": ["skill", "rank"],
  "c-prof": ["prof", "rank"],
  "c-gear": ["item"],
  "c-loot": ["item"],
  "c-group": ["mates"],
  "c-inn": ["inn"],
  "c-boss": ["boss", "dungeon"],
  "c-tame": ["pet", "family"],
};
const VOICE = ["home", "kin", "faith", "weapon"];
const TAGS = ["night", "hc", "high", "low", "first", "elite", "lots", "many", "slow", "quick",
  "foe", "fall", "drowning", "lava", "nature", "beast", "people", "player", "inside", "rest", "fire", "last", "one", "aside", "new", "made", "form", "demon", "steed"];
const RACES = ["Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Orc", "Troll", "Tauren", "Scourge", "BloodElf"];
const CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"];
const tagOk = (t: string) => {
  const [k, v] = t.replace(/^!/, "").split(":");
  if (v === undefined) return TAGS.includes(k);
  return (k === "race" && RACES.includes(v)) || (k === "class" && CLASSES.includes(v)) ||
    (k === "faction" && ["alliance", "horde"].includes(v)) || (k === "client" && CLIENTS.includes(v));
};

type Sentence = { text: string; tags: string[] };
const kinds = new Map<string, Sentence[]>();
for (const f of existsSync(WRITING) ? readdirSync(WRITING).sort() : []) {
  if (!f.endsWith(".md")) continue;
  const file = join(WRITING, f);
  const src = readFileSync(file, "utf8");
  const odd = src.match(/[^\x00-\x7f]/);
  if (odd) fail(file, `non-ASCII character "${odd[0]}": use ' and plain quotes`);
  const m = src.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) { fail(file, "no front matter"); continue; }
  const kind = m[1].match(/^kind:\s*(\S+)/m)?.[1];
  if (!kind) { fail(file, "kind: missing"); continue; }
  if (kinds.has(kind)) fail(file, `kind ${kind} twice`);
  const sentences: Sentence[] = [];
  for (const line of m[2].split("\n")) {
    const s = line.match(/^- (?:\[([^\]]*)\]\s*)?(.+)$/);
    if (!s) continue;
    const sentence = { text: s[2].trim(), tags: (s[1] ?? "").split(/\s+/).filter(Boolean) };
    for (const t of sentence.tags) if (!tagOk(t)) fail(file, `unknown tag [${t}]: ${sentence.text}`);
    for (const [, slot] of sentence.text.matchAll(/\{([^}]*)\}/g))
      if (!(KINDS[kind] ?? []).includes(slot) && !VOICE.includes(slot)) fail(file, `{${slot}} is not a slot of ${kind}: ${sentence.text}`);
    if (kind.startsWith("c-")) {
      if (!/^[a-z]/.test(sentence.text) || /[.!?;:]$/.test(sentence.text)) fail(file, `a clause starts in lower case, with no stop: ${sentence.text}`);
    } else if (!/[.!?]"?$/.test(sentence.text)) fail(file, `no full stop: ${sentence.text}`);
    if (sentences.some((o) => o.text === sentence.text)) fail(file, `twice: ${sentence.text}`);
    sentences.push(sentence);
  }
  if (!sentences.length) fail(file, "no sentence");
  if (!KINDS[kind]) fail(file, `unknown kind ${kind}`);
  kinds.set(kind, sentences);
}
for (const kind of Object.keys(KINDS)) if (!kinds.has(kind)) errors.push(`writing/${kind}.md: missing`);
if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}

function luaFor(client: string) {
  const mine = (s: Sentence) => !s.tags.some((t) => t.startsWith("client:") && t !== `client:${client}`);
  const body = [...kinds.entries()]
    .map(([kind, list]) => `    [${q(kind)}] = {\n${list.filter(mine).map((s) => `      { ${q(s.text)}${s.tags.filter((t) => !t.startsWith("client:")).length ? `, tags = { ${s.tags.filter((t) => !t.startsWith("client:")).map(q).join(", ")} }` : ""} },`).join("\n")}\n    },`)
    .join("\n");
  return `-- Generated by scripts/build.ts from writing/: edit those, not this file.
local _, ns = ...
ns.data = {
  client = ${q(client)},
  writing = {
${body}
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
