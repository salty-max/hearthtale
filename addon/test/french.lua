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

io.stdout:write(("%s, French: %d checks passed\n"):format(G.forever and "Forever" or "Classic Era", passed))
