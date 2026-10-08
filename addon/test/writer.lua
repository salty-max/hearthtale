-- The writer test: writes the books of many imaginary lives (every race and
-- class, Hardcore or not, met at level 1 or mid-life) and checks every
-- chapter: slots all filled, sentences capitalised and closed, no stray
-- spaces or doubled words, every sentence of writing/ reachable, few repeats.
--   luajit addon/test/writer.lua            the checks
-- (a sample book, from a life played through the addon: addon/test/sample.lua)
local DIR = "addon/Hearthtale/"
local ns = {}
local forever = os.getenv("FOREVER") == "1"
assert(loadfile(DIR .. (forever and "Data_Forever.lua" or "Data_Classic.lua")))("Hearthtale", ns)
assert(loadfile(DIR .. "Names.lua"))("Hearthtale", ns)
dofile("addon/test/writer-files.lua")(ns, DIR)

-- A small random generator of our own, for the same lives on every machine.
local state = 12345
local function rand(a, b)
  state = (state * 1103515245 + 12345) % 2147483648
  if not a then return state / 2147483648 end
  if not b then
    a, b = 1, a
  end
  return a + math.floor(state / 65536) % (b - a + 1) -- the high bits: the low ones cycle
end
local function one(list) return list[rand(#list)] end
local function chance(p) return rand() < p end

-- ── what a life can hold (the original game's names) ─────────────────────────
local ZONES = {
  {
    "Dun Morogh",
    {
      "Coldridge Valley",
      "Anvilmar",
      "Kharanos",
      "Brewnall Village",
      "Shimmer Ridge",
      "Frostmane Hold",
      "Gol'Bolar Quarry",
    },
  },
  { "Ironforge", { "The Commons", "The Great Forge" } },
  { "Orgrimmar", { "Valley of Strength", "Valley of Honor" } },
  { "Darnassus", { "Temple of the Moon", "Tradesmen's Terrace" } },
  { "Undercity", { "The Trade Quarter", "The Apothecarium" } },
  { "Darkshore", { "Auberdine", "Cliffspring River", "Ruins of Mathystra" } },
  { "Silverpine Forest", { "The Sepulcher", "Pyrewood Village", "Ambermill" } },
  {
    "Elwynn Forest",
    {
      "Northshire Valley",
      "Goldshire",
      "Fargodeep Mine",
      "Jasperlode Mine",
      "Brackwell Pumpkin Patch",
      "Tower of Azora",
    },
  },
  { "Durotar", { "Valley of Trials", "Razor Hill", "Sen'jin Village", "Echo Isles", "Skull Rock" } },
  { "Mulgore", { "Camp Narache", "Bloodhoof Village", "Brambleblade Ravine", "The Venture Co. Mine" } },
  { "Tirisfal Glades", { "Deathknell", "Brill", "Agamand Mills", "Scarlet Watch Post" } },
  { "Teldrassil", { "Shadowglen", "Dolanaar", "Ban'ethil Barrow Den", "The Oracle Glade" } },
  { "Loch Modan", { "Thelsamar", "Stonewrought Dam", "The Farstrider Lodge", "Silver Stream Mine" } },
  { "The Barrens", { "The Crossroads", "Ratchet", "Camp Taurajo", "The Forgotten Pools", "Lushwater Oasis" } },
  { "Westfall", { "Sentinel Hill", "Moonbrook", "The Dagger Hills", "Saldean's Farm" } },
  { "Stormwind City", { "Trade District", "Dwarven District", "Old Town", "Cathedral Square" } },
  { "The Deadmines", { "Ironclad Cove" } },
  { "Stranglethorn Vale", { "Booty Bay", "Grom'gol Base Camp", "Nesingwary's Expedition", "Zul'Kunda" } },
  { "Ashenvale", { "Astranaar", "Splintertree Post", "Raynewood Retreat" } },
  { "Tanaris", { "Gadgetzan", "Steamwheedle Port", "Zalashji's Den" } },
  { "Eversong Woods", { "Sunstrider Isle", "Falconwing Square", "Fairbreeze Village" } },
  { "Azuremyst Isle", { "Ammen Vale", "Azure Watch", "Odesyus' Landing" } },
}
local CREATURES = {
  { "Ragged Young Wolf", "Wolf" },
  { "Rockjaw Trogg", "Humanoid" },
  { "Frostmane Novice", "Humanoid" },
  { "Kobold Vermin", "Humanoid" },
  { "Defias Thug", "Humanoid" },
  { "Mottled Boar", "Boar" },
  { "Plainstrider", "Tallstrider" },
  { "Rotting Dead", "Undead" },
  { "Young Nightsaber", "Cat" },
  { "Harvest Watcher", "Mechanical" },
  { "Venture Co. Laborer", "Humanoid" },
  { "Bloodfeather Harpy", "Humanoid" },
  { "Stranglethorn Raptor", "Raptor" },
  { "Mud Thresh", "Elemental" },
  { "Felstalker", "Demon" },
  { "Greater Duskbat", "Bat" },
  { "Servant of Arugal", "Undead" },
  { "Frostmane Shaman", "Humanoid" },
  { "Watchman", "Humanoid" },
  { "Thistle Cub", "Bear" },
  { "Swamp Jaguar", "Cat" },
  { "Black Dragon Whelp", "Dragonkin" },
  { "Hare", "Critter" },
}
local QUESTS = {
  "Dwarven Outfitters",
  "A New Threat",
  "The Troll Cave",
  "Beer Basted Boar Ribs",
  "Wolves Across the Border",
  "Lazy Peons",
  "The Defias Brotherhood",
  "Gnomeregan Glory",
  "The Bloodhoof Messenger",
  "Kobold Camp Cleanup",
  "Plainstrider Menace",
  "In Favor of the Light",
  "The Stolen Journal",
  "Fungus Among Us",
  "Hidden Enemies",
  "The Escape",
  "Ammo for Rumbleshot",
  "Raptor Mastery",
  "Down the Coast",
  "Mortality Wanes",
}
local GIVERS = {
  "Sten Stoutarm",
  "Marshal McBride",
  "Gornek",
  "Grull Hawkwind",
  "Magistrate Burnside",
  "Conservator Ilthalaine",
  "Rejold Barleybrew",
  "Gryan Stoutmantle",
  "Thrall",
  "Hemet Nesingwary",
}
local RARES =
  { "Timber", "Mangeclaw", "Hogger", "Rak'shiri", "Mother Fang", "Squiddic", "Lady Moongazer", "Gruff Swiftbite" }
local DUNGEONS = {
  { "The Deadmines", { "Rhahk'Zor", "Sneed", "Gilnid", "Mr. Smite", "Edwin VanCleef" } },
  { "Gnomeregan", { "Grubbis", "Viscous Fallout", "Mekgineer Thermaplugg" } },
  { "Blackfathom Deeps", { "Ghamoo-ra", "Twilight Lord Kelris", "Aku'mai" } },
  { "Ragefire Chasm", { "Taragaman the Hungerer", "Bazzalan" } },
  { "Wailing Caverns", { "Lady Anacondra", "Mutanus the Devourer" } },
  { "Shadowfang Keep", { "Rethilgore", "Baron Silverlaine", "Archmage Arugal" } },
  { "The Stockade", { "Bazil Thredd" } },
}
local THINGS = {
  "Head of VanCleef",
  "Tough Wolf Meat",
  "Crag Boar Rib",
  "Shimmerweed",
  "Gnoll Paw",
  "Grelin Whitebeard's Journal",
  "Scalding Mornbrew",
  "Kobold Candle",
  "Murloc Fin",
  "Red Bandana",
  "Linen Cloth",
}
local TASKS = {
  "Explore the Frostmane Hold",
  "Find the missing diplomat",
  "Light the signal fire",
  "Destroy the Defias plans",
  "Escort the caravan to the Crossroads",
}
local SPELLS = {
  "Blessing of Might",
  "Judgement",
  "Hammer of Justice",
  "Frostbolt",
  "Fireball",
  "Sinister Strike",
  "Shadow Word: Pain",
  "Lightning Bolt",
  "Corruption",
  "Serpent Sting",
  "Rejuvenation",
  "Battle Shout",
  "Rend",
  "Arcane Intellect",
}
local SKILLS = { "Mining", "Herbalism", "Skinning", "First Aid", "Blacksmithing", "Tailoring", "Cooking" }
local ITEMS = {
  "Wolf Fang Necklace",
  "Frostmane Leather Vest",
  "Cuirboulle Gloves",
  "Smite's Mighty Hammer",
  "Blackened Defias Armor",
  "Feline Mantle",
}
local POWERS = {
  form = { "Bear Form", "Cat Form", "Travel Form", "Aquatic Form" },
  demon = { "Summon Voidwalker", "Summon Succubus", "Summon Felhunter", "Inferno" },
  steed = { "Summon Warhorse", "Summon Charger" },
}
local PETS = { "Grrr", "Snapjaw", "Whisper", "Old Tom", "Bitey", "Fang", "Shadow", "Rusty", "Mossback", "Echo" }
local FAMILIES = { "Bear", "Wolf", "Cat", "Owl", "Crocolisk", "Boar" }
local MATES = { "Brannor", "Kelsa", "Thrudd", "Ylena", "Morgrim", "Aeris", "Zul'jin", "Brokk" }
local NODES = {
  "Ironforge, Dun Morogh",
  "Thelsamar, Loch Modan",
  "Stormwind, Elwynn",
  "Sentinel Hill, Westfall",
  "Orgrimmar, Durotar",
  "The Crossroads, The Barrens",
  "Booty Bay, Stranglethorn",
  "Gadgetzan, Tanaris",
}
local START = {
  Human = "Elwynn Forest",
  Dwarf = "Dun Morogh",
  Gnome = "Dun Morogh",
  NightElf = "Teldrassil",
  Draenei = "Azuremyst Isle",
  Orc = "Durotar",
  Troll = "Durotar",
  Tauren = "Mulgore",
  Scourge = "Tirisfal Glades",
  BloodElf = "Eversong Woods",
}
local function zoneNamed(name)
  for _, z in ipairs(ZONES) do
    if z[1] == name then return z end
  end
end
local COMBOS = {
  Human = { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
  Dwarf = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST" },
  NightElf = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "DRUID" },
  Gnome = { "WARRIOR", "ROGUE", "MAGE", "WARLOCK" },
  Draenei = { "WARRIOR", "PALADIN", "HUNTER", "PRIEST", "SHAMAN", "MAGE" },
  Orc = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "WARLOCK" },
  Troll = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE" },
  Tauren = { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" },
  Scourge = { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
  BloodElf = { "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
}

local CAUSES = { "foe", "foe", "foe", "foe", "fall", "drowning", "lava", "nature" }
local KINDS = { "Wolf", "Humanoid", "Undead", "Beast", "Boar", "Elemental", nil }
local RANKS = { "normal", "normal", "elite", "rare", "worldboss" }
local function death(n, zone, sub)
  local cause = one(CAUSES)
  local d = { level = n, zone = zone, sub = chance(0.8) and sub or nil, cause = cause }
  if cause == "foe" then
    if chance(0.15) then
      d.player, d.foe = true, one(MATES)
    else
      d.foe, d.kind, d.rank = chance(0.7) and one(CREATURES)[1] or nil, one(KINDS), one(RANKS)
    end
    d.inside = chance(0.15) or nil
  end
  return d
end

-- The races in a fixed order: pairs() would walk them differently on each run
-- (LuaJIT hashes strings with a random seed), and the lives with them.
local RACES = {}
if forever then
  COMBOS.Skyborne = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "MAGE", "DRUID" }
  START.Skyborne = "The Barrens"
end
for race in pairs(COMBOS) do
  table.insert(RACES, race)
end
table.sort(RACES)

local guid = 0
local function life(race, class, hc, from, to)
  guid = guid + 1
  local c = {
    guid = ("Player-1-%08X"):format(guid),
    name = one({ "Sealinedion", "Brannor", "Kelsa", "Thrudd", "Ylena", "Morgrim" }),
    race = race,
    class = class,
    hardcore = hc or nil,
    began = { level = from },
    chapters = {},
  }
  if race == "Skyborne" then
    c.faction = class == "SHAMAN" and "horde"
      or (class == "MAGE" and "alliance" or (guid % 2 == 0 and "alliance" or "horde"))
  end
  if from > 1 then
    c.prologue = {
      level = from,
      quests = chance(0.9) and rand(5, 200) or 0,
      inn = one({ "Goldshire", "Kharanos", "Brill", nil }),
      zone = one(ZONES)[1],
      played = chance(0.6) and rand(3000, 400000) or nil,
    }
  end
  local zone = from == 1 and zoneNamed(START[race] or "Elwynn Forest") or one(ZONES)
  local sub = zone[2][1]
  local seen, kinds, level, once = {}, {}, from, {}
  local clock, isNight = 1790000000, false
  local questId, returns = 0, {} -- quests whose work was told, not yet returned
  local grouped = false
  local function m(k, fields)
    fields = fields or {}
    clock = clock + (chance(0.15) and rand(3600, 10000) or rand(60, 900))
    if chance(0.15) then isNight = not isNight end
    if grouped and chance(0.1) then grouped = false end
    fields.k, fields.zone, fields.sub, fields.night, fields.at =
      k, fields.zone or zone[1], fields.sub or sub, isNight or nil, clock
    fields.grouped = grouped or nil
    return fields
  end
  while level <= to do
    local ch = {
      start = { level = level, zone = zone[1], sub = chance(0.85) and sub or nil, night = chance(0.35) or nil },
      log = {},
      kills = {},
      quests = 0,
      played = rand(600, 18000),
      gold = rand(0, 3) == 0 and 0 or rand(5, 40000),
    }
    local function add(x) table.insert(ch.log, x) end
    for _ = 1, rand(3, 22) do
      -- the returns to who asked, now and then, one or several in a row
      while #returns > 0 and chance(0.25) do
        add(m("quest", table.remove(returns, 1)))
      end
      local r = rand(118)
      local hunter = class == "HUNTER" and level >= 10
      if r > 100 then
        if r <= 103 then
          -- (its quality from its name: no draw of its own, so the rest of the
          -- book's chances stay as they were)
          local item = one(ITEMS)
          add(m("gear", {
            link = "|cff1eff00|Hitem:1|h[" .. item .. "]|h|r",
            quality = #item % 2 == 0 and 3 or 2,
            made = chance(0.3) or nil,
            held = chance(0.3) or nil,
          }))
        elseif r <= 105 then
          local learned = chance(0.4)
          add(m("prof", {
            name = one(SKILLS),
            learned = learned or nil,
            rank = not learned and one({ "apprentice", "journeyman", "expert", "artisan" }) or nil,
          }))
        elseif r == 106 then
          -- once in a life each, as the game records them
          local k = chance(0.5) and "riding" or "mount"
          if not once[k] then
            once[k] = true
            add(m(k, { name = "Apprentice Riding" }))
          end
        elseif r == 107 then
          local kind = ({ DRUID = "form", WARLOCK = "demon", PALADIN = "steed" })[class]
          local spell = kind and one(POWERS[kind])
          if spell and not once[spell] then
            once[spell] = true
            add(m("power", { spell = spell, kind = kind }))
          end
        elseif r <= 109 then
          local pet = one(PETS)
          if hunter and not once[pet] then
            once[pet] = true
            add(m("tame", { name = pet, family = chance(0.8) and one(FAMILIES) or nil }))
          end
        elseif r <= 111 then
          if hunter then add(m("petdied", { name = chance(0.9) and one(PETS) or nil })) end
        elseif r == 113 then
          -- the other side met in the open: one, or several in a few minutes
          local races = { "Human", "Orc", "NightElf", "Scourge", "Tauren", "Gnome", "Dwarf", "Troll" }
          local classes = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER", "WARLOCK" }
          for k = 1, one({ 1, 1, 2, 4 }) do
            local known = chance(0.75)
            local fight =
              m("pvp", { name = one(MATES), race = known and one(races) or nil, class = known and one(classes) or nil })
            if k > 1 then fight.at = ch.log[#ch.log].at + 60 end
            add(fight)
          end
        elseif r == 114 then
          -- a stretch at a craft
          for k = 1, rand(1, 4) do
            add(m("made", { link = "|cffffffff|Hitem:1|h[" .. one(THINGS) .. "]|h|r", n = rand(1, 12) }))
          end
        elseif r == 115 then
          if not hc then
            add(m("died", { death = death(level, zone[1], sub) }))
            local how = one({ "corpse", "corpse", "healer", "ally", "self" })
            add(m("revived", {
              how = how,
              by = how == "ally" and one(MATES) or nil,
              graveyard = chance(0.8) and one(zone[2]) or nil,
              took = rand(60, 900),
            }))
          end
        elseif r == 116 then
          add(m("group", { raid = one({ 10, 20, 40 }) }))
        else
          add(m("loot", { link = "|cff0070dd|Hitem:1|h[" .. one(ITEMS) .. "]|h|r", quality = 3 }))
        end
      elseif r <= 12 then
        if chance(0.25) then zone = one(ZONES) end
        sub = one(zone[2])
        if not seen[sub] then
          local newZone = not seen[zone[1]] or nil
          seen[sub], seen[zone[1]] = true, true
          add(m("place", { new = newZone and "zone" or nil }))
        end
      elseif r <= 32 then
        ch.quests = ch.quests + 1
        local o, roll = nil, rand(100)
        if roll <= 35 then
          o = { { type = "monster", name = one(CREATURES)[1], n = one({ 1, 6, 8, 10, 12, 15 }) } }
        elseif roll <= 65 then
          o = { { type = "item", name = one(THINGS), n = one({ 1, 1, 5, 6, 8, 10 }) } }
        elseif roll <= 72 then
          o = { { type = "event", text = one(TASKS) } }
        elseif roll <= 78 then -- a note in hand, to be delivered
          o = {
            { type = "item", name = one({ "Wiley's Note", "An Unsent Letter", "Sealed Report" }), n = 1, held = true },
          }
        end
        local q = {
          title = chance(0.95) and one(QUESTS) or nil,
          giver = chance(0.8) and one(GIVERS) or nil,
          ender = (chance(0.4) or (o and o[1].held)) and one(GIVERS) or nil,
          objectives = o,
        }
        if o and not o[1].held and chance(0.6) then
          -- its work done and told now; the return later (or right away)
          questId = questId + 1
          q.id, q.told, q.ender = questId, true, q.ender or one(GIVERS)
          add(m("done", { id = q.id, title = q.title, giver = q.giver, objectives = o }))
          if chance(0.3) then
            add(m("quest", q))
          else
            table.insert(returns, q)
          end
        else
          add(m("quest", q))
        end
      elseif r <= 52 then
        local cr = one(CREATURES)
        local n = rand(1, 12)
        if not ch.kills[cr[1]] then
          local first = not kinds[cr[2]] or nil
          kinds[cr[2]] = true
          add(
            m(
              "kill",
              { name = cr[1], kind = cr[2], first = first, elite = chance(0.08) or nil, quarry = chance(0.3) or nil }
            )
          )
        end
        ch.kills[cr[1]] = (ch.kills[cr[1]] or 0) + n
      elseif r <= 55 then
        add(m("rare", { name = one(RARES), elite = chance(0.3) or nil }))
      elseif r <= 60 then
        add(m("close", { foe = chance(0.8) and one(CREATURES)[1] or nil, hp = rand(1, 9) }))
      elseif r <= 63 then
        grouped = true -- the company stays a while
        add(m("group", { name = one(MATES), class = "WARRIOR" }))
      elseif r <= 66 then
        local d = one(DUNGEONS)
        add(m("dungeon", { name = d[1] }))
        for i = 1, rand(0, #d[2]) do
          add(m("boss", { name = d[2][i] }))
        end
      elseif r <= 70 then
        local spells, list = {}, {}
        for _ = 1, rand(1, 5) do
          local sp = one(SPELLS)
          if not spells[sp] then
            spells[sp] = true
            table.insert(list, sp)
          end
        end
        add(m("learned", { spells = list }))
      elseif r <= 72 then
        add(m("skill", { name = one(SKILLS), rank = one({ 50, 75, 100, 150, 200, 225, 250, 300 }) }))
      elseif r <= 76 then
        add(m("learned", { spells = { one(SPELLS) } }))
      elseif r <= 82 then
        if level < to then
          level = level + 1
          add(m("level", { level = level }))
        end
      elseif r <= 86 then
        add(m("campfire"))
      elseif r <= 90 then
        if chance(0.7) then
          add(m("night"))
        else
          add(m("rested", { place = one(zone[2]), fire = chance(0.3) or nil }))
        end
        clock = clock + 3600 -- (a real break: a relog of minutes isn't told)
        add(m("wake", { after = ch.log[#ch.log].k == "rested" and "rest" or "night" }))
      elseif r <= 92 then
        add(m("inn", { place = one(zone[2]) }))
      elseif r <= 95 then
        local a = rand(#NODES)
        add(m("flight", { from = NODES[a], to = NODES[a % #NODES + 1] }))
      elseif not hc and r <= 97 then
        add(m("died", { death = death(level, zone[1], sub) }))
      end
    end
    local lastOne = level >= to
    if lastOne and to >= 60 and chance(0.7) then
      -- the highest level: the journey's end
      ch.ended = { level = 60, zone = zone[1], sub = sub, place = one(zone[2]), how = "summit" }
      c.finished = true
    elseif not lastOne or chance(0.5) then
      local how = one({ "rest", "rest", "campfire", "long" })
      ch.ended = { level = level, zone = zone[1], sub = sub, place = one(zone[2]), how = how }
      if how == "long" then table.insert(ch.log, m("night", { last = true })) end
    end
    table.insert(c.chapters, ch)
    if lastOne then break end
    if not ch.ended then break end
    level = level + (chance(0.5) and 1 or 0)
    if level > to then break end
  end
  c.visited = {}
  for _, z in ipairs(ZONES) do
    if chance(0.3) then c.visited[z[1] .. "|"] = true end
  end
  -- Most Hardcore lives here end: a death closes the last chapter and the book.
  if hc and chance(0.7) then
    local last = c.chapters[#c.chapters]
    c.death = death(level, zone[1], sub)
    last.ended = { level = level, zone = zone[1], sub = sub, place = sub, how = "death" }
    c.closed = true
  end
  return c
end

-- ── the checks ───────────────────────────────────────────────────────────────
ns.writerUsed = {}
local problems, books, chapters, repeats, longest = {}, 0, 0, 0, 0
local longestText
local gaps = {} -- kind = the fewest uses of the kind between two uses of one of its sentences
local function problem(where, msg, text)
  if #problems < 20 then table.insert(problems, ("%s: %s\n    %s"):format(where, msg, text)) end
end
local routineTotal, remarkTotal, previousRemark = 0, 0, false
-- A remark is noticed when it comes back: none twice in a book's first ten chapters.
local remarkSeen, remarkEarly, remarkBooks = {}, 0, 0
local trackRemarks = false -- only in the lives below, as played
ns.writerRemark = function(id, chapter, book)
  if not trackRemarks then return end
  if remarkSeen._book ~= book then remarkSeen = { _book = book } end
  if chapter <= 10 and remarkSeen[id] then
    remarkEarly = remarkEarly + 1
    if os.getenv("WRITER_REMARKS") then io.stderr:write(id, " ", chapter, "\n") end
  end
  remarkSeen[id] = true
end
ns.writerSentence = function(text, routine, remarks, _, highlight)
  routineTotal, remarkTotal = routineTotal + routine, remarkTotal + remarks
  if remarks > 1 then problem("remark budget", "two remarks shared a sentence", text) end
  if previousRemark and remarks > 0 and not highlight then
    problem("remark budget", "successive sentences carried routine remarks", text)
  end
  previousRemark = remarks > 0
end
local inspect = dofile("addon/test/inspect.lua")(problem)

-- The joins serve a scene: related practice stays together, an arrival
-- frames one action, and a close call has an aftermath. Use one candidate
-- per kind here so these checks concern assembly rather than word choice.
local originalData, originalUsed = ns.data, ns.writerUsed
local fixtureWriting = {}
for kind, list in pairs(ns.data.writing) do
  if not kind:find("^r%-") then fixtureWriting[kind] = list end -- no remarks: these check the joins
end
local lines = {
  beginning = "I began {at}.",
  ["c-prof"] = "took up {prof}",
  ["c-place"] = "reached {place}",
  ["c-kill"] = "brought down {foe}",
  ["c-deed-kill"] = "killed {n} {foes} for {giver}",
  ["close-deep"] = "{foe} nearly ended me {at}. I was glad to survive.",
  ["c-deed-item"] = "found {n} {thing}",
}
for kind, line in pairs(lines) do
  fixtureWriting[kind] = { { line } }
end
ns.data, ns.writerUsed = { writing = fixtureWriting }, nil
local recorded = {
  guid = "scene-joins",
  race = "Human",
  class = "MAGE",
  chapters = {
    {
      start = { level = 1, zone = "Country", sub = "Home" },
      log = {
        { k = "prof", name = "Skinning", learned = true, zone = "Country", sub = "Home", at = 10 },
        { k = "prof", name = "Leatherworking", learned = true, zone = "Country", sub = "Home", at = 20 },
        { k = "place", zone = "Country", sub = "Farm", at = 30 },
        { k = "kill", name = "Wolf", kind = "Beast", zone = "Country", sub = "Farm", at = 40 },
        {
          k = "quest",
          giver = "Farmer",
          objectives = { { type = "monster", name = "Wolf", n = 2 } },
          zone = "Country",
          sub = "Farm",
          at = 50,
        },
        { k = "close", foe = "Wolf", hp = 2, zone = "Country", sub = "Farm", at = 60 },
        {
          k = "quest",
          objectives = { { type = "item", name = "Apple", n = 3 } },
          zone = "Country",
          sub = "Farm",
          at = 70,
        },
      },
    },
  },
}
local sceneText = ns.writeBook(recorded).chapters[1].text
if not sceneText:find("I took up skinning and took up leatherworking.", 1, true) then
  problem("scene joins", "related trades were split", sceneText)
end
if sceneText:find("leatherworking and brought down", 1, true) then
  problem("scene joins", "a trade and a fight were forced together", sceneText)
end
local framed = sceneText:find("When I reached the Farm, I brought down a Wolf.", 1, true)
  or sceneText:find("I reached the Farm, where I brought down a Wolf.", 1, true)
  or sceneText:find("I reached the Farm and brought down a Wolf.", 1, true)
if not framed then problem("scene joins", "the arrival did not frame its action", sceneText) end
if
  not (
    sceneText:find("Afterwards, I found three Apples.", 1, true)
    or sceneText:find("After that encounter, I found three Apples.", 1, true)
  )
then
  problem("scene joins", "the next action lost the close call's aftermath", sceneText)
end
if sceneText ~= ns.writeBook(recorded).chapters[1].text then
  problem("scene joins", "the same record produced different prose", sceneText)
end
-- A compound action must survive both the arrival frame and an ordinary
-- join, without three competing uses of "and" in the same thought.
fixtureWriting["c-kill"] = { { "stood against {foe} and prevailed" } }
fixtureWriting["c-deed-kill"] = { { "dealt with {n} {foes} and finished the work" } }
local compoundText = ns.writeBook(recorded).chapters[1].text
if
  compoundText:find("I reached the Farm and stood against", 1, true)
  or compoundText:find("prevailed and dealt with", 1, true)
then
  problem("scene joins", "a compound thought gained a competing conjunction", compoundText)
end
inspect("compound scene joins", compoundText)
local ordinaryCompound = ns.writeBook({
  guid = "ordinary-compound",
  race = "Human",
  class = "MAGE",
  chapters = {
    {
      start = { level = 1, zone = "Country", sub = "Home" },
      log = {
        -- (another creature than the quest's: a kill the quest counts is told by it)
        { k = "kill", name = "Boar", kind = "Beast", zone = "Country", sub = "Home", at = 10 },
        {
          k = "quest",
          giver = "Farmer",
          objectives = { { type = "monster", name = "Wolf", n = 2 } },
          zone = "Country",
          sub = "Home",
          at = 20,
        },
      },
    },
  },
}).chapters[1].text
if not ordinaryCompound:find("prevailed; I dealt with", 1, true) then
  problem("scene joins", "ordinary compound actions lost their grammatical join", ordinaryCompound)
end
ns.data, ns.writerUsed = originalData, originalUsed

-- Exercise the reported joins independently of the prose lottery. The
-- third clause has an internal comma, but the preceding pair still needs
-- its own conjunction before the semicolon.
ns.data, ns.writerUsed = { writing = fixtureWriting }, nil
fixtureWriting["c-first"] = { { "had my first taste of fighting {kind}" } }
fixtureWriting["c-kill"] = { { "killed {foe}" } }
fixtureWriting["c-deed-item"] = { { "brought {giver} {n} {thing}" } }
fixtureWriting["c-gear"] = { { "began using {item}, which I had made myself" } }
fixtureWriting["c-inn"] = { { "bound my hearthstone {inn}" } }
local tripleSeen, orcTripleSeen = false, false
for seed = 1, 40 do
  local c = {
    guid = "joins-" .. seed,
    race = "Human",
    class = "HUNTER",
    chapters = {
      {
        start = { level = 20, zone = "Country", sub = "Home" },
        log = {
          { k = "kill", kind = "Boar", name = "Boar", sub = "Home", zone = "Country" },
          {
            k = "quest",
            giver = "Ragnar",
            sub = "Home",
            zone = "Country",
            objectives = { { type = "item", name = "Crag Boar Rib", n = 6 } },
          },
          { k = "gear", made = true, link = "item:1:[Leather Vest]", sub = "Home", zone = "Country" },
        },
      },
    },
  }
  local text = ns.writeBook(c).chapters[1].text
  if text:find("a Boar, brought Ragnar", 1, true) then
    problem("three clauses", "a final conjunction was lost before a semicolon", text)
  end
  if text:find("a Boar and brought Ragnar six Crag Boar Ribs; I began using", 1, true) then tripleSeen = true end
  c.race = "Orc"
  text = ns.writeBook(c).chapters[1].text
  if text:find("a Boar and brought Ragnar six Crag Boar Ribs; I began using", 1, true) then orcTripleSeen = true end
  c.chapters[1].log = {
    { k = "place", sub = "Ratchet", zone = "Country" },
    { k = "inn", place = "Ratchet", sub = "Ratchet", zone = "Country" },
  }
  text = ns.writeBook(c).chapters[1].text
  local _, townNames = text:gsub("Ratchet", "")
  if townNames ~= 1 or text:find("where I bound my hearthstone there", 1, true) then
    problem("hearthstone join", "the town was named twice or both where and there were used", text)
  end
  c.chapters[1].log[2].place = "Broken Keel Tavern"
  text = ns.writeBook(c).chapters[1].text
  if not text:find("Broken Keel Tavern", 1, true) then
    problem("hearthstone join", "a distinct inn name disappeared", text)
  end
end
if not tripleSeen then problem("three clauses", "the three-part join was not exercised", "") end
if not orcTripleSeen then problem("orc flow", "the orc lost the ability to carry three related clauses", "") end
local tame = {
  guid = "tame-once",
  race = "Human",
  class = "HUNTER",
  chapters = {
    {
      start = { level = 10, zone = "Country", sub = "Farm" },
      log = {
        { k = "quest", objectives = { { text = "Tame a Large Crag Boar" } }, zone = "Country", sub = "Farm" },
        { k = "tame", name = "Bristle", family = "Boar", zone = "Country", sub = "Farm" },
      },
    },
  },
}
local tameText = ns.writeBook(tame).chapters[1].text
if tameText:find("Large Crag Boar", 1, true) or not tameText:find("Bristle", 1, true) then
  problem("taming", "the objective competed with the pet's introduction", tameText)
end
tame.chapters[1].log[1].title = "Taming the Beast"
tame.chapters[1].log[1].objectives[1].text = "Large Crag Boar tamed"
tameText = ns.writeBook(tame).chapters[1].text
if tameText:find("Taming the Beast", 1, true) or not tameText:find("Bristle", 1, true) then
  problem("taming", "a completed objective repeated the pet through its quest title", tameText)
end
for _, case in ipairs({
  { "Frostmane Hold", "Explore the Frostmane Hold", "explore Frostmane Hold" },
  { "The Barrens", "Explore the Barrens", "explore the Barrens" },
  { "Farm", "Explore the tunnels", "explore the tunnels" },
}) do
  local c = {
    guid = "objective-article",
    race = "Human",
    class = "MAGE",
    chapters = {
      {
        start = { level = 10, zone = "Country", sub = case[1] },
        log = {
          { k = "quest", objectives = { { text = case[2] } }, zone = "Country", sub = case[1] },
        },
      },
    },
  }
  fixtureWriting["c-deed-task"] = { { "managed to {task}" } }
  local text = ns.writeBook(c).chapters[1].text
  if not text:find(case[3], 1, true) then
    problem("objective article", "an article was lost or added to the recorded name", text)
  end
  if case[1] == "Frostmane Hold" then
    c.chapters[1].log = {
      { k = "place", zone = "Country", sub = "Home" },
      { k = "quest", zone = "Country", sub = "Home", objectives = { { text = case[2] } } },
    }
    text = ns.writeBook(c).chapters[1].text
    if not text:find(case[3], 1, true) then
      problem("objective article", "turning in elsewhere lost the explored place's name", text)
    end
  end
end
ns.data, ns.writerUsed = originalData, originalUsed

-- Lessons must agree with a single spell or a list, throughout every voice.
for _, race in ipairs(RACES) do
  for seed = 1, 40 do
    for _, spells in ipairs({ { "Mend Pet" }, { "Concussive Shot", "Mend Pet" } }) do
      local c = {
        guid = "spell-agreement-" .. seed,
        race = race,
        class = "HUNTER",
        chapters = {
          {
            start = { level = 20, zone = "Country", sub = "Home" },
            log = {
              { k = "prof", name = "Tailoring", learned = true, zone = "Country", sub = "Home" },
              { k = "learned", spells = spells, zone = "Country", sub = "Home" },
            },
          },
        },
      }
      local text = ns.writeBook(c).chapters[1].text
      if
        not text:find("Mend Pet", 1, true)
        or (#spells > 1 and not text:find("Concussive Shot and Mend Pet", 1, true))
        or text:find("proper use of it", 1, true)
      then
        problem("spell agreement", "a lesson lost a spell or used a singular pronoun for a list", text)
      end
      -- (its remark too: "Concussive Shot and Mend Pet, my choice to learn it")
      local after = #spells > 1 and text:match("Mend Pet, ([^.;]*)")
      local OBJECT = {
        learn = true,
        try = true,
        test = true,
        use = true,
        improve = true,
        master = true,
        to = true,
        of = true,
        find = true,
      }
      for verb in (after or ""):gmatch("(%a+) it%f[%A]") do
        if OBJECT[verb] then problem("spell agreement", 'a remark said "it" after several spells', text) end
      end
    end
  end
end

-- A creature named once: a kill, the quest that counts it, a close call
-- against it ("I brought down a Brigand. I put down five more. One of them
-- nearly ended me."), never its name three times over.
for _, race in ipairs(RACES) do
  for seed = 1, 12 do
    local c = {
      guid = "named-once-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      began = { level = 20 },
      chapters = {
        {
          start = { level = 20, zone = "The Barrens", sub = "Ratchet" },
          kills = {},
          quests = 0,
          played = 100,
          gold = 0,
          log = {
            { k = "place", zone = "The Barrens", sub = "The Merchant Coast", at = 100 },
            {
              k = "kill",
              name = "Southsea Brigand",
              kind = "Humanoid",
              zone = "The Barrens",
              sub = "The Merchant Coast",
              at = 200,
            },
            {
              k = "quest",
              giver = "Wharfmaster Dizzywig",
              objectives = { { type = "monster", name = "Southsea Brigand", n = 6 } },
              zone = "The Barrens",
              sub = "The Merchant Coast",
              at = 300,
            },
            {
              k = "close",
              foe = "Southsea Brigand",
              hp = 4,
              zone = "The Barrens",
              sub = "The Merchant Coast",
              at = 400,
            },
          },
        },
      },
    }
    local text = ns.writeBook(c).chapters[1].text
    local _, names = text:gsub("Southsea Brigand", "")
    if names > 1 then problem(race .. " named once", "a creature named again and again", text) end
  end
end

-- Every place described, entered by day and by night by each race (at home,
-- among allies, among foes): each description reachable, and checked.
for place, p in pairs(ns.data.scenery or {}) do
  for _, race in ipairs(RACES) do
    for seed = 1, 4 do
      local night = seed % 2 == 0 or nil
      local m = p.type == "dungeon" and { k = "dungeon", name = place, night = night, at = 100 }
        or p.type == "town" and { k = "place", new = "zone", zone = "Somewhere", sub = place, night = night, at = 100 }
        or { k = "place", new = "zone", zone = place, night = night, at = 100 }
      local c = {
        guid = "scenery-" .. place .. race .. seed,
        race = race,
        class = COMBOS[race][1],
        began = { level = 30 },
        chapters = {
          {
            start = { level = 30, zone = "Elsewhere", sub = "Elsewhere" },
            kills = {},
            quests = 0,
            played = 100,
            gold = 0,
            log = { m },
          },
        },
      }
      inspect(race .. " scenery " .. place, ns.writeBook(c).chapters[1].text)
    end
  end
end

-- Every race, class and hardcore pairing through an inn and a fighting
-- recap: the lines kept for one class or for hardcore all reachable.
for _, race in ipairs(RACES) do
  for _, class in ipairs(COMBOS[race]) do
    for _, hc in ipairs({ true, false }) do
      for seed = 1, 3 do
        -- (eight chapters: the race's own lines come first, the shared after)
        local chapters = {}
        for n = 1, 8 do
          chapters[n] = {
            start = { level = 20, zone = "Country", sub = "Home" },
            quests = 0,
            played = 3600,
            gold = 0,
            kills = { Wolf = n % 2 == 0 and 24 or 12 },
            log = { -- (a long fight, and a short)
              { k = "kill", name = "Wolf", kind = "Wolf", sub = "Home", zone = "Country", at = 50 },
              { k = "inn", place = "Home", sub = "Home", zone = "Country", at = 100 },
            },
            ended = { level = 20, place = "Home", how = "rest" },
          }
        end
        local c = {
          guid = "pairing-" .. race .. class .. tostring(hc) .. seed,
          race = race,
          class = class,
          hardcore = hc or nil,
          began = { level = 20 },
          chapters = chapters,
        }
        for _, ch in ipairs(ns.writeBook(c).chapters) do
          inspect(race .. " " .. class .. " pairing", ch.text)
        end
      end
    end
  end
end

-- A start the game had not placed yet (Forever, at login), the place told
-- seconds later: the chapter opens there, with no arrival.
for _, race in ipairs(RACES) do
  local c = {
    guid = "late-start-" .. race,
    race = race,
    class = COMBOS[race][1],
    began = { level = 1 },
    chapters = {
      {
        start = { at = 100, level = 1 },
        log = {
          { k = "place", zone = "Dun Morogh", sub = "Coldridge Valley", new = "zone", at = 107 },
          {
            k = "kill",
            name = "Ragged Young Wolf",
            kind = "Wolf",
            zone = "Dun Morogh",
            sub = "Coldridge Valley",
            at = 200,
          },
        },
      },
    },
  }
  local text = ns.writeBook(c).chapters[1].text
  inspect(race .. " late start", text)
  local _, named = text:gsub("Coldridge Valley", "")
  if
    named ~= 1
    or not text:find("Coldridge Valley", 1, true)
    or text:find("into Coldridge")
    or text:find("to Coldridge")
  then
    problem(race .. " late start", "the start told as an arrival", text)
  end
end

-- Forever's surnames: the people met go by their first name in the journal.
for _, race in ipairs(RACES) do
  local c = {
    guid = "surnames-" .. race,
    race = race,
    class = COMBOS[race][1],
    name = "Hellefie Namzar",
    began = { level = 10 },
    chapters = {
      {
        start = { level = 10, zone = "Dun Morogh", sub = "Kharanos" },
        log = {
          {
            k = "group",
            name = "Harrysaun Brightwood",
            first = "Harrysaun",
            class = "PALADIN",
            zone = "Dun Morogh",
            sub = "Kharanos",
            at = 100,
          },
          {
            k = "pvp",
            name = "Grukk Ashmane",
            first = "Grukk",
            race = "Orc",
            class = "WARRIOR",
            zone = "Dun Morogh",
            sub = "Kharanos",
            at = 2000,
          },
        },
      },
    },
  }
  local text = ns.writeBook(c).chapters[1].text
  inspect(race .. " surnames", text)
  if text:find("Brightwood") or text:find("Ashmane") or not text:find("Harrysaun") or not text:find("Grukk") then
    problem(race .. " surnames", "the people met not by their first name", text)
  end
end

-- A quest's work handed in on the spot (its turn-in next, same place): told
-- once, at the turn-in, with whom it was for. Apart (a journey between): the
-- work where it was done, the return later.
for _, race in ipairs(RACES) do
  for seed = 1, 8 do
    local kind = seed % 2 == 0 and { type = "monster", name = "Rockjaw Trogg", n = seed % 4 == 0 and 1 or 6 }
      or { type = "item", name = "Tough Wolf Meat", n = seed % 3 == 0 and 1 or 8 }
    local function at(t, sub) return { zone = "Dun Morogh", sub = sub or "Coldridge Valley", at = t } end
    local function m(t, fields, sub)
      local x = at(t, sub)
      for k, v in pairs(fields) do
        x[k] = v
      end
      return x
    end
    local spot = {
      guid = "handed-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      began = { level = 2 },
      chapters = {
        {
          start = { level = 2, zone = "Dun Morogh", sub = "Coldridge Valley" },
          log = {
            m(100, { k = "done", id = 179, giver = "Sten Stoutarm", objectives = { kind } }),
            m(110, { k = "level", level = 3 }),
            m(120, {
              k = "quest",
              id = 179,
              told = true,
              giver = "Sten Stoutarm",
              ender = "Sten Stoutarm",
              objectives = { kind },
            }),
          },
        },
      },
    }
    local text = ns.writeBook(spot).chapters[1].text
    inspect(race .. " handed on the spot", text)
    local _, sten = text:gsub("Sten Stoutarm", "")
    if sten ~= 1 then
      problem(race .. " handed on the spot", "the work and the hand-in not told once, with whom", text)
    end
    local apart = {
      guid = "apart-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      began = { level = 2 },
      chapters = {
        {
          start = { level = 2, zone = "Dun Morogh", sub = "Coldridge Valley" },
          log = {
            m(100, { k = "done", id = 179, giver = "Sten Stoutarm", objectives = { kind } }),
            m(200, { k = "place", zone = "Dun Morogh", sub = "Anvilmar" }, "Anvilmar"),
            m(300, {
              k = "quest",
              id = 179,
              told = true,
              giver = "Sten Stoutarm",
              ender = "Sten Stoutarm",
              objectives = { kind },
            }, "Anvilmar"),
          },
        },
      },
    }
    text = ns.writeBook(apart).chapters[1].text
    inspect(race .. " handed apart", text)
    if
      not text:find("Sten Stoutarm", 1, true) or not (text:find("Wolf Meat", 1, true) or text:find("Trogg", 1, true))
    then
      problem(race .. " handed apart", "the work or the return lost", text)
    end
  end
end

-- A relog (a night and its waking minutes apart): no night told. A night
-- indoors without an inn, and its waking, and a long stretch ending indoors.
for _, race in ipairs(RACES) do
  for seed = 1, 6 do
    local function m(t, fields)
      fields.zone, fields.sub, fields.at = "Dun Morogh", "Anvilmar", t
      return fields
    end
    local c = {
      guid = "nights-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      hardcore = seed % 3 == 0 or nil,
      began = { level = 2 },
      chapters = {
        {
          start = { level = 2, zone = "Dun Morogh", sub = "Anvilmar" },
          played = 4 * 3600 + 60,
          log = {
            m(100, { k = "kill", name = "Ragged Young Wolf", kind = "Wolf" }),
            m(200, { k = "night" }),
            m(300, { k = "wake", after = "night" }),
            m(400, { k = "kill", name = "Rockjaw Trogg", kind = "Humanoid" }),
            m(500, { k = "night", inside = true, night = seed % 2 == 0 or nil }),
            m(9000, { k = "wake", after = "night", inside = true, night = seed % 2 == 0 or nil }),
            m(9100, { k = "kill", name = "Small Crag Boar", kind = "Boar" }),
            m(9200, { k = "night", last = true, inside = true }),
          },
          ended = { level = 2, zone = "Dun Morogh", sub = "Anvilmar", place = "Anvilmar", how = "long", inside = true },
        },
      },
    }
    local text = ns.writeBook(c).chapters[1].text
    inspect(race .. " nights", text)
  end
end

-- An objective recorded with a number for its name (0.5.0's recorder read
-- "0/8 Tough Wolf Meat" the wrong way round): never written ("eight 0s").
for _, race in ipairs(RACES) do
  for seed = 1, 6 do
    local o = { { type = seed % 2 == 0 and "item" or "monster", name = seed % 3 == 0 and " " or "0", n = 8 } }
    local c = {
      guid = "numbered-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      chapters = {
        {
          start = { level = 2, zone = "Dun Morogh", sub = "Coldridge Valley" },
          log = {
            {
              k = "done",
              id = 179,
              giver = "Sten Stoutarm",
              objectives = o,
              zone = "Dun Morogh",
              sub = "Coldridge Valley",
              at = 100,
            },
            {
              k = "quest",
              id = 179,
              told = true,
              giver = "Sten Stoutarm",
              ender = "Sten Stoutarm",
              objectives = o,
              zone = "Dun Morogh",
              sub = "Coldridge Valley",
              at = 200,
            },
          },
        },
      },
    }
    local text = ns.writeBook(c).chapters[1].text
    inspect(race .. " numbered objective", text)
    if text:find(" 0s") or text:find(" 0[ ,.;]") then
      problem(race .. " numbered objective", "a number told as a name", text)
    end
  end
end

-- Each people and kind of foe, and each kind of find, fought and found over
-- a few chapters by every race: the remarks about them all reachable.
local SUBJECT_FOES = {
  { "Murloc Raider", "Humanoid" },
  { "Kobold Vermin", "Humanoid" },
  { "Riverpaw Gnoll", "Humanoid" },
  { "Bloodfeather Harpy", "Humanoid" },
  { "Razormane Quilboar", "Humanoid" },
  { "Kolkar Drudge", "Humanoid" },
  { "Boulderfist Ogre", "Humanoid" },
  { "Witherbark Troll", "Humanoid" },
  { "Slitherblade Naga", "Humanoid" },
  { "Hatefury Satyr", "Humanoid" },
  { "Timbermaw Warrior", "Humanoid" },
  { "Rockjaw Trogg", "Humanoid" },
  { "Defias Thug", "Humanoid" },
  { "Scarlet Crusader", "Humanoid" },
  { "Rotting Dead", "Undead" },
  { "Felguard", "Demon" },
  { "Rock Elemental", "Elemental" },
  { "Black Whelp", "Dragonkin" },
  { "Webwood Spider", "Spider" },
}
local SUBJECT_THINGS = {
  "Silithid Egg",
  "Harpy Feather",
  "Fine Moonstalker Pelt",
  "Worn Parchment",
  "Earthroot",
  "Blood Shard",
  "Mathystra Relic",
  "Gnoll Paw",
}
for _, race in ipairs(RACES) do
  for f, foe in ipairs(SUBJECT_FOES) do
    local chapters = {}
    for n = 1, 8 do
      local thing = SUBJECT_THINGS[(f + n) % #SUBJECT_THINGS + 1]
      -- (the find first: one remark a sentence, and the fight's would take it)
      local log = {
        {
          k = "quest",
          giver = "Ragnar",
          sub = "Home",
          zone = "Country",
          at = 50,
          objectives = { { type = "item", name = thing, n = n % 2 == 0 and 1 or 6 } },
        },
      }
      for i = 1, 3 do
        log[i + 1] = { k = "kill", name = foe[1], kind = foe[2], sub = "Home", zone = "Country", at = i * 100 }
      end
      log[5] = {
        k = "quest",
        giver = "Ragnar",
        sub = "Home",
        zone = "Country",
        at = 400,
        objectives = { { type = "monster", name = foe[1], n = n % 3 == 0 and 1 or 6 } },
      }
      chapters[n] = { start = { level = 30, zone = "Country", sub = "Home" }, log = log }
    end
    local c = { guid = "subjects-" .. race .. f, race = race, class = COMBOS[race][1], chapters = chapters }
    for _, ch in ipairs(ns.writeBook(c).chapters) do
      inspect(race .. " subjects " .. foe[1], ch.text)
    end
  end
end

-- The journey's end at the highest level, for every race's own lines.
for _, race in ipairs(RACES) do
  for seed = 1, 12 do
    local c = {
      guid = "summit-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      began = { level = 59 },
      finished = true,
      chapters = {
        {
          start = { level = 59, zone = "Winterspring", sub = "Everlook" },
          kills = {},
          quests = 0,
          played = 100,
          gold = 0,
          log = {
            {
              k = "kill",
              name = "Winterfall Ursa",
              kind = "Humanoid",
              zone = "Winterspring",
              sub = "Everlook",
              at = 100,
            },
          },
          ended = { level = 60, zone = "Winterspring", sub = "Everlook", place = "Everlook", how = "summit" },
        },
      },
    }
    inspect(race .. " summit", ns.writeBook(c).chapters[1].text)
  end
end

-- Routine hand-ins past a scene's first two fold into one clause, told
-- when the next thing happens: every mix of errands and green gear, and
-- nobody from the folded ones named.
for _, race in ipairs(RACES) do
  for seed = 1, 36 do
    local errands, gear = ({ 0, 1, 3 })[seed % 3 + 1], ({ 0, 1, 2 })[math.floor(seed / 3) % 3 + 1]
    local log, at = {}, 100
    local function add(m)
      at = at + 100
      m.zone, m.sub, m.at = "Silverpine Forest", "The Sepulcher", at
      table.insert(log, m)
    end
    local function deliver(ender, thing)
      add({ k = "quest", ender = ender, objectives = { { type = "item", name = thing, n = 1, held = true } } })
    end
    deliver("High Executor Hadrec", "Sealed Report")
    deliver("Magistrate Sevren", "Wiley's Note")
    for i = 1, errands do
      deliver("Folded Person " .. i, "Folded Thing " .. i)
    end
    for i = 1, gear do
      add({ k = "gear", quality = 2, link = "item:1:[Folded Gear " .. i .. "]" })
    end
    add({ k = "kill", name = "Rot Hide Gnoll", kind = "Humanoid" })
    local c = {
      guid = "fold-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      began = { level = 20 },
      chapters = {
        {
          start = { level = 20, zone = "Silverpine Forest", sub = "The Sepulcher" },
          kills = {},
          quests = 0,
          played = 100,
          gold = 0,
          log = log,
        },
      },
    }
    local text = ns.writeBook(c).chapters[1].text
    inspect(race .. " fold", text)
    if text:find("Folded") then problem(race .. " fold", "a folded hand-in named", text) end
    if
      errands + gear > 0
      and not text:find("gear")
      and not text:find("errand")
      and not text:find("job")
      and not text:find("task")
    then
      problem(race .. " fold", "folded hand-ins never told", text)
    end
  end
end

-- A thing carried from one to the next ("I carried Deliah's Ring to Hadrec,
-- took it on to Sevren"), or handed over twice to the same person: named once.
for _, race in ipairs(RACES) do
  for seed = 1, 24 do
    local function deliver(ender, at, thing)
      return {
        k = "quest",
        ender = ender,
        objectives = { { type = "item", name = thing or "Deliah's Ring", n = 1, held = true } },
        zone = "Silverpine Forest",
        sub = "The Sepulcher",
        at = at,
      }
    end
    local c = {
      guid = "carried-on-" .. race .. seed,
      race = race,
      class = COMBOS[race][1],
      began = { level = 20 },
      chapters = {
        {
          start = { level = 20, zone = "Silverpine Forest", sub = "The Sepulcher" },
          kills = {},
          quests = 0,
          played = 100,
          gold = 0,
          log = seed % 3 == 0 and {
            deliver("High Executor Hadrec", 100),
            deliver("Magistrate Sevren", 200),
            deliver("Raleigh Andrean", 300),
          } or seed % 3 == 1 and {
            deliver("High Executor Hadrec", 100),
            deliver("High Executor Hadrec", 200),
            deliver("Magistrate Sevren", 300),
          } or {
            deliver("High Executor Hadrec", 100),
            deliver("High Executor Hadrec", 200, "Wiley's Note"),
            deliver("Magistrate Sevren", 300, "Sealed Report"),
          },
        },
      },
    }
    local text = ns.writeBook(c).chapters[1].text
    inspect(race .. " carried on", text)
    local _, rings = text:gsub("Deliah's Ring", "")
    local _, hadrec = text:gsub("Hadrec", "")
    if rings > 1 or hadrec > 1 then
      problem(race .. " carried on", "a thing or a person named again and again", text)
    end
  end
end

-- Repeated journeys exercise return wording as well as one-off arrivals.
for _, race in ipairs(RACES) do
  local log = {}
  for i = 1, 100 do
    log[i] = { k = "place", sub = i % 2 == 0 and "Home" or "Farm", zone = "Country" }
  end
  local c = {
    guid = "return-journeys",
    race = race,
    class = COMBOS[race][1],
    chapters = { { start = { level = 20, zone = "Country", sub = "Home" }, log = log } },
  }
  inspect(race .. " return journeys", ns.writeBook(c).chapters[1].text)
end

-- A busy fighting day can also include quests. Recap fighting the objectives
-- have not already told, and exercise the long-work variants of that ending.
for _, race in ipairs(RACES) do
  for seed = 1, 80 do
    local c = {
      guid = "uncovered-fights-" .. seed,
      race = race,
      class = COMBOS[race][1],
      chapters = {
        {
          start = { level = 20, zone = "Country", sub = "Home" },
          quests = 2,
          played = 7200,
          kills = { Wolf = 20, Scorpid = 18 },
          log = {
            { k = "quest", giver = "Farmer", objectives = { { type = "monster", name = "Wolf", n = 2 } } },
          },
          ended = { level = 20, place = "Home", how = "rest" },
        },
      },
    }
    local text = ns.writeBook(c).chapters[1].text
    inspect(race .. " uncovered fights", text)
    -- (a number may open the sentence: "Eighteen Scorpids had fallen")
    if not text:lower():find("eighteen scorpids", 1, true) or text:lower():find("twenty wolves", 1, true) then
      problem(race .. " uncovered fights", "the recap repeated an objective or lost other fighting", text)
    end
  end
end

local runs = 0
-- Future or otherwise unwritten races still get a complete generic beginning.
-- Racial beginnings now belong to their own catalogs rather than redundant
-- shared lines that a complete racial catalog would hide permanently.
for i = 1, 80 do
  local c = {
    guid = "unwritten-" .. i,
    race = "Unwritten",
    class = "WARRIOR",
    hardcore = i % 2 == 0 or nil,
    chapters = { { start = { level = 1, zone = "Country", sub = "Home" }, log = {} } },
  }
  inspect("unwritten race", ns.writeBook(c).chapters[1].text)
end

-- A race added by another client still needs the shared narrator throughout
-- a life, including both singular and plural objectives and crafted gear.
for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "SHAMAN", "DRUID" }) do
  for _, hc in ipairs({ true, false }) do
    for _ = 1, 3 do
      local book = ns.writeBook(life("Unwritten", class, hc, 1, 60))
      inspect("shared narrator prologue", book.prologue)
      inspect("shared narrator epitaph", book.epitaph)
      for _, ch in ipairs(book.chapters) do
        inspect("shared narrator " .. class, ch.text)
      end
    end
  end
end

-- A long run of ordinary errands must not exhaust the racial narrator and
-- leave the rest of the book to the shared voice: the race's own remarks
-- come back once spaced, the shared ones only fill the gaps. Observe real
-- selections without modifying any candidate pool or the writer's own history.
for _, race in ipairs(RACES) do
  local selected, own = 0, 0
  local coverage = ns.writerUsed
  ns.writerUsed = setmetatable({}, {
    __newindex = function(_, reach)
      coverage[reach] = true
      if reach:find("r-task#", 1, true) then
        selected = selected + 1
        if reach:sub(1, #race + 1) == race .. "/" then own = own + 1 end
      end
    end,
  })
  -- forty chapters of four errands each
  local chapters = {}
  for n = 1, 40 do
    local log = {}
    for i = 1, 4 do
      log[i] = {
        k = "quest",
        giver = "Gazlowe",
        at = i * 300,
        objectives = { { type = "event", text = "Recover the missing cargo" } },
      }
    end
    chapters[n] = { start = { level = 20, zone = "The Barrens", sub = "Ratchet" }, log = log }
  end
  local c = { guid = "long-errands", race = race, class = COMBOS[race][1], chapters = chapters }
  for _, ch in ipairs(ns.writeBook(c).chapters) do
    inspect(race .. " long errands", ch.text)
  end
  ns.writerUsed = coverage
  if selected < 30 or own < selected * 0.55 then
    problem(race .. " long errands", "the racial voice faded during repeated work", own .. "/" .. selected)
  end
end

-- Skyborne traditions follow a recorded faction. A missing faction must
-- not be inferred even from a class currently restricted to one faction.
if forever then
  for _, faction in ipairs({ "alliance", "horde", "unknown" }) do
    local seen = false
    local coverage = ns.writerUsed
    ns.writerUsed = setmetatable({}, {
      __newindex = function(_, reach)
        coverage[reach] = true
        local i = reach:match("^Skyborne/beginning#(%d+)$")
        local tags = i and ns.data.voices.Skyborne.beginning[tonumber(i)].tags
        local required
        for _, tag in ipairs(tags or {}) do
          required = required or tag:match("faction:(%a+)")
        end
        if required then
          seen = true
          if required ~= faction then
            problem("Skyborne faction", "a tradition was assigned without its faction", reach)
          end
        end
      end,
    })
    for i = 1, 80 do
      local c = {
        guid = "skyborne-faction-" .. i,
        race = "Skyborne",
        class = "SHAMAN",
        faction = faction ~= "unknown" and faction or nil,
        chapters = { { start = { level = 1, zone = "Country", sub = "Home" }, log = {} } },
      }
      inspect("Skyborne " .. faction, ns.writeBook(c).chapters[1].text)
    end
    ns.writerUsed = coverage
    if faction ~= "unknown" and not seen then
      problem("Skyborne faction", "its own tradition was never heard", faction)
    end
  end
end

local comparison = dofile("addon/test/voices.lua")
for _, race in ipairs(comparison.races) do
  local c = comparison.day(race)
  local text = ns.writeBook(c).chapters[1].text
  inspect(race .. " voice comparison", text)
  -- (the six Brigands: all six, or the first told and "five more"; a count
  -- may open its sentence)
  local low = text:lower()
  if
    not (
      low:find("eight linen cloth", 1, true)
      and (low:find("six southsea brigands", 1, true) or low:find("five more", 1, true))
      and text:find("Brown Linen Robe", 1, true)
      and text:find("Kelsa", 1, true)
    )
  then
    problem(race .. " voice comparison", "the voice lost a recorded fact", text)
  end
  if text ~= ns.writeBook(c).chapters[1].text then
    problem(race .. " voice comparison", "the voice was not deterministic", text)
  end
end

trackRemarks = true
for _, round in ipairs({
  { 1, 12 },
  { 1, 60 },
  { 18, 41 },
  { 38, 60 },
  { 1, 30 },
  { 1, 7 },
  { 20, 50 },
  { 15, 45 },
  { 1, 15 },
  { 1, 10 },
}) do
  for _, race in ipairs(RACES) do
    local classes = COMBOS[race]
    for _, class in ipairs(classes) do
      for _, hc in ipairs({ true, false }) do
        runs = runs + 1
        local c = life(race, class, hc, round[1], round[2])
        local book = ns.writeBook(c)
        if (c.death ~= nil) ~= (book.epitaph ~= nil) then
          problem(race .. " " .. class, "a Hardcore death without an epitaph, or the reverse", "")
        end
        if hc then
          for _, ch in ipairs(book.chapters) do
            if ch.text and ch.text:find("I died", 1, true) then
              problem(race .. " " .. class, "a Hardcore death told in the first person", ch.text)
            end
          end
        end
        books = books + 1
        inspect(race .. " " .. class .. " prologue", book.prologue)
        inspect(race .. " " .. class .. " epitaph", book.epitaph)
        if round[1] > 1 and not book.prologue then problem(race .. " " .. class, "no prologue", "") end
        for _, ch in ipairs(book.chapters) do
          chapters = chapters + 1
          inspect(("%s %s chapter %d"):format(race, class, ch.number), ch.text)
          if class == "HUNTER" and ch.to <= 10 and ch.text and ch.text:find("%f[%a]pet%f[%A]") then
            problem(("%s HUNTER chapter %d"):format(race, ch.number), "a hunter's pet before level 10", ch.text)
          end
          if ch.text and #ch.text > longest then
            longest, longestText = #ch.text, ch.text
          end
        end
        repeats = repeats + book.repeats
        if book.minGap and (not gaps[book.minGapKind] or book.minGap < gaps[book.minGapKind]) then
          gaps[book.minGapKind] = book.minGap
        end
      end
    end
  end
end

trackRemarks = false

-- Deaths of every sort: closed Hardcore lives at levels low, middling and high,
-- the foe known or not, the place known or not.
for _, race in ipairs(RACES) do
  local classes = COMBOS[race]
  for _, class in ipairs(classes) do
    for _, level in ipairs({ 5, 20, 45 }) do
      for _ = 1, 6 do
        local c = life(race, class, true, level, level)
        c.death = death(level, "Loch Modan", chance(0.5) and "Thelsamar" or nil)
        if chance(0.2) then
          c.death.zone, c.death.sub = nil, nil
        end
        local last = c.chapters[#c.chapters]
        last.ended, c.closed = { level = level, place = "Thelsamar", how = "death" }, true
        local book = ns.writeBook(c)
        if not book.epitaph then problem(race .. " " .. class, "a Hardcore death without an epitaph", "") end
        inspect(race .. " " .. class .. " epitaph", book.epitaph)
      end
    end
  end
end

-- A chapter being written only grows: told one moment more, what was written
-- stays, but for its last sentence (the scene still being played).
-- (the text with its abbreviations hidden: "Venture Co. Laborer" is one sentence)
local function upTo(c, i, k)
  local copy = {}
  for key, v in pairs(c) do
    copy[key] = v
  end
  copy.chapters, copy.death = {}, nil
  for j = 1, i - 1 do
    copy.chapters[j] = c.chapters[j]
  end
  local ch = c.chapters[i]
  local open = { start = ch.start, kills = ch.kills, quests = ch.quests, played = ch.played, gold = ch.gold, log = {} }
  for j = 1, k do
    open.log[j] = ch.log[j]
  end
  copy.chapters[i] = open
  return ((ns.writeBook(copy).chapters[i].text or ""):gsub("Co%. ", "Co_ "):gsub("Mr%. ", "Mr_ "))
end
for _, race in ipairs(RACES) do
  local c = life(race, COMBOS[race][1], false, 1, 20)
  for i = 1, math.min(#c.chapters, 3) do
    local before = upTo(c, i, 0):gsub("\n\n", " ")
    for k = 1, #c.chapters[i].log do
      local now = upTo(c, i, k):gsub("\n\n", " ")
      local kept = before:match('^(.*[%.!%?]"?) [^%.!%?]*[%.!%?]"?$') or ""
      if now:sub(1, #kept) ~= kept then
        problem(race .. " chapter " .. i, "a finished sentence changed at moment " .. k, before .. "\n => " .. now)
        break
      end
      before = now
    end
  end
end

-- Every sentence must be reachable by some life: the shared ones, each
-- race's own, and each place's scenery.
local unused = {}
for kind, list in pairs(ns.data.writing) do
  for i, s in ipairs(list) do
    if not ns.writerUsed[kind .. "#" .. i] then table.insert(unused, kind .. ": " .. s[1]) end
  end
end
for race, own in pairs(ns.data.voices or {}) do
  for kind, list in pairs(own) do
    for i, s in ipairs(list) do
      if not ns.writerUsed[race .. "/" .. kind .. "#" .. i] then
        table.insert(unused, race .. "/" .. kind .. ": " .. s[1])
      end
    end
  end
end
for place, p in pairs(ns.data.scenery or {}) do
  for i, s in ipairs(p) do
    if not ns.writerUsed["scenery:" .. place .. "#" .. i] then
      table.insert(unused, "scenery " .. place .. ": " .. s[1])
    end
  end
end
table.sort(unused)
for _, u in ipairs(unused) do
  problem("never written", "unreachable sentence", u)
end

-- The open journal writes the book again at each moment, the closed chapters
-- from what it kept (ns.writeBook(c, keep)): the same book as written whole,
-- word for word, at every step of a life (each chapter open, half told, then
-- whole, then closed).
local function sameBook(x, y)
  if x.prologue ~= y.prologue or x.epitaph ~= y.epitaph or #x.chapters ~= #y.chapters then return false end
  for i, a in ipairs(x.chapters) do
    local b = y.chapters[i]
    for _, k in ipairs({ "number", "text", "place", "from", "to", "open", "rare", "close" }) do
      if a[k] ~= b[k] then return false end
    end
  end
  return true
end
local hooks = { ns.writerUsed, ns.writerSentence, ns.writerRemark }
ns.writerUsed, ns.writerSentence, ns.writerRemark = nil, nil, nil
for _, n in ipairs({ 1, 2, 3, 6 }) do -- (a Hardcore life, one met mid-life, both, neither)
  local race = RACES[n]
  local whole = life(race, COMBOS[race][1], n % 3 == 0, n % 2 == 0 and 20 or 1, 60)
  local all, keep = whole.chapters, {}
  local c = setmetatable({ chapters = {} }, { __index = whole })
  for i, ch in ipairs(all) do
    c.chapters[i] = ch
    local log, ended = ch.log, ch.ended
    ch.ended = nil
    for _, upTo in ipairs({ math.floor(#log / 2), #log }) do
      ch.log = { unpack(log, 1, upTo) }
      if not sameBook(ns.writeBook(c, keep), ns.writeBook(c)) then
        problem("kept", race .. ": chapter " .. i .. " open, " .. upTo .. " moments", "not the book written whole")
      end
    end
    ch.log, ch.ended = log, ended
    if not sameBook(ns.writeBook(c, keep), ns.writeBook(c)) then
      problem("kept", race .. ": chapter " .. i .. " closed", "not the book written whole")
    end
  end
end
ns.writerUsed, ns.writerSentence, ns.writerRemark = hooks[1], hooks[2], hooks[3]

-- Words and plurals.
local function eq(a, b, what)
  if a ~= b then problem("words", what, tostring(a) .. " ~= " .. tostring(b)) end
end
eq(ns.writer.words(1), "one", "1")
eq(ns.writer.words(21), "twenty-one", "21")
eq(ns.writer.words(115), "a hundred and fifteen", "115")
eq(ns.writer.plural("Ragged Young Wolf"), "Ragged Young Wolves", "wolf")
eq(ns.writer.plural("Bloodfeather Harpy"), "Bloodfeather Harpies", "harpy")
eq(ns.writer.plural("Servant of Arugal"), "Servants of Arugal", "of")
eq(ns.writer.plural("Watchman"), "Watchmen", "man")
eq(ns.writer.plural("Frostmane Shaman"), "Frostmane Shamans", "shaman")
eq(ns.writer.plural("Mud Thresh"), "Mud Threshes", "thresh")
eq(ns.writer.plural("Rotting Dead"), "Rotting Dead", "dead")
eq(ns.writer.plural("Scavenged Goods"), "Scavenged Goods", "already many")
eq(ns.writer.plural("Rough Glass"), "Rough Glasses", "glass")
eq(ns.writer.things("Crag Boar Rib"), "Crag Boar Ribs", "ribs")
eq(ns.writer.things("Tough Wolf Meat"), "Tough Wolf Meat", "meat")
eq(ns.writer.things("Shimmerweed"), "Shimmerweeds", "as the game writes it: 6 Shimmerweeds")
eq(ns.writer.things("Linen Cloth"), "Linen Cloth", "cloth")
eq(ns.writer.plural("Kobold Vermin"), "Kobold Vermin", "vermin")
eq(ns.writer.itemName("Wolf Fang Necklace"), "a Wolf Fang Necklace", "a")
eq(ns.writer.itemName("Cuirboulle Gloves"), "Cuirboulle Gloves", "plural")
eq(ns.writer.itemName("An Unsent Letter"), "an Unsent Letter", "own article")
eq(ns.writer.itemName("Wiley's Note"), "Wiley's Note", "possessive note")
eq(ns.writer.itemName("Smite's Mighty Hammer"), "Smite's Mighty Hammer", "possessive")
eq(ns.writer.itemName("Blackened Defias Armor"), "Blackened Defias Armor", "mass")
eq(
  ns.writer.taskOf("Read the Hallowed Rune and speak to Branstock Khalder in Anvilmar."),
  "read the Hallowed Rune",
  "the hand-in left out"
)
eq(ns.writer.instruction("Speak to Branstock Khalder."), false, "only the return: no task")
eq(ns.writer.playedWords(7170), "two hours", "1h59 is two hours")
eq(ns.writer.playedWords(3600 + 58 * 60), "two hours", "1h58")
eq(ns.writer.playedWords(1500), "twenty-five minutes", "25 min")
eq(ns.writer.playedWords(5400), "an hour and a half", "1h30")
eq(ns.writer.playedWords(9000), "two hours and a half", "2h30")
eq(ns.writer.goldWords(12345), "a gold piece", "1g")

io.write(
  ("%d books, %d chapters, %d sentences repeated (%.1f per book), longest chapter %d characters\n"):format(
    books,
    chapters,
    repeats,
    repeats / books,
    longest
  )
)
if os.getenv("WRITER_PROFILE") == "1" then io.write(longestText .. "\n") end
io.write(("routine remarks: %d/%d (%.1f%%)\n"):format(remarkTotal, routineTotal, 100 * remarkTotal / routineTotal))
io.write(("remarks repeated within a book's first ten chapters: %d\n"):format(remarkEarly))
if remarkEarly > 0 then
  problem("remark repeats", "a remark came back within a book's first ten chapters", tostring(remarkEarly))
end
if remarkTotal / routineTotal < 0.30 or remarkTotal / routineTotal > 0.45 then
  problem("remark budget", "routine remarks strayed outside the target frequency", remarkTotal .. "/" .. routineTotal)
end
local kinds = {}
for kind, gap in pairs(gaps) do
  table.insert(kinds, ("%s %d"):format(kind, gap))
end
table.sort(kinds)
io.write("fewest uses of a kind between two uses of one of its sentences: " .. table.concat(kinds, ", ") .. "\n")
for kind, gap in pairs(gaps) do
  if gap < 6 then
    problem("repeats", "a sentence of " .. kind .. " used again after " .. gap .. " uses of its kind", "")
  end
end
if #problems > 0 then
  io.write(table.concat(problems, "\n") .. "\n")
  os.exit(1)
end
io.write("all good (writer)\n")
