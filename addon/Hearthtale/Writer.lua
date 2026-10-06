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
local function article(name)
  if not name then return nil end
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
    if t == "aside" then -- a mark, not a condition
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

local Book = {}
Book.__index = Book

local function newBook(c)
  local race, class = c.race or "Human", c.class or "WARRIOR"
  local b = setmetatable({ c = c, used = {}, usedIn = {}, uses = 0, seed = c.guid or "", zones = {}, flown = false,
    repeats = 0, chapterNo = 0, kindUses = {}, voiceUsed = 0 }, Book)
  b.voice = { home = HOME[race], kin = KIN[race], faith = faith(race, class), weapon = weapon(race, class) }
  b.base = { hc = c.hardcore or nil, ["race:" .. race] = true, ["class:" .. class] = true }
  if FACTION[race] then b.base["faction:" .. FACTION[race]] = true end
  return b
end

-- One sentence of a kind for a moment: key makes the choice stable, values
-- fill the slots (_place: the place {at}, {in} or {where} names), tags add to
-- the character's. prefer: tags to favour (a fresh sentence with one of them
-- wins over the rest). raw: a clause, left as it is (no capital).
function Book:say(kind, key, values, tags, prefer, raw)
  local list = ns.data.writing[kind]
  if not list then return end
  local ctx = setmetatable(tags or {}, { __index = self.base })
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
  local fresh, voiced, all
  for pass = 1, 3 do
    fresh, voiced, all = {}, {}, {}
    for i, s in ipairs(list) do
      if satisfied(s.tags, ctx) and fillable(s[1], values) and (pass == 3 or allowed(s)) then
        table.insert(all, i)
        if not self.used[kind .. i] then
          table.insert(fresh, i)
          if s.tags then table.insert(voiced, i) end
        end
      end
    end
    if #all > 0 then break end
    -- nothing allowed: first the place may be named again, then the limits go
    if pass == 1 and values["in"] ~= named then values["in"] = named end
  end
  if #all == 0 then return end
  if prefer then
    local favoured = {}
    for _, i in ipairs(fresh) do
      for _, t in ipairs(list[i].tags or {}) do
        if prefer[t] then table.insert(favoured, i) break end
      end
    end
    if #favoured > 0 then fresh, voiced = favoured, {} end
  end
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
    local gap = (self.kindUses[kind] or 0) - self.usedIn[kind .. i]
    if not self.minGap or gap < self.minGap then self.minGap, self.minGapKind = gap, kind end
  end
  self.uses = self.uses + 1
  self.kindUses[kind] = (self.kindUses[kind] or 0) + 1
  self.used[kind .. i] = self.uses
  self.usedIn[kind .. i] = self.kindUses[kind]
  if ns.writerUsed then ns.writerUsed[kind .. "#" .. i] = true end
  local text = list[i][1]
  if self.inChapter then
    if isVoice(list[i]) then self.voiceUsed = self.voiceUsed + 1 end
    if isQuip(list[i]) and not MATTERS[kind] then self.quipped = true end
  end
  if text:find("{in}") or text:find("{where}") or text:find("{place}") or (text:find("{at}") and values._named) then
    self.last, self.there = values._place, false
  elseif text:find("{at}") and values.at == "there" then
    self.there = true
  elseif text:find("{places}") or text:find("{zone}") then
    self.last = nil
  end
  text = text:gsub("{(%w+)}", values)
  -- a place left out: no space before the punctuation, none doubled
  -- (and none left at the start: "{at}, my tenth level" with no place)
  text = text:gsub(" +([%.,;:!%?])", "%1"):gsub("  +", " "):gsub("^[ ,;:]+", "")
  return raw and text or capitalise(text)
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
-- thing brought, a task, a message carried to another (a clause); its title
-- only when there is nothing else to tell.
local function lowerFirst(text) return (text:gsub("^%u", string.lower)) end
function Book:deed(m, key, tags)
  local o = m.objectives and m.objectives[1]
  local ender = m.ender ~= m.giver and m.ender or nil
  local values = { giver = m.giver, ender = ender }
  local done
  if o and o.type == "monster" and o.name then
    local count = o.n or 1
    -- one asked for is a named one, mostly ("Vagash"): no article
    values.n, values.foes = words(count), count > 1 and plural(o.name) or o.name
    tags.one = count == 1 or nil
    done = self:say("c-deed-kill", key, values, tags, nil, true)
  elseif o and o.type == "item" and o.name then
    local count = o.n or 1
    values.n, values.thing = words(count), count > 1 and things(o.name) or itemName(o.name)
    tags.one = count == 1 or nil
    done = self:say("c-deed-item", key, values, tags, nil, true)
  elseif o and o.text then
    values.task = lowerFirst((o.text:gsub("[%.:]%s*$", "")))
    done = self:say("c-deed-task", key, values, tags, nil, true)
  elseif ender and m.giver then
    done = self:say("c-deed-word", key, values, tags, nil, true)
  end
  if not done and m.title then
    done = self:say("c-quest", key, { quest = '"' .. m.title .. '"', giver = m.giver }, tags, nil, true)
  end
  return done
