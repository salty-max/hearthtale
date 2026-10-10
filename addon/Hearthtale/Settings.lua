-- The addon's settings, kept for the whole account in HearthtaleSettings,
-- and their page in the game's Options (AddOns tab). /ht settings opens it;
-- so does a right-click on the minimap button. One setting is the
-- character's own: "This character is Hardcore", offered only where the game
-- can't tell (no C_GameRules), kept in its journal.
local _, ns = ...

-- (minimapAngle: the button's place around the minimap, in degrees; 200 is
-- to the left, clear of the game's buttons and the siblings')
-- (welcomed: the welcome page was seen, Welcome.lua)
local DEFAULTS = { chat = true, toast = true, minimapHidden = false, minimapAngle = 200, welcomed = false }

local function saved()
  if type(HearthtaleSettings) ~= "table" then HearthtaleSettings = {} end
  return HearthtaleSettings
end

function ns.option(key)
  local v = saved()[key]
  if v == nil then return DEFAULTS[key] end
  return v
end

function ns.setOption(key, value)
  saved()[key] = value
  if key == "minimapHidden" and ns.updateMinimapButton then ns.updateMinimapButton() end
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

  Settings.RegisterAddOnCategory(category)
end

function ns.openSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
  return category ~= nil
end
