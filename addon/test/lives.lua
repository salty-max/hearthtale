-- Lives played through the addon in the fake game (game.lua), as the game would
-- send them: the sample book (sample.lua) and the site's test data (seed.lua).
-- Each starts a fresh game (the account's Hall of the Fallen carries over, as
-- on one account) and returns it once played (G.ns.writeBook(...)).
--   local lives = dofile("addon/test/lives.lua")
--   local G = lives.brannok()
local lives = {}
local MINUTE, HOUR = 60, 3600

-- The moves of a life in one game: kill, travel, quests, levels, training,
-- gear, trades, rests.
local function moves(G)
  local state, fire, kill, creature, itemLink = G.state, G.fire, G.kill, G.creature, G.itemLink
  local serial = 0
  local function slay(name, n, type, family, rank)
    local id = creature(name, type or "Humanoid", family, rank)
    for _ = 1, n or 1 do
      serial = serial + 1
      kill(id, serial)
      G.wait(45)
    end
  end
  local function go(sub, zone)
    state.sub, state.zone = sub, zone or state.zone
    fire(zone and "ZONE_CHANGED_NEW_AREA" or "ZONE_CHANGED")
    G.wait(5 * MINUTE)
  end
  local quest = 100
  -- A quest from someone: its objective (as the quest log writes it), the work
  -- done for it, and the one it is turned in to.
  local function task(title, giver, objective, work, ender)
    quest = quest + 1
    state.titles = state.titles or {}
    state.titles[quest] = title
    state.objectives = { [quest] = objective and { objective } or {} }
    state.npc = giver
    if G.forever then fire("QUEST_ACCEPTED", quest) else fire("QUEST_ACCEPTED", 1, quest) end
    state.npc = nil
    G.wait(2 * MINUTE)
    if work then work() end
    state.npc = ender or giver
    fire("QUEST_COMPLETE")
    fire("QUEST_TURNED_IN", quest, 100, 0)
    state.npc = nil
    G.wait(3 * MINUTE)
  end
  local function slain(name, n) return { text = name .. " slain: 0/" .. n, type = "monster", numRequired = n } end
  local function found(name, n) return { text = name .. ": 0/" .. n, type = "item", numRequired = n } end
  local function ding()
    state.level = state.level + 1
    fire("PLAYER_LEVEL_UP", state.level)
  end
  local spellIds = { ["Bear Form"] = 5487, ["Serpent Sting"] = 1978, ["Track Beasts"] = 1494, ["Arcane Shot"] = 3044, ["Hunter's Mark"] = 1130,
    ["Raptor Strike"] = 14260, ["Concussive Shot"] = 5116, ["Mend Pet"] = 136, ["Leatherworking"] = 2108, ["Skinning"] = 8613 }
  local function learn(...)
    for _, spell in ipairs({ ... }) do
      fire("CHAT_MSG_SYSTEM", ("You have learned a new spell: |cff71d5ff|Hspell:%d|h[%s]|h|r."):format(spellIds[spell] or 1, spell))
    end
    G.wait(MINUTE)
  end
  local function wear(slot, name, quality)
    itemLink(name, quality)
    state.gear[slot] = name
    fire("PLAYER_EQUIPMENT_CHANGED", slot)
  end
  local function closeCall(name, hp)
    state.target = { id = creature(name, "Humanoid"), n = 999 }
    fire("PLAYER_TARGET_CHANGED")
    state.health = hp
    fire("UNIT_HEALTH", "player")
    state.health, state.target = 100, nil
  end
  local function trade(name, max, section)
    for _, s in ipairs(state.skills) do if s[1] == name then s[3] = max; fire("SKILL_LINES_CHANGED") return end end
    local at
    for i, s in ipairs(state.skills) do if s[1] == section then at = i end end
    if not at then table.insert(state.skills, { section, true }); at = #state.skills end
    table.insert(state.skills, at + 1, { name, false, max })
    fire("SKILL_LINES_CHANGED")
  end
  local function rest(hours) -- logged out at an inn (or a city)
    state.resting = true
    G.logout()
    G.sleep(hours * HOUR)
    state.resting = false
    G.login()
  end
  local function camp(hours) -- logged out in the wild
    G.logout()
    G.sleep(hours * HOUR)
    G.login()
  end
  -- The last blow: the foe in the target (Forever and Classic alike), then death.
  local function fall(name, kind, family, rank)
    state.target = { id = creature(name, kind or "Humanoid", family, rank), n = 9999 }
    fire("PLAYER_TARGET_CHANGED")
    state.health = 0
    fire("PLAYER_DEAD")
    state.health, state.target = 100, nil
  end
  return { state = state, fire = fire, slay = slay, go = go, task = task, slain = slain, found = found, ding = ding,
    learn = learn, wear = wear, closeCall = closeCall, trade = trade, rest = rest, camp = camp, fall = fall, itemLink = itemLink }
