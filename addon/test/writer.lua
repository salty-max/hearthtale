-- The writer test: writes the journals of many imaginary lives (every race
-- and class, Hardcore or not, met at level 1 or mid-life) and checks every
-- entry: slots all filled, sentences capitalised and closed, no stray spaces
-- or doubled words, every sentence of writing/ reachable, a finished entry
-- never changed by the next.
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
  -- (the ways of fighting and the spells with a line of their own)
  "Arcane Missiles",
  "Immolate",
  "Smite",
  "Wrath",
  "Moonfire",
  "Life Tap",
  "Fear",
  "Drain Life",
  "Health Funnel",
  "Polymorph",
  "Blink",
  "Frost Nova",
  "Conjure Water",
  "Power Word: Shield",
  "Renew",
  "Resurrection",
  "Psychic Scream",
  "Lay on Hands",
  "Turn Undead",
  "Divine Protection",
  "Charge",
  "Execute",
  "Pick Pocket",
  "Sap",
  "Vanish",
  "Sprint",
  "Aspect of the Cheetah",
  "Feign Death",
  "Hunter's Mark",
  "Ghost Wolf",
  "Ancestral Spirit",
  "Lightning Shield",
  "Entangling Roots",
  "Healing Touch",
  "Rebirth",
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
  Orc = "Durotar",
  Troll = "Durotar",
  Tauren = "Mulgore",
  Scourge = "Tirisfal Glades",
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
  Orc = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "WARLOCK" },
  Troll = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE" },
  Tauren = { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" },
  Scourge = { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
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
-- Forever: the Skyborne, who begin on Zephras Isle, and the old races'
-- new classes (the client's CharBaseInfo against Classic Era's).
if forever then
  COMBOS.Skyborne = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "MAGE", "DRUID" }
  START.Skyborne = "Zephras Isle"
  table.insert(ZONES, {
    "Zephras Isle",
    {
      "Valanaar",
      "Shen'dar Village",
      "Thendal Grove",
      "Thendal Village",
      "Gustberry Lowlands",
      "Shrine of Akir",
      "Shadowgale Forest",
      "Falaath Village",
    },
  })
  for race, class in pairs({
    Dwarf = "SHAMAN",
    Gnome = "PRIEST",
    Human = "HUNTER",
    Orc = "MAGE",
    Scourge = "PALADIN",
    Troll = "WARLOCK",
  }) do
    table.insert(COMBOS[race], class)
  end
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
  local questId, returns = 1000000, {} -- quests whose work was told, not yet returned (ids no real quest has: no story of its own)
  local lastThing -- the thing the last quest for a thing asked for
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
          local k = one({ "riding", "mount", "bag", "gold" })
          if not once[k] then
            once[k] = true
            if k == "bag" then
              local looted = chance(0.5)
              local bag = one({ "Small Brown Pouch", "Linen Bag", "Small Black Pouch" })
              add(m(k, {
                link = chance(0.9) and ("|cffffffff|Hitem:1|h[" .. bag .. "]|h|r") or nil,
                slots = 6,
                looted = looted or nil,
              }))
            else
              add(m(k, { name = "Apprentice Riding" }))
            end
          end
        elseif r == 107 then
          local kind = ({ DRUID = "form", WARLOCK = "demon", PALADIN = "steed" })[class]
          local spell = kind and one(POWERS[kind])
          if spell and not once[spell] then
            once[spell] = true
            add(m("power", { spell = spell, kind = kind }))
          end
          -- (a warlock's first demon of a kind, a druid's first form: as today's journals record them)
          local first = class == "WARLOCK" and one({ "Imp", "Voidwalker", "Succubus", "Felhunter", "Felguard" })
            or class == "DRUID" and one({ "bear", "cat", "travel", "aquatic", "moonkin", "tree", "flight" })
          if first and not once[first] then
            once[first] = true
            if class == "WARLOCK" then
              add(m("demon", { name = one({ "Zigfik", "Ganrul", "Lirasha", "Kezzik" }), family = first }))
            else
              add(m("shift", { form = first }))
            end
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
            -- (the way back: most often soon after, and then told with the death)
            if chance(0.4) then clock = clock + 2400 end
            local how = one({ "corpse", "corpse", "healer", "healer", "ally", "ally", "self", "self" })
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
        -- (back to a place: often after a long while, a return then told)
        if seen[sub] and chance(0.8) then clock = clock + rand(3600, 7200) end
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
          -- (quests in a row often ask for the same thing: "more" of it)
          local thing = lastThing and chance(0.3) and lastThing or one(THINGS)
          lastThing = thing
          o = { { type = "item", name = thing, n = one({ 1, 1, 5, 6, 8, 10 }) } }
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
          -- (a hunter's or a warlock's pet at my side, now and then)
          local pet = (class == "HUNTER" or class == "WARLOCK") and chance(0.5) and one({ "Zigfik", "Bristle" }) or nil
          add(m("done", { id = q.id, title = q.title, giver = q.giver, objectives = o, pet = pet }))
          if chance(0.3) then
            add(m("quest", q))
          else
            table.insert(returns, q)
          end
        else
          add(m("quest", q))
          -- an errand whose ender sends me straight on with the next
          if q.giver and q.ender and q.giver ~= q.ender and not (o and o[1].name) and chance(0.5) then
            local last
            repeat
              last = one(GIVERS)
            until last ~= q.giver and last ~= q.ender
            add(m("quest", { title = one(QUESTS), giver = q.ender, ender = last }))
          end
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
local problems, books, chapters, longest = {}, 0, 0, 0
local longestText
local function problem(where, msg, text)
  if #problems < (os.getenv("WRITER_ALL") and 100000 or 20) then
    table.insert(problems, ("%s: %s\n    %s"):format(where, msg, text))
  end
end
local inspect = dofile("addon/test/inspect.lua")(problem)

-- Every place described, by day and by night, for each race (at home, among
-- allies, among foes): each description reachable through the book
-- (Book:sceneryOf), and checked.
for place in pairs(ns.data.scenery or {}) do
  for _, race in ipairs(RACES) do
    for seed = 1, 4 do
      local c = { guid = "scenery-" .. place .. race .. seed, race = race, class = COMBOS[race][1], chapters = {} }
      if race == "Skyborne" then c.faction = seed <= 2 and "alliance" or "horde" end
      inspect(race .. " scenery " .. place, ns.writer.newBook(c):sceneryOf(place, seed % 2 == 0 or nil))
    end
  end
end

-- A find of note (epic and above), one an entry: told by its name.
for _, race in ipairs(RACES) do
  for life = 1, 4 do
    local chapters = {}
    for n, item in ipairs({ "Thunderfury", "Lok'delar", "Benediction" }) do
      chapters[n] = {
        start = { level = 40, zone = "Tanaris", sub = "Gadgetzan" },
        kills = {},
        quests = 0,
        played = 3600,
        gold = 0,
        log = {
          {
            k = "loot",
            link = "|cffa335ee|Hitem:1|h[" .. item .. "]|h|r",
            quality = 4,
            zone = "Tanaris",
            sub = "Gadgetzan",
            at = 100,
          },
        },
        ended = { level = 40, zone = "Tanaris", sub = "Gadgetzan", place = "Gadgetzan", how = "rest" },
      }
    end
    local c = { guid = ("finds-%s-%d"):format(race, life), race = race, class = COMBOS[race][1], chapters = chapters }
    for _, ch in ipairs(ns.writeBook(c).chapters) do
      inspect(race .. " find", ch.text)
      if
        not ch.text:find("Thunderfury", 1, true)
        and not ch.text:find("Lok'delar", 1, true)
        and not ch.text:find("Benediction", 1, true)
      then
        problem(race .. " find", "a find of note not told", ch.text)
      end
    end
  end
end

-- Every supported race, class and hardcore pairing through an inn, a
-- dungeon and a fighting recap: class-specific lines remain reachable.
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
              { k = "group", name = "Mara", class = "WARRIOR", at = 150 },
              { k = "dungeon", name = "The Deadmines", at = 200 },
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

-- Every race and class from its first steps: a beginning of its own (the
-- Forsaken priest's or paladin's Light) remains reachable.
for _, race in ipairs(RACES) do
  for _, class in ipairs(COMBOS[race]) do
    for seed = 1, 2 do
      local c = {
        guid = ("first-steps-%s-%s-%d"):format(race, class, seed),
        race = race,
        class = class,
        began = { level = 1 },
        chapters = {
          {
            start = { level = 1, zone = "Country", sub = "Home" },
            quests = 0,
            played = 3600,
            gold = 0,
            kills = { Wolf = 4 },
            log = { { k = "kill", name = "Wolf", kind = "Wolf", sub = "Home", zone = "Country", at = 50 } },
            ended = { level = 3, place = "Home", how = "rest" },
          },
        },
      }
      if race == "Skyborne" then c.faction = seed == 1 and "alliance" or "horde" end
      for _, ch in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " " .. class .. " first steps", ch.text)
      end
      for _, e in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " " .. class .. " first steps diary", e.text)
      end
    end
  end
