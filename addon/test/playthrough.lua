-- Books written by playing the game's real quests: for each race, from its
-- starting zone, the quests open to it (race, class, prerequisites, level),
-- taken a few at a time from their real givers, done against their real
-- targets (the creatures asked for, or those that drop the item asked for),
-- marked done where it happens and turned in to their real enders; reward
-- gear worn, levels gained, a chapter from rest to rest. Every chapter goes
-- through the writer's checks (inspect.lua); the books are written out for
-- reading in .cache/audit/books/.
--   luajit addon/test/playthrough.lua        (after `bun run audit`)
local DIR = "addon/Hearthtale/"
local ns = {}
assert(loadfile(DIR .. "Data_Classic.lua"))("Hearthtale", ns)
assert(loadfile(DIR .. "Names.lua"))("Hearthtale", ns)
assert(loadfile(DIR .. "Writer.lua"))("Hearthtale", ns)
local ok, D = pcall(dofile, ".cache/audit/game.lua")
if not ok then io.stderr:write("no game data: run bun run audit\n") os.exit(1) end

local problems = {}
local function problem(where, msg, text)
  if #problems < 30 then table.insert(problems, ("%s: %s\n    %s"):format(where, msg, text)) end
end
local inspect = dofile("addon/test/inspect.lua")(problem)

