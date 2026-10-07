-- A chapter being told (Writer.lua tells each moment into it): its
-- paragraphs and sentences, the clauses of the sentence being written and how
-- they join, the scene it is in (a place, its zone), the moment being told,
-- and what the telling remembers of the moments so far (those told with
-- another, the find just told, the routine hand-ins folded into a tally...).
local _, ns = ...
local W = ns.writer
local words, listing, mid, objectiveOf, capitalise = W.words, W.listing, W.mid, W.objectiveOf, W.capitalise
local instruction, linked, hash = W.instruction, W.linked, W.hash

local Scene = {}
Scene.__index = Scene

-- Related work keeps together in a sentence: learning two trades is one
-- thought, a trade followed by a fight a new one.
local FAMILIES = { quest = "work", kill = "work", boss = "work", loot = "work", gear = "work",
  learned = "practice", skill = "practice", prof = "practice", made = "practice" }

-- Curation: in a scene, the first LOW_TOLD routine hand-ins (a delivery, a
-- report back, a message carried, a favour known only by who asked, green
-- gear) are told; the rest fold into one clause, told once the place is left
-- or the chapter ends ("I saw to four more errands besides"). The deeds
-- themselves, the firsts, the dangers, the finds are always told.
local LOW_TOLD = 2

-- Chapter n of the book, ch its record.
local function newScene(book, n, ch)
  local s = setmetatable({
    book = book, n = n, ch = ch, c = book.c,
    paragraphs = {}, current = {},
    -- the scene: its place (and zone), the places of the chapter so far, a
    -- plain kill told there
    scene = nil, sceneZone = nil, seenHere = {}, killed = false,
    -- the sentence being written: its clauses (their kinds, the creature a
    -- plain kill clause names: one told by its quest is dropped), the link it
    -- takes, how many the scene has, whether it names its place, an arrival
    -- framing it
    pending = {}, pendingKinds = {}, pendingFoes = {}, lead = nil, sentences = 0, named = false,
    arrival = false, arrivalMode = nil, sentenceLimit = nil,
    pendingRoutine = 0, pendingRemarks = 0, pendingHighlight = false, pendingTurn = false,
    -- the moment being told (i its place in the log, key its seed, place
    -- where it happened), and the one before
    m = nil, i = nil, key = nil, place = nil, prev = nil, foldNow = false,
    -- the fold: hand-ins told in the scene it counts for, its tally
    lowTold = 0, lowScene = nil, folded = { errands = 0, gear = 0 },
    -- who joined so far; the dungeon I'm in; moments told with the one
    -- before; the find just told; where each quest's work was told in the log
    mates = {}, dungeon = nil, merged = {}, found = nil, doneAt = {},
    -- a night (or a rest) and its waking less than half an hour apart: a
    -- relog, not a break (the recorder no longer keeps them; older journals have them)
    relog = {},
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
    if (m.k == "night" or m.k == "rested") and not m.last and w and w.k == "wake" and (w.at or 0) - (m.at or 0) < 1800 then
      s.relog[j], s.relog[j + 1] = true, true
    end
  end
  book.prepareRemark = function()
    -- (an arrival alone frames what follows: kept whole, the remark waits)
    if book.pendingRemark or (book.lastSentenceRemark and #s.pending > 0 and not (s.arrival and #s.pending == 1)) then s:flush() end
  end
  return s
end

-- ── the text ─────────────────────────────────────────────────────────────────
-- A sentence into the chapter.
function Scene:append(text, routine, remarks, highlight)
  local b = self.book
  table.insert(self.current, text)
  b.told = (b.told or 0) + 1
  b.lastSentenceRemark = (remarks or 0) > 0
  if ns.writerSentence then ns.writerSentence(text, routine or 0, remarks or 0, self.n, highlight) end
end

function Scene:newParagraph()
  if #self.current > 0 then table.insert(self.paragraphs, self.current); self.current = {} end
  local b = self.book
  b.quipped = false
  b.peopleNamed, b.thingsCarried = {}, {}
end

-- The chapter's text: a paragraph of one sentence joins the one before it
-- (the first, the one after).
function Scene:text()
  self:newParagraph()
  if #self.paragraphs == 0 then return nil end
  local merged = {}
  for _, p in ipairs(self.paragraphs) do
    if #p == 1 and #merged > 0 then table.insert(merged[#merged], p[1]) else table.insert(merged, p) end
  end
  if #merged > 1 and #merged[1] == 1 then
    table.insert(merged[2], 1, merged[1][1])
    table.remove(merged, 1)
  end
  local out = {}
  for _, p in ipairs(merged) do table.insert(out, table.concat(p, " ")) end
  return table.concat(out, "\n\n")
end

-- A moment's tags, with what the chapter knows of it: in the race's own lands
-- (a place's scenery says whose home it is), at night, in a group, the level.
function Scene:tags(t, m)
  t = t or {}
  local land = m and m.zone and ns.data.scenery and ns.data.scenery[m.zone]
  if t.home == nil then t.home = (land and land.home and land.home[self.c.race or ""]) or nil end
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
      if mode == 0 or (mode == 2 and actions:find(" and ")) then text = "When I " .. pending[1] .. ", I " .. actions
      elseif mode == 1 then
        if self.pendingKinds[2] == "inn" then actions = actions:gsub(" there", "", 1) end
        text = "I " .. pending[1] .. ", where I " .. actions
      else text = "I " .. pending[1] .. " and " .. actions end
    else
      local join = " and "
      -- A fight followed by a completed errand is an observed sequence,
      -- not an inferred cause. Other unrelated acts need no forced link.
      if pending[1]:find("[,;:]") or pending[1]:find(" and ") or last:find("[,;:]") or last:find(" and ") then join = "; I "
      elseif #pending == 2 and self.pendingKinds[1] == "kill" and self.pendingKinds[2] == "quest" then join = " before I " end
      local before = {}
      for j = 1, #pending - 1 do before[j] = pending[j] end
      text = "I " .. (join == "; I " and listing(before) or table.concat(before, ", ")) .. join .. last
    end
  elseif not self.pendingTurn then
    text = "I " .. text
  end
  self:append(linked(self.lead, capitalise(text .. ".")), self.pendingRoutine, self.pendingRemarks, self.pendingHighlight)
  b.lastSentenceRemark, b.pendingRemark = self.pendingRemarks > 0, false
  self.pendingRoutine, self.pendingRemarks, self.pendingHighlight, self.pendingTurn = 0, 0, false, false
  b.openClauses = 0
  -- "there" only right after the place is named
  if not self.named then b.there = true end
  self.pending, self.pendingKinds, self.pendingFoes = {}, {}, {}
  self.lead, self.named, self.arrival, self.arrivalMode, self.sentenceLimit = nil, false, false, nil, nil
  self.sentences = self.sentences + 1
end

-- Whether a clause of this kind starts a sentence of its own: the one being
-- written is of other work (and not an arrival, which may frame either).
function Scene:otherWork(kind)
  return #self.pending > 0 and not self.arrival and
    (not FAMILIES[kind] or FAMILIES[kind] ~= FAMILIES[self.pendingKinds[1]])
end

-- A clause for a moment: a new sentence takes a link (the time gone by, or
-- the next thing in the scene); a sentence holds as many clauses as the
-- race's style allows (STYLE), varying the length between two and three.
-- A comma within a clause is not a reason to cut the thought short.
function Scene:clause(text, m, key, isArrival)
  if not text then return end
  local b = self.book
  local complex = text:find("[,;:%.!%?]") or text:find(" and ")
  local kind = m and m.k or ""
  -- a highlight has its sentence to itself (an arrival may frame it), and
  -- so has a clause turned round ("{foe} fell to me")
  local highlight, turned = b.selectedWeight == 3, b.selectedTurn
  if turned then self:flush() end
  if highlight and #self.pending > 0 and not (self.arrival and #self.pending == 1) then self:flush() end
  if self:otherWork(kind) then self:flush() end
  if #self.pending == 0 then
    self.lead = b:link(m, self.prev, key)
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
  table.insert(self.pendingFoes, m and m.k == "kill" and m.name or false)
  -- (the clauses that may carry a remark: not a hand-in)
  if b.selectedRoutine and (b.selectedWeight or 1) > 0 then self.pendingRoutine = self.pendingRoutine + 1 end
  if b.selectedRemark then self.pendingRemarks, b.pendingRemark = self.pendingRemarks + 1, true end
  if highlight then self.pendingHighlight = true end
  if turned then self.pendingTurn = true end
  b.openClauses = #pending
  if turned or highlight or #pending >= self.sentenceLimit or text:find("[;%.!%?]")
    or (isArrival and b.selectedRemark) or (b.pendingRemark and #pending >= 2)
    or (#pending >= 2 and (complex or pending[1]:find("[,;:]") or pending[1]:find(" and "))) then self:flush() end
end

-- A moment of its own: a sentence, after the clauses before it (linked to
-- the one before when m is given).
function Scene:alone(kind, values, t, m)
  local b = self.book
  self:flush()
  local s = b:say(kind, self.key, values, t)
  if s then
    self:append((#self.current > 0 and m) and linked(b:link(m, self.prev, self.key), s) or s)
    self.sentences = 1 -- what follows in the scene may be "then"
    b.lastSentenceRemark = false
  end
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

-- The moment i of the log, about to be told.
function Scene:at(i, m)
  local names = self.book.placeNames
  if m.sub then names[m.sub] = true end
  if m.zone then names[m.zone] = true end
  self.m, self.i, self.key = m, i, self.n .. "|" .. i
  self.place = self:placeOf(m)
end

-- A new scene at a place: told as the journey there (a place just named
-- needs none).
function Scene:arrive(place, zone, m, key, opener)
  local b = self.book
  self:emitFold()
  self:flush()
  if #self.current >= 3 then self:newParagraph() end
  local back = self.seenHere[place]
  self.scene, self.sceneZone, self.killed, self.sentences = place, zone, false, 0
  self.seenHere[place] = true
  if opener then
    self.named = true
    self:clause(b:say(opener, key, { place = mid(place), _place = place }, self:tags(nil, m), nil, true), m, key, true)
  elseif place ~= b.last then
    self.named = true
    self:clause(b:say(back and "c-return" or "c-travel", key .. "|go", { place = mid(place), _place = place },
      self:tags(nil, m), nil, true), m, key, true)
  end
end

-- The moment's clause goes in the scene where it happened: arrived there,
-- and in a sentence of its kind of work.
function Scene:prepare()
  local m = self.m
  if self.place and self.place ~= self.scene then self:arrive(self.place, m.zone, m, self.key) end
  if self:otherWork(m.k) then self:flush() end
end

-- The moment told in a clause of its kind (c-…), in its scene.
function Scene:tell(kind, values, t)
  local b, m = self.book, self.m
  self:prepare()
  if kind == "c-inn" then
    values._place = m.place
    values.inn = m.place == b.last and "there" or "at " .. mid(m.place)
  end
  self:clause(b:say(kind, self.key, values, self:tags(t, m), nil, true), m, self.key)
end

-- A quest's deed told in a clause (Book:deed), in its scene, t its tags.
function Scene:deed(t)
  local m = self.m
  self:prepare()
  self:dropKill(m, t)
  self:clause(self.book:deed(m, self.key, t), m, self.key)
end

-- A quest that counts a creature just killed in the sentence being written
-- tells that kill itself: "I brought down a Brigand; I killed six Brigands"
-- is one telling too many.
function Scene:dropKill(m, t)
  local b = self.book
  local o = objectiveOf(m)
  if not (o and o.type == "monster" and o.name) then return end
  local dropped = false
  for j = #self.pending, 1, -1 do
    if self.pendingFoes[j] == o.name then
      -- (its remark, if it had one, goes with it: the budget counts again)
      if self.pending[j]:find(", ") then self.pendingRemarks = math.max(0, self.pendingRemarks - 1) end
      self.pendingRoutine = math.max(0, self.pendingRoutine - 1)
      b.pendingRemark = self.pendingRemarks > 0
      table.remove(self.pending, j); table.remove(self.pendingKinds, j); table.remove(self.pendingFoes, j)
      dropped = true
    end
  end
  -- already told, a sentence before: the quest's count is "more" of them
  local last = b.lastFoe
  if not dropped and (o.n or 1) > 1 and last and last.name == o.name and not last.many
    and (b.told or 0) - last.told <= 1 then t.more = true end
end

-- ── the moments around ───────────────────────────────────────────────────────
-- The moments told on either side (a level reached isn't one).
function Scene:nextOf(j)
  local log = self.ch.log
  j = j + 1
  while log[j] and log[j].k == "level" do j = j + 1 end
  return log[j]
end
function Scene:prevAt(j)
  local log = self.ch.log
  j = j - 1
  while j > 0 and log[j] and log[j].k == "level" do j = j - 1 end
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
    if here ~= self.lowScene then self:emitFold(); self.lowTold, self.lowScene = 0, here end
    if self.lowTold >= LOW_TOLD then
      local folded = self.folded
      self.foldNow = true
      if m.k == "gear" then folded.gear = folded.gear + 1 else folded.errands = folded.errands + 1 end
      folded.m, folded.key = m, self.key
    else
      self.lowTold = self.lowTold + 1
    end
  elseif what ~= "silent" and ((place and place ~= self.lowScene) or m.k == "place" or m.k == "dungeon" or m.k == "flight") then
    self:emitFold() -- the place left: its tally, once
  end
end

-- The tally, told.
function Scene:emitFold()
  local folded = self.folded
  if folded.errands + folded.gear == 0 then return end
  local fm, fk = folded.m, folded.key
  local t = { one = folded.errands == 1 or nil, gear = folded.gear > 0 or nil, onlygear = folded.errands == 0 or nil }
  local n = folded.errands
  folded.errands, folded.gear = 0, 0
  self:clause(self.book:say("c-fold", fk, { n = words(n) }, self:tags(t, fm), nil, true), fm, fk)
end

-- (for the next files of the writer)
ns.writer = ns.writer or {}
do
  local W = ns.writer
  W.newScene = newScene
end
