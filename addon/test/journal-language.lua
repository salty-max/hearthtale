-- The journal's language, the character's own (Core.lua): the client's at the
-- first login (French once it is complete), kept whatever the client after;
-- a journal from before is English; the setting changes it, and the whole
-- journal is written again in the other (every entry, its titles, its life
-- in the Hall), the player's own titles and notes as they wrote them.
--   luajit addon/test/journal-language.lua
LOCALE = "frFR"
HEARTHTALE_FRENCH = true -- (played before the French is complete)
local lives = dofile("addon/test/lives.lua")
local failures = 0
local function check(ok, what, got)
  if ok then
    io.write("\226\156\147 ", what, "\n")
  else
    failures = failures + 1
    io.write("\226\156\151 ", what, got and (": got " .. tostring(got)) or "", "\n")
  end
end

-- A new journal on a French client: French, kept in the saved book.
local G = lives.brannok()
local ns = G.ns
local c = HearthtaleChar
check(c.language == "frFR", "a journal begun on a French client is French", c.language)
check(c.book and c.book.language == "frFR", "the saved book says its language", c.book and c.book.language)
local book = ns.writeBook(c)
check(
  book.chapters[1].text:find("^J'ai fait mes premiers pas"),
  "its first entry is told in French",
  book.chapters[1].text
)
check(book.chapters[1].title == "La caverne des trolls", "its title the game's French", book.chapters[1].title)

-- The player's own title, and a switch to English: the whole journal again,
-- in English, the player's words kept.
c.notes = { [1] = { title = "Mon titre", text = "Ma note" } }
ns.askJournalLanguage("enUS")
StaticPopupDialogs.HEARTHTALE_LANGUAGE_enUS.OnAccept()
check(c.language == "enUS", "the setting makes it English", c.language)
check(c.book == nil, "the saved words let go (written again at the next logout)")
book = ns.writeBook(c)
check(
  book.chapters[1].text:find("^I began in Coldridge Valley"),
  "its first entry told again in English",
  book.chapters[1].text
)
check(
  book.chapters[1].title == "Mon titre" and book.chapters[1].note == "Ma note",
  "the player's own title and note kept"
)
check(book.chapters[1].writtenTitle == "The Troll Cave", "the writer's title in English", book.chapters[1].writtenTitle)
for _, ch in ipairs(book.chapters) do
  if (ch.text or ""):find("J'ai") then check(false, "no French left in entry " .. ch.number) end
end

-- And back to French: the same first entry as at first.
StaticPopupDialogs.HEARTHTALE_LANGUAGE_frFR.OnAccept()
book = ns.writeBook(c)
check(book.chapters[1].text:find("^J'ai fait mes premiers pas"), "back to French: told again in French")

-- A journal from before the language was kept, on a French client: English,
-- and it stays so at every login whatever the client.
c.language = nil
ns.login()
check(c.language == "enUS", "a journal from before is English", c.language)
ns.login()
check(c.language == "enUS", "a login on a French client leaves it English")

-- A new journal on a French client while the French is not complete: English.
ns.french.ready = false
HearthtaleChar = nil
ns.login()
check(HearthtaleChar.language == "enUS", "French is no default before it is complete", HearthtaleChar.language)

io.write(failures == 0 and "all good\n" or (failures .. " failed\n"))
os.exit(failures == 0 and 0 or 1)
