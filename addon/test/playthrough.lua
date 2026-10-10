-- Books written by playing the game's real quests: for each race, from its
-- starting zone, the quests open to it (race, class, prerequisites, level),
-- taken a few at a time from their real givers, done against their real
-- targets (the creatures asked for, or those that drop the item asked for),
-- marked done where it happens and turned in to their real enders; reward
-- gear worn, levels gained, a chapter from rest to rest. Every chapter goes
-- through the writer's checks (inspect.lua); the books are written out for
-- reading in .cache/audit/books/.
--   luajit addon/test/playthrough.lua        (after `bun run audit`)
--   FOREVER=1 luajit addon/test/playthrough.lua   WoW Forever: the Skyborne from
--     Zephras Isle and the old races' new classes, on Forever's own quests
--     too (.cache/audit/game-forever.lua, from scripts/forever-data.ts);
--     the books in .cache/audit/books-forever/.
local forever = os.getenv("FOREVER") == "1"
local DIR = "addon/Hearthtale/"
local ns = {}
assert(loadfile(DIR .. (forever and "Data_Forever.lua" or "Data_Classic.lua")))("Hearthtale", ns)
assert(loadfile(DIR .. "Names.lua"))("Hearthtale", ns)
dofile("addon/test/writer-files.lua")(ns, DIR)
local ok, D = pcall(dofile, ".cache/audit/game.lua")
if not ok then
  io.stderr:write("no game data: run bun run audit\n")
  os.exit(1)
end
if forever then
  local found, F = pcall(dofile, ".cache/audit/game-forever.lua")
  if not found then
    io.stderr:write("no Forever data: run bun scripts/forever-data.ts\n")
    os.exit(1)
  end
  for name, t in pairs(F) do
    for id, v in pairs(t) do
      if name == "quests" then v.forever = true end
      D[name][id] = v
    end
  end
