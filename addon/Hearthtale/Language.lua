-- The writer's language: numbers and lists in words, places, plurals,
-- articles, items, tasks, what a foe or a thing is. Pure helpers, no state.
-- (Language.lua, Lines.lua and Diary.lua make the writer.)
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

-- Where I was, as a sentence says it: "in Westfall", but "on Zephras Isle",
-- "on the Echo Isles" (an island is stood on).
local function at(name)
  if not name then return nil end
  local last = name:match("(%a+)$") or ""
  return ((last == "Isle" or last == "Isles" or last == "Island" or last == "Islands") and "on " or "in ") .. mid(name)
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
  Tooth = "Teeth",
  Foot = "Feet",
  Hoof = "Hooves",
  Leaf = "Leaves",
  Knife = "Knives",
  Deer = "Deer",
  Shaman = "Shamans",
  Undead = "Undead",
  Dead = "Dead",
  Highborne = "Highborne",
  Matriarch = "Matriarchs",
  Patriarch = "Patriarchs",
  Monarch = "Monarchs",
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

-- (words ending in "s" that name one thing: "a Telescopic Lens")
local SINGULAR_S = { Lens = true, Atlas = true, Canvas = true, Gas = true, Chaos = true }

-- Words for what can't be counted ("Linen Cloth", "Tough Wolf Meat").
local UNCOUNTED = set([[
  Meat Cloth Leather Silk Wool Ore Water Oil Blood Moss Sand Ash Powder Venom Ichor Dust Silver Gold
  Iron Copper Bark Mail Grain Barley Rye Corn Pulp Nitroglycerin Salt Flour Ink Rum Ale Wine Honey Tar
  Clay Coal Sap Resin Slime Ooze Mud Lumber
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
  Prospector Battleguard Warchief Admiral Inquisitor Chieftain Colonel Farmer Geomancer Lorekeeper Private
  Tinkerer Advisor Old Ol Ranger Broodlord Pyroguard Archbishop Bishop Crier Emissary Emmisary Matron
  Herald Courier Warlord Highlord Count Duke Magistrate
]])
-- A thing the game never counts ("8 Linen Cloth", "8 Tough Wolf Meat"): its
-- plural is its name (but for a word that is its own plural: "Explosive Sheep").
local function uncounted(name)
  local known = ns.names and ns.names.plural[name]
  if known then return known == name and not name:find("s$") and not IRREGULAR[name:match("(%a+)$") or ""] end
  return UNCOUNTED[name:match("(%a+)$") or ""] or false
end

