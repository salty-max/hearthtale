-- The journal in French, on a French client. The writer chooses its lines in
-- English as ever (Lines.lua, Diary.lua: their weights, their checks, the
-- English output unchanged); each line told is told again in French, from
-- the facts behind its slots (a place, a foe, a quest, a number), never from
-- its English words. An entry is French when each of its sentences is, else
-- it stays English whole.
--   the lines: French_<game>.lua (scripts/build.ts, i18n/frFR/writing/)
--   the game's names: FrenchNames_<game>.lua (scripts/french-names.ts)
-- Both live in Hearthtale_French, an addon of their own loaded on demand the
-- first time a journal is written in French: an English journal never loads
-- them. HearthtaleFrench is its namespace, shared (its Share.lua).
-- How a slot's French is found: the writer's helpers (W.mid, W.at,
-- W.article, W.itemName, W.plural, W.words, W.listing, W.playedWords,
-- W.deathFoe) are wrapped here, each English result remembered with its
-- French (memo); a slot the helpers didn't make is found by its kind (a
-- spell, a trade, a creature, a place) through the English name's id. A
-- name the tables don't know stays as kept (a player's, a pet's, a name the
-- client gave in French). A French template may write {slot:un}, {slot:le},
-- {slot:de} (its article, agreeing), {slot:nu} (its noun alone) and
-- {slot=m|f} or {slot=m|f|mp|fp} (a word agreeing with it); $gmasc:fem;
-- agrees with the narrator.
local _, ns = ...
local W = ns.writer
if not W then return end
local COMPANION = "Hearthtale_French"
-- (the French data: loaded at the first need, nil when the companion is
-- missing or turned off)
local function data()
  if not HearthtaleFrench and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, COMPANION) end
  -- (a load that failed: no French from here on, the English stays whole)
  if not HearthtaleFrench and ns.french then ns.french.ready = false end
  return HearthtaleFrench