end
-- The quest givers, by name: their people and calling (scripts/knowledge.ts,
-- and Forever's own callings, scripts/forever-data.ts)
local found, NPCS = pcall(dofile, ".cache/audit/npcs.lua")
if not found then
  io.stderr:write("no quest givers: run bun scripts/knowledge.ts\n")
  os.exit(1)
end
if forever then
  for name, v in pairs(dofile(".cache/audit/npcs-forever.lua")) do
    NPCS[name] = NPCS[name] or v
  end
end
local BOOKS = forever and ".cache/audit/books-forever" or ".cache/audit/books"

local problems = {}
local function problem(where, msg, text)
  if #problems < 30 then table.insert(problems, ("%s: %s\n    %s"):format(where, msg, text)) end
end
local inspect = dofile("addon/test/inspect.lua")(problem)

-- The game's codes.
local RACE = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local CLASS =
  { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local TYPE = { "Beast", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Humanoid", "Critter", "Mechanical" }
local FAMILY = {
  [1] = "Wolf",
  [2] = "Cat",
  [3] = "Spider",
  [4] = "Bear",
  [5] = "Boar",
  [6] = "Crocolisk",
  [7] = "Carrion Bird",
  [8] = "Crab",
  [9] = "Gorilla",
  [11] = "Raptor",
  [12] = "Tallstrider",
  [20] = "Scorpid",
  [21] = "Turtle",
  [24] = "Bat",
  [25] = "Hyena",
  [26] = "Owl",
  [27] = "Wind Serpent",
}
-- Each race's road, by the game's zone ids: its starting valley, its land,
-- then its faction's zones in the order players level through them.
local ALLIANCE = { 40, 38, 44, 148, 10, 11, 331, 267, 45, 400, 33 } -- Westfall … Stranglethorn
local HORDE = { 17, 130, 406, 331, 267, 400, 45, 33 } -- the Barrens … Stranglethorn
local ROAD = {
  -- Zephras Isle (Forever), then where Valanaar's airships land: Dalaran in
  -- the Alterac Mountains (Alliance), Skywatcher Plateau in Mulgore (Horde)
  Skyborne = { alliance = { 16593, 36 }, horde = { 16593, 215 } },
  Human = { 9, 12 },
  Dwarf = { 132, 1 },
  Gnome = { 132, 1 },
  NightElf = { 188, 141, 148 },
  Orc = { 363, 14 },
  Troll = { 363, 14 },
  Scourge = { 154, 85 },
  Tauren = { 220, 215 },
}
local FACTION = {
  Human = ALLIANCE,
  Dwarf = ALLIANCE,
  Gnome = ALLIANCE,
  NightElf = ALLIANCE,
  Orc = HORDE,
  Troll = HORDE,
  Scourge = HORDE,
  Tauren = HORDE,
}
local LIVES = {
  { "Human", "WARRIOR" },
  { "Dwarf", "HUNTER" },
  { "NightElf", "DRUID" },
  { "Gnome", "MAGE" },
  { "Orc", "SHAMAN" },
  { "Troll", "PRIEST" },
  { "Tauren", "WARRIOR" },
  { "Scourge", "ROGUE" },
}
-- Forever: the Skyborne of each side (the High Order, Alliance; the
-- Windshapers, Horde), and the old races' new classes.
if forever then
  LIVES = {
    { "Skyborne", "MAGE", "alliance" },
    { "Skyborne", "HUNTER", "alliance" },
    { "Skyborne", "SHAMAN", "horde" },
    { "Skyborne", "DRUID", "horde" },
    { "Skyborne", "WARRIOR", "horde" },
    { "Skyborne", "ROGUE", "alliance" },
    { "Scourge", "PALADIN" },
    { "Dwarf", "SHAMAN" },
    { "Gnome", "PRIEST" },
    { "Human", "HUNTER" },
    { "Orc", "MAGE" },
    { "Troll", "WARLOCK" },
  }
end
local SIDE = { Human = "alliance", Dwarf = "alliance", Gnome = "alliance", NightElf = "alliance" }
-- (the lands of one side only: a Forever quest's ender there, a creature
-- of the old game Forever has put somewhere else, is met where the quest is)
local LANDS = { alliance = {}, horde = {} }
for race, road in pairs(ROAD) do
  if race ~= "Skyborne" then
    for _, z in ipairs(road) do
      LANDS[SIDE[race] or "horde"][z] = true
    end
  end
end
for _, z in ipairs(ALLIANCE) do
  LANDS.alliance[z] = true
end
for _, z in ipairs(HORDE) do
  LANDS.horde[z] = true
end
local SIDE_RACES = { alliance = 1 + 4 + 8 + 64, horde = 2 + 16 + 32 + 128 }
local MATES = { "Thessaly", "Brannigan", "Rowan", "Halvard", "Ysolde", "Korrak", "Mirelle", "Durgan" }
local TO = tonumber(os.getenv("PLAYTHROUGH_LEVEL") or "") or 30

-- What a class can use, as the original game has it: its weapons (item
-- subclasses), the armour it wears before and after 40 (cloth 1, leather 2,
-- mail 3, plate 4), a shield. A reward it can't use isn't taken.
local WEAPONS = {
  WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 },
  PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
  HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 },
  ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
  PRIEST = { 4, 10, 15, 19 },
  SHAMAN = { 0, 4, 5, 10, 13, 15 },
  MAGE = { 7, 10, 15, 19 },
  WARLOCK = { 7, 10, 15, 19 },
  DRUID = { 4, 5, 10, 13, 15 },
}
local ARMOR = {
  WARRIOR = { 3, 4 },
  PALADIN = { 3, 4 },
  HUNTER = { 2, 3 },
  SHAMAN = { 2, 3 },
  ROGUE = { 2, 2 },
  DRUID = { 2, 2 },
  PRIEST = { 1, 1 },
  MAGE = { 1, 1 },
  WARLOCK = { 1, 1 },
}
local SHIELDS = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local function usable(item, class, level)
  if item.classes and bit.band(item.classes, CLASS[class]) == 0 then return false end
  if item.req and item.req > level then return false end
  if item.class == 2 then
    for _, sub in ipairs(WEAPONS[class]) do
      if sub == item.sub then return true end
    end
    return false
  end
  if item.class ~= 4 then return false end
  if item.sub == 0 then return true end -- rings, necklaces, trinkets
  if item.sub == 6 then return SHIELDS[class] or false end
  if item.sub > 4 then return false end
  return item.sub <= ARMOR[class][level >= 40 and 2 or 1]
end

-- What a class learns, as its trainers teach it (.cache/audit/game.lua's
-- lessons, from cmangos): every other level, what opened since the last
-- visit; a race's own priest spells for that race; a form or a demon is a
-- power, not a lesson (Util.lua), told when first used.
local RACIAL = {
  Starshards = "NightElf",
  ["Elune's Grace"] = "NightElf",
  ["Desperate Prayer"] = "Human Dwarf",
  ["Fear Ward"] = "Dwarf",
  Feedback = "Human",
  ["Touch of Weakness"] = "Scourge",
  ["Devouring Plague"] = "Scourge",
  ["Hex of Weakness"] = "Troll",
  Shadowguard = "Troll",
}
local NOT_TAUGHT = { ["Elemental Fury"] = true } -- (a shaman's talent in the warrior trainers' list)
local function lessonsAt(class, race, from, to)
  local out = {}
  for l = from, to do
    for _, spell in ipairs(((D.lessons or {})[class] or {})[l] or {}) do
      local own = RACIAL[spell]
      if
        not spell:find("^zz")
        and not NOT_TAUGHT[spell]
        and not ns.POWER_SPELLS[spell]
        and (not own or own:find(race))
      then
        table.insert(out, spell)
      end
    end
  end
  return out
end
-- A warlock's demons and a druid's forms, at the levels the original game
-- gives them (its class quests, which the road leaves out); a hunter's first
-- pet at 10, a beast of the land.
local DEMONS = {
  { 4, "Imp", "Zigfik" },
  { 10, "Voidwalker", "Ganrul" },
  { 20, "Succubus", "Lirasha" },
  { 30, "Felhunter", "Kezzik" },
}
local FORMS = { { 10, "bear" }, { 16, "aquatic" }, { 20, "cat" }, { 30, "travel" } }
-- (a shaman's initiations: the element's totem, the end of its class quests)
local TOTEMS = { { 4, "earth" }, { 10, "fire" }, { 20, "water" }, { 30, "air" } }
local PET_NAMES = { "Bristle", "Grimfang", "Thistle", "Ember", "Dusk", "Rook" }

-- (a creature Classic left unused and Forever gave back a role: by its name)
for _, c in pairs(D.creatures) do
  if c.name then c.name = c.name:gsub("^UNUSED ", "") end
end
local function creature(id) return id and id > 0 and D.creatures[id] or nil end
local function kindOf(c) return FAMILY[c.family or 0] or TYPE[c.type or 0] end

-- (Forever's quests, their class or side unrecorded: a class trainer's
-- own is that class's; one whose people are all of one side, that side's)
local PEOPLE_SIDE = {
  Human = "alliance",
  Dwarf = "alliance",
  Gnome = "alliance",
  NightElf = "alliance",
  Orc = "horde",
  Troll = "horde",
  Tauren = "horde",
  Scourge = "horde",
}
-- (a title another quest gives to its class: Call of Fire is a shaman's)
local TITLE_CLASSES = {}
for _, q in pairs(D.quests) do
  if (q.classes or 0) ~= 0 and q.title then TITLE_CLASSES[q.title] = bit.bor(TITLE_CLASSES[q.title] or 0, q.classes) end
end
-- (a giver whose every other quest is a class's: Ravenholdt's for rogues)
local GIVER = {}
for _, q in pairs(D.quests) do
  for _, id in ipairs(q.starters or {}) do
    local g = GIVER[id] or { all = 0, classed = 0, mask = 0 }
    GIVER[id] = g
    g.all = g.all + 1
    if (q.objectives or ""):lower():find("pickpocket") then g.rogue = true end -- (Ravenholdt's)
    if (q.classes or 0) ~= 0 then
      g.classed, g.mask = g.classed + 1, bit.bor(g.mask, q.classes)
    end
  end
end
-- (the place a quest's own words give a person: "Magatha Grimtotem in
-- Thunder Bluff")
local ZONE_NAMED = {}
for id, name in pairs(D.zones) do
  ZONE_NAMED[name] = ZONE_NAMED[name] or id
end
local function placeNamed(q, person)
  local text = q.objectives or ""
  local at = person.name and text:find(person.name, 1, true)
  local named = at and text:sub(at + #person.name):match("^,? in ([%u][%a' ]*%a)")
  named = named and (named:match("^the (.+)$") or named)
  return named and (ZONE_NAMED[named] or ZONE_NAMED["The " .. named])
end
local function unrecorded(q, class, side)
  local mask = (q.classes or 0) == 0 and TITLE_CLASSES[q.title or ""]
  if mask and bit.band(mask, CLASS[class]) == 0 then return false end
  for _, id in ipairs((q.classes or 0) == 0 and q.starters or {}) do
    local g = GIVER[id]
    if g and g.classed > 0 and g.classed == g.all - 1 and bit.band(g.mask, CLASS[class]) == 0 then return false end
    if g and g.rogue and class ~= "ROGUE" then return false end
  end
  local sides = {}
  for _, list in ipairs({ q.starters or {}, q.enders or {} }) do
    for _, id in ipairs(list) do
      local c = creature(id)
      local npc = c and NPCS[c.name]
      local trains = npc and npc.role and npc.role:match("^(%a+) Trainer$")
      if (q.classes or 0) == 0 and trains and CLASS[trains:upper()] and trains:upper() ~= class then return false end
      if npc and PEOPLE_SIDE[npc.people or ""] then sides[PEOPLE_SIDE[npc.people]] = true end
    end
  end
  if not q.side and (q.races or 0) == 0 and sides.alliance ~= sides.horde and not sides[side] then return false end
  return true
end

-- A quest one can play: open to the race and class, its targets alive
-- somewhere, its items dropped or found somewhere (or in hand from the start).
local function playable(q, race, class, side)
  if q.zone == nil or q.zone <= 0 then return false end -- class, profession and holiday quests
  if q.repeatable then return false end -- turned in again and again: a player's choice, not the road
  if q.side and q.side ~= side then return false end -- (Forever's: a side's own)
  if q.forever and not q.level then return false end -- (Forever's, its level unknown: not on the road)
  if q.forever and not unrecorded(q, class, side) then return false end
  -- (a donation, "A Donation of Wool": sixty cloth gathered over many days, not a hunt)
  if q.forever and q.items and #q.items > 0 then
    local donation = true
    for _, pair in ipairs(q.items) do
      local item = D.items[pair[1]]
      if not (item and item.class == 7 and pair[2] >= 20) then donation = false end
    end
    if donation then return false end
  end
  -- (the Skyborne have no bit of the old masks: a quest for every race of their side is theirs)
  if q.races and q.races ~= 0 and race == "Skyborne" and bit.band(q.races, SIDE_RACES[side]) ~= SIDE_RACES[side] then
    return false
  end
  if q.races and q.races ~= 0 and race ~= "Skyborne" and bit.band(q.races, RACE[race]) == 0 then return false end
  if q.classes and q.classes ~= 0 and bit.band(q.classes, CLASS[class]) == 0 then return false end
  for _, t in ipairs(q.targets or {}) do
    local c = creature(t[1])
    if t[1] > 0 and not (c and c.spawns > 0) then return false end
  end
  for _, pair in ipairs(q.items or {}) do
    local s = D.sources[pair[1]]
    -- (Forever's: an item whose source no trace saw is still found, somewhere)
    local found = q.forever and D.items[pair[1]]
    if
      q.src ~= pair[1]
      and not found
      and not (s and ((s.creatures and #s.creatures > 0) or (s.objects and #s.objects > 0)))
    then
      return false
    end
  end
  return true
end

-- What the quest log shows of a quest, as the recorder keeps it (Record.lua):
-- a creature "slain", or the quest's own words; an item; an event's text.
local function objectivesOf(q)
  local out = {}
  for k, t in ipairs(q.targets or {}) do
    local own = q.texts[k] ~= "" and q.texts[k] or nil
    local c = creature(t[1])
    if own then
      table.insert(out, { type = t[1] > 0 and "monster" or "object", text = own, n = t[2] })
    elseif c then
      table.insert(out, { type = "monster", name = c.name, n = t[2] })
    else
      table.insert(out, { type = "object", text = (D.objects[-t[1]] or "?"), n = t[2] })
    end
  end
  for _, pair in ipairs(q.items or {}) do
    local item = D.items[pair[1]]
    if item then table.insert(out, { type = "item", name = item.name, n = pair[2], held = q.src == pair[1] or nil }) end
  end
  for k = #(q.targets or {}) + 1, 4 do
    if q.texts[k] and q.texts[k] ~= "" then table.insert(out, { type = "event", text = q.texts[k] }) end
  end
  return #out > 0 and out or nil
end

-- The quest that ends a shaman's initiation into an element, for this
-- race and side (Knowledge.lua's totem), if the game has one.
local function totemQuest(element, race, side)
  local ids = {}
  for id, k in pairs(ns.knowledge.quests) do
    -- (the original game's: Forever's own are on the road, played as found)
    if k.class == "SHAMAN" and k.totem == element and D.quests[id] and not D.quests[id].forever then
      table.insert(ids, id)
    end
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local q = D.quests[id]
    local races = q.races or 0
    if race == "Skyborne" then
      if races == 0 or bit.band(races, SIDE_RACES[side]) ~= 0 then return id end
    elseif races == 0 or bit.band(races, RACE[race]) ~= 0 then
      return id
    end
  end
end

local function play(race, class, side)
  side = side or SIDE[race] or "horde"
  local c = {
    guid = "Player-1-PLAY" .. race .. class, -- (each life its own: two of a race don't write alike)
    name = "Wanderer",
    race = race,
    class = class,
    faction = race == "Skyborne" and side or nil, -- (as the game reports it: the tradition follows it)
    began = { level = 1 },
    chapters = {},
  }
  local road = {}
  for _, z in ipairs(ROAD[race][side] or ROAD[race]) do
    table.insert(road, z)
  end
  for _, z in ipairs(FACTION[race] or (side == "alliance" and ALLIANCE or HORDE)) do
    table.insert(road, z)
  end
  local level, done, kinds = 1, {}, {}
  local chosen = {} -- (an exclusive group: the one quest of it taken)
  local zone = road[1]
  local at = zone -- (where I am: the quests' land, or an ender's far away)
  local clock, toLevel = 1790000000 + 8 * 3600, 0
  local ch, mates, grouped, told = nil, {}, false, 0
  local pet, petFamily, lessonLevel, powers, lastBeast = nil, nil, 0, {}, nil
  -- (an area's land: Coldridge Valley lies in Dun Morogh)
  local function landOf(id)
    for _ = 1, 4 do
      if not (D.parents or {})[id] then break end
      id = D.parents[id]
    end
    return id
  end
  local function zoneName(id) return D.zones[landOf(id)] or ("Zone " .. landOf(id)) end
  local function subName(id) return landOf(id) ~= id and D.zones[id] or nil end
  local function night()
    local h = math.floor(clock / 3600) % 24
    return h >= 21 or h < 6
  end
  local function newChapter()
    ch = {
      start = { level = level, zone = zoneName(at), sub = subName(at), night = night() or nil },
      log = {},
      kills = {},
      quests = 0,
      played = 0,
      gold = 0,
    }
    table.insert(c.chapters, ch)
  end
  local function moment(k, fields)
    fields = fields or {}
    if not fields.zone then
      fields.zone, fields.sub = zoneName(at), subName(at)
    end
    fields.k, fields.at, fields.night, fields.grouped = k, clock, night() or nil, grouped or nil
    table.insert(ch.log, fields)
    return fields
  end
  local function wait(seconds)
    clock = clock + seconds
    ch.played = ch.played + seconds
  end
  local function kill(cr, n, quarry)
    if not cr then return end
    if cr.rank == 2 or cr.rank == 4 then n = 1 end -- (a rare lives once)
    if FAMILY[cr.family or 0] then lastBeast = FAMILY[cr.family] end
    local first = ch.kills[cr.name] == nil
    ch.kills[cr.name] = (ch.kills[cr.name] or 0) + n
    wait(40 * n)
    local kind = kindOf(cr)
    if cr.rank == 2 or cr.rank == 4 then
      moment("rare", { name = cr.name, elite = cr.rank == 2 or nil })
    elseif first then
      moment("kill", {
        name = cr.name,
        kind = kind,
        first = kind and not kinds[kind] or nil,
        elite = cr.rank == 1 or nil,
        quarry = quarry or nil,
      })
    end
    if kind then kinds[kind] = true end
  end
  -- What the class gains at this level: the trainer's lessons, every other
  -- level; a warlock's demon, a druid's form, a hunter's first pet.
  local function classMoments()
    if level % 2 == 0 and level > lessonLevel then
      local spells = lessonsAt(class, race, lessonLevel + 1, level)
      lessonLevel = level
      if #spells > 0 then
        wait(120)
        moment("learned", { spells = spells })
      end
    end
    if class == "WARLOCK" then
      for _, d in ipairs(DEMONS) do
        if level >= d[1] and not powers[d[2]] then
          powers[d[2]] = true
          pet, petFamily = d[3], d[2]
          moment("demon", { name = d[3], family = d[2] })
        end
      end
    elseif class == "DRUID" then
      for _, f in ipairs(FORMS) do
        if level >= f[1] and not powers[f[2]] then
          powers[f[2]] = true
          moment("shift", { form = f[2] })
        end
      end
    elseif class == "SHAMAN" then
      for _, t in ipairs(TOTEMS) do
        local id = level >= t[1] and not powers[t[2]] and totemQuest(t[2], race, side)
        if id then
          powers[t[2]] = true
          local q = D.quests[id]
          local giver, ender = creature((q.starters or {})[1]), creature((q.enders or {})[1])
          wait(15 * 60)
          moment("quest", {
            id = id,
            title = q.title,
            giver = giver and giver.name,
            ender = (ender or giver) and (ender or giver).name,
            objectives = {},
          })
        end
      end
    elseif class == "HUNTER" and level >= 10 and not pet and lastBeast then
      pet, petFamily = PET_NAMES[(#c.chapters % #PET_NAMES) + 1], lastBeast
      moment("tame", { name = pet, family = petFamily })
    end
  end
  local function levelUp()
    level, toLevel = level + 1, 0
    moment("level", { level = level })
    classMoments()
  end
  -- (on the way to whoever takes a quest back, in another land, and home again)
  local function travel(to)
    if not to or to == at then return end
    local before = landOf(at)
    at = to
    wait(20 * 60)
    moment("place", landOf(to) ~= before and { new = "zone" } or {})
  end
  -- the first land on the road with a quest open now
  local function opens(z)
    for id, q in pairs(D.quests) do
      local prev = q.prev and math.abs(q.prev)
      if
        not done[id]
        and q.zone == z
        and (q.min or 1) <= level
        and (q.level or 1) <= level + 3
        and (not prev or done[prev])
        and not (q.exclusive and chosen[q.exclusive] and chosen[q.exclusive] ~= id)
        and playable(q, race, class, side)
      then
        return true
      end
    end
  end
  -- (a Skyborne leaves Zephras Isle on the skycutter: its quest done, or
  -- the island's work all done)
  local SKYCUTTER = { 94946, 95349 }
  local function grounded()
    if race ~= "Skyborne" then return false end
    for _, id in ipairs(SKYCUTTER) do
      if done[id] then return false end
    end
    return opens(road[1])
  end
  local function nextZone()
    for k, z in ipairs(road) do
      if k > 1 and grounded() then return nil end
      if opens(z) then return z end
    end
  end
  newChapter()
  while level <= TO do
    -- the quests open here, now: the lowest first, a few at a time
    local open = {}
    for id, q in pairs(D.quests) do
      local prev = q.prev and math.abs(q.prev)
      if
        not done[id]
        and q.zone == zone
        and (q.min or 1) <= level
        and (q.level or 1) <= level + 3
        and (not prev or done[prev])
        and not (q.exclusive and chosen[q.exclusive] and chosen[q.exclusive] ~= id)
        and playable(q, race, class, side)
      then
        table.insert(open, id)
      end
    end
    table.sort(open, function(a, b)
      local x, y = D.quests[a], D.quests[b]
      if x.level ~= y.level then return (x.level or 0) < (y.level or 0) end
      return a < b
    end)
    if #open == 0 then
      local z = nextZone()
      if z then
        local before = landOf(at)
        zone, at = z, z
        wait(15 * 60)
        moment("place", landOf(z) ~= before and { new = "zone" } or {})
      else
        -- nothing open anywhere: a level gained by fighting, as players do
        local here = {}
        for id, q in pairs(D.quests) do
          if done[id] and q.zone == zone then
            for _, t in ipairs(q.targets or {}) do
              table.insert(here, t[1])
            end
          end
        end
        kill(creature(here[#here]), 20)
        levelUp()
      end
    else
      local batch = {}
      for _, id in ipairs(open) do
        local group = D.quests[id].exclusive
        if #batch < 4 and not (group and chosen[group]) then
          table.insert(batch, id)
          if group then chosen[group] = id end
        end
      end
      local accepted = {}
      for _, id in ipairs(batch) do
        local q = D.quests[id]
        local giver = q.starters and creature(q.starters[1])
        accepted[id] = { giver = giver and giver.name, objectives = objectivesOf(q) }
        wait(60)
      end
      -- an elite to fight: company for it
      local elite = false
      for _, id in ipairs(batch) do
        for _, t in ipairs(D.quests[id].targets or {}) do
          if (creature(t[1]) or {}).rank == 1 then elite = true end
        end
      end
      if elite and not grouped then
        grouped = true
        local a, b = MATES[(told % #MATES) + 1], MATES[((told + 3) % #MATES) + 1]
        moment("group", { name = a })
        moment("group", { name = b })
      end
      for _, id in ipairs(batch) do
        local q, a = D.quests[id], accepted[id]
        wait(5 * 60)
        for k, t in ipairs(q.targets or {}) do
          -- (a creature to fight: the quest log's "slain", or its own words for a
          -- kill; "Peons Awoken", "Find Aamelia Windfield" fight no one)
          local own = q.texts[k] or ""
          if
            own == ""
            or own:lower():find("slain")
            or own:lower():find("killed")
            or own:lower():find("defeated")
            or own:lower():find("destroyed")
          then
            kill(creature(t[1]), t[2], own == "")
          end
        end
        for _, pair in ipairs(q.items or {}) do
          local s = D.sources[pair[1]]
          if q.src ~= pair[1] and s and s.creatures then
            -- the creature that drops it most widely (not a lone boss that happens
            -- to), in the quest's own land if one lives there
            local best
            for _, local_ in ipairs({ true, false }) do
              for _, cid in ipairs(s.creatures) do
                local cr = creature(cid)
                local here = not local_ or (cr and cr.zone and landOf(cr.zone) == landOf(q.zone))
                -- (elsewhere, never a creature far above the quest: no Maraudon elite for a well stone)
                local near = cr and (local_ or (cr.max or 0) <= (q.level or 60) + 10)
                if cr and here and near and cr.spawns > 0 and (not best or cr.spawns > best.spawns) then best = cr end
              end
              if best then break end
            end
            if best then
              kill(best, best.spawns > 1 and math.ceil(pair[2] * 1.5) or 1)
            else
              wait(math.floor(4 * 60 * pair[2] / 2))
            end
          elseif q.src ~= pair[1] then
            wait(math.floor(4 * 60 * pair[2] / 2))
          end
        end
        local held = a.objectives and a.objectives[1] and a.objectives[1].held
        -- (an escort or an event: no objective in the log, the game says when
        -- it is done, as Quests.lua hears it)
        -- (Forever's, no flag known: an escort or a rescue by its words)
        local escort = q.forever
          and #(q.targets or {}) == 0
          and #(q.items or {}) == 0
          and (q.objectives or ""):match("^%s*(%a+)")
        local verbs = { Escort = true, Protect = true, Defend = true, Guard = true, Help = true, Free = true }
        if (q.event or verbs[escort or ""]) and not a.objectives then
          wait(10 * 60)
          a.done = true
          moment("done", { id = id, title = q.title, giver = a.giver, pet = pet, petFamily = petFamily })
        elseif a.objectives and not held then
          a.done = true
          moment(
            "done",
            { id = id, title = q.title, giver = a.giver, objectives = a.objectives, pet = pet, petFamily = petFamily }
          )
        end
      end
      if grouped and not elite then grouped = false end
      -- back to who asked, each in turn
      wait(10 * 60)
      for _, id in ipairs(batch) do
        local q, a = D.quests[id], accepted[id]
        local ender = q.enders and creature(q.enders[1])
        -- (an ender in another land: the way there; not into the other
        -- side's own lands for one of Forever's; where the quest's own words
        -- put them, "Apothecary Lydon in Tarren Mill", over the data's zone)
        local where = ender and (placeNamed(q, ender) or ender.zone)
        local land = where and landOf(where)
        local foreign = q.forever
          and land
          and LANDS[side == "alliance" and "horde" or "alliance"][land]
          and not LANDS[side][land]
        if land and land ~= landOf(at) and D.zones[land] and not foreign then travel(where) end
        moment("quest", {
          id = id,
          title = q.title,
          giver = a.giver,
          ender = ender and ender.name,
          objectives = a.objectives,
          told = a.done or nil,
        })
        ch.quests, ch.gold = ch.quests + 1, ch.gold + (q.money or 0)
        done[id], told = true, told + 1
        for _, r in ipairs(q.rewards or {}) do
          local item = D.items[r]
          if
            item
            and (item.class == 2 or item.class == 4)
            and (item.slot or 0) > 0
            and (item.quality or 0) >= 2
            and usable(item, class, level)
          then
            moment("gear", {
              link = ("|cff1eff00|Hitem:%d|h[%s]|h|r"):format(r, item.name),
              quality = item.quality,
              held = item.class == 2 or (item.slot or 0) == 14 or (item.slot or 0) == 23 or nil,
              trinket = (item.slot or 0) == 12 or nil,
            }) -- a weapon, a shield
            -- (the weapon in hand, by its kind, as Life.lua hears it)
            local hand = item.class == 2 and ((class == "HUNTER") == (item.slot == 15 or item.slot == 26))
            if hand then moment("weapon", { weapon = item.sub }) end
            break
          end
        end
        toLevel = toLevel + 1
        if toLevel >= 4 + math.floor(level / 4) then levelUp() end
      end
      travel(zone) -- (back to the quests' land, if a turn-in took me away)
      -- a rest, now and then: the chapter closes
      if ch.played >= 9000 then
        ch.ended = { level = level, place = subName(at) or zoneName(at), how = "rest" }
        clock = clock + 9 * 3600
        newChapter()
      end
    end
  end
  return c
end

-- The people who give and take back quests: none named three times in a
-- paragraph (a second mention reads without the name).
local PEOPLE = {}
for _, q in pairs(D.quests) do
  for _, id in ipairs(q.starters or {}) do
    if D.creatures[id] then PEOPLE[D.creatures[id].name] = true end
  end
  for _, id in ipairs(q.enders or {}) do
    if D.creatures[id] then PEOPLE[D.creatures[id].name] = true end
  end
end
local function namedOnce(where, text)
  for paragraph in (text or ""):gmatch("[^\n]+") do
    local counts = {}
    for name in pairs(PEOPLE) do
      if #name > 3 and paragraph:find(name, 1, true) then
        -- (a possessive is an item's name, "Gazlowe's Ledger", not a mention)
        local _, n = paragraph:gsub(name:gsub("%p", "%%%0") .. "%f[^%w']", "")
        if n >= 3 then problem(where, name .. " named " .. n .. " times in a paragraph", paragraph) end
      end
    end
  end
end

os.execute("mkdir -p " .. BOOKS)
local books, chapters, quests = 0, 0, 0
for _, life in ipairs(LIVES) do
  local c = play(life[1], life[2], life[3])
  local book = ns.writeBook(c)
  books = books + 1
  local f = io.open(("%s/%s-%s.md"):format(BOOKS, life[1], life[2]:lower()), "w")
  f:write(("# %s %s, levels 1 to %d\n\n"):format(life[1], life[2]:lower(), c.chapters[#c.chapters].start.level))
  for _, ch in ipairs(book.chapters) do
    chapters = chapters + 1
    local where = ("%s %s chapter %d"):format(life[1], life[2], ch.number)
    inspect(where, ch.text)
    namedOnce(where, ch.text)
    local levels = ch.from == ch.to and ("level %d"):format(ch.from) or ("levels %d to %d"):format(ch.from, ch.to)
    if ch.open then levels = levels .. ", still being written" end
    f:write(("## %d. %s%s\n\n%s\n\n"):format(ch.number, ch.place and ch.place .. ", " or "", levels, ch.text or ""))
  end
  for _, ch in ipairs(c.chapters) do
    quests = quests + ch.quests
  end
  f:close()
end
io.write(("%d books, %d chapters, %d real quests played → %s/\n"):format(books, chapters, quests, BOOKS))
if #problems > 0 then
  io.write(table.concat(problems, "\n"), "\n")
  os.exit(1)
end
io.write("all good (playthroughs)\n")
