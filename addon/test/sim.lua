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
-- Forever's client here doesn't say whether a character is Hardcore: the
-- player says so in the settings (tested below).
if not FOREVER then C_GameRules = { IsHardcoreActive = function() return state.hardcore end } end
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
  [6] = { name = "Defias Overseer", type = "Humanoid", rank = "elite" },
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

-- UI: any method works and returns something sensible, scripts are kept.
local function ui()
  local o = { shown = false, scripts = {} }
  return setmetatable(o, {
    __index = function(t, k)
      if k == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
      if k == "Show" then return function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
      if k == "Hide" then return function(self) self.shown = false end end
      if k == "SetShown" then return function(self, v) if v then self:Show() else self:Hide() end end end
      if k == "IsShown" then return function(self) return self.shown end end
      if k == "SetText" then return function(self, v) self.text = v end end
      if k == "GetText" then return function(self) return rawget(self, "text") or "" end end
      if k == "GetStringHeight" then return function() return 14 end end
      if k == "SetHeight" then return function(self, v) self.height = v end end
      if k == "GetHeight" then return function(self) return rawget(self, "height") or 100 end end
      if k == "SetVerticalScroll" then return function(self, v) self.vscroll = v end end
      if k == "GetVerticalScroll" then return function(self) return rawget(self, "vscroll") or 0 end end
      if k == "GetWidth" then return function() return 140 end end
      if k == "GetCenter" then return function() return 0, 0 end end
      if k == "GetEffectiveScale" then return function() return 1 end end
      if k == "CreateFontString" or k == "CreateTexture" then return function() return ui() end end
      return function() return t end
    end,
  })
end
UIParent, UISpecialFrames = ui(), {}
Minimap, GameTooltip = ui(), ui()
function GetCursorPosition() return 0, 0 end
-- The game's settings panel: keep what the addon registers.
local panel = { settings = {} }
Settings = {
  VarType = { Boolean = "boolean", Number = "number" },
  RegisterVerticalLayoutCategory = function(name) panel.name = name; return { GetID = function() return 42 end } end,
  RegisterProxySetting = function(_, variable, _, name, default, get, set)
    local s = { variable = variable, name = name, default = default, get = get, set = set }
    panel.settings[variable] = s
    return s
  end,
  CreateCheckbox = function() end,
  RegisterAddOnCategory = function() panel.registered = true end,
  OpenToCategory = function(id) panel.opened = id end,
}
local portraitOf
function SetPortraitTexture(_, unit) portraitOf = unit end

local frames = {}
function CreateFrame(_, name, _, template)
  local f = ui()
  f.registered = {}
  if template == "ButtonFrameTemplate" then -- the game's window has its portrait
    local p = ui()
    f.GetPortrait = function() return p end
  end
  function f:RegisterEvent(e)
    if FOREVER and e == "COMBAT_LOG_EVENT_UNFILTERED" then error("COMBAT_LOG_EVENT_UNFILTERED: forbidden") end
    self.registered[e] = true
  end
  table.insert(frames, f)
  if name then _G[name] = f end
  return f
end
local function fire(e, ...)
  local heard = false
  for _, f in ipairs(frames) do
    if f.registered[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...); heard = true end
  end
  assert(heard, "nobody listens to " .. e)
end

-- The game's toasts, links and realm: keep what the addon hands them.
local toasted = {}
function GetRealmName() return "Nightslayer" end
C_XMLUtil = { GetTemplateInfo = function(name) return name ~= "PanelTabButtonTemplate" or nil end }
AlertFrame = { AddQueuedAlertFrameSubSystem = function(_, _, setUp)
  return { AddAlert = function(_, guid)
    local frame = ui()
    frame.Icon, frame.Title, frame.Name = ui(), ui(), ui()
    setUp(frame, guid)
    table.insert(toasted, frame)
  end }
end }
local linkHandlers = {}
LinkUtil = { RegisterLinkHandler = function(kind, fn) linkHandlers[kind] = fn end }
LinkProcessorResponse = { Handled = 2 }