end

-- A new character, at its first login.
local function begin(G, who)
  local state = G.state
  for k, v in pairs(who) do state[k] = v end
  state.skills = state.skills or { { "Weapon Skills", true }, { "Languages", true }, { "Common", false, 300 } }
  HearthtaleChar = nil
  G.login()
end

-- A Hardcore dwarf hunter's first evenings: the sample book (three chapters,
-- the third still being written).
function lives.brannok()
  local G = dofile("addon/test/game.lua")
  local m = moves(G)
  local state, fire, itemLink = m.state, m.fire, m.itemLink
  local slay, go, task, slain, found, ding, learn, wear, closeCall, trade, rest, camp =
    m.slay, m.go, m.task, m.slain, m.found, m.ding, m.learn, m.wear, m.closeCall, m.trade, m.rest, m.camp
  state.gear = { [4] = "Rugged Trapper's Shirt", [7] = "Rugged Trapper's Pants", [8] = "Rugged Trapper's Boots", [18] = "Ornate Blunderbuss" }
  for _, name in pairs(state.gear) do itemLink(name, 1) end
  begin(G, { name = "Brannok", race = "Dwarf", class = "HUNTER", hardcore = true, guid = "Player-6113-0B4A2201", level = 1, region = 1,
    hour = 9, zone = "Dun Morogh", sub = "Coldridge Valley", bind = "Anvilmar",
    skills = { { "Weapon Skills", true }, { "Guns", false, 5 }, { "Languages", true }, { "Dwarven", false, 300 } } })
  -- ── the first evening: Coldridge Valley ─────────────────────────────────────
  task("Dwarven Outfitters", "Sten Stoutarm", found("Tough Wolf Meat", 8), function()
    go("Anvilmar")
    slay("Ragged Young Wolf", 10, "Beast", "Wolf")
  end)
  task("A New Threat", "Balir Frosthammer", slain("Rockjaw Trogg", 6), function()
    go("Coldridge Valley")
    slay("Rockjaw Trogg", 6)
    slay("Burly Rockjaw Trogg", 4)
  end)
  ding()
  task("Coldridge Valley Mail Delivery", "Talin Keeneye", nil, function() G.wait(10 * MINUTE) end, "Grelin Whitebeard")
  slay("Frostmane Troll Whelp", 3)
  closeCall("Frostmane Troll Whelp", 9)
  task("The Troll Cave", "Grelin Whitebeard", slain("Frostmane Troll Whelp", 14), function() slay("Frostmane Troll Whelp", 14) end)
  ding()
  task("The Stolen Journal", "Grelin Whitebeard", found("Grelin Whitebeard's Journal", 1), function()
    slay("Frostmane Shadowcaster", 3)
  end)
  wear(6, "Frostmane Leather Belt")
  ding()
  go("Anvilmar")
  learn("Serpent Sting", "Track Beasts")
  task("Scalding Mornbrew Delivery", "Durnan Furcutter", nil, function() G.wait(8 * MINUTE) end, "Marryk Nurribit")
  rest(10)

  -- ── the second: Kharanos, Brewnall Village, a night outdoors ────────────────
  go("Coldridge Pass")
  go("Kharanos")
  state.bind = "Thunderbrew Distillery"
  fire("HEARTHSTONE_BOUND")
  trade("Skinning", 75, "Professions")
  learn("Skinning")
  trade("Leatherworking", 75, "Professions")
  learn("Leatherworking")
  task("Beer Basted Boar Ribs", "Ragnar Thunderbrew", found("Crag Boar Rib", 6), function()
    slay("Crag Boar", 9, "Beast", "Boar")
  end)
  fire("CHAT_MSG_LOOT", "You create: " .. itemLink("Handstitched Leather Vest") .. ".")
  wear(5, "Handstitched Leather Vest")
  ding()
  task("Ammo for Rumbleshot", "Loslor Rudge", nil, function() go("The Grizzled Den") end, "Hegnar Rumbleshot")
  go("Brewnall Village")
  task("Operation Recombobulation", "Razzle Sprysprocket", found("Gyromechanic Gear", 8), function()
    slay("Leper Gnome", 11)
  end)
  learn("Arcane Shot")
  G.wait(HOUR)
  go("Shimmer Ridge")
  slay("Frostmane Snowstrider", 4)
  camp(8)
  slay("Frostmane Snowstrider", 6)
  slay("Timber", 1, "Beast", "Wolf", "rare")
  fire("CHAT_MSG_SKILL", "Your skill in Skinning has increased to 50.")
  ding()
  fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Frostmane Scepter", 3) .. ".")
  task("Frostmane Hold", "Senir Whitebeard", { text = "Explore the Frostmane Hold", type = "event" }, function()
    go("Frostmane Hold")
    slay("Frostmane Headhunter", 3)
  end)
  task("Protecting the Herd", "Rudra Amberstill", slain("Vagash", 1), function()
    go("Amberstill Ranch")
    slay("Vagash", 1, "Beast", "Bear", "elite")
  end)
  ding()
  go("Kharanos")
  learn("Hunter's Mark", "Raptor Strike")
  rest(9)

  -- ── the third: a pet, a friend, and the road east ───────────────────────────
  task("The Grizzled Den", "Pilot Stonegear", found("Wendigo Mane", 8), function()
    go("The Grizzled Den")
    slay("Young Wendigo", 10, "Beast")
  end)
  ding()
  state.party.party1 = { name = "Thorgrim", class = "WARRIOR" }
  fire("GROUP_ROSTER_UPDATE")
  task("Gnomeregan's Fall", "Ozzie Togglevolt", slain("Rockjaw Bonesnapper", 10), function()
    go("Gol'Bolar Quarry")
    slay("Rockjaw Bonesnapper", 10)
  end)
  state.party = {}
  fire("GROUP_ROSTER_UPDATE")
  ding()
  go("Kharanos")
  learn("Concussive Shot", "Mend Pet")
  task("Taming the Beast", "Grif Wildheart", { text = "Tame a Large Crag Boar", type = "event" }, function()
    go("Amberstill Ranch")
    G.wait(10 * MINUTE)
  end)
  state.pet = { name = "Bristle", family = "Boar" }
  fire("UNIT_PET", "player")
  G.wait(10 * MINUTE)
  state.auras[7353] = true
  fire("UNIT_AURA", "player")
  G.wait(10 * MINUTE)
  state.auras[7353] = nil
  fire("UNIT_AURA", "player")
  slay("Frostmane Seer", 3)
  state.pet.dead = true
  fire("UNIT_HEALTH", "pet")
  state.pet.dead = false
  fire("UNIT_HEALTH", "pet")
  G.wait(10 * MINUTE)
  go("North Gate Pass", "Loch Modan")
  go("Thelsamar")
  slay("Mountain Boar", 4, "Beast", "Boar")
  return G
