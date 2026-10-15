-- The reader's language, for the interface (the journal itself is written in
-- English on every client: Record.lua). The client loads its own
-- Text_<locale>.lua next (the TOCs name Text_[TextLocale].lua;
-- scripts/locales.ts writes them from i18n/), which hands its words to
-- ns.translate; English stays wherever it says nothing. Loaded right after the
-- kit, before any file reads a word.
local _, ns = ...
local K = ns.kit

-- (is n the "one" form? English, German, Spanish, Italian: 1; French and
-- Brazilian Portuguese: 0 and 1; Russian: 1, 21, 31... but not 11; Korean
-- and Chinese have one form)
local PLURALS = {
  one = function(n) return n == 1 end,
  fr = function(n) return n == 0 or n == 1 end,
  ru = function(n) return n % 10 == 1 and n % 100 ~= 11 end,
  none = function() return false end,
}

-- Capitals, the accented ones too ("écrit" is "ÉCRIT": the game's upper
-- leaves a letter of two bytes as it is). Latin-1's small letters à to þ
-- (UTF-8 C3 A0 to C3 BE, ÷ aside) are their capitals' plus 32; œ is Œ's plus 1.
function ns.upper(s)
  s = s:upper():gsub("\195([\160-\190])", function(c)
    if c == "\183" then return "\195\183" end
    return "\195" .. string.char(c:byte() - 32)
  end)
  return (s:gsub("\197\147", "\197\146"))
end

-- The game's names in the client's language (its Text file's, every
-- language's, English one of them): the places inside buildings by their ids,
-- each game's (Record.lua finds a building's id by the name the client
-- gives); the races by their tokens, masculine and feminine (the Hall's).
function ns.gameNames(t)
  ns.insideNames = t
  ns.raceNames = t.races
end

function ns.translate(t)
  ns.locale = t.locale
  K.isOne = PLURALS[t.plural] or K.isOne
  -- (the reader's gender, the game's own token: $gmasculine:feminine;)
  local female = UnitSex and UnitSex("player") == 3
  local L = K.L
  for english, word in pairs(t.words or {}) do
    L[english] = word:gsub("%$g([^:;]*):([^;]*);", function(m, f) return female and f or m end)
  end
end