-- ── load the addon ───────────────────────────────────────────────────────────
local ns = {}
assert(loadfile(DIR .. (FOREVER and "Data_Forever.lua" or "Data_Classic.lua")))("WayfarersJournal", ns)
for _, f in ipairs({ "Core.lua", "Record.lua", "Writer.lua", "Book.lua", "Hall.lua", "Settings.lua", "Minimap.lua" }) do assert(loadfile(DIR .. f))("WayfarersJournal", ns) end
local D = ns.data
local function check(cond, msg) assert(cond, msg); io.write("✓ " .. msg .. "\n") end
local function lvl(n) return WayfarersJournalChar.levels[n] end

-- ── a life ───────────────────────────────────────────────────────────────────
check(D.client == (FOREVER and "forever" or "classic") and D.writing.opening, "each game's data file is its own, with the writing")
check(ns.forever == FOREVER, FOREVER and "Forever is recognised" or "Classic is recognised")
WayfarersJournalChar = { guid = "Player-6113-0DEAD000", levels = { [1] = {} } }
fire("PLAYER_LOGIN")
local J = WayfarersJournalChar
check(panel.registered and panel.name == "Wayfarer's Journal" and panel.settings.WAYFARERSJOURNAL_CHAT
  and panel.settings.WAYFARERSJOURNAL_TOAST and panel.settings.WAYFARERSJOURNAL_MINIMAPHIDDEN.get() == true,
  "the settings page: chat lines, the alert, the minimap button (shown)")
local hcSetting = panel.settings.WAYFARERSJOURNAL_HARDCORE
if FOREVER then
  check(hcSetting and not J.hardcore, "Forever: the game can't tell Hardcore; the settings ask")
  hcSetting.set(true)
  fire("PLAYER_LOGIN")
  check(J.hardcore and J.hardcoreChosen and hcSetting.get() == true, "Forever: declared Hardcore, and it holds at the next login")
else
  check(not hcSetting, "Classic: the game tells Hardcore; no setting for it")
end
local mm = WayfarersJournalMinimapButton
check(mm and mm:IsShown(), "the minimap button")
SlashCmdList.WAYFARERSJOURNAL("minimap")
check(not mm:IsShown() and panel.settings.WAYFARERSJOURNAL_MINIMAPHIDDEN.get() == false, "/wj minimap hides it")
SlashCmdList.WAYFARERSJOURNAL("minimap")
check(mm:IsShown(), "and shows it again")
SlashCmdList.WAYFARERSJOURNAL("settings")
check(panel.opened == 42, "/wj settings opens the page")
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
check(wolves.n == 2 and wolves.kind == "Wolf" and wolves.first and wolves.where == "Anvilmar" and lvl(1).kills["Rockjaw Trogg"].first,
  "kills by creature, with their kind, where, and the first of each kind")
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
local before = #printed
fire("PLAYER_LEVEL_UP", 2)
check(#printed == before + 1 and printed[#printed]:find("level 1 is written", 1, true) and printed[#printed]:find("|Hwayfarer:chapter:1|h", 1, true),
  "a level ends: a line in chat, with a link to its chapter")
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
kill(6, 14)
check(not lvl(2).kills["Defias Overseer"].elite, "an elite inside a dungeon is not an open-world feat")
local run = lvl(2).dungeons
check(lvl(2).company.Brannor == "WARRIOR" and #run == 1 and run[1].name == "The Deadmines" and #run[1].bosses == 1 and run[1].bosses[1] == "Edwin VanCleef",
  "who I grouped with, the dungeon (once) and the bosses beaten")
state.instance = nil

-- The book of that life, written from the records.
local book = ns.writeBook(J)
local one, two = book.chapters[1], book.chapters[2]
check(not book.prologue and one.level == 1 and (one.text:find("Anvilmar", 1, true) or one.text:find("Coldridge Valley", 1, true)),
  "the book of that life: chapter one begins where the life began")
