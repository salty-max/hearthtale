-- Small helpers shared by the addon's files: plain Lua, no game API (the
-- writer's tests load it outside the game).
local _, ns = ...

-- A deep copy of a value: tables copied all the way down, but for the key
-- skip at the top (a record's book, say).
local function copy(t, skip)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do
    if k ~= skip then out[k] = copy(v) end
  end
  return out
end
ns.copy = copy

-- Spells known by name (English clients): a druid's forms and a warlock's
-- demons (spell = the form, or the demon's family as the game names it),
-- told the first time they are used, not when learned; and a trade's own
-- spells, learned with it, which the trade itself tells.
ns.POWER_SPELLS = {
  ["Summon Imp"] = "Imp",
  ["Summon Voidwalker"] = "Voidwalker",
  ["Summon Succubus"] = "Succubus",
  ["Summon Felhunter"] = "Felhunter",
  ["Summon Felguard"] = "Felguard",
  ["Bear Form"] = "bear",
  ["Dire Bear Form"] = "bear",
  ["Cat Form"] = "cat",
  ["Travel Form"] = "travel",
  ["Aquatic Form"] = "aquatic",
  ["Moonkin Form"] = "moonkin",
  ["Tree of Life"] = "tree",
  ["Flight Form"] = "flight",
}
ns.TRADE_SPELLS = {}
for _, name in ipairs({
  "Find Herbs",
  "Herb Gathering",
  "Gardening",
  "Find Minerals",
  "Smelting",
  "Mining",
  "Skinning",
  "Fishing",
  "Cooking",
  "Basic Campfire",
  "First Aid",
  "Disenchant",
}) do
  ns.TRADE_SPELLS[name] = true
end
