-- Hearthtale on a German client: its own language file (Text_deDE.lua), the
-- interface in German. The journal itself stays English (Record.lua).
--   luajit addon/test/german.lua; FOREVER=1 luajit addon/test/german.lua
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

-- Codes and commands stay executable while their feedback is translated.
SlashCmdList.HEARTHTALE("link BAD")
check(last():find("sechs Zeichen %(Buchstaben oder Ziffern%)"), "an invalid code explains the total length", last())
SlashCmdList.HEARTHTALE("link ab12cd")
local journal = ns.journal()
check(journal.link.code == "AB12CD", "the translated interface preserves the actual link code")
check(last():find("gib /reload ein", 1, true), "the accepted code gives the executable upload instruction", last())

-- A German interface must not translate the journal's stored names or
-- overwrite the player's own words. A rewrite remains a separate choice.
SlashCmdList.HEARTHTALE("title 1 Mein eigener Titel")
SlashCmdList.HEARTHTALE("note 1 Meine eigene Notiz")
local before = ns.writeBook(journal).chapters[1]
check(
  before.title == "Mein eigener Titel" and before.note == "Meine eigene Notiz",
  "the player's German title and note are kept"
)
check(journal.race == "Dwarf" and journal.class == "PALADIN", "recorded identity remains in the writer's English keys")
G.logout()
local saved = journal.book
check(saved.chapters[1].diary == before.text, "the German interface saves the journal's original prose")
SlashCmdList.HEARTHTALE("rewrite")
check(
  G.popups[#G.popups] == "HEARTHTALE_REWRITE" and journal.book == saved,
  "asking to rewrite does not rewrite the book"
)
StaticPopupDialogs.HEARTHTALE_REWRITE.OnAccept()
local after = ns.writeBook(journal).chapters[1]
check(last():find("das Tagebuch wurde neu geschrieben%.") ~= nil, "the confirmed rewrite reports completion", last())
check(
  after.title == before.title and after.note == before.note,
  "a confirmed rewrite preserves the player's title and note"
)
for _, n in ipairs({ 0, 1, 2 }) do
  check(
    ns.kit.plural(n, "%d entry", "%d entries"):format(n) == ("%d %s"):format(n, n == 1 and "Eintrag" or "Einträge"),
    n .. " entry/entries: German plural rule"
  )
end

io.stdout:write(("%s, German: %d checks passed\n"):format(G.forever and "Forever" or "Classic Era", passed))
