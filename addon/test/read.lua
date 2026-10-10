-- A character's journal, written by the current writer from a saved file:
--   luajit addon/test/read.lua path/to/SavedVariables/Hearthtale.lua
-- (the game's data for the client the book was saved by: Forever or Classic)
--   luajit addon/test/read.lua path/to/Hearthtale.lua record   each entry
--     followed by what its chapter recorded, moment by moment
local path = assert(arg[1], "usage: luajit addon/test/read.lua <saved Hearthtale.lua> [record]")
local withRecord = arg[2] == "record"
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
-- (a moment in one line: its kind, then what it holds, the log's position first)
local function moment(i, m)
  local parts = { ("%3d %s"):format(i, m.k or "?") }
  local keys = {}
  for k in pairs(m) do
    if k ~= "k" then table.insert(keys, k) end
  end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local v = m[k]
    if type(v) == "table" then
      local inner = {}
      for _, x in ipairs(v) do
        inner[#inner + 1] = type(x) == "table" and ((x.name or x.type or "?") .. (x.n and ("x" .. x.n) or ""))
          or tostring(x)
      end
      v = "{" .. table.concat(inner, ", ") .. "}"
    end
    table.insert(parts, k .. "=" .. tostring(v))
  end
  return table.concat(parts, " ")
end
for i, ch in ipairs(book.chapters) do
  io.write("## Chapter ", i, "\n\n", ch.text or "", "\n\n")
  if withRecord then
    io.write("```\n")
    for j, m in ipairs(ch.chapter.log or {}) do
      io.write(moment(j, m), "\n")
    end
    io.write("```\n\n")
  end
end
if book.epitaph then io.write("---\n\n", book.epitaph, "\n") end
