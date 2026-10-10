-- The rest of a life: company and dungeons, what was learned (spells,
-- powers, trades, riding), what was made, worn and found, a hunter's pets,
-- the first ride, the money. (Record.lua keeps the chapters; this file adds
-- their moments.)
local _, ns = ...
local R, secret = ns.record, ns.secret
local char, now, changed, moment, chapter, match = R.char, R.now, R.changed, R.moment, R.chapter, R.match
local itemInfo, LINK, playerName = R.itemInfo, R.LINK, R.playerName
-- ── company and dungeons ─────────────────────────────────────────────────────
local inRaid = false
ns.on("GROUP_ROSTER_UPDATE", function()
  local ch = chapter()
  ch.company = ch.company or {}
  local n, raid = GetNumGroupMembers(), IsInRaid()
  if secret(n) or secret(raid) then return end
  -- a raid: one moment, its number, not forty names
  if raid then
    if not inRaid then moment("group", { raid = n }) end
    inRaid = true
    return
  end
  inRaid = false
  -- a party: each one who joined, once (party1 to party4: the others)
  for i = 1, n - 1 do
    local unit = "party" .. i
    local name, first = playerName(UnitName(unit))
    if name and name ~= char().name and not ch.company[name] then
      ch.company[name] = true
      moment("group", { name = name, first = first ~= name and first or nil, class = select(2, UnitClass(unit)) })
    end
  end
end)
local lastDungeon
ns.on("PLAYER_ENTERING_WORLD", function()
  local inside, kind = IsInInstance()
  if not inside or (kind ~= "party" and kind ~= "raid") then return end
  local name = GetInstanceInfo()
  if not name or secret(name) then return end
  if lastDungeon and lastDungeon.name == name and now() - lastDungeon.at < 3600 then return end
  lastDungeon = { name = name, at = now() }
  moment("dungeon", { name = name })
end)
ns.on("ENCOUNTER_END", function(_, encounterName, _, _, success)
  if success == 1 and encounterName and not secret(encounterName) then moment("boss", { name = encounterName }) end
end)

-- ── learning and spoils ──────────────────────────────────────────────────────
-- Spells learned, read from the game's message (any language); the spell's
-- id, from its link, says what it is: a druid's new form, a warlock's new
-- demon, a class's own steed (a moment of their own); a profession's rank (told
-- by the professions, below: left out here); anything else, a trainer's
-- lesson (spells learned together are one moment).
-- A class's own steed: a moment of its own when learned.
local STEEDS = { [5784] = true, [23161] = true, [13819] = true, [23214] = true, [34769] = true, [34767] = true }
local POWERS, TRADE = ns.POWER_SPELLS, ns.TRADE_SPELLS
local RANKED = { Apprentice = true, Journeyman = true, Expert = true, Artisan = true, Master = true }
-- A lesson put to use: the first cast of a spell learned in the chapter still
-- being written, kept on its lesson's moment (used = { spell, ... }); the
-- journal says a spell was used only then. (A closed chapter never changes.)
local untried = {} -- [a spell's name] = { m = its lesson's moment, ch = its chapter }
local function spellName(id)
  local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  local name = get and get(id)
  return (name and not secret(name)) and name or nil
