-- The book's lines: one book's choice of sentences (Book:say), the scenery
-- of places, the lessons, the prologue and the epitaph. Each moment picks a
-- sentence of its kind (writing/<kind>.md):
--   - only sentences whose [tags] the moment has (night, hc, race:Dwarf...;
--     "!night" = not at night) and whose {slots} it can fill;
--   - a sentence never used twice in a book while a fresh one is left (then the
--     one used longest ago);
--   - chosen by a hash of the character and the moment, so the book reads the
--     same each time it is opened.
-- Counts are written in words; every sentence starts with a capital. {at}
-- names a place ("in Thelsamar"), {in} too, for sentences without a verb.
local _, ns = ...
local W = ns.writer
local floor, mid, TITLES, capitalise = W.floor, W.mid, W.TITLES, W.capitalise
local FACTION, HOME, KIN, faith, weapon = W.FACTION, W.HOME, W.KIN, W.faith, W.weapon
local words, deathTags, deathFoe, playedWords = W.words, W.deathTags, W.deathFoe, W.playedWords

-- ── the writer of one book ───────────────────────────────────────────────────
local function hash(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 2147483648
  end
  -- its low bits are poor (the lowest is the parity of the bytes' sum, so
  -- "% 2" between similar keys always agreed): the high ones brought down
  return (h % 65536) * 32768 + math.floor(h / 65536)
end

-- A line's tags: conditions the moment must meet ("night"; "!night", not at
-- night).
local function holds(tag, ctx)
  if tag:sub(1, 1) == "!" then return not ctx[tag:sub(2)] end
  return ctx[tag] and true or false
end
local function satisfied(tags, ctx)
  for _, t in ipairs(tags or {}) do
    if not holds(t, ctx) then return false end
  end
  return true
end

-- (a name with a title of its own, "Aetheen of the Gales", "Leonid
-- Barthalomew the Revered", or a thing's, "Wizzlecrank's Shredder", takes
-- no "'s"; "found a way to" no "find"; nor a word said twice where the
-- slot meets it: "went on {at}", "on Zephras Isle")
local function fillable(text, values)
  for slot in text:gmatch("{(%w+)}") do
    local v = values[slot]
    if v == nil then return false end
    local before = type(v) == "string" and text:match("(%a+) {" .. slot .. "}")
    if before and v:match("^(%a+)") == before then return false end
    if type(v) == "string" and text:find("{" .. slot .. "}'s", 1, true) then
      if v:find(" of ", 1, true) or v:find(" the ", 1, true) or v:find("'s ", 1, true) then return false end
    end
  end
  if values.task and text:find("found a way to {task}", 1, true) and values.task:find("^find ") then return false end
  return true
end

-- How many uses of a kind before one of the race's own sentences may come back.
local OWN_GAP = 12
-- A race's emblems, by the start of their words: a line on one, no other on
-- it for MOTIF_GAP lines told (a voice is a way of looking, not a refrain:
-- the forge, the camps, the drums, a hoof in every sentence).
local MOTIFS = {
  Dwarf = {
    "forge",
    "anvil",
    "smith",
    "smelt",
    "assay",
    "mortar",
    "hinge",
    "seam",
    "keystone",
    "quarr",
    "mason",
    "chisel",
    "ale",
    "beard",
    "iron",
  },
  Gnome = {
    "gnomeregan",
    "refugee",
    "radiat",
    "evacuat",
    "tinker",
    "contraption",
    "sprocket",
    "gear",
    "calculat",
    "sum",
    "reckon",
    "measure",
  },
  Orc = { "thrall", "camp", "draenor", "durnholde", "warband", "temper", "rage", "blood", "chain", "grom" },
  Troll = { "drum", "fish", "supper", "crab", "sea", "shore", "coal", "loa", "echo isles", "sen'jin", "village" },
  Tauren = {
    "hoof",
    "hooves",
    "horn",
    "broad",
    "my people",
    "earth mother",
    "plains",
    "kodo",
    "slow",
    "unhurried",
    "size",
  },
  Human = { "stormwind", "king", "mason", "bread", "neighbour", "doorstep", "honest", "conscience" },
  NightElf = { "elune", "moon", "teldrassil", "centur", "ages", "glade", "root", "hyjal" },
  Scourge = { "grave", "pulse", "lich king", "sylvanas", "plague", "coffin", "lid", "first life", "second life" },
  Skyborne = { "island", "skycutter", "zephras", "balance", "footing", "skystream" },
}
local MOTIF_GAP = 12
local function motifsOf(race, text)
  local found, lower = {}, text:lower()
  for _, m in ipairs(MOTIFS[race] or {}) do
    if lower:find("%f[%a]" .. m) then table.insert(found, m) end
  end
  return found
