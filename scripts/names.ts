// How the game itself writes each place and creature: "the Dagger Hills" or
// "Moonbrook", "Hogger" or "a Defias Thug" or "the Defias Messenger", counted
// over all its quest texts and what its creatures say (.cache/audit, from
// `bun scripts/audit-data.ts`), into addon/Hearthtale/Names.lua for the
// writer. Where the game never writes a name, the writer's own rules decide.
//   bun scripts/names.ts
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const DIR = path.join(import.meta.dir, "..", ".cache", "audit");
const OUT = path.join(import.meta.dir, "..", "addon", "Hearthtale", "Names.lua");
const data = JSON.parse(readFileSync(path.join(DIR, "names.json"), "utf8")) as {
  zones: string[];
  creatures: { name: string; spawns: number; npc: number }[];
  questItems: { name: string; most: number }[];
  items: string[];
};
const corpus = readFileSync(path.join(DIR, "corpus.txt"), "utf8");

// English words (macOS's list), to tell plain words from names.
const DICT = "/usr/share/dict/words";
const dictionary = existsSync(DICT)
  ? new Set(readFileSync(DICT, "utf8").split("\n").filter((w) => /^[a-z]+$/.test(w)))
  : null;
const common = (word: string) => {
  const w = word.toLowerCase().replace(/'s$/, "");
  if (!dictionary || dictionary.has(w) || dictionary.has(w.replace(/s$/, ""))) return true;
  for (let i = 4; i <= w.length - 4; i++) if (dictionary.has(w.slice(0, i)) && dictionary.has(w.slice(i))) return true;
  return false;
};
// given names: in the word list only with a capital ("Patrick", "Johnson")
const given = existsSync(DICT)
  ? new Set(readFileSync(DICT, "utf8").split("\n").filter((w) => /^[A-Z][a-z]+$/.test(w) && !dictionary!.has(w.toLowerCase())).map((w) => w.toLowerCase()))
  : new Set<string>();

// A name used as a name: followed by punctuation, the end, or a small word
// ("in Moonbrook,", "the Dagger Hills to the south") - not as an adjective
// ("the Westfall farmers") or inside a longer name ("the Westfall Brigade").
const AFTER = "(?=[.,;:!?'\")]|$| (?:and|or|to|in|is|was|are|were|for|where|that|which|until|before|near|with|from|by|at|on|has|had|will|lies|lie|of|if|but|so|as|when|while|again|now|himself|herself|itself|yourself|there|here)\\b)";
const DETERMINERS = new Set(["a", "an", "the", "this", "that", "these", "those", "every", "each", "some", "any", "another", "one", "no"]);

// The text read once: its words, where they start; the names, by first word.
const words = [...corpus.matchAll(/[A-Za-z][A-Za-z'.-]*/g)].map((m) => ({ at: m.index!, word: m[0] }));
const after = new RegExp(AFTER, "y");
const counted = new Map<string, { the: number; a: number; bare: number }>();
function count(names: string[]) {
  const byFirst = new Map<string, string[]>();
  for (const n of names) {
    const first = n.match(/^[A-Za-z][A-Za-z'.-]*/)?.[0];
    if (first) byFirst.set(first, [...(byFirst.get(first) ?? []), n]);
    counted.set(n, { the: 0, a: 0, bare: 0 });
  }
  words.forEach((w, i) => {
    for (const name of byFirst.get(w.word.replace(/[.']+$/, "")) ?? byFirst.get(w.word) ?? []) {
      if (!corpus.startsWith(name, w.at)) continue;
      after.lastIndex = w.at + name.length;
      if (!after.test(corpus)) continue;
      const c = counted.get(name)!;
      const prev = words[i - 1];
      const gap = prev ? corpus.slice(prev.at + prev.word.length, w.at) : "\n";
      if (/\d/.test(gap)) { c.a++; continue } // "Kill 10 Gordunni Shaman": a count, not a name
      if (!prev || gap !== " ") { c.bare++; continue } // starts a text, or after punctuation
      const before = prev.word.toLowerCase();
      if (before === "the") c.the++;
      else if (DETERMINERS.has(before)) c.a++;
      else if (/^[a-z]/.test(prev.word)) c.bare++; // "kill Hogger", "to Moonbrook"
      // a capitalised word before it is another name around it: no evidence
    }
  });
}
const evidence = (name: string) => counted.get(name) ?? { the: 0, a: 0, bare: 0 };

const placeNames = [...new Set(data.zones)].filter((n) => !/^The /.test(n) && n !== "UNUSED" && n.length >= 3);
const spawnsOf = new Map<string, number>();
// (a creature in several entries, one per phase of a quest, is still one)
for (const c of data.creatures) if (c.name) spawnsOf.set(c.name, Math.max(spawnsOf.get(c.name) ?? 0, c.spawns));
const creatureNames = [...spawnsOf].filter(([n, k]) => k > 0 && !/^The /.test(n) && !/[([]/.test(n)).map(([n]) => n);
count([...placeNames, ...creatureNames]);

const placeThe: string[] = [], placeBare: string[] = [];
for (const name of placeNames) {
  const e = evidence(name);
  if (e.the + e.bare < 2) continue;
  if (e.the > e.bare) placeThe.push(name);
  else placeBare.push(name);
}

// Where the game never writes a place: "the" for a plural ("the Mirage
// Flats"), a river or a sea, "X of Y" from a plain word ("the Altar of the
// Blood God"), and a place named by a plain word ("the Stables").
const FEATURES = new Set(["River", "Sea", "Ocean", "Tram", "Channel", "Highway", "Road"]);
for (const name of placeNames) {
  const e = evidence(name);
  if (e.the + e.bare >= 2 || !dictionary) continue;
  const words = name.split(" ");
  const last = words[words.length - 1];
  const head = name.match(/^(\S+) of /)?.[1];
  const plural = /[^s'u]s$/.test(last) && !/'s$/.test(last) && dictionary.has(last.toLowerCase().replace(/e?s$/, ""))
    || dictionary.has(last.toLowerCase().replace(/s$/, "")) && last.endsWith("s") && !dictionary.has(last.toLowerCase());
  if (plural || FEATURES.has(last) || (head && dictionary.has(head.toLowerCase()))
    || (words.length === 1 && dictionary.has(name.toLowerCase()))) placeThe.push(name);
}

// Creatures fought: a name the game writes bare is a person ("Hogger"); one
// it writes with "the" and that lives once is one of a kind ("the Defias
// Messenger"); the rest take "a".
// Where the game never writes it, a creature that lives once is a person if
// a word of its name is no English word, nor two put together ("kingsnake"),
// and no other creature's name has it: "Bazil Thredd", "Bloodlord Mandokir",
// but not "Bloodscalp Speaker" (a tribe's word) nor "Black Kingsnake".
const uses = new Map<string, number>();
for (const name of creatureNames) for (const w of new Set(name.match(/[A-Za-z][A-Za-z']*/g) ?? [])) uses.set(w, (uses.get(w) ?? 0) + 1);
const personal = (name: string) => {
  const words = name.match(/[A-Za-z][A-Za-z']*/g) ?? [];
  const last = words[words.length - 1] ?? "";
  if (words.length === 1) return true; // one word, living once: "Rattlegore", "Archaedas"
  // a word of its own, a given name, a last word that is no plain word, or a
  // family name no other creature shares ("Tara Coldgaze")
  return words.some((w) => (uses.get(w) === 1 && !common(w)) || given.has(w.toLowerCase())) || !common(last)
    || (words.length > 1 && uses.get(last) === 1 && !dictionary!.has(last.toLowerCase()));
};

const creatureThe: string[] = [], creatureBare: string[] = [];
for (const name of creatureNames) {
  const n = spawnsOf.get(name)!;
  const e = evidence(name);
  // the game's own writing, when it says enough; else, living once, the name itself
  const said = e.the + e.a + e.bare >= 2 && (e.bare > e.the + e.a || e.the > e.bare || e.a > e.bare);
  if (!said) {
    if (n === 1 && dictionary && personal(name)) creatureBare.push(name);
    continue;
  }
  // (living in several places, a name needs stronger evidence to be a person's)
  const person = n === 1 ? e.bare > e.the + e.a : e.bare >= 3 && e.bare >= 2 * (e.the + e.a);
  if (person) creatureBare.push(name);
  else if (n === 1 && e.the > e.a) creatureThe.push(name);
}

// Quest items asked for by the dozen: their plural as the game writes it after
// a number ("8 Tough Wolf Meat", "10 Gnoll Paws", "5 Heads of Bangalash").
const counted_ = new Set<string>();
for (const m of corpus.matchAll(/\b\d+ ([A-Z][\w'-]*(?: (?:of|the|[A-Z][\w'-]*))*)/g)) counted_.add(m[1]);
const singular = (p: string) => {
  const head = p.match(/^(.*?)( of .*)?$/)!;
  const word = head[1];
  return [word.replace(/ies$/, "y"), word.replace(/es$/, ""), word.replace(/s$/, ""), word.replace(/ves$/, "f")]
    .map((w) => w + (head[2] ?? ""));
};
const plurals: [string, string][] = [];
const byName = new Map<string, string[]>();
for (const p of counted_) for (const s of singular(p)) if (s !== p) byName.set(s, [...(byName.get(s) ?? []), p]);
for (const { name, most } of data.questItems) {
  if (most < 2) continue;
  if (counted_.has(name) && !byName.has(name)) plurals.push([name, name]); // uncounted: "8 Tough Wolf Meat"
  else if (byName.has(name)) plurals.push([name, byName.get(name)![0]]);
}

// Items named for a role ("Champion's Dragonhide Helm") take an article like
// any other; items named for a person ("Zanzil's Seal") don't.
// A role owns many items ("Champion's", "General's"); a person a few, and
// shares a word with one of the game's people ("Mr. Smite", "Thrall").
const owners = new Map<string, number>();
for (const name of data.items) for (const m of name.matchAll(/(?:^| )([A-Z][a-z]+)'s /g)) owners.set(m[1], (owners.get(m[1]) ?? 0) + 1);
const people = new Set(creatureBare.flatMap((n) => n.split(" ")));
const roles = new Set<string>();
for (const [owner, n] of owners)
  if (dictionary?.has(owner.toLowerCase()) && !given.has(owner.toLowerCase()) && (n >= 5 || !people.has(owner))) roles.add(owner);

const list = (names: string[]) =>
  names.sort().map((n) => `    [${JSON.stringify(n)}] = true,`).join("\n");
writeFileSync(OUT, `-- Generated by scripts/names.ts: do not edit. How the game itself writes
-- these names, counted over its quest texts and what its creatures say
-- (cmangos classic-db): the places it writes with "the" ("the Dagger Hills")
-- or without, the creatures it writes bare ("Hogger") or as one of a kind
-- ("the Defias Messenger"). The writer's own rules decide the rest.
local _, ns = ...
ns.names = {
  placeThe = {
${list(placeThe)}
  },
  placeBare = {
${list(placeBare)}
  },
  creatureThe = {
${list(creatureThe)}
  },
  creatureBare = {
${list(creatureBare)}
  },
  roles = {
${list([...roles])}
  },
  plural = {
${plurals.sort().map(([n, p]) => `    [${JSON.stringify(n)}] = ${JSON.stringify(p)},`).join("\n")}
  },
}
`);
console.log(`✓ places: ${placeThe.length} with "the", ${placeBare.length} without; creatures: ${creatureBare.length} by name, ` +
  `${creatureThe.length} one of a kind; ${plurals.length} plurals → addon/Hearthtale/Names.lua`);
