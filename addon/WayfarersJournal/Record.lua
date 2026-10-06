-- The journal's chapters, recorded as they happen, for the writer to tell. A
-- chapter is a stretch of the road between two rests: it closes when the
-- character logs out resting (an inn, a city, a campfire) with a few moments
-- written, or at any logout once it holds four hours of play; a logout
-- elsewhere is a night outdoors, and the chapter goes on.
--   chapters[i] = {
--     start = { at, level, zone, sub, night }
--     log = { moment, ... }                 in order (below)
--     kills = { [name] = n }                every kill, for the closing recap
--     quests = n                            quests turned in
--     played = seconds, gold = copper       time played in it, money gained
--     ended = { at, level, zone, sub, place, how }   how: rest, campfire,
--                                           long (the cap), death
--   }
--   moments: { k = kind, at, night, zone, sub, ... }:
--     place { new = "zone" or nil }         a place seen for the first time
--     inn { place }  flight { from, to }
--     quest { title, giver, ender, objectives = { { type, name, n, text } } }
--                                           what it asked (monster: kill n of name;
--                                           item: bring n of name; others: text),
--                                           and who I returned to
--     kill { name, kind, first, elite }     the chapter's first of a creature
--     rare { name, elite }  close { foe, hp }  died { death }
--     group { name, class }                 someone joined me
--     dungeon { name }  boss { name }
--     learned { spells }                    a trainer's visit (merged)
--     skill { name, rank }  loot { link, quality }   (the chapter's best yet)
--     level { level }                       (recorded, not told)
--     campfire  rested { place, fire }      (a rest too short to close)
--     night { }                             slept outdoors (a logout in the wild)
--     wake { after }                        the next session in the same chapter
--   visited[zone|sub], kinds[kind] = true   the character's firsts, life-long
--   death, hardcore, closed, race, class, name, sex, prologue: as before
--   logout = { at, rest, fire, place, zone, sub, level }   the last logout,
--                                           settled at the next login (a /reload
--                                           fires the same event: it is dropped)
-- Kills: Classic from the combat log (mine or my pet's); Forever, which
-- closes the combat log to addons, from corpses targeted dead after a fight
-- with me.
local _, ns = ...
local secret = ns.secret

local CAP = 4 * 3600      -- a chapter's play time after which any logout closes it
local MIN_MOMENTS = 3     -- what a chapter needs before a rest can close it
-- The auras of a campfire: Cozy Fire (the cooking fires, both games), and
-- Forever's camps (Welcoming Campfire, Well Rested).
local FIRES = { 7353, 7358, 1232234, 1229739, 1289723, 1225478 }

local function char() return ns.journal() end
local function now() return time() end
local function night()
  local h = GetGameTime and GetGameTime()
  return h ~= nil and not secret(h) and (h < 6 or h >= 18)
end
local function where()
  local zone, sub = GetRealZoneText and GetRealZoneText(), GetSubZoneText and GetSubZoneText()
  if secret(zone) then zone = nil end
  if secret(sub) or sub == "" or sub == zone then sub = nil end
  return zone, sub
end
local function changed() if ns.onRecord then ns.onRecord() end end

-- ── the chapter in progress ──────────────────────────────────────────────────
local function chapter()
  local c = char()
  c.chapters = c.chapters or {}
  local ch = c.chapters[#c.chapters]
  if not ch or ch.ended then
    local zone, sub = where()
    -- where it starts is named by its opening: not a discovery too
    c.visited = c.visited or {}
    if zone then
      c.visited[zone .. "|"] = true
      c.visited[zone .. "|" .. (sub or "")] = true
    end
    ch = { start = { at = now(), level = UnitLevel("player"), zone = zone, sub = sub, night = night() },
      log = {}, kills = {}, quests = 0, played = 0, gold = 0 }
    table.insert(c.chapters, ch)
  end
  return ch
end
ns.chapter = chapter

-- A moment, in order.
local function moment(k, fields)
  local ch = chapter()
  local zone, sub = where()
  local m = fields or {}
  m.k, m.at, m.night = k, now(), night() or nil
  m.zone, m.sub = m.zone or zone, m.sub or sub
  table.insert(ch.log, m)
  changed()
  return m
end
ns.moment = moment

local function moments(ch)
  local n = 0
  for _, m in ipairs(ch.log) do
    if m.k ~= "wake" and m.k ~= "night" and m.k ~= "rested" then n = n + 1 end
  end
  return n
end

-- Time played, counted by session, charged to the chapter in progress.
local sessionFrom
local function tally()
  if not (char() and sessionFrom) then return end
  local t = GetTime()
  local ch = chapter()
  ch.played = ch.played + (t - sessionFrom)
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
  if not c.closed then c.hardcore = hardcore() or c.hardcoreChosen or nil end -- chosen: in the settings, where the game can't tell
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
  sessionFrom = GetTime()
  c.money = GetMoney()
end)
-- The prologue's time played, heard whenever something asks the game (asking
-- ourselves would print it in chat).
ns.on("TIME_PLAYED_MSG", function(total)
  local p = char().prologue
  if p and not p.played and not secret(total) then p.played = total end
end)

-- ── resting, and the end of a chapter ────────────────────────────────────────
local function hasAura(id)
  local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
  return ok and aura ~= nil
end
local isFire = {}
for _, id in ipairs(FIRES) do isFire[id] = true end
local function byFire()
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    for _, id in ipairs(FIRES) do
      if hasAura(id) then return true end
    end
    return false
  end
  -- without it: the buffs once over
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    if not name then return false end
    if spellId and not secret(spellId) and isFire[spellId] then return true end
  end
  return false
end
ns.byFire = byFire

-- A campfire's warmth: a moment per stop (a fire found again within the hour,
-- in the same place, is the same stop).
local warm = false
ns.on("UNIT_AURA", function(unit)
  if unit ~= "player" then return end
  local fire = byFire()
  if fire and not warm then
    local ch, zone, sub = chapter(), where()
    local last
    for i = #ch.log, 1, -1 do if ch.log[i].k == "campfire" then last = ch.log[i] break end end
    if not (last and now() - last.at < 3600 and last.zone == zone and last.sub == sub) then moment("campfire") end
  end
  warm = fire
end)

