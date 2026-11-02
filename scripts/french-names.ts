// The game's French names, for the journal written in French on a French
// client: addon/Hearthtale/FrenchNames_Classic.lua and FrenchNames_Forever.lua
// (each game's own: Classic Era's French client keeps "Ironforge" where
// Forever says "Forgefer"), by the same ids as the English names the record
// keeps (Client_<game>.lua, English_<game>.lua), from wow-data's databases.
//   bun scripts/french-names.ts           (part of bun run audit)
//   bun scripts/french-names.ts --check   fails if the files are not what the
//                                         databases give
// With each name, what French puts before it, as the game's own French texts
// write it (its quest texts, gossip, speech, books, spell and item
// descriptions: counted): a place's article and the preposition it takes
// ("dans la vallée des Frigères", "à Forgefer", "en Durotar", "sur l'île de
// Zephras"), a creature's or a thing's gender ("un jeune troll Frostmane",
// "une harpie"), whether its first word stays a capital in a sentence.
// Where the texts are silent, the head noun's gender as they use it
// elsewhere, then a rule; i18n/frFR/names.json settles the rest by hand
// ({ "<kind>": { "<id>": { "n"?, "g"?, "a"?, "p"? } } }).
// Each entry: { name as a sentence writes it, gender ("m", "f", "mp", "fp"),
// article ("" none, "le", "la", "l'", "les"), preposition (places) }.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import type * as WowDb from "../../wow-data/src/db";
import { familyPath } from "./root";

const { openDb } = (await import(familyPath("wow-data", "src", "db.ts"))) as typeof WowDb;

const ROOT = path.join(import.meta.dir, "..");
const DIR = path.join(ROOT, "addon/Hearthtale");
const CHECK = process.argv.includes("--check");
const GAMES = { classic: "Classic", forever: "Forever" } as const;
type Game = keyof typeof GAMES;

// ── the English names' ids, as the addon holds them ──────────────────────────
// (Client_<game>.lua and English_<game>.lua loaded by luajit, their tables by
// id written out as JSON)
type Ids = Record<string, Record<string, string>>;
function englishIds(game: Game): Ids {
  const lua = `
    local json = dofile(${JSON.stringify(path.join(ROOT, "addon/test/json.lua"))})
    local ns = {}
    assert(loadfile(${JSON.stringify(path.join(DIR, `Client_${GAMES[game]}.lua`))}))("Hearthtale", ns)
    assert(loadfile(${JSON.stringify(path.join(DIR, `English_${GAMES[game]}.lua`))}))("Hearthtale", ns)
    local C, E = ns.client, ns.englishNames()
    local out = {}
    local function put(key, t)
      local o = {}
      for id, n in pairs(t or {}) do
        if type(n) == "table" then n = n.title end
        if type(n) == "string" then o[tostring(id)] = n end
      end
      -- (what the game's tables leave out, behind them)
      local mt = getmetatable(t or {})
      if mt and type(mt.__index) == "table" then
        for id, n in pairs(mt.__index) do
          if type(n) == "string" and not o[tostring(id)] then o[tostring(id)] = n end
        end
      end
      out[key] = o
    end
    for _, k in ipairs({ "areas", "maps", "encounters", "spells", "skillIds", "typeIds", "familyIds", "taxiIds", "treeIds", "specIds", "inside", "mounts" }) do
      put(k, C[k])
    end
    put("creatures", E.creatures)
    put("quests", E.quests)
    put("items", E.items)
    io.write(json(out))
  `;
  const r = Bun.spawnSync(["luajit", "-e", lua]);
  if (r.exitCode !== 0) throw new Error(`luajit: ${r.stderr.toString()}`);
  return JSON.parse(r.stdout.toString());
}

// ── the game's French ────────────────────────────────────────────────────────
const dbs = { classic: openDb("classic"), forever: openDb("forever") };
function frenchOf(game: Game, kind: string): Map<string, { name: string; female: string | null }> {
  const rows = dbs[game]
    .query("SELECT id, name, female FROM name WHERE kind = ? AND locale = 'frFR'")
    .all(kind) as { id: number; name: string; female: string | null }[];
  return new Map(rows.map((r) => [String(r.id), { name: r.name, female: r.female }]));
}
// (the places inside buildings: the kit's list, i18n/frFR/subzones.json)
function insideOf(game: Game): Map<string, string> {
  const file = path.join(ROOT, "i18n/frFR/subzones.json");
  const all = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {};
  return new Map(Object.entries((all[game] ?? {}) as Record<string, string>));
}

