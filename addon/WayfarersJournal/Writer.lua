-- The writer: turns the records into the journal's prose, when it is read
-- (never stored). Each moment of a level picks one sentence of its kind
-- (writing/<kind>.md):
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

-- A name inside a sentence: "The Barrens" reads "the Barrens".
local function mid(name) return name and (name:gsub("^The ", "the ")) end

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
  if last:match("[sxz]$") or last:match("[cs]h$") then return name .. "es" end
  if last:match("[a-z]man$") then return before .. last:sub(1, -4) .. "men" end
  return name .. "s"
end
ns.plural = plural

-- An item: "a Wolf Fang Necklace", but "Cuirboulle Gloves", "Blackened Defias
-- Armor", "Smite's Mighty Hammer".
local MASS = { Armor = true, Mail = true, Garb = true, Attire = true, Regalia = true, Raiment = true, Plate = true, Leather = true }
local function itemName(name)
  local last = name:match("(%S+)$")
  if name:find("'s ") or last:match("s$") or MASS[last] then return name end
  return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end
ns.itemName = itemName

-- A creature named in passing: "a Frostmane Novice". The game can't tell a
-- named creature from a common one, so only rares go without (by their name).
local function article(name)
  if not name then return nil end
  return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end

-- Kinds worth a "first of its kind" (the game's English names; people are
-- not a kind, and critters are not a fight).
local KINDS = {
  Wolf = "wolves", Cat = "great cats", Spider = "spiders", Bear = "bears", Boar = "boars", Crocolisk = "crocolisks",
  ["Carrion Bird"] = "carrion birds", Crab = "crabs", Gorilla = "gorillas", Raptor = "raptors",
  Tallstrider = "tallstriders", Scorpid = "scorpids", Turtle = "turtles", Bat = "bats", Hyena = "hyenas",
  Owl = "owls", ["Wind Serpent"] = "wind serpents", Serpent = "serpents", Dragonhawk = "dragonhawks",
  Ravager = "ravagers", ["Warp Stalker"] = "warp stalkers", Sporebat = "sporebats", ["Nether Ray"] = "nether rays",
  Beast = "beasts", Undead = "undead", Elemental = "elementals", Demon = "demons", Dragonkin = "dragonkin",
  Giant = "giants", Mechanical = "constructs",
}
local SKIP = { Critter = true, ["Non-combat Pet"] = true, Totem = true, ["Not specified"] = true, ["Gas Cloud"] = true }

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
  Orc = "my clan", Troll = "the Darkspear", Tauren = "my tribe", Scourge = "the Forsaken", BloodElf = "my people" }
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
    if t:sub(1, 1) == "!" then
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

local Book = {}
Book.__index = Book

local function newBook(c)
  local race, class = c.race or "Human", c.class or "WARRIOR"
  local b = setmetatable({ c = c, used = {}, usedIn = {}, uses = 0, seed = c.guid or "", zones = {}, flown = false,
    repeats = 0, chapterNo = 0 }, Book)
  b.voice = { home = HOME[race], kin = KIN[race], faith = faith(race, class), weapon = weapon(race, class) }
  b.base = { hc = c.hardcore or nil, ["race:" .. race] = true, ["class:" .. class] = true }
  if FACTION[race] then b.base["faction:" .. FACTION[race]] = true end
  return b
end

