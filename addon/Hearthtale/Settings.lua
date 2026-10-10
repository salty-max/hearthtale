-- The addon's settings, each character's own (its profile, "Name - Realm"),
-- all kept in HearthtaleSettings (the game installation's, account-wide) so
-- that one character can take another's: picked from the characters of this
-- game, or from a code copied anywhere (another game, another account).
-- Their page in the game's Options (AddOns tab): /ht settings, or a
-- right-click on the minimap button. One more setting is the character's
-- own: "This character is Hardcore", offered only where the game can't tell
-- (no C_GameRules), kept in its journal.
--
--   HearthtaleSettings.profiles["Name - Realm"] = { chat, toast,
--     minimapHidden, minimapAngle, welcomed }
--   (the account-wide values of 0.6.0, at the top of HearthtaleSettings: the
--   first profile of a character who kept a journal before takes them)
local _, ns = ...

-- (minimapAngle: the button's place around the minimap, in degrees; 200 is
-- to the left, clear of the game's buttons and the siblings')
-- (welcomed: the welcome page was seen, Welcome.lua: never copied)
local DEFAULTS = { chat = true, toast = true, minimapHidden = false, minimapAngle = 200, welcomed = false }
local SHARED = { "chat", "toast", "minimapHidden", "minimapAngle" } -- (what a copy carries, in a code's order)

local function saved()
  if type(HearthtaleSettings) ~= "table" then HearthtaleSettings = {} end
  HearthtaleSettings.profiles = HearthtaleSettings.profiles or {}
  return HearthtaleSettings
end

local profileKey, profile -- this character's, from its login

-- This character's profile at its login: its own, else a new one (the
-- account's 0.6.0 values for a character who kept a journal before, the
-- defaults for a new one).
function ns.loadProfile(journal)
  profileKey = ("%s - %s"):format(UnitName("player") or "?", GetRealmName() or "?")
  local all = saved()
  profile = all.profiles[profileKey]
  if profile then return end
  profile = {}
  local before = journal and journal.chapters and #journal.chapters > 0
  if before then
    for _, k in ipairs(SHARED) do
      profile[k] = all[k]
    end
  end
  all.profiles[profileKey] = profile
end
function ns.profileKey() return profileKey end

function ns.option(k)
  local v = profile and profile[k]
  if v == nil then return DEFAULTS[k] end
  return v
end

function ns.setOption(k, value)
  if not profile then return end
  profile[k] = value
  if (k == "minimapHidden" or k == "minimapAngle") and ns.updateMinimapButton then ns.updateMinimapButton() end
end

-- The other characters of this game with a profile, by name.
function ns.otherProfiles()
  local out = {}
  for k in pairs(saved().profiles) do
    if k ~= profileKey then table.insert(out, k) end
  end
  table.sort(out)
  return out
end

local function take(from)
  for _, k in ipairs(SHARED) do
    ns.setOption(k, from[k])
  end
  if ns.refreshSettings then ns.refreshSettings() end
end

-- Another character's settings, for this one. False: no such profile.
function ns.copyProfile(other)
  local from = other ~= profileKey and saved().profiles[other]
  if not from then return false end
  take(from)
  return true
end

-- A code for this character's settings, to bring them anywhere:
-- "HT1:c1:t1:m1:a200" (chat, toast, minimap button shown, its angle).
local CODE = { c = "chat", t = "toast", m = "minimapHidden", a = "minimapAngle" }
function ns.exportCode()
  return ("HT1:c%d:t%d:m%d:a%d"):format(
    ns.option("chat") and 1 or 0,
    ns.option("toast") and 1 or 0,
    ns.option("minimapHidden") and 0 or 1,
    math.floor((ns.option("minimapAngle") or 200) + 0.5) % 360
  )
end

-- A code's settings, for this character. False: not a Hearthtale code (an
-- unknown part is left out: a later version's).
function ns.importCode(code)
  code = strtrim(code or "")
  local parts = {}
  for part in code:gmatch("[^:]+") do
    table.insert(parts, part)
  end
  if parts[1] ~= "HT1" or #parts < 2 then return false end
  local from, known = {}, false
  for i = 2, #parts do
    local letter, value = parts[i]:match("^(%a)(%d+)$")
    local k = letter and CODE[letter]
    if k then known = true end
    value = tonumber(value)
    if k == "minimapAngle" then
      from[k] = value % 360
    elseif k == "minimapHidden" then
      from[k] = value == 0
    elseif k then
      from[k] = value == 1
    end
  end
  if not known then return false end
  for _, k in ipairs(SHARED) do
    if from[k] == nil then from[k] = ns.option(k) end
  end
  take(from)
  return true
end

-- Does the game say whether this character is Hardcore?
function ns.gameKnowsHardcore() return C_GameRules ~= nil and C_GameRules.IsHardcoreActive ~= nil end

-- Where the game can't tell, the player says so (the Options page, the
-- welcome): its death then closes the book. Never once the book is closed.
function ns.isHardcore()
  local c = ns.journal()
  return c and c.hardcore == true or false