// The game's own French writing, one game's: what the names are counted in.
function corpus(game: Game): string[] {
  const db = dbs[game];
  const texts: string[] = [];
  const add = (sql: string) => {
    for (const r of db.query(sql).all() as { text: string }[]) if (r.text) texts.push(r.text);
  };
  add("SELECT text FROM quest_text WHERE locale = 'frFR'");
  add("SELECT text FROM speech WHERE locale = 'frFR'");
  add("SELECT text FROM gossip_page WHERE locale = 'frFR'");
  add("SELECT text FROM gossip_option WHERE locale = 'frFR'");
  add("SELECT text FROM readable_page WHERE locale = 'frFR'");
  add(
    "SELECT name AS text FROM name WHERE locale = 'frFR' AND kind IN ('spell_description', 'item_description', 'aura_description', 'global_string', 'faction_description')",
  );
  return texts;
}

// ── words ────────────────────────────────────────────────────────────────────
// (an elided article or preposition is a word of its own: "l'Alliance" is
// "l'" "Alliance"; a name's own apostrophe stays: "Grik'nir")
const ELIDED = /(?<![\p{L}])(qu|[ldjmnstcLDJMNSTC])['’](?=[\p{L}])/gu;
const WORD = /(?:[ldjmnstcLDJMNSTC]|qu|Qu)'(?=\s)|[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*/gu;
function tokens(text: string): string[] {
  return text.replace(/’/g, "'").replace(ELIDED, "$1' ").match(WORD) ?? [];
}
const low = (s: string) => s.toLocaleLowerCase("fr");
const cap = (s: string) => s.charAt(0).toLocaleUpperCase("fr") + s.slice(1);
const isCap = (s: string) => s.charAt(0) !== s.charAt(0).toLocaleLowerCase("fr");

// Every word of the texts, where it stands: [text, position].
type Index = { texts: string[][]; at: Map<string, [number, number][]>; small: Map<string, number> };
function index(texts: string[]): Index {
  const tok = texts.map(tokens);
  const at = new Map<string, [number, number][]>();
  const small = new Map<string, number>(); // (a word written in lower case: a common word)
  tok.forEach((ws, t) =>
    ws.forEach((w, i) => {
      const k = low(w);
      if (w === k) small.set(k, (small.get(k) ?? 0) + 1);
      let l = at.get(k);
      if (!l) at.set(k, (l = []));
      l.push([t, i]);
    }),
  );
  return { texts: tok, at, small };
}
// (a name's first word is a common word: "jeune", "vallée", "loup"; "Hogger",
// "Frostmane" are not)
const commonWord = (ix: Index, w: string) => (ix.small.get(low(w)) ?? 0) >= 3;
// (a name's first word in lower case as the texts spell it: the game writes
// capitals without their accent, "Etoffe de lin" is "étoffe de lin")
const ACCENTED: Record<string, string[]> = { e: ["é", "è", "ê"], a: ["à", "â"], i: ["î"], o: ["ô"], u: ["û"], c: ["ç"] };
function lowered(ix: Index, name: string): string | undefined {
  const w = tokens(name)[0];
  if (!w) return undefined;
  const plain = low(w);
  const first = plain.charAt(0);
  // (only a word the texts never write bare: "a" is a word, "à" another)
  if (plain.length < 2 || (ix.small.get(plain) ?? 0) >= 3) return undefined;
  let best = plain,
    count = ix.small.get(plain) ?? 0;
  for (const a of ACCENTED[first] ?? []) {
    const c = ix.small.get(a + plain.slice(1)) ?? 0;
    if (c > count) [best, count] = [a + plain.slice(1), c];
  }
  return best === plain ? undefined : best + name.slice(w.length);
}

// A name's uses in the texts: the two words before it and how its first word
// was written ("Vallée", "vallée").
type Use = { before: string[]; first: string };
function uses(ix: Index, name: string, cap = 400): Use[] {
  const ws = tokens(name).map(low);
  if (!ws.length) return [];
  const out: Use[] = [];
  for (const [t, i] of ix.at.get(ws[0]) ?? []) {
    const text = ix.texts[t];
    let ok = true;
    for (let k = 1; k < ws.length && ok; k++) ok = low(text[i + k] ?? "") === ws[k];
    if (!ok) continue;
    // (a longer name around it is another name: "Forgefer" in "Porte de Forgefer" counts, it is the city)
    out.push({ before: [low(text[i - 2] ?? ""), low(text[i - 1] ?? "")], first: text[i] });
    if (out.length >= cap) break;
  }
  return out;
}

// The gender of a word as the texts use it: le/un/du/au/ce before it, or
// la/une/cette (its plural: les/des tell nothing; notre/votre/leur never
// tell, mon/ton/son not before a vowel: "son étreinte").
const MASC = new Set(["le", "un", "du", "au", "ce", "cet", "mon", "ton", "son", "quel", "aucun", "nouveau", "vieux", "grand", "petit", "premier", "dernier", "seul", "bon", "mauvais", "gros"]);
const FEM = new Set(["la", "une", "cette", "ma", "ta", "sa", "quelle", "aucune", "nouvelle", "vieille", "grande", "petite", "première", "dernière", "seule", "bonne", "mauvaise", "grosse"]);
const POSSESSIVE = new Set(["mon", "ton", "son"]);
const vowelStart = (w: string) => /^[aeiouyhàâäéèêëîïôöûüœ]/i.test(w);
function genderBefore(before: string, word: string): "m" | "f" | null {
  if (FEM.has(before)) return "f";
  if (!MASC.has(before)) return null;
  return POSSESSIVE.has(before) && vowelStart(word) ? null : "m";
}
// (any word that says a common noun follows, its gender or not)
const DETERMINERS = new Set([...MASC, ...FEM, "l'", "les", "des", "notre", "votre", "leur", "nos", "vos", "leurs", "mes", "tes", "ses"]);
// (nouns the texts get wrong or never settle: "Egide draconien" is a slip,
// the game's other égides agree in the feminine)
const NOUN_GENDER: Record<string, "m" | "f"> = {
  egide: "f",
  galoches: "f",
  // (the Darkmoon cards: "le Trois de Fauves")
  as: "m", deux: "m", trois: "m", quatre: "m", cinq: "m", six: "m", sept: "m", huit: "m",
};
// (a verb and a noun, or "haut-de": one thing, masculine, whatever its -s:
// "un casse-noisettes", "un haut-de-chausses"; but the paired armour)
const VERB_FIRST = new Set(["casse", "cache", "ecrase", "tranche", "crache", "cure", "brise", "claque", "porte", "coupe", "perce", "fend", "ouvre", "tire", "chasse", "lance", "croque", "mange", "presse", "pare", "attrape", "garde", "protege", "couvre", "serre", "fauche", "broie", "arrache", "taille", "souffle", "saute", "haut", "hauts"]);
const PAIRED = /^(garde|protege)-(poignets|mains|bras|jambes|tibias|epaules)$/;
function compound(head: string): boolean {
  const k = plain(low(head));
  const [first] = k.split("-");
  return k.includes("-") && VERB_FIRST.has(first) && !PAIRED.test(k);
}
const lexicon = new Map<string, Map<string, { m: number; f: number; d: number }>>();
function counts(game: Game, ix: Index, k: string) {
  let cache = lexicon.get(game);
  if (!cache) lexicon.set(game, (cache = new Map()));
  let c = cache.get(k);
  if (!c) {
    c = { m: 0, f: 0, d: 0 };
    for (const [t, i] of ix.at.get(k) ?? []) {
      const before = low(ix.texts[t][i - 1] ?? "");
      if (DETERMINERS.has(before)) c.d++;
      const g = genderBefore(before, k);
      if (g) c[g]++;
    }
    cache.set(k, c);
  }
  return c;
}
function genderOfWord(game: Game, ix: Index, word: string): "m" | "f" | null {
  const k = low(word);
  const fixed = NOUN_GENDER[plain(k)];
  if (fixed) return fixed;
  const c = counts(game, ix, k);
  if (c.m + c.f >= 2 && c.m !== c.f) return c.f > c.m ? "f" : "m";
  // (a plural tells nothing: its singular may, "flèches" by "la flèche")
  if (/[sx]$/.test(k) && k.length > 3) {
    const one = counts(game, ix, k.slice(0, -1));
    if (one.m + one.f >= 2 && one.m !== one.f) return one.f > one.m ? "f" : "m";
  }
  return bySuffix(k);
}
// (a plural head: an -s the texts never put after a singular article)
function pluralHead(game: Game, ix: Index, head: string, byEnding = false): boolean {
  if (!pluralWord(head) || compound(head)) return false;
  const k = low(head);
  const c = counts(game, ix, k);
  if (c.m + c.f >= 2) return false;
  // (an item's or a spell's -s is a plural, "Galoches", "Sarments", but for
  // the words above; a creature's or a place's needs the texts: "Dannus",
  // "Leprithus" are names)
  const one = counts(game, ix, k.slice(0, -1));
  // (but -us: mostly a singular, "cactus", "Archeus", unless the texts know
  // its singular, "résidu")
  if (byEnding && !/us$/.test(k)) return true;
  return c.d >= 2 || one.d >= 2;
}
// (a common noun: the texts put an article or a possessive before it)
const isCommon = (game: Game, ix: Index, word: string) => counts(game, ix, low(word)).d >= 2;
// (a noun the texts never give an article: its ending, as French dictionaries
// would; null when the ending says nothing)
function bySuffix(w: string): "m" | "f" | null {
  if (/(erie|ion|té|ure|ance|ence|ade|ette|esse|ise|ie|ée|elle|euse|rice|ine|ière|ole|aille|ille|ude|ode|ève|ade)s?$/.test(w)) return "f";
  if (/(ment|age|eau|isme|eur|ier|oir|on|in|at|et|ard|ail|eil|ou|ot|ois|ais|ent|ant|ier|al|il|el|ic|ac|oc|ug|ul|us)s?$/.test(w)) return "m";
  return null;
}

// (words before the head noun: "Jeune troll", "Vieille harpie", "Grand
// kodo"; their own form tells the gender where it shows)
const BEFORE_NOUN: Record<string, "m" | "f" | null> = {
  jeune: null, vieux: "m", vieil: "m", vieille: "f", grand: "m", grande: "f", petit: "m", petite: "f",
  gros: "m", grosse: "f", haut: "m", haute: "f", ancien: "m", ancienne: "f", sombre: null, noble: null,
  féroce: null, sauvage: null, maître: "m", maîtresse: "f", vil: "m", vile: "f", fier: "m", fière: "f",
  premier: "m", première: "f", dernier: "m", dernière: "f", bon: "m", bonne: "f", mauvais: "m", mauvaise: "f",
  infâme: null, faux: "m", fausse: "f", gigantesque: null, énorme: null, immense: null, mini: null, demi: null,
  étrange: null,
};
// (the game writes a capital without its accent: "Enorme" is "énorme")
const plain = (w: string) => w.normalize("NFD").replace(/\p{M}/gu, "");
const BEFORE_PLAIN = new Map(Object.entries(BEFORE_NOUN).map(([k, v]) => [plain(k), v] as const));
// (a word of many: an -s or -x, but for the words that end so in the singular)
const ALWAYS_S = new Set(["pavois", "papyrus", "mucus", "index", "porte-clés", "humus", "taudis", "remous", "tamis", "kris", "keris", "némésis", "poix", "proboscis", "portefaix", "cacatoès", "deux", "trois", "six", "bois", "marais", "pas", "os", "puits", "gris", "repos", "palais", "temps", "corps", "fois", "avis", "souris", "tapis", "bras", "nez", "voix", "croix", "paix", "choix", "prix", "perdrix", "lynx", "sphinx", "dos", "héros", "mas", "jus", "pus", "ours", "fils", "pays", "tiers", "lys", "rubis", "abysse", "crocs", "vers", "fracas", "rhinocéros", "silex", "phénix", "onyx", "obus", "cyprès", "procès", "succès", "progrès", "relais", "talus", "hibou", "radis", "frimas", "glas", "tas", "cas", "lilas", "matelas", "verglas", "parcours", "secours", "discours", "concours", "recours", "cours", "velours", "remords", "mors", "corps", "colis", "logis", "parvis", "taillis", "treillis", "anis", "iris", "oasis", "mépris", "permis", "paradis", "rubis", "brebis", "vis", "buis", "puis", "chablis", "ananas", "atlas", "débarras", "embarras", "canevas", "bas", "repas", "amas", "trépas", "cadenas", "compas", "plâtras", "galimatias", "ramas", "taffetas", "harnais", "jais", "laquais", "mauvais", "rabais", "biais", "frais", "dais", "engrais", "geais", "marais", "niais", "panais", "relais", "tais"]);
const pluralWord = (w: string) => /[sx]$/.test(low(w)) && !ALWAYS_S.has(low(w)) && !/eux$|oux$/.test(low(w)) ? true : /aux$|eaux$/.test(low(w));

// A name as the journal shows it: straight apostrophes, and the accent the
// game leaves off a capital ("Ile" is "Île", "Etoffe" is "Étoffe")
function shownName(ix: Index, name: string): string {
  const n = name.replace(/\u2019/g, "'");
  const lf = lowered(ix, n);
  if (!lf || !isCap(n) || lf.charAt(0) === low(n.charAt(0))) return n;
  return lf.charAt(0).toUpperCase() + n.slice(1);
}

// The head of a name and its gender: the first noun, past the words that
// stand before one.
function headOf(name: string): { head: string; given: "m" | "f" | null } {
  const ws = tokens(name).filter((w) => !/^[ldjmnstc]'$/i.test(w));
  let given: "m" | "f" | null = null;
  for (const w of ws) {
    const k = low(w);
    if (k === "le" || k === "la" || k === "les" || k === "l'") continue;
    if (BEFORE_PLAIN.has(plain(k))) {
      given = given ?? BEFORE_PLAIN.get(plain(k)) ?? null;
      continue;
    }
    return { head: w, given };
  }
  return { head: ws[0] ?? name, given };
}

// ── what French puts before a name ───────────────────────────────────────────
type Entry = { n: string; g: string; a: string; p?: string };
const ARTICLES = new Set(["le", "la", "les", "l'"]);
const PREPOSITIONS = new Set(["à", "de", "d'", "en", "dans", "sur", "vers", "depuis", "par", "pour", "jusqu'"]);
const CONTRACTED: Record<string, string> = { au: "le", aux: "les", du: "le", des: "les" };
// a place's preposition by its head ("à la ferme", "sur le pic", "dans la forêt")
// (looked up without accents too: the game writes "Ile")
const AT_PLAIN = new Map<string, string>();
const AT_HEAD: Record<string, string> = {
  camp: "à", campement: "à", poste: "à", fort: "à", fortin: "à", bastion: "à", tour: "à", ferme: "à", porte: "à",
  col: "à", avant: "à", comptoir: "à", refuge: "à", village: "dans", ville: "dans", cité: "dans", port: "à",
  île: "sur", îles: "sur", îlot: "sur", pic: "sur", mont: "sur", colline: "sur", collines: "dans", pont: "sur",
  place: "sur", terrasse: "sur", plateau: "sur", rivage: "sur", plage: "sur", côte: "sur", sommet: "au sommet de",
  lac: "au bord de", chantier: "sur", réserve: "dans", ruines: "dans", ruine: "dans", couvent: "dans", convent: "dans",
  grève: "sur", mesa: "sur", hauts: "sur", rivages: "sur", vallée: "dans", forêt: "dans", bois: "dans", marais: "dans",
  grotte: "dans", caverne: "dans", cavernes: "dans", mine: "dans", mines: "dans", crypte: "dans", temple: "dans",
  cathédrale: "dans", chapelle: "dans", abbaye: "à", monastère: "dans", donjon: "dans", prison: "dans", repaire: "dans",
  antre: "dans", gouffre: "dans", gorge: "dans", gorges: "dans", canyon: "dans", ravin: "dans", défilé: "dans",
  plaine: "dans", plaines: "dans", champ: "dans", champs: "dans", jardin: "dans", jardins: "dans", quartier: "dans",
  district: "dans", rue: "dans", taverne: "à", auberge: "à", hall: "dans", salle: "dans", chambre: "dans",
  bassin: "dans", étang: "au bord de", rivière: "au bord de", fleuve: "au bord de", passe: "dans", passage: "dans",
  marche: "dans", terres: "sur", steppes: "dans", désert: "dans", dunes: "dans", jungle: "dans", clairière: "dans",
  bosquet: "dans", vallon: "dans", val: "dans", cuvette: "dans", cratère: "dans", lande: "sur", landes: "sur",
  colonie: "dans", hameau: "dans", bourg: "dans", fermes: "dans", scierie: "à",
  route: "sur", chemin: "sur", sentier: "sur", tertre: "sur", butte: "sur", éperon: "sur", cap: "sur", pointe: "sur",
  baie: "dans", crique: "dans", anse: "dans", lagon: "dans", quai: "sur", quais: "sur", jetée: "sur", promontoire: "sur", falaise: "sur", falaises: "sur", crête: "sur",
};
for (const [k, v] of Object.entries(AT_HEAD)) AT_PLAIN.set(plain(k), v);
function place(ix: Index, game: Game, name: string, fixed?: Partial<Entry>): Entry {
  const own = low(tokens(name)[0] ?? "");
  const hasOwn = ARTICLES.has(own);
  // (the name without its own article: "Les Tarides" is "Tarides" after "les")
  const bare = hasOwn ? name.replace(/^l['’]\s*/i, "").replace(/^(les|le|la)\s+/i, "") : name;
  const art: Record<string, number> = {};
  const prep: Record<string, number> = {};
  let lower = 0,
    upper = 0;
  const us = uses(ix, bare);
  for (const u of us) {
    const [b2, b1] = u.before;
    let a = "",
      p = b1;
    if (ARTICLES.has(b1)) [a, p] = [b1, b2];
    else if (b1 in CONTRACTED) [a, p] = [CONTRACTED[b1], b1 === "au" || b1 === "aux" ? "à" : "de"];
    else if (!PREPOSITIONS.has(b1)) continue; // (no article, but nothing says none should be: a title, a sentence's start)
    art[a] = (art[a] ?? 0) + 1;
    if (["à", "en", "dans", "sur"].includes(p)) prep[p] = (prep[p] ?? 0) + 1;
    if (isCap(u.first)) upper++;
    else lower++;
  }
  const top = (o: Record<string, number>) => Object.entries(o).sort((x, y) => y[1] - x[1])[0]?.[0];
  const { head, given } = headOf(bare);
  const headLow = low(head);
  const nounGender = genderOfWord(game, ix, lowered(ix, head) ?? headLow); // (a common noun the texts use with articles)
  const common = (nounGender !== null || isCommon(game, ix, headLow)) && tokens(bare).length > 1;
  // the article: the name's own, else as the texts write it, else a common
  // noun's ("la vallée des Frigères"), none for a name of its own ("Forgefer")
  let a = hasOwn ? own : us.length ? top(art) ?? "" : common ? "?" : "";
  // the gender: an article that tells it, the words before the noun, the noun's own
  const g0 = (a === "la" ? "f" : a === "le" ? "m" : null) ?? given ?? nounGender ?? ((art.la ?? 0) > (art.le ?? 0) ? "f" : "m");
  const headWord = lowered(ix, head) ?? headLow;
  if (a === "?" && pluralHead(game, ix, headWord)) a = "les";
  if (a === "?") a = /^[aeiouyâàéèêîïôûœ]/i.test(headLow) || /^h[^aou]/i.test(headLow) ? "l'" : g0 === "f" ? "la" : "le";
  const g = g0 + (a === "les" || pluralHead(game, ix, headWord) ? "p" : "");
  // (the first word in a sentence: lower case when the texts write it so, or
  // when they never name it and it is a common noun)
  let n = bare;
  // (the game's own capitals after the article, "au Loch Modan", unless its
  // texts write the name in lower case more often: "la caverne des trolls")
  if (a && lower > upper) n = lowered(ix, n) ?? low(n.charAt(0)) + n.slice(1);
  if (!a) n = cap(n);
  // the preposition: as the texts write it, else by the head, else "à" for a
  // name of its own and "dans" for one with its article
  const voted = top(prep);
  const p = AT_HEAD[headLow] ?? AT_PLAIN.get(plain(headLow)) ?? (voted && prep[voted] >= 2 ? voted : undefined) ?? (a ? "dans" : "à");
  return { n: shownName(ix, n), g, a, p, ...fixed };
}

// A creature or a thing: its gender, its head's case.
function thing(ix: Index, game: Game, name: string, person: boolean, fixed?: Partial<Entry>, creature = false): Entry {
  if (person) return { n: name.replace(/\u2019/g, "'"), g: "m", a: "", ...fixed };
  const us = uses(ix, name, 200);
  let m = 0,
    f = 0,
    lower = 0,
    upper = 0;
  for (const u of us) {
    const g = genderBefore(u.before[1], u.first);
    if (g === "m") m++;
    else if (g === "f") f++;
    if (isCap(u.first)) upper++;
    else lower++;
  }
  const { head, given } = headOf(name);
  let g: string = compound(head) ? "m" : m + f > 0 ? (f > m ? "f" : "m") : given ?? genderOfWord(game, ix, lowered(ix, head) ?? low(head)) ?? "m";
  const ws = tokens(name);
  if (ws.length && pluralHead(game, ix, lowered(ix, head) ?? head, !creature) && m + f === 0) g += "p";
  const first = ws[0] ?? "";
  const lc = lower > upper || commonWord(ix, first);
  const lf = lowered(ix, name);
  return { n: shownName(ix, name), g, a: "", ...fixed, ...(lc ? { lc: "1" } : {}), ...(lf ? { lf: lf.replace(/\u2019/g, "'") } : {}) } as Entry;
}

// ── the files ────────────────────────────────────────────────────────────────
const overridesFile = path.join(ROOT, "i18n/frFR/names.json");
const overrides: Record<string, Record<string, Partial<Entry>>> = existsSync(overridesFile)
  ? JSON.parse(readFileSync(overridesFile, "utf8"))
  : {};
const lua = (s: string) => JSON.stringify(s);
const stale: string[] = [];
const report: string[] = [];

const ix = index([...corpus("forever"), ...corpus("classic")]);
const factions: Record<string, Record<string, string>> = {};
for (const game of Object.keys(GAMES) as Game[]) {
  const ids = englishIds(game);
  const person = new Set<string>(); // (English names of people: Names.lua's creatureBare)
  {
    const r = Bun.spawnSync([
      "luajit",
      "-e",
      `local ns = {} assert(loadfile(${lua(path.join(DIR, "Names.lua"))}))("Hearthtale", ns)
       ${game === "forever" ? `pcall(function() assert(loadfile(${lua(path.join(DIR, "Forever.lua"))}))("Hearthtale", ns) end)` : ""}
       for n in pairs(ns.names.creatureBare) do io.write(n, "\\n") end`,
    ]);
    for (const n of r.stdout.toString().split("\n")) if (n) person.add(n);
  }
  const out: Record<string, Record<string, Entry | string>> = {};
  const missing: Record<string, number> = {};
  const KINDS: [string, string, "place" | "thing" | "name"][] = [
    ["areas", "area", "place"],
    ["maps", "map", "place"],
    ["inside", "", "place"],
    ["encounters", "encounter", "name"],
    ["spells", "spell", "thing"],
    ["mounts", "spell", "thing"],
    ["skillIds", "skill_line", "thing"],
    ["typeIds", "creature_type", "thing"],
    ["familyIds", "creature_family", "thing"],
    ["taxiIds", "taxi_node", "name"],
    ["treeIds", "talent_tab", "thing"],
    ["specIds", "specialization", "thing"],
    ["creatures", "creature", "thing"],
    ["quests", "quest", "name"],
    ["items", "item", "thing"],
  ];
  for (const [key, kind, how] of KINDS) {
    const fr = key === "inside" ? new Map([...insideOf(game)].map(([id, name]) => [id, { name, female: null }])) : frenchOf(game, kind);
    // (Forever's inside places the kit doesn't list: the client's own)
    if (key === "inside") for (const [id, r] of frenchOf(game, "wmo_area")) if (!fr.has(id)) fr.set(id, r);
    const o: Record<string, Entry | string> = {};
    for (const [id, english] of Object.entries(ids[key] ?? {})) {
      const name = fr.get(id)?.name;
      const fixed = overrides[key]?.[id];
      if (!name && !fixed?.n) {
        missing[key] = (missing[key] ?? 0) + 1;
        continue;
      }
      // (Classic's French client keeps the English beside some: "Tarides (the Barrens)")
      const n = fixed?.n ?? name!.replace(/\s*\([^)]*\)\s*$/, "");
      o[id] =
        how === "place"
          ? place(ix, game, n, fixed)
          : how === "thing"
            ? thing(ix, game, n, key === "creatures" && person.has(english), fixed, key === "creatures")
            : n.replace(/\u2019/g, "'");
    }
    out[key] = o;
  }
  // the factions, by their English names (no table of the record names them:
  // French text names them, [[faction:Wildhammer Clan]])
  {
    const rows = dbs[game]
      .query(
        "SELECT e.name AS en, f.name AS fr FROM name e JOIN name f ON f.kind = e.kind AND f.id = e.id AND f.locale = 'frFR' WHERE e.kind = 'faction' AND e.locale = 'enUS'",
      )
      .all() as { en: string; fr: string }[];
    const o: Record<string, string> = {};
    for (const r of rows) if (r.en && r.fr && !(r.en in o)) o[r.en] = r.fr;
    factions[game] = o;
  }
  // the peoples and the classes, a man's and a woman's names
  for (const kind of ["race", "class"]) {
    const o: Record<string, Entry | string> = {};
    for (const [id, r] of frenchOf(game, kind)) o[id] = r.female ? `${r.name}|${r.female}` : r.name;
    out[kind === "race" ? "races" : "classes"] = o;
  }

  const entry = (v: Entry | string) => {
    if (typeof v === "string") return lua(v);
    const parts = [lua(v.n), lua(v.g)];
    if (v.a !== "" || v.p) parts.push(lua(v.a));
    if (v.p) parts.push(lua(v.p));
    const extra = [(v as { lc?: string }).lc ? "lc = true" : "", (v as { lf?: string }).lf ? `lf = ${lua((v as { lf?: string }).lf!)}` : ""].filter(Boolean);
    return `{ ${[...parts, ...extra].join(", ")} }`;
  };
  const factionRows = Object.keys(factions[game])
    .sort()
    .map((en) => `[${lua(en)}]=${lua(factions[game][en])},`)
    .join("\n");
  const sections = Object.entries(out)
    .map(([key, o]) => {
      const rows = Object.keys(o)
        .sort((x, y) => Number(x) - Number(y))
        .map((id) => `[${id}]=${entry(o[id])},`)
        .join("\n");
      return `  ${key} = {\n${rows}\n  },`;
    })
    .concat(`  factions = {\n${factionRows}\n  },`)
    .join("\n");
  const text = `-- Generated by scripts/french-names.ts: the game's French names by id, each
-- with what French puts before it ({ name, gender, article, preposition };
-- a name alone: a quest's, a boss's, a flight point's), for the journal
-- written in French. Do not edit: i18n/frFR/names.json.
local _, ns = ...
-- (kept out of the addon until the French is complete: addon/Hearthtale_French/,
-- loaded by the tests; built at the first need)
function ns.frenchNames()
  return {
${sections.replace(/\u2019/g, "'") /* (straight apostrophes, as the journal writes them) */}
  }
end
`;
  const file = path.join(ROOT, "addon/Hearthtale_French", `FrenchNames_${GAMES[game]}.lua`);
  if (CHECK) {
    if (!existsSync(file) || readFileSync(file, "utf8") !== text) stale.push(path.basename(file));
  } else writeFileSync(file, text);
  // (the places as a sentence says them, for a read: .cache/audit/french-<game>.txt)
  if (!CHECK) {
    const lines = Object.entries(out.areas ?? {}).map(([id, e]) => {
      const v = e as Entry;
      return `${id}\t${v.p ?? ""} ${v.a === "l'" ? "l'" : v.a ? v.a + " " : ""}${v.n}\t(${v.g})`;
    });
    const dir = path.join(ROOT, ".cache/audit");
    if (existsSync(dir)) writeFileSync(path.join(dir, `french-${game}.txt`), lines.join("\n") + "\n");
  }
  report.push(`${game}: ${Object.entries(out).map(([k, o]) => `${k} ${Object.keys(o).length}`).join(", ")}; no French: ${JSON.stringify(missing)}`);
}
console.log(report.join("\n"));
if (stale.length) {
  console.error(`stale: ${stale.join(", ")} (bun scripts/french-names.ts)`);
  process.exit(1);
}
