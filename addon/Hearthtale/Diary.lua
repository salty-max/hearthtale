-- The diary (a prototype beside the chapters of Writer.lua): each chapter as
-- the character would write it at the rest that ends it, the stretch looked
-- back on rather than told moment by moment. From the same record, the
-- moments that matter: where it began, new lands, new powers and the firsts
-- of a life, the foes worth naming, deaths and close calls, a dungeon,
-- company; the ordinary work in one sentence; a thought on the kind of
-- stretch it was; the rest that ends it. Its sentences are the book's own
-- (Lines.lua: the race's voice, the spacing of repeats), its words
-- Language.lua's, so a diary and the chapters can be read side by side.
local _, ns = ...
local W = ns.writer
local words, listing, mid, article = W.words, W.listing, W.mid, W.article
local deathTags, deathFoe, namedElite, FINAL = W.deathTags, W.deathFoe, W.namedElite, W.FINAL
local HOSTS, TAKEN_IN, newBook, taught, hasNote = W.HOSTS, W.TAKEN_IN, W.newBook, W.taught, W.hasNote
local ELEMENT, CLASS_FIGHT = W.ELEMENT, W.CLASS_FIGHT

-- The race's own land, at home there (its people's, the hosts' who took it
-- in, or a place its scenery says is home).
local function homeOf(race, zone)
  local land = zone and ns.data.scenery and ns.data.scenery[zone]
  if land and land.home and land.home[race] then return true end
  local owner = zone and HOSTS[zone]
  return (owner ~= nil and (owner == race or TAKEN_IN[race] == owner)) or nil
end

-- A people, as the diary says whom the work was for.
local PEOPLE = {
  Human = "the humans",
  Dwarf = "the dwarves",
  NightElf = "the night elves",
  Gnome = "the gnomes",
  Orc = "the orcs",
  Troll = "the Darkspear",
  Tauren = "the tauren",
  Scourge = "the Forsaken",
  Skyborne = "the shen'dorei",
}
local FIRSTS = { demon = true, shift = true, tame = true, mount = true, riding = true, power = true }
local POWERS = { demon = true, shift = true, tame = true, power = true, ["class-reward"] = true } -- (new powers, of those)
local WAY_BACK = 1800 -- (a death and its way back: one sentence)

