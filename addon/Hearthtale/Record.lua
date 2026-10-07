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
--     skill { name, rank }                  a profession's milestone
--     prof { name, learned or rank }        a trade taken up, a new rank
--     riding { name }  mount                riding learned; the first ride
--     gear { link, quality, made }          worn for the first time (green+;
--                                           made: crafted by the character)
--     loot { link, quality }                a find of note (blue and above)
--     power { spell, kind }                 a druid's form, a warlock's demon,
--                                           a class's steed
--     tame { name, family }  petdied { name }   a hunter's pet
--     level { level }                       (recorded, not told)
--     campfire  rested { place, fire }      (a rest too short to close)
--     night { }                             slept outdoors (a logout in the wild)
--     wake { after }                        the next session in the same chapter
--   visited[zone|sub], kinds[kind] = true   the character's firsts, life-long
--   death, hardcore, closed, race, class, name, sex, prologue: as before
--   realm, region                           where the character lives (for the site)
--   book = { ... }                          the book as written at the last logout (Save.lua)
--   logout = { at, rest, fire, place, zone, sub, level, inside }   the last logout,
--                                           settled at the next login (a /reload
--                                           fires the same event: it is dropped)
-- Kills: Classic from the combat log (mine or my pet's); Forever, which
-- closes the combat log to addons, from corpses targeted dead after a fight
-- with me.
local _, ns = ...
local secret = ns.secret
-- An item link, as the game writes it in a message: coloured the old way
-- ("|cff1eff00|Hitem:…") or the new ("|cnIQ2:|Hitem:…").
local LINK = "|c[^|]+|Hitem:[^|]+|h%[.-%]|h|r"
-- A link's own quality, from its colour: always there, even for an item the
-- game hasn't loaded yet (whose info it doesn't have to give).
local QUALITY_COLOUR =
  { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6 }
local function linkQuality(link)
  local q = link:match("^|cnIQ(%d+):")
  if q then return tonumber(q) end
  local colour = link:match("^|c%x%x(%x%x%x%x%x%x)")
  return colour and QUALITY_COLOUR[colour:lower()]
end
-- An item's name and quality: C_Item in today's clients (the global is gone
-- from Classic Era since 1.15), the global in older ones; an item not loaded
-- yet, from its link.
local function itemInfo(link)
  local name, quality
  local api = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if api then
    local ok, n, _, q = pcall(api, link)
    if ok then
      name, quality = n, q
    end
  end
  return name or link:match("|h%[(.-)%]|h"), quality or linkQuality(link)
end

-- A player's name: on Forever a first name and a surname (UnitName's second
-- value; elsewhere it's a realm, left out). The full name, and the first.
local function playerName(first, second)
  if not first or secret(first) then return nil end
  first = first:match("^([^-]+)") or first -- (without a realm: "Name-Realm")
  if ns.forever and second and second ~= "" and not secret(second) then return first .. " " .. second, first end
  return first, first
end
ns.playerName = playerName

local CAP = 4 * 3600 -- a chapter's play time after which any logout closes it
local MIN_MOMENTS = 3 -- what a chapter needs before a rest can close it
-- The auras of a campfire: Cozy Fire (the cooking fires, both games), and
-- Forever's camps (Welcoming Campfire, Well Rested).
local FIRES = { 7353, 7358, 1232234, 1229739, 1289723, 1225478 }

local function char() return ns.journal() end
local function now() return time() end
local function night()
  -- no night or day under the ground: a dungeon is neither
  if IsInInstance then
    local inside, kind = IsInInstance()
    if inside and (kind == "party" or kind == "raid") then return false end
  end
  local h = GetGameTime and GetGameTime()
  return h ~= nil and not secret(h) and (h < 6 or h >= 18)
end
local function where()
  local zone, sub = GetRealZoneText and GetRealZoneText(), GetSubZoneText and GetSubZoneText()
  if secret(zone) then zone = nil end
  if secret(sub) or sub == "" or sub == zone then sub = nil end
  return zone, sub
end
local function changed()
  if ns.onRecord then ns.onRecord() end
end

