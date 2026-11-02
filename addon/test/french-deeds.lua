-- Every French deed (i18n/frFR/writing/why/) told in the game's French: a name
-- the French tables don't know, a token left or an error fails. Each game
-- checks the deeds of its own quests.
--   luajit addon/test/french-deeds.lua      FOREVER=1 for Forever
LOCALE = "frFR"
HEARTHTALE_FRENCH = true -- (played before the French is complete)
local lives = dofile("addon/test/lives.lua")
local G = lives.brannok()
local F = G.ns.french
assert(F, "French.lua not loaded")
F.on = true
local quests = G.ns.englishNames().quests
local ids = {}
for id in pairs(G.ns.frenchWriting().why) do
  if quests[id] then ids[#ids + 1] = id end
end
table.sort(ids)
local failures = {}
for _, id in ipairs(ids) do
  F.unknown = {}
  local ok, fr = pcall(F.deed, id, "the deed of " .. id, "Human")
  local out = ok and F.tidy(fr or ""):gsub("\1", "") or ("error: " .. tostring(fr))
  local unknown = {}
  for n in pairs(F.unknown) do
    unknown[#unknown + 1] = n
  end
  table.sort(unknown)
  if not ok or #unknown > 0 or out:find("%[%[") then
    failures[#failures + 1] = ("%d: %s%s"):format(
      id,
      out,
      #unknown > 0 and (" (unknown: " .. table.concat(unknown, "; ") .. ")") or ""
    )
  end
end
io.stderr:write(("French deeds: %d told, %d failing\n"):format(#ids, #failures))
if #failures > 0 then
  io.stderr:write(table.concat(failures, "\n"), "\n")
  os.exit(1)
end
