-- The addon's settings, kept for the whole account in WayfarersJournalSettings,
-- and their page in the game's Options (AddOns tab). /wj settings opens it;
-- so does a right-click on the minimap button. One setting is the
-- character's own: "This character is Hardcore", offered only where the game
-- can't tell (no C_GameRules), kept in its journal.
local _, ns = ...

local DEFAULTS = { chat = true, toast = true, minimapHidden = false }

function ns.option(key)
  if type(WayfarersJournalSettings) ~= "table" then WayfarersJournalSettings = {} end
  local v = WayfarersJournalSettings[key]
  if v == nil then return DEFAULTS[key] end
  return v
end

function ns.setOption(key, value)
  if type(WayfarersJournalSettings) ~= "table" then WayfarersJournalSettings = {} end
  WayfarersJournalSettings[key] = value
  if key == "minimapHidden" and ns.updateMinimapButton then ns.updateMinimapButton() end
end

-- Does the game say whether this character is Hardcore?
function ns.gameKnowsHardcore()
  return C_GameRules ~= nil and C_GameRules.IsHardcoreActive ~= nil
end

local category

function ns.createSettingsPanel()
  if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  category = Settings.RegisterVerticalLayoutCategory("Wayfarer's Journal")

  local function checkbox(key, name, tooltip, invert)
    invert = invert or false
    local setting = Settings.RegisterProxySetting(category, "WAYFARERSJOURNAL_" .. key:upper(), Settings.VarType.Boolean, name,
      not DEFAULTS[key] == invert,
      function() return ns.option(key) ~= invert end,
      function(value) ns.setOption(key, value ~= invert) end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end
  checkbox("chat", "A line in chat for each chapter", "When a chapter closes (you rested at an inn, in a city or by a campfire), a line in chat with a link to it.")
  checkbox("toast", "Alert when a book closes", "The game's alert when a Hardcore character falls and its book joins the Hall of the Fallen (the chat line stays).")
  checkbox("minimapHidden", "Minimap button", "The journal by the minimap: click to open it, drag to move it.", true)

  -- Where the game can't tell, the player says whether this character is
  -- Hardcore (its death then closes the book).
  if not ns.gameKnowsHardcore() then
    local setting = Settings.RegisterProxySetting(category, "WAYFARERSJOURNAL_HARDCORE", Settings.VarType.Boolean,
      "This character is Hardcore", false,
      function() local c = ns.journal() return c and c.hardcore == true or false end,
      function(value)
        local c = ns.journal()
        if not c or c.closed then return end
        c.hardcoreChosen = value or nil
        c.hardcore = value or nil
        if ns.refresh then ns.refresh() end
      end)
    Settings.CreateCheckbox(category, setting,
      "This character's death closes its book: an epitaph, and its journal joins the Hall of the Fallen. For this character only.")
  end

  Settings.RegisterAddOnCategory(category)
end

function ns.openSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
  return category ~= nil
end
