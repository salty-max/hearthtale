-- The writer: turns the records into the journal's prose, when it is read
-- (never stored), in scenes (Book:chapter): each moment by its arm (match),
-- told into the chapter's Scene (Scene.lua), its lines chosen by the Book
-- (Lines.lua), its words by Language.lua.
local _, ns = ...
local W = ns.writer
local words, listing, mid, plural = W.words, W.listing, W.mid, W.plural
local itemName, things, article, KINDS, SKIP, TEETH = W.itemName, W.things, W.article, W.KINDS, W.SKIP, W.TEETH
local deathTags, namedElite, deathFoe, playedWords = W.deathTags, W.namedElite, W.deathFoe, W.playedWords
local goldWords, RACE_NAME, HORDE_RACE, CLASS_NAME = W.goldWords, W.RACE_NAME, W.HORDE_RACE, W.CLASS_NAME
local FINAL, foeOf, town, topKills = W.FINAL, W.foeOf, W.town, W.topKills
local linked, rankName, hash = W.linked, W.rankName, W.hash
local Book, newBook, newScene = W.Book, W.newBook, W.newScene
local copy = ns.copy

-- A moment m told by the first arm that fits it, as Rust's match: an arm is
-- { kind, fn, when = guard }, its kind a moment's kind, a set of them
-- (kinds(...)), or "_" for any; the guard, if any, must hold too. Both are
-- called with the chapter's Scene and the moment: fn(s, m).
local function kinds(...)
  local set = {}
  for _, k in ipairs({ ... }) do
    set[k] = true
  end
  return set
end
local function match(m, arms, s)
  -- (the arms a kind can meet, in order, worked out once per kind)
  arms.byKind = arms.byKind or {}
  local plan = arms.byKind[m.k or ""]
  if not plan then
    plan = {}
    for _, arm in ipairs(arms) do
      local k = arm[1]
      if k == "_" or k == m.k or (type(k) == "table" and k[m.k or ""]) then table.insert(plan, arm) end
    end
    arms.byKind[m.k or ""] = plan
  end
  for j = 1, #plan do
    local arm = plan[j]
    if not arm.when or arm.when(s, m) then return arm[2](s, m) end
  end
end

