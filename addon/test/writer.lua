-- The writer test: writes the books of many imaginary lives (every race and
-- class, Hardcore or not, met at level 1 or mid-life) and checks every
-- chapter: slots all filled, sentences capitalised and closed, no stray
-- spaces or doubled words, every sentence of writing/ reachable, few repeats.
--   luajit addon/test/writer.lua            the checks
-- (a sample book, from a life played through the addon: addon/test/sample.lua)
local DIR = "addon/WayfarersJournal/"
local ns = {}
assert(loadfile(DIR .. "Data_Classic.lua"))("WayfarersJournal", ns)
assert(loadfile(DIR .. "Writer.lua"))("WayfarersJournal", ns)

-- A small random generator of our own, for the same lives on every machine.
local state = 12345
local function rand(a, b)
  state = (state * 1103515245 + 12345) % 2147483648
  if not a then return state / 2147483648 end
  if not b then a, b = 1, a end
  return a + math.floor(state / 65536) % (b - a + 1) -- the high bits: the low ones cycle
end
local function one(list) return list[rand(#list)] end
local function chance(p) return rand() < p end

-- ── what a life can hold (the original game's names) ─────────────────────────
local ZONES = {
  { "Dun Morogh", { "Coldridge Valley", "Anvilmar", "Kharanos", "Brewnall Village", "Shimmer Ridge", "Frostmane Hold", "Gol'Bolar Quarry" } },
  { "Elwynn Forest", { "Northshire Valley", "Goldshire", "Fargodeep Mine", "Jasperlode Mine", "Brackwell Pumpkin Patch", "Tower of Azora" } },
  { "Durotar", { "Valley of Trials", "Razor Hill", "Sen'jin Village", "Echo Isles", "Skull Rock" } },
  { "Mulgore", { "Camp Narache", "Bloodhoof Village", "Brambleblade Ravine", "The Venture Co. Mine" } },
  { "Tirisfal Glades", { "Deathknell", "Brill", "Agamand Mills", "Scarlet Watch Post" } },
  { "Teldrassil", { "Shadowglen", "Dolanaar", "Ban'ethil Barrow Den", "The Oracle Glade" } },
  { "Loch Modan", { "Thelsamar", "Stonewrought Dam", "The Farstrider Lodge", "Silver Stream Mine" } },
  { "The Barrens", { "The Crossroads", "Ratchet", "Camp Taurajo", "The Forgotten Pools", "Lushwater Oasis" } },
  { "Westfall", { "Sentinel Hill", "Moonbrook", "The Dagger Hills", "Saldean's Farm" } },
  { "Stranglethorn Vale", { "Booty Bay", "Grom'gol Base Camp", "Nesingwary's Expedition", "Zul'Kunda" } },
  { "Ashenvale", { "Astranaar", "Splintertree Post", "Raynewood Retreat" } },
  { "Tanaris", { "Gadgetzan", "Steamwheedle Port", "Zalashji's Den" } },
  { "Eversong Woods", { "Sunstrider Isle", "Falconwing Square", "Fairbreeze Village" } },
  { "Azuremyst Isle", { "Ammen Vale", "Azure Watch", "Odesyus' Landing" } },
}
local CREATURES = {
  { "Ragged Young Wolf", "Wolf" }, { "Rockjaw Trogg", "Humanoid" }, { "Frostmane Novice", "Humanoid" },
  { "Kobold Vermin", "Humanoid" }, { "Defias Thug", "Humanoid" }, { "Mottled Boar", "Boar" },
  { "Plainstrider", "Tallstrider" }, { "Rotting Dead", "Undead" }, { "Young Nightsaber", "Cat" },
  { "Harvest Watcher", "Mechanical" }, { "Venture Co. Laborer", "Humanoid" }, { "Bloodfeather Harpy", "Humanoid" },
  { "Stranglethorn Raptor", "Raptor" }, { "Mud Thresh", "Elemental" }, { "Felstalker", "Demon" },
  { "Greater Duskbat", "Bat" }, { "Servant of Arugal", "Undead" }, { "Frostmane Shaman", "Humanoid" },
  { "Watchman", "Humanoid" }, { "Thistle Cub", "Bear" }, { "Swamp Jaguar", "Cat" }, { "Black Dragon Whelp", "Dragonkin" },
  { "Hare", "Critter" },
}
local QUESTS = { "Dwarven Outfitters", "A New Threat", "The Troll Cave", "Beer Basted Boar Ribs", "Wolves Across the Border",
  "Lazy Peons", "The Defias Brotherhood", "Gnomeregan Glory", "The Bloodhoof Messenger", "Kobold Camp Cleanup",
  "Plainstrider Menace", "In Favor of the Light", "The Stolen Journal", "Fungus Among Us", "Hidden Enemies",
  "The Escape", "Ammo for Rumbleshot", "Raptor Mastery", "Down the Coast", "Mortality Wanes" }
local GIVERS = { "Sten Stoutarm", "Marshal McBride", "Gornek", "Grull Hawkwind", "Magistrate Burnside", "Conservator Ilthalaine",
  "Rejold Barleybrew", "Gryan Stoutmantle", "Thrall", "Hemet Nesingwary" }
local RARES = { "Timber", "Mangeclaw", "Hogger", "Rak'shiri", "Mother Fang", "Squiddic", "Lady Moongazer", "Gruff Swiftbite" }
local DUNGEONS = { { "The Deadmines", { "Rhahk'Zor", "Sneed", "Gilnid", "Mr. Smite", "Edwin VanCleef" } },
  { "Ragefire Chasm", { "Taragaman the Hungerer", "Bazzalan" } }, { "Wailing Caverns", { "Lady Anacondra", "Mutanus the Devourer" } },
  { "Shadowfang Keep", { "Rethilgore", "Baron Silverlaine", "Archmage Arugal" } }, { "The Stockade", { "Bazil Thredd" } } }
local THINGS = { "Tough Wolf Meat", "Crag Boar Rib", "Shimmerweed", "Gnoll Paw", "Grelin Whitebeard's Journal", "Scalding Mornbrew",
  "Kobold Candle", "Murloc Fin", "Red Bandana", "Linen Cloth" }
local TASKS = { "Explore the Frostmane Hold", "Find the missing diplomat", "Light the signal fire", "Destroy the Defias plans",
  "Escort the caravan to the Crossroads" }
local SPELLS = { "Blessing of Might", "Judgement", "Hammer of Justice", "Frostbolt", "Fireball", "Sinister Strike", "Shadow Word: Pain",
  "Lightning Bolt", "Corruption", "Serpent Sting", "Rejuvenation", "Battle Shout", "Rend", "Arcane Intellect" }
local SKILLS = { "Mining", "Herbalism", "Skinning", "First Aid", "Blacksmithing", "Tailoring", "Cooking" }
local ITEMS = { "Wolf Fang Necklace", "Frostmane Leather Vest", "Cuirboulle Gloves", "Smite's Mighty Hammer", "Blackened Defias Armor", "Feline Mantle" }
local POWERS = { form = { "Bear Form", "Cat Form", "Travel Form", "Aquatic Form" },
  demon = { "Summon Voidwalker", "Summon Succubus", "Summon Felhunter", "Inferno" },
  steed = { "Summon Warhorse", "Summon Charger" } }
local PETS = { "Grrr", "Snapjaw", "Whisper", "Old Tom", "Bitey", "Fang", "Shadow", "Rusty", "Mossback", "Echo" }
local FAMILIES = { "Bear", "Wolf", "Cat", "Owl", "Crocolisk", "Boar" }
local MATES = { "Brannor", "Kelsa", "Thrudd", "Ylena", "Morgrim", "Aeris", "Zul'jin", "Brokk" }
local NODES = { "Ironforge, Dun Morogh", "Thelsamar, Loch Modan", "Stormwind, Elwynn", "Sentinel Hill, Westfall",
  "Orgrimmar, Durotar", "The Crossroads, The Barrens", "Booty Bay, Stranglethorn", "Gadgetzan, Tanaris" }
local START = { Human = "Elwynn Forest", Dwarf = "Dun Morogh", Gnome = "Dun Morogh", NightElf = "Teldrassil",
  Draenei = "Azuremyst Isle", Orc = "Durotar", Troll = "Durotar", Tauren = "Mulgore", Scourge = "Tirisfal Glades",
  BloodElf = "Eversong Woods" }
local function zoneNamed(name) for _, z in ipairs(ZONES) do if z[1] == name then return z end end end
local COMBOS = {
  Human = { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK" }, Dwarf = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST" },
  NightElf = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "DRUID" }, Gnome = { "WARRIOR", "ROGUE", "MAGE", "WARLOCK" },
  Draenei = { "WARRIOR", "PALADIN", "HUNTER", "PRIEST", "SHAMAN", "MAGE" }, Orc = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "WARLOCK" },
  Troll = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE" }, Tauren = { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" },
  Scourge = { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" }, BloodElf = { "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
}

local CAUSES = { "foe", "foe", "foe", "foe", "fall", "drowning", "lava", "nature" }
local KINDS = { "Wolf", "Humanoid", "Undead", "Beast", "Boar", "Elemental", nil }
local RANKS = { "normal", "normal", "elite", "rare", "worldboss" }
local function death(n, zone, sub)
  local cause = one(CAUSES)
  local d = { level = n, zone = zone, sub = chance(0.8) and sub or nil, cause = cause }
  if cause == "foe" then
    if chance(0.15) then d.player, d.foe = true, one(MATES)
    else d.foe, d.kind, d.rank = chance(0.7) and one(CREATURES)[1] or nil, one(KINDS), one(RANKS) end
    d.inside = chance(0.15) or nil
  end
  return d
end

-- The races in a fixed order: pairs() would walk them differently on each run
-- (LuaJIT hashes strings with a random seed), and the lives with them.
local RACES = {}
for race in pairs(COMBOS) do table.insert(RACES, race) end
table.sort(RACES)

local guid = 0
local function life(race, class, hc, from, to)
  guid = guid + 1
  local c = { guid = ("Player-1-%08X"):format(guid), name = one({ "Sealinedion", "Brannor", "Kelsa", "Thrudd", "Ylena", "Morgrim" }),
    race = race, class = class, hardcore = hc or nil, began = { level = from }, chapters = {} }
  if from > 1 then
    c.prologue = { level = from, quests = chance(0.9) and rand(5, 200) or 0, inn = one({ "Goldshire", "Kharanos", "Brill", nil }),
      zone = one(ZONES)[1], played = chance(0.6) and rand(3000, 400000) or nil }
  end
  local zone = from == 1 and zoneNamed(START[race]) or one(ZONES)
  local sub = zone[2][1]
  local seen, kinds, level, once = {}, {}, from, {}
  local clock, isNight = 1790000000, false
  local function m(k, fields)
    fields = fields or {}
    clock = clock + (chance(0.15) and rand(3600, 10000) or rand(60, 900))
    if chance(0.15) then isNight = not isNight end
    fields.k, fields.zone, fields.sub, fields.night, fields.at = k, fields.zone or zone[1], fields.sub or sub, isNight or nil, clock
    return fields
  end
  while level <= to do
    local ch = { start = { level = level, zone = zone[1], sub = chance(0.85) and sub or nil, night = chance(0.35) or nil },
      log = {}, kills = {}, quests = 0, played = rand(600, 18000), gold = rand(0, 3) == 0 and 0 or rand(5, 40000) }
    local function add(x) table.insert(ch.log, x) end
    for _ = 1, rand(3, 22) do
      local r = rand(112)
      local hunter = class == "HUNTER" and level >= 10
      if r > 100 then
        if r <= 103 then
          add(m("gear", { link = "|cff1eff00|Hitem:1|h[" .. one(ITEMS) .. "]|h|r", quality = 2, made = chance(0.3) or nil }))
        elseif r <= 105 then
          local learned = chance(0.4)
          add(m("prof", { name = one(SKILLS), learned = learned or nil,
            rank = not learned and one({ "apprentice", "journeyman", "expert", "artisan" }) or nil }))
        elseif r == 106 then
          -- once in a life each, as the game records them
          local k = chance(0.5) and "riding" or "mount"
          if not once[k] then once[k] = true; add(m(k, { name = "Apprentice Riding" })) end
        elseif r == 107 then
          local kind = ({ DRUID = "form", WARLOCK = "demon", PALADIN = "steed" })[class]
          local spell = kind and one(POWERS[kind])
          if spell and not once[spell] then once[spell] = true; add(m("power", { spell = spell, kind = kind })) end
        elseif r <= 109 then
          local pet = one(PETS)
          if hunter and not once[pet] then once[pet] = true; add(m("tame", { name = pet, family = chance(0.8) and one(FAMILIES) or nil })) end
        elseif r <= 111 then
          if hunter then add(m("petdied", { name = chance(0.9) and one(PETS) or nil })) end
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
        if roll <= 35 then o = { { type = "monster", name = one(CREATURES)[1], n = one({ 1, 6, 8, 10, 12, 15 }) } }
        elseif roll <= 65 then o = { { type = "item", name = one(THINGS), n = one({ 1, 1, 5, 6, 8, 10 }) } }
        elseif roll <= 75 then o = { { type = "event", text = one(TASKS) } } end
        add(m("quest", { title = chance(0.95) and one(QUESTS) or nil, giver = chance(0.8) and one(GIVERS) or nil,
          ender = chance(0.4) and one(GIVERS) or nil, objectives = o }))
      elseif r <= 52 then
        local cr = one(CREATURES)
        local n = rand(1, 12)
        if not ch.kills[cr[1]] then
          local first = not kinds[cr[2]] or nil
          kinds[cr[2]] = true
          add(m("kill", { name = cr[1], kind = cr[2], first = first, elite = chance(0.08) or nil, quarry = chance(0.3) or nil }))
        end
        ch.kills[cr[1]] = (ch.kills[cr[1]] or 0) + n
      elseif r <= 55 then
        add(m("rare", { name = one(RARES), elite = chance(0.3) or nil }))
      elseif r <= 60 then
        add(m("close", { foe = chance(0.8) and one(CREATURES)[1] or nil, hp = rand(1, 9) }))
      elseif r <= 63 then
        add(m("group", { name = one(MATES), class = "WARRIOR" }))
      elseif r <= 66 then
        local d = one(DUNGEONS)
        add(m("dungeon", { name = d[1] }))
        for i = 1, rand(0, #d[2]) do add(m("boss", { name = d[2][i] })) end
      elseif r <= 70 then
        local spells, list = {}, {}
        for _ = 1, rand(1, 5) do
          local sp = one(SPELLS)
          if not spells[sp] then spells[sp] = true; table.insert(list, sp) end
        end
        add(m("learned", { spells = list }))
      elseif r <= 72 then
        add(m("skill", { name = one(SKILLS), rank = one({ 50, 75, 100, 150, 200, 225, 250, 300 }) }))
      elseif r <= 76 then
        add(m("learned", { spells = { one(SPELLS) } }))
      elseif r <= 82 then
        if level < to then level = level + 1; add(m("level", { level = level })) end
      elseif r <= 86 then
        add(m("campfire"))
      elseif r <= 90 then
        if chance(0.7) then add(m("night")) else add(m("rested", { place = one(zone[2]), fire = chance(0.3) or nil })) end
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
    if not lastOne or chance(0.5) then
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
  for _, z in ipairs(ZONES) do if chance(0.3) then c.visited[z[1] .. "|"] = true end end
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
local gaps = {} -- kind = the fewest uses of the kind between two uses of one of its sentences
local function problem(where, msg, text)
  if #problems < 20 then table.insert(problems, ("%s: %s\n    %s"):format(where, msg, text)) end
end
local function inspect(where, text)
  if not text then return end
  local checks = {
    { "{", "a slot left unfilled" }, { "nil", "nil in the text" }, { "  ", "a double space" },
    { " %.", "a space before a full stop" }, { " ,", "a space before a comma" }, { "%.%.", "two full stops" },
    { ",%.", "a comma before a full stop" }, { "there there", "there there" }, 
    { "%f[%a]in in%f[%A]", "in in" }, { "%f[%a]in there%f[%A]", "in there" }, { "%f[%a]a a%f[%A]", "a a" }, { "%f[%a]the the%f[%A]", "the the" },
    { "%f[%a]there%f[%A][^%.!%?]*%f[%a]there%f[%A]", "there twice in a sentence" }, { " ;", "a space before a semicolon" },
    { "[;:] *[%.!%?]", "nothing after a colon" },
    { "^%l", "a lowercase start" },
    { "[%.!%?]\"? +%l", "a sentence starting in lowercase" }, { "[^%.!%?\"]$", "no full stop at the end" },
    { "\n%l", "a paragraph starting in lowercase" }, { "\n\n\n", "an empty paragraph" }, { "[^%.!%?\"\n]\n", "a paragraph without a full stop" },
  }
  for _, c in ipairs(checks) do
    if text:find(c[1]) then problem(where, c[2], text) end
  end
  -- A count of one before a plural ("one tasks"), but not "twenty-one tasks"
  -- or "a hundred and one tasks".
  for at, noun in text:gmatch("()[Oo]ne (%a+)") do
    local before = text:sub(math.max(1, at - 4), at - 1)
    local plural = ({ tasks = 1, foes = 1, lands = 1, good = 1, errands = 1, jobs = 1, quests = 1 })[noun]
    if plural and not before:find("%a$") and not before:find("%-$") and not before:find("and $") then
      problem(where, "one, then a plural", text)
    end
  end
end

local runs = 0
for _, round in ipairs({ { 1, 12 }, { 1, 60 }, { 18, 41 }, { 38, 60 }, { 1, 30 }, { 1, 7 }, { 20, 50 } }) do
  for _, race in ipairs(RACES) do
  local classes = COMBOS[race]
    for _, class in ipairs(classes) do
      for _, hc in ipairs({ true, false }) do
        runs = runs + 1
        local c = life(race, class, hc, round[1], round[2])
        local book = ns.writeBook(c)
        if (c.death ~= nil) ~= (book.epitaph ~= nil) then problem(race .. " " .. class, "a Hardcore death without an epitaph, or the reverse", "") end
        if hc then
          for _, ch in ipairs(book.chapters) do
            if ch.text and ch.text:find("I died", 1, true) then problem(race .. " " .. class, "a Hardcore death told in the first person", ch.text) end
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
          if ch.text and #ch.text > longest then longest = #ch.text end
        end
        repeats = repeats + book.repeats
        if book.minGap and (not gaps[book.minGapKind] or book.minGap < gaps[book.minGapKind]) then gaps[book.minGapKind] = book.minGap end
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
        if chance(0.2) then c.death.zone, c.death.sub = nil, nil end
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
  for key, v in pairs(c) do copy[key] = v end
  copy.chapters, copy.death = {}, nil
  for j = 1, i - 1 do copy.chapters[j] = c.chapters[j] end
  local ch = c.chapters[i]
  local open = { start = ch.start, kills = ch.kills, quests = ch.quests, played = ch.played, gold = ch.gold, log = {} }
  for j = 1, k do open.log[j] = ch.log[j] end
  copy.chapters[i] = open
  return ((ns.writeBook(copy).chapters[i].text or ""):gsub("Co%. ", "Co_ "):gsub("Mr%. ", "Mr_ "))
end
for _, race in ipairs(RACES) do
  local c = life(race, COMBOS[race][1], false, 1, 20)
  for i = 1, math.min(#c.chapters, 3) do
    local before = upTo(c, i, 0):gsub("\n\n", " ")
    for k = 1, #c.chapters[i].log do
      local now = upTo(c, i, k):gsub("\n\n", " ")
      local kept = before:match("^(.*[%.!%?]\"?) [^%.!%?]*[%.!%?]\"?$") or ""
      if now:sub(1, #kept) ~= kept then problem(race .. " chapter " .. i, "a finished sentence changed at moment " .. k, before .. "\n => " .. now) break end
      before = now
    end
  end
end

-- Every sentence must be reachable by some life.
local unused = {}
for kind, list in pairs(ns.data.writing) do
  for i, s in ipairs(list) do
    if not ns.writerUsed[kind .. "#" .. i] then table.insert(unused, kind .. ": " .. s[1]) end
  end
end
table.sort(unused)
for _, u in ipairs(unused) do problem("never written", "unreachable sentence", u) end

-- Words and plurals.
local function eq(a, b, what) if a ~= b then problem("words", what, tostring(a) .. " ~= " .. tostring(b)) end end
eq(ns.words(1), "one", "1"); eq(ns.words(21), "twenty-one", "21"); eq(ns.words(115), "a hundred and fifteen", "115")
eq(ns.plural("Ragged Young Wolf"), "Ragged Young Wolves", "wolf"); eq(ns.plural("Bloodfeather Harpy"), "Bloodfeather Harpies", "harpy")
eq(ns.plural("Servant of Arugal"), "Servants of Arugal", "of"); eq(ns.plural("Watchman"), "Watchmen", "man")
eq(ns.plural("Frostmane Shaman"), "Frostmane Shamans", "shaman"); eq(ns.plural("Mud Thresh"), "Mud Threshes", "thresh")
eq(ns.plural("Rotting Dead"), "Rotting Dead", "dead")
eq(ns.things("Crag Boar Rib"), "Crag Boar Ribs", "ribs"); eq(ns.things("Tough Wolf Meat"), "Tough Wolf Meat", "meat")
eq(ns.things("Shimmerweed"), "Shimmerweed", "weed"); eq(ns.things("Linen Cloth"), "Linen Cloth", "cloth"); eq(ns.plural("Kobold Vermin"), "Kobold Vermin", "vermin")
eq(ns.itemName("Wolf Fang Necklace"), "a Wolf Fang Necklace", "a"); eq(ns.itemName("Cuirboulle Gloves"), "Cuirboulle Gloves", "plural")
eq(ns.itemName("Smite's Mighty Hammer"), "Smite's Mighty Hammer", "possessive"); eq(ns.itemName("Blackened Defias Armor"), "Blackened Defias Armor", "mass")
eq(ns.playedWords(7170), "two hours", "1h59 is two hours"); eq(ns.playedWords(3600 + 58 * 60), "two hours", "1h58")
eq(ns.playedWords(1500), "twenty-five minutes", "25 min"); eq(ns.playedWords(5400), "an hour and a half", "1h30")
eq(ns.playedWords(9000), "two hours and a half", "2h30"); eq(ns.goldWords(12345), "a gold piece", "1g")

io.write(("%d books, %d chapters, %d sentences repeated (%.1f per book), longest chapter %d characters\n")
  :format(books, chapters, repeats, repeats / books, longest))
local kinds = {}
for kind, gap in pairs(gaps) do table.insert(kinds, ("%s %d"):format(kind, gap)) end
table.sort(kinds)
io.write("fewest uses of a kind between two uses of one of its sentences: " .. table.concat(kinds, ", ") .. "\n")
for kind, gap in pairs(gaps) do
  if gap < 6 then problem("repeats", "a sentence of " .. kind .. " used again after " .. gap .. " uses of its kind", "") end
end
if #problems > 0 then
  io.write(table.concat(problems, "\n") .. "\n")
  os.exit(1)
end
io.write("all good (writer)\n")
