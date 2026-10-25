-- The reader's language, for the interface (the journal itself is written in
-- English on every client: Record.lua). The client loads its own
-- Text_<locale>.lua next (the TOCs name Text_[TextLocale].lua;
-- scripts/locales.ts writes them from i18n/), which hands its words to
-- ns.translate; English stays wherever it says nothing. Loaded right after the
-- kit, before any file reads a word.
local _, ns = ...
local K = ns.kit

-- Capitals, the accented ones too ("écrit" is "ÉCRIT": the kit's, which the
-- game's upper isn't, leaving a letter of two bytes as it is).
ns.upper = K.upper

-- The game's names in the client's language (its Text file's, every
-- language's, English one of them): the places inside buildings by their ids,
-- each game's (Record.lua finds a building's id by the name the client
-- gives); the races by their tokens, masculine and feminine (the Hall's).
function ns.gameNames(t)
  ns.insideNames = t
  ns.raceNames = t.races
end

-- (the kit's: the language's plural rule, every word agreed to the reader's
-- gender, the game's own token $gmasculine:feminine;)
function ns.translate(t)
  ns.locale = t.locale
  K.translate(t)
end
