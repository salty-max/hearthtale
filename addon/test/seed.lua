-- The site's test data: the lives of lives.lua played through the addon, each
-- logged out so the addon writes its book into the saved file (Save.lua), then
-- given as the site will receive them: who, where, and the book as written.
--   luajit addon/test/seed.lua > apps/api/src/db/seed/characters.json
local lives = dofile("addon/test/lives.lua")

local json = dofile("addon/test/json.lua")

local characters = {}
for _, name in ipairs({ "brannok", "pippa", "aldric", "grashnak", "aelyndra", "mortis", "edric" }) do
  local G = lives[name]()
  -- (the player's own words, as the site shows them: a title given, a note)
  if name == "brannok" then
    SlashCmdList.HEARTHTALE("title 2 Timber and the Vest")
    SlashCmdList.HEARTHTALE("note 2 First thing I ever made that was worth wearing. Buy more arrows before Kharanos.")
  end
  G.logout()
  local c = HearthtaleChar
  table.insert(characters, {
    guid = c.guid,
    name = c.name,
    realm = c.realm,
    region = c.region,
    race = c.race,
    class = c.class,
    hardcore = c.hardcore or false,
    fallen = c.closed or false,
    book = c.book,
  })
end
io.write(json(characters), "\n")
