-- The writer against the whole game: every place, creature, quest objective
-- and item of Classic (.cache/audit/game.lua, from `bun scripts/audit-data.ts`)
-- through the writer's own rules, written out for review.
--   luajit addon/test/audit.lua > .cache/audit/report.txt
local DIR = "addon/Hearthtale/"
local ns = {}
assert(loadfile(DIR .. "Data_Classic.lua"))("Hearthtale", ns)
assert(loadfile(DIR .. "Names.lua"))("Hearthtale", ns)
assert(loadfile(DIR .. "Writer.lua"))("Hearthtale", ns)
local ok, D = pcall(dofile, ".cache/audit/game.lua")
if not ok then io.stderr:write("no game data: run bun scripts/audit-data.ts\n") os.exit(1) end

local function sorted(t) table.sort(t) return t end
local function section(title, lines)
  io.write(("\n## %s (%d)\n\n"):format(title, #lines))
  for _, l in ipairs(sorted(lines)) do io.write(l, "\n") end
end

-- Places: as the writer names them inside a sentence.
local places, seen = {}, {}
for _, name in pairs(D.zones) do
  if not seen[name] then seen[name] = true; table.insert(places, ("I reached %s."):format(ns.mid(name))) end
end
section("places", places)

-- Creatures one meets in passing (an article) or by name (none): those with
-- a single spawn point, by the writer's rule.
local named, generic = {}, {}
seen = {}
for _, c in pairs(D.creatures) do
  if c.name and not seen[c.name] and (c.npc or 0) == 0 and c.spawns > 0 and not c.name:find("[%(%[]") then
    seen[c.name] = true
    local line = ("I killed %s. (%d spawn%s)"):format(ns.article(c.name), c.spawns, c.spawns == 1 and "" or "s")
    table.insert(c.spawns == 1 and named or generic, line)
  end
end
section("creatures met once (one spawn point)", named)
io.write(("\n(%d creatures with several spawn points: always an article)\n"):format(#generic))

-- Quest objectives the log shows as text (events): as a task done, or
-- (a result, not an instruction) told by who asked.
local tasks, results = {}, {}
for id, q in pairs(D.quests) do
  for _, t in ipairs(q.texts or {}) do
    if t ~= "" and ns.instruction(t) then table.insert(tasks, ("I managed to %s. [%d %s]"):format(ns.taskOf(t), id, q.title))
    elseif t ~= "" then table.insert(results, ("%s [%d %s]"):format(t, id, q.title)) end
  end
end
section("event objectives told as tasks", tasks)
section("event objectives told by who asked (results, not instructions)", results)

-- Quest items: one, and several.
local things = {}
seen = {}
for _, q in pairs(D.quests) do
  for _, pair in ipairs(q.items or {}) do
    local item = D.items[pair[1]]
    if item and not seen[item.name] then
      seen[item.name] = true
      table.insert(things, ("I found %s / I found eight %s."):format(ns.itemName(item.name), ns.things(item.name)))
    end
  end
end
section("quest items", things)

-- Blue and better finds, as the loot line names them.
local finds = {}
for _, item in pairs(D.items) do
  if (item.quality or 0) >= 3 and item.name and not item.name:find("^Monster ") then
    table.insert(finds, ("I turned up %s."):format(ns.itemName(item.name)))
  end
end
section("finds (blue and better)", finds)

-- Regressions: what the rules must never write, over the whole game.
local problems = {}
local function never(pattern, lines, what)
  for _, l in ipairs(lines) do
    if (l:gsub(" %[.*$", "")):find(pattern) then table.insert(problems, what .. ": " .. l) break end
  end
end
never("^I reached The ", places, "a place with its own article, capitalised")
never("^I killed an? The ", named, "an article before a name's own")
never("^I killed an? Mr%. ", named, "an article before a title")
never("^I managed to %u", tasks, "a task starting in capitals")
never("^I managed to .* The ", tasks, "a capitalised article inside a task")
never("an? An? ", things, "two articles")
for _, title in ipairs({ "Baron", "Lord", "Lady", "Captain", "King", "Queen", "General", "Commander", "Chief", "Prince",
  "Overlord", "Archmage", "Foreman", "Sergeant", "Lieutenant", "Marshal" }) do
  never("an? " .. title .. " %u%a*'s ", things, "an article before a titled owner")
  never("an? " .. title .. " %u%a*'s ", finds, "an article before a titled owner")
end
for _, l in ipairs(results) do
  if l:find("^%l") then table.insert(problems, "a result told as a task: " .. l) break end
end
if #problems > 0 then
  io.stderr:write(table.concat(problems, "\n"), "\n")
  os.exit(1)
end
io.stderr:write(("all good (audit: %d places, %d creatures, %d objectives, %d quest items, %d finds)\n")
  :format(#places, #named + #generic, #tasks + #results, #things, #finds))