end

-- A Hardcore gnome mage who falls in Frostmane Hold at level 6: two chapters,
-- the book closed by her death (an epitaph, a life in the Hall).
function lives.pippa()
  local G = dofile("addon/test/game.lua")
  local m = moves(G)
  local slay, go, task, slain, found, ding, learn, wear, closeCall, rest, fall =
    m.slay, m.go, m.task, m.slain, m.found, m.ding, m.learn, m.wear, m.closeCall, m.rest, m.fall
  begin(G, { name = "Pippa", race = "Gnome", class = "MAGE", hardcore = true, guid = "Player-6113-0C77A9F3", level = 1,
    realm = "Soulseeker", region = 3, hour = 19, zone = "Dun Morogh", sub = "Coldridge Valley", bind = "Anvilmar" })
  task("A New Threat", "Balir Frosthammer", slain("Rockjaw Trogg", 6), function()
    slay("Rockjaw Trogg", 6)
  end)
  task("Dwarven Outfitters", "Sten Stoutarm", found("Tough Wolf Meat", 8), function()
    slay("Ragged Young Wolf", 9, "Beast", "Wolf")
  end)
  ding()
  go("Anvilmar")
  learn("Frost Armor", "Arcane Missiles")
  task("Coldridge Valley Mail Delivery", "Talin Keeneye", nil, function() G.wait(10 * 60) end, "Grelin Whitebeard")
  ding()
  rest(9)
  go("Coldridge Pass")
  go("Kharanos")
  task("Tools for Steelgrill", "Beldin Steelgrill", nil, function() G.wait(6 * 60) end, "Tharek Blackstone")
  ding()
  learn("Frostbolt", "Conjure Water")
  wear(5, "Apprentice's Robe")
  go("Brewnall Village")
  task("Operation Recombobulation", "Razzle Sprysprocket", found("Gyromechanic Gear", 8), function()
    slay("Leper Gnome", 9)
  end)
  ding()
  ding()
  go("Frostmane Hold")
  slay("Frostmane Headhunter", 2)
  closeCall("Frostmane Headhunter", 8)
  slay("Frostmane Seer", 1)
  fall("Frostmane Shadowcaster")
  return G