end
-- (the companion is there to load, the same version as Hearthtale: French can
-- be chosen. An addon on demand not yet loaded says "DEMAND_LOADED" with
-- loadable false, as the game's own AddonList reads it; one turned off says
-- "DISABLED". Another version's lines would not match these, by their places.)
local function available()
  if HearthtaleFrench then return HearthtaleFrench.frenchComplete == true end
  if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
  local name, _, _, loadable, reason = C_AddOns.GetAddOnInfo(COMPANION)
  if not name or not (loadable or reason == "DEMAND_LOADED") then return false end
  local meta = C_AddOns.GetAddOnMetadata
  local mine, its = meta and meta("Hearthtale", "Version"), meta and meta(COMPANION, "Version")
  return mine == its
end
-- (the writer's own helpers, before they are wrapped below: what the French
-- reads of the English never comes back here)
local EN = {}
for k, v in pairs(W) do
  EN[k] = v
end
-- (the tables, built at the first need: FN the names, FW the lines)
local FN = setmetatable({}, {
  __index = function(t, k)
    local d = data()
    if not d then
      -- (the companion failed to load: no French, the English stays whole)
      if ns.french then ns.french.ready = false end
      return nil
    end
    local all = d.frenchNames()
    for key, v in pairs(all) do
      rawset(t, key, v)
    end
    setmetatable(t, nil)
    return all[k]
  end,
})
local FW = setmetatable({}, {
  __index = function(t, k)
    local d = data()
    if not d then
      -- (the companion failed to load: no French, the English stays whole)
      if ns.french then ns.french.ready = false end
      return nil
    end
    local all = d.frenchWriting()
    for key, v in pairs(all) do
      rawset(t, key, v)
    end
    setmetatable(t, nil)
    return all[k]
  end,
})

local F = {
  -- (French may be chosen: the companion is there, every line of it French)
  ready = available(),
  -- (the book being written is in French: its language, ns.writeBook)
  on = false,
  memo = {}, -- [an English slot value] = its French
  gender = {}, -- [a French value] = "m", "f", "mp", "fp"
  bare = {}, -- [a French value] = its noun without its article ("vallée des Frigères")
  place = {}, -- [a place with its preposition] = without it ("à Brill" = "Brill", "dans les Tarides" = "les Tarides")
  unknown = {}, -- [a name] = true: one the tables don't know (the tests list them)
  missing = {}, -- [a line told] = true: one with no French yet (the tests list them)
}
ns.french = F
F.data = data -- (the companion's tables: the tests read the deeds there)

-- ── words ────────────────────────────────────────────────────────────────────
-- (UTF-8: an accented capital is \195 then 128-158, its small letter +32)
local function lowerFirst(s)
  if not s or s == "" then return s end
  local b1, b2 = s:byte(1, 2)
  if b1 == 195 and b2 and b2 >= 128 and b2 <= 158 then return string.char(195, b2 + 32) .. s:sub(3) end
  return s:sub(1, 1):lower() .. s:sub(2)
end
local function upperFirst(s)
  if not s or s == "" then return s end
  local b1, b2 = s:byte(1, 2)
  if b1 == 195 and b2 and b2 >= 160 and b2 <= 190 then return string.char(195, b2 - 32) .. s:sub(3) end
  return s:sub(1, 1):upper() .. s:sub(2)
end
F.lowerFirst, F.upperFirst = lowerFirst, upperFirst

-- (the vowels a French word elides before: é, è, à, î … are two bytes, the
-- first \195; ç is not one; an aspirated h is no vowel: "la Horde")
-- (the common nouns with a mute h that open the game's item and spell names)
local MUTE_H = {}
for w in
  ([[huile habit herbe heure homme hôtel hymne histoire hiver honneur horreur horloge héritage
  hémorragie hibernation hérésie héros_ harmonie hydre hydromel hémoglobine hostie humeur huître hutin
  habileté habitant hallebardier_ hommage horizon hospice]]):gmatch("%S+")
do
  if not w:find("_$") then MUTE_H[w] = true end
end
local ASPIRATED = {
  horde = true,
  ["h\195\169ros"] = true,
  haine = true,
  hache = true,
  haut = true,
  haute = true,
  hauts = true,
  hurlement = true,
  hameau = true,
  harpie = true,
  ["hy\195\168ne"] = true,
  hibou = true,
  homard = true,
  honte = true,
  hutte = true,
  haubert = true,
  harnais = true,
  heaume = true,
  horion = true,
  heurt = true,
  hallebarde = true,
  hampe = true,
  harpon = true,
  hargne = true,
  hurlevent = true,
  ["h\195\162te"] = true, -- (hâte)
  hall = true,
  halte = true,
  hangar = true,
  hardi = true,
  hasard = true,
  hune = true,
  hurleur = true,
  hurleuse = true,
}
local function vowel(word)
  local c = word:sub(1, 1)
  if c:find("[aeiouyAEIOUY]") then return true end
  if c == "\195" then
    local b = word:byte(2)
    return b ~= 167 and b ~= 135 -- (ç, Ç)
  end
  -- (a name of the game's with an H never elides, as its own texts write
  -- it: "de Hurlevent", "de Hautebrande", "de Hogger"; but an item's or a
  -- spell's common noun with a mute h does: "l'Hémorragie", "l'Huile")
  if c == "H" then
    local w = (word:match("^[%a\128-\255]+") or ""):lower()
    return MUTE_H[w] or MUTE_H[(w:gsub("s$", ""))] or false
  end
  if c == "h" then
    local w = word:match("^[%a\128-\255]+") or ""
    return not (ASPIRATED[w] or ASPIRATED[(w:gsub("s$", ""))]) -- ("de huttes")
  end
  return false
end
F.vowel = vowel

-- (an article the writer put before a name or a slot's value, marked so only
-- it contracts: "de le pic" is "du pic", "de le laisser" stays as written)
local A = "\1"
-- What French does where two words meet: "je ai" is "j'ai", "de le" (an
-- article of ours) is "du", "à les" is "aux", "si il" is "s'il". (A word
-- starts after a space, a quote or a parenthesis.)
local function tidy(s)
  s = " " .. s
  s = s:gsub('([%s%("])([JjMmTtSsLlNnDdCc])e (%S+)', function(b, l, w)
    if vowel(w) then return b .. l .. "'" .. w end
  end)
  s = s:gsub('([%s%("])([Qq])ue (%S+)', function(b, q, w)
    if vowel(w) then return b .. q .. "u'" .. w end
  end)
  s = s:gsub('([%s%("])([Ll])a (%S+)', function(b, l, w)
    if vowel(w) then return b .. l .. "'" .. w end
  end)
  s = s:gsub('([%s%("])([Jj]usque) (%S+)', function(b, j, w)
    if vowel(w) then return b .. j .. "'" .. w end
  end)
  -- (de, à before the article: du, des, au, aux; never before l')
  s = s:gsub('([%s%("])([Dd])e \1le ', "%1%2u "):gsub('([%s%("])([Dd])e \1les ', "%1%2es ")
  -- (after an apostrophe too: "jusqu'aux Tarides")
  s = s:gsub("([%s%(\"'])\195\160 \1le ", "%1au "):gsub("([%s%(\"'])\195\160 \1les ", "%1aux ")
  s = s:gsub('([%s%("])\195\128 \1le ', "%1Au "):gsub('([%s%("])\195\128 \1les ', "%1Aux ")
  -- (de before un plural indefinite: "de des" is "de")
  s = s:gsub('([%s%("])([Dd])e des ', "%1%2e ")
  s = s:gsub(" si il", " s'il"):gsub(" si ils", " s'ils")
  return (s:sub(2):gsub(A, ""))
end
F.tidy = tidy

-- The narrator's gender: $gmasc:fem; as the game's own texts write it.
local function gendered(s, female)
  return (s:gsub("%$[gG]([^:;]*):([^;]*);", function(m, f) return female and f or m end))
end

-- A sentence's capitals: its first letter, and after a full stop.
local function capital(s)
  local lead, rest = s:match('^(["%(%s]*)(.*)$')
  s = lead .. upperFirst(rest)
  return (s:gsub('([%.!%?]"?[%s\194\160]+)(%S+)', function(p, w) return p .. upperFirst(w) end))
end

-- ── numbers, lists, time ─────────────────────────────────────────────────────
local ONES = {
  "un",
  "deux",
  "trois",
  "quatre",
  "cinq",
  "six",
  "sept",
  "huit",
  "neuf",
  "dix",
  "onze",
  "douze",
  "treize",
  "quatorze",
  "quinze",
  "seize",
}
local TENS = { [2] = "vingt", [3] = "trente", [4] = "quarante", [5] = "cinquante", [6] = "soixante" }
local function words(n)
  n = math.floor(n)
  if n <= 0 then return "aucun" end
  if n <= 16 then return ONES[n] end
  if n < 20 then return "dix-" .. ONES[n - 10] end
  if n < 70 then
    local t, u = math.floor(n / 10), n % 10
    if u == 0 then return TENS[t] end
    if u == 1 then return TENS[t] .. " et un" end
    return TENS[t] .. "-" .. ONES[u]
  end
  if n < 80 then
    if n == 71 then return "soixante et onze" end
    return "soixante-" .. words(n - 60)
  end
  if n < 100 then
    if n == 80 then return "quatre-vingts" end
    return "quatre-vingt-" .. words(n - 80)
  end
  if n < 1000 then
    local h, r = math.floor(n / 100), n % 100
    local head = h == 1 and "cent" or (ONES[h] .. " cent" .. (r == 0 and "s" or ""))
    return head .. (r > 0 and " " .. words(r) or "")
  end
  return tostring(n)
end
F.words = words

local function listing(items)
  if #items == 0 then return nil end
  if #items == 1 then return items[1] end
  return table.concat(items, ", ", 1, #items - 1) .. " et " .. items[#items]
end

local function playedWords(s)
  if not s or s < 60 then return nil end
  local m = math.floor(s / 60 + 0.5)
  if m > 20 then m = math.floor(m / 5 + 0.5) * 5 end
  if m < 60 then return m == 1 and "une minute" or words(m) .. " minutes" end
  local h, r = math.floor(m / 60), m % 60
  if h < 2 then
    if r == 0 then return "une heure" end
    if r == 30 then return "une heure et demie" end
    return "une heure et " .. words(r) .. " minutes"
  end
  if r >= 45 then
    h, r = h + 1, 0
  end
  if h >= 24 then
    local d = math.floor(h / 24 + 0.5)
    return d == 1 and "une journée entière" or words(d) .. " jours"
  end
  return words(h) .. " heures" .. ((r >= 15 and r < 45) and " et demie" or "")
end

-- ── the game's names, by the English name's id ───────────────────────────────
local C = ns.client or {}
local reversed = {}
-- [an English name] = its id, and the same in lower case (a trade, a family,
-- a mount the writer lowers: "mining", "boar")
local function reverse(key, names)
  if reversed[key] then return reversed[key] end
  local r, l = {}, {}
  local function put(id, n)
    if type(n) == "table" then n = n.title end
    if type(n) ~= "string" then return end
    if not r[n] or id < r[n] then r[n] = id end
    local low = n:lower()
    if not l[low] or id < l[low] then l[low] = id end
  end
  for id, n in pairs(names or {}) do
    put(id, n)
  end
  local mt = getmetatable(names or {})
  if mt and type(mt.__index) == "table" then
    for id, n in pairs(mt.__index) do
      if not r[type(n) == "table" and n.title or n] then put(id, n) end
    end
  end
  reversed[key] = { r, l }
  return reversed[key]
end
local function recordNames() return (ns.record and ns.record.names and ns.record.names()) or {} end
local LISTS = {
  areas = function() return C.areas end,
  inside = function() return C.inside end,
  maps = function() return C.maps end,
  encounters = function() return C.encounters end,
  spells = function() return C.spells end,
  mounts = function() return C.mounts end,
  skillIds = function() return C.skillIds end,
  typeIds = function() return C.typeIds end,
  familyIds = function() return C.familyIds end,
  taxiIds = function() return C.taxiIds end,
  treeIds = function() return C.treeIds end,
  specIds = function() return C.specIds end,
  creatures = function() return recordNames().creatures end,
  items = function() return recordNames().items end,
  quests = function() return recordNames().quests end,
}
-- The French entry of an English name of a kind ({ name, gender, article,
-- preposition }, or a name alone), nil when the tables don't know it.
local function lookup(key, name)
  if type(name) ~= "string" or name == "" then return nil end
  local r = reverse(key, LISTS[key]())
  local id = r[1][name] or r[2][name:lower()]
  return id and FN[key] and FN[key][id]
end
F.lookup = lookup

-- A place: an area, a place inside a building, a dungeon.
local function placeOf(name)
  return lookup("areas", name)
    or lookup("inside", name)
    or lookup("maps", name)
    or (name and lookup("areas", name .. " City")) -- (a spell's "Teleport: Stormwind")
end
-- (a place named without the game's "The": a deed's "Crossroads"; only where
-- a place is meant, a creature or an item may bear the bare name)
local function placeOrThe(name)
  if not name then return nil end
  local bare = name:match("^[Tt]he (.+)$")
  return placeOf(name) or (bare and placeOf(bare)) or placeOf("The " .. (bare or name)) or nil
end
F.placeOf = placeOrThe
-- (Forgefer; la vallée des Frigères; l'île; les Tarides)
local function withArticle(e, art)
  local a = art or e[3] or ""
  if a == "" then return e[1] end
  if a == "l'" then return A .. "l'" .. e[1] end
  return A .. a .. " " .. e[1]
end
local function definiteOf(n, g)
  g = g or "m"
  if g:find("p") then return A .. "les " .. n end
  if vowel(n) then return A .. "l'" .. n end
  return A .. (g == "f" and "la " or "le ") .. n
end
local function indefiniteOf(n, g)
  g = g or "m"
  if g:find("p") then return "des " .. n end
  return (g == "f" and "une " or "un ") .. n
end
local function partitiveOf(n, g)
  g = g or "m"
  if g:find("p") then return "des " .. n end
  if vowel(n) then return "de l'" .. n end
  return (g == "f" and "de la " or "du ") .. n
end

-- (a value made: its gender and its bare noun, for the templates' agreements)
local function made(fr, g, bare)
  if fr then
    F.gender[fr] = g
    F.bare[fr] = bare
  end
  return fr
end

local function frMid(name)
  if not name or name == "" then return nil end
  local e = placeOrThe(name)
  if not e then
    F.unknown[name] = true
    return name
  end
  return made(withArticle(e), e[2], e[1])
end
local function frAt(name)
  if not name or name == "" then return nil end
  local e = placeOrThe(name)
  if not e then
    F.unknown[name] = true
    F.place["\195\160 " .. name] = name
    return "\195\160 " .. name
  end
  local p = e[4] or "\195\160"
  if p == "en" and (e[3] or "") ~= "" then p = "dans" end
  local out = p .. " " .. withArticle(e)
  F.place[out] = withArticle(e)
  return out
end

-- A creature: one of a kind, a family, a type, a boss.
local function creatureOf(name) return lookup("creatures", name) or lookup("familyIds", name) or lookup("typeIds", name) end
-- (a name's first word in lower case as the game's texts spell it: "étoffe")
local function lowered(e) return e.lf or lowerFirst(e[1]) end
local function shown(e) return e.lc and lowered(e) or e[1] end
-- (a person's name, or a creature's as the game writes it)
local function nameOf(name)
  local e = creatureOf(name)
  if type(e) == "table" then
    -- (a name with its article, "La Tremblotte", reads "la Tremblotte" in a
    -- sentence and contracts: "à la Tremblotte", "du Gardien")
    local art, rest = e[1]:match("^(L[ae]s?) (.+)$")
    if art then return A .. art:lower() .. " " .. rest end
    rest = e[1]:match("^L'(.+)$")
    if rest then return A .. "l'" .. rest end
    return e[1]
  end
  local boss = lookup("encounters", name)
  if type(boss) == "string" then return boss end
  F.unknown[name] = true
  return name
end
local function definiteCreature(name)
  local e = creatureOf(name)
  if type(e) ~= "table" then
    F.unknown[name] = true
    return A .. "le " .. name
  end
  local n = shown(e)
  return made(definiteOf(n, e[2]), e[2], n)
end
local function indefiniteCreature(name)
  local e = creatureOf(name)
  if type(e) ~= "table" then
    F.unknown[name] = true
    return "un " .. name
  end
  local n = shown(e)
  return made(indefiniteOf(n, e[2]), e[2], n)
end

-- (a trade's ranks, as the game names them)
local RANKS = {
  apprentice = "apprenti",
  journeyman = "compagnon",
  expert = "expert",
  artisan = "artisan",
  master = "ma\195\174tre",
  ["grand master"] = "grand ma\195\174tre",
}
F.RANKS = RANKS

-- The writer's article (Language.lua's), in French: a name of its own as it
-- is, one of a kind with "le", any other with "un".
local function frArticle(name)
  if not name then return nil end
  if RANKS[name] then return made("un " .. RANKS[name], "m", RANKS[name]) end
  local first = name:match("^(%a+)") or ""
  if W.TITLES[first] and name:find(" ") then return nameOf(name) end
  if name:find("^The ") then return definiteCreature(name) end
  local known = ns.names
  if known and known.creatureBare[name] then return nameOf(name) end
  if known and known.creatureThe[name] then return definiteCreature(name) end
  if name:find(" the ") or name:find("^%u%a*'%a+$") then return nameOf(name) end
  return indefiniteCreature(name)
end

-- An item, as the writer names it: "un Collier en crocs de loup", "des Gants
-- en cuir bouilli", "la tête de VanCleef", "du Tissu de lin".
local TROPHY = { Head = true, Skull = true, Heart = true, Scalp = true }
local function itemOf(name)
  local e = lookup("items", name)
  if type(e) == "table" then return e end
end
local function frItem(name)
  if not name then return nil end
  local e = itemOf(name)
  if not e then
    F.unknown[name] = true
    return name
  end
  local n, g = e[1], e[2]
  local english = EN.itemName(name) -- (its English shape: an article, none, an owner)
  local piece = name:match("^(%a+) of ")
  local part = name:match("^(%a+) of .+$")
  if part and TROPHY[part] then return made(definiteOf(lowerFirst(n), g), g, lowerFirst(n)) end
  if piece == "Top" or piece == "Middle" or piece == "Bottom" or piece == "Upper" or piece == "Lower" then
    return made(definiteOf(n, g), g, n)
  end
  if english == name then
    -- (no article in English: many, uncounted, or a person's: "Zanzil's Seal")
    if name:find("'s ") or name:find("s' ") then return made(definiteOf(n, g), g, n) end
    if g:find("p") then return made("des " .. n, g, n) end
    return made(partitiveOf(n, g), g, n)
  end
  if english:find("^the ") then return made(definiteOf(n, g), g, n) end
  return made(indefiniteOf(n, g), g, n)
end

-- A name of many: "jeunes trolls Frostmane", "loups des bois".
local STOP = {
  de = true,
  du = true,
  des = true,
  ["d'"] = true,
  ["\195\160"] = true,
  au = true,
  aux = true,
  en = true,
  sans = true,
  pour = true,
  ["l'"] = true,
  la = true,
  le = true,
  les = true,
}
local X_PLURAL = { bijou = true, caillou = true, chou = true, genou = true, hibou = true, joujou = true, pou = true }
local AL_S =
  { bal = true, carnaval = true, chacal = true, festival = true, ["r\195\169cital"] = true, ["r\195\169gal"] = true }
local function pluralWord(w)
  if w:find("[sxz]$") then return w end
  local low = w:lower()
  if X_PLURAL[low] then return w .. "x" end
  if low:find("al$") and not AL_S[low] then return w:sub(1, -3) .. "aux" end
  if low:find("eau$") or low:find("au$") or (low:find("eu$") and low ~= "pneu" and low ~= "bleu") then
    return w .. "x"
  end
  return w .. "s"
end
local VERB_FIRST = {}
for v in
  ("casse cache tranche crache cure brise claque porte coupe perce fend ouvre tire chasse lance croque mange presse pare attrape garde couvre serre fauche broie arrache taille souffle saute haut hauts"):gmatch(
    "%S+"
  )
do
  VERB_FIRST[v] = true
end
VERB_FIRST["\195\169crase"], VERB_FIRST["prot\195\168ge"] = true, true
local function pluralOf(n)
  local out, stop = {}, false
  local i = 0
  for w in n:gmatch("%S+") do
    i = i + 1
    local low = w:lower()
    if STOP[low] or low:find("^d'") or low:find("^l'") then stop = true end
    -- (the first word, then the small ones: a name inside stays, "Frostmane")
    if not stop and (i == 1 or not w:find("^%u")) then
      if w:find("%-") then
        -- (a verb and a noun stays: "protège-poignets", "casse-noisettes";
        -- two nouns both take it: "hommes-loups")
        local first = w:match("^[^%-]+"):lower():gsub("^\195\137", "\195\169")
        if VERB_FIRST[first] then
          -- (the noun after it takes the -s, if it has none: "haut-trotteurs")
          w = w:gsub("([^%-]+)$", pluralWord)
        else
          w = w:gsub("[^%-]+", pluralWord)
        end
      else
        w = pluralWord(w)
      end
    end
    out[#out + 1] = w
  end
  return table.concat(out, " ")
end
F.pluralOf = pluralOf
local function frPlural(name)
  local e = creatureOf(name)
  if type(e) ~= "table" then e = itemOf(name) end
  if not e then
    F.unknown[name] = true
    return name
  end
  local g = e[2]:gsub("p", "") .. "p"
  local n = pluralOf(e.lc and lowered(e) or e[1])
  return made(n, g, n)
end

local function frDeathFoe(d)
  if not d.foe then return nil end
  if d.player or d.inside or d.rank == "rare" or d.rank == "rareelite" or d.rank == "worldboss" then
    return d.player and d.foe or nameOf(d.foe)
  end
  if d.rank == "elite" and d.foe and not d.foe:find(" ") and d.foe:match("^%u") then return nameOf(d.foe) end
  return frArticle(d.foe)
end

-- ── a slot's French ──────────────────────────────────────────────────────────
local PEOPLE_SLOTS = { giver = true, via = true, ender = true, boss = true, who = true, rare = true, by = true }
local PASS = { pet = true, name = true, mates = true }
local SIDES = { ["the Horde"] = "la Horde", ["the Alliance"] = "l'Alliance" }
-- (a raw name's French by the slot it fills)
local function bySlot(slot, v)
  if SIDES[v] then return SIDES[v] end
  if slot == "times" then
    if v == "twice" then return "deux fois" end
    local n = v:match("^(.-) times$")
    return n and F.memo[n] and (F.memo[n] .. " fois") or nil
  end
  if slot == "spell" or slot == "spells" then
    local e = lookup("spells", v)
    if type(e) == "table" then return made(e[1], e[2], e[1]) end
    return e
  elseif slot == "spec" or slot == "was" then
    local e = lookup("treeIds", v) or lookup("specIds", v)
    return e and (type(e) == "table" and e[1] or e) or nil
  elseif slot == "prof" then
    local e = lookup("skillIds", v)
    if type(e) == "table" then
      local n = lowered(e)
      return made(definiteOf(n, e[2]), e[2], n)
    end
  elseif slot == "rank" then
    return RANKS[v]
  elseif slot == "mount" then
    local e = lookup("mounts", v)
    if type(e) == "table" then return made(lowered(e), e[2], lowered(e)) end
  elseif slot == "from" or slot == "to" then
    local e = placeOrThe(v)
    if e then return made(withArticle(e), e[2], e[1]) end
    local t = lookup("taxiIds", v)
    if type(t) == "string" then return t:match("^([^,]+)") or t end
  elseif PEOPLE_SLOTS[slot] or slot == "foe" then
    local bare = v:match("^the (.+)$")
    if bare then return definiteCreature(bare) end
    return nameOf(v)
  elseif slot == "item" or slot == "things" then
    return frItem(v)
  elseif slot == "family" or slot == "demon" then
    return frArticle(v)
  elseif PASS[slot] then
    return v
  end
  return nil
end
-- (a name by itself, whatever slot or list it came in: a place, a creature, an
-- item, a trade, a spell)
local function generic(v)
  local e = placeOf(v)
  if e then return made(withArticle(e), e[2], e[1]) end
  -- (a trade before a creature: Forever has a creature called "Leatherworking")
  e = lookup("skillIds", v)
  if type(e) == "table" then
    local n = lowered(e)
    return made(definiteOf(n, e[2]), e[2], n)
  end
  e = creatureOf(v)
  if type(e) == "table" then
    local n = v:find("^%l") and lowered(e) or e[1]
    return made(n, e[2], n)
  end
  e = itemOf(v)
  if e then return frItem(v) end
  e = lookup("spells", v)
  if type(e) == "table" then return e[1] end
  local boss = lookup("encounters", v)
  if type(boss) == "string" then return boss end
  -- (last, a place without its "The": a deed's [[Crossroads]])
  e = placeOrThe(v)
  if e then return made(withArticle(e), e[2], e[1]) end
  return nil
end
F.generic = generic
local LISTS_OF = { lands = true, foes = true, mates = true, spells = true, prof = true, things = true, zones = true }
-- A slot's French: what the helpers made, else the name by its kind, else
-- the name as kept (a player's, a pet's, one the client gave in French).
function F.value(slot, v)
  if v == nil then return nil end
  if type(v) == "number" then return tostring(v) end
  if v == "" then return "" end
  if v == "there" then return "l\195\160" end
  local m = F.memo[v]
  if m then return m end
  local ok, fr = pcall(bySlot, slot, v)
  if ok and fr then return fr end
  if slot == "why" or slot == "why2" then return nil end -- (a deed: its French, or none)
  ok, fr = pcall(generic, v)
  if ok and fr then return fr end
  -- (a list the helpers didn't make: each name by the slot's kind)
  if LISTS_OF[slot] and (v:find(", ") or v:find(" and ")) then
    local items = {}
    for part in (v:gsub(", and ", ", "):gsub(" and ", ", ") .. ","):gmatch("%s*(.-),") do
      if part ~= "" then items[#items + 1] = F.value(slot, part) or part end
    end
    return listing(items)
  end
  if PASS[slot] or PEOPLE_SLOTS[slot] then return v end
  F.unknown[v] = true
  return v
end

-- ── the helpers, wrapped: each English result remembered with its French ────
local function remember(en, fr)
  if type(en) == "string" and type(fr) == "string" then F.memo[en] = fr end
end
F.remember = remember
local FRENCH_OF = {
  mid = function(name) return frMid(name) end,
  at = function(name) return frAt(name) end,
  article = frArticle,
  itemName = frItem,
  plural = frPlural,
  words = words,
  playedWords = playedWords,
  deathFoe = frDeathFoe,
  listing = function(items)
    local fr, genders = {}, {}
    for _, item in ipairs(items or {}) do
      local f = F.memo[item] or F.value("", item) or item
      fr[#fr + 1] = f
      genders[#genders + 1] = F.gender[f]
    end
    local out = listing(fr)
    local bares = {}
    for k, f in ipairs(fr) do
      bares[k] = F.bare[f] or f
    end
    if out then F.bare[out] = listing(bares) end
    if out and #fr > 1 then
      local fem = true
      for _, g in ipairs(genders) do
        if not (g and g:find("^f")) then fem = false end
      end
      F.gender[out] = fem and "fp" or "mp"
    elseif out then
      F.gender[out] = genders[1]
    end
    return out
  end,
}
for key, fr in pairs(FRENCH_OF) do
  local en = W[key]
  W[key] = function(...)
    local out = en(...)
    if F.on and type(out) == "string" and F.memo[out] == nil then
      local ok, f = pcall(fr, ...)
      if ok then remember(out, f) end
    end
    return out
  end
end

-- ── the voice: home, kin, faith, a weapon ────────────────────────────────────
local KIN = {
  Human = "mon peuple",
  Dwarf = A .. "les miens",
  Gnome = A .. "les autres gnomes",
  NightElf = A .. "les miens",
  Orc = "mon clan",
  Troll = A .. "les Darkspear", -- (the game's French keeps the name: "Trolls Darkspear")
  Tauren = "ma tribu",
  Scourge = A .. "les R\195\169prouv\195\169s",
  Skyborne = A .. "les shen'dorei",
}
local FAITH = {
  ["the Light"] = A .. "la Lumi\195\168re",
  Elune = "Elune",
  ["the Earth Mother"] = A .. "la Terre-M\195\168re",
  ["the loa"] = A .. "les loas",
  ["the ancestors"] = A .. "les anc\195\170tres",
  ["the spirits"] = A .. "les esprits",
}
local WEAPONS = {
  ["my weapon"] = "mon arme",
  ["my rifle"] = "mon fusil",
  ["my bow"] = "mon arc",
  ["my hammer"] = "mon marteau",
  ["my dagger"] = "ma dague",
  ["my mace"] = "ma masse",
  ["my staff"] = "mon b\195\162ton",
  ["my axe"] = "ma hache",
  ["my polearm"] = "mon arme d'hast",
  ["my sword"] = "mon \195\169p\195\169e",
  ["my fists"] = "mes poings",
  ["my crossbow"] = "mon arbal\195\168te",
}
local HOME = {
  Stormwind = "Hurlevent",
  Ironforge = "Forgefer",
  Darnassus = "Darnassus",
  Orgrimmar = "Orgrimmar",
  ["Sen'jin Village"] = A .. "le village de Sen'jin",
  ["Thunder Bluff"] = A .. "les Pitons-du-Tonnerre",
  ["the Undercity"] = "Fossoyeuse",
}
local function voice(slot, v)
  if slot == "kin" then
    for race, en in pairs(W.KIN) do
      if en == v then return KIN[race] end
    end
  elseif slot == "faith" then
    return FAITH[v]
  elseif slot == "weapon" then
    return WEAPONS[v]
  elseif slot == "home" then
    -- (the place's own French, else the voice's)
    local e = placeOf(v == "Stormwind" and "Stormwind City" or v:gsub("^the ", ""))
    if e then return withArticle(e) end
    return HOME[v]
  end
end

-- ── the game's names in French text ──────────────────────────────────────────
-- A name written in a French line or deed is the game's own, each game's
-- ("Ironforge" on Classic's French client, "Forgefer" on Forever's), never
-- typed: [[Ironforge]] (a place with its article, a creature, an item, a
-- trade), [[at:Coldridge Valley]] ("dans la vallée des Frigères"),
-- [[un:Frostmane Troll Whelp]], [[le:Defias Messenger]], [[name:Hogger]],
-- [[spell:Life Tap]] (a spell, never a creature or an item of its name),
-- [[sort:Hunter's Mark]] (a spell with its article: "la Marque du chasseur"),
-- [[faction:Frostwolf Clan]] (a faction, each game's: "Clan Loup-de-Givre"),
-- [[spec:Beast Mastery]] (a talent tree, a specialization), [[les:Kobold
-- Vermin]], [[des:X]], [[pl:X]] (a creature or an item, in the plural: "les
-- vermines kobolds"); [[un:X]] and [[le:X]] take an item too.
-- (a creature, else an item: what a deed names in passing)
local function thingOf(english)
  local e = creatureOf(english)
  if type(e) == "table" then return e, true end
  e = itemOf(english)
  if e then return e, false end
end
local PLURAL = { les = true, des = true, pl = true }
local TOKENS =
  { at = true, un = true, le = true, name = true, spell = true, sort = true, faction = true, clan = true, spec = true }
for k in pairs(PLURAL) do
  TOKENS[k] = true
end
local function gameName(form, english)
  if form == "at" then return frAt(english) end
  if form == "un" or form == "le" or PLURAL[form] then
    local e, living = thingOf(english)
    if not e then
      F.unknown[english] = true
      if form == "un" then return "un " .. english end
      if form == "le" then return A .. "le " .. english end
      return english
    end
    -- (a creature as the game writes it in a sentence; an item's name kept as
    -- a name, but in the plural a common noun: "des fourrures de loup")
    local n = ((living and e.lc) or PLURAL[form]) and lowered(e) or e[1]
    local g = e[2]
    if PLURAL[form] then
      n = pluralOf(n)
      if form == "les" then return A .. "les " .. n end
      if form == "des" then return "des " .. n end
      return n
    end
    if form == "le" then return definiteOf(n, g) end
    return indefiniteOf(n, g)
  end
  if form == "name" then return nameOf(english) end
  if form == "faction" then
    local f = FN.factions and FN.factions[english]
    if not f then F.unknown[english] = true end
    return f or english
  end
  -- (a clan by its faction's name, as each game writes it: "Clan Frostwolf"
  -- gives "Frostwolf", Forever's "Clan Loup-de-Givre" gives "Loup-de-Givre")
  if form == "clan" then
    local f = FN.factions and FN.factions[english]
    if not f then
      F.unknown[english] = true
      return english
    end
    return (f:gsub("^Clan ", ""):gsub("^Garde ", ""))
  end
  if form == "spec" then
    local e = lookup("treeIds", english) or lookup("specIds", english)
    if type(e) == "table" then return e[1] end
  end
  if form == "spell" or form == "sort" then
    local e = lookup("spells", english)
    if type(e) == "table" then return form == "sort" and definiteOf(e[1], e[2]) or e[1] end
  end
  return generic(english) or (function()
    F.unknown[english] = true
    return english
  end)()
end
local function names(s)
  return (
    s:gsub("%[%[(.-)%]%]", function(inner)
      local form, english = inner:match("^(%a+):(.+)$")
      if not TOKENS[form or ""] then
        form, english = "", inner
      end
      return gameName(form, english)
    end)
  )
end
F.names = names

-- ── a line told ──────────────────────────────────────────────────────────────
-- The French template of the line chosen (e: Lines.lua's candidate).
local function template(book, kind, e)
  -- (its place in its kind: "d-why2#2", never the id's end, "d-why22")
  local i = tonumber((e.reach or ""):match("#(%d+)$") or e.id:match("(%d+)$"))
  if e.id:sub(1, 2) == "v:" then
    local own = FW.voices[book.c.race or "Human"]
    return own and own[kind] and own[kind][i]
  end
  return FW.writing[kind] and FW.writing[kind][i]
end
local FORMS = { m = 1, f = 2, mp = 3, fp = 4 }
local function agree(forms, g)
  local list = {}
  for x in (forms .. "|"):gmatch("([^|]*)|") do
    list[#list + 1] = x
  end
  g = g or "m"
  if #list == 2 then return list[g:find("^f") and 2 or 1] end
  return list[FORMS[g] or 1] or list[1]
end
-- A template filled: its slots' French (nil when one has none), the
-- narrator's gender, French's contractions.
function F.fill(fr, values, book, raw)
  local missing
  local female = book.c.sex == 3
  local function slot(name)
    local v = values[name]
    local f
    if name == "home" or name == "kin" or name == "faith" or name == "weapon" then
      f = (v ~= nil) and voice(name, v) or nil
    else
      f = F.value(name, v)
    end
    if f == nil then missing = name end
    return f
  end
  local out = fr:gsub("{(%w+)([:=]?)([^}]*)}", function(name, how, arg)
    local f = slot(name)
    if not f then return "" end
    if how == ":" then
      local bare, g = F.bare[f] or f, F.gender[f]
      if arg == "un" then return indefiniteOf(bare, g) end
      if arg == "le" then return definiteOf(bare, g) end
      if arg == "de" then return "de " .. definiteOf(bare, g) end
      if arg == "nu" then return bare end -- (the noun alone: "en {prof:nu}", "en minage")
      -- (a place without its preposition, its article kept: "partie de {at:lieu}",
      -- "partie du Glas", "repris la route depuis {at:lieu}")
      -- (no place: the word before it goes too, "partie, avec…" as the English drops it)
      if arg == "lieu" then return f == "" and "\2" or F.place[f] or f end
      return f
    elseif how == "=" then
      return agree(arg, F.gender[f])
    end
    return f
  end)
  if missing then return nil end
  out = out:gsub("%s*[^%s]+%s+\2", "")
  out = tidy(gendered(names(out), female))
  out = out:gsub(" +([%.,])", "%1"):gsub("  +", " "):gsub("^[ ,]+", ""):gsub(",%s*,", ",")
  return raw and out or capital(out)
end
-- The French of a line told (Book:say), nil when it has none.
function F.say(book, kind, e, values, raw)
  local fr = template(book, kind, e)
  if not fr then
    F.missing[(e.id:sub(1, 2) == "v:" and (book.c.race or "") .. "/" or "") .. kind .. ": " .. e.s[1]] = true
    return nil
  end
  local out = F.fill(fr, values, book, raw)
  if not out then F.missing["(a slot without French) " .. kind .. ": " .. e.s[1]] = true end
  return out
end
-- A place's description (writing/scenery/), its line by index.
function F.scenery(book, name, i)
  local p = FW.scenery[name]
  local fr = p and p[i]
  if not fr then
    F.missing["scenery " .. name .. " #" .. i] = true
    return nil
  end
  return capital(tidy(gendered(names(fr), book.c.sex == 3)))
end
-- A piece Diary.lua joins, by its key (i18n/frFR/writing/glue.md), filled.
function F.glue(key, values, book, raw)
  local fr = FW.glue[key]
  if not fr then return nil end
  local missing
  local out = fr:gsub("{(%w+)}", function(name)
    local v = values[name]
    if v == nil then missing = name end
    return v or ""
  end)
  if missing then return nil end
  out = tidy(gendered(names(out), book and book.c.sex == 3))
  out = out:gsub(" +([%.,])", "%1"):gsub("  +", " ")
  return raw and out or capital(out)
end

-- ── the deeds ────────────────────────────────────────────────────────────────
-- (in a quest's deed, my own people are mine: "pour les Réprouvés" is "pour
-- les miens" in a Forsaken's diary; "les Réprouvés de Fossoyeuse" stays)
local OURS = {
  Human = { "humains" },
  Dwarf = { "nains" },
  NightElf = { "elfes de la nuit", "kaldorei" },
  Gnome = { "gnomes" },
  Orc = { "orcs" },
  Troll = { "trolls Darkspear", "Darkspear" },
  Tauren = { "taurens", "shu'halo" },
  Scourge = { "R\195\169prouv\195\169s" },
}
-- (as the people it replaces: "les humains avaient" is "les miens avaient";
-- after a noun "de mon peuple", never "des miens": docs/race-voices.md)
local OURS_ARTICLE = { les = "les miens", des = "de mon peuple", aux = "aux miens" }
local OURS_FOLLOWS = {}
for w in
  ([[qui que et ou mais car pour contre avec sans dans sur sous vers chez avant après depuis
  à a ont avaient était étaient sont ne n' se s' lui leur leurs eux y en]]):gmatch("%S+")
do
  OURS_FOLLOWS[w] = true
end
function F.ours(text, race)
  for _, people in ipairs(OURS[race] or {}) do
    text = text:gsub(
      "(%f[%w%z\128-\255])(%a+) " .. people:gsub("%p", "%%%0") .. "(.?)(%S*)",
      function(b, art, sep, word)
        local swap = OURS_ARTICLE[art:lower()]
        if not swap then return nil end
        if sep ~= "" and sep ~= " " and sep:find("[%w\128-\255]") then return nil end
        local follow = (word or ""):lower():match("^[%a\128-\255']+")
        if sep == " " and follow and not OURS_FOLLOWS[follow] then return nil end
        return b .. swap .. sep .. word
      end
    )
  end
  return text
end
-- A quest's deed in French, after "je" (its English remembered beside it).
function F.deed(id, english, race)
  local fr = FW.why[id]
  if not fr then return nil end
  fr = F.ours(names(fr), race)
  remember(english, fr)
  return fr
end

-- A name for an entry's title: a quest's, a place's, a creature's, a spell's,
-- a mount's, as the game writes it in French; a pet's as it is.
function F.title(english, quest)
  if not english then return nil end
  if quest then
    local q = lookup("quests", english)
    if type(q) == "string" then return q end
  end
  local p = placeOf(english)
  if p then
    local a = p[3] or ""
    return upperFirst(a == "" and p[1] or (withArticle(p):gsub(A, "")))
  end
  local c = creatureOf(english)
  if type(c) == "table" then return c[1] end
  local s = lookup("spells", english)
  if type(s) == "table" then return s[1] end
  local m = lookup("mounts", english)
  if type(m) == "table" then return m[1] end
  local q = lookup("quests", english)
  if type(q) == "string" then return q end
  return english
end

-- (the other side's people: "un chasseur elfe de la nuit"; the game's own
-- names, a woman's where it has one)
local RACE = {
  Human = { "humain", "humaine" },
  Dwarf = { "nain", "naine" },
  NightElf = { "elfe de la nuit", "elfe de la nuit" },
  Gnome = { "gnome", "gnome" },
  Orc = { "orc", "orque" },
  Troll = { "troll", "trollesse" },
  Tauren = { "tauren", "taur\195\168ne" },
  Scourge = { "r\195\169prouv\195\169", "r\195\169prouv\195\169e" },
  Skyborne = { "shen'dorei", "shen'dorei" },
}
local CLASS_ID =
  { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
function F.someone(race, class, female)
  local r = RACE[race or ""]
  local c = FN.classes and FN.classes[CLASS_ID[class or ""] or 0]
  local cm, cf
  if c then
    cm, cf = c:match("^([^|]+)|?(.*)$")
  end
  local cname = c and lowerFirst(female and cf ~= "" and cf or cm) or nil
  local rname = r and r[female and 2 or 1]
  if not (cname or rname) then return nil end
  local n = cname and (rname and cname .. " " .. rname or cname) or rname
  return made((female and "une " or "un ") .. n, female and "f" or "m", n)
end

return F