local function itemName(name)
  -- one the game never counts ("8 Linen Cloth"): no article, but for a
  -- word that is its own plural ("an Explosive Sheep")
  if ns.names and ns.names.plural[name] and uncounted(name) then return name end
  -- its own article: "An Unsent Letter" reads "an Unsent Letter"
  local own = name:match("^(An?) ") or name:match("^(The) ")
  if own then return own:lower() .. name:sub(#own + 1) end
  -- a thing's own part, one of a kind: "the Top of Gelkak's Key"
  local piece = name:match("^(%a+) of ")
  if piece == "Top" or piece == "Middle" or piece == "Bottom" or piece == "Upper" or piece == "Lower" then
    return "the " .. name
  end
  -- a trophy: "Head of VanCleef" is VanCleef's head
  local part, whose = name:match("^(%a+) of (.+)$")
  if part and TROPHY[part] then return whose .. "'s " .. part:lower() end
  -- the thing itself, before an "of": "Chausses of Westfall" are many, and
  -- so are "Supplies for Sven"
  local last = (name:match("^(.-) of ") or name:match("^(.-) for ") or name:match("^(.-) from ") or name):match(
    "(%S+)$"
  )
  if not last then return name end
  -- a person's ("Zanzil's Seal") is named; a role's ("Champion's Helm") is not
  -- (an owner opening the name: "Book from Sven's Farm" is a book)
  local head = name:match("^(.-) %l") or name
  local owner = head:match("(%a+)'s ") or head:match("(%a+s)' ")
  -- (a title before the owner makes a person of it: "Baron Longshore's Head")
  local titled = owner and TITLES[head:match("(%a+)%.? " .. owner .. "'s ") or ""]
  if owner and (titled or not (ns.names and ns.names.roles[owner])) then return name end
  if (last:match("s$") and not SINGULAR_S[last]) or MASS[last] or UNCOUNTED[last] then return name end
  return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
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

-- (not after an abbreviation's stop: "the Venture Co. papers")
local ABBREVIATIONS = { Co = true, Mr = true, Mrs = true, St = true, Dr = true, Jr = true }
local function capitalise(text)
  text = text:gsub("^(%W*)(%l)", function(p, c) return p .. c:upper() end)
  return (
    text:gsub('(%a*)([%.!%?]"? +%W*)(%l)', function(word, p, c)
      if ABBREVIATIONS[word] and p:sub(1, 1) == "." then return word .. p .. c end
      return word .. p .. c:upper()
    end)
  )
end

-- ── the voice ────────────────────────────────────────────────────────────────
local FACTION = {
  Human = "alliance",
  Dwarf = "alliance",
  NightElf = "alliance",
  Gnome = "alliance",
  Orc = "horde",
  Troll = "horde",
  Tauren = "horde",
  Scourge = "horde",
}
local HOME = {
  Human = "Stormwind",
  Dwarf = "Ironforge",
  Gnome = "Ironforge",
  NightElf = "Darnassus",
  Orc = "Orgrimmar",
  Troll = "Sen'jin Village",
  Tauren = "Thunder Bluff",
  Scourge = "the Undercity",
}
local KIN = {
  Human = "my people",
  Dwarf = "my kin",
  Gnome = "my fellow gnomes",
  NightElf = "my kin",
  Orc = "my clan",
  Troll = "the Darkspear",
  Tauren = "my tribe",
  Scourge = "the Forsaken",
  Skyborne = "the shen'dorei",
}
local FAITH_RACE = {
  Human = "the Light",
  Dwarf = "the Light",
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
-- (before a weapon in hand is known: by class, never by race but a dwarf
-- hunter's first gun; then by the weapon held, WEAPON_OF its subclass)
local function weapon(race, class)
  if class == "WARRIOR" then return "my weapon" end
  if class == "HUNTER" then return race == "Dwarf" and "my rifle" or "my bow" end
  return ({ PALADIN = "my hammer", ROGUE = "my dagger", SHAMAN = "my mace" })[class] or "my staff"
end
W.WEAPON_OF = {
  [0] = "my axe",
  [1] = "my axe",
  [2] = "my bow",
  [3] = "my rifle",
  [4] = "my mace",
  [5] = "my mace",
  [6] = "my polearm",
  [7] = "my sword",
  [8] = "my sword",
  [10] = "my staff",
  [13] = "my fists",
  [15] = "my dagger",
  [18] = "my crossbow",
}

-- The other side's people, as a sentence names them ("a night elf hunter").
local RACE_NAME = {
  Human = "human",
  Dwarf = "dwarf",
  NightElf = "night elf",
  Gnome = "gnome",
  Orc = "orc",
  Troll = "troll",
  Tauren = "tauren",
  Scourge = "Forsaken",
}
local HORDE_RACE = { Orc = true, Troll = true, Tauren = true, Scourge = true }
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
  Baron Rivendare, Balnazzar,
  Rath'mael, Durgen Dirgehammer, Relic Guardian
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
  outlaw: Defias, Syndicate, Bandit, Brigand, Southsea, Bloodsail, Pirate, Highwayman, Smuggler,
          Cutthroat, Wastewander
  venture: Venture Co
  scarlet: Scarlet
  cenarion: Cenarius, Cenarion, Keeper Ordanus
]])
local FOE_KIND =
  { Undead = "undead", Demon = "demon", Elemental = "elemental", Dragonkin = "dragonkin", Spider = "spider" }
-- (peoples told by name whatever their kind: a leper gnome is a gnome, the
-- Writhing Highborne are Highborne before they are undead)
local BY_NAME = named([[
  leper: Leper Gnome, Leprous
  highborne: Highborne
  cenarion: Cenarius, Cenarion, Keeper Ordanus
]])
local function foeOf(name, kind)
  for _, people in ipairs(name and BY_NAME or {}) do
    for _, word in ipairs(people[2]) do
      if name:find(word, 1, true) then return people[1] end
    end
  end
  if FOE_KIND[kind or ""] then return FOE_KIND[kind] end
  if not name or (kind and kind ~= "Humanoid") then return nil end
  for _, people in ipairs(FOE_PEOPLE) do
    for _, word in ipairs(people[2]) do
      if name:find(word, 1, true) then return people[1] end
    end
  end
end
-- How a class fights, from what it knows: the spells that make an element of
-- its fighting (the tags of its fighting lines), and what each class fights
-- with from the start (a warlock's first Shadow Bolt, a mage's Fireball).
local ELEMENT = {}
for _, e in
  ipairs(named([[
  fire: Immolate, Fireball, Fire Blast, Searing Pain, Flame Shock, Scorch, Pyroblast, Flamestrike, Rain of Fire,
        Hellfire
  frost: Frostbolt, Cone of Cold, Blizzard, Frost Shock
  arcane: Arcane Missiles, Arcane Explosion
  shadow: Shadow Bolt, Shadow Word: Pain, Mind Blast, Mind Flay, Drain Life, Drain Soul
  curse: Corruption, Curse of Agony, Curse of Weakness, Curse of Recklessness
  holy: Smite, Holy Fire, Exorcism, Holy Shock, Consecration
  lightning: Lightning Bolt, Chain Lightning, Earth Shock
  wrath: Wrath, Insect Swarm
  moon: Moonfire, Starfire
]]))
do
  for _, spell in ipairs(e[2]) do
    ELEMENT[spell] = e[1]
  end
end
local CLASS_FIGHT = {
  WARRIOR = { "steel" },
  ROGUE = { "steel" },
  PALADIN = { "steel" },
  HUNTER = { "arrow" },
  SHAMAN = { "lightning" },
  MAGE = { "fire" },
  PRIEST = { "holy" },
  WARLOCK = { "shadow" },
  DRUID = { "wrath" },
}

-- Whose land a zone is (a people's own: the hosts where another works), and
-- the races with no land of their own and who took them in (gnomes, since
-- Gnomeregan, among the dwarves; the Darkspear among the orcs). The Skyborne's
-- is Zephras Isle (Forever), where they begin.
local HOSTS = {}
for _, h in
  ipairs(named([[
  Dwarf: Dun Morogh, Ironforge, Loch Modan, Anvilmar
  Human: Elwynn Forest, Stormwind City, Westfall, Redridge Mountains, Duskwood
  NightElf: Teldrassil, Darnassus, Darkshore
  Orc: Durotar, Orgrimmar
  Tauren: Mulgore, Thunder Bluff
  Scourge: Tirisfal Glades, Undercity, Silverpine Forest
  Skyborne: Zephras Isle
]]))
do
  for _, zone in ipairs(h[2]) do
    HOSTS[zone] = h[1]
  end
end
local TAKEN_IN = { Gnome = "Dwarf", Troll = "Orc" }

local function lowerFirst(text) return (text:gsub("^%u", string.lower)) end
-- (for the next files of the writer)
W.floor = floor
W.words = words
W.listing = listing
W.mid = mid
W.plural = plural
W.TITLES = TITLES
W.itemName = itemName
W.article = article
W.deathTags = deathTags
W.deathFoe = deathFoe
W.playedWords = playedWords
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
-- A class's first spells, known from the first day: a new rank is no news.
local FIRST_SPELLS = {
  WARRIOR = { "Battle Stance", "Heroic Strike" },
  PALADIN = { "Seal of Righteousness", "Holy Light" },
  HUNTER = { "Raptor Strike", "Auto Shot" },
  ROGUE = { "Sinister Strike", "Eviscerate", "Stealth" },
  PRIEST = { "Smite", "Lesser Heal" },
  SHAMAN = { "Lightning Bolt", "Healing Wave" },
  MAGE = { "Fireball", "Frost Armor" },
  WARLOCK = { "Shadow Bolt", "Demon Skin" },
  DRUID = { "Wrath", "Healing Touch" },
}
W.FIRST_SPELLS = FIRST_SPELLS
-- A class's defining moments learned as spells (a warlock's demons, a
-- hunter's companions, a druid's forms and a shaman's totems are moments
-- of their own): a warrior's stances, a paladin's Redemption, a rogue's
-- poisons, a priest's own people's prayers, a mage's first way home, a
-- druid's way to Moonglade. By the tag its lines carry (writing/d-calling.md).
local CALLING = {
  WARRIOR = { ["Defensive Stance"] = true, ["Berserker Stance"] = true },
  PALADIN = { Redemption = true },
  ROGUE = { Poisons = true },
  PRIEST = {
    ["Desperate Prayer"] = true,
    Feedback = true,
    ["Fear Ward"] = true,
    Starshards = true,
    ["Elune's Grace"] = true,
    ["Touch of Weakness"] = true,
    ["Devouring Plague"] = true,
    ["Hex of Weakness"] = true,
    Shadowguard = true,
  },
  DRUID = { ["Teleport: Moonglade"] = true },
}
function W.callingOf(class, spell)
  if not spell then return nil end
  if class == "MAGE" and spell:find("^Teleport: ") then return "teleport" end -- (the first of them)
  if CALLING[class] and CALLING[class][spell] then return "spell:" .. spell:gsub(" ", "_") end
  return nil
end
-- (a people's capital: a city, no farms nor hills, no "country")
W.CITIES = {
  ["Stormwind City"] = true,
  Ironforge = true,
  Darnassus = true,
  Orgrimmar = true,
  ["Thunder Bluff"] = true,
  Undercity = true,
}
W.foeOf = foeOf
W.ELEMENT = ELEMENT
W.HOSTS = HOSTS
W.at = at
W.TAKEN_IN = TAKEN_IN
W.CLASS_FIGHT = CLASS_FIGHT
-- (in a quest's why, my own people are mine: "for the Forsaken", written by one)
local OURS = {
  Human = { { "the humans", "my people" } },
  Dwarf = { { "the dwarves", "my people" } },
  NightElf = { { "the night elves", "my people" }, { "the kaldorei", "my people" } },
  Gnome = { { "the gnomes", "my people" } },
  Orc = { { "the orcs", "my people" } },
  Troll = {
    { "the Darkspear tribe", "my tribe" },
    { "the Darkspear trolls", "my people" },
    { "the Darkspear", "my people" },
  },
  Tauren = { { "the tauren", "my people" }, { "the shu'halo", "my people" } },
  Scourge = { { "the Forsaken", "my people" } },
}
-- A quest's why, as one of the people it names writes it: "for the
-- Forsaken" is "for my people" in a Forsaken's diary.
local function ours(text, race)
  for _, pair in ipairs(OURS[race] or {}) do
    text = text:gsub(pair[1]:gsub("%p", "%%%0"), pair[2])
  end
  return text
end

W.ours = ours
W.lowerFirst = lowerFirst
