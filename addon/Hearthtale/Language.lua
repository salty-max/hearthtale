-- The writer's language: numbers and lists in words, places, plurals,
-- articles, items, tasks, what a foe or a thing is. Pure helpers, no state.
-- (Language.lua, Lines.lua, Scene.lua and Writer.lua make the writer.)
local _, ns = ...
local W = {} -- what the writer's files share (each adds its own at its end)
ns.writer = W

local floor = math.floor

-- Words written as text: a list, in order, split at commas and line ends
-- ("Murloc, Vile Fin"); a set (each word of "Valley Temple Hall" true); and
-- named lists, a line each ("murloc: Murloc, Vile Fin").
local function list(text)
  local out = {}
  for item in text:gmatch("[^,\n]+") do
    item = item:match("^%s*(.-)%s*$")
    if item ~= "" then out[#out + 1] = item end
  end
  return out
end
local function set(text)
  local out = {}
  for word in text:gmatch("%S+") do
    out[word] = true
  end
  return out
end
local function named(text)
  local out, last = {}, nil
  for line in text:gmatch("[^\n]+") do
    local name, items = line:match("^%s*(%w+):%s*(.*)$")
    if name then
      last = { name, list(items) }
      out[#out + 1] = last
    elseif last then -- (a long list, carried on)
      for _, item in ipairs(list(line)) do
        table.insert(last[2], item)
      end
    end
  end
  return out
end

-- ── words ────────────────────────────────────────────────────────────────────
local ONES = list([[
  one, two, three, four, five, six, seven, eight, nine, ten, eleven, twelve, thirteen, fourteen,
  fifteen, sixteen, seventeen, eighteen, nineteen
]])
local TENS = {
  [2] = "twenty",
  [3] = "thirty",
  [4] = "forty",
  [5] = "fifty",
  [6] = "sixty",
  [7] = "seventy",
  [8] = "eighty",
  [9] = "ninety",
}
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

local function listing(items)
  if #items == 0 then return nil end
  if #items == 1 then return items[1] end
  return table.concat(items, ", ", 1, #items - 1) .. " and " .. items[#items]
end

-- A name inside a sentence: "The Barrens" reads "the Barrens", and a place
-- the game names without its article reads with it ("the Valley of Strength").
local COMMON = set([[
  Valley Temple Hall Halls Ring Cleft Vale Den Field Fields Isle Ruins Tower Gate Gates Shrine Sanctum
  Caverns Court Terrace Pools Circle
]])
local TRAILING = { District = true, Quarter = true } -- "the Dwarven District", "the Mage Quarter"
local function mid(name)
  if not name then return nil end
  -- as the game itself writes it (Names.lua), else by the rules below
  local known = ns.names
  if known and known.placeThe[name] then return "the " .. name end
  if known and known.placeBare[name] then return name end
  local first = name:match("^(%a+) of ")
  if first and COMMON[first] then return "the " .. name end
  if TRAILING[name:match("(%a+)$") or ""] and not name:find("^The ") then return "the " .. name end
  return (name:gsub("^The ", "the "))
end

local IRREGULAR = {
  Wolf = "Wolves",
  Thief = "Thieves",
  Elf = "Elves",
  Dwarf = "Dwarves",
  Man = "Men",
  Woman = "Women",
  Mouse = "Mice",
  Sheep = "Sheep",
  Deer = "Deer",
  Shaman = "Shamans",
  Undead = "Undead",
  Dead = "Dead",
  Vermin = "Vermin",
  Wildkin = "Wildkin",
  Moonkin = "Moonkin",
  Dragonkin = "Dragonkin",
  Salmon = "Salmon",
  Trout = "Trout",
  Moose = "Moose",
  Kin = "Kin",
  Wolfkin = "Wolfkin",
  Spawn = "Spawn",
  Fish = "Fish",
}
local function plural(name)
  local head, tail = name:match("^(.-)( of .+)$")
  if head then return plural(head) .. tail end
  local before, last = name:match("^(.-)(%S+)$")
  if IRREGULAR[last] then return before .. IRREGULAR[last] end
  if last:match("fish$") then return name end -- "Queenfish", like "Fish"
  if last:match("[^aeiouAEIOU]y$") then return before .. last:sub(1, -2) .. "ies" end
  if last:match("ss$") or last:match("[xz]$") or last:match("[cs]h$") then return name .. "es" end
  if last:match("s$") then return name end -- already many: "Scavenged Goods"
  if last:match("[a-z]man$") then return before .. last:sub(1, -4) .. "men" end
  return name .. "s"
end

-- Words for what can't be counted ("Linen Cloth", "Tough Wolf Meat").
local UNCOUNTED = set([[
  Meat Cloth Leather Silk Wool Ore Water Oil Blood Moss Sand Ash Powder Venom Ichor Dust Silver Gold
  Iron Copper Bark Mail Grain Barley Rye Corn
]])
-- An item: "a Wolf Fang Necklace", but "Cuirboulle Gloves", "Blackened Defias
-- Armor", "Smite's Mighty Hammer".
local TROPHY = { Head = true, Skull = true, Heart = true, Scalp = true }
local MASS = set([[
  Armor Mail Garb Attire Regalia Raiment Plate Leather
]])
local TITLES = set([[
  Mr Mrs Captain Lord Lady King Queen Prince Princess Baron Baroness General Commander Chief Overlord
  Archmage Foreman Sergeant Lieutenant Marshal Master Archivist Magus Khan Emperor Brother Sister
  Father Mother Gatekeeper Jailor Taskmaster Watcher Acolyte Ambassador Engineer Boss Apothecary
  Deathguard Guard Huntsman Rifleman Miner Protector Cannoneer Grunt Scout Priestess Bloodlord
  Battleguard Warchief Admiral Inquisitor Chieftain Colonel Farmer Geomancer Lorekeeper Private
  Tinkerer Advisor Old Ol Ranger Broodlord Pyroguard Archbishop Bishop Crier Emissary Emmisary Matron
  Herald Courier Warlord Highlord Count Duke Magistrate
]])
-- A moment's first objective, as recorded. One whose name the game hadn't
-- filled in yet when it was recorded ("0" by 0.5.0, " " by 0.5.1: an item
-- not loaded) has no real name: not told.
local function objectiveOf(m)
  local o = m.objectives and m.objectives[1]
  if o and o.name and (o.name:match("^%d+$") or not o.name:find("%S")) then return nil end
  return o
end

local function itemName(name)
  -- one the game never counts ("8 Linen Cloth"): no article, but for a
  -- word that is its own plural ("an Explosive Sheep")
  local known = ns.names and ns.names.plural[name]
  if known == name and not name:find("s$") and not IRREGULAR[name:match("(%a+)$") or ""] then return name end
  -- its own article: "An Unsent Letter" reads "an Unsent Letter"
  local own = name:match("^(An?) ") or name:match("^(The) ")
  if own then return own:lower() .. name:sub(#own + 1) end
  -- a trophy: "Head of VanCleef" is VanCleef's head
  local part, whose = name:match("^(%a+) of (.+)$")
  if part and TROPHY[part] then return whose .. "'s " .. part:lower() end
  -- the thing itself, before an "of": "Chausses of Westfall" are many
  local last = (name:match("^(.-) of ") or name):match("(%S+)$")
  if not last then return name end
  -- a person's ("Zanzil's Seal") is named; a role's ("Champion's Helm") is not
  -- (an owner opening the name: "Book from Sven's Farm" is a book)
  local head = name:match("^(.-) %l") or name
  local owner = head:match("(%a+)'s ") or head:match("(%a+s)' ")
  -- (a title before the owner makes a person of it: "Baron Longshore's Head")
  local titled = owner and TITLES[head:match("(%a+)%.? " .. owner .. "'s ") or ""]
  if owner and (titled or not (ns.names and ns.names.roles[owner])) then return name end
  if last:match("s$") or MASS[last] or UNCOUNTED[last] then return name end
  return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end

-- Things in numbers: "six Crag Boar Ribs", but "eight Tough Wolf Meat" (a
-- name that can't be counted stays as it is).
local function things(name)
  -- as the game writes it after a number (Names.lua), else by the rules
  local known = ns.names and ns.names.plural[name]
  if known then return known end
  local last = name:match("(%S+)$")
  if not last then return name end
  if name:find("'s ") or UNCOUNTED[last] or last:find("weed$") or last:find("moss$") or last:find("dust$") then
    return name
  end
  return plural(name)
end

-- A creature named in passing: "a Frostmane Novice". The game can't tell a
-- named creature from a common one, so only rares go without (by their name).
-- (a title is a name of its own: "Mr. Smite", "Captain Greenskin")
local function article(name)
  if not name then return nil end
  -- a title before a name ("Brother Ravenoak"), not the name alone ("Guard")
  if TITLES[name:match("^(%a+)") or ""] and name:find(" ") then return name end
  if name:find("^The ") then return "the " .. name:sub(5) end -- "The Evalcharr"
  -- as the game itself writes it (Names.lua): a person, or one of a kind
  local known = ns.names
  if known and known.creatureBare[name] then return name end
  if known and known.creatureThe[name] then return "the " .. name end
  -- a name of its own: "Targorr the Dread", "Rhahk'Zor"
  if name:find(" the ") or name:find("^%u%a*'%a+$") then return name end
  return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end

-- Kinds worth a "first of its kind" (the game's English names; people are
-- not a kind, critters are not a fight, and a beast without a family is
-- just a beast).
local KINDS = {
  Wolf = "wolves",
  Cat = "great cats",
  Spider = "spiders",
  Bear = "bears",
  Boar = "boars",
  Crocolisk = "crocolisks",
  ["Carrion Bird"] = "carrion birds",
  Crab = "crabs",
  Gorilla = "gorillas",
  Raptor = "raptors",
  Tallstrider = "tallstriders",
  Scorpid = "scorpids",
  Turtle = "turtles",
  Bat = "bats",
  Hyena = "hyenas",
  Owl = "owls",
  ["Wind Serpent"] = "wind serpents",
  Serpent = "serpents",
  Dragonhawk = "dragonhawks",
  Ravager = "ravagers",
  ["Warp Stalker"] = "warp stalkers",
  Sporebat = "sporebats",
  ["Nether Ray"] = "nether rays",
  Undead = "undead",
  Elemental = "elementals",
  Demon = "demons",
  Dragonkin = "dragonkin",
  Giant = "giants",
  Mechanical = "constructs",
}
local SKIP = { Critter = true, ["Non-combat Pet"] = true, Totem = true, ["Not specified"] = true, ["Gas Cloud"] = true }
-- Creature families a remark may speak of the teeth of.
local TEETH = { Wolf = true, Cat = true, Bear = true, Boar = true, Crocolisk = true, Raptor = true }
-- Creature types that are not beasts (a beast's kind is "Beast" or its family).
local NOT_BEAST = set([[
  Humanoid Undead Elemental Demon Dragonkin Giant Mechanical Critter Aberration
]])

-- What killed me, as tags and the {foe} slot: a player by name, a rare or a
-- boss by name, any other creature with an article.
local function deathTags(d)
  local t = { [d.cause or "foe"] = true }
  if d.cause == "foe" then
    if d.player then
      t.player = true
    elseif d.kind == "Humanoid" then
      t.people = true
    elseif d.kind and not NOT_BEAST[d.kind] then
      t.beast = true
    end
    if d.rank == "elite" or d.rank == "rareelite" or d.rank == "worldboss" then t.elite = true end
  end
  if d.inside then t.inside = true end
  return t
end
-- A named elite goes without an article: the game can't tell one from a common
-- elite, but a one-word name is a name (Stitches, Hogger), where "a Defias
-- Overseer" keeps its article.
local function namedElite(name) return name and not name:find(" ") and name:match("^%u") ~= nil end
local function deathFoe(d)
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
  if r >= 45 then
    h, r = h + 1, 0
  end
  if h >= 24 then
    local d = floor(h / 24 + 0.5)
    return d == 1 and "a whole day" or words(d) .. " days"
  end
  return words(h) .. " hours" .. ((r >= 15 and r < 45) and " and a half" or "")
end

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

local function capitalise(text)
  text = text:gsub("^(%W*)(%l)", function(p, c) return p .. c:upper() end)
  return (text:gsub('([%.!%?]"? +%W*)(%l)', function(p, c) return p .. c:upper() end))
end

-- ── the voice ────────────────────────────────────────────────────────────────
local FACTION = {
  Human = "alliance",
  Dwarf = "alliance",
  NightElf = "alliance",
  Gnome = "alliance",
  Draenei = "alliance",
  Orc = "horde",
  Troll = "horde",
  Tauren = "horde",
  Scourge = "horde",
  BloodElf = "horde",
}
local HOME = {
  Human = "Stormwind",
  Dwarf = "Ironforge",
  Gnome = "Ironforge",
  NightElf = "Darnassus",
  Draenei = "the Exodar",
  Orc = "Orgrimmar",
  Troll = "Sen'jin Village",
  Tauren = "Thunder Bluff",
  Scourge = "the Undercity",
  BloodElf = "Silvermoon",
}
local KIN = {
  Human = "my people",
  Dwarf = "my kin",
  Gnome = "my fellow gnomes",
  NightElf = "my kin",
  Draenei = "my people",
  Orc = "my clan",
  Troll = "the Darkspear",
  Tauren = "my tribe",
  Scourge = "the Forsaken",
  BloodElf = "my people",
  Skyborne = "the shen'dorei",
}
local FAITH_RACE = {
  Human = "the Light",
  Dwarf = "the Light",
  Draenei = "the Light",
  NightElf = "Elune",
  Tauren = "the Earth Mother",
  Troll = "the loa",
  Orc = "the ancestors",
}
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

-- The other side's people, as a sentence names them ("a night elf hunter").
local RACE_NAME = {
  Human = "human",
  Dwarf = "dwarf",
  NightElf = "night elf",
  Gnome = "gnome",
  Draenei = "draenei",
  Orc = "orc",
  Troll = "troll",
  Tauren = "tauren",
  Scourge = "Forsaken",
  BloodElf = "blood elf",
}
local HORDE_RACE = { Orc = true, Troll = true, Tauren = true, Scourge = true, BloodElf = true }
local CLASS_NAME = {
  WARRIOR = "warrior",
  PALADIN = "paladin",
  HUNTER = "hunter",
  ROGUE = "rogue",
  PRIEST = "priest",
  SHAMAN = "shaman",
  MAGE = "mage",
  WARLOCK = "warlock",
  DRUID = "druid",
}

-- The last masters of the dungeons and raids: their fall is a sentence of its own.
local FINAL = {}
local DUNGEON_ENDS = list([[
  Taragaman the Hungerer, Mutanus the Devourer, Edwin VanCleef, Archmage Arugal, Aku'mai, Bazil Thredd,
  Mekgineer Thermaplugg, Charlga Razorflank, Herod, Arcanist Doan, Bloodmage Thalnos,
  High Inquisitor Whitemane, Amnennar the Coldbringer, Archaedas, Chief Ukorz Sandscalp,
  Princess Theradras, Shade of Eranikus, Emperor Dagran Thaurissan, Overlord Wyrmthalak,
  General Drakkisath, King Gordok, Immol'thar, Prince Tortheldrin, Darkmaster Gandling,
  Baron Rivendare, Balnazzar
]])
local RAID_ENDS = list([[
  Onyxia, Ragnaros, Nefarian, Hakkar, Ossirian the Unscarred, C'Thun, Kel'Thuzad, Prince Malchezaar,
  Gruul the Dragonkiller, Magtheridon, Lady Vashj, Kael'thas Sunstrider, Archimonde, Illidan Stormrage,
  Zul'jin, Kil'jaeden
]])
for _, ends in ipairs({ DUNGEON_ENDS, RAID_ENDS }) do
  for _, name in ipairs(ends) do
    FINAL[name] = true
  end
end

-- What a remark may be about. Ordered: the first match wins.
-- A foe's people, from the name the game gives it (a humanoid only: a
-- "Vilebranch Wolf Pup" is a wolf), else its kind.
local FOE_PEOPLE = named([[
  murloc: Murloc, Vile Fin, Greymist
  kobold: Kobold, Tunnel Rat
  gnoll: Gnoll, Riverpaw, Redridge, Mosshide, Rot Hide, Mudsnout, Shadowhide, Hogger, Woodpaw, Wildpaw
  harpy: Harpy, Windfury, Bloodfeather, Witchwing, Wind Witch, Dustfeather
  quilboar: Quilboar, Razormane, Bristleback, Razorfen, Death's Head
  centaur: Kolkar, Galak, Magram, Gelkis, Maraudine, Centaur
  ogre: Ogre, Dustbelcher, Boulderfist, Mo'grosh, Gordunni, Gorsh, Splinterfist, Dunemaul, Crushridge,
        Mosh'Ogg
  troll: Frostmane, Bloodscalp, Skullsplitter, Witherbark, Vilebranch, Mossflayer, Smolderthorn,
         Sandfury, Hakkari, Gurubashi
  naga: Naga, Slitherblade, Spitelash, Daggerspine, Strashaz, Hatecrest
  satyr: Satyr, Hatefury, Bleakheart, Xavian, Haldarr, Legashi
  furbolg: Furbolg, Gnarlpine, Timbermaw, Foulweald, Thistlefur, Deadwood, Blackwood, Winterfall
  trogg: Trogg, Rockjaw, Stonesplinter, Stonevault
  outlaw: Defias, Syndicate, Bandit, Brigand, Southsea, Bloodsail, Pirate, Highwayman, Venture Co,
          Smuggler, Cutthroat, Wastewander
  scarlet: Scarlet
]])
local FOE_KIND =
  { Undead = "undead", Demon = "demon", Elemental = "elemental", Dragonkin = "dragonkin", Spider = "spider" }
local function foeOf(name, kind)
  if FOE_KIND[kind or ""] then return FOE_KIND[kind] end
  if not name or (kind and kind ~= "Humanoid") then return nil end
  for _, people in ipairs(FOE_PEOPLE) do
    for _, word in ipairs(people[2]) do
      if name:find(word, 1, true) then return people[1] end
    end
  end
end
-- What a thing found is, from its name: a word of it ("Silithid Egg").
local THING_KIND = named([[
  stone: Ore, Stone, Crystal, Rock, Gem, Shard, Pebble, Geode, Nugget
  egg: Egg
  feather: Feather, Plume, Quill
  hide: Hide, Pelt, Fur, Skin, Leather, Scale
  paper: Letter, Note, Journal, Book, Tome, Page, Plans, Orders, Map, Document, Report, Manual, Scroll,
         Ledger, Diary, Missive, Papers, Writ, Contract, Manifest, Parchment
  plant: Herb, Flower, Bloom, Petal, Root, Leaf, Moss, Mushroom, Fungus, Shroom, Weed, Lotus, Thistle,
         Briar, Seed, Bark, Lily, Blossom, Sprout, Cactus, Vine, Frond, Bulb
  relic: Relic, Idol, Artifact, Statue, Statuette, Fragment, Tablet, Carving, Totem, Figurine, Rune
  remains: Bone, Skull, Claw, Fang, Tooth, Teeth, Tusk, Horn, Heart, Eye, Tail, Ear, Paw, Talon, Gland,
           Sac, Blood, Ichor, Mane, Brain, Tongue, Wing, Head, Scalp, Hoof, Spine, Venom, Snout, Beak,
           Mandible, Tentacle, Liver, Flesh, Rib
]])
local function thingOf(name)
  if not name then return nil end
  for _, kind in ipairs(THING_KIND) do
    for _, word in ipairs(kind[2]) do
      if name:find("%f[%a]" .. word .. "e?s?%f[%A]") then return kind[1] end
      -- (a plant's name is often one word: "Earthroot", "Peacebloom")
      if kind[1] == "plant" and name:find("%l" .. word:lower() .. "s?%f[%A]") then return kind[1] end
    end
  end
end

local function town(node) return node and (node:match("^([^,]+)") or node) end

-- The chapter's kills, the most first (for the closing recap).
local function topKills(kills)
  local top = {}
  for name, n in pairs(kills or {}) do
    table.insert(top, { name = name, n = n })
  end
  table.sort(top, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.name < b.name
  end)
  return top
end

-- A quest, told by what it asked: so many of a creature slain, so many of a
-- thing brought, a task, a message carried to another (a clause); else only
-- who asked; a quest with nothing but its title goes untold.
-- An objective the log writes as an instruction ("Burn the Highvale Notes")
-- reads as a task done; one that names a result ("Banner Destroyed", "Flame
-- of Stratholme", "Attack Plan: Orgrimmar destroyed") can't follow "I
-- managed to", and the quest is told by who asked. (Checked against every
-- objective of the game: addon/test/audit.lua.)
local INSTRUCTIONS = set([[
  accept activate ask assist attack awaken banish break bring build burn bury calm capture catch check
  chart cleanse climb close collect convince cook craft cure defeat defend deliver descend destroy dig
  discover douse drop enter escort examine excavate explore extinguish feed find fly follow free
  gather guard harvest heal help hunt ignite inspect interrogate investigate kill learn light locate
  lure mark obtain observe open persuade place plant protect purge purify question raise reach read
  recover recruit release repair rescue retrieve return revive ride sabotage save scare scout search
  set shatter shut slay smash speak spy steal study summon survive take talk tame test throw toss
  track trap travel uncover unearth unlock use view visit wake warn witness%a+
]])
-- The hand-in a quest's text may end with ("… and speak to Branstock
-- Khalder"): the return, told as such, not part of the task.
local HAND_IN = { "speak", "talk", "report", "return" }
local function handIn(text)
  local lower = text:lower()
  for _, verb in ipairs(HAND_IN) do
    if lower:find("^" .. verb .. " to ") and not lower:find(" and ") then return true end
  end
  return false
end
local function instruction(text)
  if handIn(text) then return false end -- only the return: a word carried
  return INSTRUCTIONS[(text:match("^(%a+)") or ""):lower()] and not text:find("[:?]") or false
end
local function lowerFirst(text) return (text:gsub("^%u", string.lower)) end
-- An objective as a task done: "Escort The Defias Traitor to discover where
-- VanCleef is hiding" is "escort the Defias Traitor to discover where
-- VanCleef was hiding".
local function taskOf(text)
  text = text:gsub("[%.:]%s*$", "")
  for _, verb in ipairs(HAND_IN) do
    text = text:gsub(",? and " .. verb .. " to .+$", ""):gsub(",? then " .. verb .. " to .+$", "")
  end
  return (lowerFirst(text):gsub(" The ", " the "):gsub(" is ", " was "):gsub(" are ", " were "))
end

-- A sentence with its link before it ("That night, I..."), if it begins with
-- "I", "My" or an article.
-- A sentence's first word a link may come before ("Afterwards, the road…",
-- "Later, six Defias…"): not a name, which keeps its capital and no link.
local OPENERS = { My = true, A = true, An = true, The = true, It = true, There = true }
local NUMBER_WORDS = set([[
  two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen
  seventeen eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety%a+
]])
local function linked(word, text)
  if not word then return text end
  local head, rest = text:match("^(%a+)( .*)$")
  if not head or not (head == "I" or OPENERS[head] or NUMBER_WORDS[head:lower()]) then return text end
  if head ~= "I" then head = head:lower() end
  return word .. " " .. head .. rest
end

-- The rank a profession's trainer gives: "an apprentice", "a journeyman".
local function rankName(rank) return rank and ((rank:match("^[aeiou]") and "an " or "a ") .. rank) end

-- (for the next files of the writer)
W.floor = floor
W.words = words
W.listing = listing
W.mid = mid
W.plural = plural
W.TROPHY = TROPHY
W.TITLES = TITLES
W.objectiveOf = objectiveOf
W.itemName = itemName
W.things = things
W.article = article
W.KINDS = KINDS
W.SKIP = SKIP
W.TEETH = TEETH
W.deathTags = deathTags
W.namedElite = namedElite
W.deathFoe = deathFoe
W.playedWords = playedWords
W.goldWords = goldWords
W.capitalise = capitalise
W.FACTION = FACTION
W.HOME = HOME
W.KIN = KIN
W.faith = faith
W.weapon = weapon
W.RACE_NAME = RACE_NAME
W.HORDE_RACE = HORDE_RACE
W.CLASS_NAME = CLASS_NAME
W.FINAL = FINAL
W.FOE_PEOPLE = FOE_PEOPLE
W.FOE_KIND = FOE_KIND
W.foeOf = foeOf
W.THING_KIND = THING_KIND
W.thingOf = thingOf
W.town = town
W.topKills = topKills
W.instruction = instruction
W.lowerFirst = lowerFirst
W.taskOf = taskOf
W.linked = linked
W.rankName = rankName
