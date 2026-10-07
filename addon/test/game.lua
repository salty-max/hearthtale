-- A fake game for the tests: the WoW API the addon uses, its events, a
-- character to play (state), and the addon loaded into it.
--   local G = dofile("addon/test/game.lua")
-- FOREVER=1 in the environment: Forever's client (no combat log).
local DIR = "addon/Hearthtale/"
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
  money = 0, health = 100, hardcore = true, bind = "Anvilmar", party = {}, race = "Dwarf", class = "PALADIN",
  gear = {}, skills = {},
}
-- Items the client has loaded: until then it gives no info for one (asking
-- loads it), and a quest's objective for it comes without its name ("0/8 ").
local loaded = {}
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
C_QuestLog = {
  GetTitleForQuestID = function(id) return state.titles and state.titles[id] end,
  -- (the tests write objectives as "Tough Wolf Meat: 0/8"; today's clients,
  -- Classic Era and Forever alike, say "0/8 Tough Wolf Meat")
  GetQuestObjectives = function(id)
    local list = state.objectives and state.objectives[id] or {}
    local out = {}
    for i, o in ipairs(list) do
      local copy = {}
      for k, v in pairs(o) do copy[k] = v end
      local name, have, need = (o.text or ""):match("^(.-): (%d+)/(%d+)$")
      if name and o.type == "item" and not loaded[name] then
        loaded[name] = true -- (the log asks for it: named the next time)
        name = ""
      end
      if name then copy.text = ("%s/%s %s"):format(have, need, name) end
      out[i] = copy
    end
    return out
  end,
  IsComplete = function(id)
    local list = state.objectives and state.objectives[id]
    if list and #list > 0 then for _, o in ipairs(list) do if not o.finished then return false end end return true end
    return state.complete ~= nil and state.complete[id] == true
  end,
}
-- (numbered blanks in today's clients: the name last)
QUEST_MONSTERS_KILLED = "%2$d/%3$d %1$s slain"
QUEST_OBJECTS_FOUND = "%2$d/%3$d %1$s"
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
  if u == "pet" and state.pet then return state.pet end
end
function UnitExists(u) return (u == "target" and state.target ~= nil and state.target.player == true) or u == "player" or unitOf(u) ~= nil or (u == "npc" and state.npc ~= nil) or state.party[u] ~= nil end
function UnitIsPlayer(u) return u == "player" or state.party[u] ~= nil or (u == "target" and state.target ~= nil and state.target.player == true) end
-- the unit a GUID is, if it is one now (the target, here)
function UnitTokenFromGUID(guid)
  if state.target and UnitGUID("target") == guid then return "target" end
end
function UnitGUID(u)
  if u == "player" then return state.guid end
  if u == "pet" then return state.pet and state.pet.guid end
  if u == "target" and state.target and state.target.player then return state.target.guid end
  if u == "target" and state.target then return creatureGuid(state.target.id, state.target.n) end
end
-- (a player's second name: a surname on Forever, a realm elsewhere)
function UnitName(u)
  if u == "player" then return state.name or "Sealinedion", state.surname end
  if u == "npc" then return state.npc end
  if state.party[u] then return state.party[u].name, state.party[u].surname end
  if u == "target" and state.target and state.target.player then return state.target.name end
  local c = unitOf(u)
  return c and c.name
end
function UnitLevel(u) return u == "player" and state.level or 1 end
function UnitRace() return state.race, state.race end
function UnitFactionGroup()
  return state.faction or (({ Orc = true, Troll = true, Tauren = true, Scourge = true, BloodElf = true })[state.race] and "Horde" or "Alliance")
end
function UnitClass(u) if state.party[u] then return state.party[u].class, state.party[u].class end return state.class:sub(1, 1) .. state.class:sub(2):lower(), state.class end
function UnitSex() return 3 end
function UnitCreatureType(u) local c = unitOf(u); return c and c.type end
function UnitCreatureFamily(u) local c = unitOf(u); return c and c.family end
function UnitClassification(u) local c = unitOf(u); return c and c.rank end
function UnitIsDead(u) if u == "pet" then return state.pet and state.pet.dead or false end return u == "target" and deadTarget end
function UnitCanAttack(_, u) return u == "target" and state.target ~= nil end
function UnitAffectingCombat(u) return inCombat and not (u == "target" and deadTarget) end
function UnitHealth() return state.health end
function UnitHealthMax() return 100 end
function UnitIsDeadOrGhost() return state.health <= 0 end
function GetNumGroupMembers() local n = 0 for _ in pairs(state.party) do n = n + 1 end return n > 0 and n + 1 or 0 end
function IsInRaid() return state.raid == true end
function IsInInstance() return state.instance ~= nil, state.instance and (state.instanceKind or "party") or "none" end
function UnitIsGhost() return state.ghost == true end
function GetMaxPlayerLevel() return state.maxLevel or 60 end
-- The other side's players met: guid = { class, race }.
function GetPlayerInfoByGUID(guid)
  local p = state.players and state.players[guid]
  if p then return p.class, p.class, p.race, p.race, 2, p.name, "" end
end
function GetInstanceInfo() return state.instance end
-- Items: { quality, item level, id }.
local ITEMS = { ["Ragged Leather Gloves"] = { 1, 3, 1 }, ["Frostmane Leather Vest"] = { 2, 8, 2 }, ["Wolf Fang Necklace"] = { 2, 10, 3 } }
local itemCount = 3
-- (today's clients, Classic Era and Forever alike, have only C_Item.GetItemInfo)
C_Item = { GetItemInfo = function(link)
  local name = link:match("%[(.-)%]"); local i = ITEMS[name]
  if not loaded[name] then loaded[name] = true return nil end -- (asking loads it)
  if i then return name, link, i[1], i[2] end
end }
local function itemLink(name, quality)
  if not ITEMS[name] then itemCount = itemCount + 1; ITEMS[name] = { quality or 2, 10, 100 + itemCount } end
  local colour = ({ [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000" })[ITEMS[name][1]] or "1eff00"
  return ("|cff%s|Hitem:%d::::::::1:::::|h[%s]|h|r"):format(colour, ITEMS[name][3], name)
end
function GetInventoryItemLink(_, slot) return state.gear[slot] and itemLink(state.gear[slot]) end
-- Skills: { name, header, max }, as the skills pane lists them.
TRADE_SKILLS, SECONDARY_SKILLS = "Professions", "Secondary Skills"
function GetNumSkillLines() return #state.skills end
function GetSkillLineInfo(i) local s = state.skills[i]; return s[1], s[2], nil, nil, nil, nil, s[3] end
function IsMounted() return state.mounted == true end
-- The game's formats, as in its global strings.
ERR_LEARN_SPELL_S = "You have learned a new spell: %s."
ERR_LEARN_ABILITY_S = "You have learned a new ability: %s."
SKILL_RANK_UP = "Your skill in %s has increased to %d."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_CREATED_SELF = "You create: %s."
LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
-- Taxis.
local TAXI = { "Ironforge, Dun Morogh", "Thelsamar, Loch Modan" } -- or state.taxi: the current one first
function NumTaxiNodes() return #(state.taxi or TAXI) end
function TaxiNodeName(i) return (state.taxi or TAXI)[i] end
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
    -- (PARTY_KILL, an event of its own: on Forever; the Classic run plays an
    -- older client without it, its kills from the combat log)
    if not FOREVER and e == "PARTY_KILL" then error("Attempt to register unknown event \"PARTY_KILL\"") end
    self.registered[e] = true
  end
  function f:UnregisterEvent(e) self.registered[e] = nil end
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
-- an event the game sends whether anyone listens or not (a fight's own)
local function offer(e, ...)
  for _, f in ipairs(frames) do
    if f.registered[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end
  end
end

-- The game's toasts, links and realm: keep what the addon hands them.
local toasted = {}
function GetRealmName() return state.realm or "Nightslayer" end
function GetCurrentRegion() return state.region or 3 end
C_AddOns = { GetAddOnMetadata = function(name, key) return name == "Hearthtale" and key == "Version" and "0.2.0" or nil end }
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
assert(loadfile(DIR .. (FOREVER and "Data_Forever.lua" or "Data_Classic.lua")))("Hearthtale", ns)
for _, f in ipairs({ "Names.lua", "Core.lua", "Record.lua", "Language.lua", "Lines.lua", "Scene.lua", "Writer.lua", "Book.lua", "Hall.lua", "Save.lua", "Settings.lua", "Minimap.lua" }) do assert(loadfile(DIR .. f))("Hearthtale", ns) end
local D = ns.data
-- Resting and campfires: the game's resting state, the auras on me.
state.auras = {}
function IsResting() return state.resting == true end
function IsIndoors() return state.indoors == true end
-- (a creature someone else hit first: not mine to claim)
function UnitIsTapDenied(u) return u == "target" and state.target ~= nil and state.target.tapped == true end
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return state.auras[id] and { spellId = id } or nil end }
local function login() fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD", true, false) end
local function logout() fire("PLAYER_LOGOUT") end
local function reload() fire("PLAYER_LOGOUT"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD", false, true) end
-- Kills.
local function kill(id, n, tapped)
  state.target = { id = id, n = n, tapped = tapped }
  if FOREVER then
    -- as it's played: chosen first, then the fight (its health falling), and
    -- it dies still targeted
    fire("PLAYER_TARGET_CHANGED")
    inCombat = true
    offer("PLAYER_REGEN_DISABLED")
    offer("UNIT_HEALTH", "target")
    inCombat, deadTarget = false, true
    offer("UNIT_HEALTH", "target")
    -- my killing blow (not when another struck first: their kill)
    if not tapped then fire("PARTY_KILL", state.guid, creatureGuid(id, n)) end
    deadTarget = false
    return
  end
  fire("PLAYER_TARGET_CHANGED")
  combatLog = { clock, "PARTY_KILL", false, state.guid, "Sealinedion", 0, 0, creatureGuid(id, n), CREATURES[id].name, 0, 0 }
  fire("COMBAT_LOG_EVENT_UNFILTERED")
end
-- A player of the other side killed: who (guid, name), of what race and class.
local function vanquish(guid, name, race, class)
  state.players = state.players or {}
  state.players[guid] = { name = name, race = race, class = class }
  if FOREVER then
    state.target = { player = true, guid = guid, name = name }
    inCombat = true
    fire("PLAYER_TARGET_CHANGED")
    inCombat, deadTarget = false, true
    fire("PLAYER_TARGET_CHANGED")
    fire("PARTY_KILL", state.guid, guid)
    deadTarget, state.target = false, nil
    return
  end
  combatLog = { clock, "PARTY_KILL", false, state.guid, "Sealinedion", 0, 0, guid, name .. "-Firemaw", 0, 0 }
  fire("COMBAT_LOG_EVENT_UNFILTERED")
end
-- A creature to meet: its id (for kill()).
local function creature(name, type, family, rank)
  for i, c in ipairs(CREATURES) do if c.name == name then return i end end
  table.insert(CREATURES, { name = name, type = type, family = family, rank = rank or "normal" })
  return #CREATURES
end

return {
  ns = ns, D = D, state = state, fire = fire, printed = printed, panel = panel, toasted = toasted, linkHandlers = linkHandlers,
  login = login, logout = logout, reload = reload, kill = kill, vanquish = vanquish, creature = creature, itemLink = itemLink, forever = FOREVER,
  secrets = secrets,
  -- time: the clock (and the hour of the day) or only the time played
  wait = function(s) clock, uptime = clock + s, uptime + s; state.hour = (state.hour + s / 3600) % 24 end,
  played = function(s) uptime = uptime + s end,
  sleep = function(s) clock = clock + s; state.hour = (state.hour + s / 3600) % 24 end, -- logged out
  clock = function() return clock end,
  portrait = function() return portraitOf end,
  corpse = function(id, n) state.target = { id = id, n = n }; deadTarget = true; fire("PLAYER_TARGET_CHANGED"); deadTarget = false end,
  fall = function() combatLog = { clock, "ENVIRONMENTAL_DAMAGE", false, nil, nil, 0, 0, state.guid, "Sealinedion", 0, 0, "FALLING", 120 } end,
}
