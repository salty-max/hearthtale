-- The journal's button on the minimap (the kit's: Kit.lua): click to open the
-- journal, right-click for its settings, drag to move it around the minimap.
-- Its place (and whether it shows) is kept with this character's settings
-- (Settings.lua).
local _, ns = ...
local K = ns.kit
local L = K.L

local M

function ns.createMinimapButton()
  if M then return end
  M = K.minimapButton({
    name = "HearthtaleMinimapButton",
    icon = "Interface\\AddOns\\Hearthtale\\Media\\Logo",
    crop = true,
    title = "Hearthtale",
    -- what the tooltip says of the journal: its chapters, the Hall
    lines = function()
      local c = ns.journal()
      local chapters = #(c and c.chapters or {})
      local fallen = #ns.fallen()
      local out = { K.plural(chapters, "%d entry", "%d entries"):format(chapters) }
      if fallen > 0 then
        table.insert(
          out,
          K.plural(fallen, "%d book in the Hall of the Fallen", "%d books in the Hall of the Fallen"):format(fallen)
        )
      end
      return out
    end,
    hint = L["Click to open the journal, right-click for the settings. Drag to move this button."],
    click = function() ns.toggle() end,
    rightClick = function() ns.openSettings() end,
    get = ns.option,
    set = ns.setOption,
  })
end

function ns.updateMinimapButton()
  if M then M:update() end
end
