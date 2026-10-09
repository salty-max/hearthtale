-- The diary (a prototype beside the chapters of Writer.lua): each chapter as
-- the character would write it at the rest that ends it, the stretch looked
-- back on rather than told moment by moment. From the same record: its
-- story (what the work that mattered was for: writing/why/), dangers, the
-- foes worth naming, a dungeon or company, new country, a new way of
-- fighting and the firsts of a life, the rest of the work in a sentence,
-- and one ending: a thought when the stretch gave one, else the rest. Its
-- sentences are the book's own (Lines.lua: the race's voice, the spacing
-- of repeats), its words Language.lua's.
local _, ns = ...
local W = ns.writer
local words, listing, mid, article, plural = W.words, W.listing, W.mid, W.article, W.plural
local deathTags, deathFoe, FINAL = W.deathTags, W.deathFoe, W.FINAL
local HOSTS, TAKEN_IN, newBook, taught, hasNote = W.HOSTS, W.TAKEN_IN, W.newBook, W.taught, W.hasNote
local ELEMENT, CLASS_FIGHT, at, lowerFirst = W.ELEMENT, W.CLASS_FIGHT, W.at, W.lowerFirst

-- The race's own land: its people's (HOSTS), or a place its scenery says
-- is home; "hosts": the land of those who took a race in (TAKEN_IN).
local function homeOf(race, zone)
  local land = zone and ns.data.scenery and ns.data.scenery[zone]
  if land and land.home and land.home[race] then return "home" end
  local owner = zone and HOSTS[zone]
  if owner == nil then return nil end
  if owner == race then return "home" end
  if TAKEN_IN[race] == owner then return "hosts" end
  return nil
end

