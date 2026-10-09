-- The writer's lines: one book's choice of sentences (Book:say), the
-- narrator's remarks (Book:remark), a quest's deed (Book:deed), the links
-- between sentences and the scenery of places. Each moment picks a sentence
-- or a clause of its kind (writing/<kind>.md):
--   - only sentences whose [tags] the moment has (night, hc, race:Dwarf...;
--     "!night" = not at night) and whose {slots} it can fill;
--   - a sentence never used twice in a book while a fresh one is left (then the
--     one used longest ago);
--   - chosen by a hash of the character and the moment, so the book reads the
--     same each time it is opened.
-- A place just named becomes "there"; counts are written in words; every
-- sentence starts with a capital. A place is named ("in Thelsamar"), then
-- "there" once, then left out ("I put down six wolves."): {at} must read well
-- without it. {in} always names the place (for sentences without a verb:
-- "Timber in Shimmer Ridge.").
local _, ns = ...
local W = ns.writer
local floor, listing, mid, plural, TROPHY = W.floor, W.listing, W.mid, W.plural, W.TROPHY
local TITLES, objectiveOf, itemName, things = W.TITLES, W.objectiveOf, W.itemName, W.things
local objectivesLike, sizes, uncounted = W.objectivesLike, W.sizes, W.uncounted
local article, capitalise, FACTION, HOME, KIN = W.article, W.capitalise, W.FACTION, W.HOME, W.KIN
local faith, weapon, FOE_PEOPLE, FOE_KIND, foeOf = W.faith, W.weapon, W.FOE_PEOPLE, W.FOE_KIND, W.foeOf
local THING_KIND, thingOf, instruction, lowerFirst = W.THING_KIND, W.thingOf, W.instruction, W.lowerFirst
local taskOf, TEETH, ELEMENT, CLASS_FIGHT = W.taskOf, W.TEETH, W.ELEMENT, W.CLASS_FIGHT

-- ── the writer of one book ───────────────────────────────────────────────────
local function hash(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 2147483648
  end
  -- its low bits are poor (the lowest is the parity of the bytes' sum, so
  -- "% 2" between similar keys always agreed): the high ones brought down
  return (h % 65536) * 32768 + math.floor(h / 65536)
end

-- A line's tags: conditions the moment must meet ("night"; "!night", not at
-- night), and marks, which aren't conditions.
local MARKS = { aside = true, plain = true, turn = true, state = true }
local function holds(tag, ctx)
  if MARKS[tag] then return true end
  if tag:sub(1, 1) == "!" then return not ctx[tag:sub(2)] end
  return ctx[tag] and true or false
end
local function satisfied(tags, ctx)
  for _, t in ipairs(tags or {}) do
    if not holds(t, ctx) then return false end
  end
  return true
end

local function fillable(text, values)
  for slot in text:gmatch("{(%w+)}") do
    if values[slot] == nil then return false end
  end
  return true
end

local function hasTag(s, tag)
  for _, t in ipairs(s.tags or {}) do
    if t == tag then return true end
  end
  return false
end
-- A race's or a class's line.
local function isVoice(s)
  for _, t in ipairs(s.tags or {}) do
    if t:find("^race:") or t:find("^class:") then return true end
  end
  return false