check(one.text:find('"Dwarven Outfitters"', 1, true) and one.close and two.level == 2 and two.rare and not one.text:find("{", 1, true),
  "its chapters tell the quests, mark the close calls and rares")
io.write("    " .. one.text:gsub("\n\n", "\n    ") .. "\n")

-- The book, open: a chapter per level, the last one open.
SlashCmdList.WAYFARERSJOURNAL("")
local B, page, rows = WayfarersJournalFrame, WayfarersJournalPage, ns.bookRows
check(B:IsShown() and portraitOf == "player" and B.who:GetText():find("Sealinedion, level 2", 1, true) and B.who:GetText():find("Hardcore", 1, true),
  "/wj opens the book: my portrait, who I am, Hardcore")
check(rows[1]:IsShown() and rows[2]:IsShown() and not (rows[3] and rows[3]:IsShown()) and rows[1].title:GetText() == "Level 1",
  "a row per level")
check(page.title:GetText() == "Level 2" and page.body:GetText() == ns.writeBook(J).chapters[2].text,
  "the last chapter opens first, as the writer wrote it")
check(rows[1].marks[1]:IsShown() and not rows[1].marks[2]:IsShown() and rows[2].marks[2]:IsShown(),
  "marks: a skull for a close call (level 1), a star for a rare (level 2)")
rows[1].scripts.OnClick(rows[1])
check(page.title:GetText() == "Level 1" and page.body:GetText():find('"Dwarven Outfitters"', 1, true)
  and page.sub:GetText():find("Dun Morogh", 1, true) and not page.sub:GetText():find("still being written", 1, true),
  "a click opens a chapter: the place, the dates")
