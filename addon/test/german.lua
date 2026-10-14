-- Hearthtale on a German client: its own language file (Text_deDE.lua), the
-- interface in German. The journal itself stays English (Record.lua).
--   luajit addon/test/french.lua; FOREVER=1 luajit addon/test/french.lua
LOCALE = "deDE"
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

check(ns.locale == "deDE" and L["Hall of the Fallen"] == "Halle der Gefallenen", "the German language file")
check(L["A word Hearthtale never says"] == "A word Hearthtale never says", "… a word it lacks stays English")
check(ns.upper("Bücher über Schätze") == "BÜCHER ÜBER SCHÄTZE", "capitals, the accented ones too")

G.login()
check(last():find("Eintrag 1 %a+%. Tippe /ht"), "the login's line in German", last())
SlashCmdList.HEARTHTALE("what")
check(
  last():find("^|c%x+Hearthtale:|r /ht öffnet das Tagebuch, /ht hall die Halle der Gefallenen%."),
  "/ht's help in German",
  last()
)
SlashCmdList.HEARTHTALE("title 9 Rien")
check(
  last():find("Titel von Eintrag %d+ gespeichert%.") or last():find("noch kein Eintrag für einen Titel"),
  "an entry's title, said in German",
  last()
)

io.stdout:write(("%s, German: %d checks passed\n"):format(G.forever and "Forever" or "Classic Era", passed))