end

-- A human paladin met at level 23 on a normal realm: a prologue, a chapter in
-- Duskwood closed at the Scarlet Raven Tavern (a death told in it), a second
-- being written.
function lives.aldric()
  local G = dofile("addon/test/game.lua")
  local m = moves(G)
  local state = m.state
  local slay, go, task, slain, found, ding, learn, wear, rest, fall =
    m.slay, m.go, m.task, m.slain, m.found, m.ding, m.learn, m.wear, m.rest, m.fall
  state.questsDone = {}
  for i = 1, 87 do state.questsDone[i] = true end
  state.gear = { [5] = "Rough Bronze Cuirass", [16] = "Bronze Mace" }
  begin(G, { name = "Aldric", race = "Human", class = "PALADIN", hardcore = false, guid = "Player-6113-0A13D2E8", level = 23,
    realm = "Firemaw", region = 3, hour = 20, zone = "Duskwood", sub = "Darkshire", bind = "Lakeshire" })
  G.fire("TIME_PLAYED_MSG", 172800, 3600)
  state.bind = "Darkshire"
  G.fire("HEARTHSTONE_BOUND")
  task("The Night Watch", "Commander Althea Ebonlock", slain("Skeletal Fiend", 15), function()
    go("Raven Hill Cemetery")
    slay("Skeletal Fiend", 15, "Undead")
    slay("Skeletal Horror", 3, "Undead")
  end)
  task("Worgen in the Woods", "Calor", slain("Nightbane Shadow Weaver", 6), function()
    go("Brightwood Grove")
    slay("Nightbane Shadow Weaver", 6)
  end)
  ding()
  wear(16, "Night Watch Shortsword")
  go("Darkshire")
  learn("Seal of Command", "Holy Light", "Hammer of Justice")
  task("The Hermit", "Madame Eva", nil, function() go("The Hushed Bank") end, "Abercrombie")
  go("Raven Hill")
  fall("Stitches", "Undead", nil, "elite")
  G.wait(10 * 60)
  go("Darkshire")
  state.resting = true
  rest(10)
  task("Bride of the Embalmer", "Abercrombie", found("Ghoul Rib", 7), function()
    go("Tranquil Gardens Cemetery")
    slay("Flesh Eating Worm", 6, "Beast")
  end)
  ding()
  return G
end

-- An orc warrior's first days: the Valley of Trials, Razor Hill, then Orgrimmar.
function lives.grashnak()
  local G = dofile("addon/test/game.lua")
  local m = moves(G)
  local slay, go, task, slain, found, ding, learn, wear, closeCall, rest =
    m.slay, m.go, m.task, m.slain, m.found, m.ding, m.learn, m.wear, m.closeCall, m.rest
  begin(G, { name = "Grashnak", race = "Orc", class = "WARRIOR", hardcore = false, guid = "Player-6113-0D21E5A0", level = 1,
    realm = "Firemaw", region = 3, hour = 8, zone = "Durotar", sub = "Valley of Trials", bind = "Razor Hill" })
  task("Cutting Teeth", "Gornek", slain("Mottled Boar", 10), function() slay("Mottled Boar", 10, "Beast", "Boar") end)
  task("Sarkoth", "Hana'zua", slain("Sarkoth", 1), function() slay("Sarkoth", 1, "Beast", "Scorpid") end)
  ding()
  task("Vile Familiars", "Zureetha Fargaze", slain("Vile Familiar", 12), function() slay("Vile Familiar", 12, "Demon") end)
  task("Galgar's Cactus Apple Surprise", "Galgar", found("Cactus Apple", 10), function() G.wait(15 * 60) end)
  ding()
  task("Lazy Peons", "Foreman Thazz'ril", { text = "Peons Awoken: 0/5", type = "event" }, function() G.wait(10 * 60) end)
  task("Report to Sen'jin Village", "Gornek", nil, function() go("Razor Hill") end, "Master Gadrin")
  learn("Rend", "Battle Shout")
  wear(5, "Rough Leather Vest")
  ding()
  task("Sting of the Scorpid", "Rezlak", found("Scorpid Worker Tail", 8), function() slay("Scorpid Worker", 9, "Beast", "Scorpid") end)
  closeCall("Kul Tiras Marine", 9)
  task("Vanquish the Betrayers", "Gar'Thok", slain("Kul Tiras Sailor", 10), function() slay("Kul Tiras Sailor", 10) end)
  ding()
  rest(9)
  go("Valley of Strength", "Orgrimmar")
  learn("Charge", "Thunder Clap")
  task("Hidden Enemies", "Thrall", nil, function() G.wait(10 * 60) end, "Gor the Enforcer")
  ding()
  return G