end

-- New ways of fighting in the diary, one or two, tried at once or not.
local plain = {} -- (quests with no story of their own: the fight is the trainer's)
for id = 300, 900 do
  if not ns.data.why[id] and #plain < 60 then table.insert(plain, id) end
end
for r, race in ipairs(RACES) do
  for life = 1, 6 do
    local spells = life % 2 == 1 and { "Frostbolt", "Arcane Missiles" } or { "Frostbolt" }
    local log = { { k = "learned", spells = spells, zone = "Westfall", sub = "Sentinel Hill", at = 100 } }
    if life <= 4 then
      table.insert(log, {
        k = "done",
        id = plain[r * 6 + life],
        giver = "Gryan Stoutmantle",
        objectives = { { type = "monster", name = "Defias Trapper", n = 8 } },
        zone = "Westfall",
        sub = "Sentinel Hill",
        at = 400,
      })
    end
    local c = {
      guid = ("new-ways-%s-%d"):format(race, life),
      race = race,
      class = "MAGE",
      chapters = {
        {
          start = { level = 8, zone = "Westfall", sub = "Sentinel Hill" },
          ended = { how = "rest", place = "Sentinel Hill", level = 8, at = 20000 },
          quests = 1,
          played = 3600,
          log = log,
        },
      },
    }
    if race == "Skyborne" then c.faction = "alliance" end
    for _, e in ipairs(ns.writeBook(c).chapters) do -- (the chapter: tried already?)
      inspect(race .. " new ways diary", e.text)
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

-- The journey's end at the highest level, for every race's own lines.
for _, race in ipairs(RACES) do
  for seed = 1, 24 do
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

-- Forever's own dungeons (the beta's), entered by each race: their places
-- described from a home or from outside, their last bosses told as such.
-- (Apart from the random lives, whose dungeons they would reshuffle.)
if forever then
  local FOREVER_DUNGEONS = {
    { "The Hall of Thanes", { "Faldrim Anvilmar", "Magmatus", "Plunder", "Durgen Dirgehammer" } },
    { "City of Dalaran", { "Arcane Anomaly", "Atrexis the Grave Knight", "Shade of the Archmage" } },
  }
  for _, race in ipairs(RACES) do
    for k, d in ipairs(FOREVER_DUNGEONS) do
      local log = { { k = "dungeon", name = d[1], zone = d[1], sub = d[1] } }
      for _, boss in ipairs(d[2]) do
        table.insert(log, { k = "boss", name = boss, zone = d[1], sub = d[1] })
      end
      local c = {
        guid = "forever-dungeon-" .. race .. k,
        race = race,
        class = COMBOS[race][1],
        faction = race == "Skyborne" and "alliance" or nil,
        chapters = { { start = { level = 25, zone = "Country", sub = "Home" }, log = log } },
      }
      inspect(race .. " in " .. d[1], ns.writeBook(c).chapters[1].text)
    end
  end
end

-- The Skyborne of each side come down from Zephras Isle into foreign lands
-- (their own arrivals, by side) and home again.
if forever then
  for _, faction in ipairs({ "alliance", "horde" }) do
    for seed = 1, 12 do
      local log = {}
      for i, zone in ipairs({ "Far Country", "Old Marches", "Zephras Isle", "Far Country", "Zephras Isle" }) do
        table.insert(log, { k = "place", new = "zone", zone = zone, sub = zone, at = i * 4000 })
      end
      local c = {
        guid = ("skyborne-lands-%s-%d"):format(faction, seed),
        race = "Skyborne",
        class = faction == "alliance" and "MAGE" or "SHAMAN",
        faction = faction,
        chapters = { { start = { level = 13, zone = "Zephras Isle", sub = "Valanaar" }, log = log } },
      }
      inspect("Skyborne " .. faction .. " lands", ns.writeBook(c).chapters[1].text)
    end
  end
end

-- Forever's Forsaken paladins (and priests): the Light learned, and what it
-- costs them, in a lesson, a close call and a revival.
if forever then
  for _, class in ipairs({ "PALADIN", "PRIEST" }) do
    for seed = 1, 6 do
      local c = {
        guid = ("forsaken-light-%s-%d"):format(class, seed),
        race = "Scourge",
        class = class,
        chapters = {
          {
            start = { level = 6, zone = "Tirisfal Glades", sub = "Brill" },
            log = {
              {
                k = "learned",
                spells = { class == "PALADIN" and "Holy Light" or "Smite" },
                zone = "Tirisfal Glades",
                sub = "Brill",
                at = 100,
              },
              {
                k = "close",
                foe = "Rot Hide Gnoll",
                hp = 10 + seed,
                zone = "Tirisfal Glades",
                sub = "Brill",
                at = 2000,
              },
              {
                k = "died",
                death = { level = 6, zone = "Tirisfal Glades", cause = "foe", foe = "Rot Hide Gnoll" },
                zone = "Tirisfal Glades",
                at = 9000,
              },
              { k = "revived", how = "healer", zone = "Tirisfal Glades", at = 20000 },
            },
          },
        },
      }
      inspect("Forsaken " .. class .. " and the Light", ns.writeBook(c).chapters[1].text)
    end
  end
