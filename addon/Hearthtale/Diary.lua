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
local FIRSTS =
  { demon = true, shift = true, tame = true, mount = true, riding = true, power = true, bag = true, gold = true }
-- (how much each telling weighs: milestones and the story always told, then
-- what happened that a life remembers, then what fills the room left)
local MILESTONE = { demon = true, shift = true, tame = true, power = true, ["class-reward"] = true, initiation = true }
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
-- place the game names (Names.lua: "Skull Rock", "the Deadmines"); it then
-- takes no other place before it ("In Orgrimmar, I seized … in Skull Rock").
local function namesPlace(text, zone)
  if zone and text:lower():find((zone:lower():gsub("^the ", "")), 1, true) then return true end
  local the, bare = ns.names and ns.names.placeThe or {}, ns.names and ns.names.placeBare or {}
  local parts = {}
  for part in text:gmatch("[%w'%-]+") do
    table.insert(parts, part)
  end
  for i = 1, #parts do
    local name = parts[i]
    for j = i, math.min(i + 4, #parts) do
      if j > i then name = name .. " " .. parts[j] end
      if name:find("^%u") and (the[name] or bare[name]) then return true end
    end
  end
  return false
end
local function SUBJECT(text, objectives, kinds)
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
      -- (a people of note to the narrator: their own irradiated kin, their
      -- forebears, Cenarius's own)
      local people = W.foeOf(o.name, kind)
      if people == "leper" or people == "highborne" or people == "cenarion" then return people end
      if kind == "Undead" then return "undead" end
      if kind == "Demon" then return "demon" end
      if bare[o.name] and foes == 1 then return kind == "Beast" and "beast" or "villain" end
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
    fires = {}, -- the stops by a campfire
    titles = {}, -- [quest id]: its title, as the game gives it
    raids = {},
    petdied = {},
  }
  local seenMate, seenSpell, seenDungeon, dungeon = {}, {}, {}, nil
  local bare = ns.names and ns.names.creatureBare or {}
  local log = ch.log or {}
  local capital = CAPITAL[c.race or ""]
  local level = ch.start and ch.start.level or 1
  local looted = {} -- [an item's id]: found in this stretch
  for i, m in ipairs(log) do
    f.at[m] = i
    if m.k == "level" and m.level then level = m.level end
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
    elseif FIRSTS[m.k] or (m.k == "prof" and m.learned) then -- (a trade taken up)
      table.insert(f.firsts, m)
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

-- The stretch's story: the quests whose work weighed most (writing/why/:
-- what each was for, weighed 1 to 3), the heaviest first, of two alike the
-- one whose work was done here (a deed over a delivery), then the later;
-- the first if it was more than an errand, a second if a climax too and
-- both read well in one sentence.
local function storyOf(d, ch, f, thin)
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
      table.insert(
        all,
        { id = m.id, w = why[1], text = why[2], i = i, deed = deed, mine = mine, zone = w.zone or m.zone }
      )
    end
  end
  table.sort(all, function(x, y)
    if x.w ~= y.w then return x.w > y.w end
    if x.mine ~= y.mine then return x.mine end
    if x.deed ~= y.deed then return x.deed end
    return x.i > y.i
  end)
  local told = {}
  -- (an errand with a reason, when the stretch has nothing else to tell)
  if all[1] and (all[1].w >= 2 or thin) then told[1] = all[1] end
  if told[1] and all[2] and told[1].w == 3 and all[2].w == 3 then told[2] = all[2] end
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
  local story = storyOf(d, ch, f, thin)
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
    elseif m.k == "calling" then
      text = sayFresh(
        "d-calling",
        key,
        { spell = m.spell, place = m.spell:match("^Teleport: (.+)$") or m.spell:match("^Portal: (.+)$") },
        { [m.tag] = true },
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
      headline(
        1,
        (m.k == "tame" or m.k == "demon") and m.name
          or m.k == "shift" and FORM_TITLE[m.form or ""]
          or m.k == "initiation" and questTitle(m.m.title)
          or m.k == "class-reward" and (questTitle(m.m.title) or m.q.spell)
          or m.spell
      )
    end
  end

  -- the story of the stretch: the deed that mattered, told as done ("I
  -- killed Hogger, …"); a chain's quest after a recent entry told one of it
  -- by the same people, the business taken up again, or finished; a second
  -- climax in the same sentence when both are short, else its own; and, now
  -- and then, a word on what it was (a rescue, a villain's end, the dead)
  local chains, ends = ns.knowledge and ns.knowledge.chains or {}, ns.knowledge and ns.knowledge.ends or {}
  local also
  local storyTold = false
  local storied = {} -- (the stories told: a boss whose end one tells isn't told again)
  if #story > 0 then
    local text
    local why = ours(story[1].text, race)
    local sameVerb = story[2] and story[1].text:match("^(%S+)") == story[2].text:match("^(%S+)")
    if #story == 2 and #story[1].text + #story[2].text <= PAIR and not sameVerb then
      text = sayFresh("d-why2", "why", { why = why, why2 = ours(story[2].text, race) }, {})
    else
      also = story[2]
      local q = story[1]
      local root = chains[q.id]
      local before = root and d.threads[root]
      local w = f.work[q.id] or {}
      local thread = before
        and before.n < n
        and before.n >= n - 4
        and w.giver
        and (w.giver == before.giver or w.giver == before.ender)
      local t = thread and { thread = true, settled = ends[q.id] or nil } or {}
      local prefer = thread and (t.settled and { settled = true } or { thread = true }) or nil
      text = sayFresh("d-why", "why", { why = why }, t, nil, prefer)
    end
    if text and lead then
      -- ("I" stays a capital after the place: "In Loch Modan, I killed …")
      local rest = text:find("^I[ ']") and text or lowerFirst(text)
      text = lead:gsub("^%l", string.upper) .. ", " .. rest
    end
    local told = add(text, true, first0 or story[1].i)
    storyTold = told
    if told then
      table.insert(storied, story[1].text)
      if not also and story[2] then table.insert(storied, story[2].text) end
    end
    if also then
      -- (somewhere else than the first: "Later, in Darkshore, I …")
      local moved = also.zone and also.zone ~= storyZone and not namesPlace(also.text, also.zone)
      local where2 = moved and at(also.zone) or nil
      if
        add(
          say("d-why-also", "also", { why = ours(also.text, race), where = where2 }, { moved = moved or nil }),
          false,
          also.i
        )
      then
        out[#out].where = where2
        table.insert(storied, also.text)
      end
    end
    -- (what it was, a word on it: now and then, never the same twice)
    local subject = told and SUBJECT(story[1].text, (f.work[story[1].id] or {}).objectives, f.kinds)
    if told then headline(subject and 2 or 5, questTitle(f.titles[story[1].id])) end
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
        out[#out].follows = true -- (never the first of a paragraph)
      end
    end
  end
  for _, q in ipairs(story) do
    d.storied[q.id] = true -- (its work done here, its return in the next: told once)
    local root = chains[q.id]
    local w = f.work[q.id] or {}
    if root then d.threads[root] = { n = n, giver = w.giver, ender = w.ender } end
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
  elseif #f.closes > 0 then
    local worst = f.closes[1]
    for _, m in ipairs(f.closes) do
      if (m.hp or 100) < (worst.hp or 100) then worst = m end
    end
    if worst.foe then deathFoes[worst.foe] = true end -- (told there, not again among the foes)
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
    local when = f.away.i
    for _, q in ipairs(story) do
      if q.zone == ZEPHRAS and q.i > when then when = q.i + 0.1 end
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

  -- in the room left (less for each milestone, never none): the foes worth
  -- naming, new lands, lessons and new ways of fighting, company, a trade
  -- taken up, a ride, the first bag or gold, the pet named again
  local room = math.max(1, ROOM - #out - milestones)
  local function more(text, event, when)
    if lesser >= room then return false end
    if add(text, event, when) then
      lesser = lesser + 1
      return true
    end
    return false
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
  if #named > 0 then
    local told = more(
      sayFresh("d-land", "land", { lands = listing(named) }, {
        one = #named == 1 or nil,
        town = (#named == 1 and W.CITIES[lands[1]]) or nil,
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

  -- what I can do now: a spell with a line of its own (two at most, in the
  -- entry it was learned), else a new way of fighting (a noted spell's way is
  -- no news after it)
  local fighting, notes, newWay = {}, {}, false
  for _, sp in ipairs(f.spells) do
    local way = ELEMENT[sp]
    if hasNote(sp, b) and not b.noted[sp] then
      b.noted[sp] = true
      if #notes < 2 then table.insert(notes, sp) end
      if way then d.ways[way] = true end
    elseif way and not d.ways[way] then
      d.ways[way], newWay = true, true
      table.insert(fighting, sp)
    end
  end
  for k, note in ipairs(notes) do
    more(
      say("lesson", "lesson" .. k, { spell = note }, { ["spell:" .. note:gsub(" ", "_")] = true }),
      false,
      f.spellAt[note]
    )
  end
  if newWay and #notes == 0 then
    local spells = {}
    for k = 1, math.min(#fighting, 3) do
      spells[k] = fighting[k]
    end
    -- (put to use already in its stretch: a quest's foes fought after it)
    local used, fought = false, false
    for i = (f.spellAt[spells[1]] or 0) + 1, #(ch.log or {}) do
      local m = ch.log[i]
      if m.k == "kill" then fought = true end
      if m.k == "done" then
        for _, o in ipairs(m.objectives or {}) do
          if o.type == "monster" or (o.type == "item" and fought) then used = true end
        end
      end
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

  -- company (not when the dungeon told it)
  if not below and #mates > 0 then
    local again = true
    for _, mate in ipairs(mates) do
      if not d.mates[mate] then again = false end
      d.mates[mate] = true
    end
    more(
      say("d-company", "company", { mates = listing(mates) }, { one = #mates == 1 or nil, again = again or nil }),
      false,
      f.mateAt[mates[1]]
    )
  end

  -- the lesser firsts: a trade taken up, a ride, the first bag, the first gold
  for k, m in ipairs(f.firsts) do
    if not MILESTONE[m.k] then
      local key, text = "small" .. k, nil
      if m.k == "prof" then
        for try = 1, 4 do
          local clause = b:say(
            "c-prof",
            n .. "|diary|" .. key .. (try > 1 and try or ""),
            { prof = m.name:lower() },
            tags({ new = true, one = true }),
            nil,
            true
          )
          text = clause and ("I " .. clause .. ".")
          if text then break end
        end
      else
        -- (the first bag: what it is, its room; the first mount: which)
        local item = m.k == "bag" and m.link and m.link:match("%[(.-)%]")
        local values = {
          item = item and W.itemName(item),
          slots = m.slots and words(m.slots),
          mount = m.k == "mount" and m.name and m.name:lower() or nil,
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
        sayFresh("d-pet", "pet", { pet = pet }, { demon = f.demons[pet] or nil, again = known.said and true or nil }),
        false,
        LATE + 1
      )
    then
      known.said = n
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
    local shape = {
      hard = #f.deaths > 0 or nil,
      near = (#f.deaths == 0 and #f.closes > 0) or nil,
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
      elseif not (storyTold and n % 3 == 2 and #out >= 4) then -- (one entry in three ends on its story)
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
-- number, text (its diary entry), place, from, to (levels), open, rare,
-- close (the book's marks), chapter (its record) } }, epitaph (a Hardcore
-- death) }.
function ns.writeBook(c)
  local d = {
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
  }
  d.book.ownGap = 18 -- (one line a kind an entry: the race's own come back later than a chapter's)
  for _, way in ipairs(CLASS_FIGHT[c.class or ""] or {}) do
    d.ways[way] = true
  end
  for _, sp in ipairs(FIRST_SPELLS[c.class or ""] or {}) do
    d.known[sp] = true
  end
  local capital = CAPITAL[c.race or ""]
  if capital then d.lands[capital] = true end
  local book = { chapters = {} }
  if c.prologue then book.prologue = d.book:prologue(c.prologue) end
  for i, ch in ipairs(c.chapters or {}) do
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
  end
  if c.hardcore and c.death then book.epitaph = d.book:epitaph(c) end
  return book
end