end

-- Linking words, by what happened since the moment before: night falling,
-- morning, hours gone by. Within a scene, the next thing.
local LINKS = {
  night = { "That night,", "By nightfall,", "When night came," },
  day = { "At first light,", "In the morning,", "With the dawn," },
  later = { "Later,", "Some hours later,", "Later that day," },
  next = { "Then", "After that,", "Next,", "Before long," },
}
function Book:link(m, prev, key)
  if not (m and prev and m.at and prev.at) then return nil end
  local which
  if m.night and not prev.night then which = "night"
  elseif prev.night and not m.night then which = "day"
  elseif m.at - prev.at > 3600 then which = "later" end
  return which and self:linkWord(which, key)
end
function Book:linkWord(which, key)
  local list = LINKS[which]
  return list[hash(self.seed .. "|word|" .. key) % #list + 1]
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
  local function newParagraph()
    if #current > 0 then table.insert(paragraphs, current); current = {} end
    self.quipped = false
  end
  local start = ch.start or {}
  local lvl = start.level or 1
  local function tags(t, m)
    t = t or {}
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
  local prev -- the moment before the one being told

  -- The clauses so far, as one sentence: "I a.", "I a and b.", "I a, b and c."
  local function flush()
    if #pending == 0 then return end
    local text = pending[1]
    if #pending > 1 then
      local last = pending[#pending]
      local thenFirst = table.concat(pending, "|"):find(" and ") or hash(self.seed .. "|join|" .. n .. "|" .. pending[1]) % 3 == 0
      text = table.concat(pending, ", ", 1, #pending - 1) .. (thenFirst and ", then " or " and ") .. last
    end
    table.insert(current, linked(lead, capitalise("I " .. text .. ".")))
    -- "there" only right after the place is named
    if not named then self.there = true end
    pending, lead, named = {}, nil, false
    sentences = sentences + 1
  end
  -- A clause for a moment: a new sentence takes a link (the time gone by, or
  -- the next thing in the scene); a sentence holds three clauses at most, and
  -- ends with a clause that has its own punctuation.
  local function clause(text, m, key)
    if not text then return end
    if #pending == 0 then
      lead = self:link(m, prev, key)
      if not lead and #current > 0 and sentences > 0 then
        lead = hash(self.seed .. "|next|" .. key) % 2 == 0 and self:linkWord("next", key) or nil
      end
    end
    table.insert(pending, text)
    if #pending >= 3 or text:find("[,:;]") then flush() end
  end
  -- A new scene at a place: told as the journey there (a place just named
  -- needs none).
  local function arrive(place, zone, m, key, opener)
    flush()
    if #current >= 5 then newParagraph() end
    local back = seenHere[place]
    scene, sceneZone, killed, sentences = place, zone, false, 0
    seenHere[place] = true
    if opener then
      clause(opener, m, key)
      named = true
    elseif place ~= self.last then
      clause(self:say(back and "c-return" or "c-travel", key .. "|go", { place = mid(place), _place = place }, tags(nil, m), nil, true), m, key)
      named = true
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
      table.insert(current, (#current > 0 and m) and linked(self:link(m, prev, key), s) or s)
      sentences = 1 -- what follows in the scene may be "then"
    end
    return s
  end

  -- Where the chapter began.
  local where = start.sub or start.zone
  local first = n == 1 and (c.began and c.began.level or 1) == 1 and lvl == 1
  if where then
    local s = self:say(first and "beginning" or "opening", n .. "|open", self:here({ where = mid(where) }, where), tags({ night = start.night or nil }))
    if s then table.insert(current, s) end
    scene, sceneZone = where, start.zone
    seenHere[where] = true
  end

  local mates, dungeon = {}, nil -- who joined me so far in the chapter; the dungeon I'm in
  for i, m in ipairs(ch.log or {}) do
    local key = n .. "|" .. i
    local place = placeOf(m)
    -- a clause in the scene where it happened
    local function inScene(text)
      if place and place ~= scene then arrive(place, m.zone, m, key) end
      clause(text, m, key)
    end
    local function c_(kind, values, t) return self:say(kind, key, values, tags(t, m), nil, true) end
    if m.k == "level" then
      lvl = m.level or lvl -- a level reached: recorded, not told
    elseif m.k == "place" then
      if m.new == "zone" then
        flush()
        newParagraph()
        self.last = nil
        alone("zone", key, { zone = mid(m.zone) }, tags(nil, m))
        self.last = nil
        scene, sceneZone = nil, nil
        if m.sub then
          arrive(m.sub, m.zone, m, key, c_("c-place", { place = mid(m.sub), _place = m.sub }))
        end
      elseif m.sub or m.zone then
        local here = m.sub or m.zone
        arrive(here, m.zone, m, key, c_("c-place", { place = mid(here), _place = here }))
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
      if place and place ~= scene then arrive(place, m.zone, m, key) end
      clause(self:deed(m, key, t), m, key)
    elseif m.k == "kill" then
      if m.quarry or SKIP[m.kind or ""] then -- told by its quest, or not a fight
      elseif m.first and KINDS[m.kind] then
        inScene(c_("c-first", { kind = KINDS[m.kind] }))
      elseif m.elite then
        inScene(c_("c-elite", { foe = namedElite(m.name) and m.name or article(m.name) }))
      elseif not (killed and place == scene) then
        inScene(c_("c-kill", { foe = article(m.name) }))
        killed = true
      end
    elseif m.k == "group" then
      if #mates < 4 then table.insert(mates, m.name) end
      inScene(c_("c-group", { mates = m.name }))
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
        inScene(c_("c-trainer", { spells = listing(named) }, { many = #spells > 3 or nil }))
      end
    elseif m.k == "skill" then
      inScene(c_("c-skill", { skill = m.name:lower(), rank = words(m.rank) }))
    elseif m.k == "prof" then
      inScene(c_("c-prof", { prof = m.name:lower(), rank = rankName(m.rank) }, { new = m.learned or nil }))
    elseif m.k == "gear" or m.k == "loot" then
      local item = m.link and m.link:match("%[(.-)%]")
      if item then inScene(c_("c-" .. m.k, { item = itemName(item) }, { made = m.made or nil })) end
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
        alone(m.hp <= 5 and "close-deep" or "close-light", key,
          self:here({ foe = article(m.foe), hp = tostring(m.hp) }, place), tags({ night = m.night or false }, m), m)
      elseif m.k == "died" and m.death then
        alone("died", key, self:here({ foe = deathFoe(m.death, article) }, place), deathTags(m.death), m)
      elseif m.k == "dungeon" then
        dungeon = m.name
        alone("dungeon", key, { dungeon = mid(m.name), mates = listing(mates) }, tags(nil, m), m)
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
      if s then table.insert(current, s) end
    end
    if (ch.quests or 0) >= 2 then
      local giver
      for i = #ch.log, 1, -1 do
        if ch.log[i].k == "quest" and ch.log[i].giver then giver = ch.log[i].giver break end
      end
      say("quests-many", "recap-q", { n = words(ch.quests), giver = giver }, tags())
    end
    local top = topKills(ch.kills)
    local a, b = top[1], top[2]
    if a and a.n >= 3 then
      if b and b.n >= 3 then
        say("kills-two", "recap-k", self:here({ n1 = words(a.n), foes1 = plural(a.name), n2 = words(b.n), foes2 = plural(b.name) }, nil),
          tags({ lots = a.n >= 15 or nil }))
      else
        say("kills", "recap-k", self:here({ n = words(a.n), foes = plural(a.name) }, nil), tags({ lots = a.n >= 15 or nil }))
      end
    end
    local played = ch.played or 0
    say("closing", "end", { time = playedWords(played), gold = goldWords(ch.gold) },
      tags({ slow = played > 7200 or nil, quick = (played > 0 and played < 1800) or nil }))
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