-- The game's codes.
local RACE = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local CLASS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local TYPE = { "Beast", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Humanoid", "Critter", "Mechanical" }
local FAMILY = { [1] = "Wolf", [2] = "Cat", [3] = "Spider", [4] = "Bear", [5] = "Boar", [6] = "Crocolisk", [7] = "Carrion Bird",
  [8] = "Crab", [9] = "Gorilla", [11] = "Raptor", [12] = "Tallstrider", [20] = "Scorpid", [21] = "Turtle", [24] = "Bat",
  [25] = "Hyena", [26] = "Owl", [27] = "Wind Serpent" }
-- Each race's road, by the game's zone ids: its starting valley, its land,
-- then its faction's zones in the order players level through them.
local ALLIANCE = { 40, 38, 44, 148, 10, 11, 331, 267, 45, 400, 33 } -- Westfall … Stranglethorn
local HORDE = { 17, 130, 406, 331, 267, 400, 45, 33 } -- the Barrens … Stranglethorn
local ROAD = {
  Human = { 9, 12 }, Dwarf = { 132, 1 }, Gnome = { 132, 1 }, NightElf = { 188, 141, 148 },
  Orc = { 363, 14 }, Troll = { 363, 14 }, Scourge = { 154, 85 }, Tauren = { 220, 215 },
}
local FACTION = { Human = ALLIANCE, Dwarf = ALLIANCE, Gnome = ALLIANCE, NightElf = ALLIANCE,
  Orc = HORDE, Troll = HORDE, Scourge = HORDE, Tauren = HORDE }
local LIVES = { { "Human", "WARRIOR" }, { "Dwarf", "HUNTER" }, { "NightElf", "DRUID" }, { "Gnome", "MAGE" },
  { "Orc", "SHAMAN" }, { "Troll", "PRIEST" }, { "Tauren", "WARRIOR" }, { "Scourge", "ROGUE" } }
local MATES = { "Thessaly", "Brannigan", "Rowan", "Halvard", "Ysolde", "Korrak", "Mirelle", "Durgan" }
local TO = tonumber(os.getenv("PLAYTHROUGH_LEVEL") or "") or 30

local function creature(id) return id and id > 0 and D.creatures[id] or nil end
local function kindOf(c) return FAMILY[c.family or 0] or TYPE[c.type or 0] end

-- A quest one can play: open to the race and class, its targets alive
-- somewhere, its items dropped or found somewhere (or in hand from the start).
local function playable(q, race, class)
  if q.zone == nil or q.zone <= 0 then return false end -- class, profession and holiday quests
  if q.repeatable then return false end -- turned in again and again: a player's choice, not the road
  if q.races and q.races ~= 0 and bit.band(q.races, RACE[race]) == 0 then return false end
  if q.classes and q.classes ~= 0 and bit.band(q.classes, CLASS[class]) == 0 then return false end
  for _, t in ipairs(q.targets or {}) do
    local c = creature(t[1])
    if t[1] > 0 and not (c and c.spawns > 0) then return false end
  end
  for _, pair in ipairs(q.items or {}) do
    local s = D.sources[pair[1]]
    if q.src ~= pair[1] and not (s and ((s.creatures and #s.creatures > 0) or (s.objects and #s.objects > 0))) then return false end
  end
  return true
end

-- What the quest log shows of a quest, as the recorder keeps it (Record.lua):
-- a creature "slain", or the quest's own words; an item; an event's text.
local function objectivesOf(q)
  local out = {}
  for k, t in ipairs(q.targets or {}) do
    local own = q.texts[k] ~= "" and q.texts[k] or nil
    local c = creature(t[1])
    if own then table.insert(out, { type = t[1] > 0 and "monster" or "object", text = own, n = t[2] })
    elseif c then table.insert(out, { type = "monster", name = c.name, n = t[2] })
    else table.insert(out, { type = "object", text = (D.objects[-t[1]] or "?"), n = t[2] }) end
  end
  for _, pair in ipairs(q.items or {}) do
    local item = D.items[pair[1]]
    if item then table.insert(out, { type = "item", name = item.name, n = pair[2], held = q.src == pair[1] or nil }) end
  end
  for k = #(q.targets or {}) + 1, 4 do
    if q.texts[k] and q.texts[k] ~= "" then table.insert(out, { type = "event", text = q.texts[k] }) end
  end
  return #out > 0 and out or nil
end

local function play(race, class)
  local c = { guid = "Player-1-PLAY" .. race, name = "Wanderer", race = race, class = class, began = { level = 1 }, chapters = {} }
  local road = {}
  for _, z in ipairs(ROAD[race]) do table.insert(road, z) end
  for _, z in ipairs(FACTION[race]) do table.insert(road, z) end
  local level, done, kinds = 1, {}, {}
  local zone = road[1]
  local clock, toLevel = 1790000000 + 8 * 3600, 0
  local ch, mates, grouped, told = nil, {}, false, 0
  local function zoneName(id) return D.zones[id] or ("Zone " .. id) end
  local function night() local h = math.floor(clock / 3600) % 24 return h >= 21 or h < 6 end
  local function newChapter()
    ch = { start = { level = level, zone = zoneName(zone), night = night() or nil }, log = {}, kills = {}, quests = 0,
      played = 0, gold = 0 }
    table.insert(c.chapters, ch)
  end
  local function moment(k, fields)
    fields = fields or {}
    fields.k, fields.at, fields.zone, fields.night, fields.grouped = k, clock, fields.zone or zoneName(zone), night() or nil, grouped or nil
    table.insert(ch.log, fields)
    return fields
  end
  local function wait(seconds) clock = clock + seconds; ch.played = ch.played + seconds end
  local function kill(cr, n, quarry)
    if not cr then return end
    local first = ch.kills[cr.name] == nil
    ch.kills[cr.name] = (ch.kills[cr.name] or 0) + n
    wait(40 * n)
    local kind = kindOf(cr)
    if cr.rank == 2 or cr.rank == 4 then moment("rare", { name = cr.name, elite = cr.rank == 2 or nil })
    elseif first then
      moment("kill", { name = cr.name, kind = kind, first = kind and not kinds[kind] or nil, elite = cr.rank == 1 or nil,
        quarry = quarry or nil })
    end
    if kind then kinds[kind] = true end
  end
  -- the first land on the road with a quest open now
  local function opens(z)
    for id, q in pairs(D.quests) do
      local prev = q.prev and math.abs(q.prev)
      if not done[id] and q.zone == z and (q.min or 1) <= level and (q.level or 1) <= level + 3
        and (not prev or done[prev]) and playable(q, race, class) then return true end
    end
  end
  local function nextZone()
    for _, z in ipairs(road) do if opens(z) then return z end end
  end
  newChapter()
  while level <= TO do
    -- the quests open here, now: the lowest first, a few at a time
    local open = {}
    for id, q in pairs(D.quests) do
      local prev = q.prev and math.abs(q.prev)
      if not done[id] and q.zone == zone and (q.min or 1) <= level and (q.level or 1) <= level + 3
        and (not prev or done[prev]) and playable(q, race, class) then table.insert(open, id) end
    end
    table.sort(open, function(a, b) local x, y = D.quests[a], D.quests[b] if x.level ~= y.level then return (x.level or 0) < (y.level or 0) end return a < b end)
    if #open == 0 then
      local z = nextZone()
      if z then
        zone = z
        wait(15 * 60)
        moment("place", { new = "zone" })
      else
        -- nothing open anywhere: a level gained by fighting, as players do
        local here = {}
        for id, q in pairs(D.quests) do
          if done[id] and q.zone == zone then for _, t in ipairs(q.targets or {}) do table.insert(here, t[1]) end end
        end
        kill(creature(here[#here]), 20)
        level, toLevel = level + 1, 0
        moment("level", { level = level })
      end
    else
      local batch = {}
      for i = 1, math.min(4, #open) do batch[i] = open[i] end
      local accepted = {}
      for _, id in ipairs(batch) do
        local q = D.quests[id]
        local giver = q.starters and creature(q.starters[1])
        accepted[id] = { giver = giver and giver.name, objectives = objectivesOf(q) }
        wait(60)
      end
      -- an elite to fight: company for it
      local elite = false
      for _, id in ipairs(batch) do
        for _, t in ipairs(D.quests[id].targets or {}) do if (creature(t[1]) or {}).rank == 1 then elite = true end end
      end
      if elite and not grouped then
        grouped = true
        local a, b = MATES[(told % #MATES) + 1], MATES[((told + 3) % #MATES) + 1]
        moment("group", { name = a }); moment("group", { name = b })
      end
      for _, id in ipairs(batch) do
        local q, a = D.quests[id], accepted[id]
        wait(5 * 60)
        for k, t in ipairs(q.targets or {}) do kill(creature(t[1]), t[2], q.texts[k] == "") end
        for _, pair in ipairs(q.items or {}) do
          local s = D.sources[pair[1]]
          if q.src ~= pair[1] and s and s.creatures then
            -- the creature that drops it most widely (not a lone boss that happens to)
            local best
            for _, cid in ipairs(s.creatures) do
              local cr = creature(cid)
              if cr and cr.spawns > 0 and (not best or cr.spawns > best.spawns) then best = cr end
            end
            kill(best, best and best.spawns > 1 and math.ceil(pair[2] * 1.5) or 1)
          elseif q.src ~= pair[1] then wait(math.floor(4 * 60 * pair[2] / 2)) end
        end
        local held = a.objectives and a.objectives[1] and a.objectives[1].held
        if a.objectives and not held then
          a.done = true
          moment("done", { id = id, title = q.title, giver = a.giver, objectives = a.objectives })
        end
      end
      if grouped and not elite then grouped = false end
      -- back to who asked, each in turn
      wait(10 * 60)
      for _, id in ipairs(batch) do
        local q, a = D.quests[id], accepted[id]
        local ender = q.enders and creature(q.enders[1])
        moment("quest", { id = id, title = q.title, giver = a.giver, ender = ender and ender.name, objectives = a.objectives,
          told = a.done or nil })
        ch.quests, ch.gold = ch.quests + 1, ch.gold + (q.money or 0)
        done[id], told = true, told + 1
        for _, r in ipairs(q.rewards or {}) do
          local item = D.items[r]
          if item and (item.class == 2 or item.class == 4) and (item.slot or 0) > 0 and (item.quality or 0) >= 2 then
            moment("gear", { link = ("|cff1eff00|Hitem:%d|h[%s]|h|r"):format(r, item.name), quality = item.quality,
              held = item.class == 2 or (item.slot or 0) == 14 or nil }) -- a weapon, a shield
            break
          end
        end
        toLevel = toLevel + 1
        if toLevel >= 4 + math.floor(level / 4) then
          toLevel, level = 0, level + 1
          moment("level", { level = level })
        end
      end
      -- a rest, now and then: the chapter closes
      if ch.played >= 9000 then
        ch.ended = { level = level, place = zoneName(zone), how = "rest" }
        clock = clock + 9 * 3600
        newChapter()
      end
    end
  end
  return c
end

-- The people who give and take back quests: none named three times in a
-- paragraph (a second mention reads without the name).
local PEOPLE = {}
for _, q in pairs(D.quests) do
  for _, id in ipairs(q.starters or {}) do if D.creatures[id] then PEOPLE[D.creatures[id].name] = true end end
  for _, id in ipairs(q.enders or {}) do if D.creatures[id] then PEOPLE[D.creatures[id].name] = true end end
end
local function namedOnce(where, text)
  for paragraph in (text or ""):gmatch("[^\n]+") do
    local counts = {}
    for name in pairs(PEOPLE) do
      if #name > 3 and paragraph:find(name, 1, true) then
        -- (a possessive is an item's name, "Gazlowe's Ledger", not a mention)
        local _, n = paragraph:gsub(name:gsub("%p", "%%%0") .. "%f[^%w']", "")
        if n >= 3 then problem(where, name .. " named " .. n .. " times in a paragraph", paragraph) end
      end
    end
  end
end

os.execute("mkdir -p .cache/audit/books")
local books, chapters, quests = 0, 0, 0
for _, life in ipairs(LIVES) do
  local c = play(life[1], life[2])
  local book = ns.writeBook(c)
  books = books + 1
  local f = io.open((".cache/audit/books/%s-%s.md"):format(life[1], life[2]:lower()), "w")
  f:write(("# %s %s, levels 1 to %d\n\n"):format(life[1], life[2]:lower(), c.chapters[#c.chapters].start.level))
  for _, ch in ipairs(book.chapters) do
    chapters = chapters + 1
    inspect(("%s %s chapter %d"):format(life[1], life[2], ch.number), ch.text)
    namedOnce(("%s %s chapter %d"):format(life[1], life[2], ch.number), ch.text)
    f:write(("## Chapter %d (levels %d to %d)\n\n%s\n\n"):format(ch.number, ch.from, ch.to, ch.text or ""))
  end
  for _, ch in ipairs(c.chapters) do quests = quests + ch.quests end
  f:close()
end
io.write(("%d books, %d chapters, %d real quests played → .cache/audit/books/\n"):format(books, chapters, quests))
if #problems > 0 then
  io.write(table.concat(problems, "\n"), "\n")
  os.exit(1)
end
io.write("all good (playthroughs)\n")