-- What a chapter holds that a diary tells, from its log.
local function gather(d, c, ch)
  local f = {
    lands = {},
    count = {},
    spells = {},
    firsts = {},
    foes = {},
    deaths = {},
    closes = {},
    mates = {},
    dungeons = {},
    finals = {},
    givers = {},
  }
  local seenFoe, seenMate, seenSpell, seenDungeon, dungeon = {}, {}, {}, {}, nil
  local log = ch.log or {}
  for i, m in ipairs(log) do
    if m.zone then f.count[m.zone] = (f.count[m.zone] or 0) + 1 end
    if m.k == "place" and m.new == "zone" and m.zone and not d.lands[m.zone] then
      d.lands[m.zone] = true
      table.insert(f.lands, m.zone)
    elseif m.k == "learned" then
      -- (a spell's new rank is no new spell: told the first time only)
      for _, sp in ipairs(taught(m.spells, c)) do
        if not seenSpell[sp] and not d.known[sp] then
          seenSpell[sp], d.known[sp] = true, true
          table.insert(f.spells, sp)
        end
      end
    elseif FIRSTS[m.k] or (m.k == "prof" and m.learned) then -- (a trade taken up)
      table.insert(f.firsts, m)
    elseif (m.k == "kill" and m.elite) or m.k == "rare" then
      if m.name and not seenFoe[m.name] then
        seenFoe[m.name] = true
        table.insert(f.foes, (m.k == "rare" or namedElite(m.name)) and m.name or article(m.name))
      end
    elseif m.k == "died" and m.death and not (log[i - 1] and log[i - 1].k == "died" and log[i - 1].at == m.at) then
      -- (one death the game told twice, in older journals, is one)
      -- (its way back, if soon after)
      local back
      for j = i + 1, #log do
        local r = log[j]
        if r.k == "revived" then
          if not (r.at and m.at) or r.at - m.at <= WAY_BACK then back = r end
          break
        end
        if r.k == "died" then break end
      end
      table.insert(f.deaths, { m = m, back = back })
    elseif m.k == "close" then
      table.insert(f.closes, m)
    elseif m.k == "group" and (m.first or m.name) and not seenMate[m.first or m.name] then
      seenMate[m.first or m.name] = true
      table.insert(f.mates, m.first or m.name)
    elseif m.k == "dungeon" and m.name then
      dungeon = m.name
      if not seenDungeon[m.name] then
        seenDungeon[m.name] = true
        table.insert(f.dungeons, m.name)
      end
    elseif m.k == "boss" and m.name and FINAL[m.name] then
      table.insert(f.finals, { boss = m.name, dungeon = dungeon })
    end
    if (m.k == "quest" or m.k == "done") and m.giver then f.givers[m.giver] = true end
    -- a foe with a name of its own a quest sent me after ("Hogger")
    if m.k == "done" and not m.abandoned then
      local bare = ns.names and ns.names.creatureBare or {}
      for _, o in ipairs(m.objectives or {}) do
        if o.type == "monster" and o.name and (bare[o.name] or namedElite(o.name)) and not seenFoe[o.name] then
          seenFoe[o.name] = true
          table.insert(f.foes, o.name)
        end
      end
    end
    -- a class's own quest turned in: what it taught (Knowledge.lua)
    local q = m.k == "quest" and m.id and ns.knowledge and ns.knowledge.quests[m.id]
    if q and q.spell and q.class == c.class then table.insert(f.firsts, { k = "class-reward", m = m, q = q }) end
  end
  -- (the land most of it happened in)
  local main, most = ch.start and ch.start.zone, 0
  for zone, n in pairs(f.count) do
    if n > most or (n == most and zone == main) then
      main, most = zone, n
    end
  end
  f.main = main
  return f
end

-- Whom the work was for: the people most of its givers were (Knowledge.lua),
-- when they were most of them; mine as "my own people".
local function workedFor(givers, race)
  local npcs, count, total = ns.knowledge and ns.knowledge.npcs or {}, {}, 0
  for name in pairs(givers) do
    local who = npcs[name] and npcs[name].people
    if who then count[who] = (count[who] or 0) + 1 end
    total = total + 1
  end
  local best, n = nil, 0
  for who, k in pairs(count) do
    if k > n or (k == n and best and who < best) then
      best, n = who, k
    end
  end
  if not best or n * 2 < total then return nil end
  return best == race and "my own people" or PEOPLE[best]
end

-- The stretch's story: the quests whose work weighed most (writing/why/:
-- what each was for, weighed 1 to 3), the heaviest first, the later of two
-- alike; the first if it was more than an errand, a second if it was a
-- story's climax too.
local function storyOf(ch)
  local whys, seen, all = ns.data.why or {}, {}, {}
  for i, m in ipairs(ch.log or {}) do
    local why = m.id and whys[m.id]
    if why and (m.k == "quest" or m.k == "done") and not m.abandoned and not seen[m.id] then
      seen[m.id] = true
      table.insert(all, { id = m.id, w = why[1], text = why[2], i = i })
    end
  end
  table.sort(all, function(x, y)
    if x.w ~= y.w then return x.w > y.w end
    return x.i > y.i
  end)
  local told = {}
  if all[1] and all[1].w >= 2 then told[1] = all[1] end
  -- (a second only if both read well in one sentence)
  if told[1] and all[2] and all[2].w == 3 and #told[1].text + #all[2].text <= 170 then told[2] = all[2] end
  -- (in the order they happened)
  table.sort(told, function(x, y) return x.i < y.i end)
  return told
end

