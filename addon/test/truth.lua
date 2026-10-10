-- Whether a quest's story belongs to the quest recorded: a quest told by its
-- story (writing/why/, by id) must be the game's quest of that id, the same
-- title. Grammar and reachability can't tell a true story from one borrowed by
-- a wrong id (a test's made-up quest told as Lord Aliden Perenolde's end).
--   local truth = dofile("addon/test/truth.lua")(ns, titles)   (titles: id -> the game's title)
--   truth(c, where, problem)   (c: a character's record)
return function(ns, titles)
  return function(c, where, problem)
    for n, ch in ipairs(c.chapters or {}) do
      for _, m in ipairs(ch.log or {}) do
        if (m.k == "quest" or m.k == "done") and m.id and ns.data.why[m.id] and titles[m.id] ~= m.title then
          problem(
            ("%s entry %d"):format(where, n),
            ("quest %d recorded as %q has the story of the game's %q"):format(m.id, m.title or "?", titles[m.id] or "?"),
            ns.data.why[m.id][2]
          )
        end
      end
    end
  end
end