rows[2].scripts.OnClick(rows[2])
check(page.sub:GetText():find("still being written", 1, true), "the level in progress is still being written")
state.sub = "Kharanos"
fire("ZONE_CHANGED")
check(page.body:GetText():find("Kharanos", 1, true) and page.title:GetText() == "Level 2", "a new moment while the book is open: rewritten at once, the same chapter open")
SlashCmdList.WAYFARERSJOURNAL("")
check(not B:IsShown(), "/wj again closes it")
linkHandlers.wayfarer("wayfarer:chapter:1")
check(B:IsShown() and page.title:GetText() == "Level 1", "the chapter's link opens the book at it")
SlashCmdList.WAYFARERSJOURNAL("")
panel.settings.WAYFARERSJOURNAL_CHAT.set(false)
local lines = #printed
ns.onChapter(1)
check(#printed == lines, "chat lines can be turned off")
panel.settings.WAYFARERSJOURNAL_CHAT.set(true)

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

-- A Hardcore death closes the book: nothing more is recorded; it joins the Hall
-- of the Fallen (a copy of its records), with a chat line and the game's toast.
local fallen = WayfarersJournalHall and WayfarersJournalHall.lives[state.guid]
check(J.closed and fallen and fallen.name == "Sealinedion" and fallen.raceName == "Dwarf" and fallen.realm == "Nightslayer"
  and fallen.levels[2] and fallen ~= J, "a Hardcore death closes the book; a copy joins the Hall of the Fallen")
check(printed[#printed]:find("closed", 1, true) and printed[#printed]:find("|Hwayfarer:hall:" .. state.guid, 1, true),
  "a chat line says so, with a link to the Hall")
check(#toasted == 1 and toasted[1].Title:GetText() == "The book is closed" and toasted[1].Name:GetText() == "Sealinedion",
  "the game's toast: the book is closed")
local placesBefore = #lvl(2).places
state.sub = "Brewnall Village"
fire("ZONE_CHANGED")
fire("PLAYER_LOGIN")
check(#lvl(2).places == placesBefore and not lvl(3), "a closed book records nothing more, even at the next login")
local closedBook = ns.writeBook(J)
check(closedBook.epitaph and closedBook.epitaph:find("Sealinedion", 1, true) and closedBook.epitaph:find("level two", 1, true)
  and not closedBook.epitaph:find("{", 1, true), "its epitaph: who, where, at what level")
io.write("    " .. closedBook.epitaph .. "\n")

-- The link opens the Hall at that life: its epitaph, then its chapters.
linkHandlers.wayfarer("wayfarer:hall:" .. state.guid)
check(B:IsShown() and B.selectedTab == 2 and rows[1].title:GetText() == "Sealinedion" and rows[2].title:GetText() == "Epitaph"
  and rows[3].title:GetText() == "Level 1" and page.title:GetText() == "Sealinedion" and page.body:GetText():find(closedBook.epitaph, 1, true)
  and page.sub:GetText():find("Level 2 Dwarf Paladin", 1, true), "the link opens the Hall: the life, its epitaph, its chapters")
rows[4].scripts.OnClick(rows[4])
check(page.title:GetText() == "Level 2" and page.sub:GetText():find("the end", 1, true) and page.body:GetText():find(closedBook.epitaph, 1, true),
  "its last chapter ends with the epitaph")
ns.showTab(1)
check(B.who:GetText():find("Fallen", 1, true) and page.title:GetText() == "Level 2" and page.body:GetText():find(closedBook.epitaph, 1, true),
  "the Journal tab: my own closed book, the same end")
SlashCmdList.WAYFARERSJOURNAL("")

-- A character met mid-life: a prologue from what the game knows.
WayfarersJournalChar = nil
state.guid, state.level, state.questsDone, state.hardcore = "Player-6113-0FFFFFF0", 23, { [1] = true, [2] = true, [3] = true }, false
fire("PLAYER_LOGIN")
local P = WayfarersJournalChar.prologue
fire("TIME_PLAYED_MSG", 86400, 3600)
fire("TIME_PLAYED_MSG", 90000, 7200)
check(P and P.level == 23 and P.quests == 3 and P.inn == "Thunderbrew Distillery" and P.played == 86400 and WayfarersJournalChar.levels[23],
  "a character met mid-life gets a prologue: its level, quests done, inn, time played when first heard")
local later = ns.writeBook(WayfarersJournalChar)
check(later.prologue and later.prologue:find("^%u") and later.chapters[1].level == 23 and not later.chapters[1].text:find("begin", 1, true),
  "its book opens with the prologue; its first chapter is no beginning")
io.write("    " .. later.prologue .. "\n")
SlashCmdList.WAYFARERSJOURNAL("")
check(rows[1].title:GetText() == "Prologue" and rows[2].title:GetText() == "Level 23" and not (rows[3] and rows[3]:IsShown())
  and page.title:GetText() == "Level 23", "its book lists the prologue, then its first chapter")
rows[1].scripts.OnClick(rows[1])
check(page.title:GetText() == "Prologue" and page.sub:GetText():find("level 23", 1, true) and page.body:GetText() == later.prologue,
  "the prologue reads")
SlashCmdList.WAYFARERSJOURNAL("")

-- A death on a normal realm: told in its chapter; the book goes on.
state.health, state.target = 0, nil
fire("PLAYER_DEAD")
state.health = 100
local K = WayfarersJournalChar
state.sub = "Gol'Bolar Quarry"
fire("ZONE_CHANGED")
ns.writerUsed = {}
ns.writeBook(K)
local told = false
for key in pairs(ns.writerUsed) do if key:find("^died#") then told = true end end
ns.writerUsed = nil
check(not K.closed and #K.levels[23].deaths == 1 and K.levels[23].places[#K.levels[23].places].sub == "Gol'Bolar Quarry"
  and told and not WayfarersJournalHall.lives[state.guid], "a death on a normal realm: told in its chapter, no Hall, the book goes on")
io.write(FOREVER and "all good (Forever)\n" or "all good\n")
