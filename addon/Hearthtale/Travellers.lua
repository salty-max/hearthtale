-- The fellow travellers: the players this account has grouped with, kept
-- apart from the journal (HearthtaleTravellers, account-wide, by the player's
-- GUID). Other players' names stay on this computer: Ravenpost reads the
-- character's record by a list of fields and the account file's
-- HearthtaleCollect alone, and nothing here is written into the book.
--
--   HearthtaleTravellers = {
--     people = { [guid] = {
--       name, first                        who (first: the first name, on Forever)
--       class                              the class token
--       firstAt, firstZone, lastAt, lastZone   when and where, first and last
--       days = { ["2026-10-29"] = true }   the days spent in a group together
--       duo = { [day] = true }             those days spent as a pair, two alone
--       dungeons = { [name] = true }       the dungeons entered together (English)
--       sex                                the sex the game gave (the class's name)
--       with = { [character's guid] = its name }   whom I played as
--       note                               the player's own words
--     } },
--     filled = { [character's guid] = true }   the chapters' company read in once
--   }
-- (a person read from the chapters' company has no GUID yet: "n:Name", taken
-- over by the real one at the next meeting; the zones and dungeons are the
-- game's names in English, into ids at the logout: Ids.lua)
local _, ns = ...
local R, secret = ns.record, ns.secret
local char, now, playerName = R.char, R.now, R.playerName

local NOTE_LIMIT = 1000
-- selene: allow(global_usage) (the game's word for a name not yet known)
local UNKNOWN = _G.UNKNOWNOBJECT

local function store()
  if type(HearthtaleTravellers) ~= "table" then HearthtaleTravellers = {} end
  HearthtaleTravellers.people = HearthtaleTravellers.people or {}
  HearthtaleTravellers.filled = HearthtaleTravellers.filled or {}
  return HearthtaleTravellers
end

local function dayOf(at) return date("%Y-%m-%d", at) end

-- A person to keep: by GUID, a legacy "n:Name" one taken over.
local function person(guid, name)
  local people = store().people
  local p = people[guid]
  if p then return p end
  local old = people["n:" .. name]
  if old then
    people["n:" .. name] = nil
    people[guid] = old
    return old
  end
  p = { days = {}, duo = {}, dungeons = {}, with = {} }
  people[guid] = p
  return p
end

-- Everyone in my party now is met today, here: the days, the pair, the
-- dungeon. A raid or a battleground is no company kept (as Life.lua's).
local function meet()
  local c = char()
  if not c or c.closed then return end
  local n, raid = GetNumGroupMembers(), IsInRaid()
  if secret(n) or secret(raid) or raid or n < 2 or R.battleground() then return end
  local at = now()
  local day = dayOf(at)
  local zone = R.where()
  local dungeon
  local inside, kind = IsInInstance()
  if inside and kind == "party" then
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    if name and not secret(name) then dungeon = R.instance(not secret(id) and id or nil, name) end
  end
  for i = 1, n - 1 do
    local unit = "party" .. i
    local guid = UnitGUID(unit)
    local name, first = playerName(UnitName(unit))
    -- (a name arrives a moment after the join; a secret one is no one yet)
    local connected = UnitIsConnected(unit)
    if
      guid
      and not secret(guid)
      and connected ~= false
      and not secret(connected)
      and name
      and name ~= UNKNOWN
      and name ~= char().name
    then
      local p = person(guid, name)
      p.name, p.first = name, first ~= name and first or nil
      local class = select(2, UnitClass(unit))
      if class and not secret(class) then p.class = class end
      local sex = UnitSex(unit)
      if sex and not secret(sex) then p.sex = sex end
      p.firstAt, p.firstZone = p.firstAt or at, p.firstZone or zone
      p.lastAt, p.lastZone = at, zone or p.lastZone
      p.days[day] = true
      if n == 2 then p.duo[day] = true end
      if dungeon then p.dungeons[dungeon] = true end
      p.with[c.guid] = c.name
    end
  end
end
ns.on("GROUP_ROSTER_UPDATE", meet)
ns.on("PLAYER_ENTERING_WORLD", meet)
ns.meetTravellers = meet -- (for the tests)

-- The company the chapters already tell (the group moments), read in once
-- for this character: when and where each was first and last met, the days.
local function fill()
  local c = char()
  if not c or c.closed then return end
  local t = store()
  if t.filled[c.guid] then return end
  t.filled[c.guid] = true
  local known = {}
  for guid, p in pairs(t.people) do
    -- (a name met as this character: not another realm's of the same name)
    if p.with and p.with[c.guid] then known[p.name or ""] = guid end
  end
  for _, ch in ipairs(c.chapters or {}) do
    for _, m in ipairs(ch.log or {}) do
      if m.k == "group" and m.name and m.at then
        local key = known[m.name] or ("n:" .. m.name)
        local p = t.people[key]
        if not p then
          p = { name = m.name, first = m.first, days = {}, duo = {}, dungeons = {}, with = {} }
          t.people[key] = p
          known[m.name] = key
        end
        p.class = p.class or m.class
        if not p.firstAt or m.at < p.firstAt then
          p.firstAt, p.firstZone = m.at, m.zone
        end
        if not p.lastAt or m.at > p.lastAt then
          p.lastAt, p.lastZone = m.at, m.zone
        end
        p.days[dayOf(m.at)] = true
        p.with[c.guid] = c.name
      end
    end
  end
end
ns.on("PLAYER_ENTERING_WORLD", fill)
ns.fillTravellers = fill -- (for the tests)

-- ── what the page reads ──────────────────────────────────────────────────────
local function count(set)
  local n = 0
  for _ in pairs(set or {}) do
    n = n + 1
  end
  return n
end
ns.countOf = count

-- Everyone kept, the latest met first (key: their GUID, or "n:Name").
function ns.travellers()
  local list = {}
  for key, p in pairs(store().people) do
    if type(p) == "table" and p.name then table.insert(list, { key = key, p = p }) end
  end
  table.sort(list, function(a, b)
    local x, y = a.p.lastAt or 0, b.p.lastAt or 0
    if x ~= y then return x > y end
    return a.p.name < b.p.name
  end)
  return list
end
function ns.traveller(key) return store().people[key] end

-- The player's own note on someone (empty: removed). False when there is none.
function ns.setTravellerNote(key, text)
  local p = store().people[key]
  if not p then return false end
  text = ns.clean(text or "", NOTE_LIMIT)
  p.note = text ~= "" and text or nil
  if ns.refresh then ns.refresh() end
  return true
end
