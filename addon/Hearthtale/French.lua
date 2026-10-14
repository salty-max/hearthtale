-- The French writing, a trial (branch french-slice). The writer chooses its
-- lines in English as ever; a line told is told again in French, from the
-- facts behind its slots (a place, a foe, a quest), never from its English
-- words. An entry is French when each of its sentences is; else it stays
-- English whole. The words: Text_frFR.lua (scripts/french.ts).
local _, ns = ...

local function text() return ns.frenchText end

-- (Classic Era: its own names, "Ironforge"; Forever's "Forgefer")
local function isClassic() return not ns.forever end

-- The game's French name of a place, and the place with its preposition.
local function place(name)
  local t = text()
  local p = isClassic() and t.placesClassic[name] or t.places[name]
  return p
end

-- A foe: a name of its own as it is ("Grik'nir le Froid"), one of a kind
-- with its article ("un jeune troll Frostmane").
local function foe(name, bare)
  local t = text()
  local c = isClassic() and t.creaturesClassic[name] or t.creatures[name]
  if not c then return nil end
  return bare and c[1] or c.one
end

-- (the vowels a French word elides before: é, è, à … are two bytes, the
-- first \195; ç is not one; an aspirated h is no vowel: "la Horde")
local ASPIRATED = { horde = true, ["h\195\169ros"] = true, haine = true, hache = true, haut = true, hurlement = true }
local function vowel(word)
  local c = word:sub(1, 1)
  if c:find("[aeiouyAEIOUY]") then return true end
  if c == "\195" then return word:byte(2) ~= 167 and word:byte(2) ~= 135 end
  if c == "h" or c == "H" then return not ASPIRATED[word:lower():match("^[%a\128-\255]+")] end
  return false
end

-- What French does where two words meet: "je ai" is "j'ai", "de le" is
-- "du", "à les" is "aux". (A word starts after a space, a quote or a
-- parenthesis: Lua's %a knows no é, so "modèle" is no "le".)
local function tidy(s)
  s = " " .. s
  s = s:gsub('([%s%("])([JjMmTtSsLlNnDd])e (%S+)', function(b, l, w)
    if vowel(w) then return b .. l .. "'" .. w end
  end)
  s = s:gsub('([%s%("])([Qq])ue (%S+)', function(b, q, w)
    if vowel(w) then return b .. q .. "u'" .. w end
  end)
  s = s:gsub('([%s%("])([Ll])a (%S+)', function(b, l, w)
    if vowel(w) then return b .. l .. "'" .. w end
  end)
  s = s:gsub('([%s%("])([Dd])e le ', "%1%2u "):gsub('([%s%("])([Dd])e les ', "%1%2es ")
  s = s:gsub(" \195\160 le ", " au "):gsub(" \195\160 les ", " aux ")
  s = s:gsub(" si il", " s'il")
  return s:sub(2)
end

-- The narrator's gender: $gmasc:fem; as the game's own texts write it.
local function gendered(s, female)
  return (s:gsub("%$[gG]([^:;]*):([^;]*);", function(m, f) return female and f or m end))
end

-- A sentence's first letter in capitals, é and à too.
local function capital(s)
  local first = s:sub(1, 1)
  if first == "\195" then
    local b = s:byte(2)
    if b >= 160 and b <= 190 then return first .. string.char(b - 32) .. s:sub(3) end
    return s
  end
  return first:upper() .. s:sub(2)
end

-- The French of a line told: its template, its slots from the facts in
-- values (_place, _foe, _why, _where), the narrator's gender. nil when any
-- piece has no French.
function ns.frenchSay(template, values, book, raw)
  local t = text()
  local fr = t and t.lines[template]
  if not fr then return nil end
  local female = book.c.sex == 3
  -- (only what French has words for: an English slot never leaks in; a
  -- person's name is theirs, as the record has it)
  local slots = { who = values.who, mates = values.mates, pet = values.pet }
  local p = values._place and place(values._place)
  if values.at ~= nil then
    if values.at == "" then
      slots.at = ""
    elseif values.at == "there" then
      slots.at = "l\195\160"
    else
      slots.at = p and p.at
    end
  end
  if values["in"] ~= nil then slots["in"] = p and p.at end
  if values.where ~= nil then
    local w = values._where and place(values._where)
    slots.where = (values._where and (w and w.at)) or (p and p[1])
  end
  if values.place ~= nil then slots.place = p and p[1] end
  if values.home ~= nil then
    local h = place(values.home)
    slots.home = h and h[1]
  end
  if values.foe ~= nil then slots.foe = values._foe and foe(values._foe, values._bare) end
  if values.why ~= nil then slots.why = values._why and t.deeds[values._why] end
  local missing
  fr = fr:gsub("{(%w+)}", function(slot)
    local v = slots[slot]
    if type(v) ~= "string" then
      missing = slot
      return ""
    end
    return v
  end)
  if missing then return nil end
  if isClassic() then
    for forever, own in pairs(t.classic) do
      fr = fr:gsub(forever:gsub("%p", "%%%0"), own)
    end
  end
  fr = tidy(gendered(fr, female))
  fr = fr:gsub(" +([%.,])", "%1"):gsub("  +", " "):gsub("^[ ,]+", "")
  return raw and fr or capital(fr)
end

-- A place's description in French (writing/scenery/), as written.
function ns.frenchScenery(english, book)
  local t = text()
  local fr = t and t.lines[english]
  if not fr then return nil end
  if isClassic() then
    for forever, own in pairs(t.classic) do
      fr = fr:gsub(forever:gsub("%p", "%%%0"), own)
    end
  end
  return tidy(gendered(fr, book.c.sex == 3))
end
