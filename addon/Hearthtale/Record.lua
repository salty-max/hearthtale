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
--     spec                                           the specialization held (false: none yet)
--     logout = { at, rest, fire, place, zone, sub, level, night, inside }   the last
--                                                    logout, settled at the next login
--     finished                                       (before 0.6: the highest level reached, the
--                                                    journal stopped; cleared at login, it goes on)
--     death, deaths, dying                           the last death; how many; the way back from it
--   chapters[i] = {
--     start = { at, level, zone, sub, night }
--     log = { moment, ... }                          in order (below)
--     kills = { [name] = n }, quests = n             for the closing recap
--     played = seconds, gold = copper                time played in it, money gained
--     company = { [name] = true }                    who joined (a group's names, once each)
--     ended = { at, level, zone, sub, place, how, inside }   how: rest, campfire,
--                                                    long (the cap), death; summit before 0.6
--   }
--   moments: { k = kind, at, night, zone, sub, grouped, ... }
--     (the game's names in English on any client, Client_<game>.lua and
--     English_<game>.lua; a creature's id beside its name since 0.10: id,
--     foeId, giverId, enderId. In the saved file, every name by its id:
--     Ids.lua, at the logout and the login.)
--     place { new = "zone" or nil }  inn { place }  flight { from, to }  level { level, top }
--                                                    (top: the highest level the game allows)
--     done { id, title, giver, giverId, objectives, abandoned, pet, petFamily, with }   a quest's work
--                                                    done (pet: the one at my side then;
--                                                    with: the party then, by first name)
--     quest { id, title, giver, giverId, ender, enderId,   a quest turned in (told: its
--             objectives, told, giverSex, enderSex,  work was told when done);
--             enderBeast, with }                     objectives =
--                                                    { { type, name, n, text, held } }
--     kill { name, id, kind, first, elite, quarry }  the chapter's first of a creature (killed by
--                                                    me, my pet, my group, or credited by a quest)
--     rare { name, id, elite }  pvp { name, first, race, class }  close { foe, foeId, hp }
--     died { death }  revived { how, by, graveyard, took }
--     group { name, first, class } or { raid = n }  dungeon { name }  boss { name }
--     learned { spells, used }  power { spell, kind }  skill { name, rank }
--                                                    (used: those cast before the chapter closed)
--     prof { name, learned or rank }  riding { name }  mount { name, kind }  made { id, link, n }
--     gear { link, quality, made, held, trinket }  loot { link, quality }
--     tame { name, family }  petdied { name }  demon { name, family }  shift { form }
--     bag { link, slots, looted }  gold  spec { name, was }
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
-- ── the record in English, whatever the client's language ───────────────────
-- The journal is written in English, the game's names in it too: on a client
-- in another language, a name is kept in English by what the game says it is
-- (Client_<game>.lua: the game's own names by id, and in every language), so
-- a life played in two languages keeps one trade, one place, one path. A name
-- the tables don't know is kept as the game gave it.
local C = ns.client or {}
local function language() return GetLocale and GetLocale() or "enUS" end
local function inEnglish()
  local l = language()
  return l == "enUS" or l == "enGB"
end
-- [a name in the client's language] = its English, from the game's ids and
-- what the game calls each in this language (made at the first need)
local function reverse(names, get)
  local out, ids = {}, {}
  for id in pairs(names or {}) do
    ids[#ids + 1] = id
  end
  table.sort(ids) -- (a name two of them share: the first one's)
  for _, id in ipairs(ids) do
    local ok, here = pcall(get, id)
    if ok and type(here) == "string" and here ~= "" and not out[here] then out[here] = names[id] end
  end
  return out
end
local areaOf, spellOf, insideOf = {}, {}, {} -- [a language] = its names' English
-- (a place inside a building, which has no area id: by the language's list of
-- them, Text_<locale>.lua's, its id, and its English)
local function insideNamed(name)
  local l = language()
  if not insideOf[l] then
    local own = ns.insideNames or {}
    own = (ns.forever and own.inside or own.insideClassic) or {}
    insideOf[l] = reverse(C.inside, function(id) return own[id] end)
  end
  return insideOf[l][name]
end
local function place(name)
  if not name or inEnglish() then return name end
  local l = language()
  if not areaOf[l] then
    local get = C_Map and C_Map.GetAreaInfo
    areaOf[l] = get and reverse(C.areas, get) or {}
  end
  return areaOf[l][name] or insideNamed(name) or (C.taxi or {})[name] or name
end
-- a trade, a secondary skill, a riding; a creature's type, a family; a
-- flight master's place (any language's, a record's from another client too)
local function skill(name) return name and (C.skills or {})[name] or name end
local function creatureType(name) return name and (C.types or {})[name] or name end
local function family(name) return name and (C.families or {})[name] or name end
local function taxi(name) return name and (C.taxi or {})[name] or place(name) end
local function riding(name)
  if name == nil then return false end
  local english = skill(name)
  return (C.riding or {})[english] == true or english:find("Riding") ~= nil
end
-- a spell, a dungeon, a boss: by the id the game gives with it
local function spell(id, name)
  if inEnglish() then return name end
  return (id and (C.spells or {})[id]) or name
end
-- (a spell known only by its name, in the client's language: a record's)
local function spellNamed(name)
  if not name or inEnglish() then return name end
  local l = language()
  if not spellOf[l] then
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    spellOf[l] = get and reverse(C.spells, get) or {}
  end
  return spellOf[l][name] or name
end
local function instance(id, name)
  if inEnglish() then return name end
  return (id and (C.maps or {})[id]) or place(name)
end
local function encounter(id, name)
  if inEnglish() then return name end
  return (id and (C.encounters or {})[id]) or name
end

-- the game's creatures, quests and items, by id (English_<game>.lua: made at
-- the first need, which an English client never has)
local englishNames
local function names()
  englishNames = englishNames or (ns.englishNames and ns.englishNames()) or {}
  return englishNames
end
local function forgetNames() englishNames = nil end
-- a creature's id, from its GUID ("Creature-0-…-<id>-<spawn>")
local function npcId(guid)
  if not guid or secret(guid) then return nil end
  return tonumber(
    guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  )
end
local function creature(id, name)
  if not id or inEnglish() then return name end
  return (names().creatures or {})[id] or name
end
local function questTitle(id, title)
  if not id or inEnglish() then return title end
  local q = (names().quests or {})[id]
  return q and q.title or title
end
-- an objective's creature or item: the quest's k-th of its type
local function objective(id, kind, k, name)
  if not id or not name or inEnglish() then return name end
  local q = (names().quests or {})[id]
  local of = q and ((kind == "monster" and q.targets) or (kind == "item" and q.items))
  local target = of and of[k]
  if not target then return name end
  return (kind == "monster" and (names().creatures or {})[target] or (names().items or {})[target]) or name
end
-- an item's link, its name in English
local function link(l)
  if not l or inEnglish() then return l end
  local id = tonumber(l:match("|Hitem:(%d+)"))
  local name = id and (names().items or {})[id]
  if not name then return l end
  return (l:gsub("|h%[.-%]|h", function() return "|h[" .. name .. "]|h" end, 1))
end

local function where()
  local zone, sub = GetRealZoneText(), GetSubZoneText()
  if secret(zone) then zone = nil end
  if secret(sub) or sub == "" or sub == zone then sub = nil end
  return place(zone), place(sub)
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
  -- a battleground is no part of the tale (but for a level gained there)
  if k ~= "level" and battleground() then return end
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

-- ── a record kept in two languages, mended ──────────────────────────────────
-- Before 0.10 the record kept the game's names in the client's language: a
-- life played in French, then in English, had "Minage" beside "Mining", and a
-- path "Guerrier" after "Warrior". At each login its names are put back in
-- English where the game's tables know them (a place only from the client's
-- own language), and what only a change of language made is let go: a trade
-- given up and taken up again in the same minute or two, a riding told as a
-- trade, a lesson that was a trade's, a specialization named after the class
-- (Forever's, held from the first level), a land "new" that was not. An
-- entry closed with such words is written again. A fallen life's book is
-- left as it closed.
local SWITCH = 120 -- (seconds: a trade dropped and taken up this close is the language changing)
local function mend(c)
  if c.closed then return end
  local classSpec, trees = C.classSpecNames or {}, C.treeNames or {}
  local function kind(name) return family(creatureType(name)) end
  local function tree(name) return trees[name] or name end
  -- (a table's keys in English, two of one merged)
  local function rekey(t, fn, merge)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
      local e = type(k) == "string" and fn(k) or k
      if out[e] ~= nil and merge then
        out[e] = merge(out[e], v)
      elseif out[e] == nil then
        out[e] = v
      end
    end
    return out
  end
  c.profs = rekey(c.profs, skill, math.max)
  c.dropped = rekey(c.dropped, skill)
  c.kinds = rekey(c.kinds, kind)
  c.powers = rekey(c.powers, spellNamed)
  c.demons = rekey(c.demons, family)
  for name, f in pairs(c.pets or {}) do
    if type(f) == "string" then c.pets[name] = family(f) end
  end
  c.visited = rekey(c.visited, function(key)
    local zone, sub = key:match("^(.-)|(.*)$")
    if not zone then return key end
    return place(zone) .. "|" .. (sub ~= "" and place(sub) or "")
  end)
  if c.spec and classSpec[c.spec] then
    c.spec = false -- (none chosen yet: the talents will tell)
  elseif c.spec then
    c.spec = tree(c.spec)
  end
  local TRADE = ns.TRADE_SPELLS or {}
  local dropsLeft, seen = {}, {}
  for i, ch in ipairs(c.chapters or {}) do
    local mended = false
    local function english(t, k, fn)
      local v = t and t[k]
      if type(v) ~= "string" then return end
      local e = fn(v)
      if e ~= v then
        t[k], mended = e, true
      end
    end
    for _, t in ipairs({ ch.start, ch.ended }) do
      english(t, "zone", place)
      english(t, "sub", place)
      english(t, "place", place)
    end
    if ch.start and ch.start.zone then seen[ch.start.zone] = true end
    local log, gone = ch.log or {}, {}
    for _, m in ipairs(log) do
      english(m, "zone", place)
      english(m, "sub", place)
      local k = m.k
      if k == "prof" or k == "riding" or k == "skill" then
        english(m, "name", skill)
      elseif k == "inn" or k == "rested" then
        english(m, "place", place)
      elseif k == "flight" then
        english(m, "from", taxi)
        english(m, "to", taxi)
      elseif k == "dungeon" then
        english(m, "name", place)
      elseif k == "kill" then
        english(m, "kind", kind)
      elseif k == "tame" or k == "demon" then
        english(m, "family", family)
      elseif k == "done" then
        english(m, "petFamily", family)
      elseif k == "revived" then
        english(m, "graveyard", place)
      elseif k == "power" then
        english(m, "spell", spellNamed)
      elseif k == "spec" then
        english(m, "name", tree)
        english(m, "was", tree)
      elseif k == "learned" then
        for _, list in ipairs({ m.spells or {}, m.used or {} }) do
          for j in ipairs(list) do
            english(list, j, spellNamed)
          end
        end
      end
    end
    -- what only a change of language made
    for a, m in ipairs(log) do
      local k = m.k
      if k == "prof" and riding(m.name) then gone[a] = true end -- (a riding is no trade)
      if k == "spec" and classSpec[m.name or ""] then gone[a] = true end
      if k == "spec" and m.was and classSpec[m.was] then
        m.was, mended = nil, true
      end
      if k == "learned" then -- (a trade's lesson is the trade's news)
        local kept = {}
        for _, sp in ipairs(m.spells or {}) do
          if not (TRADE[sp] or (c.profs or {})[skill(sp)]) then table.insert(kept, sp) end
        end
        if #kept < #(m.spells or {}) then
          m.spells, mended = kept, true
          if #kept == 0 then gone[a] = true end
        end
      end
      if k == "prof" and (m.learned or m.dropped) and not gone[a] then
        for b = a + 1, #log do
          local o = log[b]
          if (o.at or 0) - (m.at or 0) > SWITCH then break end
          if
            not gone[b]
            and o.k == "prof"
            and o.name == m.name
            and ((m.learned and o.dropped) or (m.dropped and o.learned))
          then
            gone[a], gone[b] = true, true
            break
          end
        end
      end
      if k == "place" and m.new == "zone" and m.zone and seen[m.zone] then
        m.new, mended = nil, true
      end
      if m.zone then seen[m.zone] = true end
    end
    if next(gone) then
      local kept = {}
      for a, m in ipairs(log) do
        if not gone[a] then table.insert(kept, m) end
      end
      ch.log, mended = kept, true
    end
    for _, m in ipairs(ch.log or {}) do
      if m.k == "prof" and m.dropped then dropsLeft[m.name] = true end
    end
    -- (an entry closed with words this mended: written again)
    local saved = mended and c.book and c.book.chapters and c.book.chapters[i]
    if saved then saved.diary = nil end
  end
  -- (a trade known now, never given up but for a change of language)
  for name in pairs(c.dropped or {}) do
    if (c.profs or {})[name] and not dropsLeft[name] then c.dropped[name] = nil end
  end
end

ns.on("PLAYER_LOGIN", function()
  local c = char()
  c.visited, c.kinds = c.visited or {}, c.kinds or {}
  mend(c)
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
      { level = c.began.level, quests = questsDone(), inn = place(GetBindLocation()), zone = zone, gold = GetMoney() }
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
    local name, spellId = ns.buff(i)
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
  view.book = c.book -- (read, never changed: the words a closed entry keeps, Diary.lua)
  settle(view.logout, view, true)
  view.logout = nil
  return view
end

ns.on("PLAYER_ENTERING_WORLD", function(initial, reloading)
  local c = char()
  local before = #(c.chapters or {})
  if reloading then
    c.logout = nil -- a /reload, not a night's rest
  elseif initial and c.logout then
    local l = c.logout
    c.logout = nil
    settle(l, c)
  end
  if not c.closed then chapter() end
  -- a line in chat at a login or a /reload (not at each loading screen): the
  -- entry going on, or the one this login began (Book.lua; a closed book's:
  -- Core.lua, as it hears nothing)
  if (initial or reloading) and ns.onResume then ns.onResume(#c.chapters, #c.chapters > before) end
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
  local inn = GetBindLocation()
  if inn and not secret(inn) then moment("inn", { place = place(inn) }) end
end)

hooksecurefunc("TakeTaxiNode", function(index)
  local to, from = taxi(TaxiNodeName(index)), nil
  for i = 1, NumTaxiNodes() do
    if TaxiNodeGetType(i) == "CURRENT" then from = taxi(TaxiNodeName(i)) end
  end
  if to and from then moment("flight", { from = from, to = to }) end
end)

-- ── levels ───────────────────────────────────────────────────────────────────
-- The highest level the game allows: a moment of a life (top), and the
-- journal goes on. (One an older version closed there opens again.)
local function maxLevel()
  local max = GetMaxPlayerLevel()
  return (not secret(max) and type(max) == "number" and max > 0) and max or 60
end
ns.on("PLAYER_LEVEL_UP", function(newLevel)
  local top = not secret(newLevel) and newLevel >= maxLevel() or nil
  moment("level", { level = newLevel, top = top })
end)
ns.on("PLAYER_ENTERING_WORLD", function()
  local c = char()
  if c and c.finished then
    c.finished = nil
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
  present = present,
  hasAura = hasAura,
  chapter = chapter,
  moment = moment,
  battleground = battleground,
  tally = tally,
  place = place,
  skill = skill,
  creatureType = creatureType,
  family = family,
  taxi = taxi,
  riding = riding,
  spell = spell,
  spellNamed = spellNamed,
  instance = instance,
  encounter = encounter,
  inEnglish = inEnglish,
  mend = mend,
  npcId = npcId,
  creature = creature,
  questTitle = questTitle,
  objective = objective,
  link = link,
  names = names,
  forgetNames = forgetNames,
}
