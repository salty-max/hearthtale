-- The record in the saved file: ids, never a game name (the family's rule,
-- 15 October 2026). In the game, the record keeps the game's names in English
-- (the journal is written in English, and its writer reads them as they
-- are); at the logout, once the book is written (Save.lua), every name the
-- game has an id for becomes its id (ns.toIds), and at the login its English
-- name again (ns.toNames). A name becomes an id only where the id gives it
-- back exactly, so nothing is lost; a name the tables don't know stays as
-- kept (a quest's own words, a name the game gave in another language, a
-- player's).
--   places: an area "a<id>", a place inside a building "w<id>", a dungeon
--     "m<id>"; a creature's kind: a type "t<id>", a family "f<id>"
--   a creature, a quest's title, a giver: their name false beside the id
--     kept (id, foeId, giverId, enderId); an objective's creature or item by
--     its id (of); an item's link without its name ("|h[]|h")
--   by their numbers: trades and ridings, families, talent trees, spells,
--     flight points, bosses, mounts; the kills, a quest's counts by their
--     creatures
local _, ns = ...
local C = ns.client or {}
local R = ns.record

-- [an English name] = its id (a name two share: the lowest), made at the first need
local reversed = {}
local function reverse(key, names)
  if reversed[key] then return reversed[key] end
  local r = {}
  for id, n in pairs(names or {}) do
    if type(n) == "string" and (not r[n] or id < r[n]) then r[n] = id end
  end
  reversed[key] = r
  return r
end
local function names() return R.names() end
local function creatures() return names().creatures or {} end
local function items() return names().items or {} end
local function quests() return names().quests or {} end

-- ── one kind of name: to its id, from it ─────────────────────────────────────
-- (a number for a kind of its own)
local function numbered(key, list)
  return {
    to = function(n)
      if type(n) ~= "string" then return n end
      return reverse(key, list())[n] or n
    end,
    from = function(v)
      if type(v) ~= "number" then return v end
      return list()[v] or v
    end,
  }
end
-- (a letter and a number where kinds share a field)
local function lettered(kinds)
  return {
    to = function(n)
      if type(n) ~= "string" then return n end
      for _, k in ipairs(kinds) do
        local id = reverse(k.key, k.list())[n]
        if id then return k.letter .. id end
      end
      return n
    end,
    from = function(v)
      if type(v) ~= "string" then return v end
      local letter, id = v:match("^(%a)(%d+)$")
      if not letter then return v end
      for _, k in ipairs(kinds) do
        if k.letter == letter then return k.list()[tonumber(id)] or v end
      end
      return v
    end,
  }
end
local AREA = { letter = "a", key = "areas", list = function() return C.areas or {} end }
local INSIDE = { letter = "w", key = "inside", list = function() return C.inside or {} end }
local DUNGEON = { letter = "m", key = "maps", list = function() return C.maps or {} end }
local PLACE = lettered({ AREA, INSIDE })
local DUNGEON_PLACE = lettered({ DUNGEON, AREA, INSIDE })
local KIND = lettered({
  { letter = "t", key = "types", list = function() return C.typeIds or {} end },
  { letter = "f", key = "families", list = function() return C.familyIds or {} end },
})
local SKILL = numbered("skills", function() return C.skillIds or {} end)
local FAMILY = numbered("families", function() return C.familyIds or {} end)
local TREE = numbered("trees", function() return C.treeIds or {} end)
local SPELL = numbered("spells", function() return C.spells or {} end)
local BOSS = numbered("encounters", function() return C.encounters or {} end)
local MOUNT = numbered("mounts", function() return C.mounts or {} end)
local CREATURE = numbered("creatures", creatures)
-- a flight's ends: a flight point, else a place
local FLIGHT = {
  to = function(n)
    local id = type(n) == "string" and reverse("taxi", C.taxiIds or {})[n]
    return id or PLACE.to(n)
  end,
  from = function(v)
    if type(v) == "number" then return (C.taxiIds or {})[v] or v end
    return PLACE.from(v)
  end,
}

-- ── the record, one way or the other ─────────────────────────────────────────
local function convert(c, out)
  local function way(kind) return out and kind.to or kind.from end
  local function field(t, key, kind)
    if t and t[key] ~= nil then t[key] = way(kind)(t[key]) end
  end
  -- (a table's keys; two of one merged by the first)
  local function rekey(t, fn)
    if type(t) ~= "table" then return t end
    local new = {}
    for k, v in pairs(t) do
      local e = fn(k)
      if new[e] == nil then new[e] = v end
    end
    return new
  end
  local function list(t, kind)
    for i, v in ipairs(t or {}) do
      t[i] = way(kind)(v)
    end
  end
  -- a creature's name beside its id (named: a creature always, a kill's, its
  -- id found by its name where an older record kept none)
  local function creature(t, key, idKey, named)
    if not t then return end
    local id, n = t[idKey], t[key]
    if out then
      if not id and named and type(n) == "string" then
        id = reverse("creatures", creatures())[n]
        t[idKey] = id
      end
      if id and type(n) == "string" and creatures()[id] == n then t[key] = false end
    elseif n == false then
      t[key] = id and creatures()[id] or nil
    end
  end
  -- a quest's title beside its id (a quest in the log: by its key)
  local function title(t, id)
    local q = t and quests()[id or t.id]
    if not q then return end
    if out and type(t.title) == "string" and q.title == t.title then
      t.title = false
    elseif not out and t.title == false then
      t.title = q.title
    end
  end
  -- an objective's creature or item: one of the quest's, by its id
  local function objectives(t, id)
    local q = t and quests()[id or t.id]
    for _, o in ipairs(t and t.objectives or {}) do
      local of = (o.type == "monster" and creatures()) or (o.type == "item" and items()) or nil
      if out and of and q and type(o.name) == "string" then
        local own
        if o.type == "monster" then
          own = q.targets
        else
          own = q.items
        end
        for _, target in ipairs(own or {}) do
          if of[target] == o.name then
            o.of, o.name = target, false
            break
          end
        end
      elseif not out and o.name == false then
        o.name, o.of = of and of[o.of] or nil, nil
      end
    end
  end
  -- an item's link: its name the item's own
  local function link(t, key)
    local l = t and t[key]
    if type(l) ~= "string" then return end
    local id = tonumber(l:match("|Hitem:(%d+)"))
    local n = id and items()[id]
    if not n then return end
    if out and l:match("|h%[(.-)%]|h") == n then
      t[key] = (l:gsub("|h%[.-%]|h", "|h[]|h", 1))
    elseif not out and l:find("|h[]|h", 1, true) then
      t[key] = (l:gsub("|h%[%]|h", function() return "|h[" .. n .. "]|h" end, 1))
    end
  end
  local function where(t)
    for _, key in ipairs({ "zone", "sub", "place" }) do
      field(t, key, PLACE)
    end
  end
  local function death(d)
    if type(d) ~= "table" then return end
    where(d)
    creature(d, "foe", "foeId")
    field(d, "kind", KIND)
  end

  c.visited = rekey(c.visited, function(key)
    local zone, sub = tostring(key):match("^(.-)|(.*)$")
    if not zone then return key end
    local p = way(PLACE)
    return tostring(p(zone)) .. "|" .. (sub ~= "" and tostring(p(sub)) or "")
  end)
  c.kinds = rekey(c.kinds, way(KIND))
  c.profs = rekey(c.profs, way(SKILL))
  c.dropped = rekey(c.dropped, way(SKILL))
  c.powers = rekey(c.powers, way(SPELL))
  c.demons = rekey(c.demons, way(FAMILY))
  for name, f in pairs(c.pets or {}) do
    c.pets[name] = way(FAMILY)(f)
  end
  if c.spec then c.spec = way(TREE)(c.spec) end
  if type(c.prologue) == "table" then
    field(c.prologue, "zone", PLACE)
    field(c.prologue, "inn", PLACE)
  end
  where(c.logout)
  where(c.dying)
  death(c.death)
  for id, p in pairs(c.pending or {}) do
    if type(p) == "table" then
      title(p, id)
      creature(p, "giver", "giverId")
      objectives(p, id)
      -- (a quest's counts, by its creatures)
      p.counted = rekey(p.counted, way(CREATURE))
    end
  end
  for _, ch in ipairs(c.chapters or {}) do
    where(ch.start)
    where(ch.ended)
    ch.kills = rekey(ch.kills, way(CREATURE))
    for _, m in ipairs(ch.log or {}) do
      where(m)
      local k = m.k
      if k == "inn" or k == "rested" then
        field(m, "place", PLACE)
      elseif k == "flight" then
        field(m, "from", FLIGHT)
        field(m, "to", FLIGHT)
      elseif k == "done" or k == "quest" then
        title(m)
        creature(m, "giver", "giverId")
        creature(m, "ender", "enderId")
        objectives(m)
        field(m, "petFamily", FAMILY)
      elseif k == "kill" then
        creature(m, "name", "id", true)
        field(m, "kind", KIND)
      elseif k == "rare" then
        creature(m, "name", "id", true)
      elseif k == "close" then
        creature(m, "foe", "foeId")
      elseif k == "died" then
        death(m.death)
      elseif k == "revived" then
        field(m, "graveyard", PLACE)
      elseif k == "dungeon" then
        field(m, "name", DUNGEON_PLACE)
      elseif k == "boss" then
        field(m, "name", BOSS)
      elseif k == "learned" then
        list(m.spells, SPELL)
        list(m.used, SPELL)
      elseif k == "power" then
        field(m, "spell", SPELL)
      elseif k == "skill" or k == "prof" or k == "riding" then
        field(m, "name", SKILL)
      elseif k == "mount" then
        field(m, "name", MOUNT)
      elseif k == "made" or k == "gear" or k == "loot" or k == "bag" then
        link(m, "link")
      elseif k == "tame" or k == "demon" then
        field(m, "family", FAMILY)
      elseif k == "spec" then
        field(m, "name", TREE)
        field(m, "was", TREE)
      end
    end
  end
  return c
end

-- The record into the saved file's ids (at the logout), and back (at the
-- login); a fallen life's in the Hall too.
function ns.toIds(c) return c and convert(c, true) end
function ns.toNames(c) return c and convert(c, false) end
-- Every record the saved files hold: this character's, and the Hall's.
function ns.savedRecords(char)
  local all = { char }
  local hall = type(HearthtaleHall) == "table" and HearthtaleHall.lives or {}
  for _, life in pairs(hall) do
    if type(life) == "table" then table.insert(all, life) end
  end
  return all
end
-- At the login, every saved record's names again (an English client names
-- nothing by these tables while it plays: let go after).
function ns.namesAtLogin(char)
  for _, c in ipairs(ns.savedRecords(char)) do
    convert(c, false)
  end
  if R.inEnglish() then R.forgetNames() end
end