end
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, id)
  if not id or secret(id) or next(untried) == nil then return end
  local name = spellName(id)
  local lesson = name and untried[name]
  if not lesson then return end
  untried[name] = nil
  local chapters = char().chapters or {}
  if chapters[#chapters] ~= lesson.ch or lesson.ch.ended then return end
  lesson.m.used = lesson.m.used or {}
  table.insert(lesson.m.used, name)
  changed()
end)
-- (at login, or after a reload: the lessons of the chapter still open, not
-- yet put to use)
local function lookAtLessons()
  local chapters = char().chapters or {}
  local ch = chapters[#chapters]
  if not ch or ch.ended then return end
  for _, m in ipairs(ch.log or {}) do
    if m.k == "learned" then
      local used = {}
      for _, sp in ipairs(m.used or {}) do
        used[sp] = true
      end
      for _, sp in ipairs(m.spells or {}) do
        if not used[sp] then untried[sp] = { m = m, ch = ch } end
      end
    end
  end
end
ns.on("PLAYER_ENTERING_WORLD", lookAtLessons)
local function professionSpell(name)
  if TRADE[name] or (char().profs or {})[name] then return true end
  local first = name:match("^(%a+) ")
  return first and RANKED[first] or false
end
ns.on("CHAT_MSG_SYSTEM", function(msg)
  if secret(msg) then return end
  for _, g in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S" }) do
    local raw = match(g, msg)
    if raw then
      local id = tonumber(raw:match("|Hspell:(%d+)"))
      local spell = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", "%1")
      if id and STEEDS[id] then
        moment("power", { spell = spell, kind = "steed" })
      elseif POWERS[spell] then
        local c = char()
        c.powers = c.powers or {}
        c.powers[spell] = true
      elseif not professionSpell(spell) then
        -- a trainer's visit is one moment: spells learned together merge
        local ch = chapter()
        local last = ch.log[#ch.log]
        if last and last.k == "learned" and now() - last.at < 120 then
          table.insert(last.spells, spell)
          changed()
        else
          last = moment("learned", { spells = { spell } })
        end
        untried[spell] = { m = last, ch = ch }
      end
      return
    end
  end
end)
local MILESTONES =
  { [50] = true, [75] = true, [100] = true, [150] = true, [200] = true, [225] = true, [250] = true, [300] = true }
ns.on("CHAT_MSG_SKILL", function(msg)
  if secret(msg) then return end
  local skill, rank = match("SKILL_RANK_UP", msg)
  rank = tonumber(rank)
  if skill and rank and MILESTONES[rank] then moment("skill", { name = skill, rank = rank }) end
end)

-- ── professions ──────────────────────────────────────────────────────────────
-- What the character knows of its trades: profs[name] = the rank's ceiling
-- (75 apprentice, 150 journeyman, 225 expert, 300 artisan, 375 master). A new
-- trade, a new rank, a trade given up or taken up again is a moment; riding
-- is one too. Those known when the journal first looks are noted quietly.
-- (A trade is given up when the whole list no longer has it: a header folded
-- in the skills pane hides its trades, and then nothing is given up.)
local RANK_OF = { [75] = "apprentice", [150] = "journeyman", [225] = "expert", [300] = "artisan", [375] = "master" }
local function trades()
  local out, whole = {}, true
  if GetNumSkillLines and GetSkillLineInfo then
    if GetNumSkillLines() == 0 then return nil end -- not loaded yet (there are always weapons, languages)
    local section
    for i = 1, GetNumSkillLines() do
      local name, header, expanded, _, _, _, max = GetSkillLineInfo(i)
      if header then
        section = name
        if not expanded then whole = false end
      elseif
        name
        and not secret(name)
        and (section == TRADE_SKILLS or section == SECONDARY_SKILLS or name:find("Riding"))
      then
        out[name] = max or 0
      end
    end
  elseif GetProfessions and GetProfessionInfo then
    for _, index in ipairs({ GetProfessions() }) do
      local name, _, _, max = GetProfessionInfo(index)
      if name and not secret(name) then out[name] = max or 0 end
    end
  end
  return out, whole
end
local function sorted(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end
local function lookAtTrades(quiet)
  local c = char()
  local list, whole = trades()
  if not list then return end
  local known = c.profs
  c.profs = c.profs or {}
  for _, name in ipairs(sorted(list)) do
    local max, before = list[name], c.profs[name]
    c.profs[name] = max
    if known and not quiet then
      if name:find("Riding") and not before then
        moment("riding", { name = name })
      elseif not before then
        moment("prof", { name = name, learned = true, again = (c.dropped or {})[name] })
      elseif max > before and RANK_OF[max] then
        moment("prof", { name = name, rank = RANK_OF[max] })
      end
    end
  end
  if known and not quiet and whole then
    for _, name in ipairs(sorted(c.profs)) do
      if not list[name] and not name:find("Riding") then
        c.profs[name] = nil
        c.dropped = c.dropped or {}
        c.dropped[name] = true
        moment("prof", { name = name, dropped = true })
      end
    end
  end
end
ns.on("SKILL_LINES_CHANGED", function() lookAtTrades(false) end)

-- ── a specialization ─────────────────────────────────────────────────────────
-- The way a life took, by its name as the game gives it ("Fire",
-- "Protection"): the specialization chosen, on today's client (Forever);
-- on Classic's, the talent tree holding most of the points (ten at least,
-- more than half of them). Never the talents themselves. A new one is a
-- moment (spec { name, was }); one held when the journal first looks is
-- noted quietly; talents unlearned, none for a while, is no change.
local SPEC_POINTS = 10
local function specOf()
  local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local info = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  if get and info then
    local index = get()
    if index and not secret(index) and index > 0 then
      local _, name = info(index)
      if name and not secret(name) then return name end
    end
  end
  if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
  local best, most, all = nil, 0, 0
  for i = 1, GetNumTalentTabs() or 0 do
    -- (Classic Era's: name, icon, points; later clients': id, name, text, icon, points)
    local a, b, c, _, e = GetTalentTabInfo(i)
    local name, points = a, c
    if type(a) == "number" then
      name, points = b, e
    end
    if type(name) == "string" and type(points) == "number" and not secret(name) and not secret(points) then
      all = all + points
      if points > most then
        best, most = name, points
      end
    end
  end
  if best and most >= SPEC_POINTS and most * 2 > all then return best end
  return nil
end
local function lookAtSpec(quiet)
  local c = char()
  local spec = specOf()
  if quiet then
    c.spec = spec or false
  elseif spec and spec ~= c.spec then
    moment("spec", { name = spec, was = c.spec or nil })
    c.spec = spec
  end
end
for _, e in ipairs({
  "CHARACTER_POINTS_CHANGED",
  "PLAYER_TALENT_UPDATE",
  "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
}) do
  ns.on(e, function() lookAtSpec(char().spec == nil) end)
end

-- ── gear ─────────────────────────────────────────────────────────────────────
-- Something worn for the first time (green and above; an item put on again,
-- after another, is no news). worn[itemId] = true; made[itemId] = true for
-- what the character crafted ("You create: ..."), told as such when put on.
-- The weapon in hand (a hunter's: the bow or gun), by its kind (the game's
-- weapon subclass: 7 a sword, 10 a staff...), whatever its quality: a moment
-- no sentence tells, for the writer's "my sword" rather than one by race.
local function lookAtWeapon(c)
  local get = C_Item and C_Item.GetItemInfoInstant
  local link = get and GetInventoryItemLink("player", c.class == "HUNTER" and 18 or 16)
  if not link or secret(link) then return end
  local _, _, _, _, _, classID, subclassID = get(link)
  if classID ~= 2 or not subclassID or secret(subclassID) or c.weapon == subclassID then return end
  c.weapon = subclassID
  moment("weapon", { weapon = subclassID })
end
local function lookAtGear(quiet)
  local c = char()
  lookAtWeapon(c)
  c.worn = c.worn or {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    local id = link and not secret(link) and tonumber(link:match("item:(%d+)"))
    if id and not c.worn[id] then
      c.worn[id] = true
      local _, quality = itemInfo(link)
      if not quiet and quality and quality >= 2 then
        -- (in hand: a weapon, a shield, a bow, taken up rather than put on; a
        -- trinket, carried rather than worn)
        moment("gear", {
          link = link,
          quality = quality,
          made = (c.made or {})[id] or nil,
          held = slot >= 16 or nil,
          trinket = (slot == 13 or slot == 14) or nil,
        })
      end
    end
  end
end
ns.on("PLAYER_EQUIPMENT_CHANGED", function() lookAtGear(char().worn == nil) end) -- the first look is quiet

-- Loot: a find of note (blue and above; the green ones are told when worn).
-- Only what is looted: an item received (a quest's reward, a purchase) is
-- no find, and is told when worn, if it is.
ns.on("CHAT_MSG_LOOT", function(msg)
  if secret(msg) then return end
  local c = char()
  for _, g in ipairs({ "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do -- (the counted form first: the other matches it too)
    local found, many = match(g, msg)
    local link = found and msg:match(LINK)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then
      c.made = c.made or {}
      c.made[id] = true
      -- what was made: one moment while the same thing keeps coming
      local count = tonumber(many) or 1
      local log = chapter().log
      local last = log[#log]
      if last and last.k == "made" and last.id == id and now() - last.at < 600 then
        last.n, last.at = last.n + count, now()
        changed()
      else
        moment("made", { id = id, link = link, n = count })
      end
      return
    end
  end
  local mine = false
  for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE" }) do
    if match(g, msg) then mine = true end
  end
  local link = mine and msg:match(LINK)
  if not link then return end
  local _, quality = itemInfo(link)
  if quality and quality >= 3 then moment("loot", { link = link, quality = quality }) end
end)

-- ── pets, demons, forms, a first ride ────────────────────────────────────────
-- A hunter's new companion (a pet not met before, by name), and its deaths;
-- a warlock's first demon of each kind, by its name; a druid's first shift
-- into each form; the first time the character rides a mount of its own.
-- (A demon or a form the journal saw learned: one known before it began is
-- no first.)
local petDown = false
local function lookAtDemon()
  local c = char()
  if not UnitExists("pet") then return end
  local name, family = UnitName("pet"), UnitCreatureFamily("pet")
  if not name or secret(name) or not family or secret(family) then return end
  c.demons = c.demons or {}
  if c.demons[family] or not (c.powers or {})["Summon " .. family] then return end
  c.demons[family] = name
  moment("demon", { name = name, family = family })
end

-- (a pet is tamed when it answers soon after a Tame Beast; one new to the
-- journal otherwise came from the stable, tamed before the journal began:
-- noted quietly. Renamed soon after its taming, the taming takes its name.)
local TAME_BEAST, TAMING = 1515, 300
local tamedAt, tamed -- the last Tame Beast cast; the taming it told
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, spell)
  if spell and not secret(spell) and spell == TAME_BEAST then tamedAt = now() end
end)
local function lookAtPet(quiet)
  local c = char()
  if c.class == "WARLOCK" then return lookAtDemon() end
  if c.class ~= "HUNTER" then return end
  if not UnitExists("pet") then
    c.pets = c.pets or {} -- no pet yet: the first one tamed is news
    return
  end
  local name, family = UnitName("pet"), UnitCreatureFamily("pet")
  if not name or secret(name) then return end
  c.pets = c.pets or {}
  if not c.pets[name] then
    c.pets[name] = (family and not secret(family)) and family or true
    local fresh = not quiet and tamedAt and now() - tamedAt <= TAMING
    local kind = c.pets[name] ~= true and c.pets[name] or nil
    if fresh and tamed and tamed.at >= tamedAt and tamed.family == kind then
      tamed.name = name -- (its new name)
    elseif fresh then
      tamed = moment("tame", { name = name, family = kind })
    end
  end
end
ns.onUnit("UNIT_PET", "player", function() lookAtPet(char().pets == nil) end)
ns.onUnit("UNIT_HEALTH", "pet", function()
  if char().class ~= "HUNTER" then return end
  local dead = UnitIsDead("pet")
  if secret(dead) then return end
  if dead and not petDown then
    local name = UnitName("pet")
    moment("petdied", { name = (name and not secret(name)) and name or nil })
  end
  petDown = dead and true or false
end)
-- (GetShapeshiftFormID's forms)
local FORMS = {
  [1] = "cat",
  [2] = "tree",
  [3] = "travel",
  [4] = "aquatic",
  [5] = "bear",
  [8] = "bear",
  [27] = "flight",
  [29] = "flight",
  [31] = "moonkin",
  [35] = "moonkin",
}
local FORM_SPELL = {}
for spell, form in pairs(POWERS) do
  FORM_SPELL[form] = FORM_SPELL[form] or {}
  table.insert(FORM_SPELL[form], spell)
end
ns.on("UPDATE_SHAPESHIFT_FORM", function()
  local c = char()
  if c.class ~= "DRUID" then return end
  local id = GetShapeshiftFormID()
  local form = id and not secret(id) and FORMS[id]
  if not form then return end
  c.forms = c.forms or {}
  if c.forms[form] then return end
  local learned = false
  for _, spell in ipairs(FORM_SPELL[form] or {}) do
    if (c.powers or {})[spell] then learned = true end
  end
  if not learned then return end
  c.forms[form] = true
  moment("shift", { form = form })
end)

-- (the mount ridden: its aura's name, the game's English, and its kind)
local MOUNT_KINDS = {
  { "Skeletal", "skeletal" },
  { "Mechanostrider", "mechanostrider" },
  { "Ram", "ram" },
  { "saber", "saber" },
  { "Kodo", "kodo" },
  { "Raptor", "raptor" },
  { "Wolf", "wolf" },
  { "Warhorse", "warhorse" },
  { "Charger", "warhorse" },
  { "Felsteed", "felsteed" },
  { "Dreadsteed", "felsteed" },
  { "Horse", "horse" },
  { "Stallion", "horse" },
  { "Mare", "horse" },
  { "Pinto", "horse" },
  { "Palomino", "horse" },
}
local function ridden()
  for i = 1, 40 do
    local name = UnitBuff("player", i)
    if not name then return nil end
    if not secret(name) then
      for _, k in ipairs(MOUNT_KINDS) do
        if name:find(k[1], 1, true) then return name, k[2] end
      end
    end
  end
end
ns.onUnit("UNIT_AURA", "player", function()
  local c = char()
  if c.rode then return end
  local mounted = IsMounted()
  if mounted and not secret(mounted) then
    c.rode = true
    local name, kind = ridden()
    moment("mount", { name = name, kind = kind })
  end
end)

-- ── a first bag, a first gold piece ──────────────────────────────────────────
-- The first bag worn on the back (where it came from, if it was looted: bags
-- are rare at first, and dear to buy); the first gold piece. A journal begun
-- with them already notes them quietly.
local GOLD = 10000 -- copper
local lootedBag -- the last bag looted: its item id
local function bagSlots(bag)
  local get = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local n = get(bag)
  return (n and not secret(n)) and n or 0
end
local function lookAtBags(quiet)
  local c = char()
  if c.bagged then return end
  for bag = 1, 4 do
    local slots = bagSlots(bag)
    if slots > 0 then
      c.bagged = true
      if quiet then return end
      local toSlot = (C_Container and C_Container.ContainerIDToInventoryID) or ContainerIDToInventoryID
      local link = GetInventoryItemLink("player", toSlot(bag))
      local id = link and not secret(link) and tonumber(link:match("item:(%d+)"))
      moment("bag", { link = id and link or nil, slots = slots, looted = (id and id == lootedBag) or nil })
      return
    end
  end
  c.bagged = false
end
ns.on("BAG_UPDATE_DELAYED", function() lookAtBags(char().bagged == nil) end)
-- (a bag looted: noted, for the bag when it is worn)
local CONTAINER = 1 -- an item's class
ns.on("CHAT_MSG_LOOT", function(msg)
  if secret(msg) or not match("LOOT_ITEM_SELF", msg) then return end
  local link = msg:match(LINK)
  local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not (link and get) then return end
  local id, _, _, _, _, class = get(link)
  if class == CONTAINER then lootedBag = id end
end)

-- At login: what the character already wears, knows and keeps, noted quietly
-- (a journal begun mid-life doesn't announce a whole wardrobe).
ns.on("PLAYER_ENTERING_WORLD", function(initial)
  if not initial then return end
  local c = char()
  lookAtGear(c.worn == nil)
  lookAtTrades(c.profs == nil)
  lookAtPet(c.pets == nil)
  lookAtBags(c.bagged == nil)
  lookAtSpec(c.spec == nil)
  -- (riding known when the journal first looks: ridden before it began)
  local rides = IsMounted()
  for name in pairs(c.profs or {}) do
    if name:find("Riding") then rides = true end
  end
  if c.rode == nil and rides then c.rode = true end
  if c.rich == nil then c.rich = GetMoney() >= GOLD end
end)

ns.on("PLAYER_MONEY", function()
  local c, money = char(), GetMoney()
  if c.rich == false and money >= GOLD then
    c.rich = true
    moment("gold")
  end
  if c.money and money > c.money then
    local ch = chapter()
    ch.gold = ch.gold + (money - c.money)
  end
  c.money = money
end)
