-- A chapter being told (Writer.lua tells each moment into it): its
-- paragraphs and sentences, the clauses of the sentence being written and how
-- they join, the scene it is in (a place, its zone), the moment being told,
-- and what the telling remembers of the moments so far (those told with
-- another, the find just told, the routine hand-ins folded into a tally...).
-- While it is told, it is the book's scene (book.scene): Book:say reads and
-- keeps there what a paragraph or a chapter remembers (who was named, the
-- quips and voice lines used, the remark budget).
local _, ns = ...
local W = ns.writer
local words, listing, mid, objectiveOf, capitalise = W.words, W.listing, W.mid, W.objectiveOf, W.capitalise
local instruction, linked, hash, plural, article = W.instruction, W.linked, W.hash, W.plural, W.article
local HOSTS, TAKEN_IN, TITLES = W.HOSTS, W.TAKEN_IN, W.TITLES

local Scene = {}
Scene.__index = Scene

-- Related work keeps together in a sentence: learning two trades is one
-- thought, a trade followed by a fight a new one.
local FAMILIES = {
  quest = "work",
  kill = "work",
  boss = "work",
  loot = "work",
  gear = "work",
  learned = "practice",
  skill = "practice",
  prof = "practice",
  made = "practice",
}

-- Curation: in a scene, the first LOW_TOLD routine hand-ins (a delivery, a
-- report back, a message carried, a favour known only by who asked, green
-- gear) are told; the rest fold into one clause, told once the place is left
-- or the chapter ends ("I saw to four more errands besides"). The deeds
-- themselves, the firsts, the dangers, the finds are always told.
local LOW_TOLD = 2