end
-- A sentence with a quip, marked [aside] in writing/ ("I saw it through.
-- Nobody died, least of all me.").
local function isQuip(s)
  for _, t in ipairs(s.tags or {}) do
    if t == "aside" then return true end
  end
  return false
end
-- The moments that may always have one.
local MATTERS = {
  ["close-light"] = true,
  ["close-deep"] = true,
  rare = true,
  died = true,
  rest = true,
  night = true,
  beginning = true,
  power = true,
  petdied = true,
}

-- How each race's journal runs (with its own sentences, writing/voices/): how
-- many clauses a sentence holds, and its own time words over the shared ones.
local STYLE = {
  default = { clauses = 3, links = {} },
  Dwarf = {
    clauses = 3,
    links = {
      night = { "Come nightfall,", "When the light went,", "That night," },
      day = { "At first light,", "Come morning,", "With the dawn," },
    },
  },
  Orc = {
    clauses = 3,
    links = {
      night = { "At nightfall,", "In the dark,", "That night," },
      day = { "At sunrise,", "With the sun,", "At dawn," },
      later = { "Later,", "Hours later," },
    },
  },
  NightElf = {
    clauses = 3,
    links = {
      night = { "Beneath the moon,", "When Elune rose,", "As night fell," },
      day = { "At dawn,", "With the first light,", "As the stars faded," },
      later = { "In time,", "Some hours later,", "Later that day," },
    },
  },
  Scourge = {
    clauses = 3,
    links = {
      night = { "After dark,", "In the dark hours,", "That night," },
      day = { "When the sun rose,", "By morning,", "Morning came, and" },
      later = { "Later,", "In due course,", "Some hours on," },
    },
  },
}

-- How many uses of a kind before one of the race's own sentences may come back.
local OWN_GAP = 8
-- The routine clauses, and the pool of remarks each may end with: the
-- narrator's own reaction ("…, with rather more appetite for supper"), told
-- for about one routine clause in three, never the same one soon again.
local ROUTINE = {
  ["c-deed-kill"] = "r-foe",
  ["c-first"] = "r-first",
  ["c-deed-item"] = "r-item",
  ["c-deed-task"] = "r-task",
  ["c-deed-word"] = "r-task",
  ["c-chain"] = "r-task",
  ["c-deliver"] = "r-task",
  ["c-gear"] = "r-gear",
  ["c-trainer"] = "r-lesson",
  ["c-skill"] = "r-lesson",
  ["c-prof"] = "r-lesson",
  ["c-travel"] = "r-road",
  ["c-return"] = "r-road",
  ["c-place"] = "r-road",
  ["c-inn"] = "r-inn",
  ["c-group"] = "r-company",
  ["c-report"] = "r-task",
  ["c-handed-kill"] = "r-foe",
  ["c-handed-item"] = "r-item",
}
-- How much a clause matters, from its own moment alone (a later moment never
-- changes it, so text already read stays as it was): 0 a routine hand-in (no
-- remark), 1 the ordinary, 2 a deed, 3 a highlight (a sentence of its own,
-- and the narrator's thought on it when one is free).
local function weigh(kind, ctx)
  if kind == "c-first" or kind == "c-elite" or kind == "c-tame" then return 3 end
  if kind == "c-deed-kill" or kind == "c-handed-kill" then return ctx.named and 3 or 2 end -- one asked for by name
  if kind == "c-handed-item" then return 2 end
  if kind == "c-deed-task" then return ctx.escort and 3 or 2 end
  if kind == "c-deed-item" or kind == "c-hunt" then return 2 end -- (a hunt: no remark, its creatures last)
  if kind == "c-gear" then return ctx.fine and 2 or ctx.made and 1 or 0 end
  if kind == "c-report" or kind == "c-deliver" or kind == "c-deed-word" or kind == "c-quest" or kind == "c-fold" then
    return 0
  end
  if kind == "c-boss" or kind == "c-loot" then return 2 end
  return 1
end

-- Chapters before a remark may come back (none fresh left): sooner than
-- that, the clause goes without.
local REMARK_GAP = 10
-- Tags that name what a remark is about: such a remark, when it fits, comes first.
local SUBJECTS =
  { teeth = true, mechanical = true, cloth = true, meat = true, explore = true, escort = true, made = true }
for _, people in ipairs(FOE_PEOPLE) do
  SUBJECTS[people[1]] = true
end
for _, kind in pairs(FOE_KIND) do
  SUBJECTS[kind] = true
end
for _, kind in ipairs(THING_KIND) do
  SUBJECTS[kind[1]] = true
end
-- A remark about this moment, not any: its subject, the night, a return, a
-- first lesson, a long fight, a weapon in hand. The others are general.
-- The pools whose general lines would fit any moment of the kind (any fight
-- at all): kept for the deeds; an ordinary one takes a specific line or none.
local GATED = { ["r-foe"] = true }
local SPECIFIC = setmetatable(
  { night = true, back = true, new = true, lots = true, held = true },
  { __index = SUBJECTS }
)

local PEOPLE = { "giver", "via", "ender", "boss", "mates", "pet" } -- slots that name people
-- Who asked, left out of a deed when already named; the kinds told without
-- the person when already named (their [again] sentences).
local AGAIN_DROPS = {
  ["c-deed-kill"] = true,
  ["c-deed-item"] = true,
  ["c-deed-task"] = true,
  ["c-deed-word"] = true,
  ["c-handed-kill"] = true,
  ["c-handed-item"] = true,
  ["c-chain"] = true,
  ["c-hunt"] = true,
  ["c-fold"] = true,
}
local AGAIN = { ["c-report"] = true, ["c-deliver"] = true, ["c-deed-word"] = true, ["c-quest"] = true }
local SINGULAR_S = W.SINGULAR_S
local Book = {}
Book.__index = Book

local function newBook(c)
  local race, class = c.race or "Human", c.class or "WARRIOR"
  local b = setmetatable({
    c = c,
    used = {},
    usedIn = {},
    uses = 0,
    seed = c.guid or "",
    flown = false,
    repeats = 0,
    chapterNo = 0,
    kindUses = {},
  }, Book)
  b.voice = { home = HOME[race], kin = KIN[race], faith = faith(race, class), weapon = weapon(race, class) }
  b.own = ns.data.voices and ns.data.voices[race] -- the race's own journal voice (writing/voices/<Race>/)
  b.style = STYLE[race] or STYLE.default
  b.faction = (c.faction == "alliance" or c.faction == "horde") and c.faction or FACTION[race]
  b.sceneSeen = {} -- places already described in this book
  b.remarkChapter = {} -- the chapter each remark was last told in
  b.creatureKinds = {} -- classifications actually recorded, not guessed from a quest's name
  b.placeNames = {} -- only places encountered so far; later events cannot rewrite an objective
  b.sizesUsed, b.sizesOrder = {}, {} -- the size words told last (Book:size)
  -- how I fight (Book:learn): fire, shadow, steel... from my class and the
  -- spells learned; a new one, to try on the next foes a quest asks for
  b.fighting, b.fresh = {}, nil
  b.noted = {} -- the spells told by a line of their own (writing/lesson.md)
  b.kinZones, b.hostsTold = {}, false -- (Scene:situate)
  for _, e in ipairs(CLASS_FIGHT[class] or {}) do
    b.fighting[e] = true
  end
  b.base = { hc = c.hardcore or nil, ["race:" .. race] = true, ["class:" .. class] = true }
  if b.faction then b.base["faction:" .. b.faction] = true end
  return b
end

-- The words a remark may not repeat from its clause's own wording ("a vest I
-- had made, made by my own hands"): those of four letters or more, and a few
-- families by their root. (What the clause names may come back: "eight Linen
-- Cloth, wondering what could be sewn from so much cloth".)
local COMMON = {
  with = true,
  that = true,
  than = true,
  what = true,
  them = true,
  their = true,
  there = true,
  more = true,
  into = true,
  from = true,
  have = true,
  been = true,
  were = true,
  when = true,
  ["then"] = true,
  some = true,
  just = true,
  this = true,
  they = true,
  once = true,
  still = true,
  before = true,
  after = true,
  again = true,
}
local ROOTS = {
  making = "made",
  make = "made",
  makes = "made",
  hands = "hand",
  handiwork = "hand",
  handmade = "hand",
  own = "own",
  works = "work",
  workmanship = "work",
}
local function echoWords(text)
  local roots = {}
  for w in text:lower():gmatch("%a+") do
    local root = ROOTS[w] or (#w >= 4 and not COMMON[w] and w) or nil
    if root then roots[root] = true end
  end
  return roots
end

-- ── one sentence ─────────────────────────────────────────────────────────────
-- Book:say below, in its steps. In a chapter, the book's scene (self.scene,
-- Scene.lua) keeps what a paragraph or a chapter remembers: who was named,
-- the quips and voice lines used, the remark budget.

-- A sentence chosen: what "used" remembers of it, the book its uses.
function Book:use(kind, e)
  self.uses = self.uses + 1
  self.kindUses[kind] = (self.kindUses[kind] or 0) + 1
  self.used[e.id] = self.uses
  self.usedIn[e.id] = self.kindUses[kind]
  if ns.writerUsed then ns.writerUsed[e.reach] = true end
end

-- Whether a clause ends with a remark: one every few ordinary clauses,
-- sooner for a deed, on a highlight whenever it can; a hand-in neither has
-- one nor counts towards one.
local function remarkDue(s, routine, weight)
  if not (s and routine and weight > 0) then return false end
  s.routineCount = s.routineCount + 1
  if weight >= 3 or s.routineCount >= s.nextRemark - (weight >= 2 and 1 or 0) then
    s:prepareRemark()
    -- (not on two sentences in a row, unless the second is a highlight)
    return s.pendingRemarks == 0 and (weight >= 3 or not s.lastSentenceRemark)
  end
  return false
end

local function each(list, fn) -- "A, B and C": A, B, C
  for part in (list:gsub(" and ", ", ")):gmatch("[^,]+") do
    fn((part:gsub("^%s+", ""):gsub("%s+$", "")))
  end
end

-- The people a sentence names (values): those as given (returned, for the
-- paragraph to remember), with "the" where it belongs.
function Book:people(kind, values, ctx, seen)
  -- A person already named in this paragraph is not named again: who asked
  -- is left out of a deed, and a return, a delivery, a message carried or a
  -- giver's request is told without the name ("I reported back once more").
  local asked = {} -- (the people as given, before "the" or a list is touched)
  for _, k in ipairs(PEOPLE) do
    asked[k] = values[k]
  end
  if seen then
    if type(values.giver) == "string" and seen[values.giver] and AGAIN_DROPS[kind] then values.giver = nil end
    -- a list of those I returned to: the ones already named leave it
    if kind == "c-report" and type(values.ender) == "string" then
      local rest = {}
      each(values.ender, function(name)
        if not seen[name] then table.insert(rest, name) end
      end)
      if #rest > 0 then values.ender = listing(rest) end
    end
    local who = kind == "c-quest" and values.giver or values.ender
    if AGAIN[kind] and type(who) == "string" then
      local all = true
      each(who, function(name)
        if not seen[name] then all = false end
      end)
      if all then ctx.again = true end
    end
  end
  -- people named with their article ("The Defias Traitor") or by a role
  -- ("the Captured Mountaineer", Names.lua): "the" inside a sentence
  local roleNamed = ns.names and ns.names.npcThe or {}
  for _, k in ipairs(PEOPLE) do
    if type(values[k]) == "string" then
      values[k] = values[k]:gsub("[^,]+", function(part)
        local lead, name, tail = part:match("^(%s*)(.-)(%s*)$")
        local andWord, rest = name:match("^(and )(.+)$")
        name = rest or name
        if name:find("^The ") then
          name = "the " .. name:sub(5)
        elseif roleNamed[name] and not TITLES[name:match("^(%a+)") or ""] then
          name = "the " .. name
        end
        return lead .. (andWord or "") .. name .. tail
      end)
    end
  end
  return asked
end

-- The sentences of a kind that fit: the race's own fresh ones, the shared
-- fresh ones (and those of them with tags), and all that fit, used or not.
-- Each with its id (what "used" remembers) and its name in the reachability
-- test: the race's own ("Dwarf/kill#3") and the shared ("kill#3").
function Book:candidates(kind, values, ctx, wantRemark)
  local s = self.scene
  -- A place just named is not named again by a sentence without a verb,
  -- unless no other sentence fits.
  local named = values["in"]
  if named and values._place == self.last and not self.there then values["in"] = nil end
  -- In a chapter: a race's or a class's line only in some chapters, twice at
  -- most; a sentence with a quip (a second, wry sentence) once a paragraph,
  -- but for the moments that matter.
  local function allowed(line)
    if not s then return true end
    if isVoice(line) and not (s.voiceChapter and s.voiceUsed < 2) and not hasTag(line, "first") then return false end -- a first, once in a life, may
    if s.quipped and not MATTERS[kind] and isQuip(line) then return false end
    -- a clause turned round ("{foe} fell to me") opens a sentence of its own,
    -- and takes no remark (a remark's subject is "I": "the road led me back,
    -- glad to be heading home" would dangle)
    if hasTag(line, "turn") and (#s.pending > 0 or wantRemark) then return false end
    return true
  end
  local race = self.c.race or "Human"
  local onlyPlain = s and s.onlyPlain
  local own, list = self.own and self.own[kind], ns.data.writing[kind]
  local ownFresh, fresh, voiced, all
  for pass = 1, 3 do
    ownFresh, fresh, voiced, all = {}, {}, {}, {}
    local function add(from, mine)
      for i, line in ipairs(from or {}) do
        if
          not (onlyPlain and pass < 3 and not hasTag(line, "plain"))
          and satisfied(line.tags, ctx)
          and fillable(line[1], values)
          and (pass % 3 == 0 or allowed(line))
        then
          local e = mine and { s = line, id = "v:" .. kind .. i, reach = race .. "/" .. kind .. "#" .. i }
            or { s = line, id = kind .. i, reach = kind .. "#" .. i }
          table.insert(all, e)
          if not self.used[e.id] then
            if mine then
              table.insert(ownFresh, e)
            else
              table.insert(fresh, e)
              if line.tags then table.insert(voiced, e) end
            end
          end
        end
      end
    end
    add(own, true)
    add(list, false)
    if #all > 0 then break end
    -- nothing allowed: first the place may be named again, then the limits go
    if pass == 1 and values["in"] ~= named then values["in"] = named end
  end
  return ownFresh, fresh, voiced, all
end

-- The sentence told, among the candidates: the race's own first while one is
-- fresh; then the lowest bit of the hash chooses between the shared tagged
-- lines and the rest, the others which; all used, the one used longest ago.
-- A routine clause doesn't begin with the verb of the one before, if a fresh
-- one can help it; prefer: tags to favour.
function Book:pick(kind, key, prefer, ownFresh, fresh, voiced, all)
  local routine = ROUTINE[kind]
  -- (a clause doesn't repeat the words of the sentence it joins: "returned
  -- with the work done and told Gryan the work was done")
  local s = self.scene
  if s and #s.pending > 0 then
    local said = echoWords(table.concat(s.pending, " "))
    local function fresh2(group)
      local kept = {}
      for _, e in ipairs(group) do
        local echo = false
        for w in pairs(echoWords((e.s[1]:gsub("{%w+}", "")))) do
          if said[w] then echo = true end
        end
        if not echo then table.insert(kept, e) end
      end
      return kept
    end
    local o, f, v = fresh2(ownFresh), fresh2(fresh), fresh2(voiced)
    if #o + #f > 0 then
      ownFresh, fresh, voiced = o, f, v
    end
  end
  local function sameVerb(e) return routine and e and e.s[1]:match("^(%a+)") == self.lastVerb end
  if routine and self.lastVerb then
    local function other(group)
      local kept = {}
      for _, e in ipairs(group) do
        if not sameVerb(e) then table.insert(kept, e) end
      end
      return kept
    end
    local o, f, v = other(ownFresh), other(fresh), other(voiced)
    if #o > 0 then
      ownFresh = o
    elseif #f > 0 then
      ownFresh = {}
    end
    if #f > 0 then
      fresh, voiced = f, v
    end
  end
  if prefer then
    local favoured = {}
    for _, group in ipairs({ ownFresh, fresh }) do
      for _, e in ipairs(group) do
        for _, t in ipairs(e.s.tags or {}) do
          if prefer[t] then
            table.insert(favoured, e)
            break
          end
        end
      end
    end
    if #favoured > 0 then
      ownFresh, fresh, voiced = {}, favoured, {}
    end
  end
  local h = hash(self.seed .. "|" .. kind .. "|" .. key)
  local pick = floor(h / 2)
  -- once all of the race's own were used: its oldest comes back, if it has
  -- been long enough (a voice that holds over a whole life, not shared prose)
  local ownOldest
  if #ownFresh == 0 then
    for _, x in ipairs(all) do
      if
        x.id:sub(1, 2) == "v:"
        and self.used[x.id]
        and (not ownOldest or self.used[x.id] < self.used[ownOldest.id])
      then
        ownOldest = x
      end
    end
    -- (a routine clause's own verbs come back less often: they are short)
    local gap = routine and 2 * OWN_GAP or OWN_GAP
    if ownOldest and ((self.kindUses[kind] or 0) - self.usedIn[ownOldest.id] < gap or sameVerb(ownOldest)) then
      ownOldest = nil
    end
  end
  if #ownFresh > 0 then return ownFresh[pick % #ownFresh + 1] end
  if ownOldest then
    self.repeats = self.repeats + 1
    return ownOldest
  end
  if #voiced > 0 and h % 2 == 0 then return voiced[pick % #voiced + 1] end
  if #fresh > 0 then return fresh[pick % #fresh + 1] end
  local e = all[1]
  for _, x in ipairs(all) do
    if self.used[x.id] < self.used[e.id] then e = x end
  end
  self.repeats = self.repeats + 1
  local gap = (self.kindUses[kind] or 0) - self.usedIn[e.id]
  if not self.minGap or gap < self.minGap then
    self.minGap, self.minGapKind = gap, kind
  end
  return e
end

-- What a sentence did to the place just named: named it (then "there"), said
-- "there" (then nothing), or moved on to other places.
function Book:placed(text, values)
  if text:find("{in}") or text:find("{where}") or text:find("{place}") or (text:find("{at}") and values._named) then
    self.last, self.there = values._place, false
  elseif text:find("{at}") and values.at == "there" then
    self.there = true
  elseif text:find("{inn}") then
    self.last, self.there = values._place, values.inn == "there"
  elseif text:find("{places}") or text:find("{zone}") then
    self.last = nil
  end
end

-- One sentence of a kind for a moment: key makes the choice stable, values
-- fill the slots (_place: the place {at}, {in} or {where} names), tags add to
-- the character's. prefer: tags to favour (a fresh sentence with one of them
-- wins over the rest). raw: a clause, left as it is (no capital).
-- Returns the text and what was chosen: { kind, weight (weigh), routine (its
-- remarks' pool, if routine), remark (the one added, if any), turn (a [turn]
-- line), state (a [state] line: "had them in my pack", no action) }.
function Book:say(kind, key, values, tags, prefer, raw)
  if not ns.data.writing[kind] then return end
  local s = self.scene
  local ctx = setmetatable(tags or {}, { __index = self.base })
  if kind == "c-return" then ctx.back = true end -- for its remark: a place known
  local routine, weight = ROUTINE[kind], weigh(kind, ctx)
  local wantRemark = not ctx.quiet and remarkDue(s, routine, weight)
  for k, v in pairs(self.voice) do
    if values[k] == nil then values[k] = v end
  end
  local seen = s and s.peopleNamed
  local asked = self:people(kind, values, ctx, seen)
  local ownFresh, fresh, voiced, all = self:candidates(kind, values, ctx, wantRemark)
  if #all == 0 then return end
  local e = self:pick(kind, key, prefer, ownFresh, fresh, voiced, all)
  self:use(kind, e)
  local chosen = e.s
  local text = chosen[1]
  local said = {
    kind = kind,
    weight = weight,
    routine = routine,
    remark = false,
    turn = hasTag(chosen, "turn"),
    state = hasTag(chosen, "state"),
  }
  if seen then -- who this sentence names, for the rest of the paragraph
    for _, k in ipairs(PEOPLE) do
      if type(asked[k]) == "string" and text:find("{" .. k .. "}", 1, true) then
        each(asked[k], function(name)
          seen[name] = true
          table.insert(s.peopleSaid, name) -- (for Scene:situate)
        end)
      end
    end
  end
  if routine then self.lastVerb = text:match("^(%a+)") end
  -- a remark ends a clause that has no comma or "and" of its own ("cursed it
  -- and let the rot do its work, taller than me" would hang off the rot)
  if wantRemark and not text:find(",") and not text:find(" and ") and not ctx.trophy then -- (a trophy speaks for itself)
    local remark = self:remark(routine, key, values, ctx, (text:gsub("{%w+}", "")), weight >= 2)
    if remark then
      text = text .. ", " .. remark
      said.remark = remark
      s.nextRemark = s.routineCount + 2 + hash(self.seed .. "|remark-gap|" .. key) % 2
    end
  end
  if s then
    if isVoice(chosen) then s.voiceUsed = s.voiceUsed + 1 end
    if isQuip(chosen) and not MATTERS[kind] then s.quipped = true end
  end
  self:placed(text, values)
  text = text:gsub("{(%w+)}", values)
  -- a place left out: no space before the punctuation, none doubled
  -- (and none left at the start: "{at}, my tenth level" with no place)
  text = text:gsub(" +([%.,;:!%?])", "%1"):gsub("  +", " "):gsub("^[ ,;:]+", "")
  return raw and text or capitalise(text), said
end

-- A remark from a pool (writing/r-*.md, and the race's own): a fresh one,
-- the race's first, one about the moment's subject (its teeth, the meat)
-- before the general; once all were used, the one used longest ago, if
-- REMARK_GAP chapters have passed; else none.
function Book:remark(pool, key, values, ctx, clauseText, general)
  local race = self.c.race or "Human"
  local own, list = self.own and self.own[pool], ns.data.writing[pool]
  local ownFresh, fresh, all = {}, {}, {}
  local said = clauseText and echoWords(clauseText) or {}
  local function echoes(line)
    for w in pairs(echoWords(line)) do
      if said[w] then return true end
    end
    return false
  end
  local function add(from, mine)
    for i, s in ipairs(from or {}) do
      if satisfied(s.tags, ctx) and fillable(s[1], values) and not echoes(s[1]) then
        local e = mine and { s = s, id = "v:" .. pool .. i, reach = race .. "/" .. pool .. "#" .. i }
          or { s = s, id = pool .. i, reach = pool .. "#" .. i }
        table.insert(all, e)
        if not self.used[e.id] then table.insert(mine and ownFresh or fresh, e) end
      end
    end
  end
  add(own, true)
  add(list, false)
  local function specific(group)
    local found = {}
    for _, e in ipairs(group) do
      for _, t in ipairs(e.s.tags or {}) do
        if SUBJECTS[t] then
          table.insert(found, e)
          break
        end
      end
    end
    return #found > 0 and found or group
  end
  local pick = hash(self.seed .. "|" .. pool .. "|" .. key)
  local function oldest(mine)
    local o
    for _, x in ipairs(all) do
      if (mine == nil or (x.id:sub(1, 2) == "v:") == mine) and (not o or self.used[x.id] < self.used[o.id]) then
        o = x
      end
    end
    return o and self.chapterNo - self.remarkChapter[o.id] >= REMARK_GAP and o or nil
  end
  local function only(group, set)
    local found = {}
    for _, x in ipairs(group) do
      for _, t in ipairs(x.s.tags or {}) do
        if set[t] then
          table.insert(found, x)
          break
        end
      end
    end
    return found
  end
  -- about this moment first ("the gurgling still in my ears" after murlocs):
  -- the race's own, else a shared one over a general line in any voice
  local ownAbout, sharedAbout = only(ownFresh, SUBJECTS), only(fresh, SUBJECTS)
  local e
  if #ownAbout > 0 then
    e = ownAbout[pick % #ownAbout + 1]
  elseif #sharedAbout > 0 then
    e = sharedAbout[pick % #sharedAbout + 1]
  elseif not general and GATED[pool] then
    -- an ordinary fight (a stray kill): a remark that answers to it (its
    -- teeth, the night) or none, not one that would fit any fight
    local near = only(ownFresh, SPECIFIC)
    if #near == 0 then near = only(fresh, SPECIFIC) end
    if #near == 0 then return nil end
    e = near[pick % #near + 1]
  -- the race's own while fresh, then back when spaced enough: the shared
  -- ones fill the gaps, so the voice holds over a whole life
  elseif #ownFresh > 0 then
    local group = specific(ownFresh)
    e = group[pick % #group + 1]
  else
    e = oldest(true)
    -- (where the race has its own, the shared fill every other gap)
    if not e and #fresh > 0 and (not own or pick % 2 == 0) then
      local group = specific(fresh)
      e = group[pick % #group + 1]
    end
    e = e or (not own and oldest(nil)) or nil
    if not e then return nil end
  end
  self:use(pool, e)
  self.remarkChapter[e.id] = self.chapterNo
  if ns.writerRemark then ns.writerRemark(e.id, self.chapterNo, self) end
  return (e.s[1]:gsub("{(%w+)}", values))
end

-- The place slots of a moment: {at} ("in Coldridge Valley", "there" if it was
-- just named, then nothing), {in} (always the name), and the place itself.
function Book:here(values, place)
  if not place then
    values.at = ""
  elseif place ~= self.last then
    values.at, values._named = W.at(place), true
  else
    values.at = self.there and "" or "there"
  end
  values["in"], values._place = W.at(place), place
  return values
end

-- Spells learned: a new way of fighting (Immolate: fire, for a warlock who
-- had only shadow) is tried on the next foes a quest asks for.
function Book:learn(spells)
  for _, spell in ipairs(spells) do
    local e = ELEMENT[spell]
    if e and not self.fighting[e] then
      self.fighting[e] = true
      self.fresh = self.fresh or spell
    end
  end
end

-- How many n is, in words (Language.lua's sizes): one of those that fit,
-- not one of the last few used, so "a good many" doesn't come back every
-- other quest; often none at all.
local SIZE_GAP = 4
-- (a size word's family: "many" for "a good many" and "a great many", "deal"
-- for "a good deal of" and "a great deal of")
local function familyOf(w) return w:match("(%a+) of$") or w:match("(%a+)$") or w end
function Book:size(n, key, mass, pack)
  local fit, fresh, unused = sizes(n, mass, pack), {}, {}
  -- (nor one of the same family: "a great many" just after "a good many")
  local family = {}
  for w in pairs(self.sizesUsed) do
    family[familyOf(w)] = true
  end
  for _, w in ipairs(fit) do
    if w == "" or not self.sizesUsed[w] then table.insert(unused, w) end
    if w == "" or not (self.sizesUsed[w] or family[familyOf(w)]) then table.insert(fresh, w) end
  end
  if #fresh == 0 then fresh = #unused > 0 and unused or fit end
  local w = fresh[hash(self.seed .. "|size|" .. key) % #fresh + 1]
  if w ~= "" then
    self.sizesUsed[w] = true
    table.insert(self.sizesOrder, w)
    if #self.sizesOrder > SIZE_GAP then self.sizesUsed[table.remove(self.sizesOrder, 1)] = nil end
  end
  return w
end

-- A quest's deed, in a clause: the creatures killed, the things gathered or
-- delivered, the task done, or who asked. Returns the text and what was
-- chosen, as Book:say.
function Book:deed(m, key, tags)
  local o = objectiveOf(m)
  local objective = o and o.text and lowerFirst(o.text)
  if objective and (objective:match("^tame ") or objective:lower():match(" tamed[%.:]?%s*$")) then return end
  local ender = m.ender ~= m.giver and m.ender or nil
  local values = { giver = m.giver, ender = ender }
  local done, said
  if o and o.type == "monster" and o.name then
    -- every creature asked for ("Rockjaw Troggs and Burly Rockjaw Troggs");
    -- one asked for by a name of its own ("Vagash", "Grik'nir the Cold") as
    -- it is, any other with its article ("a Snow Leopard Prowler")
    local foes, count, named = {}, 0, false
    for _, f in ipairs(objectivesLike(m, o)) do
      named = not f.name:find(" ") or f.name:find(" the ")
      table.insert(foes, (f.n or 1) > 1 and plural(f.name) or named and f.name or article(f.name))
      count = count + (f.n or 1)
    end
    tags.named = count == 1 and named or nil
    -- (no size with a creature asked for by name: "Clerk Horrace
    -- Whitesteed, Citizen Wilkes and Miner Hackett" are no handful)
    local single = false
    for _, f in ipairs(objectivesLike(m, o)) do
      if (f.n or 1) == 1 then single = true end
    end
    local pack = #foes == 1 and self.creatureKinds[o.name] == "Wolf"
    values.n, values.foes = single and "" or self:size(count, key, false, pack), listing(foes)
    self.lastFoe = { name = o.name, many = count > 1, told = self.told or 0 }
    tags.one = count == 1 or nil
    tags.teeth = TEETH[self.creatureKinds[o.name] or ""]
    tags.mechanical = self.creatureKinds[o.name] == "Mechanical" or nil
    local people = foeOf(o.name, self.creatureKinds[o.name])
    if people then tags[people] = true end
    -- how I fought them: my way of fighting (fire, steel...), a spell just
    -- learned, the pet at my side; favoured one time in three
    for e in pairs(self.fighting) do
      tags[e] = true
    end
    local prefer
    if self.fresh then
      tags.tried, values.spell, prefer = true, self.fresh, { tried = true }
      self.fresh = nil
    elseif tags.petName and hash(self.seed .. "|pet|" .. key) % 3 == 0 then
      prefer = { pet = true }
    elseif hash(self.seed .. "|fight|" .. key) % 3 == 0 then
      prefer = self.fighting
    end
    values.pet = tags.petName
    tags.pet = values.pet and true or nil
    -- (handed in on the spot: to whom, if not named in the paragraph already)
    if tags.handed then
      local handed =
        { n = values.n, foes = values.foes, giver = m.ender or m.giver, spell = values.spell, pet = values.pet }
      done, said = self:say("c-handed-kill", key, handed, tags, prefer, true)
    end
    if not done then
      done, said = self:say("c-deed-kill", key, values, tags, prefer, true)
    end
  elseif o and o.type == "item" and o.held and o.name and m.ender then
    -- a thing in hand when the quest was taken (a note, a letter found on a
    -- foe), carried to another: a delivery
    values.ender, values.thing = m.ender, itemName(o.name)
    -- (a thing named for whom it goes to: "the journal", once)
    local owner = o.name:match("^(.-)'s ")
    if owner and m.ender:find(owner, 1, true) == 1 then values.thing = "the " .. o.name:match("'s (.+)$"):lower() end
    -- the same thing, delivered just before: "took it on to …" ("it" only
    -- right after it was named; further back in the paragraph, named again)
    local carried = self.scene and self.scene.thingsCarried or {}
    local last = carried[o.name]
    -- ("it" for one thing; "Scarlet Crusade Documents" are "the documents")
    local many = o.name:find("[^s's]s$") and not o.name:find("'s ")
    -- ("Ahanu's Leather Goods were in Tal's hands", not "was")
    local noun = (o.name:match("^(.-) of ") or o.name):match("(%a+)$") or ""
    tags.plural = noun:find("[^s]s$") and not SINGULAR_S[noun] or nil
    if last and (self.told or 0) - last <= 1 and not many then
      tags.onward = true
    elseif last then
      -- named before, further back: by what it is ("the ring", "the book")
      local head = (o.name:match("^(.-) %l") or o.name):match("(%a+)$")
      if head then values.thing = "the " .. head:lower() end
    end
    carried[o.name] = self.told or 0
    done, said = self:say("c-deliver", key, values, tags, nil, true)
  elseif o and o.type == "item" and o.name then
    -- every thing asked for ("Felix's Box, Felix's Chest and Felix's Bucket of
    -- Bolts"), the weight of the work for one kind of thing only
    local all, list = objectivesLike(m, o), {}
    for _, f in ipairs(all) do
      table.insert(list, (f.n or 1) > 1 and things(f.name) or itemName(f.name))
    end
    -- a thing named for who asked for it: "the journal" ("Grelin Whitebeard
    -- had asked for Grelin Whitebeard's Journal" says it twice)
    local owner = m.giver and #all == 1 and (o.name:match("^(.-)'s (.+)$"))
    local renamed = owner and m.giver:find(owner, 1, true) == 1
    if renamed then list[1] = "the " .. o.name:match("'s (.+)$"):lower() end
    if #all == 1 and self.scene then self.scene.thingsCarried[o.name] = self.told or 0 end
    -- ("the harvest", Milly's eight sacks of it: one thing, never "all the the harvest")
    local count = renamed and 1 or (#all == 1 and (o.n or 1) or 2)
    values.n, values.thing = #all == 1 and self:size(count, key, uncounted(o.name)) or "", listing(list)
    if tags.done then values.giver = nil end -- found, not yet handed over
    -- the same thing again, told just before: "four more Blood Shards"
    local last = self.lastThing
    if count > 1 and last and last.name == o.name and (self.told or 0) - last.told <= 1 then tags.more = true end
    self.lastThing = { name = o.name, told = self.told or 0 }
    tags.one = count == 1 or nil
    -- several things, one of each ("Sleepers' Key, a Claw Key and a Barrow
    -- Key"): not "all the …", nor "so many"
    local single = #all > 1
    for _, f in ipairs(all) do
      if (f.n or 1) > 1 then single = false end
    end
    tags.set = single or nil
    -- one thing with a plural name ("Sea Creature Bones", "MacGrann's Dried
    -- Meats"): not "it"
    local head = (o.name:match("^(.-) of ") or o.name):match("(%a+)$") or ""
    tags.plural = count == 1 and head:find("[^s']s$") and not SINGULAR_S[head] or nil
    tags.trophy = TROPHY[o.name:match("^(%a+) of ") or ""] or nil
    tags.cloth = o.name:match("Cloth$") or o.name:match("Silk$") or o.name:match("Wool$") or nil
    tags.meat = o.name:match("Meat$") or nil -- uncounted: "it"
    local kind = not (tags.cloth or tags.meat) and thingOf(o.name)
    if kind then tags[kind] = true end
    -- (the hunt for them: the creatures they drop from, killed on the way)
    if tags.prey and not tags.trophy then
      -- {item}: the things by name, with "the" ("the Tough Wolf Meat"), or a
      -- name of their own ("Ilkrud Magthrull's Tome"), or "the tome" when
      -- named for who asked
      local hunt = { prey = tags.prey, n = values.n, thing = values.thing, giver = m.ender or m.giver }
      local names = {}
      for _, f in ipairs(all) do
        table.insert(names, (f.n or 1) > 1 and things(f.name) or f.name)
      end
      hunt.item = listing(names)
      if not hunt.item:find("^[^,]-'s ") then
        -- (its own article goes: "the Mysterious Message", not "the A …")
        hunt.item = "the " .. (hunt.item:match("^An? (.+)$") or hunt.item:match("^The (.+)$") or hunt.item)
      end
      if owner and m.giver:find(owner, 1, true) == 1 then hunt.item = list[1] end
      -- (a thing named for the creature it comes from: "the Scale of Old
      -- Murk-Eye" is not taken "from Old Murk-Eye" as well)
      local whose = o.name:match("^(.-)'s ") or o.name:match("^(.-s)' ")
      for name in tags.prey:gmatch("%u[%w' -]+%w") do
        if o.name:find(name, 1, true) then tags.ofprey = true end
        -- ("Hezrul Bloodmark" for "Hezrul's Head"; "Baron Longshores", a
        -- creature with a name of its own killed twice, for "Baron
        -- Longshore's Head": one Baron Longshore)
        if whose and ((" " .. name .. " "):find(" " .. whose .. " ", 1, true) or name == whose .. "s") then
          tags.ofprey = true
          -- (one creature by its own name, "Gregor Agamand", killed twice:
          -- not "Gregor Agamands")
          local one = name == whose .. "s" and whose
          if not one and name:sub(1, #whose + 1) == whose .. " " and name:find("s$") then
            for _, from in ipairs(ns.knowledge and ns.knowledge.drops[o.name] or {}) do
              if from == name:sub(1, -2) then one = from end
            end
          end
          local at = one and hunt.prey:find(name, 1, true)
          if at then
            hunt.prey = hunt.prey:sub(1, at - 1) .. one .. hunt.prey:sub(at + #name)
            if hunt.prey == one then tags.lone = true end
          end
        end
      end
      -- ("hunted Athrikus Narassin for Athrikus Narassin's Head": "for the
      -- head", the creature named once)
      local short = tags.ofprey
        and #all == 1
        and (o.n or 1) == 1
        and (o.name:match("'s (.+)$") or o.name:match("s' (.+)$") or o.name:match("^(.-) of "))
      if short then
        hunt.thing, hunt.item, hunt.n = "the " .. short:lower(), "the " .. short:lower(), ""
      end
      -- ("Durotar Tigers for Durotar Tiger Furs", "Tunnel Rat Ears from Tunnel
      -- Rat Vermin": "for a handful of furs", "ears")
      local part
      if #all == 1 and not short then
        local words = {}
        for w in o.name:gmatch("%S+") do
          table.insert(words, w)
        end
        for name in tags.prey:gmatch("%u[%w' -]+%w") do
          local k, same = 0, true
          for w in name:gmatch("%S+") do
            local one = (w:gsub("ies$", "y"):gsub("ves$", "f"):gsub("s$", ""))
            if same and (w == words[k + 1] or one == words[k + 1]) then
              k = k + 1
            else
              same = false
            end
          end
          if k >= 1 and k == #words - 1 and words[#words]:find("^%u%l+$") and not part then
            part = (o.n or 1) > 1 and things(words[#words]):lower() or words[#words]:lower()
          end
        end
      end
      -- ("Kuz's Skull, Nak's Skull and Lok's Skull" from Kuz, Nak and Lok
      -- Orcbane: "their skulls")
      if #all > 1 then
        local same, piece = true, nil
        for _, f in ipairs(all) do
          local whom, thing = f.name:match("^(.-)'s (%a+)$")
          if
            not whom
            or (piece and thing ~= piece)
            or not (" " .. tags.prey .. " "):find("[ ,]" .. whom:gsub("%p", "%%%0") .. "[ ,]")
          then
            same = false
          end
          piece = piece or thing
        end
        if same and piece then
          local parts = (piece:find("s$") and piece or things(piece)):lower()
          tags.ofprey, hunt.thing, hunt.item, hunt.n = true, "their " .. parts, "the " .. parts, ""
        end
      end
      if part then
        tags.ofprey = true
        hunt.thing, hunt.item = (o.n or 1) > 1 and part or article(part), "the " .. part
      end
      -- how I hunted them: my way of fighting, the pet at my side, favoured
      -- one time in three ("hunted" alone, hunt after hunt, wears thin)
      for e in pairs(self.fighting) do
        tags[e] = true
      end
      hunt.pet = tags.petName
      tags.pet = hunt.pet and true or nil
      local prefer
      if tags.pet and hash(self.seed .. "|pet|" .. key) % 3 == 0 then
        prefer = { pet = true }
      elseif hash(self.seed .. "|fight|" .. key) % 3 == 0 then
        prefer = self.fighting
      end
      done, said = self:say("c-hunt", key, hunt, tags, prefer, true)
    end
    if not done and tags.handed and not tags.more and not tags.trophy then
      local handed = { n = values.n, thing = values.thing, giver = m.ender or m.giver }
      done, said = self:say("c-handed-item", key, handed, tags, nil, true)
    end
    if not done then
      done, said = self:say("c-deed-item", key, values, tags, tags.trophy and { trophy = true } or nil, true)
    end
  elseif o and o.text and instruction(o.text) then
    -- told after the fact: "escort the Defias Traitor to discover where
    -- VanCleef was hiding" (the log's "The Defias Traitor", "is hiding")
    values.task = taskOf(o.text)
    -- (a place the reader knows already: not named again at the end)
    local prep, at = values.task:match(" (in) ([^,]+)$")
    if not at then
      prep, at = values.task:match(" (at) ([^,]+)$")
    end
    if not at then
      prep, at = values.task:match(" (inside) ([^,]+)$")
    end
    if at and self.placeNames[at] then values.task = values.task:sub(1, -(#at + #prep + 3)) end
    -- Taming objectives describe the same event as UNIT_PET. Leave that
    -- telling to the pet record, even before it arrives: no lookahead and
    -- no rewriting a finished quest sentence when the pet is later named.
    tags.explore, tags.escort = values.task:match("^explore "), values.task:match("^escort ")
    local site = values.task:match("^explore the (.+)$")
    if site and (self.placeNames[site] or (ns.data.scenery or {})[site]) then values.task = "explore " .. mid(site) end
    done, said = self:say("c-deed-task", key, values, tags, nil, true)
  elseif ender and m.giver then
    done, said = self:say("c-deed-word", key, values, tags, nil, true)
  end
  -- nothing to tell but who asked: that much; a title alone isn't told
  if not done and m.giver then
    done, said = self:say("c-quest", key, { giver = m.giver }, tags, nil, true)
  end
  return done, said
end

-- Linking words, by what happened since the moment before: night falling,
-- morning, hours gone by. A connector needs a recorded change in time.
local LINKS = {
  night = { "That night,", "By nightfall,", "When night came," },
  day = { "At first light,", "In the morning,", "With the dawn," },
  later = { "Later,", "Some hours later,", "Later that day," },
  aftermath = { "Afterwards,", "After that encounter," },
}
function Book:link(m, prev, key)
  if not (m and prev and m.at and prev.at) then return nil end
  local which
  if m.night and not prev.night then
    which = "night"
  elseif prev.night and not m.night then
    which = "day"
  elseif m.at - prev.at > 3600 then
    which = "later"
  elseif prev.k == "close" then
    which = "aftermath"
  end
  return which and self:linkWord(which, key)
end
function Book:linkWord(which, key)
  local list = (self.style and self.style.links[which]) or LINKS[which]
  local i = hash(self.seed .. "|word|" .. key) % #list + 1
  -- never the same word twice running
  if list[i] == self.lastLink then i = i % #list + 1 end
  self.lastLink = list[i]
  return list[i]
end

-- A place described, the first time in the book the character comes to it
-- (writing/scenery/): as home, an ally's land, enemy ground or neutral, by
-- night or day. Nil if there is nothing written for it, or it was told.
-- A dungeon by the instance's own name, where it differs from the place's
-- (the game gives both, depending on where it is asked).
local SCENERY_ALIAS = {
  Deadmines = "The Deadmines",
  ["Stormwind Stockade"] = "The Stockade",
  ["The Temple of Atal'Hakkar"] = "Sunken Temple",
  ["Temple of Ahn'Qiraj"] = "Ahn'Qiraj Temple",
}

function Book:sceneryOf(name, night)
  name = SCENERY_ALIAS[name or ""] or name
  local p = name and ns.data.scenery and ns.data.scenery[name]
  if not p or self.sceneSeen[name] then return nil end
  self.sceneSeen[name] = true
  local view = (p.home and p.home[self.c.race or ""]) and "home"
    or (p.faction == "neutral" and "neutral")
    or ((self.faction and p.faction == self.faction) and "ally")
    or (self.faction and "foe")
    or "neutral"
  local ctx = setmetatable({ [view] = true, night = night or nil }, { __index = self.base })
  local fits = {}
  for i, s in ipairs(p) do
    if satisfied(s.tags, ctx) then table.insert(fits, i) end
  end
  if #fits == 0 then return nil end
  local i = fits[hash(self.seed .. "|scenery|" .. name) % #fits + 1]
  if ns.writerUsed then ns.writerUsed["scenery:" .. name .. "#" .. i] = true end
  return p[i][1]
end

-- (for the next files of the writer)
W.hash = hash
W.Book = Book
W.newBook = newBook