-- At logout: where, and whether resting. The next login decides.
ns.on("PLAYER_LOGOUT", function()
  tally()
  local zone, sub = where()
  local rest = IsResting and IsResting()
  char().logout = { at = now(), rest = (rest and not secret(rest)) or nil, fire = byFire() or nil,
    zone = zone, sub = sub, place = sub or zone, level = UnitLevel("player"), night = night() or nil }
end)

local function close(ch, how, l)
  ch.ended = { at = l.at, level = l.level, zone = l.zone, sub = l.sub, place = l.place, how = how }
  if ns.onChapter then ns.onChapter(#char().chapters) end
end

-- The first login after a logout (not a /reload) settles it: a rest closes
-- the chapter (if it holds enough), so does any logout past the cap;
-- otherwise the chapter goes on, with the night between.
local function settle(l)
  local c = char()
  local ch = c.chapters and c.chapters[#c.chapters]
  if not ch or ch.ended or c.closed then return end
  local rested = l.rest or l.fire
  local function note(k, fields)
    fields.at, fields.night, fields.zone, fields.sub = l.at, l.night, l.zone, l.sub
    fields.k = k
    table.insert(ch.log, fields)
  end
  if rested and moments(ch) >= MIN_MOMENTS then
    close(ch, l.fire and "campfire" or "rest", l)
  elseif ch.played >= CAP then
    note("night", { last = true })
    close(ch, "long", l)
  else
    if rested then note("rested", { place = l.place, fire = l.fire }) else note("night", {}) end
    table.insert(ch.log, { k = "wake", at = now(), night = night() or nil, after = rested and "rest" or "night" })
  end
end

ns.on("PLAYER_ENTERING_WORLD", function(initial, reloading)
  local c = char()
  if reloading then
    c.logout = nil -- a /reload, not a night's rest
  elseif initial and c.logout then
    local l = c.logout
    c.logout = nil
    settle(l)
  end
  if not c.closed then chapter() end
end)

-- ── where ────────────────────────────────────────────────────────────────────
local function moved()
  local c = char()
  local zone, sub = where()
  if not zone then return end
  local key = zone .. "|" .. (sub or "")
  if c.visited[key] then return end
  c.visited[key] = true
  local newZone = not c.visited[zone .. "|"]
  c.visited[zone .. "|"] = true
  moment("place", { new = newZone and "zone" or nil })
end
for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do ns.on(e, moved) end
ns.on("PLAYER_ENTERING_WORLD", moved)

ns.on("HEARTHSTONE_BOUND", function()
  local place = GetBindLocation and GetBindLocation()
  if place and not secret(place) then moment("inn", { place = place }) end
end)

if hooksecurefunc and TakeTaxiNode then
  hooksecurefunc("TakeTaxiNode", function(index)
    local to, from = TaxiNodeName(index), nil
    for i = 1, NumTaxiNodes() do
      if TaxiNodeGetType(i) == "CURRENT" then from = TaxiNodeName(i) end
    end
    if to and from then moment("flight", { from = from, to = to }) end
  end)
end

-- ── levels ───────────────────────────────────────────────────────────────────
ns.on("PLAYER_LEVEL_UP", function(newLevel)
  moment("level", { level = newLevel })
end)

-- ── quests ───────────────────────────────────────────────────────────────────
-- Who gave a quest (the one I was talking to when I accepted it) and its
-- title, kept until it is turned in (the title may be out of the game's cache
-- by then). Classic passes (index, id), Forever (id).
local function titleOf(id)
  return (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id))
    or (GetTitleForQuestID and GetTitleForQuestID(id)) or nil
end

-- What a quest asks, from the quest log: its objectives' lines ("Kobold
-- Vermin slain: 0/10", "Tough Wolf Meat: 0/8"), read through the game's own
-- formats; the rest ("Find the missing diplomat") kept as it is.
local function objectivesOf(id)
  local raw = {}
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
    for _, o in ipairs(ok and list or {}) do table.insert(raw, { text = o.text, type = o.type, n = o.numRequired }) end
  elseif GetQuestLogIndexByID and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    local index = GetQuestLogIndexByID(id)
    if index and index > 0 then
      for i = 1, GetNumQuestLeaderBoards(index) or 0 do
        local text, type = GetQuestLogLeaderBoard(i, index)
        table.insert(raw, { text = text, type = type })
      end
    end
  end
  local out = {}
  for _, o in ipairs(raw) do
    if o.text and not secret(o.text) then
      local name, n
      for _, g in ipairs({ "QUEST_MONSTERS_KILLED", "QUEST_OBJECTS_FOUND" }) do
        local p = ns.pattern(g)
        local a, _, c = o.text:match(p or "^$")
        if a then name, n = a, tonumber(c) break end
      end
      table.insert(out, { type = o.type, name = name, n = n or o.n, text = not name and o.text or nil })
    end
  end
  return #out > 0 and out or nil
end

ns.on("QUEST_ACCEPTED", function(a, b)
  local id, c = b or a, char()
  if not id then return end
  c.pending = c.pending or {}
  local giver = UnitName("npc") or UnitName("target")
  c.pending[id] = { giver = (giver and not secret(giver)) and giver or nil, title = titleOf(id), objectives = objectivesOf(id) }
end)
-- The quest log fills in after the acceptance: the objectives, once known.
ns.on("QUEST_LOG_UPDATE", function()
  for id, p in pairs(char().pending or {}) do
    if not p.objectives then p.objectives = objectivesOf(id) end
  end
end)
-- Who I returned to: the one I talk to when the quest is completed.
local ender
ns.on("QUEST_COMPLETE", function()
  local name = UnitName("npc")
  ender = (name and not secret(name)) and name or nil
end)
ns.on("QUEST_TURNED_IN", function(id)
  local c = char()
  local p = c.pending and c.pending[id] or {}
  local ch = chapter()
  ch.quests = ch.quests + 1
  moment("quest", { title = titleOf(id) or p.title, giver = p.giver, ender = ender, objectives = p.objectives })
  ender = nil
  if c.pending then c.pending[id] = nil end
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

-- A kill: counted for the recap; the chapter's first of a creature is a
-- moment (the first of its kind for the character, an elite outside
-- dungeons); a rare or a world boss always is.
local function slain(guid, name)
  local u = units[guid] or { name = name }
  if not u.name then return end
  local c, ch = char(), chapter()
  local firstHere = ch.kills[u.name] == nil
  ch.kills[u.name] = (ch.kills[u.name] or 0) + 1
  if u.rank == "rare" or u.rank == "rareelite" or u.rank == "worldboss" then
    moment("rare", { name = u.name, elite = u.rank ~= "rare" or nil })
  elseif firstHere then
    local first = u.kind and not c.kinds[u.kind] or nil
    local inside = IsInInstance and IsInInstance()
    moment("kill", { name = u.name, kind = u.kind, first = first, elite = (u.rank == "elite" and not inside) or nil })
  end
  if u.kind then c.kinds[u.kind] = true end
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
    moment("close", { foe = who, hp = hp })
  end
  if C_Timer then C_Timer.After(5, check) else check() end
end)

-- ── company and dungeons ─────────────────────────────────────────────────────
ns.on("GROUP_ROSTER_UPDATE", function()
  local ch = chapter()
  ch.company = ch.company or {}
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, n do
    local unit = IsInRaid and IsInRaid() and ("raid" .. i) or ("party" .. i)
    local name = UnitName(unit)
    if name and not secret(name) and name ~= UnitName("player") and not ch.company[name] then
      ch.company[name] = true
      moment("group", { name = name, class = select(2, UnitClass(unit)) })
    end
  end
end)
local lastDungeon
ns.on("PLAYER_ENTERING_WORLD", function()
  local inside, kind = IsInInstance()
  if not inside or (kind ~= "party" and kind ~= "raid") then return end
  local name = GetInstanceInfo()
  if not name or secret(name) then return end
  if lastDungeon and lastDungeon.name == name and now() - lastDungeon.at < 3600 then return end
  lastDungeon = { name = name, at = now() }
  moment("dungeon", { name = name })
end)
ns.on("ENCOUNTER_END", function(_, encounterName, _, _, success)
  if success == 1 and encounterName and not secret(encounterName) then moment("boss", { name = encounterName }) end
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
      -- a trainer's visit is one moment: spells learned together merge
      local ch = chapter()
      local last = ch.log[#ch.log]
      if last and last.k == "learned" and now() - last.at < 120 then
        table.insert(last.spells, spell)
        changed()
      else
        moment("learned", { spells = { spell } })
      end
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
  if skill and rank and MILESTONES[rank] then moment("skill", { name = skill, rank = rank }) end
end)
-- Loot: the chapter's best yet (green and above, by quality, then level).
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
  local ch = chapter()
  local best = ch.best
  if not best or quality > best.quality or (quality == best.quality and (ilvl or 0) > (best.level or 0)) then
    ch.best = { quality = quality, level = ilvl }
    moment("loot", { link = link, quality = quality })
  end
end)
ns.on("PLAYER_MONEY", function()
  local c, money = char(), GetMoney()
  if c.money and money > c.money then local ch = chapter(); ch.gold = ch.gold + (money - c.money) end
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
  c.death = d
  c.deaths = (c.deaths or 0) + 1
  if c.hardcore then
    -- the end: the chapter closes with the epitaph
    local ch = chapter()
    ch.ended = { at = d.at, level = d.level, zone = zone, sub = sub, place = sub or zone, how = "death" }
    c.closed = true
  else
    moment("died", { death = d })
  end
  if ns.onDeath then ns.onDeath(d) end
  changed()
end)
