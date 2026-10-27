-- Hearthtale on a French client: its own language file (Text_frFR.lua), the
-- interface in French. The journal itself stays English (Record.lua).
--   luajit addon/test/french.lua; FOREVER=1 luajit addon/test/french.lua
LOCALE = "frFR"
local G = dofile("addon/test/game.lua")
local ns = G.ns
local L = ns.kit.L
local passed = 0
local function check(cond, msg, got)
  if not cond and got then msg = msg .. ": got " .. tostring(got) end
  assert(cond, msg)
  passed = passed + 1
  io.stdout:write("✓ ", msg, "\n")
end
local function last() return G.printed[#G.printed] or "" end

check(ns.locale == "frFR" and L["Hall of the Fallen"] == "Salle des Disparus", "the French language file")
check(L["A word Hearthtale never says"] == "A word Hearthtale never says", "… a word it lacks stays English")
check(ns.upper("en cours d'écriture") == "EN COURS D'ÉCRITURE", "capitals, the accented ones too")

G.login()
check(last():find("de l'entrée 1%. Tapez /ht"), "the login's line in French", last())
SlashCmdList.HEARTHTALE("what")
check(
  last():find("^|c%x+Hearthtale.-:|r /ht ouvre le journal, /ht hall la Salle des Disparus%."),
  "/ht's help in French",
  last()
)
SlashCmdList.HEARTHTALE("title 9 Rien")
check(
  last():find("Titre de l'entrée %d+ gardé%.") or last():find("Aucune entrée à titrer"),
  "an entry's title, said in French",
  last()
)

-- A fallen life's race and class in today's language, by their tokens and
-- its sex, whatever names it kept: a class the game's, a race the language's
-- list (feminine where the client has one: a Portuguese "Anã", none in
-- French); an older life's names of the day let go
local getLocale = GetLocale
local classMale, classFemale = LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE
GetLocale = function() return "frFR" end
LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE = { WARRIOR = "Guerrier" }, { WARRIOR = "Guerrière" }
local english =
  { race = "Dwarf", class = "WARRIOR", sex = 3, raceName = "Dwarf", className = "Warrior", locale = "enUS" }
local race1, class1 = ns.lifeNames(english)
local french = ns.raceNames
ns.raceNames = { Dwarf = { "Anão", "Anã" } }
local race2 = ns.lifeNames({ race = "Dwarf", class = "WARRIOR", sex = 3 })
local race3 = ns.lifeNames({ race = "Dwarf", class = "WARRIOR", sex = 2 })
ns.raceNames = french
check(
  race1 == "Nain" and class1 == "Guerrière" and race2 == "Anã" and race3 == "Anão",
  "a fallen life's race and class in today's language, by their tokens and its sex",
  tostring(race1) .. " " .. tostring(class1)
)
GetLocale = getLocale
LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE = classMale, classFemale

io.stdout:write(("%s, French: %d checks passed\n"):format(G.forever and "Forever" or "Classic Era", passed))
