-- The writer test: writes the books of many imaginary lives (every race and
-- class, Hardcore or not, met at level 1 or mid-life) and checks every
-- chapter: slots all filled, sentences capitalised and closed, no stray
-- spaces or doubled words, every sentence of writing/ reachable, few repeats.
--   luajit addon/test/writer.lua            the checks
--   luajit addon/test/writer.lua --sample   one book, as Markdown (docs/sample.md)
local DIR = "addon/WayfarersJournal/"
local SAMPLE = arg[1] == "--sample"
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
local SPELLS = { "Blessing of Might", "Judgement", "Hammer of Justice", "Frostbolt", "Fireball", "Sinister Strike", "Shadow Word: Pain",
  "Lightning Bolt", "Corruption", "Serpent Sting", "Rejuvenation", "Battle Shout", "Rend", "Arcane Intellect" }
local SKILLS = { "Mining", "Herbalism", "Skinning", "First Aid", "Blacksmithing", "Tailoring", "Cooking" }
local ITEMS = { "Wolf Fang Necklace", "Frostmane Leather Vest", "Cuirboulle Gloves", "Smite's Mighty Hammer", "Blackened Defias Armor", "Feline Mantle" }
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

local guid = 0
local function life(race, class, hc, from, to)
  guid = guid + 1
  local c = { guid = ("Player-1-%08X"):format(guid), name = one({ "Sealinedion", "Brannor", "Kelsa", "Thrudd", "Ylena", "Morgrim" }), race = race, class = class, hardcore = hc or nil, began = { level = from }, levels = {} }
  if from > 1 then
    c.prologue = { level = from, quests = chance(0.9) and rand(5, 200) or 0, inn = one({ "Goldshire", "Kharanos", "Brill", nil }),
      zone = one(ZONES)[1], played = chance(0.6) and rand(3000, 400000) or nil }
  end
  local zone = from == 1 and zoneNamed(START[race]) or one(ZONES)
  local sub = zone[2][1]
  local seen = {}
  local kinds = {}
  for n = from, to do
    local l = { start = { zone = zone[1], sub = chance(0.85) and sub or nil, night = chance(0.35) },
      played = rand(300, 9000), gold = rand(0, 3) == 0 and 0 or rand(5, 40000),
      places = {}, quests = {}, kills = {}, rares = {}, closeCalls = {}, company = {}, dungeons = {}, learned = {}, skills = {}, flights = {} }
    if n < to or chance(0.5) then l.ended = true end
    if chance(0.3) then zone = one(ZONES) end
    for _ = 1, rand(0, 4) do
      sub = one(zone[2])
      if not seen[sub] then
        seen[sub] = true
        table.insert(l.places, { zone = zone[1], sub = sub })
      end
    end
    local titles = {}
    for _ = 1, rand(0, 9) do
      local title = one(QUESTS)
      if not titles[title] then
        titles[title] = true
        table.insert(l.quests, { title = chance(0.95) and title or nil, giver = chance(0.7) and one(GIVERS) or nil })
      end
    end
    for _ = 1, rand(0, 4) do
      local cr = one(CREATURES)
      local first = not kinds[cr[2]] or nil
      kinds[cr[2]] = true
      l.kills[cr[1]] = { n = rand(1, 30), kind = cr[2], first = first, elite = chance(0.08) or nil, where = chance(0.9) and sub or nil }
    end
    if chance(0.12) then table.insert(l.rares, { name = one(RARES), sub = sub, zone = zone[1], elite = chance(0.3) or nil }) end
    if chance(0.25) then
      table.insert(l.closeCalls, { foe = chance(0.8) and one(CREATURES)[1] or nil, hp = rand(1, 9), sub = sub, zone = zone[1], night = chance(0.4) })
    end
    if chance(0.25) then for _ = 1, rand(1, 4) do l.company[one(MATES)] = "WARRIOR" end end
    if chance(0.12) then
      local d = one(DUNGEONS)
      local bosses = {}
      for i = 1, rand(0, #d[2]) do bosses[i] = d[2][i] end
      table.insert(l.dungeons, { name = d[1], bosses = bosses })
    end
    if n % 2 == 0 then
      local spells = {}
      for _ = 1, rand(0, 5) do
        local s = one(SPELLS)
        if not spells[s] then spells[s] = true; table.insert(l.learned, s) end
      end
    end
    if chance(0.2) then table.insert(l.skills, { name = one(SKILLS), rank = one({ 50, 75, 100, 150, 200, 225, 250, 300 }) }) end
    if chance(0.35) then l.loot = { link = "|cff1eff00|Hitem:1|h[" .. one(ITEMS) .. "]|h|r", quality = 2 } end
    if chance(0.1) then l.inn = { place = one(zone[2]) } end
    if not hc and chance(0.1) then l.deaths = { death(n, zone[1], sub) } end
    if chance(0.15) then
      local a = rand(#NODES)
      table.insert(l.flights, { from = NODES[a], to = NODES[a % #NODES + 1] })
    end
    c.levels[n] = l
  end
  c.visited = {}
  for _, z in ipairs(ZONES) do if chance(0.3) then c.visited[z[1] .. "|"] = true end end
  -- Most Hardcore lives here end: the last level's death closes the book.
  if hc and chance(0.7) then
    c.death = death(to, zone[1], sub)
    c.levels[to].deaths = { c.death }
    c.closed = true
  end
  return c
end

-- ── the sample: a life as the game would record it ───────────────────────────
if SAMPLE then
  local DM, LM = "Dun Morogh", "Loch Modan"
  local function lv(t)
    t.played, t.gold, t.ended = t.played or 1800, t.gold or 0, true
    for _, k in ipairs({ "places", "quests", "rares", "closeCalls", "dungeons", "learned", "skills", "flights" }) do t[k] = t[k] or {} end
    t.kills, t.company = t.kills or {}, t.company or {}
    return t
  end
  local function q(title, giver) return { title = title, giver = giver } end
  local c = { guid = "Player-1-SAMPLE", race = "Dwarf", class = "PALADIN", hardcore = true, began = { level = 1 }, levels = {
    [1] = lv({ start = { zone = DM, sub = "Anvilmar" }, played = 1320, gold = 45,
      quests = { q("Dwarven Outfitters", "Sten Stoutarm"), q("A New Threat", "Balir Frosthammer") },
      kills = { ["Ragged Young Wolf"] = { n = 6, kind = "Wolf", first = true, where = "Coldridge Valley" },
        ["Rockjaw Trogg"] = { n = 9, kind = "Humanoid", where = "Coldridge Valley" } } }),
    [2] = lv({ start = { zone = DM, sub = "Coldridge Valley" }, played = 1500, gold = 120,
      quests = { q("Coldridge Valley Mail Delivery", "Balir Frosthammer") },
      kills = { ["Burly Rockjaw Trogg"] = { n = 12, kind = "Humanoid", where = "Coldridge Valley" } } }),
    [3] = lv({ start = { zone = DM, sub = "Coldridge Valley" }, played = 2280, gold = 210,
      quests = { q("The Troll Cave", "Felix Whindlebolt"), q("The Stolen Journal", "Felix Whindlebolt") },
      kills = { ["Frostmane Troll Whelp"] = { n = 14, kind = "Humanoid", where = "Coldridge Valley" } },
      closeCalls = { { foe = "Frostmane Troll Whelp", hp = 9, zone = DM, sub = "Coldridge Valley" } } }),
    [4] = lv({ start = { zone = DM, sub = "Coldridge Valley", night = true }, played = 2460, gold = 300,
      places = { { zone = DM, sub = "Coldridge Pass" } }, learned = { "Blessing of Might", "Judgement" },
      quests = { q("Senir's Observations", "Mountaineer Thalos") },
      kills = { ["Frostmane Novice"] = { n = 8, kind = "Humanoid", where = "Coldridge Pass" } } }),
    [5] = lv({ start = { zone = DM, sub = "Coldridge Pass" }, played = 3120, gold = 520,
      places = { { zone = DM, sub = "Kharanos" } }, inn = { place = "Thunderbrew Distillery" },
      quests = { q("Scalding Mornbrew Delivery", "Nori Pridedrift"), q("Beer Basted Boar Ribs", "Ragnar Thunderbrew"),
        q("The Boar Hunter", "Talin Keeneye"), q("Tools for Steelgrill", "Beldin Steelgrill") },
      kills = { ["Small Crag Boar"] = { n = 10, kind = "Boar", first = true, where = "Kharanos" },
        ["Ragged Timber Wolf"] = { n = 7, kind = "Wolf", where = "Kharanos" } } }),
    [6] = lv({ start = { zone = DM, sub = "Kharanos" }, played = 3900, gold = 700,
      places = { { zone = DM, sub = "Brewnall Village" }, { zone = DM, sub = "Steelgrill's Depot" } },
      quests = { q("Bitter Rivals", "Rejold Barleybrew"), q("Ammo for Rumbleshot", "Loslor Rudge") },
      kills = { ["Leper Gnome"] = { n = 11, kind = "Humanoid", where = "Brewnall Village" } },
      learned = { "Divine Protection", "Seal of the Crusader" }, skills = { { name = "Mining", rank = 50 } } }),
    [7] = lv({ start = { zone = DM, sub = "Kharanos", night = true }, played = 4200, gold = 900,
      places = { { zone = DM, sub = "Shimmer Ridge" } }, quests = { q("Frostmane Hold", "Senir Whitebeard") },
      kills = { ["Frostmane Snowstrider"] = { n = 13, kind = "Humanoid", where = "Shimmer Ridge" } },
      loot = { link = "|cff1eff00|Hitem:1|h[Cuirboulle Gloves]|h|r", quality = 2 } }),
    [8] = lv({ start = { zone = DM, sub = "Shimmer Ridge" }, played = 4800, gold = 1100,
      places = { { zone = DM, sub = "Frostmane Hold" }, { zone = DM, sub = "The Grizzled Den" } },
      quests = { q("The Grizzled Den", "Pilot Stonegear"), q("Stocking Jetsteam", "Pilot Stonegear") },
      kills = { ["Wendigo"] = { n = 9, kind = "Humanoid", where = "The Grizzled Den" },
        ["Frostmane Seer"] = { n = 6, kind = "Humanoid", where = "Frostmane Hold" } },
      learned = { "Hammer of Justice", "Purify" } }),
    [9] = lv({ start = { zone = DM, sub = "Kharanos", night = true }, played = 5100, gold = 1400,
      quests = { q("The Perfect Stout", "Rejold Barleybrew"), q("Protecting the Herd", "Rudra Amberstill") },
      kills = { ["Winter Wolf"] = { n = 15, kind = "Wolf", where = "Iceflow Lake" } },
      rares = { { name = "Timber", zone = DM, sub = "Iceflow Lake" } } }),
    [10] = lv({ start = { zone = DM, sub = "Gol'Bolar Quarry" }, played = 5400, gold = 1800,
      quests = { q("Distracting Jarven", "Rejold Barleybrew") },
      kills = { ["Rockjaw Bonesnapper"] = { n = 12, kind = "Humanoid", where = "Gol'Bolar Quarry" } },
      closeCalls = { { foe = "Rockjaw Ambusher", hp = 4, zone = DM, sub = "Gol'Bolar Quarry" } },
      learned = { "Lay on Hands", "Devotion Aura" } }),
    [11] = lv({ start = { zone = DM, sub = "Gol'Bolar Quarry" }, played = 6000, gold = 2100,
      places = { { zone = LM, sub = "North Gate Pass" }, { zone = LM, sub = "Thelsamar" } }, inn = { place = "Thelsamar" },
      quests = { q("Rat Catching", "Mountaineer Kadrell"), q("Thelsamar Blood Sausages", "Vidra Hearthstove") },
      kills = { ["Tunnel Rat Vermin"] = { n = 14, kind = "Humanoid", where = "Silver Stream Mine" },
        ["Mountain Boar"] = { n = 9, kind = "Boar", where = "Thelsamar" } },
      company = { Brannor = "WARRIOR", Kelsa = "PRIEST" } }),
    [12] = { start = { zone = LM, sub = "Thelsamar" }, played = 2000, gold = 600, places = {}, quests = { q("The Tome of Divinity") },
      kills = {}, rares = {}, closeCalls = {}, company = {}, dungeons = {}, learned = {}, skills = { { name = "Mining", rank = 75 } },
      flights = { { from = "Thelsamar, Loch Modan", to = "Ironforge, Dun Morogh" } } },
  } }
  local book = ns.writeBook(c)
  io.write("# Sample: a Hardcore dwarf paladin, levels 1 to 12\n\n")
  io.write("Generated by `luajit addon/test/writer.lua --sample` from a life as the game would record it\n")
  io.write("(level 12 is still being lived: no closing yet).\n\n")
  for _, ch in ipairs(book.chapters) do
    io.write(("## Level %d\n\n%s\n\n"):format(ch.level, ch.text or "(nothing to tell)"))
  end
  return
end

-- ── the checks ───────────────────────────────────────────────────────────────
ns.writerUsed = {}
local problems, books, chapters, repeats, longest = {}, 0, 0, 0, 0
local gaps = {} -- kind = the fewest chapters between two uses of one of its sentences
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
for _, round in ipairs({ { 1, 12 }, { 1, 60 }, { 18, 41 }, { 38, 60 }, { 1, 30 }, { 1, 7 } }) do
  for race, classes in pairs(COMBOS) do
    for _, class in ipairs(classes) do
      for _, hc in ipairs({ true, false }) do
        runs = runs + 1
        local c = life(race, class, hc, round[1], round[2])
        local book = ns.writeBook(c)
        if (c.death ~= nil) ~= (book.epitaph ~= nil) then problem(race .. " " .. class, "a Hardcore death without an epitaph, or the reverse", "") end
        for _, l in pairs(c.levels) do
          if hc and l.deaths and #l.deaths > 0 then
            for _, ch in ipairs(book.chapters) do
              if ch.text and ch.text:find("I died", 1, true) then problem(race .. " " .. class, "a Hardcore death told in the first person", ch.text) end
            end
          end
        end
        books = books + 1
        inspect(race .. " " .. class .. " prologue", book.prologue)
        inspect(race .. " " .. class .. " epitaph", book.epitaph)
        if round[1] > 1 and not book.prologue then problem(race .. " " .. class, "no prologue", "") end
        for _, ch in ipairs(book.chapters) do
          chapters = chapters + 1
          inspect(("%s %s level %d"):format(race, class, ch.level), ch.text)
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
for race, classes in pairs(COMBOS) do
  for _, class in ipairs(classes) do
    for _, level in ipairs({ 5, 20, 45 }) do
      for _ = 1, 4 do
        local c = life(race, class, true, level, level)
        c.death = death(level, "Loch Modan", chance(0.5) and "Thelsamar" or nil)
        if chance(0.2) then c.death.zone, c.death.sub = nil, nil end
        c.levels[level].deaths, c.closed = { c.death }, true
        local book = ns.writeBook(c)
        if not book.epitaph then problem(race .. " " .. class, "a Hardcore death without an epitaph", "") end
        inspect(race .. " " .. class .. " epitaph", book.epitaph)
      end
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
eq(ns.plural("Rotting Dead"), "Rotting Dead", "dead"); eq(ns.plural("Kobold Vermin"), "Kobold Vermin", "vermin")
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
io.write("fewest chapters between two uses of a sentence: " .. table.concat(kinds, ", ") .. "\n")
for kind, gap in pairs(gaps) do
  if gap < 8 then problem("repeats", "a sentence of " .. kind .. " used twice within " .. gap .. " chapters", "") end
end
if #problems > 0 then
  io.write(table.concat(problems, "\n") .. "\n")
  os.exit(1)
end
io.write("all good (writer)\n")
