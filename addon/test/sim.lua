-- Runs the addon against a fake WoW API and replays a character's life.
--   luajit addon/test/sim.lua              (from the repo root): Classic
--   FOREVER=1 luajit addon/test/sim.lua    the same on Forever's client (no
--                                          combat log: kills from corpses fought)
local DIR = "addon/WayfarersJournal/"
local FOREVER = os.getenv("FOREVER") == "1"
function GetBuildInfo() return "1.15.8", "60000", "Oct 1 2026", FOREVER and 16001 or 11509 end
local secrets = {}
if FOREVER then issecretvalue = function(v) return secrets[v] == true end end

-- ── a fake game ──────────────────────────────────────────────────────────────
local clock, uptime = 1790900000, 1000
function time() return clock end
function GetTime() return uptime end
date = os.date
local state = {
  level = 1, guid = "Player-6113-0ABCDEF0", zone = "Dun Morogh", sub = "Coldridge Valley", hour = 10,
  money = 0, health = 100, hardcore = true, bind = "Anvilmar", party = {},
}
local printed = {}
function print(msg) table.insert(printed, msg) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetGameTime() return state.hour, 0 end
function GetRealZoneText() return state.zone end
function GetSubZoneText() return state.sub end
function GetBindLocation() return state.bind end
function GetMoney() return state.money end
function GetQuestsCompleted() return state.questsDone or {} end
C_GameRules = { IsHardcoreActive = function() return state.hardcore end }
C_QuestLog = { GetTitleForQuestID = function(id) return state.titles and state.titles[id] end }
C_Timer = { After = function(_, fn) fn() end }
SlashCmdList = {}

-- Units: the player, a target, the quest giver, the party.
local CREATURES = {
  [1] = { name = "Ragged Young Wolf", type = "Beast", family = "Wolf", rank = "normal" },
  [2] = { name = "Rockjaw Trogg", type = "Humanoid", rank = "normal" },
  [3] = { name = "Timber", type = "Beast", family = "Wolf", rank = "rare" },
  [4] = { name = "Frostmane Novice", type = "Humanoid", rank = "normal" },
  [5] = { name = "Gibblewilt", type = "Humanoid", rank = "elite" },
}
local function creatureGuid(i, n) return ("Creature-0-4170-0-12-%d-%08X"):format(i, n or 1) end
local deadTarget, inCombat = false, false
local function unitOf(u)
  if u == "target" and state.target then return CREATURES[state.target.id] end
end
function UnitExists(u) return u == "player" or unitOf(u) ~= nil or (u == "npc" and state.npc ~= nil) or state.party[u] ~= nil end
function UnitIsPlayer(u) return u == "player" or state.party[u] ~= nil end
function UnitGUID(u)
  if u == "player" then return state.guid end
  if u == "target" and state.target then return creatureGuid(state.target.id, state.target.n) end
end
function UnitName(u)
  if u == "player" then return "Sealinedion" end
  if u == "npc" then return state.npc end
  if state.party[u] then return state.party[u].name end
  local c = unitOf(u)
  return c and c.name
