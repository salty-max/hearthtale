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
 * (kinds c-*: "found {item}") starts in lower case, with no stop.
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
 *   client: forever            a place of one game only (optional)
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

// Each kind and the slots the writer (Diary.lua, Lines.lua) fills for it.
const KINDS: Record<string, string[]> = {
  // where an entry begins (a life's first page: beginning)
  beginning: ["where", "at", "in"],
  opening: ["where", "at", "in"],
  // a character met mid-life: what came before the journal
  prologue: ["at", "in", "zone", "quests", "inn", "played"],
  // dangers: the closest call, a death, a death and the way back right after it
  "close-light": ["foe", "at", "in"],
  "close-deep": ["foe", "at", "in"],
  died: ["foe", "at", "in"],
  "died-back": ["foe", "by", "graveyard", "at", "in"],
  // a dungeon's or a raid's last master; a raid
  "boss-final": ["boss", "dungeon"],
  "c-raid": ["n"],
  // a fine find (writing it as a clause: "I found {item}")
  "c-loot": ["item"],
  // a trade taken up
  "c-prof": ["prof", "rank", "arank", "began"],
  // a class's own quest turned in: what it taught ({pet}: "an imp", for a summoning)
  "class-reward": ["giver", "spell", "pet"],
  // a spell with a line of its own ([spell:Life Tap]), when learned
  lesson: ["spell"],
  // the firsts of a life
  power: ["spell"],
  bag: ["item", "slots"],
  gold: [],
  demon: ["pet", "demon"],
  shift: [],
  mount: ["mount"],
  // a life's first flight: from where, to where
  flight: ["from", "to"],
  riding: [],
  petdied: ["pet", "at", "in"],
  // players of the other side slain in the open
  "pvp-one": ["name", "who", "at", "in"],
  "pvp-many": ["n", "side", "at", "in"],
  // how an entry ends: a rest, a night outdoors or indoors, the journey's end
  rest: ["place", "at", "in"],
  night: ["at", "in"],
  "night-in": ["at", "in"],
  summit: ["level", "at", "in"],
  // a Hardcore death: the epitaph, in the third person
  epitaph: ["name", "who", "level", "in", "at", "zone", "foe"],
  remembrance: ["name", "played", "quests", "kills", "rare", "dungeon", "zones"],
  farewell: ["name"],
  // the entry's own kinds (Diary.lua)
  "d-land": ["lands"],
  "d-powers": ["spells"],
  "d-foes": ["foes"],
  "d-deaths": ["times"],
  "d-dungeon": ["dungeon", "mates"],
  "d-company": ["mates", "at"],
  "d-chores": [],
  "d-close": ["land"],
  // the stretch's story: what the work that mattered was for (writing/why/)
  "d-why": ["why", "who"],
  "d-why2": ["why", "why2"],
  // a second climax, too long to share the first's sentence
  "d-why-also": ["why", "where"],
  // a pet or a demon named again, at my side through a stretch
  "d-pet": ["pet", "where"],
  // continuity: a foe of a name that killed me or nearly did, beaten later
  "d-revenge": ["foe", "at"],
  // a hunter's companion tamed (the first, then another); a shaman's
  // initiation into an element; a word on the stretch's story
  "d-tame": ["pet", "family"],
  // a piece of gear worn for the first time (blue and better, or made by me, below level 30)
  "d-gear": ["item"],
  // a specialization taken: the way a life took ({was}: the one before)
  "d-spec": ["spec", "was"],
  // what my hands made, new to them, when no trade was told
  "d-made": ["things"],
  // a spell that defines the class (a warrior's stances, a priest's own people's prayers, a mage's way home)
  "d-calling": ["spell", "place"],
  // a stop by a campfire: the first of a life, one shared, a camp's; or the one an entry ends at ([last])
  "d-camp": ["mates", "at", "in"],
  "d-initiation": [],
  "d-react": [],
};
const VOICE = ["home", "kin", "faith", "weapon"];
const TAGS = ["after", "again", "air", "ally", "aquatic", "away", "bear", "beast", "camp", "capital", "cat", "company", "cenarion",
  "corpse", "delve", "demon", "dropped", "drowning", "earth", "elite", "fall", "felguard", "felhunter", "felsteed", "fire", "horse", "kodo", "mechanostrider", "ram", "raptor", "saber", "skeletal", "warhorse", "wolf", "first", "found", "made", "held", "trinket",
  "flight", "foe", "form", "grouped", "hard", "hc", "healer", "high", "highborne", "home", "hosts", "imp", "inside",
  "known", "last", "late", "lava", "master", "leper", "looted", "low", "moonkin", "moved", "nature", "near", "neutral", "new", "night",
  "one", "people", "player", "plural", "rank", "rescue", "self", "settled", "steed", "succubus", "summon", "portal", "teleport", "thread", "town",
  "travel", "tree", "two", "undead", "used", "victim", "villain", "voidwalker", "water", "who", "zalazane", "since", "fell", "died", "reviver", "it", "old", "change"];
