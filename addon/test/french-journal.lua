-- The journal in French: the sample's lives played on a French client, each
-- journal written in French (French.lua), whole or entry by entry; what the
-- French lacks is counted (an entry left in English, a name the tables don't
-- know) and what slipped through is caught (a slot, a gender token, English).
--   luajit addon/test/french-journal.lua [life…]            the journals, as Markdown
--   luajit addon/test/french-journal.lua --check [life…]    fails on an entry left in
--                                                           English or a leak
--   SEX=2 for a man; FOREVER=1 for Forever
LOCALE = "frFR"
HEARTHTALE_FRENCH = true -- (played before the French is complete)
local lives = dofile("addon/test/lives.lua")

local check = false
local names = {}
for _, a in ipairs(arg or {}) do
  if a == "--check" then
    check = true
  else
    names[#names + 1] = a
  end
end
if #names == 0 then names = { "brannok", "grashnak", "aelyndra", "mortis", "pippa" } end

-- (English that must never reach a French entry: its small words)
local ENGLISH = { "the", "and", "with", "of", "my", "was", "were", "had", "into", "from", "there" }
local function leaks(text)
  local found = {}
  if text:find("{") then found[#found + 1] = "a slot left" end
  if text:find("%$[gG]") then found[#found + 1] = "a gender token left" end
  for _, w in ipairs(ENGLISH) do
    if text:find("%f[%a]" .. w .. "%f[%A]") then found[#found + 1] = '"' .. w .. '"' end
  end
  return found
end

local failures, english, total = {}, 0, 0
for _, name in ipairs(names) do
  local G = lives[name]()
  local c = HearthtaleChar
  local F = G.ns.french
  assert(F, "French.lua not loaded")
  c.language = "frFR"
  G.ns.forgetWritten(c)
  c.book = nil
  F.fellBack, F.missing, F.unknown = 0, {}, {}
  local book = G.ns.writeBook(c)
  io.write(("# %s (%s %s, %s)\n\n"):format(c.name, c.race, c.class, c.sex == 3 and "femme" or "homme"))
  if book.prologue then io.write(book.prologue, "\n\n") end
  for _, ch in ipairs(book.chapters) do
    total = total + 1
    io.write(("## Entrée %d : %s\n\n%s\n\n"):format(ch.number, ch.title or "", ch.text or "(rien à raconter)"))
    local found = leaks(ch.text or "")
    if #found > 0 then
      failures[#failures + 1] = ("%s, entry %d: %s"):format(name, ch.number, table.concat(found, ", "))
    end
  end
  if book.epitaph then io.write("## Épitaphe\n\n", book.epitaph, "\n\n") end
  english = english + (F.fellBack or 0)
  local unknown = {}
  for n in pairs(F.unknown) do
    unknown[#unknown + 1] = n
  end
  table.sort(unknown)
  if #unknown > 0 then io.write("<!-- names the French tables lack: ", table.concat(unknown, "; "), " -->\n\n") end
  local missing = {}
  for m in pairs(F.missing) do
    missing[#missing + 1] = m
  end
  table.sort(missing)
  if #missing > 0 then io.write("<!-- lines with no French yet:\n", table.concat(missing, "\n"), "\n-->\n\n") end
end
io.stderr:write(("French: %d of %d entries in French (%d left in English)\n"):format(total - english, total, english))
if check then
  if english > 0 then failures[#failures + 1] = english .. " entries left in English" end
  if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n"), "\n")
    os.exit(1)
  end
end