-- One chapter's entry.
local function entry(d, n, ch)
  local b, c = d.book, d.c
  local race = c.race or "Human"
  local f = gather(d, c, ch)
  local start, e = ch.start or {}, ch.ended
  local level = (e and e.level) or start.level or 1
  local out, events = {}, 0
  local function add(text, event)
    if text and text ~= "" then
      out[#out + 1] = text
      if event then events = events + 1 end
    end
  end
  local function tags(t, zone)
    t = t or {}
    if t.home == nil then t.home = homeOf(race, zone or f.main) end
    t.high, t.low = level >= 40 or nil, level <= 10 or nil
    t.diary = true -- (no line that leans on a moment the diary doesn't tell: "In return, …")
    return t
  end
  local function say(kind, key, values, t, zone, prefer)
    return b:say(kind, n .. "|diary|" .. key, values, tags(t, zone), prefer)
  end
  local mates = {}
  for k = 1, math.min(#f.mates, 3) do
    mates[k] = f.mates[k]
  end

  -- where it began, in the race's voice (a life's first page: its land, too)
  b.last, b.there = nil, false
  local where = start.sub or start.zone
  local first = n == 1 and (c.began and c.began.level or 1) == 1 and (start.level or 1) == 1
  if where then
    add(say(first and "beginning" or "opening", "open", b:here({ where = mid(where) }, where), {
      night = start.night or nil,
    }, start.zone))
    if first then add(b:sceneryOf(start.zone, start.night)) end
    b.last, b.there = where, false
  end
  if start.zone then d.lands[start.zone] = true end

  -- the story of the stretch: what the work that mattered was for
  local story = storyOf(ch)
  local inStory = {}
  for _, q in ipairs(story) do
    inStory[q.id] = true
  end
  if #story == 2 then
    add(say("d-why2", "why", { why = story[1].text, why2 = story[2].text }, {}), true)
  elseif #story == 1 then
    add(say("d-why", "why", { why = story[1].text }, {}), true)
  end

  -- deaths, else the closest call
  if #f.deaths == 1 then
    local death = f.deaths[1]
    local m, r = death.m, death.back
    local at = m.sub or m.zone
    local t = deathTags(m.death or {})
    if r then
      t[r.how or "corpse"] = true
      add(
        say(
          "died-back",
          "died",
          b:here({ foe = deathFoe(m.death or {}), by = r.by, graveyard = r.graveyard and mid(r.graveyard) }, at),
          t,
          m.zone
        ),
        true
      )
    else
      add(say("died", "died", b:here({ foe = deathFoe(m.death or {}) }, at), t, m.zone), true)
    end
  elseif #f.deaths > 1 then
    add(say("d-deaths", "deaths", { times = #f.deaths == 2 and "twice" or words(#f.deaths) .. " times" }, {}), true)
  elseif #f.closes > 0 then
    local worst = f.closes[1]
    for _, m in ipairs(f.closes) do
      if (m.hp or 100) < (worst.hp or 100) then worst = m end
    end
    add(
      say(
        (worst.hp or 100) <= 5 and "close-deep" or "close-light",
        "close",
        b:here({ foe = worst.foe and article(worst.foe) }, worst.sub or worst.zone),
        { night = worst.night or false, foe = worst.foe ~= nil },
        worst.zone
      ),
      true
    )
  end

  -- the foes worth naming (not one the story already named)
  local foes = {}
  for _, foe in ipairs(f.foes) do
    local named = false
    for _, q in ipairs(story) do
      if q.text:find(foe, 1, true) then named = true end
    end
    if not named and #foes < 3 then table.insert(foes, foe) end
  end
  if #foes > 0 then add(say("d-foes", "foes", { foes = listing(foes) }, { one = #foes == 1 or nil }), true) end

  -- a dungeon, and its end; else company
  local below = f.dungeons[1]
  if below then
    add(
      say("d-dungeon", "dungeon", { dungeon = mid(below), mates = listing(mates) }, { one = #mates == 1 or nil }),
      true
    )
    local fin = f.finals[1]
    if fin then add(say("boss-final", "final", { boss = fin.boss, dungeon = mid(fin.dungeon or below) }, {})) end
  elseif #mates > 0 then
    add(say("d-company", "company", { mates = listing(mates) }, { one = #mates == 1 or nil }))
  end

  -- new country
  local lands = {}
  for k, zone in ipairs(f.lands) do
    if k <= 3 then lands[k] = mid(zone) end
  end
  if #lands > 0 then
    -- (home: the first of them a land of my own people's)
    add(say("d-land", "land", { lands = listing(lands) }, { one = #lands == 1 or nil }, f.lands[1]), true)
  end

  -- what I can do now: a power of note (a spell with a line of its own, a
  -- demon, a form, a pet, a class quest's reward, a trade, a mount); the
  -- trainer's list only for a new way of fighting, or a stretch with
  -- nothing else to tell
  local note, newWay = nil, false
  for _, sp in ipairs(f.spells) do
    if not note and hasNote(sp, b) and not b.noted[sp] then note = sp end
    local way = ELEMENT[sp]
    if way and not d.ways[way] then
      d.ways[way], newWay = true, true
    end
  end
  local spells = {}
  for _, sp in ipairs(f.spells) do
    if sp ~= note and #spells < 3 then table.insert(spells, sp) end
  end
  if #spells > 0 and (newWay or (events == 0 and not note and #f.firsts == 0)) then
    add(say("d-powers", "powers", { spells = listing(spells) }, {
      one = #spells == 1 or nil,
      many = #f.spells - (note and 1 or 0) > 3 or nil,
    }))
  end
  if note then
    b.noted[note] = true
    add(say("lesson", "lesson", { spell = note }, { ["spell:" .. note:gsub(" ", "_")] = true }))
  end
  for k, m in ipairs(f.firsts) do
    local key = "first" .. k
    if m.k == "demon" then
      local family = (m.family or ""):lower()
      add(say("demon", key, { pet = m.name, demon = article(family) }, { [family] = true }))
    elseif m.k == "shift" then
      add(say("shift", key, {}, { [m.form or ""] = true }))
    elseif m.k == "power" then
      add(say("power", key, { spell = m.spell }, { [m.kind or "form"] = true }))
    elseif m.k == "class-reward" then
      local family = m.q.spell:match("^Summon (.+)$")
      local t = { summon = family and true or nil }
      if family then t[family:lower()] = true end
      add(say("class-reward", key, {
        giver = m.m.ender or m.m.giver,
        spell = m.q.spell,
        pet = family and article(family:lower()),
      }, t))
    elseif m.k == "prof" or m.k == "tame" then
      local values = m.k == "prof" and { prof = m.name:lower() }
        or { pet = m.name, family = m.family and article(m.family:lower()) }
      local t = m.k == "prof" and { new = true, one = true } or {}
      local clause = b:say("c-" .. m.k, n .. "|diary|" .. key, values, tags(t), nil, true)
      if clause then add("I " .. clause .. ".") end
    else
      add(say(m.k, key, {}, {}))
    end
  end

  -- the rest of the work, in one sentence
  local rest = (ch.quests or 0) - #story
  if rest >= 2 then
    add(say("d-chores", "chores", { n = words(rest), people = workedFor(f.givers, race) }, {
      lots = rest >= 10 or nil,
      also = events > 0 or nil, -- ("the rest", "besides": after something else told)
    }))
  end

  local powerful = false
  for _, m in ipairs(f.firsts) do
    if POWERS[m.k] then powerful = true end
  end
  -- how it ends (not after a Hardcore death: the epitaph has the last word)
  if e and e.how ~= "death" then
    local shape = {
      hard = #f.deaths > 0 or nil,
      near = (#f.deaths == 0 and #f.closes > 0) or nil,
      found = #f.lands > 0 or nil,
      learned = (note ~= nil or powerful) or nil, -- (a power of note, not a trainer's routine, a mount or a trade)
      delve = below ~= nil or nil,
      grouped = #f.mates > 0 or nil,
    }
    -- (quiet: nothing told but the small work, no named foe, no new spell, no story)
    shape.quiet = not (shape.hard or shape.near or shape.found or shape.learned or shape.delve)
        and #f.foes == 0
        and #f.spells == 0
        and #story == 0
      or nil
    -- the thought, when the stretch gave something to think on (a death
    -- before a close call, a dungeon, new country, a new power, company);
    -- else, the rest it ended with, in the race's voice: one ending either way
    local prefer
    for _, k in ipairs({ "hard", "near", "delve", "found", "learned", "grouped" }) do
      if shape[k] then
        prefer = { [k] = true }
        break
      end
    end
    -- (a stretch of nothing but small work: its thought every other time)
    if not prefer and shape.quiet then
      d.quiet = (d.quiet or 0) + 1
      if d.quiet % 2 == 1 then prefer = { quiet = true } end
    end
    if prefer then
      add(say("d-close", "close", { land = f.main and mid(f.main) }, shape, nil, prefer))
    else
      b.last = nil
      if e.how == "long" then
        add(say(e.inside and "night-in" or "night", "last", b:here({}, e.place), { last = true, night = true }, e.zone))
      elseif e.how == "summit" then
        add(say("summit", "last", b:here({ level = words(e.level or 60) }, e.place), { last = true }, e.zone))
      else
        add(say("rest", "last", b:here({ place = mid(e.place) }, e.place), {
          fire = e.how == "campfire" or nil,
          last = true,
        }, e.zone))
      end
    end
  end
  return table.concat(out, " ")
end

-- The diary of a character: { entries = { { number, text, from, to } } }.
function ns.writeDiary(c)
  local d = { c = c, book = newBook(c), lands = {}, known = {}, ways = {} }
  for _, way in ipairs(CLASS_FIGHT[c.class or ""] or {}) do
    d.ways[way] = true
  end
  local diary = { entries = {} }
  for i, ch in ipairs(c.chapters or {}) do
    local start, e = ch.start or {}, ch.ended
    local text = entry(d, i, ch)
    diary.entries[i] = {
      number = i,
      text = text,
      from = start.level,
      to = (e and e.level) or start.level,
      place = e and e.place, -- (where it was written: the entry's heading)
    }
  end
  return diary
end