-- A people, as the diary says whom the work was for; mine, "my own people".
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
-- (in a quest's why, my own people are mine: "for the Forsaken", written by one)
local OURS = {
  Human = { { "the humans", "my people" } },
  Dwarf = { { "the dwarves", "my people" } },
  NightElf = { { "the night elves", "my people" }, { "the kaldorei", "my people" } },
  Gnome = { { "the gnomes", "my people" } },
  Orc = { { "the orcs", "my people" } },
  Troll = {
    { "the Darkspear tribe", "my tribe" },
    { "the Darkspear trolls", "my people" },
    { "the Darkspear", "my people" },
  },
  Tauren = { { "the tauren", "my people" }, { "the shu'halo", "my people" } },
  Scourge = { { "the Forsaken", "my people" } },
}
-- A people's own city: never new country to them.
local CAPITAL = {
  Human = "Stormwind City",
  Dwarf = "Ironforge",
  Gnome = "Ironforge",
  NightElf = "Darnassus",
  Orc = "Orgrimmar",
  Troll = "Orgrimmar",
  Tauren = "Thunder Bluff",
  Scourge = "Undercity",
}
-- A class's first spells, known from the first day: a new rank is no news.
local FIRST_SPELLS = {
  WARRIOR = { "Battle Stance", "Heroic Strike" },
  PALADIN = { "Seal of Righteousness", "Holy Light" },
  HUNTER = { "Raptor Strike", "Auto Shot" },
  ROGUE = { "Sinister Strike", "Eviscerate", "Stealth" },
  PRIEST = { "Smite", "Lesser Heal" },
  SHAMAN = { "Lightning Bolt", "Healing Wave" },
  MAGE = { "Fireball", "Frost Armor" },
  WARLOCK = { "Shadow Bolt", "Demon Skin" },
  DRUID = { "Wrath", "Healing Touch" },
}
local FIRSTS = { demon = true, shift = true, tame = true, mount = true, riding = true, power = true }
local POWERS = { demon = true, shift = true, tame = true, power = true, ["class-reward"] = true } -- (new powers, of those)
local TRAVEL_FORMS = { travel = true, aquatic = true, flight = true } -- (no new way of fighting)
local WAY_BACK = 1800 -- (a death and its way back: one sentence)
local CHORES = 4 -- (the rest of the work told only if it was this much at least)
local ZALAZANE = 826 -- (the quest that ends him: a Darkspear's hope fulfilled)
local DEMONS = { Imp = true, Voidwalker = true, Succubus = true, Felhunter = true, Felguard = true, Infernal = true }
local PET_GAP = 4 -- (a pet named again: not in the entries just after)

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
    work = {}, -- [quest id] = { giver, objectives, zone }
    pets = {}, -- [name] = the work done with it at my side
    demons = {}, -- [name] = true: a demon of mine
    done = 0,
  }
  local seenMate, seenSpell, seenDungeon, dungeon = {}, {}, {}, nil
  local bare = ns.names and ns.names.creatureBare or {}
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
    elseif m.k == "rare" and m.name then
      table.insert(f.foes, { name = m.name, rank = 1 })
    elseif m.k == "kill" and m.elite and m.name then
      -- (an elite of a kind: several of them, their plural)
      local n = (ch.kills or {})[m.name] or 1
      table.insert(f.foes, { name = m.name, rank = 3, shown = n > 1 and plural(m.name) or article(m.name) })
    elseif m.k == "died" and m.death and not (log[i - 1] and log[i - 1].k == "died" and log[i - 1].at == m.at) then
      -- (one death the game told twice, in older journals, is one; its
      -- way back, if soon after)
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
    if m.k == "quest" and m.id == ZALAZANE then d.zalazane = true end
    if m.k == "done" then
      f.done = f.done + 1
      if m.pet then
        f.pets[m.pet] = (f.pets[m.pet] or 0) + 1
        if DEMONS[m.petFamily or ""] then f.demons[m.pet] = true end
      end
    end
    -- the work: whom it was for, what it asked, where
    if (m.k == "quest" or m.k == "done") and m.id and not m.abandoned then
      local w = f.work[m.id] or {}
      w.giver = w.giver or m.giver
      w.objectives = w.objectives or m.objectives
      w.zone = w.zone or m.zone
      f.work[m.id] = w
      -- a foe with a name of its own a quest sent me after, alone ("Hogger")
      for _, o in ipairs(m.objectives or {}) do
        if o.type == "monster" and o.name and bare[o.name] and (o.n or 1) == 1 and m.k == "done" then
          table.insert(f.foes, { name = o.name, rank = 2 })
        end
      end
    end
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

-- Whom the rest of the work was for: the people of most of its tasks
-- (Knowledge.lua; a task whose giver is unknown counts for no one), when
-- they were more than half of them; mine as "my own people", unless at home.
local function workedFor(f, skip, race, home)
  local npcs, count, total = ns.knowledge and ns.knowledge.npcs or {}, {}, 0
  for id, w in pairs(f.work) do
    if not skip[id] then
      total = total + 1
      local who = w.giver and npcs[w.giver] and npcs[w.giver].people
      if not who and w.zone == "Zephras Isle" then who = "Skyborne" end -- (Forever's islanders)
      if who then count[who] = (count[who] or 0) + 1 end
    end
  end
  for who, k in pairs(count) do
    if k * 2 > total then
      if who == race then return not home and "my own people" or nil end
      return PEOPLE[who]
    end
  end
  return nil
end

-- The stretch's story: the quests whose work weighed most (writing/why/:
-- what each was for, weighed 1 to 3), the heaviest first, of two alike the
-- one whose work was done here (a deed over a delivery), then the later;
-- the first if it was more than an errand, a second if a climax too and
-- both read well in one sentence.
local function storyOf(d, ch, f)
  local whys, seen, all = ns.data.why or {}, {}, {}
  for i, m in ipairs(ch.log or {}) do
    local why = m.id and whys[m.id]
    if why and (m.k == "quest" or m.k == "done") and not m.abandoned and not seen[m.id] and not d.storied[m.id] then
      seen[m.id] = true
      local w = f.work[m.id] or {}
      local deed = false
      for _, o in ipairs(w.objectives or {}) do
        if o.type == "monster" or o.type == "item" then deed = true end
      end
      table.insert(all, { id = m.id, w = why[1], text = why[2], i = i, deed = deed, zone = w.zone or m.zone })
    end
  end
  table.sort(all, function(x, y)
    if x.w ~= y.w then return x.w > y.w end
    if x.deed ~= y.deed then return x.deed end
    return x.i > y.i
  end)
  local told = {}
  if all[1] and all[1].w >= 2 then told[1] = all[1] end
  if told[1] and all[2] and all[2].w == 3 and #told[1].text + #all[2].text <= 210 then told[2] = all[2] end
  table.sort(told, function(x, y) return x.i < y.i end) -- (in the order they happened)
  return told
end

-- A quest's why, as one of the people it names writes it: "for the
-- Forsaken" is "for my people" in a Forsaken's diary.
local function ours(text, race)
  for _, pair in ipairs(OURS[race] or {}) do
    text = text:gsub(pair[1]:gsub("%p", "%%%0"), pair[2])
  end
  return text
end

-- One chapter's entry.
local function entry(d, n, ch)
  local b, c = d.book, d.c
  local race = c.race or "Human"
  local start, e = ch.start or {}, ch.ended
  if start.zone then d.lands[start.zone] = true end -- (where it began is no new country)
  local f = gather(d, c, ch)
  local level = (e and e.level) or start.level or 1
  local out, events, owned = {}, 0, 0
  local function add(text, event)
    if text and text ~= "" then
      out[#out + 1] = text
      if event then events = events + 1 end
    end
  end
  local function tags(t, zone)
    t = t or {}
    if t.home == nil then t.home = homeOf(race, zone or f.main) == "home" or nil end
    t.high, t.low = level >= 40 or nil, level <= 10 or nil
    t.diary = true -- (no line that leans on a moment the diary doesn't tell: "In return, …")
    t.zalazane = d.zalazane -- (Zalazane dead: no line hoping for it)
    return t
  end
  -- (a line: the text alone; the race's own counted, two at most in an entry)
  local function say(kind, key, values, t, zone, prefer)
    t = tags(t, zone)
    if owned >= 2 then t._shared = true end
    local text, said = b:say(kind, n .. "|diary|" .. key, values, t, prefer)
    if said and said.own then owned = owned + 1 end
    return text
  end
  local mates = {}
  for k = 1, math.min(#f.mates, 3) do
    mates[k] = f.mates[k]
  end
  local story = storyOf(d, ch, f)
  local inStory = {}
  for _, q in ipairs(story) do
    inStory[q.id] = true
  end

  -- where it began, in the race's voice (a life's first page: its land,
  -- too); every other entry that goes on where the last one rested, its
  -- story leads instead, named by its place
  b.last, b.there = nil, false
  local where = start.sub or start.zone
  local first = n == 1 and (c.began and c.began.level or 1) == 1 and (start.level or 1) == 1
  local lead
  local wentOn = d.lastPlace and (where == d.lastPlace or start.zone == d.lastZone)
  local storyZone = story[1] and (story[1].zone or start.zone)
  local newLand = false
  for _, zone in ipairs(f.lands) do
    if zone == storyZone then newLand = true end
  end
  -- (not a land the entry then tells as new: its first sight comes first)
  if wentOn and #story > 0 and n % 2 == 0 and not newLand then
    lead = at(storyZone)
  elseif where then
    add(say(first and "beginning" or "opening", "open", b:here({ where = mid(where) }, where), {
      night = start.night or nil,
    }, start.zone))
    if first then add(b:sceneryOf(start.zone, start.night)) end
    b.last, b.there = where, false
  end

  -- the story of the stretch: what the work that mattered was for; a
  -- chain's quest when an earlier entry told one of it, the business taken
  -- up again (Knowledge.lua: chains), or finished
  local chains, ends = ns.knowledge and ns.knowledge.chains or {}, ns.knowledge and ns.knowledge.ends or {}
  if #story > 0 then
    local text
    if #story == 2 then
      text = say("d-why2", "why", { why = ours(story[1].text, race), why2 = ours(story[2].text, race) }, {})
    else
      local q = story[1]
      local root = chains[q.id]
      local thread = root and d.threads[root] and d.threads[root] < n
      local t = thread and { thread = true, settled = ends[q.id] or nil } or {}
      text = say("d-why", "why", { why = ours(story[1].text, race) }, t, nil, thread and { thread = true } or nil)
    end
    if text and lead then
      -- ("I" stays a capital after the place: "In Loch Modan, I will not soon forget …")
      local rest = text:find("^I[ ']") and text or lowerFirst(text)
      text = lead:gsub("^%l", string.upper) .. ", " .. rest
    end
    add(text, true)
  end

  for _, q in ipairs(story) do
    d.storied[q.id] = true -- (its work done here, its return in the next: told once)
    local root = chains[q.id]
    if root and not d.threads[root] then d.threads[root] = n end
  end

  -- deaths, else the closest call (a foe that killed me is told there; one
  -- that nearly did, a hard fight when the foes are named)
  local dangerFoes, deathFoes = {}, {}
  for _, m in ipairs(f.closes) do
    if m.foe then dangerFoes[m.foe] = true end
  end
  if #f.deaths == 1 then
    local death = f.deaths[1]
    local m, r = death.m, death.back
    local place = m.sub or m.zone
    local t = deathTags(m.death or {})
    if m.death and m.death.foe then deathFoes[m.death.foe] = true end
    if r then
      t[r.how or "corpse"] = true
      add(
        say(
          "died-back",
          "died",
          b:here({ foe = deathFoe(m.death or {}), by = r.by, graveyard = r.graveyard and mid(r.graveyard) }, place),
          t,
          m.zone
        ),
        true
      )
    else
      add(say("died", "died", b:here({ foe = deathFoe(m.death or {}) }, place), t, m.zone), true)
    end
  elseif #f.deaths > 1 then
    for _, death in ipairs(f.deaths) do -- (unnamed there: told plainly with the foes, if beaten after)
      if death.m.death and death.m.death.foe then dangerFoes[death.m.death.foe] = nil end
    end
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

  -- the foes worth naming: a rare, a named foe a quest sent me after, then
  -- elites; never one the story's work was about, one that killed me, nor
  -- one named before in the diary; a hard fight only one the record says
  -- nearly killed me
  local storyFoes = {}
  for _, q in ipairs(story) do
    for _, o in ipairs((f.work[q.id] or {}).objectives or {}) do
      if o.name then storyFoes[o.name] = true end
    end
  end
  table.sort(f.foes, function(x, y) return x.rank < y.rank end)
  local foes, hard, seen = {}, false, {}
  for _, foe in ipairs(f.foes) do
    local inText = false
    for _, q in ipairs(story) do
      if q.text:find(foe.name, 1, true) then inText = true end
    end
    local skip = inText or storyFoes[foe.name] or deathFoes[foe.name] or d.toldFoes[foe.name] or seen[foe.name]
    if not skip and #foes < 3 then
      seen[foe.name], d.toldFoes[foe.name] = true, true
      table.insert(foes, foe.shown or foe.name)
      if dangerFoes[foe.name] then hard = true end
    end
  end
  if #foes > 0 then
    add(
      say("d-foes", "foes", { foes = listing(foes) }, {
        one = #foes == 1 or nil,
        two = #foes == 2 or nil,
        hard = hard or nil,
      }),
      true
    )
  end

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
    local again = true
    for _, mate in ipairs(mates) do
      if not d.mates[mate] then again = false end
      d.mates[mate] = true
    end
    add(say("d-company", "company", { mates = listing(mates) }, { one = #mates == 1 or nil, again = again or nil }))
  end

  -- new country: lands strange to my people, else theirs, else our hosts'
  local strange, homes, hosted = {}, {}, {}
  for _, zone in ipairs(f.lands) do
    local kind = homeOf(race, zone)
    table.insert(kind == "home" and homes or kind == "hosts" and hosted or strange, zone)
  end
  local lands, landTag = strange, nil
  if #strange == 0 then
    lands = #homes > 0 and homes or hosted
    landTag = #homes > 0 and "home" or (#hosted > 0 and "hosts" or nil)
  end
  local named = {}
  for k = 1, math.min(#lands, 3) do
    named[k] = mid(lands[k])
  end
  if #named > 0 then
    add(
      say("d-land", "land", { lands = listing(named) }, {
        one = #named == 1 or nil,
        home = landTag == "home" or false,
        hosts = landTag == "hosts" or nil,
      }),
      true
    )
  end

  -- what I can do now: a power of note (a spell with a line of its own,
  -- one an entry, the others in the entries after; a demon, a form, a pet,
  -- a class quest's reward, a trade, a mount); a trainer's list only for a
  -- new way of fighting; two power sentences at most
  local fighting, newWay = {}, false
  for _, sp in ipairs(f.spells) do
    if hasNote(sp, b) and not b.noted[sp] then
      table.insert(d.notes, sp)
    else
      local way = ELEMENT[sp]
      if way and not d.ways[way] then
        d.ways[way], newWay = true, true
        table.insert(fighting, sp)
      end
    end
  end
  local powers = 0
  local note = table.remove(d.notes, 1)
  if note then
    b.noted[note] = true
    add(say("lesson", "lesson", { spell = note }, { ["spell:" .. note:gsub(" ", "_")] = true }))
    powers = powers + 1
  end
  for k, m in ipairs(f.firsts) do
    if powers >= 2 then break end
    local key = "first" .. k
    local text
    if m.k == "demon" then
      local family = (m.family or ""):lower()
      text = say("demon", key, { pet = m.name, demon = article(family) }, { [family] = true }, nil, { [family] = true })
    elseif m.k == "shift" then
      text = say("shift", key, {}, { [m.form or ""] = true }, nil, { [m.form or ""] = true })
    elseif m.k == "power" then
      text = say("power", key, { spell = m.spell }, { [m.kind or "form"] = true })
    elseif m.k == "class-reward" then
      local family = m.q.spell:match("^Summon (.+)$")
      local t = { summon = family and true or nil }
      if family then t[family:lower()] = true end
      text = say("class-reward", key, {
        giver = m.m.ender or m.m.giver,
        spell = m.q.spell,
        pet = family and article(family:lower()),
      }, t)
    elseif m.k == "prof" or m.k == "tame" then
      local values = m.k == "prof" and { prof = m.name:lower() }
        or { pet = m.name, family = m.family and article(m.family:lower()) }
      local t = tags(m.k == "prof" and { new = true, one = true } or {})
      local clause = b:say("c-" .. m.k, n .. "|diary|" .. key, values, t, nil, true)
      text = clause and ("I " .. clause .. ".")
    else
      text = say(m.k, key, {}, {})
    end
    if text then
      add(text)
      powers = powers + 1
    end
  end
  if newWay and powers < 2 then
    local spells = {}
    for k = 1, math.min(#fighting, 3) do
      spells[k] = fighting[k]
    end
    add(say("d-powers", "powers", { spells = listing(spells) }, { one = #spells == 1 or nil }))
  end

  -- the pet at my side through most of the work, named again (one an
  -- earlier entry met), not in the entries just after
  local pet, most = nil, 0
  for name, k in pairs(f.pets) do
    if k > most or (k == most and pet and name < pet) then
      pet, most = name, k
    end
  end
  for _, m in ipairs(f.firsts) do
    if (m.k == "tame" or m.k == "demon") and m.name == pet then pet = nil end -- (its first: told)
  end
  local known = pet and d.pets[pet]
  if known and most >= 3 and most * 2 >= f.done and n - (known.said or 0) >= PET_GAP and events < 4 then
    -- ("as ever" once it has been named so)
    add(say("d-pet", "pet", { pet = pet }, { demon = f.demons[pet] or nil, again = known.said and true or nil }))
    known.said = n
  end
  for name in pairs(f.pets) do
    d.pets[name] = d.pets[name] or {}
  end

  -- the rest of the work, in one sentence, when there was enough of it and
  -- the entry isn't full already ("the rest", "besides": after something)
  local rest = (ch.quests or 0) - #story
  if rest >= CHORES and events < 3 then
    add(say("d-chores", "chores", {
      n = words(rest),
      people = workedFor(f, inStory, race, homeOf(race, f.main) == "home"),
    }, {
      lots = rest >= 10 or nil,
      also = events > 0 or nil,
      much = events > 1 or nil,
    }))
  end

  local powerful = newWay
  for _, m in ipairs(f.firsts) do
    if POWERS[m.k] and not (m.k == "shift" and TRAVEL_FORMS[m.form or ""]) then powerful = true end
  end
  -- how it ends (not after a Hardcore death: the epitaph has the last word)
  if e and e.how ~= "death" then
    local shape = {
      hard = #f.deaths > 0 or nil,
      near = (#f.deaths == 0 and #f.closes > 0) or nil,
      found = #strange > 0 or nil, -- (a land of my own people's is no new country)
      learned = powerful or nil, -- (a new way of fighting or a power, not a lesson's utility)
      delve = below ~= nil or nil,
      grouped = #f.mates > 0 or nil,
      fought = #foes > 0 or nil,
    }
    shape.quiet = not (shape.hard or shape.near or shape.found or shape.learned or shape.delve or shape.fought)
        and #story == 0
      or nil
    -- the thought, when the stretch gave something to think on (a death
    -- before a close call, a dungeon, new country, a new power, company);
    -- else, the rest it ended with, in the race's voice
    local prefer
    for _, k in ipairs({ "hard", "near", "delve", "found", "learned", "grouped", "fought" }) do
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
    owned = math.min(owned, 1) -- (the ending may always be the race's own)
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
  d.lastPlace, d.lastZone = e and e.place, e and e.zone
  return table.concat(out, " ")
end

-- The diary of a character: { entries = { { number, text, from, to, place, open } } }.
function ns.writeDiary(c)
  local d = {
    c = c,
    book = newBook(c),
    lands = {},
    known = {},
    ways = {},
    notes = {},
    toldFoes = {},
    mates = {},
    storied = {}, -- [quest id]: its story told
    threads = {}, -- [a chain's first quest] = the entry that told one of it
    pets = {}, -- [name] = { said = the last entry that named it }: a pet met before
  }
  for _, way in ipairs(CLASS_FIGHT[c.class or ""] or {}) do
    d.ways[way] = true
  end
  for _, sp in ipairs(FIRST_SPELLS[c.class or ""] or {}) do
    d.known[sp] = true
  end
  local capital = CAPITAL[c.race or ""]
  if capital then d.lands[capital] = true end
  local diary = { entries = {} }
  for i, ch in ipairs(c.chapters or {}) do
    local start, e = ch.start or {}, ch.ended
    local text = entry(d, i, ch)
    diary.entries[i] = {
      number = i,
      text = text,
      from = start.level,
      to = (e and e.level) or start.level,
      place = (e and e.place) or start.sub or start.zone, -- (where it was written, or where it goes on)
      open = not e or nil,
    }
  end
  return diary
end
