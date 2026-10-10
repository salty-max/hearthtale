-- The journal's record, kept as it happens for the writer to tell: chapters
-- of moments, and what the character is. A chapter is a stretch of the road
-- between two rests: it closes when the character logs out resting (an inn, a
-- city, a campfire) with a few moments written, or at any logout once it holds
-- four hours of play; a logout elsewhere is a night outdoors, and the chapter
-- goes on. This file keeps the chapters, the moments, the logouts and the
-- places; Quests.lua, Combat.lua and Life.lua record the rest.
--
--   HearthtaleChar (Core.lua: guid, began, chapters, closed, book, link) and
--     race, class, faction, name, sex, realm, region   who and where (for the site)
--     hardcore, hardcoreChosen                       (chosen: in the settings, where the game can't tell)
--     prologue = { level, quests, inn, zone, gold, played }   a character met mid-life
--     visited[zone .. "|" .. sub], kinds[kind]       the firsts, life-long
--     money, pending[questId], worn[itemId], made[itemId], profs[name], pets[name], rode
--     powers[spell], demons[family], forms[form]   a warlock's or a druid's, learned here; the
--                                                    first of each told (a demon by its name)
--     bagged, rich                                   a first bag worn, a first gold piece (false: not yet)
--     logout = { at, rest, fire, place, zone, sub, level, night, inside }   the last
--                                                    logout, settled at the next login
--     finished                                       the highest level reached: nothing more is told
--     death, deaths, dying                           the last death; how many; the way back from it
--   chapters[i] = {
--     start = { at, level, zone, sub, night }
--     log = { moment, ... }                          in order (below)
--     kills = { [name] = n }, quests = n             for the closing recap
--     played = seconds, gold = copper                time played in it, money gained
--     company = { [name] = true }                    who joined (a group's names, once each)
--     ended = { at, level, zone, sub, place, how, inside }   how: rest, campfire,
--                                                    long (the cap), summit, death
--   }
--   moments: { k = kind, at, night, zone, sub, grouped, ... }
--     place { new = "zone" or nil }  inn { place }  flight { from, to }  level { level }
--     done { id, title, giver, objectives, abandoned, pet, petFamily }   a quest's work done
--                                                    (pet: the one at my side then)
--     quest { id, title, giver, ender, objectives, told,   a quest turned in (told: its
--             giverSex, enderSex, enderBeast }
--                                                    work was told when done); objectives =
--                                                    { { type, name, n, text, held } }
--     kill { name, kind, first, elite, quarry }      the chapter's first of a creature (killed by
--                                                    me, my pet, my group, or credited by a quest)
--     rare { name, elite }  pvp { name, first, race, class }  close { foe, hp }
--     died { death }  revived { how, by, graveyard, took }
--     group { name, first, class } or { raid = n }  dungeon { name }  boss { name }
--     learned { spells }  power { spell, kind }  skill { name, rank }
--     prof { name, learned or rank }  riding { name }  mount { name, kind }  made { id, link, n }
--     gear { link, quality, made, held, trinket }  loot { link, quality }
--     tame { name, family }  petdied { name }  demon { name, family }  shift { form }
--     bag { link, slots, looted }  gold
--     campfire { camp, with }  rested { place, fire }  night { last, inside }  wake { after, inside }
local _, ns = ...
local secret = ns.secret

-- ── helpers shared by the record's files (ns.record) ─────────────────────────
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

local CAP = 4 * 3600 -- a chapter's play time after which any logout closes it
local MIN_MOMENTS = 3 -- what a chapter needs before a rest can close it
-- The auras of a campfire: Cozy Fire (the cooking fires, both games), and
-- Forever's camps (Welcoming Campfire, Well Rested).
local FIRES = { 7353, 7358, 1232234, 1229739, 1289723, 1225478 }
local CAMPS = { [1232234] = true, [1229739] = true, [1289723] = true, [1225478] = true }

local function char() return ns.journal() end
local function now() return time() end
local function night()
  -- no night or day under the ground: a dungeon is neither
  local inside, kind = IsInInstance()
  if inside and (kind == "party" or kind == "raid") then return false end
  local h = GetGameTime()
  return h ~= nil and not secret(h) and (h < 6 or h >= 18)
end
local function where()
  local zone, sub = GetRealZoneText(), GetSubZoneText()
  if secret(zone) then zone = nil end
  if secret(sub) or sub == "" or sub == zone then sub = nil end
  return zone, sub
end
local function changed()
  if ns.onRecord then ns.onRecord() end
end
-- How a chapter ended (rest, campfire, long, summit, death), when and where.
local function ended(how, at, level, zone, sub, inside)
  return { at = at, level = level, zone = zone, sub = sub, place = sub or zone, how = how, inside = inside }
end

-- The game's own messages, read through its own patterns (any language).
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
ns.match = match -- (for the tests)

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
  local n = GetNumGroupMembers()
  if not secret(n) and n > 0 then m.grouped = true end
  table.insert(ch.log, m)
  changed()
  return m
end

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

-- The quests turned in so far, in this life: a modern client's list, or an
-- older one's table.
local function questsDone()
  if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then return #(C_QuestLog.GetAllCompletedQuestIDs() or {}) end
  local n = 0
  for _ in pairs(GetQuestsCompleted and GetQuestsCompleted() or {}) do
    n = n + 1
  end
  return n
end

ns.on("PLAYER_LOGIN", function()
  local c = char()
  c.visited, c.kinds = c.visited or {}, c.kinds or {}
  if not c.closed then c.hardcore = hardcore() or c.hardcoreChosen or nil end -- chosen: in the settings, where the game can't tell
  c.race, c.class = select(2, UnitRace("player")), select(2, UnitClass("player"))
  local faction = UnitFactionGroup("player")
  if not secret(faction) and (faction == "Alliance" or faction == "Horde") then c.faction = faction:lower() end
  c.name, c.sex = playerName(UnitName("player")), UnitSex("player")
  -- where it lives, for the site (the Battle.net region: 1 US, 3 EU...)
  c.realm, c.region = GetRealmName(), GetCurrentRegion()
  -- A character met mid-life: what the game can say of the life so far.
  if not c.prologue and (c.began.level or 1) > 1 then
    local zone = where()
    c.prologue =
      { level = c.began.level, quests = questsDone(), inn = GetBindLocation(), zone = zone, gold = GetMoney() }
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
-- An aura of mine, by its spell id; nil where the client can't tell by id.
local function hasAura(id)
  local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
  if not get then return nil end
  local ok, aura = pcall(get, id)
  return ok and aura ~= nil
end
local isFire = {}
for _, id in ipairs(FIRES) do
  isFire[id] = true
end
-- (which fire: its aura's id, else false)
local function byFire()
  if hasAura(FIRES[1]) ~= nil then
    for _, id in ipairs(FIRES) do
      if hasAura(id) then return id end
    end
    return false
  end
  -- (a client that can't tell by id: the buffs once over)
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    if not name then return false end
    if spellId and not secret(spellId) and isFire[spellId] then return spellId end
  end
  return false
end
-- The party with me, by first name (not a raid's forty).
local function present()
  local n, raid = GetNumGroupMembers(), IsInRaid()
  if secret(n) or secret(raid) or raid or not n or n < 2 then return nil end
  local out = {}
  for i = 1, n - 1 do
    local name, first = playerName(UnitName("party" .. i))
    if name then table.insert(out, first or name) end
  end
  return #out > 0 and out or nil
end

-- A campfire's warmth: a moment per stop (a fire found again within the hour,
-- in the same place, is the same stop): one of Forever's camps or not, and
-- who sat at it with me.
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
    if not (last and now() - last.at < 3600 and last.zone == zone and last.sub == sub) then
      moment("campfire", { camp = CAMPS[fire] or nil, with = present() })
    end
  end
  warm = fire
end)

-- At logout: where, and whether resting. The next login decides.
ns.on("PLAYER_LOGOUT", function()
  tally()
  local zone, sub = where()
  local rest, inside = IsResting(), IsIndoors()
  char().logout = {
    at = now(),
    rest = (rest and not secret(rest)) or nil,
    fire = byFire() and true or nil,
    zone = zone,
    sub = sub,
    place = sub or zone,
    level = UnitLevel("player"),
    night = night() or nil,
    inside = (inside and not secret(inside)) or nil,
  }
end)

local function close(ch, how, l, ahead)
  ch.ended = ended(how, l.at, l.level, l.zone, l.sub, l.inside)
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
  -- a dungeon's own name: its entry tells it (Life.lua)
  local inside, kind = IsInInstance()
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
  local place = GetBindLocation()
  if place and not secret(place) then moment("inn", { place = place }) end
end)

hooksecurefunc("TakeTaxiNode", function(index)
  local to, from = TaxiNodeName(index), nil
  for i = 1, NumTaxiNodes() do
    if TaxiNodeGetType(i) == "CURRENT" then from = TaxiNodeName(i) end
  end
  if to and from then moment("flight", { from = from, to = to }) end
end)

-- ── levels ───────────────────────────────────────────────────────────────────
-- The highest level the game allows: the journey's end. The chapter closes
-- there, and the journal with it.
local function maxLevel()
  local max = GetMaxPlayerLevel()
  return (not secret(max) and type(max) == "number" and max > 0) and max or 60
end
ns.on("PLAYER_LEVEL_UP", function(newLevel)
  local c = char()
  if c.finished then return end
  moment("level", { level = newLevel })
  if not secret(newLevel) and newLevel >= maxLevel() then
    local zone, sub = where()
    chapter().ended = ended("summit", now(), newLevel, zone, sub)
    c.finished = true
    changed()
  end
end)

-- (for the record's other files)
ns.record = {
  char = char,
  now = now,
  night = night,
  where = where,
  changed = changed,
  ended = ended,
  match = match,
  itemInfo = itemInfo,
  LINK = LINK,
  playerName = playerName,
  hasAura = hasAura,
  chapter = chapter,
  moment = moment,
  battleground = battleground,
  tally = tally,
}