-- ── the chapter in progress ──────────────────────────────────────────────────
local function chapter()
  local c = char()
  c.chapters = c.chapters or {}
  local ch = c.chapters[#c.chapters]
  -- the journey ended: nothing opens or changes a chapter any more
  if c.finished then return { log = {}, kills = {}, quests = 0, played = 0, gold = 0, company = {} } end
  if not ch or ch.ended then
    local zone, sub = where()
    -- where it starts is named by its opening: not a discovery too
    c.visited = c.visited or {}
    if zone then
      c.visited[zone .. "|"] = true
      c.visited[zone .. "|" .. (sub or "")] = true
    end
    ch = {
      start = { at = now(), level = UnitLevel("player"), zone = zone, sub = sub, night = night() },
      log = {},
      kills = {},
      quests = 0,
      played = 0,
      gold = 0,
    }
    table.insert(c.chapters, ch)
  end
  return ch
end
ns.chapter = chapter

-- A moment, in order.
local function battleground()
  if not IsInInstance then return false end
  local inside, kind = IsInInstance()
  return inside and kind == "pvp"
end
local function moment(k, fields)
  -- a battleground is no part of the tale (but for a level gained there);
  -- nor anything after the journey's end (the highest level reached)
  if k ~= "level" and battleground() then return end
  if char().finished then return end
  local ch = chapter()
  local zone, sub = where()
  local m = fields or {}
  m.k, m.at, m.night = k, now(), night() or nil
  m.zone, m.sub = m.zone or zone, m.sub or sub
  -- in company (a group): no line about being alone
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  if not secret(n) and n > 0 then m.grouped = true end
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
  if UnitFactionGroup then
    local faction = UnitFactionGroup("player")
    if not secret(faction) and (faction == "Alliance" or faction == "Horde") then c.faction = faction:lower() end
  end
  c.name, c.sex = playerName(UnitName("player")), UnitSex("player")
  -- where it lives, for the site (the Battle.net region: 1 US, 3 EU...)
  c.realm = GetRealmName and GetRealmName() or nil
  c.region = GetCurrentRegion and GetCurrentRegion() or nil
  -- A character met mid-life: what the game can say of the life so far.
  if not c.prologue and (c.began.level or 1) > 1 then
    local done = GetQuestsCompleted and GetQuestsCompleted()
    local n = 0
    for _ in pairs(done or {}) do
      n = n + 1
    end
    local zone = where()
    c.prologue =
      { level = c.began.level, quests = n, inn = GetBindLocation and GetBindLocation(), zone = zone, gold = GetMoney() }
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
for _, id in ipairs(FIRES) do
  isFire[id] = true
end
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
ns.onUnit("UNIT_AURA", "player", function()
  local fire = byFire()
  if fire and not warm then
    local ch, zone, sub = chapter(), where()
    local last
    for i = #ch.log, 1, -1 do
      if ch.log[i].k == "campfire" then
        last = ch.log[i]
        break
      end
    end
    if not (last and now() - last.at < 3600 and last.zone == zone and last.sub == sub) then moment("campfire") end
  end
  warm = fire
end)

-- At logout: where, and whether resting. The next login decides.
ns.on("PLAYER_LOGOUT", function()
  tally()
  local zone, sub = where()
  local rest = IsResting and IsResting()
  local inside = IsIndoors and IsIndoors()
  char().logout = {
    at = now(),
    rest = (rest and not secret(rest)) or nil,
    fire = byFire() or nil,
    zone = zone,
    sub = sub,
    place = sub or zone,
    level = UnitLevel("player"),
    night = night() or nil,
    inside = (inside and not secret(inside)) or nil,
  }
end)

local function close(ch, how, l, ahead)
  ch.ended = { at = l.at, level = l.level, zone = l.zone, sub = l.sub, place = l.place, how = how, inside = l.inside }
  if ns.onChapter and not ahead then ns.onChapter(#char().chapters) end
end

-- The first login after a logout (not a /reload) settles it: a rest closes
-- the chapter (if it holds enough), so does any logout past the cap;
-- otherwise the chapter goes on, with the night between. ahead: the logout
-- settled in advance, on a copy, for the book written at logout (Save.lua):
-- no waking yet, no chat line.
-- A logout shorter than this is no break (a relog, a quick errand away): no
-- night, no rest, no chapter closed. (The book written at the logout itself
-- can't know: it tells a break; the next login puts it right.)
local SHORT = 30 * 60
local function settle(l, c, ahead)
  local ch = c.chapters and c.chapters[#c.chapters]
  if not ch or ch.ended or c.closed then return end
  if not ahead and l.at and now() - l.at < SHORT then return end
  local rested = l.rest or l.fire
  local function note(k, fields)
    fields.at, fields.night, fields.zone, fields.sub, fields.inside = l.at, l.night, l.zone, l.sub, l.inside
    fields.k = k
    table.insert(ch.log, fields)
  end
  if rested and moments(ch) >= MIN_MOMENTS then
    close(ch, l.fire and "campfire" or "rest", l, ahead)
  elseif ch.played >= CAP then
    note("night", { last = true })
    close(ch, "long", l, ahead)
  else
    if rested then
      note("rested", { place = l.place, fire = l.fire })
    else
      note("night", {})
    end
    if ahead then return end
    local zone, sub = where()
    table.insert(ch.log, {
      k = "wake",
      at = now(),
      night = night() or nil,
      after = rested and "rest" or "night",
      zone = zone or l.zone,
      sub = sub or l.sub,
      inside = l.inside,
    })
  end
end

-- The journal as the next login will find it, if this logout is a real one: a
-- copy (the book written at logout tells the chapter a rest just closed).
function ns.settledView(c)
  if not c.logout or c.closed then return c end
  local view = ns.copy(c, "book")
  settle(view.logout, view, true)
  view.logout = nil
  return view
end

ns.on("PLAYER_ENTERING_WORLD", function(initial, reloading)
  local c = char()
  if reloading then
    c.logout = nil -- a /reload, not a night's rest
  elseif initial and c.logout then
    local l = c.logout
    c.logout = nil
    settle(l, c)
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
  -- a dungeon's own name: its entry tells it (PLAYER_ENTERING_WORLD below)
  local inside, kind
  if IsInInstance then
    inside, kind = IsInInstance()
  end
  if inside and (kind == "party" or kind == "raid") and not sub then return end
  -- a chapter begun before the game said where (Forever, at login): this is
  -- where it began, not an arrival
  local ch = chapter()
  if ch.start and not ch.start.zone and #(ch.log or {}) == 0 then
    ch.start.zone, ch.start.sub = zone, sub
    return
  end
  moment("place", { new = newZone and "zone" or nil })
end
for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do
  ns.on(e, moved)
end
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
-- The highest level the game allows: the journey's end. The chapter closes
-- there, and the journal with it.
local function maxLevel()
  local max = GetMaxPlayerLevel and GetMaxPlayerLevel()
  if (not max or secret(max)) and MAX_PLAYER_LEVEL_TABLE and GetExpansionLevel then
    max = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]
  end
  return (type(max) == "number" and max > 0) and max or 60
end
ns.on("PLAYER_LEVEL_UP", function(newLevel)
  local c = char()
  if c.finished then return end
  moment("level", { level = newLevel })
  if not secret(newLevel) and newLevel >= maxLevel() then
    local zone, sub = where()
    local ch = chapter()
    ch.ended = { at = now(), level = newLevel, zone = zone, sub = sub, place = sub or zone, how = "summit" }
    c.finished = true
    changed()
  end
end)

-- ── quests ───────────────────────────────────────────────────────────────────
-- Who gave a quest (the one I was talking to when I accepted it) and its
-- title, kept until it is turned in (the title may be out of the game's cache
-- by then). Classic passes (index, id), Forever (id).
local function titleOf(id)
  return (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id))
    or (GetTitleForQuestID and GetTitleForQuestID(id))
    or nil
end

-- What a quest asks, from the quest log: its objectives' lines ("Kobold
-- Vermin slain: 0/10", "Tough Wolf Meat: 0/8"), read through the game's own
-- formats; the rest ("Find the missing diplomat") kept as it is.
local function rawObjectives(id)
  local raw = {}
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
    for _, o in ipairs(ok and list or {}) do
      table.insert(raw, { text = o.text, type = o.type, n = o.numRequired, finished = o.finished })
    end
  elseif GetQuestLogIndexByID and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    local index = GetQuestLogIndexByID(id)
    if index and index > 0 then
      for i = 1, GetNumQuestLeaderBoards(index) or 0 do
        local text, type, finished = GetQuestLogLeaderBoard(i, index)
        table.insert(raw, { text = text, type = type, finished = finished })
      end
    end
  end
  return raw
end
-- Every objective met. A quest with none (an escort, a word to carry) is
-- done when the game says so: complete from the start, it was only to carry.
local function finishedAll(id)
  local raw = rawObjectives(id)
  if #raw == 0 then
    local api = (C_QuestLog and C_QuestLog.IsComplete) or IsQuestComplete
    if not api then return false end
    local ok, done = pcall(api, id)
    return ok and not secret(done) and (done == true or done == 1)
  end
  for _, o in ipairs(raw) do
    if not o.finished then return false end
  end
  return true
end
local function objectivesOf(id)
  local raw = rawObjectives(id)
  local out = {}
  for _, o in ipairs(raw) do
    if o.text and not secret(o.text) then
      local name, n, have, own
      for _, g in ipairs({ "QUEST_MONSTERS_KILLED", "QUEST_OBJECTS_FOUND" }) do
        local a, b, c = ns.match(g, o.text)
        if a then
          name, have, n = a, tonumber(b), tonumber(c)
          own = g ~= "QUEST_MONSTERS_KILLED"
          break
        end
      end
      -- a name the game hasn't filled in yet (an item not loaded: "0/8 "): the
      -- objectives aren't known yet, and are read again at the next update
      if name then
        name = name:match("^%s*(.-)%s*$")
        if name == "" or name:match("^%d+$") then return nil end
      end
      -- a kill told in the quest's own words ("Peons Awoken: 0/5"): its text,
      -- not a creature's name
      if o.type == "monster" and own then
        o.text, name = name, nil
      end
      -- an item already in hand when the quest is taken: a thing to deliver
      local held = o.type == "item" and (o.finished or (have and n and have >= n)) or nil
      -- (an event's count, before or after it: "0/1 Find the camp", "Find the camp: 0/1")
      local event = not name and (o.text:gsub(":%s*%d+/%d+$", ""):gsub("^%d+/%d+%s*", "")) or nil
      if event and not event:find("%S") then return nil end -- nothing but a count yet
      table.insert(out, { type = o.type, name = name, n = n or o.n, text = event, held = held })
    end
  end
  return #out > 0 and out or nil
end

ns.on("QUEST_ACCEPTED", function(a, b)
  local id, c = b or a, char()
  if not id then return end
  c.pending = c.pending or {}
  -- (a quest from an item: no npc; the target then only if a living friend,
  -- not the corpse the item came from)
  -- (nor a player: a quest shared by a companion is mine, its giver unknown)
  local friendly = UnitExists
    and UnitExists("target")
    and not (UnitIsDead and UnitIsDead("target"))
    and not (UnitCanAttack and UnitCanAttack("player", "target"))
    and not (UnitIsPlayer and UnitIsPlayer("target"))
  local giver = UnitName("npc") or (friendly and UnitName("target")) or nil
  local objectives = objectivesOf(id)
  c.pending[id] = {
    giver = (giver and not secret(giver)) and giver or nil,
    title = titleOf(id),
    objectives = objectives,
    held = finishedAll(id) or nil,
  } -- done from the start: nothing to tell before the turn-in
end)
-- The quest log fills in after the acceptance (the objectives, once known),
-- and tells when a quest's work is done: told then and there, where it
-- happened; the turn-in, later, is the return to who asked.
-- (a name kept before the game had filled it in: "0" by 0.5.0, " " by 0.5.1;
-- read again while the quest is still in the log)
local function misread(objectives)
  for _, o in ipairs(objectives or {}) do
    if o.name and (o.name:match("^%d+$") or not o.name:find("%S")) then return true end
  end
  return false
end
ns.on("QUEST_LOG_UPDATE", function()
  for id, p in pairs(char().pending or {}) do
    if not p.objectives then
      p.objectives = objectivesOf(id)
      if p.objectives and finishedAll(id) then p.held = true end
    elseif misread(p.objectives) then
      p.objectives = objectivesOf(id) or p.objectives -- (its work, if done, still told below)
    end
    if not p.done and not p.held and finishedAll(id) then
      p.done = true
      moment("done", { id = id, title = p.title, giver = p.giver, objectives = p.objectives })
    end
  end
end)
-- Who I returned to: the one I talk to when the quest is completed.
local ender
-- Objectives still without their names (the item not loaded yet): read
-- again, while the quest is still in the log (the turn-in window too).
local function named(id, p)
  if p and (not p.objectives or misread(p.objectives)) then p.objectives = objectivesOf(id) or p.objectives end
end
ns.on("QUEST_COMPLETE", function()
  local name = UnitName("npc")
  ender = (name and not secret(name)) and name or nil
  local id = GetQuestID and GetQuestID()
  if id and id ~= 0 then named(id, (char().pending or {})[id]) end
end)
ns.on("QUEST_TURNED_IN", function(id)
  local c = char()
  local p = c.pending and c.pending[id] or {}
  named(id, c.pending and c.pending[id])
  local ch = chapter()
  ch.quests = ch.quests + 1
  moment("quest", {
    id = id,
    title = titleOf(id) or p.title,
    giver = p.giver,
    ender = ender,
    objectives = p.objectives,
    told = p.done or nil,
  }) -- told: its work was told when done
  ender = nil
  if c.pending then c.pending[id] = nil end
end)

-- A quest gone from the log without a turn-in (abandoned, failed): its work,
-- if it was told in the chapter still being written, is taken back. (A closed
-- chapter never changes.) A moment later: a turn-in may be on its way.
ns.on("QUEST_REMOVED", function(id)
  local function check()
    local c = char()
    if not (c.pending and c.pending[id]) then return end
    c.pending[id] = nil
    local ch = c.chapters and c.chapters[#c.chapters]
    if not ch or ch.ended then return end
    for _, m in ipairs(ch.log) do
      if m.k == "done" and m.id == id then m.abandoned = true end
    end
    changed()
  end
  if C_Timer then
    C_Timer.After(1, check)
  else
    check()
  end
end)

-- ── the creatures met (for their kind and rank when they die) ───────────────
local units = {} -- guid = { name, kind, rank }
local seenOrder = {} -- their guids, the oldest first (the last 300 kept)
local function seen(unit)
  if not UnitExists(unit) or UnitIsPlayer(unit) then return end
  local guid = UnitGUID(unit)
  if not guid or secret(guid) or units[guid] then return end
  local name, ctype, family, rank =
    UnitName(unit), UnitCreatureType(unit), UnitCreatureFamily(unit), UnitClassification(unit)
  if secret(name) then return end
  units[guid] = {
    name = name,
    kind = (not secret(family) and family) or (not secret(ctype) and ctype) or nil,
    rank = not secret(rank) and rank or nil,
  }
  table.insert(seenOrder, guid)
  if #seenOrder > 300 then units[table.remove(seenOrder, 1)] = nil end
end
ns.on("PLAYER_TARGET_CHANGED", function() seen("target") end)
ns.on("UPDATE_MOUSEOVER_UNIT", function() seen("mouseover") end)
ns.on("NAME_PLATE_UNIT_ADDED", function(unit) seen(unit) end) -- (names only: nothing depends on them)

-- A kill: counted for the recap; the chapter's first of a creature is a
-- moment (the first of its kind for the character, an elite outside
-- dungeons); a rare or a world boss always is.
local function slain(guid, name)
  if battleground() then return end
  local u = units[guid] or { name = name }
  if not u.name then return end
  local c, ch = char(), chapter()
  local firstHere = ch.kills[u.name] == nil
  ch.kills[u.name] = (ch.kills[u.name] or 0) + 1
  if u.rank == "rare" or u.rank == "rareelite" or u.rank == "worldboss" then
    moment("rare", { name = u.name, elite = u.rank ~= "rare" or nil })
  elseif firstHere then
    -- a first of its kind, for a life followed from its first levels (one
    -- met later has surely met wolves before)
    local first = u.kind and not c.kinds[u.kind] and (c.began and c.began.level or 1) <= 5 or nil
    local inside = IsInInstance and IsInInstance()
    -- a quest's quarry: the quest, turned in, tells it
    local quarry
    for _, p in pairs(c.pending or {}) do
      for _, o in ipairs(p.objectives or {}) do
        if o.name == u.name then quarry = true end
      end
    end
    moment("kill", {
      name = u.name,
      kind = u.kind,
      first = first,
      elite = (u.rank == "elite" and not inside) or nil,
      quarry = quarry,
    })
  end
  if u.kind then c.kinds[u.kind] = true end
end
ns.slain = slain

-- A player of the other side killed in the open world: who, of what race and
-- class (a battleground's are no part of the tale).
local function vanquished(guid, name, second)
  if battleground() or not guid or secret(guid) then return end
  local race, class
  if GetPlayerInfoByGUID then
    local _, englishClass, _, englishRace = GetPlayerInfoByGUID(guid)
    if not secret(englishClass) then class = englishClass end
    if not secret(englishRace) then race = englishRace end
  end
  local full, first = playerName(name, second)
  -- (the full name kept; the journal calls them by the first)
  moment("pvp", { name = full, first = first ~= full and first or nil, race = race, class = class })
end

-- Kills: my killing blow or my pet's, however it was dealt (a DoT, an area
-- spell, a creature never targeted, one with no loot). PARTY_KILL (killer,
-- victim) is an event of its own where the client has it (Forever, Classic
-- since 1.15.9), else a line of the combat log. Its GUIDs are secret only in
-- an instance on Forever, where no creature can be told from another.
local partyKill = ns.knows and ns.knows("PARTY_KILL")
local function killed(attacker, victim)
  if not attacker or not victim or secret(attacker) or secret(victim) then return end
  if attacker ~= UnitGUID("player") and attacker ~= UnitGUID("pet") then return end
  -- (one never targeted nor moused over: the game may still know it as a unit)
  local token = UnitTokenFromGUID and UnitTokenFromGUID(victim)
  if token and not secret(token) then seen(token) end
  if victim:find("^Player") then
    if token and not secret(token) then
      vanquished(victim, UnitName(token))
    else
      local name = GetPlayerInfoByGUID and select(6, GetPlayerInfoByGUID(victim))
      vanquished(victim, name)
    end
  elseif victim:find("^Creature") or victim:find("^Vehicle") then
    slain(victim)
  end
end
if partyKill then ns.on("PARTY_KILL", killed) end

local lastHit
if not ns.forever then
  ns.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    local _, sub, _, source, sourceName, _, _, dest, destName = CombatLogGetCurrentEventInfo()
    local me, pet = UnitGUID("player"), UnitGUID("pet")
    -- (a kill: told by PARTY_KILL itself where the client has it)
    local mine = sub == "PARTY_KILL" and not partyKill and (source == me or source == pet) and dest
    if mine and dest:find("^Creature") then
      slain(dest, destName)
    elseif mine and dest:find("^Player") then
      vanquished(dest, destName)
    elseif dest == me and sub == "ENVIRONMENTAL_DAMAGE" then
      local kind = select(12, CombatLogGetCurrentEventInfo())
      lastHit = { env = kind, at = now() }
    elseif dest == me and sourceName and sub:find("_DAMAGE$") then
      lastHit = { name = sourceName, guid = source, at = now() }
    end
  end)
elseif not partyKill then
  -- (a Forever client without PARTY_KILL) My target, watched as the fight goes (its health, its flags), not only
  -- when it's chosen: one I fought (both of us in combat, not another's to
  -- claim) and then see dead is my kill. (A target is mostly chosen before
  -- the fight starts, and dies still chosen.)
  local fought, counted = {}, {}
  local function look()
    if not UnitExists("target") then return end
    local guid = UnitGUID("target")
    if not guid or secret(guid) then return end
    if not UnitIsDead("target") then
      local mine, theirs = UnitAffectingCombat("player"), UnitAffectingCombat("target")
      local claimed = UnitIsTapDenied and UnitIsTapDenied("target")
      if not secret(mine) and not secret(theirs) and not secret(claimed) and mine and theirs and not claimed then
        fought[guid] = true
      end
    elseif fought[guid] and not counted[guid] then
      counted[guid] = true
      if UnitIsPlayer("target") then
        vanquished(guid, UnitName("target"))
      else
        slain(guid, UnitName("target"))
      end
    end
  end
  ns.on("PLAYER_TARGET_CHANGED", look)
  ns.on("PLAYER_REGEN_DISABLED", look)
  ns.onUnit("UNIT_HEALTH", "target", look)
  ns.onUnit("UNIT_FLAGS", "target", look)
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
ns.onUnit("UNIT_HEALTH", "player", function()
  if pending or now() - lastClose < 60 then return end
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
  if C_Timer then
    C_Timer.After(5, check)
  else
    check()
  end
end)

-- ── company and dungeons ─────────────────────────────────────────────────────
local inRaid = false
ns.on("GROUP_ROSTER_UPDATE", function()
  local ch = chapter()
  ch.company = ch.company or {}
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  -- a raid: one moment, its number, not forty names
  local raid = IsInRaid and IsInRaid()
  if raid and not secret(raid) then
    if not inRaid and not secret(n) then moment("group", { raid = n }) end
    inRaid = true
    return
  end
  inRaid = false
  for i = 1, n do
    local unit = IsInRaid and IsInRaid() and ("raid" .. i) or ("party" .. i)
    local name, first = playerName(UnitName(unit))
    if name and name ~= char().name and not ch.company[name] then
      ch.company[name] = true
      moment("group", { name = name, first = first ~= name and first or nil, class = select(2, UnitClass(unit)) })
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
-- A numbered blank keeps its argument's place: the client's "%2$d/%3$d %1$s"
-- ("0/8 Tough Wolf Meat") puts the name last, and match() gives it first.
local patterns = {} -- the game's format = { pattern, order }, each made once
local function pattern(global)
  -- (the game's string by its name: some clients don't have every one)
  -- selene: allow(global_usage)
  local format = _G[global]
  if type(format) ~= "string" then return end
  local known = patterns[format]
  if not known then
    -- the blanks become markers, the rest is escaped, the markers captures
    local order = {}
    local p = format:gsub("%%(%d*)%$?([sd])", function(at, kind)
      order[#order + 1] = tonumber(at) or #order + 1
      return kind == "s" and "\1" or "\2"
    end)
    p = p:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
    known = { "^" .. p .. "$", order }
    patterns[format] = known
  end
  return known[1], known[2]
end
-- The blanks of a game message, in its format's argument order.
local function match(global, text)
  local p, order = pattern(global)
  if not p or type(text) ~= "string" then return end
  local got = { text:match(p) }
  if #got == 0 then return end
  local out = {}
  for i, v in ipairs(got) do
    out[order[i] or i] = v
  end
  return unpack(out, 1, #got)
end
ns.pattern, ns.match = pattern, match
-- Spells learned, read from the game's message (any language); the spell's
-- id, from its link, says what it is: a druid's new form, a warlock's new
-- demon, a class's own steed (a moment of their own); a profession's rank (told
-- by the professions, below: left out here); anything else, a trainer's
-- lesson (spells learned together are one moment).
local POWERS = {
  [5487] = "form",
  [768] = "form",
  [1066] = "form",
  [783] = "form",
  [9634] = "form",
  [24858] = "form",
  [33943] = "form",
  [697] = "demon",
  [712] = "demon",
  [691] = "demon",
  [1122] = "demon",
  [18540] = "demon",
  [30146] = "demon",
  [5784] = "steed",
  [23161] = "steed",
  [13819] = "steed",
  [23214] = "steed",
  [34769] = "steed",
  [34767] = "steed",
}
local RANKED = { Apprentice = true, Journeyman = true, Expert = true, Artisan = true, Master = true }
local function professionSpell(name)
  if (char().profs or {})[name] then return true end
  local first = name:match("^(%a+) ")
  return first and RANKED[first] or false
end
ns.on("CHAT_MSG_SYSTEM", function(msg)
  if secret(msg) then return end
  for _, g in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S" }) do
    local raw = match(g, msg)
    if raw then
      local id = tonumber(raw:match("|Hspell:(%d+)"))
      local spell = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", "%1")
      if id and POWERS[id] then
        moment("power", { spell = spell, kind = POWERS[id] })
      elseif not professionSpell(spell) then
        -- a trainer's visit is one moment: spells learned together merge
        local ch = chapter()
        local last = ch.log[#ch.log]
        if last and last.k == "learned" and now() - last.at < 120 then
          table.insert(last.spells, spell)
          changed()
        else
          moment("learned", { spells = { spell } })
        end
      end
      return
    end
  end
end)
local MILESTONES =
  { [50] = true, [75] = true, [100] = true, [150] = true, [200] = true, [225] = true, [250] = true, [300] = true }
ns.on("CHAT_MSG_SKILL", function(msg)
  if secret(msg) then return end
  local skill, rank = match("SKILL_RANK_UP", msg)
  rank = tonumber(rank)
  if skill and rank and MILESTONES[rank] then moment("skill", { name = skill, rank = rank }) end
end)

-- ── professions ──────────────────────────────────────────────────────────────
-- What the character knows of its trades: profs[name] = the rank's ceiling
-- (75 apprentice, 150 journeyman, 225 expert, 300 artisan, 375 master). A new
-- trade, or a new rank, is a moment; riding is one too. Those known when the
-- journal first looks are noted quietly.
local RANK_OF = { [75] = "apprentice", [150] = "journeyman", [225] = "expert", [300] = "artisan", [375] = "master" }
local function trades()
  local out = {}
  if GetNumSkillLines and GetSkillLineInfo then
    if GetNumSkillLines() == 0 then return nil end -- not loaded yet (there are always weapons, languages)
    local section
    for i = 1, GetNumSkillLines() do
      local name, header, _, _, _, _, max = GetSkillLineInfo(i)
      if header then
        section = name
      elseif
        name
        and not secret(name)
        and (section == TRADE_SKILLS or section == SECONDARY_SKILLS or name:find("Riding"))
      then
        out[name] = max or 0
      end
    end
  elseif GetProfessions and GetProfessionInfo then
    for _, index in ipairs({ GetProfessions() }) do
      local name, _, _, max = GetProfessionInfo(index)
      if name and not secret(name) then out[name] = max or 0 end
    end
  end
  return out
end
local function lookAtTrades(quiet)
  local c = char()
  local list = trades()
  if not list then return end
  local known = c.profs
  c.profs = c.profs or {}
  for name, max in pairs(list) do
    local before = c.profs[name]
    c.profs[name] = max
    if known and not quiet then
      if name:find("Riding") and not before then
        moment("riding", { name = name })
      elseif not before then
        moment("prof", { name = name, learned = true })
      elseif max > before and RANK_OF[max] then
        moment("prof", { name = name, rank = RANK_OF[max] })
      end
    end
  end
end
ns.on("SKILL_LINES_CHANGED", function() lookAtTrades(false) end)

-- ── gear ─────────────────────────────────────────────────────────────────────
-- Something worn for the first time (green and above; an item put on again,
-- after another, is no news). worn[itemId] = true; made[itemId] = true for
-- what the character crafted ("You create: ..."), told as such when put on.
local function lookAtGear(quiet)
  local c = char()
  c.worn = c.worn or {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    local id = link and not secret(link) and tonumber(link:match("item:(%d+)"))
    if id and not c.worn[id] then
      c.worn[id] = true
      local _, quality = itemInfo(link)
      if not quiet and quality and quality >= 2 then
        -- (in hand: a weapon, a shield, a bow, taken up rather than put on)
        moment("gear", { link = link, quality = quality, made = (c.made or {})[id] or nil, held = slot >= 16 or nil })
      end
    end
  end
end
ns.on("PLAYER_EQUIPMENT_CHANGED", function() lookAtGear(char().worn == nil) end) -- the first look is quiet

-- Loot: a find of note (blue and above; the green ones are told when worn).
-- Only what is looted: an item received (a quest's reward, a purchase) is
-- no find, and is told when worn, if it is.
ns.on("CHAT_MSG_LOOT", function(msg)
  if secret(msg) then return end
  local c = char()
  for _, g in ipairs({ "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do -- (the counted form first: the other matches it too)
    local found, many = match(g, msg)
    local link = found and msg:match(LINK)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then
      c.made = c.made or {}
      c.made[id] = true
      -- what was made: one moment while the same thing keeps coming
      local count = tonumber(many) or 1
      local log = chapter().log
      local last = log[#log]
      if last and last.k == "made" and last.id == id and now() - last.at < 600 then
        last.n, last.at = last.n + count, now()
        changed()
      else
        moment("made", { id = id, link = link, n = count })
      end
      return
    end
  end
  local mine = false
  for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE" }) do
    if match(g, msg) then mine = true end
  end
  local link = mine and msg:match(LINK)
  if not link then return end
  local _, quality = itemInfo(link)
  if quality and quality >= 3 then moment("loot", { link = link, quality = quality }) end
end)

-- ── a hunter's pet, a first ride ─────────────────────────────────────────────
-- A hunter's new companion (a pet not met before, by name), and its deaths;
-- the first time the character rides a mount of its own.
local petDown = false
local function lookAtPet(quiet)
  local c = char()
  if c.class ~= "HUNTER" then return end
  if not UnitExists("pet") then
    c.pets = c.pets or {} -- no pet yet: the first one tamed is news
    return
  end
  local name, family = UnitName("pet"), UnitCreatureFamily("pet")
  if not name or secret(name) then return end
  c.pets = c.pets or {}
  if not c.pets[name] then
    c.pets[name] = (family and not secret(family)) and family or true
    if not quiet then moment("tame", { name = name, family = c.pets[name] ~= true and c.pets[name] or nil }) end
  end
end
ns.onUnit("UNIT_PET", "player", function() lookAtPet(char().pets == nil) end)
ns.onUnit("UNIT_HEALTH", "pet", function()
  if char().class ~= "HUNTER" then return end
  local dead = UnitIsDead("pet")
  if secret(dead) then return end
  if dead and not petDown then
    local name = UnitName("pet")
    moment("petdied", { name = (name and not secret(name)) and name or nil })
  end
  petDown = dead and true or false
end)
ns.onUnit("UNIT_AURA", "player", function()
  local c = char()
  if c.rode or not IsMounted then return end
  local mounted = IsMounted()
  if mounted and not secret(mounted) then
    c.rode = true
    moment("mount")
  end
end)

-- At login: what the character already wears, knows and keeps, noted quietly
-- (a journal begun mid-life doesn't announce a whole wardrobe).
ns.on("PLAYER_ENTERING_WORLD", function(initial)
  if not initial then return end
  local c = char()
  lookAtGear(c.worn == nil)
  lookAtTrades(c.profs == nil)
  lookAtPet(c.pets == nil)
  if c.rode == nil and IsMounted and IsMounted() then c.rode = true end
end)

ns.on("PLAYER_MONEY", function()
  local c, money = char(), GetMoney()
  if c.money and money > c.money then
    local ch = chapter()
    ch.gold = ch.gold + (money - c.money)
  end
  c.money = money
end)

-- ── death ────────────────────────────────────────────────────────────────────
ns.on("PLAYER_DEAD", function()
  tally()
  local c = char()
  local zone, sub = where()
  local cause = "foe"
  if lastHit and now() - lastHit.at <= 10 and lastHit.env then
    cause = (lastHit.env == "FALLING" and "fall")
      or (lastHit.env == "DROWNING" and "drowning")
      or (lastHit.env == "LAVA" and "lava")
      or "nature"
  end
  local name, guid
  if cause == "foe" then
    name, guid = foe(true)
  end
  local u = guid and units[guid]
  local d = {
    at = now(),
    level = UnitLevel("player"),
    zone = zone,
    sub = sub,
    foe = name,
    cause = cause,
    player = (guid and guid:find("^Player")) and true or nil,
    kind = u and u.kind,
    rank = u and u.rank,
    inside = (IsInInstance and IsInInstance()) or nil,
  }
  c.death = d
  c.deaths = (c.deaths or 0) + 1
  c.dying = not c.hardcore and { at = now(), zone = zone, sub = sub } or nil
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

-- After a death (a normal realm): how I came back. Raised where I fell by a
-- companion (or my own soulstone, my own spirit); or as a ghost from the
-- graveyard, back to my body, or the spirit healer's bargain there.
local SICKNESS = 15007
ns.on("RESURRECT_REQUEST", function(name)
  local d = char().dying
  if d and name and not secret(name) then d.by = name end
end)
ns.on("PLAYER_ALIVE", function()
  local c = char()
  local d = c.dying
  if not d then return end
  local ghost = UnitIsGhost and UnitIsGhost("player")
  if ghost and not secret(ghost) then
    local zone, sub = where()
    d.released, d.graveyard = now(), sub or zone
  else
    c.dying = nil
    moment("revived", { how = d.by and "ally" or "self", by = d.by, took = now() - d.at })
  end
end)
ns.on("PLAYER_UNGHOST", function()
  local c = char()
  local d = c.dying
  if not d then return end
  c.dying = nil
  local function told()
    local healer = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and hasAura(SICKNESS)
    moment(
      "revived",
      { how = healer and "healer" or "corpse", graveyard = d.graveyard, took = now() - (d.released or d.at) }
    )
  end
  if C_Timer then
    C_Timer.After(1, told)
  else
    told()
  end
end)