end
function UnitLevel(u) return u == "player" and state.level or 1 end
function UnitRace() return "Dwarf", "Dwarf" end
function UnitClass(u) if state.party[u] then return state.party[u].class, state.party[u].class end return "Paladin", "PALADIN" end
function UnitSex() return 3 end
function UnitCreatureType(u) local c = unitOf(u); return c and c.type end
function UnitCreatureFamily(u) local c = unitOf(u); return c and c.family end
function UnitClassification(u) local c = unitOf(u); return c and c.rank end
function UnitIsDead(u) return u == "target" and deadTarget end
function UnitAffectingCombat(u) return inCombat and not (u == "target" and deadTarget) end
function UnitHealth() return state.health end
function UnitHealthMax() return 100 end
function UnitIsDeadOrGhost() return state.health <= 0 end
function GetNumGroupMembers() local n = 0 for _ in pairs(state.party) do n = n + 1 end return n > 0 and n + 1 or 0 end
function IsInRaid() return false end
function IsInInstance() return state.instance ~= nil, state.instance and "party" or "none" end
function GetInstanceInfo() return state.instance end
local ITEMS = { ["Ragged Leather Gloves"] = { 1, 3 }, ["Frostmane Leather Vest"] = { 2, 8 }, ["Wolf Fang Necklace"] = { 2, 10 } }
function GetItemInfo(link) local name = link:match("%[(.-)%]"); local i = ITEMS[name]; if i then return name, link, i[1], i[2] end end
local function itemLink(name) return ("|cff1eff00|Hitem:%d::::::::1:::::|h[%s]|h|r"):format(#name, name) end
-- The game's formats, as in its global strings.
ERR_LEARN_SPELL_S = "You have learned a new spell: %s."
ERR_LEARN_ABILITY_S = "You have learned a new ability: %s."
SKILL_RANK_UP = "Your skill in %s has increased to %d."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
-- Taxis.
local TAXI = { "Ironforge, Dun Morogh", "Thelsamar, Loch Modan" }
function NumTaxiNodes() return #TAXI end
function TaxiNodeName(i) return TAXI[i] end
function TaxiNodeGetType(i) return i == 1 and "CURRENT" or "REACHABLE" end
function TakeTaxiNode() end
function hooksecurefunc(name, fn)
  local original = _G[name]
  _G[name] = function(...) local r = original(...); fn(...); return r end
end
local combatLog
function CombatLogGetCurrentEventInfo() return unpack(combatLog) end

local frames = {}
function CreateFrame()
  local f = { registered = {}, scripts = {} }
  function f:RegisterEvent(e)
    if FOREVER and e == "COMBAT_LOG_EVENT_UNFILTERED" then error("COMBAT_LOG_EVENT_UNFILTERED: forbidden") end
    self.registered[e] = true
  end
  function f:SetScript(name, fn) self.scripts[name] = fn end
  table.insert(frames, f)
  return f
end
local function fire(e, ...)
  local heard = false
  for _, f in ipairs(frames) do
    if f.registered[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...); heard = true end
  end
  assert(heard, "nobody listens to " .. e)
end

-- ── load the addon ───────────────────────────────────────────────────────────
local ns = {}
assert(loadfile(DIR .. (FOREVER and "Data_Forever.lua" or "Data_Classic.lua")))("WayfarersJournal", ns)
for _, f in ipairs({ "Core.lua", "Record.lua" }) do assert(loadfile(DIR .. f))("WayfarersJournal", ns) end
local D = ns.data
local function check(cond, msg) assert(cond, msg); io.write("✓ " .. msg .. "\n") end
local function lvl(n) return WayfarersJournalChar.levels[n] end

-- ── a life ───────────────────────────────────────────────────────────────────
check(D.client == (FOREVER and "forever" or "classic") and D.writing.opening, "each game's data file is its own, with the writing")
check(ns.forever == FOREVER, FOREVER and "Forever is recognised" or "Classic is recognised")
WayfarersJournalChar = { guid = "Player-6113-0DEAD000", levels = { [1] = {} } }
fire("PLAYER_LOGIN")
local J = WayfarersJournalChar
check(J.guid == state.guid and J.began.level == 1 and not J.prologue, "a new character named like a deleted one starts a fresh journal, from level 1: no prologue")
check(J.hardcore and J.race == "Dwarf" and J.class == "PALADIN" and J.name == "Sealinedion", "it knows who it is: a Hardcore dwarf paladin")
check(lvl(1).start.zone == "Dun Morogh" and lvl(1).start.sub == "Coldridge Valley" and not lvl(1).start.night, "level 1 begins at Coldridge Valley, by day")

fire("PLAYER_ENTERING_WORLD")
check(#lvl(1).places == 1 and lvl(1).places[1].sub == "Coldridge Valley", "the first place is seen")
state.sub = "Anvilmar"
fire("ZONE_CHANGED")
fire("ZONE_CHANGED")
check(#lvl(1).places == 2 and lvl(1).places[2].sub == "Anvilmar", "a new place, once")

-- A quest: accepted from someone, turned in later.
state.npc, state.titles = "Sten Stoutarm", { [179] = "Dwarven Outfitters" }
if FOREVER then fire("QUEST_ACCEPTED", 179) else fire("QUEST_ACCEPTED", 1, 179) end
state.npc, state.titles = nil, {}
fire("QUEST_TURNED_IN", 179, 80, 0)
check(lvl(1).quests[1].title == "Dwarven Outfitters" and lvl(1).quests[1].giver == "Sten Stoutarm",
  "a quest turned in, with its title and who gave it (even with the title out of the cache)")

-- Kills.
local function kill(id, n)
  state.target = { id = id, n = n }
  if FOREVER then
    inCombat = true
    fire("PLAYER_TARGET_CHANGED")
    inCombat, deadTarget = false, true
    fire("PLAYER_TARGET_CHANGED")
    deadTarget = false
    return
  end
  fire("PLAYER_TARGET_CHANGED")
  combatLog = { clock, "PARTY_KILL", false, state.guid, "Sealinedion", 0, 0, creatureGuid(id, n), CREATURES[id].name, 0, 0 }
  fire("COMBAT_LOG_EVENT_UNFILTERED")
end
kill(1, 1); kill(1, 2); kill(2, 3)
local wolves = lvl(1).kills["Ragged Young Wolf"]
check(wolves.n == 2 and wolves.kind == "Wolf" and wolves.first and lvl(1).kills["Rockjaw Trogg"].first, "kills by creature, with their kind and the first of each kind")
if FOREVER then
  state.target = { id = 2, n = 99 }; deadTarget = true
  fire("PLAYER_TARGET_CHANGED")
  deadTarget = false
  check(lvl(1).kills["Rockjaw Trogg"].n == 1, "Forever: a corpse never fought doesn't count")
end

-- Learning, loot and money.
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:19740|h[Blessing of Might]|h|r.")
check(lvl(1).learned[1] == "Blessing of Might", "a spell learned, from the game's own message")
fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Ragged Leather Gloves") .. ".")
check(not lvl(1).loot, "common loot isn't worth a line")
fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Frostmane Leather Vest") .. ".")
fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Wolf Fang Necklace") .. "x1.")
fire("CHAT_MSG_LOOT", "Brannor receives loot: " .. itemLink("Wolf Fang Necklace") .. ".")
check(lvl(1).loot and lvl(1).loot.link:find("Wolf Fang Necklace", 1, true), "the best green of the level is kept (mine only)")
state.money = 150
fire("PLAYER_MONEY")
state.money = 100
fire("PLAYER_MONEY")
state.money = 400
fire("PLAYER_MONEY")
check(lvl(1).gold == 450, "money gained (gains only)")

-- A close call, at night.
state.target = { id = 4, n = 7 }
fire("PLAYER_TARGET_CHANGED")
state.hour, state.health = 22, 7
fire("UNIT_HEALTH", "player")
fire("UNIT_HEALTH", "player")
state.health = 100
local close = lvl(1).closeCalls
check(#close == 1 and close[1].hp == 7 and close[1].foe == "Frostmane Novice" and close[1].night,
  "a close call: under a tenth of my health, the foe, the hour; once a minute")

-- Level up: time played goes to the level it was played at.
uptime = uptime + 1300
state.level = 2
fire("PLAYER_LEVEL_UP", 2)
check(lvl(1).played == 1300 and lvl(1).ended and lvl(2) and lvl(2).start.night, "a level up closes the level, with the time played at it; the next begins")

-- An inn, a flight, a profession, a rare.
state.bind = "Thunderbrew Distillery"
fire("HEARTHSTONE_BOUND")
TakeTaxiNode(2)
fire("CHAT_MSG_SKILL", "Your skill in Mining has increased to 50.")
fire("CHAT_MSG_SKILL", "Your skill in Mining has increased to 51.")
kill(3, 11)
check(lvl(2).inn.place == "Thunderbrew Distillery" and lvl(2).flights[1].from == "Ironforge, Dun Morogh" and lvl(2).flights[1].to == "Thelsamar, Loch Modan", "an inn and a flight")
check(#lvl(2).skills == 1 and lvl(2).skills[1].name == "Mining" and lvl(2).skills[1].rank == 50, "a profession, at its milestones only")
kill(5, 12)
check(lvl(2).rares[1] and lvl(2).rares[1].name == "Timber" and not lvl(2).kills.Timber.first, "a rare slain (a wolf: not a first of its kind)")
check(lvl(2).kills.Gibblewilt.elite and #lvl(2).rares == 1, "an elite slain, marked (not a rare)")

-- Company and a dungeon, with its boss.
state.party.party1 = { name = "Brannor", class = "WARRIOR" }
fire("GROUP_ROSTER_UPDATE")
state.instance = "The Deadmines"
fire("PLAYER_ENTERING_WORLD")
fire("PLAYER_ENTERING_WORLD")
fire("ENCOUNTER_END", 1, "Edwin VanCleef", 1, 5, 1)
fire("ENCOUNTER_END", 2, "Cookie", 1, 5, 0)
local run = lvl(2).dungeons
check(lvl(2).company.Brannor == "WARRIOR" and #run == 1 and run[1].name == "The Deadmines" and #run[1].bosses == 1 and run[1].bosses[1] == "Edwin VanCleef",
  "who I grouped with, the dungeon (once) and the bosses beaten")
state.instance = nil

-- Death.
if not FOREVER then
  combatLog = { clock, "ENVIRONMENTAL_DAMAGE", false, nil, nil, 0, 0, state.guid, "Sealinedion", 0, 0, "FALLING", 120 }
  fire("COMBAT_LOG_EVENT_UNFILTERED")
end
state.health = 0
uptime = uptime + 200
fire("PLAYER_DEAD")
check(J.death and J.death.level == 2 and J.death.zone == "Dun Morogh" and J.death.cause == (FOREVER and "foe" or "fall") and lvl(2).played == 200,
  FOREVER and "a death: where, at what level, the time played counted" or "a death: where, at what level, how (a fall), the time played counted")
state.health = 100

-- A character met mid-life: a prologue from what the game knows.
WayfarersJournalChar = nil
state.guid, state.level, state.questsDone = "Player-6113-0FFFFFF0", 23, { [1] = true, [2] = true, [3] = true }
fire("PLAYER_LOGIN")
local P = WayfarersJournalChar.prologue
fire("TIME_PLAYED_MSG", 86400, 3600)
fire("TIME_PLAYED_MSG", 90000, 7200)
check(P and P.level == 23 and P.quests == 3 and P.inn == "Thunderbrew Distillery" and P.played == 86400 and WayfarersJournalChar.levels[23],
  "a character met mid-life gets a prologue: its level, quests done, inn, time played when first heard")
io.write(FOREVER and "all good (Forever)\n" or "all good\n")
