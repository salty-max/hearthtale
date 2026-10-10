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
local K = ns.kit

-- (minimapAngle: the button's place around the minimap, in degrees; 200 is
-- to the left, clear of the game's buttons and the siblings')
-- (welcomed: the welcome page was seen, Welcome.lua: never copied)
local DEFAULTS = { chat = true, toast = true, minimapHidden = false, minimapAngle = 200, welcomed = false }
local SHARED = { "chat", "toast", "minimapHidden", "minimapAngle" } -- (what a copy carries)

-- The profiles (Kit.lua): a code "HT1:c1:t1:h0:a200" (chat, toast, the
-- minimap button hidden, its angle; 0.7.0's "m", the button shown, is left
-- out of a code now).
local P = K.profiles({
  saved = function()
    if type(HearthtaleSettings) ~= "table" then HearthtaleSettings = {} end
    return HearthtaleSettings
  end,
  defaults = DEFAULTS,
  shared = SHARED,
  letters = { chat = "c", toast = "t", minimapHidden = "h", minimapAngle = "a" },
  tag = "HT1",
  changed = function(k)
    if (k == "minimapHidden" or k == "minimapAngle") and ns.updateMinimapButton then ns.updateMinimapButton() end
  end,
})
ns.profiles = P

-- This character's profile at its login: its own, else a new one (the
-- account's 0.6.0 values for a character who kept a journal before, the
-- defaults for a new one).
function ns.loadProfile(journal)
  P:load(function(profile, saved)
    if journal and journal.chapters and #journal.chapters > 0 then
      for _, k in ipairs(SHARED) do
        profile[k] = saved[k]
      end
    end
  end)
end
function ns.profileKey() return P:key() end
function ns.option(k) return P:get(k) end
function ns.setOption(k, value) P:set(k, value) end
function ns.otherProfiles() return P:others() end
function ns.copyProfile(other) return P:copy(other) end
function ns.exportCode() return P:export() end
function ns.importCode(code) return P:import(code) end

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
  K.copySetting(
    category,
    "HEARTHTALE_COPYFROM",
    P,
    "Another character's choices, for this one (of this game: Classic Era and Forever keep their own). From elsewhere: /ht export there, then /ht import CODE here.",
    function(other) print(ns.PREFIX .. ("%s's settings copied."):format(other)) end
  )

  Settings.RegisterAddOnCategory(category)
end

function ns.openSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
  return category ~= nil
end
