-- The writer's files, in the TOC's order: loaded into ns by the tests
--   dofile("addon/test/writer-files.lua")(ns)   (Data and Names first; the
-- game's knowledge, Knowledge.lua, with them)
return function(ns, dir)
  dir = dir or "addon/Hearthtale/"
  for _, f in ipairs({ "Knowledge.lua", "Util.lua", "Language.lua", "Lines.lua", "Scene.lua", "Writer.lua" }) do
    assert(loadfile(dir .. f))("Hearthtale", ns)
  end
end