end

-- A night elf druid's first days: Shadowglen, Dolanaar, Darnassus, and her first new shape.
function lives.aelyndra()
  local G = dofile("addon/test/game.lua")
  local m = moves(G)
  local slay, go, task, slain, found, ding, learn, wear, rest, camp =
    m.slay, m.go, m.task, m.slain, m.found, m.ding, m.learn, m.wear, m.rest, m.camp
  begin(G, { name = "Aelyndra", race = "NightElf", class = "DRUID", hardcore = true, guid = "Player-6113-0E33B7C1", level = 1,
    realm = "Soulseeker", region = 3, hour = 20, zone = "Teldrassil", sub = "Shadowglen", bind = "Dolanaar" })
  task("The Balance of Nature", "Conservator Ilthalaine", slain("Young Nightsaber", 7), function()
    slay("Young Nightsaber", 7, "Beast", "Cat")
    slay("Young Thistle Boar", 4, "Beast", "Boar")
  end)
  task("Etched Sigil", "Conservator Ilthalaine", nil, function() G.wait(5 * 60) end, "Mardant Strongoak")
  ding()
  task("The Woodland Protector", "Tarindrella", slain("Grell", 8), function() slay("Grell", 8, "Demon") end)
  task("Webwood Venom", "Gilshalan Windwalker", found("Webwood Venom Sac", 10), function() slay("Webwood Spider", 11, "Beast", "Spider") end)
  ding()
  learn("Moonfire", "Rejuvenation")
  task("A Good Friend", "Dirania Silvershine", nil, function() go("Dolanaar") end, "Iverron")
  ding()
  camp(8)
  task("Zenn's Bidding", "Zenn Foulhoof", found("Nightsaber Pelt", 3), function() slay("Nightsaber", 4, "Beast", "Cat") end)
  task("The Emerald Dreamcatcher", "Tallonkai Swiftroot", found("Emerald Dreamcatcher", 1), function() G.wait(12 * 60) end)
  wear(7, "Sentinel Trousers")
  ding()
  rest(9)
  go("Temple of the Moon", "Darnassus")
  task("Body and Heart", "Mathrengyl Bearwalker", { text = "Moonkin Stone found", type = "event" }, function() G.wait(15 * 60) end)
  learn("Bear Form")
  ding()
  return G
end

-- A Forsaken priest's first days: Deathknell, Brill, the Undercity.
function lives.mortis()
  local G = dofile("addon/test/game.lua")
  local m = moves(G)
  local slay, go, task, slain, found, ding, learn, wear, rest =
    m.slay, m.go, m.task, m.slain, m.found, m.ding, m.learn, m.wear, m.rest
  begin(G, { name = "Mortis", race = "Scourge", class = "PRIEST", hardcore = false, guid = "Player-6113-0F44C8D2", level = 1,
    realm = "Firemaw", region = 3, hour = 22, zone = "Tirisfal Glades", sub = "Deathknell", bind = "Brill" })
  task("Rude Awakening", "Undertaker Mordo", nil, function() G.wait(5 * 60) end, "Shadow Priest Sarvis")
  task("The Mindless Ones", "Shadow Priest Sarvis", slain("Mindless Zombie", 8), function()
    slay("Mindless Zombie", 8, "Undead")
    slay("Wretched Zombie", 8, "Undead")
  end)
  ding()
  task("Night Web's Hollow", "Executor Arren", slain("Young Night Web Spider", 10), function() slay("Young Night Web Spider", 10, "Beast", "Spider") end)
  task("Scavenging Deathknell", "Deathguard Saltain", found("Scavenged Goods", 6), function() G.wait(15 * 60) end)
  ding()
  task("The Scarlet Crusade", "Executor Arren", found("Scarlet Armband", 12), function() slay("Scarlet Convert", 12) end)
  learn("Shadow Word: Pain", "Power Word: Shield")
  ding()
  go("Brill")
  task("Fields of Grief", "Apothecary Johaan", found("Tirisfal Pumpkin", 10), function() G.wait(20 * 60) end)
  task("Wanted: Maggot Eye", "Executor Zygand", slain("Maggot Eye", 1), function() slay("Maggot Eye", 1, "Humanoid", nil, "elite") end)
  wear(5, "Lightweight Chain Robe")
  ding()
  rest(9)
  go("The Trade Quarter", "Undercity")
  learn("Renew", "Mind Blast")
  task("The Chill of Death", "Master Apothecary Faranell", found("Vile Fin Scale", 5), function() G.wait(10 * 60) end)
  ding()
  return G
end

return lives
