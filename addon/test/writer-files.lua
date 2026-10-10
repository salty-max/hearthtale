-- The writer's files, in the TOC's order: loaded into ns by the tests
--   dofile("addon/test/writer-files.lua")(ns)   (Data and Names first; the
-- game's knowledge, Knowledge.lua, with them)
-- (FOREVER=1: Forever's own content after the knowledge, as its package has it)
return function(ns, dir)
  dir = dir or "addon/Hearthtale/"
  local files = { "Knowledge.lua", "Util.lua", "Language.lua", "Lines.lua", "Diary.lua" }
  if os.getenv("FOREVER") == "1" then table.insert(files, 2, "Forever.lua") end
  for _, f in ipairs(files) do
    assert(loadfile(dir .. f))("Hearthtale", ns)
  end
end
