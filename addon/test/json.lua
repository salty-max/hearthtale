-- JSON for the test scripts' outputs (seed.lua, sample.lua landing), keys
-- sorted: the same file on every run.
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

return json
