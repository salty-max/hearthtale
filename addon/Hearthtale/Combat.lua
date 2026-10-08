-- The fights: the creatures met (their kind and rank, for when they die), my
-- kills and those of the other side, the close calls, death and the way back.
-- (Record.lua keeps the chapters; this file adds their fighting moments.)
local _, ns = ...
local R, secret = ns.record, ns.secret
local char, now, where, changed, moment, chapter = R.char, R.now, R.where, R.changed, R.moment, R.chapter
local battleground, tally, playerName, hasAura, ended = R.battleground, R.tally, R.playerName, R.hasAura, R.ended
-- ── the creatures met (for their kind and rank when they die) ───────────────
local units = {} -- guid = { name, kind, rank }
local seenOrder = {} -- their guids, the oldest first (the last 300 kept)
local byName = {} -- name = the last one seen of that name (for a kill known by its name only)
local byKind = {} -- creature id = the last one seen of that kind (for a kill of one never seen)
local function kindOf(guid) return guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")) end
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
  byName[name] = units[guid]
  local id = kindOf(guid)
  if id then byKind[id] = units[guid] end
  table.insert(seenOrder, guid)
  if #seenOrder > 300 then units[table.remove(seenOrder, 1)] = nil end
end
ns.on("PLAYER_TARGET_CHANGED", function() seen("target") end)
ns.on("UPDATE_MOUSEOVER_UNIT", function() seen("mouseover") end)
ns.on("NAME_PLATE_UNIT_ADDED", function(unit) seen(unit) end) -- (names only: nothing depends on them)

-- A kill: counted for the recap; the chapter's first of a creature is a
-- moment (the first of its kind for the character, an elite outside
-- dungeons); a rare or a world boss always is.
local told = {} -- name = when kills of it were told (a quest's count credits the others)
local function slain(guid, name)
  if battleground() then return end
  local u = (guid and (units[guid] or byKind[kindOf(guid)])) or byName[name] or { name = name }
  if not u.name then return end
  local c, ch = char(), chapter()
  told[u.name] = told[u.name] or {}
  table.insert(told[u.name], now())
  local firstHere = ch.kills[u.name] == nil
  ch.kills[u.name] = (ch.kills[u.name] or 0) + 1
  if u.rank == "rare" or u.rank == "rareelite" or u.rank == "worldboss" then
    moment("rare", { name = u.name, elite = u.rank ~= "rare" or nil })
  elseif firstHere then
    -- a first of its kind, for a life followed from its first levels (one
    -- met later has surely met wolves before)
    local first = u.kind and not c.kinds[u.kind] and (c.began and c.began.level or 1) <= 5 or nil
    local inside = IsInInstance()
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

-- Is this one of us: me, my pet, someone of my group or their pet?
local function ours(guid)
  if guid == UnitGUID("player") or guid == UnitGUID("pet") then return true end
  local raid = IsInRaid()
  local n = GetNumGroupMembers()
  if secret(n) or secret(raid) then return false end
  local unit = raid and "raid" or "party"
  for i = 1, raid and n or n - 1 do
    if guid == UnitGUID(unit .. i) or guid == UnitGUID(unit .. "pet" .. i) then return true end
  end
  return false
end

-- Kills: my killing blow, my pet's or my group's, however it was dealt (a
-- DoT, an area spell, a creature never targeted, one with no loot). PARTY_KILL (killer,
-- victim) is an event of its own where the client has it (Forever, Classic
-- since 1.15.9), else a line of the combat log (Classic before 1.15.9; never
-- on Forever, which forbids it to addons). Its GUIDs are secret only in an
-- instance on Forever, where no creature can be told from another.
local partyKill = ns.knows("PARTY_KILL")
local function killed(attacker, victim)
  if not attacker or not victim or secret(attacker) or secret(victim) then return end
  if not ours(attacker) then return end
  -- (one never targeted nor moused over: the game may still know it as a unit)
  local token = UnitTokenFromGUID and UnitTokenFromGUID(victim)
  if token and not secret(token) then seen(token) end
  if victim:find("^Player") then
    if token and not secret(token) then
      vanquished(victim, UnitName(token))
    else
      local name = select(6, GetPlayerInfoByGUID(victim))
      vanquished(victim, name)
    end
  elseif victim:find("^Creature") or victim:find("^Vehicle") then
    slain(victim)
  end
end
if partyKill then ns.on("PARTY_KILL", killed) end

-- A quest's count of a creature gone up by n (Quests.lua): kills the game
-- credits me with. The ones told above (the event, a moment before or after)
-- are those; the rest were another's killing blow on a creature I fought
-- (Forever credits whoever tagged it), told here.
local function credited(name, n)
  C_Timer.After(2, function()
    local times, t, left = told[name] or {}, now(), n
    for i = #times, 1, -1 do
      if t - times[i] > 10 then
        table.remove(times, i)
      elseif left > 0 then
        table.remove(times, i)
        left = left - 1
      end
    end
    for _ = 1, left do
      slain(nil, name)
      table.remove(told[name]) -- (not a kill the event told)
    end
  end)
end
R.credited = credited

local lastHit
if not ns.forever then
  ns.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    local _, sub, _, source, sourceName, _, _, dest, destName = CombatLogGetCurrentEventInfo()
    local me = UnitGUID("player")
    -- (a kill: told by PARTY_KILL itself where the client has it)
    local mine = sub == "PARTY_KILL" and not partyKill and ours(source) and dest
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
  C_Timer.After(5, check)
end)

-- ── death ────────────────────────────────────────────────────────────────────
ns.on("PLAYER_DEAD", function()
  local c = char()
  -- (the game may tell one death twice)
  if c.death and now() - (c.death.at or 0) < 5 then return end
  tally()
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
    inside = IsInInstance() or nil,
  }
  c.death = d
  c.deaths = (c.deaths or 0) + 1
  c.dying = not c.hardcore and { at = now(), zone = zone, sub = sub } or nil
  if c.hardcore then
    -- the end: the chapter closes with the epitaph
    local ch = chapter()
    ch.ended = ended("death", d.at, d.level, zone, sub)
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
  local ghost = UnitIsGhost("player")
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
  local function revived()
    local healer = hasAura(SICKNESS)
    moment(
      "revived",
      { how = healer and "healer" or "corpse", graveyard = d.graveyard, took = now() - (d.released or d.at) }
    )
  end
  C_Timer.After(1, revived)
end)