end

local PEOPLE = { "giver", "via", "ender", "boss", "mates", "pet" } -- slots that name people
local Book = {}
Book.__index = Book

-- (diary: a short book read at a sitting, its frames never back while a
-- fresh one is left, shared or the race's own)
local function newBook(c, diary)
  local race, class = c.race or "Human", c.class or "WARRIOR"
  local b = setmetatable({
    c = c,
    freshFirst = diary or nil,
    used = {},
    usedIn = {},
    uses = 0,
    seed = c.guid or "",
    kindUses = {},
  }, Book)
  b.race = race
  b.motifAt = {} -- [a race's emblem] = the line told that last used it
  b.voice = { home = HOME[race], kin = KIN[race], faith = faith(race, class), weapon = weapon(race, class) }
  b.own = ns.data.voices and ns.data.voices[race] -- the race's own journal voice (writing/voices/<Race>/)
  b.faction = (c.faction == "alliance" or c.faction == "horde") and c.faction or FACTION[race]
  b.sceneSeen = {} -- places already described in this book
  b.noted = {} -- the spells told by a line of their own (writing/lesson.md)
  b.base = { hc = c.hardcore or nil, ["race:" .. race] = true, ["class:" .. class] = true }
  -- (a class that fights with a blade in hand: only it "cuts down" a foe)
  b.base.melee = (class == "WARRIOR" or class == "ROGUE" or class == "PALADIN") or nil
  if b.faction then b.base["faction:" .. b.faction] = true end
  return b
end

function Book:use(kind, e)
  self.uses = self.uses + 1
  self.kindUses[kind] = (self.kindUses[kind] or 0) + 1
  self.used[e.id] = self.uses
  self.usedIn[e.id] = self.kindUses[kind]
  if ns.writerUsed then ns.writerUsed[e.reach] = true end
end

-- The people a sentence names (values), with "the" where it belongs:
-- people named with their article ("The Defias Traitor") or by a role ("the
-- Captured Mountaineer", Names.lua).
function Book:people(values)
  local roleNamed = ns.names and ns.names.npcThe or {}
  for _, k in ipairs(PEOPLE) do
    if type(values[k]) == "string" then
      values[k] = values[k]:gsub("[^,]+", function(part)
        local lead, name, tail = part:match("^(%s*)(.-)(%s*)$")
        local andWord, rest = name:match("^(and )(.+)$")
        name = rest or name
        if name:find("^The ") then
          name = "the " .. name:sub(5)
        elseif roleNamed[name] and not TITLES[name:match("^(%a+)") or ""] then
          name = "the " .. name
        end
        return lead .. (andWord or "") .. name .. tail
      end)
    end
  end
end

-- The sentences of a kind that fit: the race's own fresh ones, the shared
-- fresh ones (and those of them with tags), and all that fit, used or not.
-- Each with its id (what "used" remembers) and its name in the reachability
-- test: the race's own ("Dwarf/kill#3") and the shared ("kill#3").
function Book:candidates(kind, values, ctx)
  -- A place just named is not named again by a sentence without a verb,
  -- unless no other sentence fits.
  local named = values["in"]
  if named and values._place == self.last and not self.there then values["in"] = nil end
  local race = self.c.race or "Human"
  local own, list = self.own and self.own[kind], ns.data.writing[kind]
  if ctx._shared then own = nil end -- (the shared lines only: an entry's limit on a race's own)
  local ownFresh, fresh, voiced, all
  for _ = 1, 2 do
    ownFresh, fresh, voiced, all = {}, {}, {}, {}
    local function add(from, mine)
      for i, line in ipairs(from or {}) do
        if satisfied(line.tags, ctx) and fillable(line[1], values) then
          local e = mine and { s = line, id = "v:" .. kind .. i, reach = race .. "/" .. kind .. "#" .. i }
            or { s = line, id = kind .. i, reach = kind .. "#" .. i }
          table.insert(all, e)
          if not self.used[e.id] then
            if mine then
              table.insert(ownFresh, e)
            else
              table.insert(fresh, e)
              if line.tags then table.insert(voiced, e) end
            end
          end
        end
      end
    end
    add(own, true)
    add(list, false)
    if #all > 0 then break end
    values["in"] = named -- (nothing fits: the place may be named again)
  end
  return ownFresh, fresh, voiced, all
end

-- The sentence told, among the candidates: the race's own first while one is
-- fresh; then the lowest bit of the hash chooses between the shared tagged
-- lines and the rest, the others which; all used, the one used longest ago.
-- A routine clause doesn't begin with the verb of the one before, if a fresh
-- one can help it; prefer: tags to favour.
function Book:pick(kind, key, prefer, ownFresh, fresh, voiced, all)
  -- (a clause avoids the verb of the one before: "I hunted… I hunted"; nor
  -- one that ends as the one before did: "… soon after. … soon after.")
  local clause = kind:find("^c%-") ~= nil
  local verb = clause and self.lastVerb or nil
  local tail = clause and self.lastTail
  local function tailOf(text) return text:match("(%a+ %a+)%W*$") end
  local function sameVerb(e)
    return e and ((verb and e.s[1]:match("^(%a+)") == verb) or (tail and tailOf(e.s[1]) == tail)) or false
  end
  if verb or tail then
    local function other(group)
      local kept = {}
      for _, e in ipairs(group) do
        if not sameVerb(e) then table.insert(kept, e) end
      end
      return kept
    end
    local o, f, v = other(ownFresh), other(fresh), other(voiced)
    if #o > 0 then
      ownFresh = o
    elseif #f > 0 then
      ownFresh = {}
    end
    if #f > 0 then
      fresh, voiced = f, v
    end
  end
  -- (nor a race's emblem used a moment ago: another line, if there is one)
  local said = self.saidCount or 0
  local function stale(e)
    for _, m in ipairs(motifsOf(self.race, e.s[1])) do
      if self.motifAt[m] and said - self.motifAt[m] < MOTIF_GAP then return true end
    end
    return false
  end
  local function lively(group)
    local kept = {}
    for _, e in ipairs(group) do
      if not stale(e) then table.insert(kept, e) end
    end
    return kept
  end
  local lo, lf, lv = lively(ownFresh), lively(fresh), lively(voiced)
  if #lo + #lf > 0 then
    ownFresh, fresh, voiced = lo, lf, lv
  end
  local function favours(e)
    for _, t in ipairs(e.s.tags or {}) do
      if prefer[t] then return true end
    end
    return false
  end
  local only = false -- (the lines preferred, when there are any: no other of the race's comes back)
  if prefer then
    -- (the race's own first, as ever, among the lines preferred)
    local function favoured(group)
      local found = {}
      for _, e in ipairs(group) do
        if favours(e) then table.insert(found, e) end
      end
      return found
    end
    local ownFavoured, sharedFavoured = favoured(ownFresh), favoured(fresh)
    if #ownFavoured + #sharedFavoured > 0 then
      ownFresh, fresh, voiced, only = ownFavoured, sharedFavoured, {}, true
    end
  end
  local h = hash(self.seed .. "|" .. kind .. "|" .. key)
  local pick = floor(h / 2)
  -- once all of the race's own were used: its oldest comes back, if it has
  -- been long enough (a voice that holds over a whole life, not shared prose)
  -- (one of those spaced enough, chosen as the fresh ones are: the oldest
  -- every time would replay the first round in its order)
  local ownOldest
  if #ownFresh == 0 then
    local gap = self.ownGap or OWN_GAP
    local spaced = {}
    for _, x in ipairs(all) do
      if
        x.id:sub(1, 2) == "v:"
        and self.used[x.id]
        and (self.kindUses[kind] or 0) - self.usedIn[x.id] >= gap
        and not sameVerb(x)
        and not (only and not favours(x))
      then
        table.insert(spaced, x)
      end
    end
    if #spaced > 0 then ownOldest = spaced[pick % #spaced + 1] end
  end
  if #ownFresh > 0 then return ownFresh[pick % #ownFresh + 1] end
  if ownOldest and not (self.freshFirst and #fresh > 0) then return ownOldest end
  if #voiced > 0 and h % 2 == 0 then return voiced[pick % #voiced + 1] end
  if #fresh > 0 then return fresh[pick % #fresh + 1] end
  local e = all[1]
  for _, x in ipairs(all) do
    if self.used[x.id] < self.used[e.id] then e = x end
  end
  return e
end

-- What a sentence did to the place just named: named it (then "there"), said
-- "there" (then nothing), or moved on to other places.
function Book:placed(text, values)
  if text:find("{in}") or text:find("{where}") or text:find("{place}") or (text:find("{at}") and values._named) then
    self.last, self.there = values._place, false
  elseif text:find("{at}") and values.at == "there" then
    self.there = true
  elseif text:find("{inn}") then
    self.last, self.there = values._place, values.inn == "there"
  elseif text:find("{places}") or text:find("{zone}") then
    self.last = nil
  end
end

-- One sentence of a kind for a moment: key makes the choice stable, values
-- fill the slots (_place: the place {at}, {in} or {where} names), tags add to
-- the character's. prefer: tags to favour (a fresh sentence with one of them
-- wins over the rest). raw: a clause, left as it is (no capital).
-- Returns the text and what was chosen: { kind, own (a race's own line) }.
function Book:say(kind, key, values, tags, prefer, raw)
  if not ns.data.writing[kind] then return end
  local ctx = setmetatable(tags or {}, { __index = self.base })
  for k, v in pairs(self.voice) do
    if values[k] == nil then values[k] = (k == "weapon" and self.weaponHeld) or v end -- (the weapon in hand, once known)
  end
  self:people(values)
  local ownFresh, fresh, voiced, all = self:candidates(kind, values, ctx)
  if #all == 0 then return end
  local e = self:pick(kind, key, prefer, ownFresh, fresh, voiced, all)
  -- (its emblems, remembered: MOTIFS)
  self.saidCount = (self.saidCount or 0) + 1
  for _, m in ipairs(motifsOf(self.race, e.s[1])) do
    self.motifAt[m] = self.saidCount
  end
  self:use(kind, e)
  local text = e.s[1]
  if kind:find("^c%-") then
    self.lastVerb, self.lastTail = text:match("^(%a+)"), text:match("(%a+ %a+)%W*$")
  end
  self:placed(text, values)
  text = text:gsub("{(%w+)}", values)
  -- a place left out: no space before the punctuation, none doubled
  -- (and none left at the start: "{at}, my tenth level" with no place)
  text = text:gsub(" +([%.,;:!%?])", "%1"):gsub("  +", " "):gsub("^[ ,;:]+", "")
  return raw and text or capitalise(text), { kind = kind, own = e.id:sub(1, 2) == "v:" }
end

-- The place slots of a moment: {at} ("in Coldridge Valley", "there" if it was
-- just named, then nothing), {in} (always the name), and the place itself.
function Book:here(values, place)
  if not place then
    values.at = ""
  elseif place ~= self.last then
    values.at, values._named = W.at(place), true
  else
    values.at = self.there and "" or "there"
  end
  values["in"], values._place = W.at(place), place
  return values
end

local SCENERY_ALIAS = {
  Deadmines = "The Deadmines",
  ["Stormwind Stockade"] = "The Stockade",
  ["The Temple of Atal'Hakkar"] = "Sunken Temple",
  ["Temple of Ahn'Qiraj"] = "Ahn'Qiraj Temple",
}

function Book:sceneryOf(name, night)
  name = SCENERY_ALIAS[name or ""] or name
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

-- ── the lessons, the prologue and the epitaph ────────────────────────────────
-- (a trade's own spell, learned before the game listed the trade, is told by
-- the trade); a spell with a line of its own (writing/lesson.md: Life Tap,
-- paid in blood) told by it after the lesson, the first of them
local noted
local function hasNote(spell, book)
  if not noted then
    noted = {}
    for _, line in ipairs(ns.data.writing.lesson or {}) do
      for _, t in ipairs(line.tags or {}) do
        local name = t:match("^spell:(.+)$") -- (its spaces "_": [spell:Life_Tap])
        if name then
          name = name:gsub("_", " ")
          noted[name] = noted[name] or {}
          table.insert(noted[name], line)
        end
      end
    end
  end
  -- (a line for this race and class: a Forsaken priest's Smite is not every priest's)
  for _, line in ipairs(noted[spell] or {}) do
    local fits = true
    for _, t in ipairs(line.tags or {}) do
      local neg, k = t:match("^(!?)(%a+:.+)$")
      if k and not k:find("^spell:") then
        local has = book.base[k] == true
        if (neg == "!") == has then fits = false end
      end
    end
    if fits then return true end
  end
  return false
end
-- The spells of a lesson worth telling: not a trade's own, a demon's or a
-- form's (told at their first use), nor a trade's rank.
local function taught(spells, c)
  local out, seen = {}, {}
  for _, sp in ipairs(spells or {}) do
    sp = sp:gsub(" %(.-%)$", "") -- (a rank in its name: "Create Healthstone (Minor)")
    if
      not seen[sp]
      and not (
        (c.profs or {})[sp]
        or ns.TRADE_SPELLS[sp]
        or ns.POWER_SPELLS[sp]
        or sp:find("^Apprentice ")
        or sp:find("^Journeyman ")
        or sp:find("^Expert ")
        or sp:find("^Artisan ")
        or sp:find("^Master ")
      )
    then
      seen[sp] = true
      table.insert(out, sp)
    end
  end
  return out
end

function Book:prologue(p)
  local zone = p.zone
  return self:say(
    "prologue",
    "prologue",
    self:here({
      zone = mid(zone),
      quests = (p.quests or 0) > 1 and words(p.quests) or nil,
      inn = mid(p.inn),
      played = playedWords(p.played),
    }, zone),
    {}
  )
end

-- The epitaph of a Hardcore life, in the third person: how it ended (a line
-- telling the cause wins), what it was (its totals, a rare, a dungeon), and a
-- farewell (often in the voice of its race or class).
local RACE_WORD = {
  Human = "human",
  Dwarf = "dwarf",
  NightElf = "night elf",
  Gnome = "gnome",
  Orc = "orc",
  Troll = "troll",
  Tauren = "tauren",
  Scourge = "Forsaken",
}
function Book:epitaph(c)
  local d = c.death or {}
  local race, class = RACE_WORD[c.race] or "", (c.class or ""):lower()
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
  local first = self:say(
    "epitaph",
    "epitaph",
    self:here({ name = c.name, who = who, level = words(d.level or 0), zone = mid(d.zone), foe = deathFoe(d) }, place),
    tags,
    cause
  )

  local quests, kills, played, rare, dungeon, zones = 0, 0, 0, nil, nil, 0
  for _, ch in ipairs(c.chapters or {}) do
    quests = quests + (ch.quests or 0)
    played = played + (ch.played or 0)
    for _, n in pairs(ch.kills or {}) do
      kills = kills + n
    end
    for _, m in ipairs(ch.log or {}) do
      if m.k == "rare" then rare = rare or m.name end
      if m.k == "dungeon" then dungeon = dungeon or m.name end
    end
  end
  for key in pairs(c.visited or {}) do
    if key:sub(-1) == "|" then zones = zones + 1 end
  end
  local second = self:say("remembrance", "remembrance", {
    name = c.name,
    played = playedWords(played),
    quests = quests > 1 and words(quests) or nil, -- "one tasks": no
    kills = kills > 1 and words(kills) or nil,
    rare = rare,
    dungeon = mid(dungeon),
    zones = zones > 1 and words(zones) or nil,
  }, { low = tags.low, high = tags.high, inside = tags.inside })
  local third = self:say("farewell", "farewell", { name = c.name }, { low = tags.low })
  if not first then return nil end
  local parts = { first }
  if second then table.insert(parts, second) end
  if third then table.insert(parts, third) end
  return table.concat(parts, " ")
end

-- (for the next files of the writer)
W.hash = hash
W.Book = Book
W.newBook = newBook
W.taught, W.hasNote = taught, hasNote