-- Chapter n of the book, ch its record.
local function newScene(book, n, ch)
  local s = setmetatable({
    book = book,
    n = n,
    ch = ch,
    c = book.c,
    paragraphs = {},
    current = {},
    -- the scene: its place (and zone), the places of the chapter so far, the
    -- creatures killed there no quest asked for (told with the work that
    -- follows), a quiet return to tell with the next sentence ("Back in …")
    scene = nil,
    sceneZone = nil,
    seenHere = {},
    discovered = {}, -- places seen for the first time, their arrival not told yet: place = { m, key, prev }
    prey = {},
    preyPlace = nil,
    toldFoes = {}, -- creatures told already (by a quest or as an elite): not again as prey or work
    slain = {}, -- named foes told slain in this paragraph (an elite, a rare): their trophy is "the head"
    trophied = {}, -- owners of a trophy told ("Zalazane" of Zalazane's Head): not told again as prey
    backTo = nil,
    backTold = false, -- (in this paragraph)
    backAt = {}, -- (the paragraph each place's return was last named in)
    -- the sentence being written: its clauses (their kinds, each without its
    -- remark), the link it takes, whether it names its place, an arrival
    -- framing it; its clauses that may carry a remark, those that do, a
    -- highlight, a turned clause
    pending = {},
    pendingKinds = {},
    pendingBare = {}, -- (each clause without its remark)
    lead = nil,
    sentenceKey = nil, -- (the key of its first clause)
    named = false,
    arrival = false,
    arrivalMode = nil,
    sentenceLimit = nil,
    pendingRoutine = 0,
    pendingRemarks = 0,
    pendingHighlight = false,
    pendingTurn = false,
    -- the paragraph: who it named, the things carried in it (when), a quip told
    peopleNamed = {},
    namedAt = {}, -- (when each was named: the book's sentence count)
    thingsCarried = {},
    quipped = false,
    -- the chapter's voice: race and class lines in some chapters only (two
    -- at most); a remark every two or three routine clauses, not after a
    -- sentence that had one
    voiceChapter = hash(book.seed .. "|voice|" .. n) % 3 == 0,
    voiceUsed = 0,
    routineCount = 0,
    nextRemark = 2 + hash(book.seed .. "|remarks|" .. n) % 2,
    lastSentenceRemark = false,
    onlyPlain = false, -- (the recap: plain lines only, but for its one thought)
    -- the moment being told (i its place in the log, key its seed, place
    -- where it happened), and the one before
    m = nil,
    i = nil,
    key = nil,
    place = nil,
    prev = nil,
    foldNow = false,
    -- the fold: hand-ins told in the scene it counts for, its tally
    lowTold = 0,
    lowScene = nil,
    folded = { errands = 0, gear = 0 },
    -- who joined so far; the dungeon I'm in; moments told with the one
    -- before; the find just told; where each quest's work was told in the log
    mates = {},
    dungeon = nil,
    merged = {},
    found = nil,
    doneAt = {},
    -- a night (or a rest) and its waking less than half an hour apart: a
    -- relog, not a break (the recorder no longer keeps them; older journals have them)
    relog = {},
    -- the stretches: the moments that begin a paragraph, and where a run of
    -- errands begins (Scene:segment)
    starts = {},
    errandsFrom = nil,
    peopleSaid = {}, -- the people the moment being told named (Scene:situate)
  }, Scene)
  local start = ch.start or {}
  -- a start whose place the game had not told yet (Forever, at login): the
  -- first place, moments later, is where the chapter began, not an arrival
  local first = ch.log and ch.log[1]
  if not start.zone and first and first.k == "place" and first.zone and (first.at or 0) - (start.at or 0) <= 60 then
    start = setmetatable({ zone = first.zone, sub = first.sub }, { __index = start })
    s.startPlace = first
  end
  s.start, s.lvl = start, start.level or 1
  for j, m in ipairs(ch.log or {}) do
    local w = ch.log[j + 1]
    if
      (m.k == "night" or m.k == "rested")
      and not m.last
      and w
      and w.k == "wake"
      and (w.at or 0) - (m.at or 0) < 1800
    then
      s.relog[j], s.relog[j + 1] = true, true
    end
  end
  s:segment()
  book.scene = s
  return s
end

-- A remark is due: the sentence being written is closed first if it has one
-- already, or the sentence before had one (an arrival alone frames what
-- follows: kept whole, the remark waits).
function Scene:prepareRemark()
  if
    self.pendingRemarks > 0
    or (self.lastSentenceRemark and #self.pending > 0 and not (self.arrival and #self.pending == 1))
  then
    self:flush()
  end
end

-- ── the text ─────────────────────────────────────────────────────────────────
-- A sentence into the chapter.
function Scene:append(text, routine, remarks, highlight)
  local b = self.book
  table.insert(self.current, text)
  b.told = (b.told or 0) + 1
  self.lastSentenceRemark = (remarks or 0) > 0
  self.lastHighlightRemark = self.lastSentenceRemark and highlight and true or false
  if ns.writerSentence then ns.writerSentence(text, routine or 0, remarks or 0, self.n, highlight) end
end

function Scene:newParagraph()
  if #self.current > 0 then
    self.current.named = self.peopleNamed -- (who it named: see Scene:text)
    table.insert(self.paragraphs, self.current)
    self.current = {}
  end
  self.quipped, self.backTold = false, false
  self.peopleNamed, self.namedAt, self.slain = {}, {}, {} -- (the things carried: remembered for the chapter)
  self.peopleSaid = {} -- (a person named in the paragraph before is no meeting here)
end

-- The chapter's text: a paragraph of one sentence joins the one before it
-- (the first, the one after), unless both name the same person: each was
-- told as a paragraph of its own, a name said again in full.
local function joins(a, b)
  for name in pairs(a.named or {}) do
    if (b.named or {})[name] then return false end
  end
  return true
end
local function joinTo(into, p, first)
  if first then
    table.insert(into, 1, p[1])
  else
    table.insert(into, p[1])
  end
  local named = {}
  for name in pairs(into.named or {}) do
    named[name] = true
  end
  for name in pairs(p.named or {}) do
    named[name] = true
  end
  into.named = named
end
function Scene:text()
  self:newParagraph()
  if #self.paragraphs == 0 then return nil end
  local merged = {}
  for _, p in ipairs(self.paragraphs) do
    if #p == 1 and #merged > 0 and joins(p, merged[#merged]) then
      joinTo(merged[#merged], p)
    else
      table.insert(merged, p)
    end
  end
  if #merged > 1 and #merged[1] == 1 and joins(merged[1], merged[2]) then
    joinTo(merged[2], merged[1], true)
    table.remove(merged, 1)
  end
  local out = {}
  for _, p in ipairs(merged) do
    table.insert(out, table.concat(p, " "))
  end
  return table.concat(out, "\n\n")
end

-- A moment's tags, with what the chapter knows of it: in the race's own lands
-- (a place's scenery says whose home it is), at night, in a group, the level.
-- (a race's own land: its people's (HOSTS), or the hosts' who took it in)
local function homeOf(race, zone)
  local owner = zone and HOSTS[zone]
  return owner ~= nil and (owner == race or TAKEN_IN[race] == owner)
end
function Scene:tags(t, m)
  t = t or {}
  local land = m and m.zone and ns.data.scenery and ns.data.scenery[m.zone]
  if t.home == nil then
    t.home = (land and land.home and land.home[self.c.race or ""]) or (m and homeOf(self.c.race, m.zone)) or nil
  end
  local level = (m and m.level) or self.lvl
  if t.night == nil then t.night = (m and m.night) or nil end
  if t.grouped == nil then t.grouped = (m and m.grouped) or nil end
  if t.high == nil then t.high = level >= 40 or nil end
  if t.low == nil then t.low = level <= 10 or nil end
  return t
end

-- ── sentences ────────────────────────────────────────────────────────────────
-- The clauses so far, as one sentence: "I a.", "I a and b.", "I a, b and c."
function Scene:flush()
  local pending = self.pending
  if #pending == 0 then return end
  local b = self.book
  local text = pending[1]
  if #pending > 1 then
    local last = pending[#pending]
    if self.arrival and not self.lead and not pending[1]:find("[;%.!%?]") then
      -- Both are recorded, in this order. The journey is the setting for
      -- the deed; it does not invent a motive or a causal link between jobs.
      local actions = table.concat(pending, " and ", 2)
      -- An action may already coordinate its own verbs. Give that thought
      -- a setting rather than introducing yet another "and" before it.
      local mode = self.arrivalMode
      if mode == 0 or (mode == 2 and actions:find(" and ")) then
        text = "When I " .. pending[1] .. ", I " .. actions
      elseif mode == 1 then
        if self.pendingKinds[2] == "inn" then actions = actions:gsub(" there", "", 1) end
        text = "I " .. pending[1] .. ", where I " .. actions
      else
        text = "I " .. pending[1] .. " and " .. actions
      end
    else
      local join = " and "
      -- A fight followed by a completed errand is an observed sequence,
      -- not an inferred cause. Other unrelated acts need no forced link.
      -- (the last clause's remark, after its comma, ends the sentence well)
      local bare = self.pendingBare[#pending]
      if pending[1]:find("[,;:]") or pending[1]:find(" and ") or bare:find("[,;:]") or bare:find(" and ") then
        join = "; I "
      elseif #pending == 2 and self.pendingKinds[1] == "kill" and self.pendingKinds[2] == "quest" then
        join = " before I "
      end
      local before = {}
      for j = 1, #pending - 1 do
        before[j] = pending[j]
      end
      text = "I " .. (join == "; I " and listing(before) or table.concat(before, ", ")) .. join .. last
      -- two plain steps of the same work, one after the other, now and then
      -- told as such ("After I fetched…, I learned…"): not every sentence
      -- opens on "I"
      if
        join == " and "
        and #pending == 2
        and not self.lead
        and self.pendingKinds[1] ~= "kill"
        and not pending[1]:find(" I ")
        and hash(b.seed .. "|after|" .. self.sentenceKey) % 3 == 0
      then
        text = "After I " .. pending[1] .. ", I " .. last
      end
    end
  elseif not self.pendingTurn then
    text = "I " .. text
  end
  self:append(
    linked(self.lead, capitalise(text .. ".")),
    self.pendingRoutine,
    self.pendingRemarks,
    self.pendingHighlight
  )
  self.pendingRoutine, self.pendingRemarks, self.pendingHighlight, self.pendingTurn = 0, 0, false, false
  -- "there" only right after the place is named
  if not self.named then b.there = true end
  self.pending, self.pendingKinds, self.pendingBare = {}, {}, {}
  self.lead, self.named, self.arrival, self.arrivalMode, self.sentenceLimit = nil, false, false, nil, nil
end

-- Whether a clause of this kind starts a sentence of its own: the one being
-- written is of other work (and not an arrival, which may frame either).
function Scene:otherWork(kind)
  return #self.pending > 0
    and not self.arrival
    and (not FAMILIES[kind] or FAMILIES[kind] ~= FAMILIES[self.pendingKinds[1]])
end

-- A clause for a moment m (the one being told, or the last one the fold
-- counted), its text and what Book:say chose (said); continued: a quest's
-- next part, which keeps to the sentence of the first. A new sentence takes a
-- link (the time gone by, or the next thing in the scene); a sentence holds as
-- many clauses as the race's style allows (STYLE), varying the length between
-- two and three. A comma within a clause is not a reason to cut the thought short.
function Scene:clause(text, said, m, key, isArrival, continued)
  if not text then return end
  local b = self.book
  local complex = text:find("[,;:%.!%?]") or text:find(" and ")
  local kind = m and m.k or ""
  -- a highlight has its sentence to itself (an arrival may frame it), and
  -- so has a clause turned round ("{foe} fell to me")
  local highlight, turned = said.weight == 3, said.turn
  if turned then self:flush() end
  if highlight and #self.pending > 0 and not (self.arrival and #self.pending == 1) then self:flush() end
  if not continued and self:otherWork(kind) then self:flush() end
  if #self.pending == 0 then
    self.sentenceKey = key
    self.lead = self:backLead(b:link(m, self.prev, key), key)
    self.sentenceLimit = isArrival and 2 or math.min(b.style.clauses, 2 + hash(b.seed .. "|length|" .. key) % 2)
    self.arrival = isArrival
    local mode = hash(b.seed .. "|arrival|" .. key) % 3
    if mode == b.lastArrivalMode then mode = (mode + 1) % 3 end
    if isArrival then b.lastArrivalMode = mode end
    self.arrivalMode = mode
  end
  local pending = self.pending
  table.insert(pending, text)
  table.insert(self.pendingKinds, kind)
  table.insert(self.pendingBare, said.remark and text:sub(1, #text - #said.remark - 2) or text)
  -- (the clauses that may carry a remark: not a hand-in)
  if said.routine and said.weight > 0 then self.pendingRoutine = self.pendingRoutine + 1 end
  if said.remark then self.pendingRemarks = self.pendingRemarks + 1 end
  if highlight then self.pendingHighlight = true end
  if turned then self.pendingTurn = true end
  if
    turned
    or highlight
    or #pending >= self.sentenceLimit
    or text:find("[;%.!%?]")
    or (isArrival and said.remark)
    or (self.pendingRemarks > 0 and #pending >= 2)
    or (#pending >= 2 and (complex or pending[1]:find("[,;:]") or pending[1]:find(" and ")))
  then
    self:flush()
  end
end

-- A quiet return named at the start of the sentence told there, after its
-- link if it has one ("Back in Anvilmar, I…", "Later, back in Anvilmar, I…").
-- Once a paragraph, and the same place not in the paragraph after: more
-- often reads as a ledger of comings and goings. (Not the wording just used.)
local BACK = { "Back %s,", "Once back %s,", "%s again," } -- ("in Anvilmar", "on Zephras Isle")
function Scene:backDue(place)
  local last = self.backAt[place]
  return place ~= nil and not self.backTold and not (last and #self.paragraphs + 1 - last < 2)
end
function Scene:backLead(link, key)
  local place = self.backTo
  self.backTo = nil
  if not self:backDue(place) then return link end
  self.backTold, self.backAt[place] = true, #self.paragraphs + 1
  local b = self.book
  self.named, b.last, b.there = true, place, false
  local i = hash(b.seed .. "|back|" .. key) % #BACK + 1
  if i == b.backForm then i = i % #BACK + 1 end
  b.backForm = i
  local back = BACK[i]:format(W.at(place)):gsub("^%l", string.upper)
  return link and link .. " " .. back:gsub("^%u", string.lower) or back
end

-- A moment of its own: a sentence, after the clauses before it (m: the
-- moment, to link it to the one before; nil: no link).
function Scene:alone(kind, values, t, m)
  local b = self.book
  self:flush()
  self.backTo = nil
  local s = b:say(kind, self.key, values, t)
  if s then self:append((#self.current > 0 and m) and linked(b:link(m, self.prev, self.key), s) or s) end
  return s
end

-- ── the scene ────────────────────────────────────────────────────────────────
-- Where a moment is: its subzone, or the scene's place if it is somewhere
-- unnamed in the same zone.
function Scene:placeOf(m)
  if m.sub then return m.sub end
  if self.scene and self.sceneZone == m.zone then return self.scene end
  return m.zone
end

-- A new scene at a place (nil: none yet, a land just entered), in a zone
-- (a quiet return to another place no longer to tell).
function Scene:enter(place, zone)
  self.scene, self.sceneZone, self.backTo = place, zone, nil
  if place then self.seenHere[place] = true end
end

-- The moment i of the log, about to be told.
function Scene:at(i, m)
  local names = self.book.placeNames
  if m.sub then names[m.sub] = true end
  if m.zone then names[m.zone] = true end
  self.m, self.i, self.key = m, i, self.n .. "|" .. i
  self.place = self:placeOf(m)
end

-- A new scene at a place, for the moment being told. Told as the journey
-- there (opener: the kind of line that tells it) the first time the chapter
-- comes to it, or coming back after a long while; a return soon after (in
-- and out of an inn, back to the camp from the hill) moves the scene without
-- a word, the place then named by what is told there, if at all.
local LONG = 3600 -- (seconds since the moment before)
function Scene:arrive(place, zone, opener, found)
  -- (found: a place's discovery, which its arrival tells, the same line
  -- whatever first happens there)
  local b, m, key = self.book, found and found.m or self.m, found and found.key or self.key
  local back = self.seenHere[place]
  local after = (m and m.at and self.prev and self.prev.at) and m.at - self.prev.at or 0
  self:emitFold()
  if back and not opener and after < LONG then
    self:enter(place, zone)
    b.last, b.there = nil, false
    self.backTo = place -- (named by the next sentence: "Back in …")
    return
  end
  self:flush()
  self:enter(place, zone)
  if not opener and place == b.last then return end
  self.named = true
  local text, said
  if opener then
    text, said = b:say(opener, key, { place = mid(place), _place = place }, self:tags(nil, m), nil, true)
  else
    text, said = b:say(
      back and "c-return" or "c-travel",
      key .. "|go",
      { place = mid(place), _place = place },
      self:tags(nil, m),
      nil,
      true
    )
  end
  -- (its link from the moment before the discovery, not before what came after)
  local prev = self.prev
  if found then self.prev = found.prev end
  self:clause(text, said, m, key, true)
  self.prev = prev
end

-- The moment's clause goes in the scene where it happened: arrived there,
-- and in a sentence of its kind of work.
function Scene:prepare()
  local m = self.m
  local place = self.place
  if place and place ~= self.scene then
    -- (a place discovered: its arrival told as a discovery)
    local found = self.discovered[place]
    self:arrive(place, m.zone, found and "c-place" or nil, found)
    self.discovered[place] = nil
  end
  if self:otherWork(m.k) then self:flush() end
end

-- The moment told in a clause of its kind (c-…), in its scene.
function Scene:tell(kind, values, t)
  local b, m = self.book, self.m
  self:prepare()
  if kind == "c-inn" then
    -- (the town a quiet return names at the start of this sentence: "there")
    local backHere = self.backTo == m.place and self:backDue(m.place) and #self.pending == 0
    values._place = m.place
    values.inn = (m.place == b.last or backHere) and "there" or "at " .. mid(m.place)
  end
  local text, said = b:say(kind, self.key, values, self:tags(t, m), nil, true)
  self:clause(text, said, m, self.key)
end

-- A quest's work by its kinds: the things it asked for, the creatures, the
-- rest, each a part of its own (the moment, with only those objectives),
-- the first objective's kind first. ("Grund and Gozwin": a log found, a
-- leopard slain: two clauses.)
local function workOf(o)
  if o.type == "monster" and o.name then return "foe" end
  if o.type == "item" and o.name then return "thing" end
  return "task"
end
local function parts(m)
  local by, order = {}, {}
  for _, o in ipairs(m.objectives or {}) do
    local k = workOf(o)
    if not by[k] then
      by[k] = {}
      table.insert(order, k)
    end
    table.insert(by[k], o)
  end
  if #order < 2 then return { m } end
  local out = {}
  for _, k in ipairs(order) do
    table.insert(out, setmetatable({ objectives = by[k] }, { __index = m }))
  end
  return out
end

-- ── prey ─────────────────────────────────────────────────────────────────────
-- A creature killed that no quest asked for: the hunt for a quest's things,
-- if they drop from it ("I hunted Ragged Young Wolves for the Tough Wolf Meat
-- Sten Stoutarm wanted"); else told with the next work done in the same place
-- soon after ("Ragged Young Wolves fell to me while I fetched
-- Tough Wolf Meat for Sten Stoutarm"), else not at all (the recap counts it).
local PREY_TIME = 1800 -- (seconds from the kill to the work)
local WORK = {
  ["c-deed-kill"] = true,
  ["c-deed-item"] = true,
  ["c-handed-kill"] = true,
  ["c-handed-item"] = true,
}
function Scene:hunted(m)
  if self.preyPlace ~= self.place then
    self.prey, self.preyPlace = {}, self.place
  end
  table.insert(self.prey, m)
end

-- The prey to tell with the work of m, in words ("Ragged Young Wolves and a
-- Ragged Timber Wolf"), and whether it is one creature; nil if none.
-- only: the creatures to take (those a quest's item drops from), the others
-- left for the next work; taken, they are told (a kill quest after the hunt
-- doesn't name them again). except: creatures not to frame this work with
-- (those its own things drop from: never "the Cougars fell before I found
-- Cougar Claws").
function Scene:takePrey(m, only, except)
  local prey, b = self.prey, self.book
  if #prey == 0 or self.preyPlace ~= self.place then return nil end
  local asked, rest = {}, {}
  for _, o in ipairs(m.objectives or {}) do
    if o.name then asked[o.name] = true end
  end
  -- (one creature in its variants, by the last word of its name and its
  -- kind: Ragged Young Wolves and a Ragged Timber Wolf are wolves, named by
  -- the one killed most)
  local groups, order, total = {}, {}, 0
  -- (a creature with a name of its own, "Gregor Agamand", is no variant of
  -- "Nissa Agamand", and one of it killed twice is still one)
  local bare = ns.names and ns.names.creatureBare or {}
  for _, k in ipairs(prey) do
    if (only and not only[k.name]) or (except and except[k.name]) then
      table.insert(rest, k)
    elseif
      (m.at or 0) - (k.at or 0) <= PREY_TIME
      and not asked[k.name]
      and not self.toldFoes[k.name]
      and not self:trophyOf(k.name)
    then
      local n = (self.ch.kills or {})[k.name] or 1
      total = total + n
      if only then self.toldFoes[k.name] = true end
      local head = bare[k.name] and k.name or (k.name:match("(%a+)$") or k.name) .. "|" .. (k.kind or "")
      local g = groups[head]
      if not g then
        g = { n = 0, most = 0 }
        groups[head] = g
        table.insert(order, g)
      end
      g.n = g.n + n
      if n > g.most then
        g.name, g.kind, g.most = k.name, k.kind, n
      end
    end
  end
  self.prey = rest
  local names = {}
  for _, g in ipairs(order) do
    -- (a creature with a name and a title of its own, killed twice, is still
    -- one: "Prospector Khazgorm", not "Prospector Khazgorms")
    g.one = bare[g.name] or TITLES[g.name:match("^(%a+) ") or ""]
    if g.one then
      table.insert(names, g.name)
    elseif g.n > 1 then
      local size = b:size(g.n, self.key .. "|" .. g.name, false, g.kind == "Wolf")
      table.insert(names, (size ~= "" and size .. " " or "") .. plural(g.name))
    else
      table.insert(names, article(g.name))
    end
  end
  if #names == 0 then return nil end
  return listing(names), total == 1 or (#order == 1 and order[1].one and true), total
end

-- Whether a creature is the owner of a trophy already told ("Thule
-- Ravenclaw" for Thule's Head): its head was the news, not another fight.
function Scene:trophyOf(name)
  for whose in pairs(self.trophied) do
    if (" " .. name .. " "):find(" " .. whose .. " ", 1, true) then return true end
  end
  return false
end
-- A named foe told slain in this paragraph whose trophy this is ("Ol'
-- Sooty" for Ol' Sooty's Head): its name, else nil.
function Scene:slainOwner(whose)
  for name in pairs(self.slain) do
    if (" " .. name .. " "):find(" " .. whose .. " ", 1, true) then return name end
  end
end

-- Every thing this work asks for drops from a creature killed on the way,
-- or the hunt would have the Okra drop from the Fleshrippers (the creatures
-- then fought between finds: "c-while").
function Scene:huntsAll(m)
  if self.preyPlace ~= self.place then return false end
  local drops, killed = ns.knowledge and ns.knowledge.drops or {}, {}
  -- (only creatures the hunt can still name: not told already, nor a trophy's owner)
  for _, k in ipairs(self.prey) do
    if (m.at or 0) - (k.at or 0) <= PREY_TIME and not self.toldFoes[k.name] and not self:trophyOf(k.name) then
      killed[k.name] = true
    end
  end
  for _, o in ipairs(m.objectives or {}) do
    if o.type == "item" and o.name then
      local any = false
      for _, name in ipairs(drops[o.name] or {}) do
        if killed[name] then any = true end
      end
      if not any then return false end
    end
  end
  return true
end

-- The creatures this work's things drop from (Knowledge.lua), as a set; nil
-- if none is known.
local function sources(m)
  local drops, out = ns.knowledge and ns.knowledge.drops or {}, nil
  for _, o in ipairs(m.objectives or {}) do
    for _, name in ipairs(o.type == "item" and o.name and drops[o.name] or {}) do
      out = out or {}
      out[name] = true
    end
  end
  return out
end

-- A quest's deed told in clauses (Book:deed), in its scene, t its tags; the
-- prey killed on the way told with its first.
function Scene:deed(t)
  local m, b = self.m, self.book
  self:prepare()
  -- (the pet at my side when the work was done, if the record knows)
  local doneAt = m.id and self.doneAt[m.id]
  local work = m.k == "done" and m or (doneAt and self.ch.log[doneAt])
  t.petName = work and work.pet or nil
  local all = parts(m)
  -- (creatures told already, as an elite moments ago: the work is who asked)
  local function told(part)
    local any = false
    for _, o in ipairs(part.objectives or {}) do
      if o.type ~= "monster" or not o.name or not self.toldFoes[o.name] then return false end
      any = true
    end
    return any
  end
  for i, part in ipairs(all) do
    if told(part) then
      if t.handed and #all == 1 and (m.ender or m.giver) then
        local text, said = b:say("c-report", self.key, { ender = m.ender or m.giver }, self:tags(nil, m), nil, true)
        self:clause(text, said, m, self.key)
      end
    else
      self:deedPart(m, part, i, #all, t)
    end
  end
end

-- One part of a quest's work (its things, its creatures or its task), told.
function Scene:deedPart(m, part, i, n, t)
  local b = self.book
  local tags = i == 1 and t or self:tags({ done = t.done, handed = t.handed, petName = t.petName }, m)
  -- (a quest's parts in one sentence: the remark, if any, on its last)
  tags.quiet = i < n or nil
  -- (the creatures its things drop from, killed on the way: the hunt for them)
  local from = i == 1 and sources(part)
  if from and self:huntsAll(part) then
    tags.prey, tags.lone = self:takePrey(m, from)
    tags.lone = tags.lone or nil -- (one creature: no "until I had")
  end
  local text, said = b:deed(part, self.key, tags)
  local prey, one, total
  if i == 1 and text and WORK[said.kind] and not said.turn and not said.state then
    prey, one, total = self:takePrey(m, nil, sources(part))
  end
  if prey then
    self:flush()
    -- (a deed with a comma or an "and" of its own takes no second "and")
    local bare = said.remark and text:sub(1, #text - #said.remark - 2) or text
    local complex = (bare:find(",") or bare:find(" and ")) and true or nil
    local t2 =
      self:tags({ one = one or nil, handed = t.handed or nil, complex = complex, lots = (total or 0) >= 10 or nil }, m)
    local framed, f = b:say("c-while", self.key, { prey = prey, deed = text }, t2, nil, true)
    if framed then
      text, said.turn = framed, f.turn
    end
  end
  self:clause(text, said, m, self.key, nil, i > 1)
  for _, o in ipairs(part.objectives or {}) do
    if o.type == "monster" and o.name then self.toldFoes[o.name] = true end
  end
end

-- An errand (a word carried, no thing or creature asked for) whose ender
-- gives the next one at once: the index of that next one in the log.
local function errand(m)
  local o = objectiveOf(m)
  return m.giver and m.ender and m.giver ~= m.ender and not (o and o.name)
end
function Scene:chainNext(m, i)
  if m.told or not errand(m) then return nil end
  local log, j = self.ch.log, i + 1
  while log[j] and (log[j].k == "level" or log[j].k == "kill") do
    j = j + 1
  end
  local nx = log[j]
  if nx and nx.k == "quest" and not nx.told and nx.giver == m.ender and errand(nx) and nx.ender ~= m.giver then
    return j
  end
end

-- A death's way back, told with it: the index of the revival that follows
-- soon after (a level, the same death told twice, a place crossed as a
-- ghost between), if any.
local REVIVAL_TIME = 1800
local function ghostly(x, m) return x.k == "level" or x.k == "place" or (x.k == "died" and x.at == m.at) end
function Scene:revivalOf(i)
  local log, m, j = self.ch.log, self.ch.log[i], i + 1
  while log[j] and ghostly(log[j], m) do
    j = j + 1
  end
  local r = log[j]
  return r and r.k == "revived" and (r.at or 0) - (m.at or 0) <= REVIVAL_TIME and j or nil
end
-- A death the open chapter ends with, so far: its way back may come yet,
-- to tell with it (told now, the sentence would change when it does).
function Scene:awaitsRevival(i)
  if self.ch.ended then return false end
  local log, m, j = self.ch.log, self.ch.log[i], i + 1
  while log[j] and ghostly(log[j], m) do
    j = j + 1
  end
  return log[j] == nil
end

-- ── the moments around ───────────────────────────────────────────────────────
-- The moments told on either side (a level reached isn't one).
function Scene:nextOf(j)
  local log = self.ch.log
  j = j + 1
  while log[j] and log[j].k == "level" do
    j = j + 1
  end
  return log[j]
end
function Scene:prevAt(j)
  local log = self.ch.log
  j = j - 1
  while j > 0 and log[j] and log[j].k == "level" do
    j = j - 1
  end
  return j
end
-- A quest's work handed in on the spot (its turn-in next, in the same place):
-- told once, at the turn-in, with whom it was for ("I brought Sten Stoutarm
-- eight Tough Wolf Meat"); the work alone says less.
function Scene:handedNext(m, i)
  local nx = self:nextOf(i)
  return nx and nx.k == "quest" and nx.told and nx.id ~= nil and nx.id == m.id and self:placeOf(nx) == self:placeOf(m)
end
-- A turn-in right after its work, in the same place.
function Scene:justDone(m, i)
  local j = self:prevAt(i)
  return m.id and self.doneAt[m.id] == j and j > 0 and self:placeOf(self.ch.log[j]) == self:placeOf(m)
end

-- ── stretches ────────────────────────────────────────────────────────────────
-- The chapter's paragraphs, worked out from its whole log: a stretch of work
-- ends at a new zone, a new day, a dungeon, a long gap, or a move to another
-- place once it holds enough (STRETCH moments told; LONGEST at most). A stretch is
-- closed only once the next has begun, so a closed paragraph never changes;
-- the one being played may, as it grows. (Not while a death waits for its
-- way back: the two are told together.)
local STRETCH, LONGEST = 4, 9
local function counted(m)
  if m.k == "level" or m.k == "revived" then return false end
  if m.k == "kill" then return m.first or m.elite or false end
  if m.k == "place" then return m.new == "zone" end
  return true
end
function Scene:segment()
  local log, starts, n, here, dying = self.ch.log or {}, {}, 0, nil, false
  -- the fold as Scene:fold will keep it: a routine hand-in past a place's
  -- few goes into the tally untold, and isn't counted (a long run of errands
  -- is no reason for a new paragraph, which would tell and fold them again)
  local lowScene, lowTold, tally, doneAt = nil, 0, 0, {}
  for i, m in ipairs(log) do
    local place, prev = m.sub or m.zone, log[i - 1]
    local what = self:routine(m, i)
    if m.k == "quest" and m.told and m.id and doneAt[m.id] == self:prevAt(i) then
      local d = log[doneAt[m.id]]
      if (d.sub or d.zone) == place then what = nil end -- (its work, told at its turn-in: Scene:justDone)
    end
    if m.k == "done" and m.id then doneAt[m.id] = i end
    local carried = what == "low" and place ~= lowScene and tally > 0 and self:onlyHandIns(i)
    local folds = what == "low" and (carried or (place == lowScene and lowTold >= LOW_TOLD))
    local cut = prev
      and (
        m.k == "wake"
        or m.k == "dungeon"
        or (m.k == "place" and m.new == "zone")
        or (m.at and prev.at and m.at - prev.at > 3600)
        or (n >= STRETCH and counted(m) and not folds and place ~= here)
        or n >= LONGEST
      )
    if cut and not dying then
      starts[i], n, here = true, 0, nil
      lowScene, lowTold, tally, carried = nil, 0, 0, false
    end
    if what == "low" then
      if place ~= lowScene then
        if not carried then
          lowTold, tally = 0, 0
        end
        lowScene = place
      end
      if lowTold >= LOW_TOLD then
        tally, folds = tally + 1, true
      else
        lowTold, folds = lowTold + 1, false
      end
    elseif what ~= "silent" and (place ~= lowScene or m.k == "place" or m.k == "dungeon" or m.k == "flight") then
      local goesOn = m.k == "place" and m.new ~= "zone" and tally > 0 and self:onlyHandIns(i)
      if not goesOn then tally = 0 end
    end
    if counted(m) and not folds then
      n, here = n + 1, place
    end
    if m.k == "died" then
      dying = true
    elseif m.k ~= "place" and m.k ~= "level" then
      dying = false
    end
  end
  self.starts = starts
  self:findErrands()
end

-- The stay that begins at moment i (until another place, zone, day or
-- dungeon) holds routine hand-ins and nothing else: a move there is no new
-- stretch, and its hand-ins join the tally of the place before (one fold,
-- not two in a row).
function Scene:onlyHandIns(i)
  local log = self.ch.log or {}
  local here, any = log[i].sub or log[i].zone, false
  for j = i, #log do
    local m, prev = log[j], log[j - 1]
    if
      j > i
      and (
        m.k == "wake"
        or m.k == "dungeon"
        or (m.k == "place" and m.new == "zone")
        or (m.at and prev and prev.at and m.at - prev.at > 3600)
        or (m.k ~= "level" and (m.sub or m.zone) ~= here)
      )
    then
      return any
    end
    -- (work done: told, or handed in on the spot and told at its turn-in)
    if m.k == "done" and not m.abandoned then return false end
    if not (m.k == "place" or m.k == "level") then
      local what = self:routine(m, j)
      if what == "low" then
        any = true
      elseif what ~= "silent" then
        return false
      end
    end
  end
  return any
end

-- A new stretch: the tally of the one before, and a new paragraph.
function Scene:nextStretch()
  self:emitFold()
  self:flush()
  self:newParagraph()
  self.book.last = nil
  self.lowTold, self.lowScene = 0, nil -- (its own few hand-ins told in full)
end

-- A run of quests one after another, nothing of note between them (a
-- lesson, a kill, a level, a new piece of gear may come between): ERRANDS of
-- them or more open with what they are ("There were smaller jobs after
-- that…"), once in ERRANDS_GAP chapters (each chapter has its run).
-- errandsFrom: the run's first moment. A class's own quest is no errand.
local ERRANDS, ERRANDS_GAP = 4, 3
local FILLER = {
  level = true,
  kill = true,
  place = true,
  learned = true,
  prof = true,
  skill = true,
  gear = true,
  loot = true,
  made = true,
  inn = true,
}
function Scene:findErrands()
  local b = self.book
  if b.errandsAt and b.chapterNo - b.errandsAt < ERRANDS_GAP then return end
  local log, class, known = self.ch.log or {}, self.c.class, ns.knowledge and ns.knowledge.quests or {}
  local from, quests, n = nil, {}, 0
  for i, m in ipairs(log) do
    if self.starts[i] then
      from, quests, n = nil, {}, 0
    end
    local own = m.id and known[m.id] and known[m.id].class == class
    if (m.k == "quest" or m.k == "done") and not m.abandoned and not own then
      from = from or i
      local id = m.id or m.title or i
      if not quests[id] then
        quests[id], n = true, n + 1
      end
      if n >= ERRANDS then
        self.errandsFrom = from
        return
      end
    elseif not FILLER[m.k] then
      from, quests, n = nil, {}, 0
    end
  end
end

-- The run of errands, opened.
function Scene:errands()
  self.book.errandsAt = self.book.chapterNo
  self:alone("errands", {}, self:tags(nil, self.m))
end

-- ── who I am among others ─────────────────────────────────────────────────────
-- After a moment told: the people its sentences named (Book:say keeps them
-- in s.peopleSaid), read against Knowledge.lua. Working for one of my own people
-- in a land that isn't theirs (a gnome's Felix Whindlebolt among the dwarves)
-- has a sentence of its own, once a zone in a book (`kin`); a race with no
-- land of its own, working in its hosts' (TAKEN_IN: gnomes among the dwarves,
-- the Darkspear among the orcs), says so once a book (`hosts`).
function Scene:situate()
  local named, b, m = self.peopleSaid, self.book, self.m
  if #named == 0 then return end
  self.peopleSaid = {}
  local race, zone = self.c.race, m.zone or ""
  local host, npcs = HOSTS[zone], ns.knowledge and ns.knowledge.npcs or {}
  if host and host == TAKEN_IN[race] and not b.hostsTold then
    b.hostsTold = true
    self:alone("hosts", { zone = mid(zone) }, self:tags({ first = true }, m), m) -- (once a life)
  end
  -- (at home, or in the hosts' land that took my people in: no news to meet them)
  if host == race or host == TAKEN_IN[race] or b.kinZones[zone] then return end
  for _, name in ipairs(named) do
    local who = npcs[name]
    if who and who.people == race then
      b.kinZones[zone] = true
      self:alone("kin", {}, self:tags(nil, m), m) -- ("We were both gnomes...": just named)
      return
    end
  end
end

-- ── the fold ─────────────────────────────────────────────────────────────────
-- What a moment is to the fold: "low" (a routine hand-in), "silent" (told
-- with another, or not at all: neither told nor tallied), else nothing.
function Scene:routine(m, i)
  if m.k == "level" or self.merged[i] then return "silent" end
  if m.k == "gear" then return (m.quality or 2) < 3 and not m.made and "low" or nil end
  if m.k ~= "quest" and m.k ~= "done" then return nil end
  if m.abandoned then return "silent" end
  if m.k == "done" and self:handedNext(m, i) then return "silent" end -- told at its turn-in
  if m.k == "quest" and m.told then -- a report back; right after the work, the work itself
    if self:justDone(m, i) then return nil end
    return m.ender and "low" or "silent"
  end
  local o = objectiveOf(m)
  if o and o.type == "item" and o.held and o.name and m.ender then return "low" end -- a delivery
  if o and (o.type == "monster" or o.type == "item") and o.name then return nil end
  if o and o.text and instruction(o.text) then return nil end
  -- known only by who asked (a message, a request): else a title, not told
  return m.giver and "low" or "silent"
end

-- The moment being told, to the fold: a routine hand-in past the scene's few
-- goes into its tally (foldNow: told there, not by its arm); anything else
-- first lets the tally be told, once the place it counted for is left.
function Scene:fold()
  local m, place = self.m, self.place
  local what = self:routine(m, self.i)
  self.foldNow = false
  if what == "low" then
    local here = place or self.scene
    if here ~= self.lowScene then
      local folded = self.folded
      if folded.errands + folded.gear > 0 and self:onlyHandIns(self.i) then
        self.lowScene = here -- (the tally goes on: nothing here but more of it)
      else
        self:emitFold()
        self.lowTold, self.lowScene = 0, here
      end
    end
    if self.lowTold >= LOW_TOLD then
      local folded = self.folded
      self.foldNow = true
      if m.k == "gear" then
        folded.gear = folded.gear + 1
      else
        -- what the errands were (all deliveries?) and who the last was for:
        -- "made three more deliveries", "did Kurdram one more favour"
        local o = objectiveOf(m)
        local sort = not m.told and o and o.type == "item" and o.held and "deliveries" or "requests"
        if folded.errands == 0 then
          folded.what = sort
        elseif folded.what ~= sort then
          folded.what = "requests"
        end
        folded.errands, folded.who = folded.errands + 1, m.ender or m.giver
      end
      folded.m, folded.key = m, self.key
    else
      self.lowTold = self.lowTold + 1
    end
  elseif
    what ~= "silent" and ((place and place ~= self.lowScene) or m.k == "place" or m.k == "dungeon" or m.k == "flight")
  then
    local folded = self.folded
    local goesOn = m.k == "place" and m.new ~= "zone" and folded.errands + folded.gear > 0 and self:onlyHandIns(self.i)
    if not goesOn then self:emitFold() end -- the place left: its tally, once
  end
end

-- The tally, told.
-- (common gear changed along the way: told in a tally once in GEAR_FOLDS,
-- or every chapter would end on "and changed some of my gear")
local GEAR_FOLDS = 3
function Scene:emitFold()
  local folded, book = self.folded, self.book
  if folded.errands + folded.gear == 0 then return end
  local gear = folded.gear > 0 and (book.foldsSinceGear or GEAR_FOLDS) >= GEAR_FOLDS
  book.foldsSinceGear = gear and 1 or (book.foldsSinceGear or GEAR_FOLDS) + 1
  local fm, fk, n = folded.m, folded.key, folded.errands
  local t = { one = n == 1 or nil, gear = gear or nil, onlygear = n == 0 or nil }
  if n > 0 then t[folded.what] = true end
  local values = { n = words(n), giver = folded.who }
  folded.errands, folded.gear, folded.what, folded.who = 0, 0, nil, nil
  if n == 0 and not gear then return end
  local text, said = self.book:say("c-fold", fk, values, self:tags(t, fm), nil, true)
  self:clause(text, said, fm, fk)
end

-- (for the next files of the writer)
W.newScene = newScene
