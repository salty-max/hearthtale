-- What each level holds, recorded as it happens, for the writer to tell:
--   levels[n] = {
--     start = { at, zone, sub, night },     where and when the level began
--     ended = at,                           when it ended (a level up)
--     played = seconds,                     time played at it (sessions)
--     gold = copper,                        money gained (gains only)
--     places = { { zone, sub, at } },       places seen for the first time
--     quests = { { id, title, giver, at } },
--     kills = { [name] = { n, kind, first, elite, where } },   by creature
--                                           (kind: type or beast family; first:
--                                           the first of its kind for this
--                                           character; elite: outside dungeons;
--                                           where: the first one's place)
--     rares = { { name, sub, zone, at, elite } },  rares and world bosses slain
--     closeCalls = { { foe, hp, zone, sub, at, night } },
--     company = { [name] = class },         who grouped with me
--     dungeons = { { name, at, bosses = {} } },
--     learned = { spell names },            from a trainer (the game's message)
--     skills = { { name, rank } },          professions crossing a milestone
--     loot = { link, quality, level },      the best item of the level
--     inn = { place, at },                  a new hearthstone bind
--     flights = { { from, to, at } },
--     deaths = { death },                   (as below) every death at the level
--   }
--   visited[zone|sub], kinds[kind] = true   the character's firsts, life-long
--   death = { at, level, zone, sub, foe, cause, player, kind, rank, inside }
--                                           the last one (cause: foe, fall,
--                                           drowning, lava, nature; player: a
--                                           player's hand; kind, rank: the
--                                           creature's, when it was met; inside:
--                                           in a dungeon)
--   hardcore = true                         a Hardcore character
--   closed = true                           a Hardcore death: the book is closed,
--                                           nothing more is recorded (Core.lua)
--   race, class, name, sex                  who I am (voice tokens)
--   prologue = { level, quests, inn, zone, gold, played }   a character met
--                                           mid-life: what the game knew then
-- Kills: Classic from the combat log (mine or my pet's); Forever, which
-- closes the combat log to addons, from corpses targeted dead after a fight
-- with me.
local _, ns = ...
local secret = ns.secret

local function char() return ns.journal() end

local function now() return time() end
local function night()
  local h = GetGameTime and GetGameTime()
  return h ~= nil and (h < 6 or h >= 20)
end
local function where()
  local zone, sub = GetRealZoneText and GetRealZoneText(), GetSubZoneText and GetSubZoneText()
  if secret(zone) then zone = nil end
  if secret(sub) or sub == "" or sub == zone then sub = nil end
  return zone, sub
end

-- ── the level in progress ────────────────────────────────────────────────────
local function level(n)
  local c = char()
  n = n or UnitLevel("player")
  local l = c.levels[n]
  if not l then
    local zone, sub = where()
    l = { start = { at = now(), zone = zone, sub = sub, night = night() }, played = 0, gold = 0,
      places = {}, quests = {}, kills = {}, rares = {}, closeCalls = {}, company = {}, dungeons = {},
      learned = {}, skills = {}, flights = {}, deaths = {} }
    c.levels[n] = l
  end
  return l
end
ns.recordLevel = level

local function changed() if ns.onRecord then ns.onRecord() end end

-- Time played, counted by session (the game's /played would print in chat),
-- charged to the level in progress: at a level up the game may already report
-- the new one.
local sessionFrom, current
local function tally()
  local c = char()
  if not (c and sessionFrom and current) then return end
  local t = GetTime()
  local l = level(current)
  l.played = l.played + (t - sessionFrom)
  sessionFrom = t
end

-- ── who I am ─────────────────────────────────────────────────────────────────
local function hardcore()
  local rules = C_GameRules
  if rules and rules.IsHardcoreActive then
    local ok, on = pcall(rules.IsHardcoreActive)
    if ok and not secret(on) then return on == true end
  end
  return false
end

ns.on("PLAYER_LOGIN", function()
  local c = char()
  c.visited, c.kinds = c.visited or {}, c.kinds or {}
  c.hardcore = hardcore() or nil
  c.race, c.class = select(2, UnitRace("player")), select(2, UnitClass("player"))
  c.name, c.sex = UnitName("player"), UnitSex("player")
  -- A character met mid-life: what the game can say of the life so far.
  if not c.prologue and (c.began.level or 1) > 1 then
    local done = GetQuestsCompleted and GetQuestsCompleted()
    local n = 0
    for _ in pairs(done or {}) do n = n + 1 end
    local zone = where()
    c.prologue = { level = c.began.level, quests = n, inn = GetBindLocation and GetBindLocation(), zone = zone, gold = GetMoney() }
  end
  sessionFrom, current = GetTime(), UnitLevel("player")
  c.money = GetMoney()
  level()
end)
ns.on("PLAYER_LOGOUT", tally)
-- The prologue's time played, heard whenever something asks the game (asking
-- ourselves would print it in chat).
ns.on("TIME_PLAYED_MSG", function(total)
  local p = char().prologue
  if p and not p.played and not secret(total) then p.played = total end
end)

-- ── a level ends ─────────────────────────────────────────────────────────────
ns.on("PLAYER_LEVEL_UP", function(newLevel)
  tally()
  current = newLevel
  local c = char()
  local old = c.levels[newLevel - 1]
  if old then old.ended = now() end
  level(newLevel)
  changed()
end)

-- ── where ────────────────────────────────────────────────────────────────────
local function moved()
  local c = char()
  local zone, sub = where()
  if not zone then return end
  local key = zone .. "|" .. (sub or "")
  if c.visited[key] then return end
  c.visited[key] = true
  if not c.visited[zone .. "|"] and sub then c.visited[zone .. "|"] = true end
  table.insert(level().places, { zone = zone, sub = sub, at = now() })
  changed()
end
for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do ns.on(e, moved) end
ns.on("PLAYER_ENTERING_WORLD", moved)

ns.on("HEARTHSTONE_BOUND", function()
  local place = GetBindLocation and GetBindLocation()
  if place then level().inn = { place = place, at = now() }; changed() end
end)

if hooksecurefunc and TakeTaxiNode then
  hooksecurefunc("TakeTaxiNode", function(index)
    local to, from = TaxiNodeName(index), nil
    for i = 1, NumTaxiNodes() do
      if TaxiNodeGetType(i) == "CURRENT" then from = TaxiNodeName(i) end
    end
    if to and from then table.insert(level().flights, { from = from, to = to, at = now() }); changed() end
  end)
end

-- ── quests ───────────────────────────────────────────────────────────────────
-- Who gave a quest (the one I was talking to when I accepted it) and its
-- title, kept until it is turned in (the title may be out of the game's cache
-- by then). Classic passes (index, id), Forever (id).
local function titleOf(id)
  return (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id))
    or (GetTitleForQuestID and GetTitleForQuestID(id)) or nil
end
ns.on("QUEST_ACCEPTED", function(a, b)
  local id, c = b or a, char()
  if not id then return end
  c.pending = c.pending or {}
  local giver = UnitName("npc") or UnitName("target")
  c.pending[id] = { giver = (giver and not secret(giver)) and giver or nil, title = titleOf(id) }
end)
ns.on("QUEST_TURNED_IN", function(id)
  local c = char()
  local p = c.pending and c.pending[id] or {}
  table.insert(level().quests, { id = id, title = titleOf(id) or p.title, giver = p.giver, at = now() })
  if c.pending then c.pending[id] = nil end
  changed()
end)

-- ── the creatures met (for their kind and rank when they die) ───────────────
local units = {} -- guid = { name, kind, rank }
local order = {}
local function seen(unit)
  if not UnitExists(unit) or UnitIsPlayer(unit) then return end
  local guid = UnitGUID(unit)
  if not guid or secret(guid) or units[guid] then return end
  local name, ctype, family, rank = UnitName(unit), UnitCreatureType(unit), UnitCreatureFamily(unit), UnitClassification(unit)
  if secret(name) then return end
  units[guid] = {
    name = name,
    kind = (not secret(family) and family) or (not secret(ctype) and ctype) or nil,
    rank = not secret(rank) and rank or nil,
  }
  table.insert(order, guid)
  if #order > 300 then units[table.remove(order, 1)] = nil end
end
ns.on("PLAYER_TARGET_CHANGED", function() seen("target") end)
ns.on("UPDATE_MOUSEOVER_UNIT", function() seen("mouseover") end)

local function slain(guid, name)
  local u = units[guid] or { name = name }
  if not u.name then return end
  local c, l = char(), level()
  local zone, sub = where()
  local k = l.kills[u.name]
  if not k then
    local inside = IsInInstance and IsInInstance()
    k = { n = 0, kind = u.kind, elite = (u.rank == "elite" and not inside) or nil, where = sub or zone }
    l.kills[u.name] = k
    if u.kind and not c.kinds[u.kind] then
      c.kinds[u.kind] = true
      k.first = true
    end
  end
  k.n = k.n + 1
  if u.rank == "rare" or u.rank == "rareelite" or u.rank == "worldboss" then
    table.insert(l.rares, { name = u.name, zone = zone, sub = sub, at = now(), elite = u.rank ~= "rare" or nil })
  end
  changed()
end
ns.slain = slain

-- Classic: the combat log names the killer. Forever: corpses I fought.
local lastHit
if not ns.forever then
  ns.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    local _, sub, _, source, sourceName, _, _, dest, destName = CombatLogGetCurrentEventInfo()
    local me, pet = UnitGUID("player"), UnitGUID("pet")
    if sub == "PARTY_KILL" and (source == me or source == pet) and dest and dest:find("^Creature") then
      slain(dest, destName)
    elseif dest == me and sub == "ENVIRONMENTAL_DAMAGE" then
      local kind = select(12, CombatLogGetCurrentEventInfo())
      lastHit = { env = kind, at = now() }
    elseif dest == me and sourceName and sub:find("_DAMAGE$") then
      lastHit = { name = sourceName, guid = source, at = now() }
    end
  end)
else
  local fought, counted = {}, {}
  ns.on("PLAYER_TARGET_CHANGED", function()
    if not UnitExists("target") then return end
    local guid = UnitGUID("target")
    if not guid or secret(guid) then return end
    local mine, theirs = UnitAffectingCombat("player"), UnitAffectingCombat("target")
    if not UnitIsDead("target") and not secret(mine) and not secret(theirs) and mine and theirs then fought[guid] = true end
    if UnitIsDead("target") and fought[guid] and not counted[guid] then
      counted[guid] = true
      slain(guid, UnitName("target"))
    end
  end)
end

-- ── close calls ──────────────────────────────────────────────────────────────
-- Under a tenth of my health, and alive five seconds later; one a minute.
-- The foe: the last to hit me (Classic), else my target. players: a player
-- counts (a death; a close call is a creature's).
local function foe(players)
  if lastHit and now() - lastHit.at <= 10 and lastHit.name then return lastHit.name, lastHit.guid end
  if not UnitExists("target") or (UnitIsPlayer("target") and not players) then return end
  local name, guid = UnitName("target"), UnitGUID("target")
  if name and not secret(name) then return name, not secret(guid) and guid or nil end
end
local pending, lastClose = false, 0
ns.on("UNIT_HEALTH", function(unit)
  if unit ~= "player" or pending or now() - lastClose < 60 then return end
  local h, max = UnitHealth("player"), UnitHealthMax("player")
  if secret(h) or secret(max) or not max or max == 0 or h <= 0 or h / max >= 0.1 then return end
  local hp = math.max(1, math.floor(h / max * 100 + 0.5))
  local who = foe()
  pending = true
  local function check()
    pending = false
    if UnitIsDeadOrGhost("player") then return end
    lastClose = now()
    local zone, sub = where()
    table.insert(level().closeCalls, { foe = who, hp = hp, zone = zone, sub = sub, at = now(), night = night() })
    changed()
  end
  if C_Timer then C_Timer.After(5, check) else check() end
end)

-- ── company and dungeons ─────────────────────────────────────────────────────
ns.on("GROUP_ROSTER_UPDATE", function()
  local l = level()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, n do
    local unit = IsInRaid and IsInRaid() and ("raid" .. i) or ("party" .. i)
    local name = UnitName(unit)
    if name and not secret(name) and name ~= UnitName("player") and not l.company[name] then
      l.company[name] = select(2, UnitClass(unit)) or true
    end
  end
end)
ns.on("PLAYER_ENTERING_WORLD", function()
  local inside, kind = IsInInstance()
  if not inside or (kind ~= "party" and kind ~= "raid") then return end
  local name = GetInstanceInfo()
  if not name or secret(name) then return end
  local l = level()
  local last = l.dungeons[#l.dungeons]
  if last and last.name == name and now() - last.at < 3600 then return end
  table.insert(l.dungeons, { name = name, at = now(), bosses = {} })
  changed()
end)
ns.on("ENCOUNTER_END", function(_, encounterName, _, _, success)
  local l = level()
  local run = l.dungeons[#l.dungeons]
  if success == 1 and run and encounterName and not secret(encounterName) then
    table.insert(run.bosses, encounterName)
    changed()
  end
end)

-- ── learning and spoils ──────────────────────────────────────────────────────
-- The game's own messages, read through its own patterns (any language).
-- A format like "Your skill in %s has increased to %d." becomes a pattern
-- capturing its blanks (also the numbered "%1$s" of some languages).
local function pattern(global)
  local s = _G[global]
  if type(s) ~= "string" then return end
  -- the blanks become markers, the rest is escaped, the markers captures
  s = s:gsub("%%%d%$s", "\1"):gsub("%%s", "\1"):gsub("%%%d%$d", "\2"):gsub("%%d", "\2")
  s = s:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  s = s:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
  return "^" .. s .. "$"
end
ns.pattern = pattern
ns.on("CHAT_MSG_SYSTEM", function(msg)
  if secret(msg) then return end
  for _, g in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S" }) do
    local p = pattern(g)
    local spell = p and msg:match(p)
    if spell then
      spell = spell:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", "%1")
      table.insert(level().learned, spell)
      changed()
      return
    end
  end
end)
local MILESTONES = { [50] = true, [75] = true, [100] = true, [150] = true, [200] = true, [225] = true, [250] = true, [300] = true }
ns.on("CHAT_MSG_SKILL", function(msg)
  local p = pattern("SKILL_RANK_UP")
  if not p or secret(msg) then return end
  local skill, rank = msg:match(p)
  rank = tonumber(rank)
  if skill and rank and MILESTONES[rank] then
    table.insert(level().skills, { name = skill, rank = rank })
    changed()
  end
end)
ns.on("CHAT_MSG_LOOT", function(msg)
  if secret(msg) then return end
  local mine = false
  for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
    local p = pattern(g)
    if p and msg:match(p) then mine = true end
  end
  local link = mine and msg:match("|c%x+|Hitem:[^|]+|h%[.-%]|h|r")
  if not link then return end
  local _, _, quality, ilvl = GetItemInfo(link)
  if not quality or quality < 2 then return end
  local l = level()
  local best = l.loot
  if not best or quality > best.quality or (quality == best.quality and (ilvl or 0) > (best.level or 0)) then
    l.loot = { link = link, quality = quality, level = ilvl }
    changed()
  end
end)
ns.on("PLAYER_MONEY", function()
  local c, money = char(), GetMoney()
  if c.money and money > c.money then level().gold = level().gold + (money - c.money) end
  c.money = money
end)

-- ── death ────────────────────────────────────────────────────────────────────
ns.on("PLAYER_DEAD", function()
  tally()
  local c = char()
  local zone, sub = where()
  local cause = "foe"
  if lastHit and now() - lastHit.at <= 10 and lastHit.env then
    cause = (lastHit.env == "FALLING" and "fall") or (lastHit.env == "DROWNING" and "drowning") or (lastHit.env == "LAVA" and "lava") or "nature"
  end
  local name, guid
  if cause == "foe" then name, guid = foe(true) end
  local u = guid and units[guid]
  local d = { at = now(), level = UnitLevel("player"), zone = zone, sub = sub, foe = name, cause = cause,
    player = (guid and guid:find("^Player")) and true or nil, kind = u and u.kind, rank = u and u.rank,
    inside = (IsInInstance and IsInInstance()) or nil }
  local l = level()
  l.deaths = l.deaths or {}
  table.insert(l.deaths, d)
  c.death = d
  if c.hardcore then c.closed = true end
  if ns.onDeath then ns.onDeath(d) end
  changed()
end)