end

-- Lands come back to, away and at home, at level 20 and 45 (each race's own
-- arrival lines: [back], [home], [high]); elites of one people fought one
-- after another; the Scarlet Crusade fought for a quest.
do
  local HOME = {
    Human = "Westfall",
    Dwarf = "Loch Modan",
    Gnome = "Loch Modan",
    NightElf = "Darkshore",
    Orc = "Durotar",
    Troll = "Durotar",
    Tauren = "Mulgore",
    Scourge = "Silverpine Forest",
    Skyborne = "Zephras Isle",
  }
  local HORDE = { Orc = true, Troll = true, Tauren = true, Scourge = true }
  for _, race in ipairs(RACES) do
    for _, faction in ipairs(race == "Skyborne" and { "alliance", "horde" } or { "" }) do
      local horde = HORDE[race] or faction == "horde"
      local a, b = horde and "The Barrens" or "Wetlands", horde and "Stonetalon Mountains" or "Arathi Highlands"
      for _, level in ipairs({ 20, 45 }) do
        local chapters = {}
        for n = 1, 14 do
          local t = n * 100000
          local log = {
            { k = "place", new = "zone", zone = b, sub = b, at = t + 60 },
            { k = "place", new = "zone", zone = a, sub = a, at = t + 600 },
            { k = "place", new = "zone", zone = HOME[race], sub = HOME[race], at = t + 1200 },
            { k = "place", new = "zone", zone = b, sub = b, at = t + 1800 },
          }
          if n % 3 == 0 then
            for _, name in ipairs({ "Mo'grosh Ogre", "Mo'grosh Brute", "Mo'grosh Enforcer" }) do
              table.insert(
                log,
                { k = "kill", name = name, kind = "Humanoid", elite = true, zone = b, sub = b, at = t + 1900 }
              )
            end
          elseif n % 3 == 1 then
            for _, name in ipairs({ "Mottled Boar", "Mottled Worg" }) do
              table.insert(
                log,
                { k = "kill", name = name, kind = "Beast", elite = true, zone = b, sub = b, at = t + 1900 }
              )
            end
          end
          local scarlet = { { type = "monster", name = "Scarlet Convert", n = 10 } }
          table.insert(
            log,
            { k = "kill", name = "Scarlet Convert", kind = "Humanoid", quarry = true, zone = b, sub = b, at = t + 2000 }
          )
          table.insert(log, {
            k = "done",
            id = 900 + n,
            giver = "Executor Zygand",
            objectives = scarlet,
            zone = b,
            sub = b,
            at = t + 2100,
          })
          chapters[n] = {
            start = { level = level, zone = a, sub = a },
            log = log,
            ended = { level = level, place = b, how = "rest" },
            kills = {},
            quests = n % 2 == 0 and 12 or 1, -- (a long run of work, for the diary's [lots])
            played = 3600,
            gold = 0,
          }
        end
        local c = {
          guid = "lands-" .. race .. faction .. level,
          race = race,
          class = COMBOS[race][1],
          faction = faction ~= "" and faction or nil,
          began = { level = level },
          chapters = chapters,
        }
        for i, ch in ipairs(ns.writeBook(c).chapters) do
          inspect(race .. " lands " .. level .. " ch" .. i, ch.text)
        end
        for i, e in ipairs(ns.writeBook(c).chapters) do
          inspect(race .. " lands " .. level .. " diary" .. i, e.text)
        end
      end
    end
  end
end

-- The diary's story (Diary.lua, writing/why/): stretches with one quest that
-- mattered, or two that were climaxes, told by what the work was for.
do
  local heavy, middling = {}, {}
  for id, why in pairs(ns.data.why or {}) do
    if why[1] == 3 and #why[2] <= 105 then table.insert(heavy, id) end -- (two that fit one sentence)
    if why[1] == 2 then table.insert(middling, id) end
  end
  table.sort(middling)
  -- (pairs that share a sentence: short, and not the same verb)
  local whys = ns.data.why
  table.sort(heavy, function(x, y) return #whys[x][2] < #whys[y][2] or (#whys[x][2] == #whys[y][2] and x < y) end)
  local pairs_ = {}
  for i = 1, #heavy do
    for j = i + 1, #heavy do
      local a, b = whys[heavy[i]][2], whys[heavy[j]][2]
      if #a + #b <= 190 and a:match("^(%S+)") ~= b:match("^(%S+)") and #pairs_ < 40 then
        table.insert(pairs_, { heavy[i], heavy[j] })
      end
    end
  end
  for r, race in ipairs(RACES) do
    local chapters = {}
    for n = 1, 24 do -- (long enough for the shared frames after the race's own)
      local log, k = {}, (r * 13 + n * 7)
      local function quest(id, at)
        table.insert(
          log,
          { k = "quest", id = id, giver = "Sten Stoutarm", ender = "Sten Stoutarm", told = true, at = at }
        )
      end
      quest(middling[k % #middling + 1], n * 100000 + 10)
      if n % 4 == 2 then
        local pair = pairs_[(r * 5 + n) % #pairs_ + 1]
        quest(pair[1], n * 100000 + 20)
        quest(pair[2], n * 100000 + 30)
      elseif n % 4 == 0 then -- (two too long for one sentence: the second its own)
        quest(heavy[#heavy - (r + n / 4) % 8], n * 100000 + 20)
        quest(heavy[#heavy - 8 - (r * 3 + n / 4) % 8], n * 100000 + 30)
      end
      chapters[n] = {
        start = { level = 20, zone = "Wetlands", sub = "Menethil Harbor" },
        log = log,
        ended = { level = 20, place = "Menethil Harbor", how = "rest" },
        kills = {},
        quests = #log,
        played = 3600,
        gold = 0,
      }
    end
    local c = {
      guid = "story-" .. race,
      race = race,
      class = COMBOS[race][1],
      faction = race == "Skyborne" and "horde" or nil, -- (the Skyborne's tradition follows their side)
      began = { level = 20 },
      chapters = chapters,
    }
    for i, e in ipairs(ns.writeBook(c).chapters) do
      inspect(race .. " story diary " .. i, e.text)
    end
  end
end

-- New lands of my own people's, two at once (a human's Westfall and Duskwood).
do
  local log = {
    { k = "place", new = "zone", zone = "Westfall", sub = "Westfall", at = 100 },
    { k = "place", new = "zone", zone = "Duskwood", sub = "Duskwood", at = 700 },
  }
  local c = {
    guid = "homelands",
    race = "Human",
    class = "WARRIOR",
    chapters = {
      {
        start = { level = 15, zone = "Elwynn Forest", sub = "Goldshire" },
        log = log,
        ended = { level = 15, place = "Darkshire", how = "rest" },
        kills = {},
        quests = 0,
        played = 3600,
        gold = 0,
      },
    },
  }
  inspect("home lands diary", ns.writeBook(c).chapters[1].text)
end

-- The diary's links (Diary.lua): a chain's story taken up again in a later
-- entry, and finished; foes who nearly killed me, several in an entry; new
-- lands of my own people's, two at once, for every race that has them; the
-- pet at my side, named again a few entries on.
do
  local whys, K = ns.data.why or {}, ns.knowledge
  local middling = {}
  for id, why in pairs(whys) do
    if why[1] == 2 then table.insert(middling, id) end
  end
  table.sort(middling)
  local members = {}
  for id, root in pairs(K.chains) do
    local why = whys[id]
    if why and why[1] >= 2 and #why[2] <= 120 then
      members[root] = members[root] or {}
      table.insert(members[root], id)
    end
  end
  local threads = {}
  for _, ids in pairs(members) do
    table.sort(ids)
    local ends, mids = {}, {}
    for _, id in ipairs(ids) do
      table.insert(K.ends[id] and ends or mids, id)
    end
    if #mids >= 2 and #ends >= 1 then table.insert(threads, { mids[1], mids[2], ends[1] }) end
  end
  table.sort(threads, function(x, y) return x[1] < y[1] end)
  assert(#threads > 0, "no quest chain with a story")
  local RARES = {
    "Mother Fang",
    "Gruff Swiftbite",
    "Snarlmane",
    "Lady Moongazer",
    "Foe Reaper 4000",
    "Mug'thol",
    "Ribchaser",
    "Leech Widow",
    "Old Cliff Jumper",
    "Rak'shiri",
    "Sister Riven",
    "Lord Malathrom",
    "Kazon",
    "Sergeant Brashclaw",
    "Fedfennel",
    "Brack",
    "Rippa",
    "Bjarn",
    "Timber",
    "Mangeclaw",
  }
  local HOMES = {}
  local CITIES = { ["Stormwind City"] = true, Ironforge = true, Darnassus = true, Orgrimmar = true }
  CITIES["Thunder Bluff"], CITIES.Undercity, CITIES.Anvilmar = true, true, true
  for zone, owner in pairs(ns.writer.HOSTS) do
    if not CITIES[zone] then -- (a city is known from the first day: no new land)
      HOMES[owner] = HOMES[owner] or {}
      table.insert(HOMES[owner], zone)
    end
  end
  for r, race in ipairs(RACES) do
    local homes = HOMES[race] or HOMES[ns.writer.TAKEN_IN[race] or ""] or {}
    table.sort(homes)
    local chapters = {}
    for n = 1, 12 do
      local t, log = n * 100000, {}
      -- (the first two: new lands alone, the race's own words free for them)
      local chain = threads[(r * 4 + math.floor((n - 1) / 3)) % #threads + 1]
      if n > 2 then
        table.insert(
          log,
          { k = "quest", id = chain[(n - 1) % 3 + 1], giver = "Sten Stoutarm", told = true, at = t + 10 }
        )
      end
      -- (foes worth naming, one to three, one of them nearly the end of me)
      local foes = {}
      for k = 1, n > 2 and n % 3 + 1 or 0 do
        foes[k] = RARES[(r * 7 + n * 3 + k) % #RARES + 1] .. (n > 6 and " the Elder" or "")
        table.insert(log, { k = "rare", name = foes[k], zone = "Wetlands", sub = "Wetlands", at = t + 20 + k })
      end
      if (n % 2 == 0 or n % 3 == 2) and foes[1] then
        table.insert(log, { k = "close", hp = 20, foe = foes[1], zone = "Wetlands", sub = "Wetlands", at = t + 30 })
      end
      -- (two lands of my own people's, or of my hosts', at once)
      if n <= 2 and homes[2 * n] then
        for k = 2 * n - 1, 2 * n do
          table.insert(log, { k = "place", new = "zone", zone = homes[k], sub = homes[k], at = t + 40 + k })
        end
      end
      chapters[n] = {
        start = { level = 20, zone = "Wetlands", sub = "Menethil Harbor" },
        log = log,
        ended = { level = 20, place = "Menethil Harbor", how = "rest" },
        kills = {},
        quests = 1,
        played = 3600,
        gold = 0,
      }
    end
    for life = 1, 3 do
      local c = {
        guid = "links-" .. race .. life,
        race = race,
        class = COMBOS[race][1],
        faction = race == "Skyborne" and (life % 2 == 0 and "horde" or "alliance") or nil,
        began = { level = 20 },
        chapters = chapters,
      }
      for i, e in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " links diary " .. i, e.text)
      end
    end
  end
  -- stretches of nothing but small work, early in a life; then the work
  -- of one people (whom the rest of the work was for), a story or a foe beside
  local GIVERS = { "Sten Stoutarm", "Gryan Stoutmantle", "Executor Zygand", "Gornek" }
  -- (a land their own or their hosts', worked in for one people or all sorts)
  local HOSTED = { Troll = "Durotar", Gnome = "Dun Morogh", NightElf = "Darkshore" }
  for r, race in ipairs(RACES) do
    local chapters = {}
    for n = 1, 48 do
      local log, quests = {}, 2
      if n > 12 then
        local t = n * 100000
        for k = 1, 6 do
          table.insert(log, {
            k = "quest",
            id = 1000000 + n * 10 + k,
            giver = GIVERS[(r + n + ((n > 36 and n % 2 == 1) and k or 0)) % #GIVERS + 1],
            at = t + k,
          })
        end
        if n % 3 == 0 then
          table.insert(
            log,
            { k = "quest", id = middling[(r * 7 + n) % #middling + 1], giver = "Sten Stoutarm", at = t + 9 }
          )
        end
        if n % 4 == 0 then
          table.insert(
            log,
            { k = "rare", name = "Old Greypaw " .. r .. n, zone = "Wetlands", sub = "Wetlands", at = t + 8 }
          )
        end
        quests = #log
      end
      local zone = n > 36 and HOSTED[race] or "Wetlands"
      chapters[n] = {
        start = { level = 6, zone = zone, sub = zone },
        log = log,
        ended = { level = 6, place = zone, how = "rest" },
        kills = {},
        quests = quests,
        played = 3600,
        gold = 0,
      }
    end
    local c =
      { guid = "quiet-" .. race, race = race, class = COMBOS[race][1], began = { level = 6 }, chapters = chapters }
    for i, e in ipairs(ns.writeBook(c).chapters) do
      inspect(race .. " quiet diary " .. i, e.text)
    end
  end
  -- escorts and events: work with no objective, done, then handed in (by
  -- its why, else by who asked)
  for r, race in ipairs(RACES) do
    local chapters = {}
    for n = 1, 12 do
      local t, id = n * 100000, n % 2 == 0 and middling[(r * 3 + n) % #middling + 1] or 2000000 + r * 100 + n
      chapters[n] = {
        start = { level = 20, zone = "Wetlands", sub = "Menethil Harbor" },
        log = {
          { k = "done", id = id, giver = "Sentinel Aynasha", zone = "Wetlands", sub = "Wetlands", at = t + 60 },
          { k = "quest", id = id, giver = "Sentinel Aynasha", ender = "Sentinel Onaeya", told = true, at = t + 900 },
        },
        ended = { level = 20, place = "Menethil Harbor", how = "rest" },
        kills = {},
        quests = 1,
        played = 3600,
        gold = 0,
      }
    end
    local c =
      { guid = "escort-" .. race, race = race, class = COMBOS[race][1], began = { level = 20 }, chapters = chapters }
    local book = ns.writeBook(c)
    for i, ch in ipairs(book.chapters) do
      inspect(race .. " escort " .. i, ch.text)
    end
    for i, e in ipairs(ns.writeBook(c).chapters) do
      inspect(race .. " escort diary " .. i, e.text)
    end
  end
  -- an elite slain, then its head taken as proof; many deliveries in one place
  for seed = 1, 12 do
    local log = {
      {
        k = "kill",
        name = "Ol' Sooty",
        kind = "Beast",
        elite = true,
        zone = "Dun Morogh",
        sub = "Dun Morogh",
        at = 100,
      },
      {
        k = "done",
        id = 4000000 + seed,
        giver = "Senator Mehr Stonehallow",
        objectives = { { type = "item", name = "Ol' Sooty's Head", n = 1 } },
        zone = "Dun Morogh",
        sub = "Dun Morogh",
        at = 160,
      },
    }
    for k = 1, 6 do
      table.insert(log, {
        k = "quest",
        id = 4100000 + seed * 10 + k,
        giver = "Sten Stoutarm",
        ender = "Talin Keeneye",
        objectives = { { type = "item", name = "Sealed Letter", n = 1, held = true } },
        zone = "Dun Morogh",
        sub = "Kharanos",
        at = 1000 + k * 60,
      })
    end
    -- (and favours known only by who asked: a fold of requests)
    for k = 1, 6 do
      table.insert(log, {
        k = "quest",
        id = 4200000 + seed * 10 + k,
        giver = "Grelin Whitebeard",
        zone = "Dun Morogh",
        sub = "Anvilmar",
        at = 3000 + k * 60,
      })
    end
    local c = {
      guid = "trophy-" .. seed,
      race = RACES[seed % #RACES + 1],
      class = "WARRIOR",
      chapters = {
        {
          start = { level = 10, zone = "Dun Morogh", sub = "Dun Morogh" },
          log = log,
          ended = { level = 10, place = "Kharanos", how = "rest" },
          kills = { ["Ol' Sooty"] = 1 },
          quests = 7,
          played = 3600,
          gold = 0,
        },
      },
    }
    inspect("trophy and deliveries", ns.writeBook(c).chapters[1].text)
  end
  -- fights against Cenarius's own, for those who revere him
  for _, life in ipairs({ { "NightElf", "WARRIOR" }, { "NightElf", "PRIEST" }, { "Tauren", "WARRIOR" } }) do
    for seed = 1, 4 do
      local chapters = {}
      for n = 1, 4 do
        chapters[n] = {
          start = { level = 20, zone = "Stonetalon Mountains", sub = "Stonetalon Mountains" },
          log = {
            {
              k = "done",
              id = 3000000 + n,
              giver = "Sten Stoutarm",
              objectives = { { type = "monster", name = "Son of Cenarius", n = 8 } },
              zone = "Stonetalon Mountains",
              sub = "Stonetalon Mountains",
              at = n * 100000 + 60,
            },
          },
          ended = { level = 20, place = "Stonetalon Mountains", how = "rest" },
          kills = { ["Son of Cenarius"] = 8 },
          quests = 1,
          played = 3600,
          gold = 0,
        }
      end
      local c =
        { guid = "cenarion-" .. life[1] .. life[2] .. seed, race = life[1], class = life[2], chapters = chapters }
      for i, ch in ipairs(ns.writeBook(c).chapters) do
        inspect(life[1] .. " cenarion " .. i, ch.text)
      end
    end
  end
  -- a shaman's initiations (each element's totem); a summoning taught, then
  -- its demon called a stretch later; a story's foe the dead, a demon, a beast
  local function stretch(n, log)
    return {
      start = { level = 20, zone = "Wetlands", sub = "Menethil Harbor" },
      log = log,
      ended = { level = 20, place = "Menethil Harbor", how = "rest" },
      kills = {},
      quests = 1,
      played = 3600,
      gold = 0,
    }
  end
  for r, race in ipairs({ "Orc", "Troll", "Tauren" }) do
    for life = 1, 2 do
      local chapters = {}
      for n, id in ipairs({ 1518, 1527, 96, 1531 }) do
        chapters[n] = stretch(n, { { k = "quest", id = id, giver = "Kranal Fiss", at = n * 100000 + 10 } })
      end
      local c = { guid = "totem-" .. race .. life .. r, race = race, class = "SHAMAN", chapters = chapters }
      for i, e in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " initiation diary " .. i, e.text)
      end
    end
  end
  for _, race in ipairs({ "Human", "Orc", "Gnome", "Scourge" }) do
    local chapters, n = {}, 0
    for _, pair in ipairs({ { 1470, "Imp" }, { 1471, "Voidwalker" }, { 1474, "Succubus" }, { 1795, "Felhunter" } }) do
      n = n + 1
      chapters[n] = stretch(n, { { k = "quest", id = pair[1], giver = "Alamar Grimm", at = n * 100000 + 10 } })
      n = n + 1
      chapters[n] = stretch(n, { { k = "demon", name = "Zig" .. n, family = pair[2], at = n * 100000 + 10 } })
    end
    local c = { guid = "summoned-" .. race, race = race, class = "WARLOCK", chapters = chapters }
    for i, e in ipairs(ns.writeBook(c).chapters) do
      inspect(race .. " summoning diary " .. i, e.text)
    end
  end
  local heavy = {}
  for id, why in pairs(whys) do
    if why[1] == 3 then table.insert(heavy, id) end
  end
  table.sort(heavy)
  -- a rescue is of someone: never souls, a thing, a place, nor one freed to be slain
  for text, want in pairs({
    ["escorted the wounded Corporal Keeshan from his prison cave"] = "rescue",
    ["freed Drull and Tog'thar from Durnholde Keep"] = "rescue",
    ["escorted Galen away from the creatures about to eat him"] = "rescue",
    ["freed the black drakes Blacklash and Hematus from the Seal of the Earth only to slay them"] = false,
    ["freed the restless souls of Stratholme's ghostly citizens"] = false,
    ["defended Silverwing Hold in Warsong Gulch against the Horde"] = false,
    ["saved Milly Osworth's grape harvest from the overrun vineyards"] = false,
    ["rescued books from the ogres in the Ruins of Alterac"] = false,
    ["escorted the Defias Traitor to the Brotherhood's secret hideout"] = false,
  }) do
    local got = ns.storySubject(text, {}, {}) == "rescue" and "rescue" or false
    if got ~= want then problem("story subject", "a rescue told wrong", text) end
  end
  -- a villain is one, named: never several, nor a name that only says whose
  for text, want in pairs({
    ["killed Kreenig Snarlsnout, the Razormane behind the raids"] = "villain",
    ["slew Old Murk-Eye, the murloc whose raids"] = "villain",
    ["killed Nak, Kuz and Lok Orcbane, the Razormane who raided the Horde"] = false,
    ["killed Big Samras and Creepthess"] = false,
    ["killed Venture Co. loggers in Windshear Crag"] = false,
  }) do
    if (ns.storySubject(text, {}, {}) or false) ~= want then problem("story subject", "a villain told wrong", text) end
  end
  if
    ns.storySubject("killed the Kul Tiras men", {
      { type = "monster", name = "Lieutenant Benedict", n = 1 },
      { type = "monster", name = "Kul Tiras Sailor", n = 10 },
    }, {}) == "villain"
  then
    problem("story subject", "a villain is one, not one among many", "Lieutenant Benedict")
  end
  if
    ns.storySubject("rescued Mythology of the Titans from the Monastery's library", {
      { type = "item", name = "Mythology of the Titans", n = 1 },
    }, {}) == "rescue"
  then
    problem("story subject", "a thing the quest asks for is no rescue", "Mythology of the Titans")
  end
  -- a story's reaction, by its subject: the dead, demons, a beast or a
  -- villain of a name, a rescue, and the peoples of note to a narrator
  local rescues = {}
  for _, id in ipairs(heavy) do
    local verb = whys[id][2]:match("^(%a+)")
    if verb == "escorted" or verb == "rescued" or verb == "freed" then table.insert(rescues, id) end
  end
  local subjects = {
    { "Skeletal Fiend", "Undead", 8 },
    { "Felguard Sentry", "Demon", 6 },
    { "Mangeclaw", "Beast", 1 },
    { "Hogger", "Humanoid", 1 },
    { false },
    { "Leper Gnome", "Humanoid", 10 },
    { "Highborne Apparition", "Undead", 6 },
    { "Keeper Ordanus", "Humanoid", 1 },
  }
  for r, race in ipairs(RACES) do
    for life = 1, #subjects do -- (a word on a story now and then: each life lands on other subjects)
      local chapters = {}
      for n = 1, 4 * #subjects do
        local foe = subjects[(n + life) % #subjects + 1]
        local t = n * 100000
        local id = foe[1] and heavy[(r * 11 + n * 5 + life) % #heavy + 1] or rescues[(r + n + life) % #rescues + 1]
        local log = {}
        if foe[1] then
          table.insert(
            log,
            { k = "kill", name = foe[1], kind = foe[2], zone = "Wetlands", sub = "Wetlands", at = t + 5 }
          )
        end
        table.insert(log, {
          k = "done",
          id = id,
          giver = "Sten Stoutarm",
          objectives = foe[1] and { { type = "monster", name = foe[1], n = foe[3] } } or {},
          zone = "Wetlands",
          sub = "Wetlands",
          at = t + 10,
        })
        chapters[n] = stretch(n, log)
      end
      local c = { guid = "react-" .. race .. life, race = race, class = COMBOS[race][1], chapters = chapters }
      if race == "Skyborne" then c.faction = life % 2 == 0 and "horde" or "alliance" end
      for i, e in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " reaction diary " .. i, e.text)
      end
    end
  end
  -- two stories in one entry, the second in another land: its place said
  for r, race in ipairs(RACES) do
    for life = 1, 3 do
      local chapters = {}
      for n = 1, 8 do
        local t = n * 100000
        local one, two = heavy[(r * 7 + n * 3 + life) % #heavy + 1], heavy[(r * 13 + n * 5 + life * 2) % #heavy + 1]
        chapters[n] = stretch(n, {
          {
            k = "done",
            id = one,
            giver = "Sten Stoutarm",
            objectives = {},
            zone = "Wetlands",
            sub = "Wetlands",
            at = t + 10,
          },
          {
            k = "done",
            id = two,
            giver = "Thundris Windweaver",
            objectives = {},
            zone = "Darkshore",
            sub = "Auberdine",
            at = t + 20,
          },
        })
      end
      local c = { guid = "elsewhere-" .. race .. life, race = race, class = COMBOS[race][1], chapters = chapters }
      if race == "Skyborne" then c.faction = life % 2 == 0 and "horde" or "alliance" end
      for i, e in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " two lands diary " .. i, e.text)
      end
    end
  end
  -- the foes worth naming, one, two or more, a hard fight among them or not
  local RARES = {
    "Mangeclaw",
    "Old Murk-Eye",
    "Snarlmane",
    "Mother Fang",
    "Hogger",
    "Bjarn",
    "Rak'shiri",
    "Sludginn",
    "Ma'ruk Wyrmscale",
    "Vagash",
    "Mazzranache",
    "Gath'Ilzogg",
    "Chief Sharpclaw",
    "Lord Azrethoc",
    "Lord Banehollow",
    "Lord Captain Wyrmak",
    "Lord Cobrahn",
    "Lord Arkkoroc",
  }
  for r, race in ipairs(RACES) do
    for life = 1, 3 do
      local chapters, met = {}, 0
      for n, count in ipairs({ 1, 1, 1, 2, 3, 1, 2, 3, 1 }) do
        local hard = n <= 5
        local t, log = n * 100000, {}
        for k = 1, count do
          met = met + 1 -- (a foe named once a diary: a new one each time)
          local name = RARES[(r + life + met) % #RARES + 1]
          table.insert(log, { k = "rare", name = name, zone = "Wetlands", sub = "Wetlands", at = t + k })
          if hard and k == 1 then
            table.insert(log, { k = "close", foe = name, hp = 4, zone = "Wetlands", sub = "Wetlands", at = t + k + 1 })
          end
        end
        if hard and (life > 1 or n > 1) then -- (a death told: the close call is a hard fight among the foes)
          table.insert(log, {
            k = "died",
            death = { level = 22, zone = "Wetlands", cause = "foe", foe = "Mosshide Gnoll" },
            zone = "Wetlands",
            at = t + 50,
          })
          table.insert(log, { k = "revived", how = "healer", zone = "Wetlands", at = t + 60 })
        end
        chapters[n] = stretch(n, log)
      end
      local c = { guid = "foes-" .. race .. life, race = race, class = COMBOS[race][1], chapters = chapters }
      if race == "Skyborne" then c.faction = life % 2 == 0 and "horde" or "alliance" end
      for i, e in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " foes diary " .. i, e.text)
      end
    end
  end
  -- the pet: a warlock's demon, a hunter's beast, at my side through the work
  for _, life in ipairs({
    { "Human", "WARLOCK", "Zigfik", "Imp" },
    { "Orc", "WARLOCK", "Grimbal", "Voidwalker" },
    { "Gnome", "WARLOCK", "Kazrix", "Imp" },
    { "Scourge", "WARLOCK", "Rohgar", "Felhunter" },
    { "Dwarf", "HUNTER", "Ashpaw", "Bear" },
    { "NightElf", "HUNTER", "Shadowmane", "Cat" },
    { "Tauren", "HUNTER", "Plainsrunner", "Tallstrider" },
    { "Troll", "HUNTER", "Snapjaw", "Crocolisk" },
    { "Orc", "HUNTER", "Bloodfang", "Wolf" },
  }) do
    local chapters = {}
    for n = 1, 12 do
      local t, log = n * 100000, {}
      for k = 1, 4 do
        table.insert(log, {
          k = "done",
          id = 1000000 + n * 10 + k,
          giver = "Sten Stoutarm",
          objectives = { { type = "monster", name = "Mottled Boar", n = 6 } },
          zone = "Wetlands",
          sub = "Wetlands",
          at = t + k * 60,
          pet = life[3],
          petFamily = life[4],
        })
      end
      chapters[n] = {
        start = { level = 20, zone = "Wetlands", sub = "Menethil Harbor" },
        log = log,
        ended = { level = 20, place = "Menethil Harbor", how = "rest" },
        kills = {},
        quests = 4,
        played = 3600,
        gold = 0,
      }
    end
    local c = { guid = "pet-" .. life[3], race = life[1], class = life[2], began = { level = 20 }, chapters = chapters }
    for i, e in ipairs(ns.writeBook(c).chapters) do
      inspect(life[1] .. " pet diary " .. i, e.text)
    end
  end
end

-- The diary's selection (Diary.lua): a milestone told however crowded the
-- stretch; a spell's new rank no news; a second companion told as another;
-- an initiation told; a finished entry the same however many come after.
do
  local function stretch(log, quests)
    return {
      start = { level = 20, zone = "Dun Morogh", sub = "Kharanos" },
      log = log,
      ended = { level = 20, place = "Kharanos", how = "rest" },
      kills = {},
      quests = quests or 1,
      played = 3600,
      gold = 0,
    }
  end
  local heavy = {}
  for id, why in pairs(ns.data.why) do
    if why[1] == 3 then table.insert(heavy, id) end
  end
  table.sort(heavy)
  for r, race in ipairs({ "Human", "Orc", "Gnome", "Scourge" }) do
    local c = {
      guid = "crowded-" .. race,
      race = race,
      class = "WARLOCK",
      chapters = {
        stretch({
          { k = "learned", spells = { "Immolate", "Corruption", "Life Tap", "Fear" }, at = 10 },
          { k = "quest", id = heavy[r], giver = "Sten Stoutarm", at = 20 },
          { k = "quest", id = heavy[r + 10], giver = "Sten Stoutarm", at = 25 },
          { k = "demon", name = "Kazrix", family = "Imp", at = 30 },
          { k = "died", death = { foe = "Rockjaw Trogg" }, zone = "Dun Morogh", sub = "Kharanos", at = 40 },
          { k = "revived", how = "corpse", at = 60 },
          { k = "place", new = "zone", zone = "Loch Modan", sub = "Loch Modan", at = 70 },
          { k = "rare", name = "Mother Fang", zone = "Loch Modan", sub = "Loch Modan", at = 80 },
          { k = "group", name = "Korrak", at = 90 },
          { k = "shift", form = "bear", at = 95 },
        }, 9),
      },
    }
    local text = ns.writeBook(c).chapters[1].text
    if not text:find("Kazrix", 1, true) then
      problem(race .. " crowded diary", "a milestone lost to lesser things", text)
    end
  end
  -- a new rank of a spell: told the first time only
  local ranks = {
    guid = "ranks",
    race = "Gnome",
    class = "MAGE",
    chapters = {
      stretch({ { k = "learned", spells = { "Frostbolt" }, at = 10 } }),
      stretch({ { k = "learned", spells = { "Frostbolt", "Frostbolt" }, at = 10 } }),
    },
  }
  local second = ns.writeBook(ranks).chapters[2].text
  if second:find("Frostbolt", 1, true) then problem("ranks diary", "a new rank told as a new spell", second) end
  -- a second companion: another, not the first
  for seed = 1, 6 do
    local pets = {
      guid = "pets-" .. seed,
      race = "Dwarf",
      class = "HUNTER",
      chapters = {
        stretch({ { k = "tame", name = "Dusk", family = "Boar", at = 10 } }),
        stretch({ { k = "tame", name = "Ashpaw", family = "Bear", at = 10 } }),
      },
    }
    local entries = ns.writeBook(pets).chapters
    if not entries[1].text:find("Dusk", 1, true) then
      problem("pets diary", "the first companion untold", entries[1].text)
    end
    if not entries[2].text:find("Ashpaw", 1, true) or entries[2].text:find("first", 1, true) then
      problem("pets diary", "a second companion told as the first, or not at all", entries[2].text)
    end
  end
  -- a shaman's initiation: told
  local totem =
    { guid = "totem", race = "Orc", class = "SHAMAN", chapters = { stretch({ { k = "quest", id = 1518, at = 10 } }) } }
  local told = ns.writeBook(totem).chapters[1].text
  if not told:find("totem", 1, true) then problem("initiation diary", "an element's favour untold", told) end
end

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

-- Every death and every way back, soon after (one sentence) or long after
-- (each its own); a warlock's every demon, a druid's every form; each race
-- and class, several lives, each chapter closed with its recap.
local DEATHS = {
  { cause = "foe", foe = "Murloc Forager", kind = "Humanoid" },
  { cause = "foe" },
  { cause = "foe", foe = "Leofric", player = true },
  { cause = "fall" },
  { cause = "drowning" },
  { cause = "lava" },
  { cause = "nature" },
}
local FIRSTS = {
  WARLOCK = { "Imp", "Voidwalker", "Succubus", "Felhunter", "Felguard" },
  DRUID = { "bear", "cat", "travel", "aquatic", "moonkin", "tree", "flight" },
}
for _, race in ipairs(RACES) do
  for _, class in ipairs(COMBOS[race]) do
    for life = 1, 3 do
      local chapters = {}
      local function chapter(log)
        for i, m in ipairs(log) do
          m.zone, m.sub, m.at = m.zone or "Westfall", m.sub or "Sentinel Hill", m.at or i * 100
        end
        table.insert(chapters, {
          start = { level = 12, zone = "Westfall", sub = "Sentinel Hill" },
          ended = { how = "rest", place = "Sentinel Hill", level = 12, at = 20000 },
          quests = 3,
          played = 3600,
          log = log,
        })
      end
      for _, how in ipairs({ "corpse", "healer", "ally", "self" }) do
        for _, d in ipairs(DEATHS) do
          for _, later in ipairs({ 60, 3600 }) do
            local death = { level = 12, zone = "Westfall", sub = "Sentinel Hill" }
            for k, v in pairs(d) do
              death[k] = v
            end
            chapter({
              { k = "died", death = death, at = 100 },
              {
                k = "revived",
                how = how,
                by = how == "ally" and "Thessaly" or nil,
                graveyard = "Sentinel Hill",
                at = 100 + later,
              },
            })
          end
        end
      end
      -- a quest's things fetched, in my way of fighting (a new one, learned
      -- between lives), with my pet
      local element = ({
        MAGE = { "Frostbolt", "Arcane Missiles" },
        WARLOCK = { "Corruption", "Curse of Agony" },
        DRUID = { "Moonfire" },
      })[class]
      for hunt = 1, 12 do
        local meat = { { type = "item", name = "Tough Wolf Meat", n = 8 } }
        local pet = (class == "HUNTER" or class == "WARLOCK") and hunt % 2 == 0 and "Grimtooth" or nil
        local log = {
          { k = "kill", name = "Ragged Young Wolf", kind = "Wolf" },
          { k = "done", id = 179 + hunt, giver = "Sten Stoutarm", objectives = meat, pet = pet },
        }
        if hunt % 4 ~= 0 and hunt ~= 5 then -- (more than one creature, hunted "until I had")
          table.insert(log, 1, { k = "kill", name = "Ragged Timber Wolf", kind = "Wolf" })
        end
        if hunt == 1 and element and life > 1 then
          table.insert(log, 1, { k = "learned", spells = { element[life - 1] } })
        end
        if (life + hunt) % 2 == 0 then
          log[#log + 1] = {
            k = "quest",
            id = 179 + hunt,
            giver = "Sten Stoutarm",
            ender = "Sten Stoutarm",
            told = true,
            objectives = meat,
          }
        end
        chapter(log)
      end
      -- a quest's kills, one creature or several, in my way of fighting
      for k = 1, 8 do
        local one = k % 2 == 0
        chapter({
          {
            k = "done",
            id = 300 + k,
            giver = "Gryan Stoutmantle",
            objectives = { { type = "monster", name = one and "Gath'Ilzogg" or "Defias Trapper", n = one and 1 or 8 } },
          },
        })
      end
      -- a class's own quests turned in: handed in on the spot, or a return
      local rewards, seenSpell = {}, {}
      for id, q in pairs(ns.knowledge.quests) do
        if q.class == class and q.spell and not seenSpell[q.spell] then
          seenSpell[q.spell] = true
          table.insert(rewards, id)
        end
      end
      table.sort(rewards)
      for _, id in ipairs(rewards) do
        local work = { { type = "item", name = "Feather Charm", n = 3 } }
        if life % 2 == 1 then
          chapter({
            { k = "done", id = id, giver = "Alamar Grimm", objectives = work },
            { k = "quest", id = id, giver = "Alamar Grimm", ender = "Alamar Grimm", told = true, objectives = work },
          })
        else
          chapter({
            { k = "quest", id = id, giver = "Alamar Grimm", ender = "Alamar Grimm", told = true, objectives = work },
          })
        end
      end
      for _, first in ipairs(FIRSTS[class] or {}) do
        chapter({
          class == "WARLOCK" and { k = "demon", name = "Zigfik", family = first } or { k = "shift", form = first },
        })
      end
      local c = { guid = "deaths-" .. race .. class .. life, race = race, class = class, chapters = chapters }
      for _, ch in ipairs(ns.writeBook(c).chapters) do
        inspect(race .. " deaths and firsts", ch.text)
      end
    end
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
  -- (what the day's entry keeps: the trade taken up, the company, the close call)
  local low = text:lower()
  if not (low:find("tailoring", 1, true) and text:find("Kelsa", 1, true) and low:find("southsea brigand", 1, true)) then
    problem(race .. " voice comparison", "the voice lost a recorded fact", text)
  end
  if text ~= ns.writeBook(c).chapters[1].text then
    problem(race .. " voice comparison", "the voice was not deterministic", text)
  end
end

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
        -- every entry through the shared checks; no more than one thought of
        -- a kind in an entry ("stays with me"); a hunter's pet not before 10
        for _, ch in ipairs(book.chapters) do
          chapters = chapters + 1
          local where = ("%s %s entry %d"):format(race, class, ch.number)
          inspect(where, ch.text)
          if class == "HUNTER" and ch.to <= 10 and ch.text and ch.text:find("%f[%a]pet%f[%A]") then
            problem(where, "a hunter's pet before level 10", ch.text)
          end
          if ch.text and #ch.text > longest then
            longest, longestText = #ch.text, ch.text
          end
          local marks = 0
          for _, mark in ipairs({
            "stays with me",
            "left a mark",
            "leave a mark",
            "turning it over",
            "turning them over",
          }) do
            if ch.text:find(mark, 1, true) then marks = marks + 1 end
          end
          if marks > 1 then problem(where, "one reflection twice", ch.text) end
        end
        -- a finished entry the same however many come after
        if #c.chapters > 3 and books % 7 == 0 then
          local shorter = {}
          for k, v in pairs(c) do
            shorter[k] = v
          end
          shorter.chapters, shorter.death, shorter.closed = {}, nil, nil
          for k = 1, #c.chapters - 1 do
            shorter.chapters[k] = c.chapters[k]
          end
          local before = ns.writeBook(shorter).chapters
          for k = 1, #before - 1 do
            if before[k].text ~= book.chapters[k].text then
              problem(
                ("%s %s entry %d"):format(race, class, k),
                "a finished entry changed when another came",
                book.chapters[k].text
              )
            end
          end
        end
      end
    end
  end
end

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
eq(ns.writer.plural("Kobold Vermin"), "Kobold Vermin", "vermin")
eq(ns.writer.itemName("Wolf Fang Necklace"), "a Wolf Fang Necklace", "a")
eq(ns.writer.itemName("Cuirboulle Gloves"), "Cuirboulle Gloves", "plural")
eq(ns.writer.itemName("An Unsent Letter"), "an Unsent Letter", "own article")
eq(ns.writer.itemName("Wiley's Note"), "Wiley's Note", "possessive note")
eq(ns.writer.itemName("Smite's Mighty Hammer"), "Smite's Mighty Hammer", "possessive")
eq(ns.writer.itemName("Blackened Defias Armor"), "Blackened Defias Armor", "mass")
eq(ns.writer.playedWords(7170), "two hours", "1h59 is two hours")
eq(ns.writer.playedWords(3600 + 58 * 60), "two hours", "1h58")
eq(ns.writer.playedWords(1500), "twenty-five minutes", "25 min")
eq(ns.writer.playedWords(5400), "an hour and a half", "1h30")
eq(ns.writer.playedWords(9000), "two hours and a half", "2h30")

io.write(("%d books, %d entries, longest entry %d characters\n"):format(books, chapters, longest))
if os.getenv("WRITER_PROFILE") == "1" then io.write(longestText .. "\n") end
if #problems > 0 then
  io.write(table.concat(problems, "\n") .. "\n")
  os.exit(1)
end
io.write("all good (writer)\n")