-- One sentence of a kind for a moment: key makes the choice stable, values
-- fill the slots (_place: the place {at}, {in} or {where} names), tags add to
-- the character's.
function Book:say(kind, key, values, tags)
  local list = ns.data.writing[kind]
  if not list then return end
  local ctx = setmetatable(tags or {}, { __index = self.base })
  for k, v in pairs(self.voice) do if values[k] == nil then values[k] = v end end
  -- A place already named is not named again by a sentence without a verb,
  -- unless no other sentence fits.
  local named = values["in"]
  if named and values._place == self.last then values["in"] = nil end
  local fresh, voiced, all
  for _ = 1, 2 do
    fresh, voiced, all = {}, {}, {}
    for i, s in ipairs(list) do
      if satisfied(s.tags, ctx) and fillable(s[1], values) then
        table.insert(all, i)
        if not self.used[kind .. i] then
          table.insert(fresh, i)
          if s.tags then table.insert(voiced, i) end
        end
      end
    end
    if #all > 0 or values["in"] == named then break end
    values["in"] = named
  end
  if #all == 0 then return end
  -- the lowest bit chooses between the voiced and the rest, the others which
  local h = hash(self.seed .. "|" .. kind .. "|" .. key)
  local pick = floor(h / 2)
  local i
  if #voiced > 0 and h % 2 == 0 then
    i = voiced[pick % #voiced + 1]
  elseif #fresh > 0 then
    i = fresh[pick % #fresh + 1]
  else
    -- all used: the one used longest ago
    i = all[1]
    for _, j in ipairs(all) do if self.used[kind .. j] < self.used[kind .. i] then i = j end end
    self.repeats = self.repeats + 1
    local gap = self.chapterNo - self.usedIn[kind .. i]
    if not self.minGap or gap < self.minGap then self.minGap, self.minGapKind = gap, kind end
  end
  self.uses = self.uses + 1
  self.used[kind .. i] = self.uses
  self.usedIn[kind .. i] = self.chapterNo
  if ns.writerUsed then ns.writerUsed[kind .. "#" .. i] = true end
  local text = list[i][1]
  if text:find("{in}") or text:find("{where}") or text:find("{place}") or (text:find("{at}") and values._named) then
    self.last, self.there = values._place, false
  elseif text:find("{at}") and values.at == "there" then
    self.there = true
  elseif text:find("{places}") or text:find("{zone}") then
    self.last = nil
  end
  text = text:gsub("{(%w+)}", values)
  -- a place left out: no space before the punctuation, none doubled
  return (text:gsub(" +([%.,;:!%?])", "%1"):gsub("  +", " "):gsub("^ +", ""))
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

local function sortedKills(l)
  local list = {}
  for name, k in pairs(l.kills or {}) do
    if not SKIP[k.kind or ""] then table.insert(list, { name = name, k = k }) end
  end
  table.sort(list, function(a, b) if a.k.n ~= b.k.n then return a.k.n > b.k.n end return a.name < b.name end)
  return list
end

local function town(node) return node and (node:match("^([^,]+)") or node) end

function Book:chapter(n, l)
  local c, out = self.c, {}
  self.last = nil
  self.chapterNo = self.chapterNo + 1
  local function say(kind, key, values, tags)
    local s = self:say(kind, n .. "|" .. key, values, tags)
    if s then table.insert(out, s) end
    return s
  end
  local start = l.start or {}
  local level = { night = start.night or nil, high = n >= 40 or nil }
  local function tags(t)
    t = t or {}
    for k, v in pairs(level) do if t[k] == nil then t[k] = v end end
    return t
  end

  -- Where the level began.
  local where = start.sub or start.zone
  local first = n == 1 and (c.began and c.began.level or 1) == 1
  if where then
    say(first and "beginning" or "opening", "open", self:here({ where = mid(where) }, where), tags())
  end
  if start.zone then self.zones[start.zone] = true end

  -- New ground: a new zone, then its new places.
  local groups, order = {}, {}
  for _, p in ipairs(l.places or {}) do
    if p.zone and p.sub ~= where and not (p.sub == nil and p.zone == where) then
      if not groups[p.zone] then groups[p.zone] = {}; table.insert(order, p.zone) end
      if p.sub then table.insert(groups[p.zone], p.sub) end
    end
  end
  for _, zone in ipairs(order) do
    if not self.zones[zone] then
      self.zones[zone] = true
      say("zone", zone, { zone = mid(zone) }, tags())
    end
    local subs = groups[zone]
    if #subs == 1 then
      say("place", subs[1], { place = mid(subs[1]), zone = mid(zone), _place = subs[1] }, tags())
    elseif #subs > 1 then
      local named = {}
      for i = 1, math.min(#subs, 3) do named[i] = mid(subs[i]) end
      say("places", zone, { places = listing(named), zone = mid(zone) }, tags())
    end
  end
  if l.inn and l.inn.place then
    say("inn", "inn", { inn = mid(l.inn.place), _place = l.inn.place }, tags())
  end
  for i, f in ipairs(l.flights or {}) do
    if i > 1 then break end
    say("flight", "flight", { from = mid(town(f.from)), to = mid(town(f.to)) }, tags({ first = not self.flown or nil }))
    self.flown = true
  end

  -- Work.
  local quests = {}
  for _, q in ipairs(l.quests or {}) do if q.title then table.insert(quests, q) end end
  local function quoted(q) return '"' .. q.title .. '"' end
  if #quests == 1 then
    say("quest", "q", { quest = quoted(quests[1]), giver = quests[1].giver }, tags())
  elseif #quests <= 3 and #quests > 1 then
    local titles, giver = {}, nil
    for _, q in ipairs(quests) do table.insert(titles, quoted(q)); giver = giver or q.giver end
    say("quests", "q", { quests = listing(titles), giver = giver }, tags())
  elseif #quests > 3 then
    local q = quests[#quests]
    say("quests-many", "q", { n = words(#l.quests), quest = quoted(q), giver = q.giver }, tags())
  end

  -- Fights: the first of a kind, the most fought, elites, rares.
  local kills = sortedKills(l)
  for _, e in ipairs(kills) do
    if e.k.first and KINDS[e.k.kind] then
      say("first-kind", "first", self:here({ kind = KINDS[e.k.kind] }, e.k.where), tags())
      break
    end
  end
  local a, b = kills[1], kills[2]
  if a and a.k.n >= 3 then
    local place = a.k.where
    local lots = a.k.n >= 15 or nil
    if b and b.k.n >= 3 then
      say("kills-two", "kills", self:here({ n1 = words(a.k.n), foes1 = plural(a.name), n2 = words(b.k.n), foes2 = plural(b.name) },
        place), tags({ lots = lots }))
    else
      say("kills", "kills", self:here({ n = words(a.k.n), foes = plural(a.name) }, place), tags({ lots = lots }))
    end
  end
  for _, e in ipairs(kills) do
    if e.k.elite then
      say("elite", e.name, self:here({ foe = article(e.name) }, e.k.where), tags())
      break
    end
  end
  for i, r in ipairs(l.rares or {}) do
    if i > 2 then break end
    local place = r.sub or r.zone
    say("rare", r.name, self:here({ foe = r.name }, place), tags({ elite = r.elite or nil }))
  end
  for i, cc in ipairs(l.closeCalls or {}) do
    if i > 2 then break end
    local place = cc.sub or cc.zone
    say(cc.hp <= 5 and "close-deep" or "close-light", "close" .. i,
      self:here({ foe = article(cc.foe), hp = tostring(cc.hp) }, place), tags({ night = cc.night or false }))
  end

  -- Company.
  local mates = {}
  for name in pairs(l.company or {}) do table.insert(mates, name) end
  table.sort(mates)
  while #mates > 4 do table.remove(mates) end
  local dungeons = l.dungeons or {}
  for i, d in ipairs(dungeons) do
    if i > 2 then break end
    say("dungeon", d.name, { dungeon = mid(d.name), boss = d.bosses and d.bosses[#d.bosses], mates = listing(mates) }, tags())
  end
  if #dungeons == 0 and #mates > 0 then say("group", "group", { mates = listing(mates) }, tags()) end

  -- Learning and spoils.
  local learned = l.learned or {}
  if #learned > 0 then
    local named = {}
    for i = 1, math.min(#learned, 3) do named[i] = learned[i] end
    say("trainer", "trainer", { spells = listing(named) }, tags({ many = #learned > 3 or nil }))
  end
  local skills = l.skills or {}
  for i = #skills, math.max(1, #skills - 1), -1 do
    local s = skills[i]
    say("skill", s.name .. s.rank, { skill = s.name:lower(), rank = words(s.rank) }, tags())
  end
  local item = l.loot and l.loot.link and l.loot.link:match("%[(.-)%]")
  if item then say("loot", "loot", { item = itemName(item) }, tags()) end

  -- The end of the level (not while it is still being lived).
  if l.ended then
    local played = l.played or 0
    say("closing", "end", { time = playedWords(played), gold = goldWords(l.gold) },
      tags({ slow = played > 7200 or nil, quick = (played > 0 and played < 1800) or nil }))
  end
  if #out == 0 then return nil end
  return capitalise(table.concat(out, " "))
end

function Book:prologue(p)
  local zone = p.zone
  return self:say("prologue", "prologue", self:here({
    zone = mid(zone), quests = (p.quests or 0) > 0 and words(p.quests) or nil,
    inn = mid(p.inn), played = playedWords(p.played),
  }, zone), {})
end

-- The whole book: { prologue = text, chapters = { { level, text, place, rare, close } },
-- repeats, minGap } (minGap: the fewest chapters between two uses of a sentence)
function ns.writeBook(c)
  local b = newBook(c)
  local book = { chapters = {} }
  if c.prologue then
    local text = b:prologue(c.prologue)
    book.prologue = text and capitalise(text)
  end
  local levels = {}
  for n in pairs(c.levels or {}) do table.insert(levels, n) end
  table.sort(levels)
  for _, n in ipairs(levels) do
    local l = c.levels[n]
    table.insert(book.chapters, {
      level = n, text = b:chapter(n, l), place = l.start and l.start.zone,
      rare = (l.rares and #l.rares > 0) or nil, close = (l.closeCalls and #l.closeCalls > 0) or nil,
    })
  end
  book.repeats, book.minGap, book.minGapKind = b.repeats, b.minGap, b.minGapKind
  return book
end
