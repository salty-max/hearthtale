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
