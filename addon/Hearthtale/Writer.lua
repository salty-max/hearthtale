-- The writer: turns the records into the journal's prose, when it is read
-- (never stored), in scenes (Book:chapter). Each moment picks a sentence or a
-- clause of its kind (writing/<kind>.md):
--   - only sentences whose [tags] the moment has (night, hc, race:Dwarf...;
--     "!night" = not at night) and whose {slots} it can fill;
--   - a sentence never used twice in a book while a fresh one is left (then the
--     one used longest ago);
--   - chosen by a hash of the character and the moment, so the book reads the
--     same each time it is opened.
-- A place just named becomes "there"; counts are written in words; every
-- sentence starts with a capital. A place is named ("in Thelsamar"), then
-- "there" once, then left out ("I put down six wolves."): {at} must read well
-- without it. {in} always names the place (for sentences without a verb:
-- "Timber in Shimmer Ridge.").
local _, ns = ...
local floor = math.floor

-- ── words ────────────────────────────────────────────────────────────────────
local ONES = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
  "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen" }
local TENS = { [2] = "twenty", [3] = "thirty", [4] = "forty", [5] = "fifty", [6] = "sixty", [7] = "seventy",
  [8] = "eighty", [9] = "ninety" }
local function words(n)
  n = floor(n)
  if n <= 0 then return "no" end
  if n < 20 then return ONES[n] end
  if n < 100 then
    local t, u = floor(n / 10), n % 10
    return TENS[t] .. (u > 0 and "-" .. ONES[u] or "")
  end
  if n < 1000 then
    local h, r = floor(n / 100), n % 100
    return (h == 1 and "a hundred" or ONES[h] .. " hundred") .. (r > 0 and " and " .. words(r) or "")
  end
  return tostring(n)
end
ns.words = words