const RACES = ["Human", "Dwarf", "NightElf", "Gnome", "Orc", "Troll", "Tauren", "Scourge", "Skyborne"];
const CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"];
const tagOk = (t: string) => {
  const bare = t.replace(/^!/, ""), colon = bare.indexOf(":");
  const [k, v] = colon < 0 ? [bare, undefined] : [bare.slice(0, colon), bare.slice(colon + 1)];
  if (v === undefined) return TAGS.includes(k);
  return (k === "race" && RACES.includes(v)) || (k === "class" && CLASSES.includes(v)) ||
    (k === "faction" && ["alliance", "horde"].includes(v)) || (k === "client" && CLIENTS.includes(v)) ||
    (k === "spell" && /^[A-Z][A-Za-z':_]+$/.test(v)) || // a spell's name, its spaces "_": [spell:Life_Tap]
    (k === "spec" && /^[A-Z][A-Za-z_]+$/.test(v)); // a specialization's: [spec:Beast_Mastery]
};

// (the kinds that tell a spell or a power learned: its use only as [used])
const SPELL_KINDS = ["lesson", "d-calling", "d-powers", "power", "class-reward", "d-initiation", "shift", "demon", "d-spec"];

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
    // (a life the record can't know: no family, childhood, past trade or possessions of the narrator's)
    if (/\b(all my life|when I was young|as a child|in my youth|my (father|mother|brother|sister|parents|family|workshop|tools|old job|former))\b/i.test(sentence.text))
      fail(file, `a personal history the record can't know: ${sentence.text}`);
    // (nor a habit, a comparison with all that came before, a spell put to use: the
    // record has no such thing; a spell cast before its stretch closed is [used])
    if (/\b(more than once|again and again|time and again|best \w+ (yet|ever)|best \w+ my hands|finer than anything|better than anything)\b/i.test(sentence.text))
      fail(file, `a claim the record can't back: ${sentence.text}`);
    if (SPELL_KINDS.includes(own ?? "") && !sentence.tags.includes("used") &&
        /\b(put (it|them) to (work|use)|answered the first time|first time I (used|cast|called)|into every fight|has never been easier|have shrunk|found there was|learned how much)\b/i.test(sentence.text))
      fail(file, `a spell put to use, which only a cast shows ([used]): ${sentence.text}`);
    if (own?.startsWith("c-")) {
      if (!/^[a-z]/.test(sentence.text) || /[.!?;:]$/.test(sentence.text))
        fail(file, `a clause starts in lower case, with no stop: ${sentence.text}`);
    } else if (!/[.!?]"?$/.test(sentence.text)) fail(file, `no full stop: ${sentence.text}`);
    if (sentences.some((o) => o.text === sentence.text)) fail(file, `twice: ${sentence.text}`);
    sentences.push(sentence);
  }
  if (!sentences.length) fail(file, "no sentence");
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

// The places: writing/scenery/<place>.md.
type Place = { place: string; type: string; home: string[]; faction: string; client?: string; sentences: Sentence[] };
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
  const client = get("client"); // (a place of one game only: Forever's Zephras Isle)
  if (!place) fail(file, "place: missing");
  if (!type || !["zone", "town", "dungeon"].includes(type)) fail(file, "type: zone, town or dungeon");
  if (!faction || !["alliance", "horde", "neutral"].includes(faction)) fail(file, "faction: alliance, horde or neutral");
  for (const r of home) if (!RACES.includes(r)) fail(file, `home: ${r} is not a race`);
  if (scenery.some((p) => p.place === place)) fail(file, `place ${place} twice`);
  if (client && !CLIENTS.includes(client)) fail(file, `client: ${CLIENTS.join(" or ")}`);
  if (place && type && faction) scenery.push({ place, type, home, faction, client, sentences: parsed.sentences });
}

// What a quest's work was for: writing/why/*.md, "- <id> <weight> [<subject>] | <phrase>",
// from the game's own quest texts, for the diary (Diary.lua): a phrase that
// reads after "I spent the better part of it …", weighed 1 (an errand) to 3
// (a story's climax).
const WHY_DIR = join(WRITING, "why");
// (a story's subject: a villain's end, a victim's release (the corrupted, the
// cursed, the mad put down or laid to rest), a rescue, a great beast, the
// dead, demons; "none": nothing to say about it)
const SUBJECTS = ["villain", "victim", "rescue", "beast", "undead", "demon", "none"];
const why = new Map<number, { w: number; text: string; deed: string; subject?: string; client?: string }>(); // (forever-*.md: Forever's own quests)
// The deed itself, as the diary tells it: "killing Hogger, …" is "killed
// Hogger, …", read after "I", the first verb and those joined to it ("and
// bringing", ", then meeting") in the past; a form the English word list
// doesn't know fails the build (IRREGULAR, or reword the why).
const ENGLISH = new Set<string>(JSON.parse(readFileSync(join(import.meta.dir, "..", "node_modules", "an-array-of-english-words", "index.json"), "utf8")));
const IRREGULAR: Record<string, string> = {
  bearing: "bore", beating: "beat", becoming: "became", binding: "bound", blowing: "blew", breaking: "broke",
  bringing: "brought", building: "built", buying: "bought", catching: "caught", choosing: "chose", coming: "came",
  cutting: "cut", dealing: "dealt", digging: "dug", doing: "did", drawing: "drew", drinking: "drank", driving: "drove",
  dying: "died", eating: "ate", feeding: "fed", fighting: "fought", finding: "found", flying: "flew", freezing: "froze",
  getting: "got", giving: "gave", going: "went", growing: "grew", having: "had", hearing: "heard", hiding: "hid",
  holding: "held", keeping: "kept", laying: "laid", leading: "led", leaving: "left", lending: "lent", letting: "let",
  lighting: "lit", making: "made", meeting: "met", overcoming: "overcame", paying: "paid", putting: "put", reading: "read",
  repaying: "repaid", riding: "rode", ridding: "rid", rising: "rose", running: "ran", seeing: "saw", seeking: "sought",
  selling: "sold", sending: "sent", setting: "set", shooting: "shot", shrinking: "shrank", shutting: "shut", sitting: "sat",
  slaying: "slew", speaking: "spoke", spending: "spent", standing: "stood", stealing: "stole", striking: "struck",
  stringing: "strung", swearing: "swore", swimming: "swam", taking: "took", teaching: "taught", tearing: "tore",
  telling: "told", throwing: "threw", waking: "woke", winning: "won", polymorphing: "polymorphed", sowing: "sowed",
  sewing: "sewed", leaping: "leapt", lying: "lay", fleeing: "fled", forgetting: "forgot", forgiving: "forgave",
  understanding: "understood", undertaking: "undertook", withstanding: "withstood", rebuilding: "rebuilt", feeling: "felt",
  wearing: "wore", sinking: "sank", spinning: "spun", sweeping: "swept", sleeping: "slept", shaking: "shook", saying: "said",
};
// (-ing words that are no verb here)
const NOT_VERBS = new Set(["bring", "spring", "string", "thing", "king", "ring", "wing", "sling", "sting", "cunning", "willing",
  "evening", "morning", "nothing", "something", "anything", "everything", "being", "during", "ceiling", "darling"]);
// The deed: the why's verbs in the past, the first and those joined to it
// ("slaying X, and taking Y"); a gerund after a preposition ("wanted for
// murdering Forsaken and ambushing supplies"), or after a comma ("…,
// charging the rod and driving it") or a noun ("the shark circling Ratchet's
// docks and attacking sailors"), keeps what " and" joins to it.
const JOINED = /(^|, and then |, and so |, and |, then | and then | then | and | or |\b(?:for|by|after|before|without|from|of|in|on|about|into|while|when|since) |, | (?=[a-z]+ing (?:the |a |an |his |her |their |its |away |off |up |out |down |[A-Z])))([a-z]+ing)\b/g;
const ING_NOUNS = new Set(["summoning", "building", "clothing", "offering", "painting", "gathering", "teaching", "writing", "warning"]);
const JOINS = new Set(["", ", and then ", ", and so ", ", and ", ", then ", " and then ", " then ", " and ", " or "]);
function deedOf(text: string, file: string): string {
  let main = true; // (what a bare " and" joins is still the deed's own verb)
  return text.replace(JOINED, (all: string, sep: string, g: string) => {
    if (NOT_VERBS.has(g)) return all;
    if (!JOINS.has(sep)) {
      if (ING_NOUNS.has(g)) return all; // ("the circle of summoning": a thing)
      main = false; // ("for murdering": its own " and …" follows it)
      return all;
    }
    if (sep !== "" && !sep.startsWith(",") && !main) return all;
    main = true;
    let past = IRREGULAR[g];
    if (!past) {
      const stem = g.slice(0, -3);
      past = /[^aeiou]y$/.test(stem) ? stem.slice(0, -1) + "ied" : /e$/.test(stem) ? stem + "d" : stem + "ed";
      if (!ENGLISH.has(past)) fail(file, `"${g}": no past form known (add it to IRREGULAR, or reword): ${text}`);
    }
    return sep + past;
  });
}
for (const f of mdFiles(WHY_DIR)) {
  const file = join(WHY_DIR, f);
  const src = readFileSync(file, "utf8");
  // eslint-disable-next-line no-control-regex -- any character outside ASCII, on purpose
  const odd = src.match(/[^\x00-\x7f]/);
  if (odd) fail(file, `non-ASCII character "${odd[0]}": use ' and plain quotes`);
  if (!/^---\nkind: why\n---\n/.test(src)) { fail(file, "front matter: kind: why"); continue; }
  for (const line of src.split("\n")) {
    if (!line.startsWith("- ")) continue;
    const m = line.match(/^- (\d+) ([123]) (?:([a-z]+) )?\| (.+)$/);
    if (!m) { fail(file, `not "- <id> <weight> [<subject>] | <phrase>": ${line}`); continue; }
    const [id, w, subject, text] = [Number(m[1]), Number(m[2]), m[3], m[4]];
    // (what a weighty story was, for a word on it: said, never guessed)
    if (w >= 2 && !subject) fail(file, `a why weighed ${w} says what it was (${SUBJECTS.join(", ")}): ${line}`);
    if (subject && !SUBJECTS.includes(subject)) fail(file, `"${subject}" is no subject (${SUBJECTS.join(", ")}): ${line}`);
    const first = text.split(" ")[0];
    if (!/^[a-z][a-z-]*ing$/.test(first)) fail(file, `a why starts with a verb in -ing, in lower case: ${text}`);
    if (/[.!?;:]$/.test(text)) fail(file, `a why has no final punctuation: ${text}`);
    if (text.length > 150) fail(file, `a why of ${text.length} characters (150 at most): ${text}`);
    if (/\b(you|your|I|quest|quests|objective)\b/.test(text)) fail(file, `no "you", "I", "quest" or "objective" in a why: ${text}`);
    if (/[$<>[\]{}"]/.test(text)) fail(file, `no $, <>, [], {} or double quotes in a why: ${text}`);
    if (why.has(id)) fail(file, `quest ${id} twice`);
    why.set(id, { w, text, deed: deedOf(text, file), subject: subject === "none" ? undefined : subject, client: f.startsWith("forever-") ? "forever" : undefined });
  }
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
    .filter((p) => !p.client || p.client === client)
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
  why = {
${[...why.entries()].filter(([, v]) => !v.client || v.client === client).sort((a, b) => a[0] - b[0]).map(([id, v]) => `    [${id}] = { ${v.w}, ${q(v.deed)}${v.w >= 2 ? `, ${q(v.subject ?? "")}` : ""} },`).join("\n")}
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
