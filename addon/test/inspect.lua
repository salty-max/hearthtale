-- The checks every written text must pass: slots filled, sentences
-- capitalised and closed, no stray spaces or doubled words, no "one tasks".
-- Shared by the writer test (writer.lua) and the playthroughs (playthrough.lua).
--   local inspect = dofile("addon/test/inspect.lua")(problem)
return function(problem)
  return function(where, text)
    if not text then return end
    local checks = {
      { "{", "a slot left unfilled" },
      { "%f[%a]nil%f[%A]", "nil in the text" },
      { "  ", "a double space" },
      { "%%", "a health percentage in the narrative" },
      { " %.", "a space before a full stop" },
      { " ,", "a space before a comma" },
      { "%.%.", "two full stops" },
      { ",%.", "a comma before a full stop" },
      { "there there", "there there" },
      { "%f[%a]in in%f[%A]", "in in" },
      { "%f[%a]in there%f[%A]", "in there" },
      { "%f[%a]a a%f[%A]", "a a" },
      { "%f[%a]the the%f[%A]", "the the" },
      { "%f[%a]there%f[%A][^%.!%?]*%f[%a]there%f[%A]", "there twice in a sentence" },
      { " ;", "a space before a semicolon" },
      { "[;:] *[%.!%?]", "nothing after a colon" },
      { "^%l", "a lowercase start" },
      { '[%.!%?]"? +%l', "a sentence starting in lowercase" },
      { '[^%.!%?"]$', "no full stop at the end" },
      { "\n%l", "a paragraph starting in lowercase" },
      { "\n\n\n", "an empty paragraph" },
      { '[^%.!%?"\n]\n', "a paragraph without a full stop" },
    }
    for _, c in ipairs(checks) do
      if text:find(c[1]) then problem(where, c[2], text) end
    end
    -- A count of one before a plural ("one tasks"), but not "twenty-one tasks"
    -- or "a hundred and one tasks".
    for at, noun in text:gmatch("()[Oo]ne (%a+)") do
      local before = text:sub(math.max(1, at - 4), at - 1)
      local plural = ({ tasks = 1, foes = 1, lands = 1, good = 1, errands = 1, jobs = 1, quests = 1 })[noun]
      if plural and not before:find("%a$") and not before:find("%-$") and not before:find("and $") then
        problem(where, "one, then a plural", text)
      end
    end
  end
end
