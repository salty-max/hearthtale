-- The journal's button on the minimap: click to open the journal, right-click
-- for the settings, drag to move it around the minimap. Its place (and whether
-- it shows) is kept with this character's settings (Settings.lua). Built
-- with the textures of the game's own minimap buttons (the tracking button's
-- border, the zoom highlight), as its siblings'.
local _, ns = ...

local button

local function place()
  local angle = math.rad(ns.option("minimapAngle"))
  local r = Minimap:GetWidth() / 2 + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

-- While dragging: the angle from the minimap's centre to the cursor.
local function follow()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  ns.setOption("minimapAngle", math.deg(math.atan2(cy / scale - my, cx / scale - mx)))
  place()
end

-- What the tooltip says of the journal: its chapters, the Hall.
local function summary()
  local c = ns.journal()
  local chapters = #(c and c.chapters or {})
  local fallen = #ns.fallen()
  return chapters, fallen
end

function ns.createMinimapButton()
  if button then return end
  button = CreateFrame("Button", "HearthtaleMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_08")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      ns.openSettings()
    else
      ns.toggle()
    end
  end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", follow) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Hearthtale")
    local chapters, fallen = summary()
    GameTooltip:AddLine(chapters == 1 and "1 entry" or ("%d entries"):format(chapters), 1, 1, 1)
    if fallen > 0 then
      GameTooltip:AddLine(
        fallen == 1 and "1 book in the Hall of the Fallen" or ("%d books in the Hall of the Fallen"):format(fallen),
        1,
        1,
        1
      )
    end
    GameTooltip:AddLine(
      "Click to open the journal, right-click for the settings. Drag to move this button.",
      0.7,
      0.7,
      0.7,
      true
    )
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  place()
  ns.updateMinimapButton()
end

function ns.updateMinimapButton()
  if not button then return end
  place()
  button:SetShown(not ns.option("minimapHidden"))
end
