-- The journal: each chapter as the character would write it at the rest
-- that ends it, the stretch looked back on rather than told moment by
-- moment. From the record: its milestones, its story (what the work that
-- mattered was for: writing/why/), dangers, the foes worth naming, a
-- dungeon or company, new country, a new way of fighting and the firsts of
-- a life, the small work only when nothing else was, and one ending: a
-- thought when the stretch gave one, else the rest. Its sentences are the
-- book's own (Lines.lua: the race's voice, the spacing of repeats), its
-- words Language.lua's.
local _, ns = ...
local W = ns.writer
local words, listing, mid, article, plural = W.words, W.listing, W.mid, W.article, W.plural
local deathTags, deathFoe, FINAL = W.deathTags, W.deathFoe, W.FINAL
local HOSTS, TAKEN_IN, newBook, taught, hasNote = W.HOSTS, W.TAKEN_IN, W.newBook, W.taught, W.hasNote
local FIRST_SPELLS = W.FIRST_SPELLS
local ELEMENT, CLASS_FIGHT, at, lowerFirst, ours = W.ELEMENT, W.CLASS_FIGHT, W.at, W.lowerFirst, W.ours

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
local FIRSTS = {
  demon = true,
  shift = true,
  tame = true,
  mount = true,
  riding = true,
  power = true,
  bag = true,
  gold = true,
  spec = true,
}
-- (how much each telling weighs: milestones and the story always told, then
-- what happened that a life remembers, then what fills the room left)
local MILESTONE = {
  demon = true,
  shift = true,
  tame = true,
  power = true,
  ["class-reward"] = true,
  initiation = true,
  summit = true,
  spec = true,
}
local ROOM = 6 -- (an entry's sentences of the lesser kind, at most, less one for each milestone)
local PARAGRAPH = 7 -- (an entry this long, or longer: two paragraphs)
-- What a story was, for a word on it: a rescue, a villain's end, the dead, demons, a beast.
local RESCUE = { escorted = true, freed = true, rescued = true, defended = true, saved = true, protected = true }
local ENDS = {
  "from",
  "away",
  "to",
  "through",
  "against",
  "out",
  "as",
  "until",
  "with",
  "back",
  "past",
  "while",
  "in",
  "before",
  "so",
  "alive",
  "by",
  "and",
  "who",
  "whose",
}
-- (a rescue is of someone: a name, "the wounded Corporal Keeshan", never a
-- place, a thing of someone's or the quest's own, souls, books, nor one
-- freed to be slain)
local function rescued(text, objectives)
  local verb, rest = text:match("^(%a+) (.*)$")
  if not RESCUE[verb] then return text:find("^helped %S+ escape") or text:find("^sneaked out") end
  local object = rest:match("^([^,;]*)")
  if object:find("%f[%a]sla[yi]") or object:find("%f[%a]slew%f[%A]") or object:find("%f[%a]kill") then return false end
  for _, word in ipairs(ENDS) do
    object = object:gsub(" " .. word .. "%f[%A].*$", "")
  end
  local kind = object:find("^the ") -- ("the Defias Traitor": one of a kind, no one rescued)
  object = object:gsub("^the ", ""):gsub("^a ", "")
  local known = ns.names
  if kind and known and not known.creatureBare[(object:gsub("^[%l%s]+", ""))] then return false end
  if known and (known.placeThe[object] or known.placeBare[object]) then return false end
  if object:find("'s ") or object:find("s' ") then return false end
  for _, o in ipairs(objectives or {}) do
    if o.type == "item" and o.name == object then return false end
  end
  return object:match("(%S+)$") ~= nil and object:match("(%S+)$"):find("^[%u%d']") ~= nil
end
-- The names a deed begins with: one, "Kreenig Snarlsnout, the …"; three,
-- "Nak, Kuz and Lok Orcbane"; none, "Venture Co. loggers" (a name that only
-- says whose).
local LINKS = {}
for w in
  ("and of the in at on for to from with atop near who whose before after as so when while by beneath under inside behind across"):gmatch(
    "%a+"
  )
do
  LINKS[w] = true
end
local function namesIn(text)
  local rest, names = text:match("^%a+ (.*)$") or "", 0
  while rest:find("^%u") do
    local name = rest:match("^%u[%w'%.%-]*") -- (capitalised words in a row)
    while true do
      local word = rest:sub(#name + 1):match("^ %u[%w'%.%-]*")
      if not word then break end
      name = name .. word
    end
    names, rest = names + 1, rest:sub(#name + 1)
    local next = rest:match("^ (%l+)")
    if next and not LINKS[next] then return 0 end
    if not (rest:find("^, %u") or rest:find("^ and %u")) then break end
    rest = rest:gsub("^, ", ""):gsub("^ and ", "")
  end
  return names
end
-- Whether a story says where it happened: the land it was done in, or a
-- place the game names (Names.lua: "Skull Rock", "the Deadmines", the places
-- the stories name); it then
-- takes no other place before it ("In Orgrimmar, I seized … in Skull Rock").
local function namesPlace(text, zone)
  if zone and text:lower():find((zone:lower():gsub("^the ", "")), 1, true) then return true end
  local known = ns.names or {}
  local the, bare, named = known.placeThe or {}, known.placeBare or {}, known.placeNamed or {}
  local parts = {}
  for part in text:gmatch("[%w'%-]+") do
    table.insert(parts, part)
  end
  -- (a whole name, its capitalised words in a row, "of" or "the" between:
  -- "the Tower of Althalaxx", never "City" of "the City Architect")
  local i = 1
  while i <= #parts do
    if parts[i]:find("^%u") then
      local j = i
      while
        parts[j + 1]
        and (
          parts[j + 1]:find("^%u")
          or ((parts[j + 1] == "of" or parts[j + 1] == "the") and parts[j + 2] and parts[j + 2]:find("^%u"))
        )
      do
        j = j + 1
      end
      local name = table.concat(parts, " ", i, j):gsub("'s$", "")
      if the[name] or bare[name] or named[name] then return true end
      i = j + 1
    else
      i = i + 1
    end
  end
  return false
end
-- (the verbs of a hunt of mine: a beast's word needs one, never "guarded …
-- and saw her slain")
local HUNTS = {
  killed = true,
  slew = true,
  hunted = true,
  defeated = true,
  destroyed = true,
  brought = true,
  put = true,
  tracked = true,
  felled = true,
  ended = true,
}
-- (a weighty story says what it was, writing/why/: "" for nothing to say;
-- an errand's is guessed from its words and what it asked; first, either
-- way, a people of note to the narrator: their own irradiated kin, their
-- forebears, Cenarius's own)
local function SUBJECT(text, objectives, kinds, said)
  for _, o in ipairs(objectives or {}) do
    local people = o.type == "monster" and o.name and W.foeOf(o.name, kinds[o.name])
    if people == "leper" or people == "highborne" or people == "cenarion" then return people end
  end
  if said == "beast" and not HUNTS[text:match("^(%a+)") or ""] then return nil end
  if said then return said ~= "" and said or nil end
  if rescued(text, objectives) then return "rescue" end
  local verb = text:match("^(%a+)")
  local bare = ns.names and ns.names.creatureBare or {}
  local foes = 0 -- (a villain is one: "that one" never after "the four Hillsbrad humans")
  for _, o in ipairs(objectives or {}) do
    if o.type == "monster" then foes = foes + (o.n or 1) end
  end
  for _, o in ipairs(objectives or {}) do
    if o.type == "monster" and o.name then
      -- (its kind, from the kills recorded: the dead, demons, a beast of a name)
      local kind = kinds[o.name]
      if kind == "Undead" then return "undead" end
      if kind == "Demon" then return "demon" end
      if bare[o.name] and foes == 1 then
        if kind == "Beast" then return HUNTS[verb or ""] and "beast" or nil end
        return "villain"
      end
    end
  end
  local names = namesIn(text)
  if (verb == "killed" or verb == "slew" or verb == "defeated") and names == 1 then return "villain" end
  return nil
end
ns.storySubject = SUBJECT -- (for the tests)
local WAY_BACK = 1800 -- (a death and its way back: one sentence)
local PAIR = 190 -- (two climaxes in one sentence up to this length, else in two)
local ZALAZANE = 826 -- (the quest that ends him: a Darkspear's hope fulfilled)
local ZEPHRAS = "Zephras Isle" -- (the Skyborne's island: leaving it, a moment of a life)
local LATE = 1e9 -- (the pet, the rest of the work and the ending: after all that happened)
local DEMONS = { Imp = true, Voidwalker = true, Succubus = true, Felhunter = true, Felguard = true, Infernal = true }
local PET_GAP = 4 -- (a pet named again: not in the entries just after)
local GEAR_LEVEL = 30 -- (below it, a blue piece or one I made, worn for the first time, is told)
local CAMP_GAP = 3 -- (a camp's fire told again: not in the entries just after)
local MADE_GAP = 3 -- (what my hands made, told again: not in the entries just after)
-- (a spell paid for with my own health: of the lessons, told first)
local DEAR = { ["Life Tap"] = true, ["Health Funnel"] = true }
-- An entry's title, from the game's own words: a druid's form by its
-- spell's name, a quest's title without its poster's "Wanted:".
local FORM_TITLE = {
  bear = "Bear Form",
  cat = "Cat Form",
  travel = "Travel Form",
  aquatic = "Aquatic Form",
  moonkin = "Moonkin Form",
  tree = "Tree of Life",
  flight = "Flight Form",
}
local function questTitle(title)
  if not title then return nil end
  title = title:gsub("^[Ww][Aa][Nn][Tt][Ee][Dd]!?:?%s*", ""):gsub("^Bounty:%s*", "")
  -- ("Kill Grundig Darkcloud": the one it names)
  title = title:gsub("^Kill (%u)", "%1"):gsub("^Slay (%u)", "%1")
  -- (a poster's quotes around the name: "Hogger", Hogger)
  title = title:gsub('^"(.*)"$', "%1")
  return title ~= "" and title or nil
end
local REACT_GAP = 4 -- (a word on a story: not in the entries just after another)

-- What a chapter holds that a diary tells, from its log.
local function gather(d, c, ch)
  local f = {
    lands = {},
    count = {},
    spells = {},
    firsts = {},
    foes = {},
    rares = {},
    deaths = {},
    closes = {},
    mates = {},
    dungeons = {},
    finals = {},
    work = {}, -- [quest id] = { giver, objectives, zone }
    pets = {}, -- [name] = the work done with it at my side
    demons = {}, -- [name] = true: a demon of mine
    clans = {}, -- [an elite kind's first word] = its foe
    done = 0,
    at = {}, -- [moment] = its place in the log (an entry tells in the order things happened)
    landAt = {},
    nightAt = {}, -- [a land or a dungeon]: seen first by night
    spellAt = {},
    mateAt = {},
    dungeonAt = {},
    pvp = {}, -- players of the other side slain, in the open
    kinds = {}, -- [a creature killed] = its kind
    finds = {}, -- loot of note (epic and above)
    gear = {}, -- worn for the first time: blue and better, or made by me, while the levels are low
    trades = {}, -- a trade taken up, again, a new rank, mastered, given up
    made = {}, -- what my hands made
    fires = {}, -- the stops by a campfire
    titles = {}, -- [quest id]: its title, as the game gives it
    raids = {},
    petdied = {},
  }
  local seenMate, seenSpell, seenDungeon, dungeon = {}, {}, {}, nil
  local bare = ns.names and ns.names.creatureBare or {}
  local log = ch.log or {}
  local capital = CAPITAL[c.race or ""]
  -- (an entry begun in the city: no arrival in it to tell)
  if ch.start and ch.start.zone == capital then d.capitalSeen = true end
  local level = ch.start and ch.start.level or 1
  local looted = {} -- [an item's id]: found in this stretch
  for i, m in ipairs(log) do
    f.at[m] = i
    if m.k == "level" and m.level then level = m.level end
    -- (the highest level the game allows: a moment of the life, the journal
    -- going on after it)
    if m.k == "level" and m.top then
      table.insert(f.firsts, { k = "summit", level = m.level })
      f.at[f.firsts[#f.firsts]] = i
    end
    if m.zone then f.count[m.zone] = (f.count[m.zone] or 0) + 1 end
    -- (my people's own city, its first sight; a Skyborne's first ground
    -- below the islands)
    if m.k == "place" and m.zone == capital and not d.capitalSeen then
      d.capitalSeen, f.capital = true, { zone = m.zone, i = i, night = m.night }
    end
    if m.k == "place" and c.race == "Skyborne" and m.zone and m.zone ~= ZEPHRAS and not d.away then
      d.away, f.away = true, { zone = m.zone, i = i, night = m.night }
    end
    if m.k == "place" and m.new == "zone" and m.zone and not d.lands[m.zone] then
      d.lands[m.zone] = true
      f.landAt[m.zone], f.nightAt[m.zone] = i, m.night
      table.insert(f.lands, m.zone)
    elseif m.k == "learned" then
      -- (a spell's new rank is no new spell: told the first time only; one
      -- that defines the class, a milestone)
      for _, sp in ipairs(taught(m.spells, c)) do
        local calling = W.callingOf(c.class, sp)
        if calling and not d.called[calling] then
          d.called[calling], seenSpell[sp], d.known[sp] = true, true, true
          table.insert(f.firsts, { k = "calling", spell = sp, tag = calling })
          f.at[f.firsts[#f.firsts]] = i
        elseif not seenSpell[sp] and not d.known[sp] then
          seenSpell[sp], d.known[sp] = true, true
          f.spellAt[sp] = i
          table.insert(f.spells, sp)
        end
      end
    elseif FIRSTS[m.k] then
      table.insert(f.firsts, m)
    elseif m.k == "flight" and m.from and m.to and not d.flown then -- (a life's first flight)
      d.flown = true
      table.insert(f.firsts, m)
    elseif m.k == "prof" and m.name then -- (a trade taken up, again, a rank, given up)
      local stage = m.dropped and "dropped" or m.again and "again" or m.learned and "new" or "rank"
      table.insert(f.trades, { name = m.name, stage = stage, rank = m.rank, i = i })
    elseif m.k == "skill" and m.rank == 300 and d.trades[m.name or ""] then -- (as far as a trainer takes it)
      table.insert(f.trades, { name = m.name, stage = "master", i = i })
    elseif m.k == "made" and m.link then
      table.insert(f.made, { m = m, i = i })
    elseif m.k == "rare" and m.name then
      table.insert(f.foes, { name = m.name, rank = 1, i = i })
      f.rares[m.name] = true
    elseif m.k == "kill" and m.elite and m.name then
      -- (an elite with a name of its own, as it is, before the others; an
      -- elite of a kind, its plural if several; a kind's variants, "Mo'grosh
      -- Ogre, Brute, Enforcer", one, by the one killed most)
      local kills = ch.kills or {}
      if bare[m.name] then
        table.insert(f.foes, { name = m.name, rank = 2, i = i })
      else
        local clan = m.name:find(" ") and m.name:match("^(%S+)") or m.name
        local seen = f.clans[clan]
        if not seen then
          seen = { name = m.name, rank = 3, n = 0, names = {}, i = i }
          f.clans[clan] = seen
          table.insert(f.foes, seen)
        end
        if not seen.names[m.name] then
          seen.names[m.name] = true
          seen.n = seen.n + (kills[m.name] or 1)
          if (kills[m.name] or 1) > (kills[seen.name] or 1) then seen.name = m.name end
        end
      end
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
      table.insert(f.deaths, { m = m, back = back, i = i })
    elseif m.k == "close" then
      table.insert(f.closes, m)
    elseif m.k == "group" and (m.first or m.name) and not seenMate[m.first or m.name] then
      seenMate[m.first or m.name] = true
      f.mateAt[m.first or m.name] = i
      table.insert(f.mates, m.first or m.name)
    elseif m.k == "dungeon" and m.name then
      dungeon = m.name
      if not seenDungeon[m.name] then
        seenDungeon[m.name] = true
        f.dungeonAt[m.name], f.nightAt[m.name] = i, m.night
        table.insert(f.dungeons, m.name)
      end
    elseif m.k == "boss" and m.name and FINAL[m.name] then
      table.insert(f.finals, { boss = m.name, dungeon = dungeon })
    end
    if m.k == "quest" and m.id == ZALAZANE then d.zalazane = true end
    if (m.k == "quest" or m.k == "done") and m.id and m.title then f.titles[m.id] = m.title end
    if m.k == "pvp" then table.insert(f.pvp, { m = m, i = i }) end
    if m.k == "kill" and m.name and m.kind then f.kinds[m.name] = m.kind end
    if m.k == "loot" and (m.quality or 0) >= 4 and m.link then table.insert(f.finds, { m = m, i = i }) end
    if m.k == "loot" and m.link then looted[m.link:match("item:(%d+)") or ""] = true end
    -- (below level 30 a blue piece, or one I made, is rare enough to be news;
    -- an epic one always)
    if
      m.k == "gear"
      and m.link
      and (((m.quality or 0) >= 3 or m.made) and level < GEAR_LEVEL or (m.quality or 0) >= 4)
    then
      table.insert(f.gear, { m = m, i = i, found = looted[m.link:match("item:(%d+)") or ""] })
    end
    if m.k == "group" and m.raid then table.insert(f.raids, { m = m, i = i }) end
    if m.k == "petdied" and m.name then table.insert(f.petdied, { m = m, i = i }) end
    if m.k == "campfire" then table.insert(f.fires, { m = m, i = i }) end
    if m.k == "weapon" then d.book.weaponHeld = W.WEAPON_OF[m.weapon or -1] or d.book.weaponHeld end
    -- a class quest's reward (Knowledge.lua), a first of the life
    -- (a shaman's initiation into an element: the quest that gives its totem)
    local reward = m.k == "quest" and m.id and ns.knowledge and ns.knowledge.quests[m.id]
    if reward and reward.totem and reward.class == c.class then
      if not d.initiated[reward.totem] then -- (an element's favour: once a life)
        d.initiated[reward.totem] = true
        table.insert(f.firsts, { k = "initiation", totem = reward.totem, m = m })
        f.at[f.firsts[#f.firsts]] = i
      end
    elseif reward and reward.spell and reward.class == c.class then
      -- (a spell that defines the class: told as such, once)
      local calling = W.callingOf(c.class, reward.spell)
      local first
      if calling and not d.called[calling] then
        d.called[calling], d.known[reward.spell] = true, true
        first = { k = "calling", spell = reward.spell, tag = calling }
      elseif not calling then
        first = { k = "class-reward", q = reward, m = m }
      end
      if first then
        table.insert(f.firsts, first)
        f.at[first] = i
      end
    end
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
      w.ender = w.ender or m.ender
      w.objectives = w.objectives or m.objectives
      -- (its place: where its work was done, else where it was handed in)
      w.zone = (m.k == "done" and m.zone) or w.zone or m.zone
      w.done = w.done or m.k == "done" -- (its work done here: an escort's too, with no objective)
      w.grouped = w.grouped or (m.k == "done" and m.grouped) or nil -- (done in company)
      -- (who was with me when its work was done, else when it was handed in;
      -- an older record knows only that I was in company: no names in its deed)
      if m.k == "done" and m.with then
        w.with = m.with
      elseif m.k == "quest" and m.with and not w.done then
        w.with = w.with or m.with
      end
      f.work[m.id] = w
      -- a foe with a name of its own a quest sent me after, alone ("Hogger";
      -- not one of several, the farmers of a raid)
      local monsters = {}
      for _, o in ipairs(m.objectives or {}) do
        if o.type == "monster" then table.insert(monsters, o) end
      end
      local o = monsters[1]
      if #monsters == 1 and o.name and bare[o.name] and (o.n or 1) == 1 and m.k == "done" then
        table.insert(f.foes, { name = o.name, rank = 2, i = i })
      end
    end
  end
  -- (the land most of it happened in; a tie, where it began, else by name:
  -- the same book on every reading)
  local start = ch.start and ch.start.zone
  local main, most = start, 0
  for zone, n in pairs(f.count) do
    if n > most or (n == most and zone ~= main and (zone == start or (main ~= start and zone < main))) then
      main, most = zone, n
    end
  end
  f.main = main
  -- (a summoning taught and the demon called the same stretch: one moment,
  -- the demon by its name; a form taught and taken, the form; a steed, the power)
  local called = {}
  for _, m in ipairs(f.firsts) do
    if m.k == "demon" and m.family then called["Summon " .. m.family] = true end
    if m.k == "shift" and m.form then called[m.form:gsub("^%l", string.upper) .. " Form"] = true end
    if m.k == "power" and m.spell then called[m.spell] = true end
  end
  for k = #f.firsts, 1, -1 do
    local m = f.firsts[k]
    if m.k == "class-reward" and called[m.q.spell] then table.remove(f.firsts, k) end
  end
  for _, foe in ipairs(f.foes) do
    if foe.n then -- (an elite kind: several, its plural)
      foe.plural = foe.n > 1
      foe.shown = foe.plural and plural(foe.name) or article(foe.name)
    end
  end
  return f
end

-- (the foe of a name a deed ended, "slew Chol'aruk the Ravener …": Chol'aruk)
local KILLS = { killed = true, slew = true, defeated = true, destroyed = true, hunted = true, slain = true }
local function deedFoe(text)
  local verb, name = text:match("^(%a+) (%u[%w'%-]*)")
  local bare = ns.names and ns.names.creatureBare or {} -- (one of a name: not "Defias" of "Defias Trappers")
  return KILLS[verb or ""] and bare[name] and name or nil
end
-- The stretch's story: the quests whose work weighed most (writing/why/:
-- what each was for, weighed 1 to 3), the heaviest first, of two alike the
-- one whose work was done here (a deed over a delivery), then the later;
-- the first if it was more than an errand, a second if a climax too and
-- both read well in one sentence.
local function storyOf(d, ch, f, thin, busy)
  local whys, seen, all = ns.data.why or {}, {}, {}
  local race = d.c.race or "Human"
  for i, m in ipairs(ch.log or {}) do
    local why = m.id and whys[m.id]
    -- (a class's own quest is told by what it gave, a milestone, not as a story)
    local classed = m.id and ns.knowledge and ns.knowledge.quests[m.id]
    if classed and classed.class == d.c.class then why = nil end
    if why and (m.k == "quest" or m.k == "done") and not m.abandoned and not seen[m.id] and not d.storied[m.id] then
      seen[m.id] = true
      local w = f.work[m.id] or {}
      local deed = w.done or false
      for _, o in ipairs(w.objectives or {}) do
        if o.type == "monster" or o.type == "item" then deed = true end
      end
      -- (of two alike, the one for my own people: Zalazane, for a Darkspear)
      local mine = W.ours(why[2], race) ~= why[2]
      table.insert(all, {
        id = m.id,
        w = why[1],
        text = why[2],
        said = why[3],
        i = i,
        deed = deed,
        mine = mine,
        zone = w.zone or m.zone,
      })
    end
  end
  table.sort(all, function(x, y)
    if x.w ~= y.w then return x.w > y.w end
    if x.mine ~= y.mine then return x.mine end
    if x.deed ~= y.deed then return x.deed end
    return x.i > y.i
  end)
  -- (one deed told once: two quests that ended the same foe of a name,
  -- "slew Chol'aruk the Ravener …" for two givers, in this stretch or an
  -- earlier one; the other counts as told. Not by title: a chain's steps
  -- often share one, each its own deed)
  local kept, twins = {}, {}
  for _, q in ipairs(all) do
    local foe = deedFoe(q.text)
    local twin = foe and d.ended[foe] or false -- (an earlier entry told its end)
    for _, k in ipairs(kept) do
      if foe and foe == deedFoe(k.text) then twin = true end
    end
    if twin then
      table.insert(twins, q.id)
    else
      table.insert(kept, q)
    end
  end
  all = kept
  local told, weighty = { twins = twins }, 0
  for _, q in ipairs(all) do
    if q.w >= 2 then weighty = weighty + 1 end
  end
  -- (an errand with a reason, when the stretch has nothing else to tell; a
  -- second climax; in a stretch full of stories, a deed beside a climax, and
  -- in one fuller still, a third: an entry with much in it may grow)
  if all[1] and (all[1].w >= 2 or thin) then told[1] = all[1] end
  local function deed(q) return q and q.w == 2 and q.deed end
  if told[1] and all[2] and told[1].w == 3 and (all[2].w == 3 or (deed(all[2]) and weighty >= 3)) then
    told[2] = all[2]
  end
  -- (a third only when the entry has nothing else of its own: no milestone,
  -- land, company, dungeon, death, foe of note or trade; three deeds beside
  -- those read as a log)
  if told[2] and all[3] and all[3].w == 3 and weighty >= 4 and not busy then told[3] = all[3] end
  table.sort(told, function(x, y) return x.i < y.i end) -- (in the order they happened)
  return told
end

-- (words too common to count as an echo)
local COMMON = {}
for w in
  (
    "before after through another myself nothing something little should though rather having itself always "
    .. "around enough without between already almost anything everything towards against behind beside others "
    .. "people stretch thought nearly"
  ):gmatch("%a+")
do
  COMMON[w] = true
end

-- One chapter's entry. What it tells, by what weighs most: the milestones of
-- a life (a first demon of its kind, a form, a companion, an element's
-- favour, a class's reward) and the stretch's story, always, then deaths
-- and the closest call, a dungeon, a first sight, a fight with players, a
-- find; then, in the room left, the foes worth naming, new lands, lessons,
-- company, the pet; the small work only when nothing else was; an ending on
-- a danger's thought, else the rest. Told in the order it happened, two
-- paragraphs when it runs long.
local function entry(d, n, ch)
  local b, c = d.book, d.c
  -- (a place always named: the entry is told in the order things happened,
  -- after it is written, so a "there" could come before what it points to)
  local function here(values, place)
    b.last, b.there = nil, false
    return b:here(values, place)
  end

  local race = c.race or "Human"
  local start, e = ch.start or {}, ch.ended
  -- (a start the game had not placed yet, Forever at login: where it told
  -- me I was a moment later)
  local placed = ch.log and ch.log[1]
  if not (start.zone or start.sub) and placed and placed.k == "place" and (placed.zone or placed.sub) then
    if (placed.at or 0) - (start.at or placed.at or 0) <= 60 then
      start = setmetatable({ zone = placed.zone, sub = placed.sub }, { __index = start })
    end
  end
  if start.zone then d.lands[start.zone] = true end -- (where it began is no new country)
  local f = gather(d, c, ch)
  local level = (e and e.level) or start.level or 1
  local out, events, owned, lesser = {}, 0, 0, 0
  -- (at: where in the stretch it happened, the entry told in that order)
  local function add(text, event, when)
    if text and text ~= "" then
      out[#out + 1] = { text = text, at = when or LATE, seq = #out + 1 }
      if event then events = events + 1 end
      return true
    end
    return false
  end
  -- (the entry's title: its weightiest moment, by the game's own words, a
  -- quest's title, a name, a place; rank 1 weighs most)
  local heads = {}
  local function headline(rank, title)
    if title and title ~= "" then table.insert(heads, { rank = rank, title = title, seq = #heads }) end
  end
  -- (a place seen for the first time in a life: its description, writing/scenery/)
  local function scenery(place, night, when)
    local text = b:sceneryOf(place, night)
    if text then add(text, false, when) end
  end
  local function tags(t, zone)
    t = t or {}
    if t.home == nil then t.home = homeOf(race, zone or f.main) == "home" or nil end
    t.high, t.low = level >= 40 or nil, level <= 10 or nil
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
  -- (not a word of its own the entry used already, "sympathy" twice: a line
  -- that does only if no other will)
  local function echoes(text, values)
    local own = {}
    for _, v in pairs(values or {}) do
      if type(v) == "string" then
        for w in v:lower():gmatch("%a+") do
          own[w] = true
        end
      end
    end
    for _, o in ipairs(out) do
      for w in o.text:gmatch("%f[%a]%l%a%a%a%a%a+") do
        if not own[w] and not COMMON[w] and text:find("%f[%a]" .. w .. "%f[%A]") then return true end
      end
    end
    -- (nor a phrase of four words another sentence has: "before the stretch
    -- was out" twice in a row)
    local said = {}
    for _, o in ipairs(out) do
      local ws = {}
      for w in o.text:lower():gmatch("[%a']+") do
        table.insert(ws, w)
      end
      for k = 1, #ws - 3 do
        said[table.concat(ws, " ", k, k + 3)] = true
      end
    end
    local ws = {}
    for w in text:lower():gmatch("[%a']+") do
      table.insert(ws, w)
    end
    for k = 1, #ws - 3 do
      local fresh = false
      for j = k, k + 3 do
        if own[ws[j]] then fresh = true end -- (the moment's own words: a name, a deed)
      end
      if not fresh and said[table.concat(ws, " ", k, k + 3)] then return true end
    end
    return false
  end
  local function sayFresh(kind, key, values, t, zone, prefer, ok)
    local fallback, kept
    for k = 1, 4 do
      local before = owned
      local text = say(kind, k == 1 and key or key .. k, values, t, zone, prefer)
      if not text then return fallback end
      if not ok or ok(text) then
        if not echoes(text, values) then return text end
        if not fallback then
          fallback, kept = text, owned
        end
      end
      owned = before
    end
    if fallback then owned = kept end
    return fallback
  end
  local mates = {}
  for k = 1, math.min(#f.mates, 3) do
    mates[k] = f.mates[k]
  end
  local thin = #f.deaths + #f.closes + #f.foes + #f.lands + #f.firsts + #f.dungeons + #f.mates + #f.spells == 0
  local busy = #f.firsts + #f.lands + #f.mates + #f.dungeons + #f.deaths + #f.foes + #f.trades > 0
  local story = storyOf(d, ch, f, thin, busy)
  local inStory = {}
  for _, q in ipairs(story) do
    inStory[q.id] = true
  end

  -- where it began, in the race's voice (a life's first page: its land,
  -- too); one entry in three that goes on where the last one rested, its
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
  -- (its place said already by the story itself, "across Loch Modan": no lead;
  -- a land the entry then tells as new: its first sight comes first)
  local leads = storyZone and not newLand and not namesPlace(story[1].text, storyZone)
  local first0 -- (a story that leads the entry, in place of its opening: told first)
  if wentOn and leads and n % 3 == 0 then
    lead, first0 = at(storyZone), -2
  elseif where then
    add(
      sayFresh(first and "beginning" or "opening", "open", here({ where = mid(where) }, where), {
        night = start.night or nil,
      }, start.zone, first and { ["class:" .. (c.class or "")] = true } or nil), -- (a life's first page: the class's own, if any)
      false,
      -2
    )
    if first then add(b:sceneryOf(start.zone, start.night), false, -1) end
    b.last, b.there = where, false
    -- (a story elsewhere than where the entry began: led by its own place)
    if leads and storyZone ~= start.zone then lead = at(storyZone) end
  end
  b.last = nil -- (told in the order things happened: a place is named, never "there")

  -- the milestones of a life, every one: a demon (by its name; one taught
  -- before, its summoning put to use at last), a form, a companion (the first,
  -- or another), an element's favour, a class's defining spell, a class's
  -- reward (not beside its defining spell: the quest that taught it), a power
  local milestones, called = 0, false
  for _, m in ipairs(f.firsts) do
    if m.k == "calling" then called = true end
  end
  for k, m in ipairs(f.firsts) do
    local key, text = "first" .. k, nil
    if m.k == "class-reward" and called then m = {} end
    if m.k == "demon" then
      local family = (m.family or ""):lower()
      local known = d.summoned[family] and true or nil
      text = sayFresh(
        "demon",
        key,
        { pet = m.name, demon = article(family) },
        { [family] = true, known = known },
        nil,
        known and { known = true } or { [family] = true }
      )
    elseif m.k == "shift" then
      text = sayFresh("shift", key, {}, { [m.form or ""] = true }, nil, { [m.form or ""] = true })
    elseif m.k == "power" then
      text = sayFresh("power", key, { spell = m.spell }, { [m.kind or "form"] = true })
    elseif m.k == "tame" then
      text = sayFresh(
        "d-tame",
        key,
        { pet = m.name, family = m.family and article(m.family:lower()) },
        { first = not d.tamed or nil },
        nil,
        m.family and { first = not d.tamed or nil } or nil
      )
      d.tamed = true
    elseif m.k == "initiation" then
      text = sayFresh("d-initiation", key, {}, { [m.totem] = true }, nil, { [m.totem] = true })
    elseif m.k == "summit" then
      text = sayFresh("summit", key, { level = words(m.level or 60) }, {})
    elseif m.k == "spec" and m.name then
      -- (the way a life took, by the game's name for it; another after it)
      local tag = "spec:" .. m.name:gsub(" ", "_")
      text = sayFresh(
        "d-spec",
        key,
        { spec = m.name, was = m.was },
        { [tag] = true, change = m.was and true or nil },
        nil,
        not m.was and { [tag] = true } or nil
      )
    elseif m.k == "calling" then
      -- (a way to a city: home only when it is my people's, or our hosts')
      local place = m.spell:match("^Teleport: (.+)$") or m.spell:match("^Portal: (.+)$")
      local city = place and (place == "Stormwind" and "Stormwind City" or place)
      text = sayFresh(
        "d-calling",
        key,
        { spell = m.spell, place = place },
        { [m.tag] = true, home = city and homeOf(race, city) ~= nil or nil },
        nil,
        { [m.tag] = true }
      )
    elseif m.k == "class-reward" then
      -- (a demon's summoning; a warhorse's or a dreadsteed's is a mount's)
      local family = m.q.spell:match("^Summon (.+)$")
      if not DEMONS[family or ""] then family = nil end
      local t = { summon = family and true or nil }
      if family then
        t[family:lower()] = true
        d.summoned[family:lower()] = n -- (its first summoning, later: by the demon's name)
      end
      text = sayFresh("class-reward", key, {
        giver = m.m.ender or m.m.giver,
        spell = m.q.spell,
        pet = family and article(family:lower()),
      }, t)
    end
    if text then
      add(text, true, f.at[m])
      milestones = milestones + 1
      if m.k == "tame" or m.k == "demon" then d.pets[m.name] = { said = n } end -- (named: met)
      -- (a defining spell, a specialization: below a villain's end or a
      -- rescue, a milestone of the class rather than of this life)
      headline(
        (m.k == "calling" or m.k == "spec") and 2.5 or 1,
        (m.k == "tame" or m.k == "demon" or m.k == "spec") and m.name
          or m.k == "shift" and FORM_TITLE[m.form or ""]
          or m.k == "initiation" and questTitle(m.m.title)
          or m.k == "class-reward" and (questTitle(m.m.title) or m.q.spell)
          or m.spell
      )
    end
  end

  -- (one who brought me back from death in an earlier entry, met again:
  -- said in the company's own sentence, once)
  local function reviverIn(list)
    local names = {}
    for name in pairs(d.revivers) do
      table.insert(names, name)
    end
    table.sort(names)
    for _, mate in ipairs(list) do
      for _, name in ipairs(names) do
        local was = d.revivers[name]
        if was.n < n and (name == mate or name:match("^([^%s%-]+)") == mate) then return name, was end
      end
    end
  end

  -- the story of the stretch: the deed that mattered, told as done ("I
  -- killed Hogger, …"); a chain's quest after a recent entry told one of it
  -- by the same people, the business taken up again, or finished; a second
  -- climax in the same sentence when both are short, else its own; and, now
  -- and then, a word on what it was (a rescue, a villain's end, the dead)
  local chains, ends = ns.knowledge and ns.knowledge.chains or {}, ns.knowledge and ns.knowledge.ends or {}
  local also
  local storyTold, companyTold = false, false
  local inDeed = {} -- [a companion]: named in the deed
  local storyAt = nil -- (where the last of the story's sentences goes)
  local function storyLast()
    for _, o in ipairs(out) do
      if storyAt and o.at > storyAt then return false end
    end
    return storyAt ~= nil
  end
  local storied = {} -- (the stories told: a boss whose end one tells isn't told again)
  if #story > 0 then
    local text, who
    local why = ours(story[1].text, race)
    local sameVerb = story[2] and story[1].text:match("^(%S+)") == story[2].text:match("^(%S+)")
    if #story == 2 and #story[1].text + #story[2].text <= PAIR and not sameVerb then
      text = sayFresh("d-why2", "why", { why = why, why2 = ours(story[2].text, race) }, {})
    else
      also = { story[2], story[3] }
      local q = story[1]
      local root = chains[q.id]
      local before = root and d.threads[root]
      local w = f.work[q.id] or {}
      local thread = before
        and before.n < n
        and before.n >= n - 4
        and w.giver
        and (w.giver == before.giver or w.giver == before.ender)
      -- (whose business it was, by name, unless the deed names them itself)
      who = thread and not why:find(w.giver, 1, true) and w.giver or nil
      -- ("the old business": an entry or more between)
      local t = thread
          and { thread = true, settled = ends[q.id] or nil, who = who and true or nil, old = before.n <= n - 2 or nil }
        or {}
      local prefer = thread and (t.settled and { settled = true } or { thread = true }) or nil
      if prefer and who then prefer.who = true end
      text = sayFresh("d-why", "why", { why = why, who = who }, t, nil, prefer)
    end
    -- (done in company: who was with me when it was done, in the deed's own
    -- sentence; one who had left by then is told with the company, if at all)
    local with = {}
    if text and text:find("^I ") then
      for _, mate in ipairs((f.work[story[1].id] or {}).with or {}) do
        if #with < 3 then table.insert(with, mate) end
      end
      -- (among them one who once brought me back: the company's own sentence
      -- tells them, and that)
      if reviverIn(with) then with = {} end
    end
    if text and #with > 0 then
      text = (lead and lead .. ", with " or "with ") .. listing(with) .. ", " .. text
      text = text:gsub("^%l", string.upper)
      for _, mate in ipairs(with) do
        d.mates[mate], inDeed[mate] = true, true
      end
      companyTold = true
    elseif text and lead then
      -- ("I" stays a capital after the place: "In Loch Modan, I killed …";
      -- a name too: "In the Barrens, Regthar Deathgate's business …")
      local byName = who and text:sub(1, #who) == who
      local rest = (text:find("^I[ ']") or byName) and text or lowerFirst(text)
      text = lead:gsub("^%l", string.upper) .. ", " .. rest
    end
    local told = add(text, true, first0 or story[1].i)
    storyTold = told
    if told then storyAt = first0 or story[1].i end
    if told then
      table.insert(storied, story[1].text)
      if #story == 2 and not also then table.insert(storied, story[2].text) end
    end
    -- (somewhere else than the one before: "Later, in Darkshore, I …")
    -- (two of them: never the same opening twice, "After that, … After that, …")
    -- (its opening by what the record shows: the last of them, "before the
    -- stretch was out"; night fallen since the one before; the same chain)
    local before, opened, prior = storyZone, nil, story[1]
    for k, next in ipairs(also or {}) do
      local moved = next.zone and next.zone ~= before and not namesPlace(next.text, next.zone)
      local where2 = moved and at(next.zone) or nil
      local log = ch.log or {}
      local dark = (log[next.i] or {}).night and not (log[prior.i] or {}).night
      local same = chains[next.id] and chains[next.id] == chains[prior.id]
      local said = sayFresh(
        "d-why-also",
        "also" .. k,
        { why = ours(next.text, race), where = where2 },
        { moved = moved or nil, last = k == #also or nil, night = dark or nil, thread = same or nil },
        nil,
        nil,
        function(line) return line:match("^(%a+ %a+)") ~= opened end
      )
      prior = next
      if add(said, false, next.i) then
        storyAt = math.max(storyAt or next.i, next.i)
        out[#out].where = where2
        table.insert(storied, next.text)
        opened = said:match("^(%a+ %a+)")
      end
      before = next.zone or before
    end
    -- (what it was, a word on it: now and then, never the same twice)
    local subject = told and SUBJECT(story[1].text, (f.work[story[1].id] or {}).objectives, f.kinds, story[1].said)
    if told then headline(subject and 2 or 5, questTitle(f.titles[story[1].id])) end
    -- (when the weightier titles are an earlier entry's: the other stories'
    -- titles, then a foe of a name a story ended, "Grawmug")
    local bare = ns.names and ns.names.creatureBare or {}
    for k = 2, #story do
      headline(8, questTitle(f.titles[story[k].id]))
    end
    for _, q in ipairs(story) do
      for _, o in ipairs((f.work[q.id] or {}).objectives or {}) do
        if o.type == "monster" and o.name and bare[o.name] then headline(8.5, o.name) end
      end
    end
    -- (after two deeds in one sentence, it is read as about the second: only
    -- when both were alike)
    if subject and #story == 2 and not also then
      local w2 = f.work[story[2].id] or {}
      if SUBJECT(story[2].text, w2.objectives, f.kinds, story[2].said) ~= subject then subject = nil end
    end
    if subject and (story[1].w == 3 or n % 2 == 0) and milestones < 2 and n - d.reactedAt >= REACT_GAP then
      local word = sayFresh(
        "d-react",
        "react",
        {},
        { [subject] = true },
        nil,
        { [subject] = true },
        function(said) return not d.reacted[said] end
      )
      if add(word, false, first0 and -1.75 or story[1].i + 0.5) then -- (right after its story)
        d.reacted[word], d.reactedAt = true, n
        storyAt = math.max(storyAt or -2, first0 and -1.75 or story[1].i + 0.5)
        out[#out].follows = true -- (never the first of a paragraph)
      end
    end
  end
  for _, id in ipairs(story.twins) do
    d.storied[id] = true
  end
  for _, q in ipairs(story) do
    local foe = deedFoe(q.text)
    if foe then d.ended[foe] = true end
    d.storied[q.id] = true -- (its work done here, its return in the next: told once)
    local root = chains[q.id]
    local w = f.work[q.id] or {}
    if root then d.threads[root] = { n = n, giver = w.giver, ender = w.ender } end
  end

  -- deaths, else the closest call (a foe that killed me is told there; one
  -- that nearly did, a hard fight when the foes are named)
  local dangerFoes, deathFoes, dangerAt = {}, {}, nil
  local bareNames = ns.names and ns.names.creatureBare or {} -- (a foe of a name: "Hogger")
  for _, m in ipairs(f.closes) do
    if m.foe then dangerFoes[m.foe] = true end
  end
  if #f.deaths == 1 then
    local death = f.deaths[1]
    local m, r = death.m, death.back
    local place = m.sub or m.zone
    local t = deathTags(m.death or {})
    if m.death and m.death.foe then deathFoes[m.death.foe] = true end
    if r and r.how == "ally" and r.by then d.revivers[r.by] = { n = n, place = place } end
    if m.death and m.death.foe and (bareNames[m.death.foe] or f.rares[m.death.foe]) then
      d.dangers[m.death.foe] = { n = n, place = place, died = true }
    end
    if r then
      t[r.how or "corpse"] = true
      add(
        sayFresh(
          "died-back",
          "died",
          here({ foe = deathFoe(m.death or {}), by = r.by, graveyard = r.graveyard and mid(r.graveyard) }, place),
          t,
          m.zone
        ),
        true,
        death.i
      )
    else
      add(sayFresh("died", "died", here({ foe = deathFoe(m.death or {}) }, place), t, m.zone), true, death.i)
    end
    headline(4, m.zone and ("A Death " .. at(m.zone)))
    dangerAt = death.i
  elseif #f.deaths > 1 then
    headline(4, f.deaths[1].m.zone and ("Deaths " .. at(f.deaths[1].m.zone)))
    for _, death in ipairs(f.deaths) do -- (unnamed there: told plainly with the foes, if beaten after)
      if death.m.death and death.m.death.foe then dangerFoes[death.m.death.foe] = nil end
    end
    add(
      say("d-deaths", "deaths", { times = #f.deaths == 2 and "twice" or words(#f.deaths) .. " times" }, {}),
      true,
      f.deaths[1].i
    )
    dangerAt = f.deaths[1].i
  elseif #f.closes > 0 then
    local worst = f.closes[1]
    for _, m in ipairs(f.closes) do
      if (m.hp or 100) < (worst.hp or 100) then worst = m end
    end
    if worst.foe then deathFoes[worst.foe] = true end -- (told there, not again among the foes)
    if worst.foe and (bareNames[worst.foe] or f.rares[worst.foe]) and not d.dangers[worst.foe] then
      d.dangers[worst.foe] = { n = n, place = worst.sub or worst.zone }
    end
    add(
      sayFresh(
        (worst.hp or 100) <= 5 and "close-deep" or "close-light",
        "close",
        here({ foe = worst.foe and (f.rares[worst.foe] and worst.foe or article(worst.foe)) }, worst.sub or worst.zone),
        { night = worst.night or false, foe = worst.foe ~= nil },
        worst.zone
      ),
      true,
      f.at[worst]
    )
    dangerAt = f.at[worst]
  end

  -- a foe of a name that killed me or nearly did, in an earlier entry,
  -- beaten now (not when the story tells it): told once, where it fell
  for i, m in ipairs(ch.log or {}) do
    local was = (m.k == "kill" or m.k == "rare") and m.name and d.dangers[m.name]
    if was and was.n < n then
      d.dangers[m.name], d.toldFoes[m.name] = nil, true
      local told = false
      for _, q in ipairs(story) do
        if q.text:find(m.name, 1, true) then told = true end
      end
      if not told then
        add(
          sayFresh(
            "d-revenge",
            "revenge",
            { foe = m.name, at = was.place and at(was.place) },
            { died = was.died or nil }
          ),
          true,
          i
        )
      end
    end
  end

  -- a dungeon, and its end
  local below = f.dungeons[1]
  if below then
    add(
      say("d-dungeon", "dungeon", { dungeon = mid(below), mates = listing(mates) }, { one = #mates == 1 or nil }),
      true,
      f.dungeonAt[below]
    )
    scenery(below, f.nightAt[below], f.dungeonAt[below] + 0.25)
    headline(3, below)
    local fin = f.finals[1]
    for _, text in ipairs(storied) do
      if fin and text:find(fin.boss, 1, true) then fin = nil end -- (its end told by the story)
    end
    if fin then
      add(
        sayFresh(
          "boss-final",
          "final",
          { boss = fin.boss, dungeon = mid(fin.dungeon or below) },
          { grouped = #mates > 0 or nil }
        ),
        false,
        f.dungeonAt[below] + 0.5
      )
    end
  end
  -- my people's city, its first sight (or our hosts', for those taken in)
  if f.capital then
    local kind = homeOf(race, f.capital.zone)
    add(
      say("d-land", "capital", { lands = mid(f.capital.zone) }, {
        one = true,
        capital = true,
        late = d.late,
        home = kind == "home" or false,
        hosts = kind == "hosts" or nil,
      }, nil, { capital = true }),
      true,
      f.capital.i
    )
    scenery(f.capital.zone, f.capital.night, f.capital.i + 0.25)
    headline(6, f.capital.zone)
  end
  -- a Skyborne's first ground below the islands, once a life (after the
  -- island's own work that took me there: the skycutter, then the ground)
  if f.away then
    -- (the island's work: done on it, or naming it, "the skycutter from
    -- Zephras Isle to Dalaran", wherever it was handed in)
    local when = f.away.i
    for _, q in ipairs(story) do
      if (q.zone == ZEPHRAS or q.text:find(ZEPHRAS, 1, true)) and q.i > when then when = q.i + 0.1 end
    end
    add(
      say(
        "d-land",
        "away",
        { lands = mid(f.away.zone) },
        { one = true, away = true, home = false },
        nil,
        { away = true }
      ),
      true,
      when
    )
    scenery(f.away.zone, f.away.night, when + 0.05)
    headline(6, f.away.zone)
  end
  -- a fight with players of the other side, in the open (one by name, or several)
  if #f.pvp > 0 then
    local m = f.pvp[1].m
    if #f.pvp == 1 and m.name then
      local who = (W.RACE_NAME[m.race or ""] or "")
        .. (W.CLASS_NAME[m.class or ""] and " " .. W.CLASS_NAME[m.class] or "")
      who = who:gsub("^ ", "")
      add(
        sayFresh(
          "pvp-one",
          "pvp",
          here({ name = m.first or m.name, who = who ~= "" and article(who) or nil }, m.sub or m.zone),
          { known = who ~= "" or nil },
          m.zone
        ),
        true,
        f.pvp[1].i
      )
    else
      local horde = 0
      for _, x in ipairs(f.pvp) do
        if W.HORDE_RACE[x.m.race or ""] then horde = horde + 1 end
      end
      add(
        sayFresh(
          "pvp-many",
          "pvp",
          here({ n = words(#f.pvp), side = horde * 2 >= #f.pvp and "the Horde" or "the Alliance" }, m.sub or m.zone),
          {},
          m.zone
        ),
        true,
        f.pvp[1].i
      )
    end
  end
  -- a raid; a find of note; a pet lost
  if #f.raids > 0 then
    local clause = b:say("c-raid", n .. "|diary|raid", { n = words(f.raids[1].m.raid) }, tags({}), nil, true)
    add(clause and ("I " .. clause .. "."), true, f.raids[1].i)
  end
  -- a piece of gear worn for the first time (one an entry: made, else the
  -- finest), with its find when it came from this stretch's spoils
  local worn
  for _, x in ipairs(f.gear) do
    if
      not worn
      or (x.m.made and not worn.m.made)
      or (x.m.made == worn.m.made and (x.m.quality or 0) > (worn.m.quality or 0))
    then
      worn = x
    end
  end
  if worn then
    local name = worn.m.link:match("%[(.-)%]")
    local item = name and W.itemName(name)
    if item then
      add(
        sayFresh("d-gear", "gear", { item = item }, {
          made = worn.m.made or nil,
          held = worn.m.held or nil,
          trinket = worn.m.trinket or nil,
          found = worn.found or nil,
          one = item ~= name or nil, -- ("a Wolf Fang Necklace": one thing; "Cuirboulle Gloves": a pair)
        }),
        true,
        worn.i
      )
    end
  end
  for k, x in ipairs(f.finds) do
    if k > 1 or (worn and worn.found and worn.m.link == x.m.link) then break end -- (worn at once: told so)
    local item = x.m.link:match("%[(.-)%]")
    local clause = item
      and b:say("c-loot", n .. "|diary|find", { item = W.itemName(item) }, tags({ fine = true }), nil, true)
    add(clause and ("I " .. clause .. "."), true, x.i)
  end
  for _, x in ipairs(f.petdied) do
    if d.pets[x.m.name] then d.pets[x.m.name].fell = x.m.sub or x.m.zone end -- (remembered, when named again)
    add(sayFresh("petdied", "petdied", here({ pet = x.m.name }, x.m.sub or x.m.zone), {}, x.m.zone), true, x.i)
  end
  -- a stop by a fire (not the one the entry ends at): shared with others,
  -- the life's first, or one of the camps now and then
  local ending = e and e.how == "campfire" and f.fires[#f.fires]
  local stop
  for _, x in ipairs(f.fires) do
    if x ~= ending and (x.m.with or not d.fireSeen or (x.m.camp and n - (d.fireAt or -CAMP_GAP) >= CAMP_GAP)) then
      stop = stop or x
      if x.m.with and not stop.m.with then stop = x end
    end
  end
  if stop then
    local with = stop.m.with or {}
    local told = add(
      sayFresh("d-camp", "camp", here({ mates = #with > 0 and listing(with) or nil }, stop.m.sub or stop.m.zone), {
        first = not d.fireSeen or nil,
        company = #with > 0 or nil,
        one = #with == 1 or nil,
        camp = stop.m.camp or nil,
        night = stop.m.night or nil,
      }, stop.m.zone),
      #with > 0 or not d.fireSeen, -- (a fire shared, or the first: a moment of the life)
      stop.i
    )
    if told then
      d.fireSeen, d.fireAt = true, n
    end
  end

  -- in the room left (less for each milestone, two at least: an entry with
  -- much in it may grow): company, a lesson paid for in my own health, the
  -- foes worth naming, new lands, the other lessons or a new way of
  -- fighting, a new rank in a trade, a ride, the first flight, bag or gold,
  -- the pet named again
  local room = math.max(2, ROOM - #out - milestones)
  local function more(text, event, when)
    if lesser >= room then return false end
    if add(text, event, when) then
      lesser = lesser + 1
      return true
    end
    return false
  end

  -- company first, people before anything else in the room (not when the
  -- dungeon told it, nor those the story did)
  if companyTold then
    local others = {}
    for _, mate in ipairs(mates) do
      if not inDeed[mate] then table.insert(others, mate) end
    end
    mates = others
  end
  if not below and #mates > 0 then
    local again = true
    for _, mate in ipairs(mates) do
      if not d.mates[mate] then again = false end
      d.mates[mate] = true
    end
    local reviver, was = reviverIn(mates)
    if
      more(
        say(
          "d-company",
          "company",
          { mates = listing(mates), at = was and was.place and at(was.place) },
          { one = #mates == 1 or nil, again = again or nil, reviver = reviver and true or nil },
          nil,
          reviver and { reviver = true } or nil
        ),
        false,
        f.mateAt[mates[1]]
      ) and reviver
    then
      d.revivers[reviver] = nil
    end
  end

  -- what I can do now: a spell with a line of its own (two at most, in the
  -- entry it was learned; one paid for with my own health first, before the
  -- foes, the others after the lands), else a new way of fighting (a noted
  -- spell's way is no news after it)
  local fighting, notes, newWay = {}, {}, false
  for _, sp in ipairs(f.spells) do
    local way = ELEMENT[sp]
    if hasNote(sp, b) and not b.noted[sp] then
      table.insert(notes, sp)
    elseif way and not d.ways[way] then
      d.ways[way], newWay = true, true
      table.insert(fighting, sp)
    end
  end
  table.sort(notes, function(x, y)
    if (DEAR[x] or false) ~= (DEAR[y] or false) then return DEAR[x] or false end
    return f.spellAt[x] < f.spellAt[y]
  end)
  local noted = 0
  local function note(sp)
    if noted >= 2 then return end
    if
      more(
        say("lesson", "lesson" .. noted + 1, { spell = sp }, { ["spell:" .. sp:gsub(" ", "_")] = true }),
        false,
        f.spellAt[sp]
      )
    then
      noted, b.noted[sp] = noted + 1, true
      if ELEMENT[sp] then d.ways[ELEMENT[sp]] = true end
    end
  end
  for _, sp in ipairs(notes) do
    if DEAR[sp] then note(sp) end
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
  local foes, hard, seen, many, foeAt = {}, false, {}, false, nil
  for _, foe in ipairs(f.foes) do
    local inText = false
    for _, q in ipairs(story) do
      if q.text:find(foe.name, 1, true) then inText = true end
    end
    local skip = inText or storyFoes[foe.name] or deathFoes[foe.name] or d.toldFoes[foe.name] or seen[foe.name]
    if not skip and #foes < 3 then
      seen[foe.name], d.toldFoes[foe.name] = true, true
      table.insert(foes, foe.shown or foe.name)
      if foe.plural then many = true end
      foeAt = math.min(foeAt or foe.i or LATE, foe.i or LATE)
      if dangerFoes[foe.name] then hard = true end
    end
  end
  if #foes > 0 then
    for _, foe in ipairs(f.foes) do
      if seen[foe.name] and foe.rank <= 2 then headline(8.5, foe.name) end -- (a rare, a foe of a name)
    end
    more(
      sayFresh("d-foes", "foes", { foes = listing(foes) }, {
        -- (one foe in name and number: "Pyrewood Sentries" are no "one")
        one = (#foes == 1 and not many) or nil,
        two = #foes == 2 or nil,
        plural = many or nil, -- (an elite kind among them: no "both fights")
        hard = hard or nil,
      }),
      true,
      foeAt
    )
  end

  -- new country: lands strange to my people, else theirs, else our hosts'
  local strange, homes, hosted = {}, {}, {}
  for _, zone in ipairs(f.lands) do
    if not (f.away and zone == f.away.zone) then -- (told as the leaving)
      local kind = homeOf(race, zone)
      table.insert(kind == "home" and homes or kind == "hosts" and hosted or strange, zone)
    end
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
  -- (a city among them: no line calls it country)
  local town = false
  for k = 1, #named do
    if W.CITIES[lands[k]] then town = true end
  end
  if #named > 0 then
    local told = more(
      sayFresh("d-land", "land", { lands = listing(named) }, {
        one = #named == 1 or nil,
        late = d.late,
        town = town or nil,
        home = landTag == "home" or false,
        hosts = landTag == "hosts" or nil,
      }),
      true,
      f.landAt[lands[1]]
    )
    if told then headline(7, lands[1]) end
    -- (the first of them with a description of its own, right after)
    for k = 1, told and #named or 0 do
      local before = #out
      scenery(lands[k], f.nightAt[lands[k]], f.landAt[lands[1]] + 0.25)
      if #out > before then break end
    end
  end

  for _, sp in ipairs(notes) do
    if not DEAR[sp] then note(sp) end
  end
  if newWay and noted == 0 then
    local spells = {}
    for k = 1, math.min(#fighting, 3) do
      spells[k] = fighting[k]
    end
    -- (put to use already in its stretch: cast before it closed, as the
    -- record says, every one of them; never guessed from the fights after)
    local used = true
    for _, sp in ipairs(spells) do
      local lesson = ch.log[f.spellAt[sp] or 0] or {}
      local cast = false
      for _, name in ipairs(lesson.used or {}) do
        if name == sp then cast = true end
      end
      used = used and cast
    end
    more(
      say(
        "d-powers",
        "powers",
        { spells = listing(spells) },
        { one = #spells == 1 or nil, used = used and true or nil }
      ),
      false,
      f.spellAt[spells[1]]
    )
  end

  -- (what my hands made, new to them: two things at most, not the piece
  -- worn, told already)
  local function madeThings()
    local things, listed = {}, {}
    for _, x in ipairs(f.made) do
      local name = x.m.link:match("%[(.-)%]")
      if name and not listed[name] and not d.made[name] and not (worn and worn.m.link == x.m.link) and #things < 2 then
        listed[name] = true
        local one = W.itemName(name)
        table.insert(things, (x.m.n or 1) > 1 and (one == name and name or plural(name)) or one)
      end
    end
    return things
  end
  local tradeTold = false

  -- the trades of the stretch, in one sentence: taken up, taken up again, a
  -- new rank, as far as a trainer takes them, given up; in the order they
  -- came, one verb for those in a row at the same stage ("took up herbalism
  -- and mining"), the trade just named as "it" ("took up herbalism and gave
  -- it up"), and what my hands made beside them (not the piece worn: told
  -- already). A trade given up and taken up again straight after is one
  -- moment: a return to it. A rank alone is a lesser thing; a trade begun,
  -- ended or mastered, a moment of a life.
  if #f.trades > 0 then
    local trades = {}
    for _, t in ipairs(f.trades) do
      local last = trades[#trades]
      if last and last.stage == "dropped" and t.stage == "again" and last.name == t.name then
        trades[#trades] = { name = t.name, stage = "back", i = last.i }
      else
        table.insert(trades, t)
      end
    end
    local groups = {}
    for _, t in ipairs(trades) do
      local key = t.stage .. (t.rank or "")
      local g = groups[#groups]
      if not (g and g.key == key) then
        g = { key = key, stage = t.stage, rank = t.rank, names = {}, seen = {}, items = {} }
        table.insert(groups, g)
      end
      if not g.seen[t.name] then
        g.seen[t.name] = true
        table.insert(g.names, t.name:lower())
        table.insert(g.items, t)
      end
    end
    local clauses, weighty = {}, false
    for k, g in ipairs(groups) do
      -- (the first new rank of a trade taken up in an earlier entry: where)
      local name = #g.names == 1 and g.items[1].name or nil
      local began = g.stage == "rank" and name and d.began[name]
      if began and began.n >= n then began = nil end
      -- (the trade the clause before named, alone: "it")
      local before = groups[k - 1]
      local it = name and before and #before.names == 1 and before.names[1] == g.names[1] or nil
      local clause = b:say(
        "c-prof",
        n .. "|diary|trade" .. k,
        {
          prof = not it and listing(g.names) or nil,
          rank = g.rank,
          arank = g.rank and article(g.rank),
          began = began and began.at or nil,
        },
        tags({ [g.stage] = true, one = #g.names == 1 or nil, since = began and true or nil, it = it }),
        (began and { since = true }) or (it and { it = true }) or nil,
        true
      )
      if g.stage == "rank" and name then d.began[name] = nil end
      if (g.stage == "new" or g.stage == "again" or g.stage == "back") and clause then
        for _, t in ipairs(g.items) do
          d.began[t.name] = { n = n, at = at(ch.log[t.i].sub or ch.log[t.i].zone) }
        end
      end
      if clause then table.insert(clauses, clause) end
      if g.stage ~= "rank" then weighty = true end
    end
    local things = madeThings()
    if #clauses > 0 and #things > 0 then
      table.insert(clauses, "kept my hands busy with " .. listing(things))
      d.madeAt = n
    end
    if #clauses > 0 then
      local joined = clauses[1]
      if #clauses > 1 then
        local ands = false
        for _, clause in ipairs(clauses) do
          if clause:find(" and ", 1, true) then ands = true end
        end
        joined = table.concat(clauses, ", ", 1, #clauses - 1)
          .. ((ands or #clauses > 2) and ", and " or " and ")
          .. clauses[#clauses]
      end
      local text = "I " .. joined .. "."
      if weighty then
        tradeTold = add(text, true, trades[1].i)
      else
        tradeTold = more(text, false, trades[1].i)
      end
    end
  end
  -- what my hands made, when no trade was told: new to them, now and then
  if not tradeTold and n - d.madeAt >= MADE_GAP then
    local things = madeThings()
    -- (between the work, told after it: never between two deeds)
    if #things > 0 and more(sayFresh("d-made", "made", { things = listing(things) }, {}), false, LATE + 0.5) then
      d.madeAt = n
    end
  end
  for _, x in ipairs(f.made) do
    local name = x.m.link:match("%[(.-)%]")
    if name then d.made[name] = true end -- (made once: no news again)
  end

  -- the lesser firsts: a ride, the first bag, the first gold
  for k, m in ipairs(f.firsts) do
    if not MILESTONE[m.k] then
      local key, text = "small" .. k, nil
      do
        -- (the first bag: what it is, its room; the first mount: which)
        local item = m.k == "bag" and m.link and m.link:match("%[(.-)%]")
        local values = {
          item = item and W.itemName(item),
          slots = m.slots and words(m.slots),
          mount = m.k == "mount" and m.name and m.name:lower() or nil,
          -- (a flight's ends, by their places: "Ironforge", not "Ironforge, Dun Morogh")
          from = m.k == "flight" and (m.from:match("^([^,]+)") or m.from) or nil,
          to = m.k == "flight" and (m.to:match("^([^,]+)") or m.to) or nil,
        }
        local t = { looted = m.looted or nil }
        if m.k == "mount" and m.kind then
          t[m.kind] = true
          owned = math.min(owned, 1) -- (a people's own mount: the race's own words, whatever came before)
        end
        text = sayFresh(m.k, key, values, t, nil, m.k == "mount" and m.kind and { [m.kind] = true } or nil)
        if text and m.k == "mount" then headline(6, m.name) end
      end
      more(text, false, f.at[m])
    end
  end

  -- the pet at my side through most of the work, named again (one an
  -- earlier entry met), not in the entries just after (four to six), nor
  -- beside a new one
  local pet, most = nil, 0
  for name, k in pairs(f.pets) do
    if k > most or (k == most and pet and name < pet) then
      pet, most = name, k
    end
  end
  for _, m in ipairs(f.firsts) do
    if m.k == "tame" or m.k == "demon" then pet = nil end -- (a new one told: no other)
  end
  local known = pet and d.pets[pet]
  local gap = PET_GAP + (pet and #pet or 0) % 3
  if known and most >= 3 and most * 2 >= f.done and n - (known.said or 0) >= gap then
    -- ("as ever" once it has been named so)
    if
      more(
        sayFresh(
          "d-pet",
          "pet",
          { pet = pet, where = known.fell and at(known.fell) },
          { demon = f.demons[pet] or nil, again = known.said and true or nil, fell = known.fell and true or nil },
          nil,
          known.fell and { fell = true } or nil
        ),
        false,
        LATE + 1
      )
    then
      known.said, known.fell = n, nil
    end
  end
  for name in pairs(f.pets) do
    d.pets[name] = d.pets[name] or {}
  end

  -- the small work, only when nothing else was told
  local rest = (ch.quests or 0) - #story
  if rest >= 3 and events == 0 and #out <= 2 then
    add(sayFresh("d-chores", "chores", {}, { after = #out > 1 or nil }), false, LATE + 2) -- ("the rest of it": after something)
  end

  -- the town I rested in, the first time: its description, before the rest
  if e and e.how ~= "death" and e.place then
    local last = ch.log and ch.log[#ch.log]
    scenery(e.place, last and last.night, LATE + 2.5)
  end

  -- how it ends (not after a Hardcore death: the epitaph has the last word):
  -- a thought on a danger (a death, a near thing, a dungeon), else the rest
  if e and e.how ~= "death" then
    -- (a thought on a danger only once other things were told since: right
    -- after its own telling, it would say the same twice)
    local since = 0
    for _, o in ipairs(out) do
      if dangerAt and o.at > dangerAt then since = since + 1 end
    end
    local shape = {
      hard = (#f.deaths > 0 and since >= 3) or nil,
      near = (#f.deaths == 0 and #f.closes > 0 and since >= 3) or nil,
      delve = below ~= nil or nil,
    }
    local prefer
    for _, k in ipairs({ "hard", "near", "delve" }) do
      if shape[k] then
        prefer = { [k] = true }
        break
      end
    end
    owned = math.min(owned, 1) -- (the ending may always be the race's own)
    if prefer then
      add(sayFresh("d-close", "close", { land = f.main and mid(f.main) }, shape, nil, prefer), false, LATE + 3)
    else
      b.last = nil
      if e.how == "long" then
        add(
          sayFresh(e.inside and "night-in" or "night", "last", here({}, e.place), { night = true }, e.zone),
          false,
          LATE + 3
        )
      elseif e.how == "summit" then
        add(sayFresh("summit", "last", here({ level = words(e.level or 60) }, e.place), {}, e.zone), false, LATE + 3)
      elseif
        ending
        and add(
          sayFresh(
            "d-camp",
            "camp",
            here({
              mates = ending.m.with and listing(ending.m.with) or nil,
            }, e.place),
            {
              last = true,
              company = ending.m.with and true or nil,
              one = ending.m.with and #ending.m.with == 1 or nil,
              camp = ending.m.camp or nil,
              first = not d.fireSeen or nil,
            },
            e.zone
          ),
          false,
          LATE + 3
        )
      then
        d.fireSeen, d.fireAt = true, n -- (the fire the entry ends at)
      elseif not (storyTold and n % 3 == 2 and #out >= 4 and storyLast()) then -- (one entry in three ends on its story)
        add(
          sayFresh("rest", "last", here({ place = mid(e.place) }, e.place), {
            fire = e.how == "campfire" or nil,
          }, e.zone),
          false,
          LATE + 3
        )
      end
    end
  end
  d.lastPlace, d.lastZone = e and e.place, e and e.zone
  table.sort(out, function(x, y)
    if x.at ~= y.at then return x.at < y.at end
    return x.seq < y.seq
  end)
  -- (a second story's place, just named by the sentence before: not again)
  for k, o in ipairs(out) do
    local place = o.where and o.where:gsub("^%a+ ", "")
    if place and k > 1 and out[k - 1].text:find(place, 1, true) then
      o.text = o.text:gsub(", " .. o.where:gsub("%p", "%%%0") .. ",", ",", 1)
    end
  end
  -- (a long entry in two paragraphs, at the middle: what happened, then the rest)
  local texts, split = {}, #out >= PARAGRAPH and math.ceil(#out / 2) or nil
  if split and out[split + 1] and out[split + 1].follows then split = split + 1 end
  for k, o in ipairs(out) do
    texts[#texts + 1] = o.text
    if k == split then texts[#texts + 1] = "\n\n" end
  end
  -- the title: the weightiest moment not already a title, else where it was
  headline(9, f.main or start.zone or where)
  table.sort(heads, function(x, y)
    if x.rank ~= y.rank then return x.rank < y.rank end
    return x.seq < y.seq
  end)
  local title -- (none rather than one an earlier entry has)
  for _, h in ipairs(heads) do
    if not d.titled[h.title] then
      title = h.title
      break
    end
  end
  if title then d.titled[title] = true end
  return (table.concat(texts, " "):gsub(" \n\n ", "\n\n")), title
end

-- The book of a character, as read in the game and on the site, written
-- from its records each time it is read (never stored but in the saved
-- file, Save.lua): { prologue (a character met mid-life), chapters = { {
-- number, text (its diary entry), title, place, from, to (levels), open,
-- rare, close (the book's marks), chapter (its record); the player's own:
-- note, a title given it (writtenTitle: the writer's) } }, epitaph (a
-- Hardcore death) }.
-- (the finished entries of a book, kept with the book's memory after the
-- last of them: a long life is not rewritten from its first page every time
-- a page is turned. Every chapter but the last is finished: a logout under
-- half an hour may reopen the last one. Kept per record, while it lives.)
-- (a weak key alone doesn't let a record go: Lua 5.1's weak tables are no
-- ephemerons, so a memory that pointed back at its record would keep it
-- alive. The record is kept in it as RECORD, put back when read.)
local kept = setmetatable({}, { __mode = "k" })
local RECORD = {}
local function snapshot(v, shared, seen)
  if type(v) ~= "table" or shared[v] then return v end
  if seen[v] then return seen[v] end
  local out = {}
  seen[v] = out
  for k, x in pairs(v) do
    out[snapshot(k, shared, seen)] = snapshot(x, shared, seen)
  end
  return setmetatable(out, getmetatable(v))
end
local function sharedOf(c, own)
  -- (the record's chapters and the game's data are read, never copied)
  local shared = {}
  for _, t in ipairs({ ns.data, ns.names, ns.knowledge, own, c.chapters }) do
    if t then shared[t] = true end
  end
  return shared
end
local function stillKept(memo, c)
  if memo.n >= #(c.chapters or {}) then return false end
  for i = 1, memo.n do
    local ch, was = c.chapters[i], memo.marks[i]
    if ch ~= was.ch or #(ch.log or {}) ~= was.len or ch.ended ~= was.ended then return false end
  end
  return true
end

function ns.writeBook(c)
  local memo = kept[c]
  local d, book, from
  if memo and stillKept(memo, c) then
    d = snapshot(memo.d, sharedOf(c, memo.d.book.own), { [RECORD] = c })
    book = { chapters = {}, prologue = memo.prologue }
    for i = 1, memo.n do
      book.chapters[i] = memo.chapters[i]
    end
    from = memo.n + 1
  else
    d = {
      c = c,
      book = newBook(c, true),
      lands = {},
      known = {},
      ways = {},
      toldFoes = {},
      mates = {},
      storied = {}, -- [quest id]: its story told
      reacted = {}, -- [text]: a word on a story, said
      initiated = {}, -- [element]: a shaman's initiation told
      called = {}, -- [a class's defining spell, its tag]: learned, told
      titled = {}, -- [title]: an entry's already
      reactedAt = -REACT_GAP,
      threads = {}, -- [a chain's first quest] = { n, giver, ender }: the last entry that told one of it
      pets = {}, -- [name] = { said = the last entry that named it }: a pet met before
      summoned = {}, -- [a demon's kind] = the entry a class quest taught its summoning
      revivers = {}, -- [a name] = { n, place }: who brought me back from death, until met again
      dangers = {}, -- [a foe of a name] = { n, place, died }: who killed me or nearly did, until beaten
      began = {}, -- [a trade] = where I took it up, until its first new rank
      made = {}, -- [a thing]: made before, no news
      ended = {}, -- [a foe of a name]: its end told by a story
      madeAt = -MADE_GAP, -- the last entry that told what my hands made
      -- (a journal begun after the life's first steps: no land, no city told as
      -- seen for the first time, the record can't know it)
      late = (c.began and c.began.level or 1) > 1,
    }
    -- (late: nor a first fire, a first flight, a first ground below the islands)
    if d.late then
      d.away, d.fireSeen, d.flown = true, true, true
    end
    d.book.ownGap = 18 -- (one line a kind an entry: the race's own come back later than a chapter's)
    for _, way in ipairs(CLASS_FIGHT[c.class or ""] or {}) do
      d.ways[way] = true
    end
    for _, sp in ipairs(FIRST_SPELLS[c.class or ""] or {}) do
      d.known[sp] = true
    end
    local capital = CAPITAL[c.race or ""]
    if capital then d.lands[capital] = true end
    book = { chapters = {} }
    if c.prologue then book.prologue = d.book:prologue(c.prologue) end
    from = 1
  end
  -- (the trades: a skill of one at 300 is news, a weapon's is not)
  d.trades = {}
  for _, known in ipairs({ c.profs or {}, c.dropped or {} }) do
    for name in pairs(known) do
      if not name:find("Riding") then d.trades[name] = true end
    end
  end
  local chapters = c.chapters or {}
  for i = from, #chapters do
    local ch = chapters[i]
    local start, e = ch.start or {}, ch.ended
    local rare, close, to = nil, nil, start.level or 1
    for _, m in ipairs(ch.log or {}) do
      if m.k == "rare" then rare = true end
      if m.k == "close" then close = true end
      if m.k == "level" then to = m.level end
    end
    if e and e.level then to = math.max(to, e.level) end
    local text, title = entry(d, i, ch)
    book.chapters[i] = {
      number = i,
      text = text,
      title = title,
      chapter = ch,
      place = (e and e.place) or start.sub or start.zone, -- (where it was written, or where it goes on)
      from = start.level or 1,
      to = to,
      open = not e or nil,
      rare = rare,
      close = close,
    }
    -- (the last finished one: kept, with the book's memory after it)
    if i == #chapters - 1 and e then
      local finished = true
      for k = 1, i do
        if not chapters[k].ended then finished = false end
      end
      if finished then
        local marks, written = {}, {}
        for k = 1, i do
          marks[k] = { ch = chapters[k], len = #(chapters[k].log or {}), ended = chapters[k].ended }
          written[k] = book.chapters[k]
        end
        kept[c] = {
          n = i,
          d = snapshot(d, sharedOf(c, d.book.own), { [c] = RECORD }),
          chapters = written,
          prologue = book.prologue,
          marks = marks,
        }
      end
    end
  end
  if c.hardcore and c.death then book.epitaph = d.book:epitaph(c) end
  -- the player's own, laid over the written book (which never changes): a
  -- title given an entry (the writer's kept as writtenTitle), a note in its
  -- margin (c.notes[n] = { title, text }, Core.lua)
  for n, own in pairs(c.notes or {}) do
    local ch = type(own) == "table" and book.chapters[n]
    if ch then
      local copy = {}
      for k, v in pairs(ch) do
        copy[k] = v
      end
      copy.writtenTitle, copy.title, copy.note = ch.title, own.title or ch.title, own.text
      book.chapters[n] = copy
    end
  end
  return book
end