local function listing(items)
  if #items == 0 then return nil end
  if #items == 1 then return items[1] end
  return table.concat(items, ", ", 1, #items - 1) .. " and " .. items[#items]
end
ns.listing = listing

-- A name inside a sentence: "The Barrens" reads "the Barrens", and a place
-- the game names without its article reads with it ("the Valley of Strength").
local COMMON = { Valley = true, Temple = true, Hall = true, Halls = true, Ring = true, Cleft = true, Vale = true,
  Den = true, Field = true, Fields = true, Isle = true, Ruins = true, Tower = true, Gate = true, Gates = true,
  Shrine = true, Sanctum = true, Caverns = true, Court = true, Terrace = true, Pools = true, Circle = true }
local TRAILING = { District = true, Quarter = true } -- "the Dwarven District", "the Mage Quarter"
local function mid(name)
  if not name then return nil end
  local first = name:match("^(%a+) of ")
  if first and COMMON[first] then return "the " .. name end
  if TRAILING[name:match("(%a+)$") or ""] and not name:find("^The ") then return "the " .. name end
  return (name:gsub("^The ", "the "))
end

local IRREGULAR = { Wolf = "Wolves", Thief = "Thieves", Elf = "Elves", Dwarf = "Dwarves", Man = "Men",
  Woman = "Women", Mouse = "Mice", Sheep = "Sheep", Deer = "Deer", Shaman = "Shamans", Undead = "Undead", Dead = "Dead",
  Vermin = "Vermin", Wildkin = "Wildkin", Moonkin = "Moonkin",
  Dragonkin = "Dragonkin", Kin = "Kin", Wolfkin = "Wolfkin", Spawn = "Spawn", Fish = "Fish" }
local function plural(name)
  local head, tail = name:match("^(.-)( of .+)$")
  if head then return plural(head) .. tail end
  local before, last = name:match("^(.-)(%S+)$")
  if IRREGULAR[last] then return before .. IRREGULAR[last] end
  if last:match("[^aeiouAEIOU]y$") then return before .. last:sub(1, -2) .. "ies" end
  if last:match("ss$") or last:match("[xz]$") or last:match("[cs]h$") then return name .. "es" end
  if last:match("s$") then return name end -- already many: "Scavenged Goods"
  if last:match("[a-z]man$") then return before .. last:sub(1, -4) .. "men" end
  return name .. "s"
end
ns.plural = plural

-- An item: "a Wolf Fang Necklace", but "Cuirboulle Gloves", "Blackened Defias
-- Armor", "Smite's Mighty Hammer".
local TROPHY = { Head = true, Skull = true, Heart = true, Scalp = true }
local MASS = { Armor = true, Mail = true, Garb = true, Attire = true, Regalia = true, Raiment = true, Plate = true, Leather = true }
local function itemName(name)
  -- its own article: "An Unsent Letter" reads "an Unsent Letter"
  local own = name:match("^(An?) ") or name:match("^(The) ")
  if own then return own:lower() .. name:sub(#own + 1) end
  -- a trophy: "Head of VanCleef" is VanCleef's head
  local part, whose = name:match("^(%a+) of (.+)$")
  if part and TROPHY[part] then return whose .. "'s " .. part:lower() end
  -- the thing itself, before an "of": "Chausses of Westfall" are many
  local last = (name:match("^(.-) of ") or name):match("(%S+)$")
  if name:find("'s ") or last:match("s$") or MASS[last] then return name end
  return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end
ns.itemName = itemName

-- Things in numbers: "six Crag Boar Ribs", but "eight Tough Wolf Meat" (a
-- name that can't be counted stays as it is).
local UNCOUNTED = { Meat = true, Cloth = true, Leather = true, Silk = true, Wool = true, Ore = true, Water = true, Oil = true,
  Blood = true, Moss = true, Sand = true, Ash = true, Powder = true, Venom = true, Ichor = true, Dust = true, Silver = true,
  Gold = true, Iron = true, Copper = true, Bark = true, Root = false, Mail = true, Grain = true, Barley = true, Rye = true, Corn = true }
local function things(name)
  local last = name:match("(%S+)$")
  if name:find("'s ") or UNCOUNTED[last] or last:find("weed$") or last:find("moss$") or last:find("dust$") then return name end
  return plural(name)
end
ns.things = things

-- A creature named in passing: "a Frostmane Novice". The game can't tell a
-- named creature from a common one, so only rares go without (by their name).
-- (a title is a name of its own: "Mr. Smite", "Captain Greenskin")
local TITLES = { Mr = true, Mrs = true, Captain = true, Lord = true, Lady = true, King = true, Queen = true,
  Prince = true, Princess = true, Baron = true, Baroness = true, General = true, Commander = true, Chief = true,
  Overlord = true, Archmage = true, Foreman = true, Sergeant = true, Lieutenant = true, Marshal = true,
  Master = true, Emperor = true, Warlord = true, Highlord = true, Count = true, Duke = true, Magistrate = true }
local function article(name)
  if not name then return nil end
  if TITLES[name:match("^(%a+)") or ""] then return name end
  return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end

-- Kinds worth a "first of its kind" (the game's English names; people are
-- not a kind, critters are not a fight, and a beast without a family is
-- just a beast).
local KINDS = {
  Wolf = "wolves", Cat = "great cats", Spider = "spiders", Bear = "bears", Boar = "boars", Crocolisk = "crocolisks",
  ["Carrion Bird"] = "carrion birds", Crab = "crabs", Gorilla = "gorillas", Raptor = "raptors",
  Tallstrider = "tallstriders", Scorpid = "scorpids", Turtle = "turtles", Bat = "bats", Hyena = "hyenas",
  Owl = "owls", ["Wind Serpent"] = "wind serpents", Serpent = "serpents", Dragonhawk = "dragonhawks",
  Ravager = "ravagers", ["Warp Stalker"] = "warp stalkers", Sporebat = "sporebats", ["Nether Ray"] = "nether rays",
  Undead = "undead", Elemental = "elementals", Demon = "demons", Dragonkin = "dragonkin",
  Giant = "giants", Mechanical = "constructs",
}
local SKIP = { Critter = true, ["Non-combat Pet"] = true, Totem = true, ["Not specified"] = true, ["Gas Cloud"] = true }
-- Creature types that are not beasts (a beast's kind is "Beast" or its family).
local NOT_BEAST = { Humanoid = true, Undead = true, Elemental = true, Demon = true, Dragonkin = true, Giant = true,
  Mechanical = true, Critter = true, Aberration = true }

-- What killed me, as tags and the {foe} slot: a player by name, a rare or a
-- boss by name, any other creature with an article.
local function deathTags(d)
  local t = { [d.cause or "foe"] = true }
  if d.cause == "foe" then
    if d.player then t.player = true
    elseif d.kind == "Humanoid" then t.people = true
    elseif d.kind and not NOT_BEAST[d.kind] then t.beast = true end
    if d.rank == "elite" or d.rank == "rareelite" or d.rank == "worldboss" then t.elite = true end
  end
  if d.inside then t.inside = true end
  return t
end
-- A named elite goes without an article: the game can't tell one from a common
-- elite, but a one-word name is a name (Stitches, Hogger), where "a Defias
-- Overseer" keeps its article.
local function namedElite(name) return name and not name:find(" ") and name:match("^%u") ~= nil end
local function deathFoe(d, article)
  if not d.foe then return nil end
  if d.player or d.inside or d.rank == "rare" or d.rank == "rareelite" or d.rank == "worldboss" then return d.foe end
  if d.rank == "elite" and namedElite(d.foe) then return d.foe end
  return article(d.foe)
end

local function playedWords(s)
  if not s or s < 60 then return nil end
  local m = floor(s / 60 + 0.5)
  if m > 20 then m = floor(m / 5 + 0.5) * 5 end
  if m < 60 then return m == 1 and "a minute" or words(m) .. " minutes" end
  local h, r = floor(m / 60), m % 60
  if h < 2 then
    if r == 0 then return "an hour" end
    if r == 30 then return "an hour and a half" end
    return "an hour and " .. words(r) .. " minutes"
  end
  if r >= 45 then h, r = h + 1, 0 end
  if h >= 24 then
    local d = floor(h / 24 + 0.5)
    return d == 1 and "a whole day" or words(d) .. " days"
  end
  return words(h) .. " hours" .. ((r >= 15 and r < 45) and " and a half" or "")
end
ns.playedWords = playedWords

local function goldWords(copper)
  if not copper or copper < 1 then return nil end
  if copper < 20 then return "a few coppers" end
  if copper < 100 then return words(copper) .. " copper" end
  if copper < 10000 then
    local s = floor(copper / 100)
    return s == 1 and "a silver piece" or words(s) .. " silver"
  end
  local g = floor(copper / 10000)
  return g == 1 and "a gold piece" or words(g) .. " gold"
end
ns.goldWords = goldWords

local function capitalise(text)
  text = text:gsub("^(%W*)(%l)", function(p, c) return p .. c:upper() end)
  return (text:gsub("([%.!%?]\"? +%W*)(%l)", function(p, c) return p .. c:upper() end))
end

-- ── the voice ────────────────────────────────────────────────────────────────
local FACTION = { Human = "alliance", Dwarf = "alliance", NightElf = "alliance", Gnome = "alliance", Draenei = "alliance",
  Orc = "horde", Troll = "horde", Tauren = "horde", Scourge = "horde", BloodElf = "horde" }
local HOME = { Human = "Stormwind", Dwarf = "Ironforge", Gnome = "Ironforge", NightElf = "Darnassus", Draenei = "the Exodar",
  Orc = "Orgrimmar", Troll = "Sen'jin Village", Tauren = "Thunder Bluff", Scourge = "the Undercity", BloodElf = "Silvermoon" }
local KIN = { Human = "my people", Dwarf = "my kin", Gnome = "my fellow gnomes", NightElf = "my kin", Draenei = "my people",
  Orc = "my clan", Troll = "the Darkspear", Tauren = "my tribe", Scourge = "the Forsaken", BloodElf = "my people", Skyborne = "the shen'dorei" }
local FAITH_RACE = { Human = "the Light", Dwarf = "the Light", Draenei = "the Light", NightElf = "Elune",
  Tauren = "the Earth Mother", Troll = "the loa", Orc = "the ancestors" }
local function faith(race, class)
  if class == "WARLOCK" or class == "ROGUE" then return nil end
  if class == "SHAMAN" then return "the spirits" end
  if class == "PALADIN" then return "the Light" end
  if class == "PRIEST" and not FAITH_RACE[race] then return "the Light" end
  return FAITH_RACE[race]
end
-- {weapon} is only ever an object ("fell to my hammer"), never a subject.
local function weapon(race, class)
  if class == "WARRIOR" then
    return (race == "Orc" or race == "Dwarf" or race == "Tauren" or race == "Troll") and "my axe" or "my sword"
  end
  if class == "HUNTER" then return race == "Dwarf" and "my rifle" or "my bow" end
  return ({ PALADIN = "my hammer", ROGUE = "my blades", SHAMAN = "my mace" })[class] or "my staff"
end

-- ── the writer of one book ───────────────────────────────────────────────────
local function hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483648 end
  return h
end

local function satisfied(tags, ctx)
  for _, t in ipairs(tags or {}) do
    if t == "aside" or t == "plain" then -- marks, not conditions
    elseif t:sub(1, 1) == "!" then
      if ctx[t:sub(2)] then return false end
    elseif not ctx[t] then return false end
  end
  return true
end

local function fillable(text, values)
  for slot in text:gmatch("{(%w+)}") do
    if values[slot] == nil then return false end
  end
  return true
end

local function hasTag(s, tag)
  for _, t in ipairs(s.tags or {}) do if t == tag then return true end end
  return false
end
-- A race's or a class's line.
local function isVoice(s)
  for _, t in ipairs(s.tags or {}) do
    if t:find("^race:") or t:find("^class:") then return true end
  end
  return false
end
-- A sentence with a quip, marked [aside] in writing/ ("I saw it through.
-- Nobody died, least of all me.").
local function isQuip(s)
  for _, t in ipairs(s.tags or {}) do if t == "aside" then return true end end
  return false
end
-- The moments that may always have one.
local MATTERS = { ["close-light"] = true, ["close-deep"] = true, rare = true, died = true, rest = true, night = true,
  beginning = true, power = true, petdied = true }

-- How each race's journal runs (with its own sentences, writing/voices/): how
-- many clauses a sentence holds, and its own time words over the shared ones.
local STYLE = {
  default = { clauses = 3, links = {} },
  Dwarf = { clauses = 3, links = {
    night = { "Come nightfall,", "When the light went,", "That night," },
    day = { "At first light,", "Come morning,", "With the dawn," },
  } },
  Orc = { clauses = 3, links = {
    night = { "At nightfall,", "In the dark,", "That night," },
    day = { "At sunrise,", "With the sun,", "At dawn," },
    later = { "Later,", "Hours later," },
  } },
  NightElf = { clauses = 3, links = {
    night = { "Beneath the moon,", "When Elune rose,", "As night fell," },
    day = { "At dawn,", "With the first light,", "As the stars faded," },
    later = { "In time,", "Some hours later,", "Later that day," },
  } },
  Scourge = { clauses = 3, links = {
    night = { "After dark,", "In the dark hours,", "That night," },
    day = { "When the sun rose,", "By morning,", "Morning came, and" },
    later = { "Later,", "In due course,", "Some hours on," },
  } },
}

-- How many uses of a kind before one of the race's own sentences may come back.
local OWN_GAP = 8
-- The routine clauses, and the pool of remarks each may end with: the
-- narrator's own reaction ("…, with rather more appetite for supper"), told
-- for about one routine clause in three, never the same one soon again.
local ROUTINE = {
  ["c-kill"] = "r-foe", ["c-deed-kill"] = "r-foe", ["c-first"] = "r-first", ["c-deed-item"] = "r-item",
  ["c-deed-task"] = "r-task", ["c-deed-word"] = "r-task", ["c-deliver"] = "r-task", ["c-gear"] = "r-gear", ["c-trainer"] = "r-lesson",
  ["c-skill"] = "r-lesson", ["c-prof"] = "r-lesson", ["c-travel"] = "r-road", ["c-return"] = "r-road",
  ["c-place"] = "r-road", ["c-inn"] = "r-inn", ["c-group"] = "r-company",
}
-- The last masters of the dungeons: their fall is a sentence of its own.
local FINAL = {}
for _, name in ipairs({ "Taragaman the Hungerer", "Mutanus the Devourer", "Edwin VanCleef", "Archmage Arugal",
  "Aku'mai", "Bazil Thredd", "Mekgineer Thermaplugg", "Charlga Razorflank", "Herod", "Arcanist Doan",
  "Bloodmage Thalnos", "High Inquisitor Whitemane", "Amnennar the Coldbringer", "Archaedas",
  "Chief Ukorz Sandscalp", "Princess Theradras", "Shade of Eranikus", "Emperor Dagran Thaurissan",
  "Overlord Wyrmthalak", "General Drakkisath", "King Gordok", "Immol'thar", "Prince Tortheldrin",
  "Darkmaster Gandling", "Baron Rivendare", "Balnazzar" }) do FINAL[name] = true end

-- Chapters before a remark may come back (none fresh left): sooner than
-- that, the clause goes without.
local REMARK_GAP = 10
-- Tags that name what a remark is about: such a remark, when it fits, comes first.
local SUBJECTS = { teeth = true, mechanical = true, cloth = true, meat = true, explore = true, escort = true, made = true }

local Book = {}
Book.__index = Book

local function newBook(c)
  local race, class = c.race or "Human", c.class or "WARRIOR"
  local b = setmetatable({ c = c, used = {}, usedIn = {}, uses = 0, seed = c.guid or "", zones = {}, flown = false,
    repeats = 0, chapterNo = 0, kindUses = {}, voiceUsed = 0 }, Book)
  b.voice = { home = HOME[race], kin = KIN[race], faith = faith(race, class), weapon = weapon(race, class) }
  b.own = ns.data.voices and ns.data.voices[race] -- the race's own journal voice (writing/voices/<Race>/)
  b.style = STYLE[race] or STYLE.default
  b.faction = (c.faction == "alliance" or c.faction == "horde") and c.faction or FACTION[race]
  b.sceneSeen = {} -- places already described in this book
  b.remarkChapter = {} -- the chapter each remark was last told in
  b.creatureKinds = {} -- classifications actually recorded, not guessed from a quest's name
  b.placeNames = {} -- only places encountered so far; later events cannot rewrite an objective
  b.base = { hc = c.hardcore or nil, ["race:" .. race] = true, ["class:" .. class] = true }
  if b.faction then b.base["faction:" .. b.faction] = true end
  return b
end

-- One sentence of a kind for a moment: key makes the choice stable, values
-- fill the slots (_place: the place {at}, {in} or {where} names), tags add to
-- the character's. prefer: tags to favour (a fresh sentence with one of them
-- wins over the rest). raw: a clause, left as it is (no capital).
function Book:say(kind, key, values, tags, prefer, raw)
  local list = ns.data.writing[kind]
  if not list then return end
  -- The race's own voice for this kind (writing/voices/<Race>/), if it has one.
  local own = self.own and self.own[kind]
  local ctx = setmetatable(tags or {}, { __index = self.base })
  if kind == "c-return" then ctx.back = true end -- for its remark: a place known
  local routine, wantRemark = ROUTINE[kind], false
  self.selectedRoutine, self.selectedRemark = routine, false
  if routine then
    self.routineCount = (self.routineCount or 0) + 1
    if self.routineCount >= (self.nextRemark or 2) then
      if self.prepareRemark then self.prepareRemark() end
      wantRemark = not self.pendingRemark and not self.lastSentenceRemark
    end
  end
  for k, v in pairs(self.voice) do if values[k] == nil then values[k] = v end end
  -- A place just named is not named again by a sentence without a verb,
  -- unless no other sentence fits.
  local named = values["in"]
  if named and values._place == self.last and not self.there then values["in"] = nil end
  -- In a chapter: a race's or a class's line only in some chapters, twice at
  -- most; a sentence with a quip (a second, wry sentence) once a paragraph,
  -- but for the moments that matter.
  local function allowed(s)
    if not self.inChapter then return true end
    if isVoice(s) and not (self.voiceChapter and self.voiceUsed < 2) and not hasTag(s, "first") then return false end -- a first, once in a life, may
    if self.quipped and not MATTERS[kind] and isQuip(s) then return false end
    return true
  end
  -- The candidates, each with its id (what "used" remembers) and its name in
  -- the reachability test: the race's own ("Dwarf/kill#3") and the shared ("kill#3").
  local race = self.c.race or "Human"
  local ownFresh, fresh, voiced, all
  for pass = 1, 3 do
    ownFresh, fresh, voiced, all = {}, {}, {}, {}
    local function add(from, mine)
      for i, s in ipairs(from or {}) do
        if not (self.onlyPlain and pass < 3 and not hasTag(s, "plain"))
          and satisfied(s.tags, ctx) and fillable(s[1], values) and (pass % 3 == 0 or allowed(s)) then
          local e = mine and { s = s, id = "v:" .. kind .. i, reach = race .. "/" .. kind .. "#" .. i }
            or { s = s, id = kind .. i, reach = kind .. "#" .. i }
          table.insert(all, e)
          if not self.used[e.id] then
            if mine then table.insert(ownFresh, e)
            else
              table.insert(fresh, e)
              if s.tags then table.insert(voiced, e) end
            end
          end
        end
      end
    end
    add(own, true)
    add(list, false)
    if #all > 0 then break end
    -- nothing allowed: first the place may be named again, then the limits go
    if pass == 1 and values["in"] ~= named then values["in"] = named end
  end
  if #all == 0 then return end
  -- a routine clause doesn't begin with the verb of the one before, if a
  -- fresh one can help it
  local function sameVerb(e) return routine and e and e.s[1]:match("^(%a+)") == self.lastVerb end
  if routine and self.lastVerb then
    local function other(group)
      local kept = {}
      for _, e in ipairs(group) do if not sameVerb(e) then table.insert(kept, e) end end
      return kept
    end
    local o, f, v = other(ownFresh), other(fresh), other(voiced)
    if #o > 0 then ownFresh = o elseif #f > 0 then ownFresh = {} end
    if #f > 0 then fresh, voiced = f, v end
  end
  if prefer then
    local favoured = {}
    for _, group in ipairs({ ownFresh, fresh }) do
      for _, e in ipairs(group) do
        for _, t in ipairs(e.s.tags or {}) do
          if prefer[t] then table.insert(favoured, e) break end
        end
      end
    end
    if #favoured > 0 then ownFresh, fresh, voiced = {}, favoured, {} end
  end
  -- The race's own first while one is fresh; then the lowest bit chooses
  -- between the shared tagged lines and the rest, the others which.
  local h = hash(self.seed .. "|" .. kind .. "|" .. key)
  local pick = floor(h / 2)
  local e
  -- once all of the race's own were used: its oldest comes back, if it has
  -- been long enough (a voice that holds over a whole life, not shared prose)
  local ownOldest
  if #ownFresh == 0 then
    for _, x in ipairs(all) do
      if x.id:sub(1, 2) == "v:" and self.used[x.id] and (not ownOldest or self.used[x.id] < self.used[ownOldest.id]) then ownOldest = x end
    end
    -- (a routine clause's own verbs come back less often: they are short)
    local gap = ROUTINE[kind] and 2 * OWN_GAP or OWN_GAP
    if ownOldest and ((self.kindUses[kind] or 0) - self.usedIn[ownOldest.id] < gap or sameVerb(ownOldest)) then ownOldest = nil end
  end
  if #ownFresh > 0 then
    e = ownFresh[pick % #ownFresh + 1]
  elseif ownOldest then
    e = ownOldest
    self.repeats = self.repeats + 1
  elseif #voiced > 0 and h % 2 == 0 then
    e = voiced[pick % #voiced + 1]
  elseif #fresh > 0 then
    e = fresh[pick % #fresh + 1]
  else
    -- all used: the one used longest ago
    e = all[1]
    for _, x in ipairs(all) do if self.used[x.id] < self.used[e.id] then e = x end end
    self.repeats = self.repeats + 1
    local gap = (self.kindUses[kind] or 0) - self.usedIn[e.id]
    if not self.minGap or gap < self.minGap then self.minGap, self.minGapKind = gap, kind end
  end
  self.uses = self.uses + 1
  self.kindUses[kind] = (self.kindUses[kind] or 0) + 1
  self.used[e.id] = self.uses
  self.usedIn[e.id] = self.kindUses[kind]
  if ns.writerUsed then ns.writerUsed[e.reach] = true end
  local chosen = e.s
  local text = chosen[1]
  if routine then self.lastVerb = text:match("^(%a+)") end
  -- a remark ends a clause that has no comma of its own
  if wantRemark and not text:find(",") and not ctx.trophy then -- (a trophy speaks for itself)
    local remark = self:remark(routine, key, values, ctx)
    if remark then
      text = text .. ", " .. remark
      self.selectedRemark = true
      self.nextRemark = self.routineCount + 2 + hash(self.seed .. "|remark-gap|" .. key) % 2
    end
  end
  if self.inChapter then
    if isVoice(chosen) then self.voiceUsed = self.voiceUsed + 1 end
    if isQuip(chosen) and not MATTERS[kind] then self.quipped = true end
  end
  if text:find("{in}") or text:find("{where}") or text:find("{place}") or (text:find("{at}") and values._named) then
    self.last, self.there = values._place, false
  elseif text:find("{at}") and values.at == "there" then
    self.there = true
  elseif text:find("{inn}") then
    self.last, self.there = values._place, values.inn == "there"
  elseif text:find("{places}") or text:find("{zone}") then
    self.last = nil
  end
  text = text:gsub("{(%w+)}", values)
  -- a place left out: no space before the punctuation, none doubled
  -- (and none left at the start: "{at}, my tenth level" with no place)
  text = text:gsub(" +([%.,;:!%?])", "%1"):gsub("  +", " "):gsub("^[ ,;:]+", "")
  return raw and text or capitalise(text)
end

-- A remark from a pool (writing/r-*.md, and the race's own): a fresh one,
-- the race's first, one about the moment's subject (its teeth, the meat)
-- before the general; once all were used, the one used longest ago, if
-- REMARK_GAP chapters have passed; else none.
function Book:remark(pool, key, values, ctx)
  local race = self.c.race or "Human"
  local own, list = self.own and self.own[pool], ns.data.writing[pool]
  local ownFresh, fresh, all = {}, {}, {}
  local function add(from, mine)
    for i, s in ipairs(from or {}) do
      if satisfied(s.tags, ctx) and fillable(s[1], values) then
        local e = mine and { s = s, id = "v:" .. pool .. i, reach = race .. "/" .. pool .. "#" .. i }
          or { s = s, id = pool .. i, reach = pool .. "#" .. i }
        table.insert(all, e)
        if not self.used[e.id] then table.insert(mine and ownFresh or fresh, e) end
      end
    end
  end
  add(own, true)
  add(list, false)
  local function specific(group)
    local found = {}
    for _, e in ipairs(group) do
      for _, t in ipairs(e.s.tags or {}) do
        if SUBJECTS[t] then table.insert(found, e); break end
      end
    end
    return #found > 0 and found or group
  end
  local pick = hash(self.seed .. "|" .. pool .. "|" .. key)
  local function oldest(mine)
    local o
    for _, x in ipairs(all) do
      if (mine == nil or (x.id:sub(1, 2) == "v:") == mine) and (not o or self.used[x.id] < self.used[o.id]) then o = x end
    end
    return o and self.chapterNo - self.remarkChapter[o.id] >= REMARK_GAP and o or nil
  end
  -- the race's own while fresh, then back when spaced enough: the shared
  -- ones fill the gaps, so the voice holds over a whole life
  local e
  if #ownFresh > 0 then
    local group = specific(ownFresh)
    e = group[pick % #group + 1]
  else
    e = oldest(true)
    -- (where the race has its own, the shared fill every other gap)
    if not e and #fresh > 0 and (not own or pick % 2 == 0) then
      local group = specific(fresh)
      e = group[pick % #group + 1]
    end
    e = e or (not own and oldest(nil)) or nil
    if not e then return nil end
  end
  self.uses = self.uses + 1
  self.kindUses[pool] = (self.kindUses[pool] or 0) + 1
  self.used[e.id] = self.uses
  self.usedIn[e.id] = self.kindUses[pool]
  if ns.writerUsed then ns.writerUsed[e.reach] = true end
  self.remarkChapter[e.id] = self.chapterNo
  if ns.writerRemark then ns.writerRemark(e.id, self.chapterNo, self) end
  return (e.s[1]:gsub("{(%w+)}", values))
end

-- The place slots of a moment: {at} ("in Coldridge Valley", "there" if it was
-- just named, then nothing), {in} (always the name), and the place itself.
function Book:here(values, place)
  if not place then
    values.at = ""
  elseif place ~= self.last then
    values.at, values._named = "in " .. mid(place), true
  else
    values.at = self.there and "" or "there"
  end
  values["in"], values._place = place and "in " .. mid(place), place
  return values
end

local function town(node) return node and (node:match("^([^,]+)") or node) end

-- The chapter's kills, the most first (for the closing recap).
local function topKills(kills)
  local list = {}
  for name, n in pairs(kills or {}) do table.insert(list, { name = name, n = n }) end
  table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
  return list
end

-- A quest, told by what it asked: so many of a creature slain, so many of a
-- thing brought, a task, a message carried to another (a clause); else only
-- who asked; a quest with nothing but its title goes untold.
-- An objective that says what is done, not what to do ("Moonkin Stone found"):
-- it can't follow "I managed to".
local DONE = { found = true, slain = true, made = true, built = true, met = true, done = true, freed = true }
local function doneText(text)
  local last = text:gsub("[%.:].*$", ""):match("(%a+)%s*$")
  return last and (DONE[last:lower()] or last:find("[^e]ed$") or last:find("[^e]en$")) and true or false
end
local function lowerFirst(text) return (text:gsub("^%u", string.lower)) end
function Book:deed(m, key, tags)
  local o = m.objectives and m.objectives[1]
  local objective = o and o.text and lowerFirst(o.text)
  if objective and (objective:match("^tame ") or objective:lower():match(" tamed[%.:]?%s*$")) then return end
  local ender = m.ender ~= m.giver and m.ender or nil
  local values = { giver = m.giver, ender = ender }
  local done
  if o and o.type == "monster" and o.name then
    local count = o.n or 1
    -- one asked for is a named one, mostly ("Vagash"): no article
    values.n, values.foes = words(count), count > 1 and plural(o.name) or o.name
    tags.one = count == 1 or nil
    tags.teeth = ({ Wolf = true, Cat = true, Bear = true, Boar = true, Crocolisk = true, Raptor = true })[self.creatureKinds[o.name] or ""]
    done = self:say("c-deed-kill", key, values, tags, nil, true)
  elseif o and o.type == "item" and o.held and o.name and m.ender then
    -- a thing in hand when the quest was taken (a note, a letter found on a
    -- foe), carried to another: a delivery
    values.ender, values.thing = m.ender, itemName(o.name)
    done = self:say("c-deliver", key, values, tags, nil, true)
  elseif o and o.type == "item" and o.name then
    local count = o.n or 1
    values.n, values.thing = words(count), count > 1 and things(o.name) or itemName(o.name)
    tags.one = count == 1 or nil
    tags.trophy = TROPHY[o.name:match("^(%a+) of ") or ""] or nil
    tags.cloth = o.name:match("Cloth$") or o.name:match("Silk$") or o.name:match("Wool$") or nil
    tags.meat = o.name:match("Meat$") or nil -- uncounted: "it"
    done = self:say("c-deed-item", key, values, tags, tags.trophy and { trophy = true } or nil, true)
  elseif o and o.text and not doneText(o.text) then
    -- told after the fact: "escort the Defias Traitor to discover where
    -- VanCleef was hiding" (the log's "The Defias Traitor", "is hiding")
    values.task = lowerFirst((o.text:gsub("[%.:]%s*$", "")))
      :gsub(" The ", " the "):gsub(" is ", " was "):gsub(" are ", " were ")
    -- Taming objectives describe the same event as UNIT_PET. Leave that
    -- telling to the pet record, even before it arrives: no lookahead and
    -- no rewriting a finished quest sentence when the pet is later named.
    tags.explore, tags.escort = values.task:match("^explore "), values.task:match("^escort ")
    local site = values.task:match("^explore the (.+)$")
    if site and (self.placeNames[site] or (ns.data.scenery or {})[site]) then values.task = "explore " .. mid(site) end
    done = self:say("c-deed-task", key, values, tags, nil, true)
  elseif ender and m.giver then
    done = self:say("c-deed-word", key, values, tags, nil, true)
  end
  -- nothing to tell but who asked: that much; a title alone isn't told
  if not done and m.giver then
    done = self:say("c-quest", key, { giver = m.giver }, tags, nil, true)
  end
  return done
end

-- Linking words, by what happened since the moment before: night falling,
-- morning, hours gone by. A connector needs a recorded change in time.
local LINKS = {
  night = { "That night,", "By nightfall,", "When night came," },
  day = { "At first light,", "In the morning,", "With the dawn," },
  later = { "Later,", "Some hours later,", "Later that day," },
  aftermath = { "Afterwards,", "After that encounter," },
}
function Book:link(m, prev, key)
  if not (m and prev and m.at and prev.at) then return nil end
  local which
  if m.night and not prev.night then which = "night"
  elseif prev.night and not m.night then which = "day"
  elseif m.at - prev.at > 3600 then which = "later"
  elseif prev.k == "close" then which = "aftermath" end
  return which and self:linkWord(which, key)
end
function Book:linkWord(which, key)
  local list = (self.style and self.style.links[which]) or LINKS[which]
  local i = hash(self.seed .. "|word|" .. key) % #list + 1
  -- never the same word twice running
  if list[i] == self.lastLink then i = i % #list + 1 end
  self.lastLink = list[i]
  return list[i]
end
-- A sentence with its link before it ("That night, I..."), if it begins with
-- "I", "My" or an article.
local function linked(word, text)
  if not word then return text end
  local head, rest = text:match("^(%a+)( .*)$")
  if not head or not (head == "I" or head == "My" or head == "A" or head == "An" or head == "The") then return text end
  if head ~= "I" then head = head:lower() end
  return word .. " " .. head .. rest
end

-- The rank a profession's trainer gives: "an apprentice", "a journeyman".
local function rankName(rank) return rank and ((rank:match("^[aeiou]") and "an " or "a ") .. rank) end

-- A place described, the first time in the book the character comes to it
-- (writing/scenery/): as home, an ally's land, enemy ground or neutral, by
-- night or day. Nil if there is nothing written for it, or it was told.
function Book:sceneryOf(name, night)
  local p = name and ns.data.scenery and ns.data.scenery[name]
  if not p or self.sceneSeen[name] then return nil end
  self.sceneSeen[name] = true
  local view = (p.home and p.home[self.c.race or ""]) and "home"
    or (p.faction == "neutral" and "neutral")
    or ((self.faction and p.faction == self.faction) and "ally")
    or (self.faction and "foe")
    or "neutral"
  local ctx = setmetatable({ [view] = true, night = night or nil }, { __index = self.base })
  local fits = {}
  for i, s in ipairs(p) do
    if satisfied(s.tags, ctx) then table.insert(fits, i) end
  end
  if #fits == 0 then return nil end
  local i = fits[hash(self.seed .. "|scenery|" .. name) % #fits + 1]
  if ns.writerUsed then ns.writerUsed["scenery:" .. name .. "#" .. i] = true end
  return p[i][1]
end

-- A chapter, told in scenes: the moments in one place make one or two
-- sentences of clauses ("In Coldridge Valley I brought Sten his meat, killed
-- six troggs for Balir and carried Talin's word to Grelin."), a link and the
-- place at each new scene ("Later that day, I went on to Kharanos and...").
-- What matters more (a close call, a rare, a new zone, a night, a death, a new
-- power) has a sentence of its own; a new zone or a morning, a new paragraph.
-- The scene being played is the only one still growing: told in order, the
-- finished ones never change. Once closed, a recap (quests, the most fought),
-- the time and gold, and the last line (the rest that closed it, or the night
-- outdoors).
function Book:chapter(n, ch)
  local c = self.c
  local paragraphs, current = {}, {}
  self.last, self.there = nil, false
  self.chapterNo = self.chapterNo + 1
  self.inChapter, self.voiceUsed, self.quipped = true, 0, false
  self.voiceChapter = hash(self.seed .. "|voice|" .. n) % 3 == 0
  self.routineCount, self.nextRemark = 0, 2 + hash(self.seed .. "|remarks|" .. n) % 2
  self.pendingRemark, self.lastSentenceRemark = false, false
  local function append(text, routine, remarks)
    table.insert(current, text)
    self.lastSentenceRemark = (remarks or 0) > 0
    if ns.writerSentence then ns.writerSentence(text, routine or 0, remarks or 0, n) end
  end
  local function newParagraph()
    if #current > 0 then table.insert(paragraphs, current); current = {} end
    self.quipped = false
  end
  local start = ch.start or {}
  local lvl = start.level or 1
  local function tags(t, m)
    t = t or {}
    -- in the race's own lands (a place's scenery says whose home it is)
    local land = m and m.zone and ns.data.scenery and ns.data.scenery[m.zone]
    if t.home == nil then t.home = (land and land.home and land.home[c.race or ""]) or nil end
    local level = (m and m.level) or lvl
    if t.night == nil then t.night = (m and m.night) or nil end
    if t.high == nil then t.high = level >= 40 or nil end
    if t.low == nil then t.low = level <= 10 or nil end
    return t
  end

  -- The scene: its place (and zone), the places of the chapter so far, its
  -- clauses not yet in a sentence (with the link the sentence takes), the
  -- sentences it has, a plain kill told.
  local scene, sceneZone, seenHere, killed = nil, nil, {}, false
  local pending, lead, sentences, named = {}, nil, 0, false -- named: the sentence names its place
  local arrival, arrivalMode, sentenceLimit, pendingKinds = false, nil, nil, {}
  local pendingRoutine, pendingRemarks = 0, 0
  local prev -- the moment before the one being told
  local families = { quest = "work", kill = "work", boss = "work", loot = "work", gear = "work",
    learned = "practice", skill = "practice", prof = "practice" }

  -- The clauses so far, as one sentence: "I a.", "I a and b.", "I a, b and c."
  local function flush()
    if #pending == 0 then return end
    local text = pending[1]
    if #pending > 1 then
      local last = pending[#pending]
      if arrival and not lead and not pending[1]:find("[;%.!%?]") then
        -- Both are recorded, in this order. The journey is the setting for
        -- the deed; it does not invent a motive or a causal link between jobs.
        local actions = table.concat(pending, " and ", 2)
        -- An action may already coordinate its own verbs. Give that thought
        -- a setting rather than introducing yet another "and" before it.
        if arrivalMode == 0 or (arrivalMode == 2 and actions:find(" and ")) then text = "When I " .. pending[1] .. ", I " .. actions
        elseif arrivalMode == 1 then
          if pendingKinds[2] == "inn" then actions = actions:gsub(" there", "", 1) end
          text = "I " .. pending[1] .. ", where I " .. actions
        else text = "I " .. pending[1] .. " and " .. actions end
      else
        local join = " and "
        -- A fight followed by a completed errand is an observed sequence,
        -- not an inferred cause. Other unrelated acts need no forced link.
        if pending[1]:find("[,;:]") or pending[1]:find(" and ") or last:find("[,;:]") or last:find(" and ") then join = "; I "
        elseif #pending == 2 and pendingKinds[1] == "kill" and pendingKinds[2] == "quest" then join = " before I " end
        local before = {}
        for j = 1, #pending - 1 do before[j] = pending[j] end
        text = "I " .. (join == "; I " and listing(before) or table.concat(before, ", ")) .. join .. last
      end
    else
      text = "I " .. text
    end
    append(linked(lead, capitalise(text .. ".")), pendingRoutine, pendingRemarks)
    self.lastSentenceRemark, self.pendingRemark = pendingRemarks > 0, false
    pendingRoutine, pendingRemarks = 0, 0
    -- "there" only right after the place is named
    if not named then self.there = true end
    pending, lead, named, arrival, arrivalMode, sentenceLimit, pendingKinds = {}, nil, false, false, nil, nil, {}
    sentences = sentences + 1
  end
  self.prepareRemark = function()
    if self.pendingRemark or (self.lastSentenceRemark and #pending > 0) then flush() end
  end
  -- A clause for a moment: a new sentence takes a link (the time gone by, or
  -- the next thing in the scene); a sentence holds as many clauses as the
  -- race's style allows (STYLE), varying the length between two and three.
  -- A comma within a clause is not a reason to cut the thought short.
  local function clause(text, m, key, isArrival)
    if not text then return end
    local complex = text:find("[,;:%.!%?]") or text:find(" and ")
    -- Keep related work together. Learning two trades is one thought; a
    -- trade followed by a fight is a new one. An arrival may frame either.
    local kind = m and m.k or ""
    if #pending > 0 and not arrival and
      (not families[kind] or families[kind] ~= families[pendingKinds[1]]) then flush() end
    if #pending == 0 then
      lead = self:link(m, prev, key)
      sentenceLimit = isArrival and 2 or math.min(self.style.clauses, 2 + hash(self.seed .. "|length|" .. key) % 2)
      arrival = isArrival
      arrivalMode = hash(self.seed .. "|arrival|" .. key) % 3
      if arrivalMode == self.lastArrivalMode then arrivalMode = (arrivalMode + 1) % 3 end
      if isArrival then self.lastArrivalMode = arrivalMode end
    end
    table.insert(pending, text)
    table.insert(pendingKinds, kind)
    if self.selectedRoutine then pendingRoutine = pendingRoutine + 1 end
    if self.selectedRemark then pendingRemarks, self.pendingRemark = pendingRemarks + 1, true end
    if #pending >= sentenceLimit or text:find("[;%.!%?]")
      or (isArrival and self.selectedRemark) or (self.pendingRemark and #pending >= 2)
      or (#pending >= 2 and (complex or pending[1]:find("[,;:]") or pending[1]:find(" and "))) then flush() end
  end
  -- A new scene at a place: told as the journey there (a place just named
  -- needs none).
  local function arrive(place, zone, m, key, opener)
    flush()
    if #current >= 3 then newParagraph() end
    local back = seenHere[place]
    scene, sceneZone, killed, sentences = place, zone, false, 0
    seenHere[place] = true
    if opener then
      named = true
      clause(self:say(opener, key, { place = mid(place), _place = place }, tags(nil, m), nil, true), m, key, true)
    elseif place ~= self.last then
      named = true
      clause(self:say(back and "c-return" or "c-travel", key .. "|go", { place = mid(place), _place = place }, tags(nil, m), nil, true), m, key, true)
    end
  end
  -- Where a moment is: its subzone, or the scene's place if it is somewhere
  -- unnamed in the same zone.
  local function placeOf(m)
    if m.sub then return m.sub end
    if scene and sceneZone == m.zone then return scene end
    return m.zone
  end
  -- A moment of its own: a sentence, after the clauses before it.
  local function alone(kind, key, values, t, m)
    flush()
    local s = self:say(kind, key, values, t)
    if s then
      append((#current > 0 and m) and linked(self:link(m, prev, key), s) or s)
      sentences = 1 -- what follows in the scene may be "then"
      self.lastSentenceRemark = false
    end
    return s
  end

  -- Where the chapter began.
  local where = start.sub or start.zone
  if start.sub then self.placeNames[start.sub] = true end
  if start.zone then self.placeNames[start.zone] = true end
  local first = n == 1 and (c.began and c.began.level or 1) == 1 and lvl == 1
  if where then
    local s = self:say(first and "beginning" or "opening", n .. "|open", self:here({ where = mid(where) }, where), tags({ night = start.night or nil }))
    if s then append(s) end
    -- a life's first page: the land it begins in
    local land = first and self:sceneryOf(start.zone, start.night)
    if land then append(land) end
    scene, sceneZone = where, start.zone
    seenHere[where] = true
  end

  local mates, dungeon = {}, nil -- who joined me so far in the chapter; the dungeon I'm in
  local merged, found = {}, nil -- group moments told with the one before; the find just told
  for i, m in ipairs(ch.log or {}) do
    if m.sub then self.placeNames[m.sub] = true end
    if m.zone then self.placeNames[m.zone] = true end
    local key = n .. "|" .. i
    local place = placeOf(m)
    -- a clause in the scene where it happened
    local function prepare()
      if place and place ~= scene then arrive(place, m.zone, m, key) end
      if #pending > 0 and not arrival and
        (not families[m.k] or families[m.k] ~= families[pendingKinds[1]]) then flush() end
    end
    local function inScene(text) clause(text, m, key) end
    local function c_(kind, values, t)
      prepare()
      if kind == "c-inn" then
        values._place = m.place
        values.inn = m.place == self.last and "there" or "at " .. mid(m.place)
      end
      return self:say(kind, key, values, tags(t, m), nil, true)
    end
    if m.k == "level" then
      lvl = m.level or lvl -- a level reached: recorded, not told
    elseif m.k == "place" then
      if m.new == "zone" then
        flush()
        newParagraph()
        self.last = nil
        -- a land seen for the first time: described, else the plain line
        local land = self:sceneryOf(m.zone, m.night)
        if land then append(land) else alone("zone", key, { zone = mid(m.zone) }, tags(nil, m)) end
        self.last = nil
        scene, sceneZone = nil, nil
        local town = m.sub and self:sceneryOf(m.sub, m.night)
        if town then
          append(town)
          scene, sceneZone, sentences = m.sub, m.zone, 1
          seenHere[m.sub] = true
          self.last, self.there = m.sub, false
        elseif m.sub then
          arrive(m.sub, m.zone, m, key, seenHere[m.sub] and "c-return" or "c-place")
        end
      elseif m.sub or m.zone then
        local here = m.sub or m.zone
        local town = self:sceneryOf(here, m.night)
        if town then
          -- a town seen for the first time: described, in its own sentences
          flush()
          if #current >= 3 then newParagraph() end
          append(#current > 0 and linked(self:link(m, prev, key), town) or town)
          scene, sceneZone, killed, sentences = here, m.zone, false, 1
          seenHere[here] = true
          self.last, self.there = here, false
        else
          arrive(here, m.zone, m, key, seenHere[here] and "c-return" or "c-place")
        end
      end
    elseif m.k == "inn" then
      inScene(c_("c-inn", { inn = mid(m.place) }))
    elseif m.k == "flight" then
      alone("flight", key, { from = mid(town(m.from)), to = mid(town(m.to)) }, tags({ first = not self.flown or nil }, m), m)
      self.flown = true
      if place then
        scene, sceneZone = place, m.zone
        seenHere[place] = true
        self.last, self.there = place, false
      end
    elseif m.k == "quest" then
      local t = tags(nil, m)
      prepare()
      clause(self:deed(m, key, t), m, key)
    elseif m.k == "kill" then
      self.creatureKinds[m.name] = m.kind
      local t = { one = true, teeth = ({ Wolf = true, Cat = true, Bear = true, Boar = true, Crocolisk = true, Raptor = true })[m.kind or ""],
        mechanical = m.kind == "Mechanical" or nil }
      if m.quarry or SKIP[m.kind or ""] then -- told by its quest, or not a fight
      elseif m.first and KINDS[m.kind] then
        inScene(c_("c-first", { kind = KINDS[m.kind] }, t))
      elseif m.elite then
        inScene(c_("c-elite", { foe = namedElite(m.name) and m.name or article(m.name) }))
      elseif not (killed and place == scene) then
        inScene(c_("c-kill", { foe = article(m.name) }, t))
        killed = true
      end
    elseif m.k == "group" then
      -- a group formed: those who joined together, in one clause
      if not merged[i] then
        local names, j = { m.name }, i + 1
        while ch.log[j] and ch.log[j].k == "group" and (ch.log[j].at or 0) - (m.at or 0) <= 120 do
          table.insert(names, ch.log[j].name)
          merged[j] = true
          j = j + 1
        end
        for _, name in ipairs(names) do if #mates < 4 then table.insert(mates, name) end end
        inScene(c_("c-group", { mates = listing(names) }, { one = #names == 1 or nil }))
      end
    elseif m.k == "boss" and FINAL[m.name] then
      -- a dungeon's last master: a sentence of its own
      alone("boss-final", key, { boss = m.name, dungeon = mid(dungeon) }, tags(nil, m), m)
    elseif m.k == "boss" then
      inScene(c_("c-boss", { boss = m.name, dungeon = mid(dungeon) }))
    elseif m.k == "learned" then
      -- a trade's own spell (learned before the game listed the trade) is told by the trade
      local spells = {}
      for _, sp in ipairs(m.spells) do
        if not ((c.profs or {})[sp] or sp:find("^Apprentice ") or sp:find("^Journeyman ") or sp:find("^Expert ")
          or sp:find("^Artisan ") or sp:find("^Master ")) then table.insert(spells, sp) end
      end
      if #spells > 0 then
        local named = {}
        for j = 1, math.min(#spells, 3) do named[j] = spells[j] end
        inScene(c_("c-trainer", { spells = listing(named) }, { many = #spells > 3 or nil, one = #spells == 1 or nil }))
      end
    elseif m.k == "skill" then
      inScene(c_("c-skill", { skill = m.name:lower(), rank = words(m.rank) }))
    elseif m.k == "prof" then
      inScene(c_("c-prof", { prof = m.name:lower(), rank = rankName(m.rank) }, { new = m.learned or nil }))
    elseif m.k == "gear" and found == (m.link and m.link:match("%[(.-)%]")) then
      inScene(c_("c-wear-found", {})) -- the find just told, put to use
      found = nil
    elseif m.k == "gear" or m.k == "loot" then
      local item = m.link and m.link:match("%[(.-)%]")
      if item then inScene(c_("c-" .. m.k, { item = itemName(item) }, { made = m.made or nil })) end
      found = m.k == "loot" and item or nil
    elseif m.k == "tame" then
      inScene(c_("c-tame", { pet = m.name, family = m.family and article(m.family:lower()) }))
    else
      -- the moments of their own, where they happened
      flush() -- before its place is worked out: "there" depends on the sentence before
      if place and place ~= scene then
        scene, sceneZone, killed, sentences = place, m.zone, false, 0
        seenHere[place] = true
      end
      if m.k == "rare" then
        alone("rare", key, self:here({ foe = m.name }, place), tags({ elite = m.elite or nil }, m), m)
      elseif m.k == "close" then
        if #current >= 3 then newParagraph() end
        alone(m.hp <= 5 and "close-deep" or "close-light", key,
          self:here({ foe = article(m.foe) }, place), tags({ night = m.night or false, foe = m.foe ~= nil }, m), m)
      elseif m.k == "died" and m.death then
        alone("died", key, self:here({ foe = deathFoe(m.death, article) }, place), deathTags(m.death), m)
      elseif m.k == "dungeon" then
        dungeon = m.name
        -- a dungeon's first time: described, else the plain line
        local depths = self:sceneryOf(m.name, m.night)
        if depths then
          append(#current > 0 and linked(self:link(m, prev, key), depths) or depths)
          sentences = 1
        else
          alone("dungeon", key, { dungeon = mid(m.name), mates = listing(mates) }, tags(nil, m), m)
        end
        self.last, self.there = place, false
      elseif m.k == "power" then
        alone("power", key, { spell = m.spell }, tags({ [m.kind or "form"] = true }, m), m)
      elseif m.k == "mount" or m.k == "riding" then
        alone(m.k, key, {}, tags(nil, m), m)
      elseif m.k == "petdied" then
        alone("petdied", key, self:here({ pet = m.name }, place), tags(nil, m), m)
      elseif m.k == "campfire" then
        alone("campfire", key, self:here({}, place), tags(nil, m), m)
      elseif m.k == "rested" then
        alone("rest", key, self:here({ place = mid(m.place) }, m.place), tags({ fire = m.fire or nil, last = false }, m), m)
      elseif m.k == "night" and not m.last then
        alone("night", key, self:here({}, place), tags({ last = false }, m), m)
      elseif m.k == "wake" then
        flush()
        newParagraph()
        self.last = nil
        alone("wake", key, self:here({}, place), tags({ rest = m.after == "rest" or nil }, m))
      end
    end
    if m.k ~= "level" then prev = m end
  end
  flush()

  -- The end of the chapter (not while it is still being written; a death on
  -- Hardcore ends it with the epitaph instead).
  local e = ch.ended
  if e and e.how ~= "death" then
    newParagraph()
    self.last = nil
    local function say(kind, key, values, t)
      local s = self:say(kind, n .. "|" .. key, values, t)
      if s then append(s) end
    end
    -- The recap (tasks, fighting, time) holds one thought, the rest told
    -- plainly: the chapter's last sentence (the rest) has its own.
    local recap = {}
    local top = (function()
      local covered, remaining = {}, {}
      for _, m in ipairs(ch.log or {}) do
        local o = m.k == "quest" and m.objectives and m.objectives[1]
        if o and o.type == "monster" and o.name then covered[o.name] = true end
      end
      for name, count in pairs(ch.kills or {}) do
        if not covered[name] then remaining[name] = count end
      end
      return topKills(remaining)
    end)()
    if (ch.quests or 0) >= 2 then table.insert(recap, "quests") end
    if top[1] and top[1].n >= 3 then table.insert(recap, "kills") end
    table.insert(recap, "closing")
    local thought = recap[hash(self.seed .. "|thought|" .. n) % #recap + 1]
    local function plainUnless(which) self.onlyPlain = thought ~= which end
    if (ch.quests or 0) >= 2 then
      plainUnless("quests")
      local giver
      for i = #ch.log, 1, -1 do
        if ch.log[i].k == "quest" and ch.log[i].giver then giver = ch.log[i].giver break end
      end
      say("quests-many", "recap-q", { n = words(ch.quests), giver = giver }, tags())
    end
    -- (Quest objectives already told the significant fighting: the tally
    -- leaves their foes out.)
    local a, b = top[1], top[2]
    plainUnless("kills")
    if a and a.n >= 3 then
      if b and b.n >= 3 then
        say("kills-two", "recap-k", self:here({ n1 = words(a.n), foes1 = plural(a.name), n2 = words(b.n), foes2 = plural(b.name) }, nil),
          tags({ lots = a.n >= 15 or nil }))
      else
        say("kills", "recap-k", self:here({ n = words(a.n), foes = plural(a.name) }, nil), tags({ lots = a.n >= 15 or nil }))
      end
    end
    local played = ch.played or 0
    plainUnless("closing")
    say("closing", "end", { time = playedWords(played), gold = goldWords(ch.gold) },
      tags({ slow = played > 7200 or nil, quick = (played > 0 and played < 1800) or nil }))
    self.onlyPlain = nil
    if e.how == "long" then
      say("night", "last", self:here({}, e.place), tags({ last = true, night = true }))
    else
      say("rest", "last", self:here({ place = mid(e.place) }, e.place), tags({ fire = e.how == "campfire" or nil, last = true }))
    end
  end
  newParagraph()
  self.inChapter = false
  if #paragraphs == 0 then return nil end
  -- A paragraph of one sentence joins the one before it (the first, the one after).
  local merged = {}
  for _, p in ipairs(paragraphs) do
    if #p == 1 and #merged > 0 then table.insert(merged[#merged], p[1]) else table.insert(merged, p) end
  end
  if #merged > 1 and #merged[1] == 1 then
    table.insert(merged[2], 1, merged[1][1])
    table.remove(merged, 1)
  end
  local out = {}
  for _, p in ipairs(merged) do table.insert(out, table.concat(p, " ")) end
  return table.concat(out, "\n\n")
end

function Book:prologue(p)
  local zone = p.zone
  return self:say("prologue", "prologue", self:here({
    zone = mid(zone), quests = (p.quests or 0) > 1 and words(p.quests) or nil,
    inn = mid(p.inn), played = playedWords(p.played),
  }, zone), {})
end

-- The epitaph of a Hardcore life, in the third person: how it ended (a line
-- telling the cause wins), what it was (its totals, a rare, a dungeon), and a
-- farewell (often in the voice of its race or class).
local RACE = { Human = "human", Dwarf = "dwarf", NightElf = "night elf", Gnome = "gnome", Draenei = "draenei",
  Orc = "orc", Troll = "troll", Tauren = "tauren", Scourge = "Forsaken", BloodElf = "blood elf" }
function Book:epitaph(c)
  local d = c.death or {}
  local race, class = RACE[c.race] or "", (c.class or ""):lower()
  local who = (race .. " " .. class):gsub("^ +", ""):gsub(" +$", "")
  who = who ~= "" and ((who:match("^[aeiou]") and "an " or "a ") .. who) or nil
  self.last = nil
  local tags = deathTags(d)
  tags.low = (d.level or 0) <= 10 or nil
  tags.high = (d.level or 0) >= 40 or nil
  local place = d.sub or d.zone
  -- the line that tells how it ended wins (a copy: say() gives its tags the
  -- character's, race and class, which are not a cause)
  local cause = deathTags(d)
  cause.low, cause.high = tags.low, tags.high -- a short life or a long one says how it ended too
  local first = self:say("epitaph", "epitaph", self:here({ name = c.name, who = who, level = words(d.level or 0),
    zone = mid(d.zone), foe = deathFoe(d, article) }, place), tags, cause)

  local quests, kills, played, rare, dungeon, zones = 0, 0, 0, nil, nil, 0
  for _, ch in ipairs(c.chapters or {}) do
    quests = quests + (ch.quests or 0)
    played = played + (ch.played or 0)
    for _, n in pairs(ch.kills or {}) do kills = kills + n end
    for _, m in ipairs(ch.log or {}) do
      if m.k == "rare" then rare = rare or m.name end
      if m.k == "dungeon" then dungeon = dungeon or m.name end
    end
  end
  for key in pairs(c.visited or {}) do if key:sub(-1) == "|" then zones = zones + 1 end end
  local second = self:say("remembrance", "remembrance", {
    name = c.name, played = playedWords(played), quests = quests > 1 and words(quests) or nil, -- "one tasks": no
    kills = kills > 1 and words(kills) or nil, rare = rare, dungeon = mid(dungeon), zones = zones > 1 and words(zones) or nil,
  }, { low = tags.low, high = tags.high, inside = tags.inside })
  local third = self:say("farewell", "farewell", { name = c.name }, { low = tags.low })
  if not first then return nil end
  local parts = { first }
  if second then table.insert(parts, second) end
  if third then table.insert(parts, third) end
  return table.concat(parts, " ")
end

-- The whole book: { prologue = text, chapters = { { number, text, place, from,
-- to (levels), rare, close, open, chapter } }, epitaph, repeats, minGap }
-- (minGap: the fewest uses of a kind between two uses of one of its sentences)
function ns.writeBook(c)
  local b = newBook(c)
  local book = { chapters = {} }
  if c.prologue then
    book.prologue = b:prologue(c.prologue)
  end
  for i, ch in ipairs(c.chapters or {}) do
    local rare, close, to = nil, nil, (ch.start and ch.start.level) or 1
    for _, m in ipairs(ch.log or {}) do
      if m.k == "rare" then rare = true end
      if m.k == "close" then close = true end
      if m.k == "level" then to = m.level end
    end
    if ch.ended and ch.ended.level then to = math.max(to, ch.ended.level) end
    local e = ch.ended
    table.insert(book.chapters, {
      number = i, text = b:chapter(i, ch), chapter = ch, open = not e or nil,
      place = e and e.place or (ch.start and (ch.start.sub or ch.start.zone)),
      from = ch.start and ch.start.level or 1, to = to, rare = rare, close = close,
    })
  end
  if c.hardcore and c.death then book.epitaph = b:epitaph(c) end
  book.repeats, book.minGap, book.minGapKind = b.repeats, b.minGap, b.minGapKind
  return book
end
