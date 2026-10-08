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
local POWERS = {
  [5487] = "form",
  [768] = "form",
  [1066] = "form",
  [783] = "form",
  [9634] = "form",
  [24858] = "form",
  [33943] = "form",
  [697] = "demon",
  [712] = "demon",
  [691] = "demon",
  [1122] = "demon",
  [18540] = "demon",
  [30146] = "demon",
  [5784] = "steed",
  [23161] = "steed",
  [13819] = "steed",
  [23214] = "steed",
  [34769] = "steed",
  [34767] = "steed",
}
local RANKED = { Apprentice = true, Journeyman = true, Expert = true, Artisan = true, Master = true }
local function professionSpell(name)
  if (char().profs or {})[name] then return true end
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
      if id and POWERS[id] then
        moment("power", { spell = spell, kind = POWERS[id] })
      elseif not professionSpell(spell) then
        -- a trainer's visit is one moment: spells learned together merge
        local ch = chapter()
        local last = ch.log[#ch.log]
        if last and last.k == "learned" and now() - last.at < 120 then
          table.insert(last.spells, spell)
          changed()
        else
          moment("learned", { spells = { spell } })
        end
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
-- trade, or a new rank, is a moment; riding is one too. Those known when the
-- journal first looks are noted quietly.
local RANK_OF = { [75] = "apprentice", [150] = "journeyman", [225] = "expert", [300] = "artisan", [375] = "master" }
local function trades()
  local out = {}
  if GetNumSkillLines and GetSkillLineInfo then
    if GetNumSkillLines() == 0 then return nil end -- not loaded yet (there are always weapons, languages)
    local section
    for i = 1, GetNumSkillLines() do
      local name, header, _, _, _, _, max = GetSkillLineInfo(i)
      if header then
        section = name
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
  return out
end
local function lookAtTrades(quiet)
  local c = char()
  local list = trades()
  if not list then return end
  local known = c.profs
  c.profs = c.profs or {}
  for name, max in pairs(list) do
    local before = c.profs[name]
    c.profs[name] = max
    if known and not quiet then
      if name:find("Riding") and not before then
        moment("riding", { name = name })
      elseif not before then
        moment("prof", { name = name, learned = true })
      elseif max > before and RANK_OF[max] then
        moment("prof", { name = name, rank = RANK_OF[max] })
      end
    end
  end
end
ns.on("SKILL_LINES_CHANGED", function() lookAtTrades(false) end)

-- ── gear ─────────────────────────────────────────────────────────────────────
-- Something worn for the first time (green and above; an item put on again,
-- after another, is no news). worn[itemId] = true; made[itemId] = true for
-- what the character crafted ("You create: ..."), told as such when put on.
local function lookAtGear(quiet)
  local c = char()
  c.worn = c.worn or {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    local id = link and not secret(link) and tonumber(link:match("item:(%d+)"))
    if id and not c.worn[id] then
      c.worn[id] = true
      local _, quality = itemInfo(link)
      if not quiet and quality and quality >= 2 then
        -- (in hand: a weapon, a shield, a bow, taken up rather than put on)
        moment("gear", { link = link, quality = quality, made = (c.made or {})[id] or nil, held = slot >= 16 or nil })
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

-- ── a hunter's pet, a first ride ─────────────────────────────────────────────
-- A hunter's new companion (a pet not met before, by name), and its deaths;
-- the first time the character rides a mount of its own.
local petDown = false
local function lookAtPet(quiet)
  local c = char()
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
    if not quiet then moment("tame", { name = name, family = c.pets[name] ~= true and c.pets[name] or nil }) end
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
ns.onUnit("UNIT_AURA", "player", function()
  local c = char()
  if c.rode then return end
  local mounted = IsMounted()
  if mounted and not secret(mounted) then
    c.rode = true
    moment("mount")
  end
end)

-- At login: what the character already wears, knows and keeps, noted quietly
-- (a journal begun mid-life doesn't announce a whole wardrobe).
ns.on("PLAYER_ENTERING_WORLD", function(initial)
  if not initial then return end
  local c = char()
  lookAtGear(c.worn == nil)
  lookAtTrades(c.profs == nil)
  lookAtPet(c.pets == nil)
  if c.rode == nil and IsMounted() then c.rode = true end
end)

ns.on("PLAYER_MONEY", function()
  local c, money = char(), GetMoney()
  if c.money and money > c.money then
    local ch = chapter()
    ch.gold = ch.gold + (money - c.money)
  end
  c.money = money
end)
