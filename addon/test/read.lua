-- A character's journal, written by the current writer from a saved file:
--   luajit addon/test/read.lua path/to/SavedVariables/Hearthtale.lua
-- (the game's data for the client the book was saved by: Forever or Classic)
--   luajit addon/test/read.lua path/to/Hearthtale.lua diary   each chapter's
--     diary entry (Diary.lua), then the chapter in full, to compare
local path = assert(arg[1], "usage: luajit addon/test/read.lua <saved Hearthtale.lua> [diary]")
local withDiary = arg[2] == "diary"
assert(loadfile(path))()
local c = assert(HearthtaleChar, "no HearthtaleChar in " .. path)
local forever = (c.book and c.book.client) == "forever"
local ns = {}
for _, f in ipairs({ forever and "Data_Forever.lua" or "Data_Classic.lua", "Names.lua" }) do
  assert(loadfile("addon/Hearthtale/" .. f))("Hearthtale", ns)
end
dofile("addon/test/writer-files.lua")(ns)
local book = ns.writeBook(c)
io.write("# ", c.name or "?", "'s journal\n\n")
io.write(
  "*",
  c.name or "?",
  ", ",
  (c.race or ""):lower(),
  " ",
  (c.class or ""):lower(),
  ", ",
  c.realm or "",
  forever and " (Forever)" or "",
  ", recorded by Hearthtale ",
  (c.book and c.book.version) or "?",
  "*\n\n"
)
if book.prologue then io.write(book.prologue, "\n\n") end
local diary = withDiary and ns.writeDiary(c, book)
for i, ch in ipairs(book.chapters) do
  io.write("## Chapter ", i, "\n\n")
  if diary then io.write("### The diary\n\n", diary.entries[i].text, "\n\n### The full chapter\n\n") end
  io.write(ch.text or "", "\n\n")
end
if book.epitaph then io.write("---\n\n", book.epitaph, "\n") end
