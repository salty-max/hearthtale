-- The site's test data: the lives of lives.lua played through the addon, each
-- logged out so the addon writes its book into the saved file (Save.lua), then
-- given as the site will receive them: who, where, and the book as written.
--   luajit addon/test/seed.lua > apps/api/src/db/seed/characters.json
local lives = dofile("addon/test/lives.lua")

-- JSON, keys sorted (the same file on every run).
local function json(v, indent)
  indent = indent or ""
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" or t == "number" then return tostring(v) end
  if t == "string" then
    return '"'
      .. v:gsub(
        '[%c"\\]',
        function(c)
          return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t" })[c] or ("\\u%04x"):format(c:byte())
        end
      )
      .. '"'
  end
  local inner = indent .. "  "
  if #v > 0 or next(v) == nil then
    local out = {}
    for _, x in ipairs(v) do
      table.insert(out, inner .. json(x, inner))
    end
    return #out == 0 and "[]" or "[\n" .. table.concat(out, ",\n") .. "\n" .. indent .. "]"
  end
  local keys = {}
  for k in pairs(v) do
    table.insert(keys, k)
  end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    table.insert(out, inner .. json(tostring(k)) .. ": " .. json(v[k], inner))
  end
  return "{\n" .. table.concat(out, ",\n") .. "\n" .. indent .. "}"
end

local characters = {}
for _, name in ipairs({ "brannok", "pippa", "aldric", "grashnak", "aelyndra", "mortis", "edric" }) do
  local G = lives[name]()
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