-- A chapter, told in scenes: the moments in one place make one or two
-- sentences of clauses ("In Coldridge Valley I brought Sten his meat, killed
-- six troggs for Balir and carried Talin's word to Grelin."), a link and the
-- place at each new scene ("Later that day, I went on to Kharanos and...").
-- What matters more (a close call, a rare, a new zone, a night, a death, a new
-- power) has a sentence of its own; a new zone or a morning, a new paragraph.
-- The scene being played is the only one still growing: told in order, the
-- finished ones never change. Once closed, a recap (quests, the most fought),
-- the time and gold, and the last line (the rest that closed it, or the night
-- outdoors).
--
-- Each arm below tells a moment m into the chapter's Scene s (Scene.lua),
-- which knows the moment being told (s.i, s.key, s.place) and the book (s.book).
local function nothing() end
local function linkName(x) return x.link and x.link:match("%[(.-)%]") end

-- What each kind of moment tells.
local tell = {}
function tell.level(s, m) s.lvl = m.level or s.lvl end -- a level reached: recorded, not told
function tell.place(s, m)
  local b = s.book
  if m.new == "zone" then
    s:flush()
    s:newParagraph()
    b.last = nil
    -- a land seen for the first time: described, else the plain line
    local land = b:sceneryOf(m.zone, m.night)
    local back = b.landsSeen[m.zone]
    b.landsSeen[m.zone] = true
    if land then
      s:append(land)
    else
      s:alone("zone", { zone = mid(m.zone) }, s:tags({ back = back or nil }, m))
    end
    s:enter(nil, nil)
    -- (the land just named: the next sentence says "there", or nothing)
    b.last, b.there = m.zone, false
    local described = m.sub and b:sceneryOf(m.sub, m.night)
    if described then
      s:append(described)
      s:enter(m.sub, m.zone)
      b.last, b.there = m.sub, false
    elseif m.sub then
      s:arrive(m.sub, m.zone, s.seenHere[m.sub] and "c-return" or "c-place")
    else
      -- the land itself, just named: here, without arriving again
      s:enter(m.zone, m.zone)
    end
  elseif m.sub or m.zone then
    local here = m.sub or m.zone
    local described = b:sceneryOf(here, m.night)
    if described then
      -- a town seen for the first time: described, in its own sentences
      s:flush()
      s:append(#s.current > 0 and linked(b:link(m, s.prev, s.key), described) or described)
      s:enter(here, m.zone)
      b.last, b.there = here, false
    end
    -- (else the arrival is told with the first thing that happens there: a
    -- place only passed through, nothing told there, isn't)
    if not described then s.discovered[here] = { m = m, key = s.key, prev = s.prev } end
  end
end
function tell.inn(s, m) s:tell("c-inn", { inn = mid(m.place) }) end
function tell.flight(s, m)
  local b = s.book
  s:alone("flight", { from = mid(town(m.from)), to = mid(town(m.to)) }, s:tags({ first = not b.flown or nil }, m), m)
  b.flown = true
  if s.place then
    s:enter(s.place, m.zone)
    b.last, b.there = s.place, false
  end
end
-- A class's own quest, turned in: what it taught, a sentence of its own
-- ("In return, Alamar Grimm taught me to call an imp"; Knowledge.lua).
-- False if the quest is no class quest of mine, or teaches nothing.
local function teaches(s, m)
  local q = m.id and ns.knowledge and ns.knowledge.quests[m.id]
  return q and q.spell and q.class == s.c.class and q or nil
end
local function classReward(s, m)
  local q = teaches(s, m)
  if not q then return false end
  s:prepare() -- (in its place: arrived there first)
  local family = q.spell:match("^Summon (.+)$")
  local t = { summon = family and true or nil }
  if family then t[family:lower()] = true end
  local values = { giver = m.ender or m.giver, spell = q.spell, pet = family and article(family:lower()) }
  s:alone("class-reward", values, s:tags(t, m), m)
  return true
end

-- a quest's work done: told where it happened (or at its turn-in, if that
-- comes right after, in the same place)
function tell.done(s, m)
  if m.id then s.doneAt[m.id] = s.i end
  if not s:handedNext(m, s.i) then
    s:deed(s:tags({ done = true }, m)) -- (not the hand-in: "brought back" waits for it)
  end
end
-- its work told already: the turn-in is a return to who asked, the returns
-- in a row as one; right after the work, in the same place, the work and
-- the hand-in in one ("I brought Sten eight …")
function tell.turnIn(s, m)
  local log, i = s.ch.log, s.i
  if s:justDone(m, i) then
    -- (a sentence of its own: the work it tells, not told, may not join the
    -- sentence before, already read as finished)
    s:flush()
    s:deed(s:tags({ handed = true }, m))
    classReward(s, m)
  elseif classReward(s, m) then -- (the reward says I came back)
    return
  elseif m.ender then
    local enders, seenEnder, k = { m.ender }, { [m.ender] = true }, i + 1
    while
      log[k]
      and (
        log[k].k == "level"
        or (
          log[k].k == "quest"
          and log[k].told
          and log[k].ender
          and s:placeOf(log[k]) == s.place
          and not s:justDone(log[k], k)
          and not teaches(s, log[k])
        )
      )
    do
      if log[k].k == "quest" then
        if not seenEnder[log[k].ender] then table.insert(enders, log[k].ender) end
        seenEnder[log[k].ender] = true
        s.merged[k] = true
      end
      k = k + 1
    end
    s:tell("c-report", { ender = listing(enders) })
  end
end
function tell.quest(s, m)
  s:deed(s:tags(nil, m))
  classReward(s, m)
end
-- an errand whose ender sends me straight on with the next: one clause,
-- from the first who asked to the last ("from Sten Stoutarm to Talin Keeneye
-- and on to Grelin Whitebeard")
function tell.chain(s, m)
  local j = s:chainNext(m, s.i)
  local nx = s.ch.log[j]
  s.merged[j] = true
  s:tell("c-chain", { giver = m.giver, via = m.ender, ender = nx.ender })
end
function tell.kill(s, m)
  local b = s.book
  b.creatureKinds[m.name] = m.kind
  if m.quarry or SKIP[m.kind or ""] then return end -- told by its quest, or not a fight
  if m.elite then
    s.toldFoes[m.name] = true
    s.slain[m.name] = true
    -- (elites of one people fought one after another, in one sentence: "a
    -- Mo'grosh Ogre, a Brute and an Enforcer"; a level between them is no break)
    local foes, first, j = { namedElite(m.name) and m.name or article(m.name) }, m.name:match("^(%S+) "), s.i + 1
    while first and s.ch.log[j] do
      local n = s.ch.log[j]
      if n.k == "level" then
        j = j + 1
      elseif
        n.k == "kill"
        and n.elite
        and not s.merged[j]
        and n.name:match("^(%S+) ") == first
        and (n.at or 0) - (m.at or 0) < 1800
      then
        s.merged[j], s.toldFoes[n.name], s.slain[n.name] = true, true, true
        table.insert(foes, article((n.name:gsub("^%S+ ", ""))))
        j = j + 1
      else
        break
      end
    end
    -- (a person is no "it": "another like it" is for a beast)
    return s:tell("c-elite", { foe = listing(foes) }, {
      people = m.kind == "Humanoid" or nil,
      many = #foes > 1 or nil,
    })
  end
  if m.first and KINDS[m.kind] then
    local t = { one = true, teeth = TEETH[m.kind or ""], mechanical = m.kind == "Mechanical" or nil }
    local people = foeOf(m.name, m.kind)
    if people then t[people] = true end
    s:tell("c-first", { kind = KINDS[m.kind] }, t)
  end
  -- (a kill no quest asked for says little alone: told with the work that
  -- follows, if any)
  s:hunted(m)
end
function tell.raid(s, m) s:tell("c-raid", { n = words(m.raid) }) end
-- a stretch at a craft: what was made, in one clause (the most first)
function tell.made(s)
  local log, i = s.ch.log, s.i
  local made, order, j = {}, {}, i
  while
    log[j]
    and (log[j].k == "made" or log[j].k == "skill")
    and (j == i or (log[j].at or 0) - (log[j - 1].at or 0) <= 1800)
  do
    local x = log[j]
    if x.k == "made" then
      local name = linkName(x)
      if name then
        if not made[name] then table.insert(order, name) end
        made[name] = (made[name] or 0) + (x.n or 1)
      end
      s.merged[j] = j ~= i or nil
    end
    j = j + 1
  end
  table.sort(order, function(a, b) return made[a] > made[b] end)
  local list, total = {}, 0
  for k, name in ipairs(order) do
    total = total + made[name]
    if k <= 3 then table.insert(list, made[name] > 1 and words(made[name]) .. " " .. things(name) or itemName(name)) end
  end
  if #order > 3 then table.insert(list, "more besides") end
  s:tell("c-made", { things = listing(list) }, { lots = total >= 10 or nil })
end
-- the other side, met in the open: one by name, race and class when alone;
-- several within a few minutes, together
function tell.pvp(s, m)
  local b, log, i = s.book, s.ch.log, s.i
  local fight, j = { m }, i + 1
  while log[j] do
    if log[j].k == "pvp" then
      if (log[j].at or 0) - (fight[#fight].at or 0) > 600 then break end
      table.insert(fight, log[j])
      s.merged[j] = true
    end
    j = j + 1
  end
  if #fight == 1 and m.name then
    local who = (RACE_NAME[m.race or ""] or "") .. (CLASS_NAME[m.class or ""] and " " .. CLASS_NAME[m.class] or "")
    who = who:gsub("^ ", "")
    s:alone(
      "pvp-one",
      b:here({ name = m.first or m.name, who = who ~= "" and article(who) or nil }, s.place),
      s:tags({ known = who ~= "" or nil }, m),
      m
    )
  else
    local horde = 0
    for _, x in ipairs(fight) do
      if HORDE_RACE[x.race or ""] then horde = horde + 1 end
    end
    s:alone(
      "pvp-many",
      b:here({ n = words(#fight), side = horde * 2 >= #fight and "the Horde" or "the Alliance" }, s.place),
      s:tags(nil, m),
      m
    )
  end
end
-- a group formed: those who joined together, in one clause (by their first
-- name, on Forever: "Harrysaun", not "Harrysaun Brightwood")
function tell.group(s, m)
  local log, i = s.ch.log, s.i
  local names, j = { m.first or m.name }, i + 1
  while log[j] and log[j].k == "group" and (log[j].at or 0) - (m.at or 0) <= 120 do
    table.insert(names, log[j].first or log[j].name)
    s.merged[j] = true
    j = j + 1
  end
  for _, name in ipairs(names) do
    if #s.mates < 4 then table.insert(s.mates, name) end
  end
  s:tell("c-group", { mates = listing(names) }, { one = #names == 1 or nil })
end
-- a dungeon's last master: a sentence of its own
function tell.bossFinal(s, m) s:alone("boss-final", { boss = m.name, dungeon = mid(s.dungeon) }, s:tags(nil, m), m) end
function tell.boss(s, m) s:tell("c-boss", { boss = m.name, dungeon = mid(s.dungeon) }) end
-- (a trade's own spell, learned before the game listed the trade, is told by
-- the trade); a spell with a line of its own (writing/lesson.md: Life Tap,
-- paid in blood) told by it after the lesson, the first of them
local noted
local function hasNote(spell, book)
  if not noted then
    noted = {}
    for _, line in ipairs(ns.data.writing.lesson or {}) do
      for _, t in ipairs(line.tags or {}) do
        local name = t:match("^spell:(.+)$") -- (its spaces "_": [spell:Life_Tap])
        if name then
          name = name:gsub("_", " ")
          noted[name] = noted[name] or {}
          table.insert(noted[name], line)
        end
      end
    end
  end
  -- (a line for this race and class: a Forsaken priest's Smite is not every priest's)
  for _, line in ipairs(noted[spell] or {}) do
    local fits = true
    for _, t in ipairs(line.tags or {}) do
      local neg, k = t:match("^(!?)(%a+:.+)$")
      if k and not k:find("^spell:") then
        local has = book.base[k] == true
        if (neg == "!") == has then fits = false end
      end
    end
    if fits then return true end
  end
  return false
end
function tell.learned(s, m)
  s.book:learn(m.spells)
  local spells, note = {}, nil
  for _, sp in ipairs(m.spells) do
    if
      not (
        (s.c.profs or {})[sp]
        or ns.TRADE_SPELLS[sp]
        or ns.POWER_SPELLS[sp]
        or sp:find("^Apprentice ")
        or sp:find("^Journeyman ")
        or sp:find("^Expert ")
        or sp:find("^Artisan ")
        or sp:find("^Master ")
      )
    then
      if not note and hasNote(sp, s.book) and not s.book.noted[sp] then note = sp end
      table.insert(spells, sp)
    end
  end
  -- (the lesson as a whole, then its spell with a line of its own: that
  -- spell told once, by its line, not in the list as well)
  if note then
    for k = #spells, 1, -1 do
      if spells[k] == note then table.remove(spells, k) end
    end
  end
  if #spells > 0 then
    local named = {}
    for j = 1, math.min(#spells, 3) do
      named[j] = spells[j]
    end
    s:tell("c-trainer", { spells = listing(named) }, { many = #spells > 3 or nil, one = #spells == 1 or nil })
  end
  if note then
    s.book.noted[note] = true
    s:alone(
      "lesson",
      { spell = note },
      s:tags({ ["spell:" .. note:gsub(" ", "_")] = true, also = #spells > 0 or nil }, m),
      m
    )
  end
end
function tell.skill(s, m) s:tell("c-skill", { skill = m.name:lower(), rank = words(m.rank) }, { one = true }) end
function tell.prof(s, m)
  s:tell("c-prof", { prof = m.name:lower(), rank = rankName(m.rank) }, { new = m.learned or nil, one = true })
end
function tell.wearFound(s) -- the find just told, put to use
  s:tell("c-wear-found", {})
  s.found = nil
end
function tell.gearOrLoot(s, m)
  local item = linkName(m)
  if item then
    s:tell(
      "c-" .. m.k,
      { item = itemName(item) },
      { made = m.made or nil, held = m.held or nil, trinket = m.trinket or nil, fine = (m.quality or 2) >= 3 or nil }
    )
  end
  s.found = m.k == "loot" and item or nil
end
function tell.tame(s, m) s:tell("c-tame", { pet = m.name, family = m.family and article(m.family:lower()) }) end

-- The moments of their own, each its own sentence, where it happened.
local own = {}
function own.rare(s, m)
  s.slain[m.name] = true
  s:alone("rare", s.book:here({ foe = m.name }, s.place), s:tags({ elite = m.elite or nil }, m), m)
end
function own.close(s, m)
  local b = s.book
  -- the foe just named: "one of them", not its name again
  local foe, last = article(m.foe), b.lastFoe
  if m.foe and last and last.name == m.foe and (b.told or 0) - last.told <= 1 then
    foe = last.many and "one of them" or (m.foe and "another " .. m.foe)
  end
  s:alone(
    m.hp <= 5 and "close-deep" or "close-light",
    b:here({ foe = foe }, s.place),
    s:tags({ night = m.night or false, foe = m.foe ~= nil }, m),
    m
  )
end
function own.died(s, m) s:alone("died", s.book:here({ foe = deathFoe(m.death) }, s.place), deathTags(m.death), m) end
-- a death and the way back right after it: one sentence
function own.diedBack(s, m)
  local j = s:revivalOf(s.i)
  local r = s.ch.log[j]
  s.merged[j] = true
  local t = deathTags(m.death)
  t[r.how or "corpse"] = true
  s:alone(
    "died-back",
    s.book:here({ foe = deathFoe(m.death), by = r.by, graveyard = r.graveyard and mid(r.graveyard) }, s.place),
    t,
    m
  )
end
function own.dungeon(s, m)
  local b = s.book
  s.dungeon = m.name
  -- a dungeon's first time: described, else the plain line
  local depths = b:sceneryOf(m.name, m.night)
  if depths then
    s:append(#s.current > 0 and linked(b:link(m, s.prev, s.key), depths) or depths)
  else
    s:alone("dungeon", { dungeon = mid(m.name), mates = listing(s.mates) }, s:tags(nil, m), m)
  end
  b.last, b.there = s.place, false
end
-- the firsts of a life: a bag of one's own, a gold piece, a warlock's
-- demon of a new kind, a druid's new shape
function own.bag(s, m)
  local name = m.link and m.link:match("%[(.-)%]")
  local values = { item = name and itemName(name), slots = words(m.slots or 0) }
  s:alone("bag", values, s:tags({ looted = m.looted or nil }, m), m)
end
function own.gold(s, m) s:alone("gold", {}, s:tags(nil, m), m) end
function own.demon(s, m)
  local family = (m.family or ""):lower()
  s:alone("demon", { pet = m.name, demon = article(family) }, s:tags({ [family] = true }, m), m)
end
function own.shift(s, m) s:alone("shift", {}, s:tags({ [m.form or ""] = true }, m), m) end
function own.power(s, m) s:alone("power", { spell = m.spell }, s:tags({ [m.kind or "form"] = true }, m), m) end
function own.ride(s, m) s:alone(m.k, {}, s:tags(nil, m), m) end
-- back from death: how, where, how long it took
function own.revived(s, m)
  s:alone(
    "revived",
    s.book:here(
      { by = m.by, graveyard = m.graveyard and mid(m.graveyard), time = m.took and playedWords(m.took) },
      s.place
    ),
    s:tags({ [m.how or "corpse"] = true }, m),
    m
  )
end
function own.petdied(s, m) s:alone("petdied", s.book:here({ pet = m.name }, s.place), s:tags(nil, m), m) end
function own.campfire(s, m) s:alone("campfire", s.book:here({}, s.place), s:tags(nil, m), m) end
function own.rested(s, m)
  s:alone("rest", s.book:here({ place = mid(m.place) }, m.place), s:tags({ fire = m.fire or nil, last = false }, m), m)
end
-- (indoors without an inn: a corner of a hall, not the open ground)
function own.night(s, m)
  s:alone(m.inside and "night-in" or "night", s.book:here({}, s.place), s:tags({ last = false }, m), m)
end
function own.wake(s, m)
  s:flush()
  s:newParagraph()
  s.book.last = nil
  local indoors = m.inside and m.after ~= "rest"
  s:alone(indoors and "wake-in" or "wake", s.book:here({}, s.place), s:tags({ rest = m.after == "rest" or nil }, m))
end
-- selene: allow(mixed_table) -- (an arm: { kind, fn, when = guard })
local OWN = {
  { "rare", own.rare },
  { "close", own.close },
  -- (one death the game told twice: older journals recorded it twice)
  { "died", nothing, when = function(s, m) return s.prev and s.prev.k == "died" and s.prev.at == m.at end },
  { "died", own.diedBack, when = function(s, m) return m.death and s:revivalOf(s.i) end },
  { "died", nothing, when = function(s) return s:awaitsRevival(s.i) end },
  { "died", own.died, when = function(_, m) return m.death end },
  { "dungeon", own.dungeon },
  { "power", own.power },
  { "bag", own.bag },
  { "gold", own.gold },
  { "demon", own.demon },
  { "shift", own.shift },
  { kinds("mount", "riding"), own.ride },
  { "revived", own.revived },
  { "petdied", own.petdied },
  { "campfire", own.campfire },
  { "rested", own.rested },
  { "night", own.night, when = function(_, m) return not m.last end },
  { "wake", own.wake },
}
function tell.own(s, m)
  s:flush() -- before its place is worked out: "there" depends on the sentence before
  if s.place and s.place ~= s.scene then s:enter(s.place, m.zone) end
  match(m, OWN, s)
end

-- Each moment by the first arm that fits it, in this order.
-- selene: allow(mixed_table) -- (an arm: { kind, fn, when = guard })
local ARMS = {
  { "_", nothing, when = function(s) return s.merged[s.i] end }, -- told with another
  { "_", nothing, when = function(s, m) return m == s.startPlace end }, -- told by the opening
  { "_", nothing, when = function(s) return s.relog[s.i] end }, -- a relog: no night
  { "_", nothing, when = function(s) return s.foldNow end }, -- told in the scene's tally
  { "level", tell.level },
  { "place", tell.place },
  { "inn", tell.inn },
  { "flight", tell.flight },
  { "done", nothing, when = function(_, m) return m.abandoned end }, -- a quest given up: as if never done
  { "done", tell.done },
  { "quest", tell.turnIn, when = function(_, m) return m.told end },
  { "quest", tell.chain, when = function(s, m) return s:chainNext(m, s.i) end },
  { "quest", tell.quest },
  { "kill", tell.kill },
  { "group", tell.raid, when = function(_, m) return m.raid end },
  { "made", tell.made },
  { "pvp", tell.pvp },
  { "group", tell.group },
  { "boss", tell.bossFinal, when = function(_, m) return FINAL[m.name] end },
  { "boss", tell.boss },
  { "learned", tell.learned },
  { "skill", tell.skill },
  { "prof", tell.prof },
  { "gear", tell.wearFound, when = function(s, m) return s.found == linkName(m) end },
  { kinds("gear", "loot"), tell.gearOrLoot },
  { "tame", tell.tame },
  { "_", tell.own },
}

-- Where the chapter began.
local function opening(s)
  local b, start, c = s.book, s.start, s.c
  local where = start.sub or start.zone
  if start.sub then b.placeNames[start.sub] = true end
  if start.zone then
    b.placeNames[start.zone] = true
    b.landsSeen[start.zone] = true
  end
  local first = s.n == 1 and (c.began and c.began.level or 1) == 1 and s.lvl == 1
  if where then
    local line = b:say(
      first and "beginning" or "opening",
      s.n .. "|open",
      b:here({ where = mid(where) }, where),
      s:tags({ night = start.night or nil }, { zone = start.zone })
    )
    if line then s:append(line) end
    -- a life's first page: the land it begins in
    local land = first and b:sceneryOf(start.zone, start.night)
    if land then s:append(land) end
    s:enter(where, start.zone)
  end
end

-- The end of the chapter, e: the recap (tasks, fighting, time) holds one
-- thought, the rest told plainly; the chapter's last sentence (the rest) has
-- its own.
local function ending(s, e)
  local b, ch, n = s.book, s.ch, s.n
  s:newParagraph()
  b.last = nil
  local function say(kind, key, values, t)
    local line = b:say(kind, n .. "|" .. key, values, t)
    if line then s:append(line) end
  end
  local recap = {}
  local top = (function()
    local covered, remaining = {}, {}
    for _, m in ipairs(ch.log or {}) do
      for _, o in ipairs(m.k == "quest" and m.objectives or {}) do
        if o.type == "monster" and o.name then covered[o.name] = true end
      end
      -- (a rare has its own sentence: never "fifteen Squiddics")
      if m.k == "rare" and m.name then covered[m.name] = true end
    end
    for name, count in pairs(ch.kills or {}) do
      if not covered[name] then remaining[name] = count end
    end
    return topKills(remaining)
  end)()
  if (ch.quests or 0) >= 2 then table.insert(recap, "quests") end
  if top[1] and top[1].n >= 3 then table.insert(recap, "kills") end
  table.insert(recap, "closing")
  local thought = recap[hash(b.seed .. "|thought|" .. n) % #recap + 1]
  local function plainUnless(which) s.onlyPlain = thought ~= which end
  if (ch.quests or 0) >= 2 then
    plainUnless("quests")
    local giver
    for i = #ch.log, 1, -1 do
      if ch.log[i].k == "quest" and ch.log[i].giver then
        giver = ch.log[i].giver
        break
      end
    end
    say("quests-many", "recap-q", { n = words(ch.quests), giver = giver }, s:tags())
  end
  -- (Quest objectives already told the significant fighting: the tally
  -- leaves their foes out.)
  local x, y = top[1], top[2]
  plainUnless("kills")
  if x and x.n >= 3 then
    if y and y.n >= 3 then
      say(
        "kills-two",
        "recap-k",
        b:here({ n1 = words(x.n), foes1 = plural(x.name), n2 = words(y.n), foes2 = plural(y.name) }, nil),
        s:tags({ lots = x.n >= 15 or nil })
      )
    else
      say(
        "kills",
        "recap-k",
        b:here({ n = words(x.n), foes = plural(x.name) }, nil),
        s:tags({ lots = x.n >= 15 or nil })
      )
    end
  end
  local played = ch.played or 0
  -- (where the chapter ends: a rest at home is told as one)
  local here = { zone = e.zone or (ch.log[#ch.log] or {}).zone or (s.start or {}).zone }
  plainUnless("closing")
  say(
    "closing",
    "end",
    { time = playedWords(played), gold = goldWords(ch.gold) },
    s:tags(
      { slow = played > 7200 or nil, quick = (played > 0 and played < 1800) or nil, rest = e.how == "rest" or nil },
      here
    )
  )
  s.onlyPlain = false
  if e.how == "long" then
    say(e.inside and "night-in" or "night", "last", b:here({}, e.place), s:tags({ last = true, night = true }, here))
  elseif e.how == "summit" then
    -- the highest level: the journey's end, the journal's last words
    say("summit", "last", b:here({ level = words(e.level or 60) }, e.place), s:tags({ last = true }))
  else
    say(
      "rest",
      "last",
      b:here({ place = mid(e.place) }, e.place),
      s:tags({ fire = e.how == "campfire" or nil, last = true }, here)
    )
  end
end

function Book:chapter(n, ch)
  self.last, self.there = nil, false
  self.chapterNo = self.chapterNo + 1
  local s = newScene(self, n, ch) -- (the book's scene until the chapter is told)
  opening(s)
  for i, m in ipairs(ch.log or {}) do
    s:at(i, m)
    if s.starts[i] then s:nextStretch() end
    if s.errandsFrom == i then s:errands() end
    s:fold() -- (a routine hand-in past the scene's few: told in its tally, s.foldNow)
    match(m, ARMS, s)
    s:situate()
    if m.k ~= "level" then s.prev = m end
  end
  -- (the tally once the chapter ends: in an open one, the place may not be left)
  if ch.ended then s:emitFold() end
  s:flush()
  -- (not while it is still being written; a death on Hardcore ends it with
  -- the epitaph instead)
  local e = ch.ended
  if e and e.how ~= "death" then ending(s, e) end
  self.scene = nil
  return s:text()
end

function Book:prologue(p)
  local zone = p.zone
  return self:say(
    "prologue",
    "prologue",
    self:here({
      zone = mid(zone),
      quests = (p.quests or 0) > 1 and words(p.quests) or nil,
      inn = mid(p.inn),
      played = playedWords(p.played),
    }, zone),
    {}
  )
end

-- The epitaph of a Hardcore life, in the third person: how it ended (a line
-- telling the cause wins), what it was (its totals, a rare, a dungeon), and a
-- farewell (often in the voice of its race or class).
local RACE = {
  Human = "human",
  Dwarf = "dwarf",
  NightElf = "night elf",
  Gnome = "gnome",
  Orc = "orc",
  Troll = "troll",
  Tauren = "tauren",
  Scourge = "Forsaken",
}
function Book:epitaph(c)
  local d = c.death or {}
  local race, class = RACE[c.race] or "", (c.class or ""):lower()
  local who = (race .. " " .. class):gsub("^ +", ""):gsub(" +$", "")
  who = who ~= "" and ((who:match("^[aeiou]") and "an " or "a ") .. who) or nil
  self.last = nil
  local tags = deathTags(d)
  tags.low = (d.level or 0) <= 10 or nil
  tags.high = (d.level or 0) >= 40 or nil
  local place = d.sub or d.zone
  -- the line that tells how it ended wins (a copy: say() gives its tags the
  -- character's, race and class, which are not a cause)
  local cause = deathTags(d)
  cause.low, cause.high = tags.low, tags.high -- a short life or a long one says how it ended too
  local first = self:say(
    "epitaph",
    "epitaph",
    self:here({ name = c.name, who = who, level = words(d.level or 0), zone = mid(d.zone), foe = deathFoe(d) }, place),
    tags,
    cause
  )

  local quests, kills, played, rare, dungeon, zones = 0, 0, 0, nil, nil, 0
  for _, ch in ipairs(c.chapters or {}) do
    quests = quests + (ch.quests or 0)
    played = played + (ch.played or 0)
    for _, n in pairs(ch.kills or {}) do
      kills = kills + n
    end
    for _, m in ipairs(ch.log or {}) do
      if m.k == "rare" then rare = rare or m.name end
      if m.k == "dungeon" then dungeon = dungeon or m.name end
    end
  end
  for key in pairs(c.visited or {}) do
    if key:sub(-1) == "|" then zones = zones + 1 end
  end
  local second = self:say("remembrance", "remembrance", {
    name = c.name,
    played = playedWords(played),
    quests = quests > 1 and words(quests) or nil, -- "one tasks": no
    kills = kills > 1 and words(kills) or nil,
    rare = rare,
    dungeon = mid(dungeon),
    zones = zones > 1 and words(zones) or nil,
  }, { low = tags.low, high = tags.high, inside = tags.inside })
  local third = self:say("farewell", "farewell", { name = c.name }, { low = tags.low })
  if not first then return nil end
  local parts = { first }
  if second then table.insert(parts, second) end
  if third then table.insert(parts, third) end
  return table.concat(parts, " ")
end

-- A chapter's entry in the book: its text and what the list shows of it.
local function entry(b, i, ch)
  local rare, close, to = nil, nil, (ch.start and ch.start.level) or 1
  for _, m in ipairs(ch.log or {}) do
    if m.k == "rare" then rare = true end
    if m.k == "close" then close = true end
    if m.k == "level" then to = m.level end
  end
  local e = ch.ended
  if e and e.level then to = math.max(to, e.level) end
  return {
    number = i,
    text = b:chapter(i, ch),
    chapter = ch,
    open = not e or nil,
    place = e and e.place or (ch.start and (ch.start.sub or ch.start.zone)),
    from = ch.start and ch.start.level or 1,
    to = to,
    rare = rare,
    close = close,
  }
end

-- What the closed chapters were written with, besides their records: who the
-- character is, its prologue, the trades it knows (a trade's own spell is no
-- lesson). Any change, and the book is written again whole.
local function identity(c)
  local p, trades = c.prologue or {}, {}
  for name in pairs(c.profs or {}) do
    trades[#trades + 1] = name
  end
  table.sort(trades)
  return table.concat({
    tostring(c.guid),
    tostring(c.race),
    tostring(c.class),
    tostring(c.faction),
    tostring(c.hardcore),
    tostring(c.began and c.began.level),
    tostring(p.level),
    tostring(p.quests),
    tostring(p.inn),
    tostring(p.zone),
    tostring(p.played),
    table.concat(trades, ","),
  }, "|")
end

-- The writer between two chapters: all it remembers, but what the character
-- is (fixed by newBook).
local FIXED = { c = true, voice = true, own = true, style = true, base = true }
local function snapshot(b)
  local state = {}
  for k, v in pairs(b) do
    if not FIXED[k] then state[k] = copy(v) end
  end
  return state
end

-- How many of the chapters kept can be used as they were written: all of
-- them, if the character is the same and so are their records, else none.
local function reusable(keep, c, closed)
  if not keep.closed or keep.closed > closed or keep.identity ~= identity(c) then return false end
  for i = 1, keep.closed do
    if c.chapters[i] ~= keep.records[i] then return false end
  end
  return true
end

-- The whole book: { prologue = text, chapters = { { number, text, place, from,
-- to (levels), rare, close, open, chapter } }, epitaph, repeats, minGap }
-- (minGap: the fewest uses of a kind between two uses of one of its sentences)
-- keep: a table the caller keeps between two writings of the same character's
-- book (the open journal, at each moment). The closed chapters are written
-- once; then only the open one is, from where the writer stood after them. A
-- closed chapter never changes, so the book reads the same as written whole.
function ns.writeBook(c, keep)
  local chapters = c.chapters or {}
  local closed = 0
  while chapters[closed + 1] and chapters[closed + 1].ended do
    closed = closed + 1
  end
  local b, book, from = newBook(c), { chapters = {} }, 1
  local kept = keep and reusable(keep, c, closed)
  if kept then
    for k, v in pairs(keep.state) do
      b[k] = copy(v)
    end
    book.prologue = keep.prologue
    for i = 1, keep.closed do
      book.chapters[i] = keep.chapters[i]
    end
    from = keep.closed + 1
  elseif c.prologue then
    book.prologue = b:prologue(c.prologue)
  end
  -- the book up to its last closed chapter, and the writer as it stood then
  local function remember()
    keep.identity, keep.closed, keep.prologue, keep.state = identity(c), closed, book.prologue, snapshot(b)
    keep.records, keep.chapters = {}, {}
    for i = 1, closed do
      keep.records[i], keep.chapters[i] = chapters[i], book.chapters[i]
    end
  end
  if keep and not kept and closed == 0 then remember() end
  for i = from, #chapters do
    book.chapters[i] = entry(b, i, chapters[i])
    if keep and i == closed then remember() end
  end
  if c.hardcore and c.death then book.epitaph = b:epitaph(c) end
  book.repeats, book.minGap, book.minGapKind = b.repeats, b.minGap, b.minGapKind
  return book
end