end
function ns.setHardcore(value)
  local c = ns.journal()
  if not c or c.closed then return end
  c.hardcoreChosen = value or nil
  c.hardcore = value or nil
  if ns.refresh then ns.refresh() end
end

local category

function ns.createSettingsPanel()
  if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  category = Settings.RegisterVerticalLayoutCategory("Hearthtale")

  local function checkbox(key, name, tooltip, invert)
    invert = invert or false
    local setting = Settings.RegisterProxySetting(
      category,
      "HEARTHTALE_" .. key:upper(),
      Settings.VarType.Boolean,
      name,
      not DEFAULTS[key] == invert,
      function() return ns.option(key) ~= invert end,
      function(value) ns.setOption(key, value ~= invert) end
    )
    Settings.CreateCheckbox(category, setting, tooltip)
  end
  checkbox(
    "chat",
    "A line in chat for each entry",
    "When an entry is written (you rested at an inn, in a city or by a campfire), a line in chat with a link to it."
  )
  checkbox(
    "toast",
    "Alert when a book closes",
    "The game's alert when a Hardcore character falls and its book joins the Hall of the Fallen (the chat line stays)."
  )
  checkbox("minimapHidden", "Minimap button", "The journal by the minimap: click to open it, drag to move it.", true)

  -- Where the game can't tell, the player says whether this character is
  -- Hardcore (its death then closes the book).
  if not ns.gameKnowsHardcore() then
    local setting = Settings.RegisterProxySetting(
      category,
      "HEARTHTALE_HARDCORE",
      Settings.VarType.Boolean,
      "This character is Hardcore",
      false,
      ns.isHardcore,
      ns.setHardcore
    )
    Settings.CreateCheckbox(
      category,
      setting,
      "This character's death closes its book: an epitaph, and its journal joins the Hall of the Fallen. For this character only."
    )
  end

  -- Another character's settings (of this game), for this one.
  if Settings.CreateDropdown and Settings.CreateControlTextContainer and Settings.VarType.String then
    local copy = Settings.RegisterProxySetting(
      category,
      "HEARTHTALE_COPYFROM",
      Settings.VarType.String,
      "Copy settings from",
      "",
      function() return "" end,
      function(other)
        if other ~= "" and ns.copyProfile(other) then print(ns.PREFIX .. ("%s's settings copied."):format(other)) end
      end
    )
    Settings.CreateDropdown(
      category,
      copy,
      function()
        local options = Settings.CreateControlTextContainer()
        options:Add("", "Choose a character")
        for _, other in ipairs(ns.otherProfiles()) do
          options:Add(other, other)
        end
        return options:GetData()
      end,
      "Another character's choices, for this one (of this game: Classic Era and Forever keep their own). From elsewhere: /ht export there, then /ht import CODE here."
    )
  end

  Settings.RegisterAddOnCategory(category)
end

function ns.openSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
  return category ~= nil
end
