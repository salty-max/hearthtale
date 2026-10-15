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
  last():find("^|c%x+Hearthtale:|r /ht ouvre le journal, /ht hall la Salle des Disparus%."),
  "/ht's help in French",
  last()
)
SlashCmdList.HEARTHTALE("title 9 Rien")
check(
  last():find("titre de l'entrée %d+ gardé%.") or last():find("aucune entrée à titrer"),
  "an entry's title, said in French",
  last()
)

-- A fallen life's race and class in today's language: kept in English at its
-- end, read in French by their tokens (the game's own tables, a woman's
-- class); kept in French, kept as they were (a dwarf woman's "Naine")
local getLocale = GetLocale
GetLocale = function() return "frFR" end
LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE = { WARRIOR = "Guerrier" }, { WARRIOR = "Guerrière" }
C_CreatureInfo = {
  GetRaceInfo = function(id) return id == 3 and { raceName = "Nain", clientFileString = "Dwarf", raceID = 3 } or nil end,
}
local english =
  { race = "Dwarf", class = "WARRIOR", sex = 3, raceName = "Dwarf", className = "Warrior", locale = "enUS" }
local french = { race = "Dwarf", class = "WARRIOR", sex = 3, raceName = "Naine", className = "Guerrière" }
local race1, class1 = ns.lifeNames(english)
local race2, class2 = ns.lifeNames(french)
check(
  race1 == "Nain" and class1 == "Guerrière" and race2 == "Naine" and class2 == "Guerrière",
  "a fallen life's race and class in today's language, by their tokens; kept in it, as kept",
  tostring(race1) .. " " .. tostring(class1)
)
GetLocale = getLocale
LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE, C_CreatureInfo = nil, nil, nil

io.stdout:write(("%s, French: %d checks passed\n"):format(G.forever and "Forever" or "Classic Era", passed))
