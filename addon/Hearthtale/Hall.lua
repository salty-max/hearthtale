-- The Hall of the Fallen (account-wide, HearthtaleHall.lives[guid]):
-- the closed books of Hardcore characters, kept whole. What is kept is their
-- records (the text is written when read, as any journal's, and saved at
-- logout for the site: Save.lua), with their realm
-- and the game's names of their race and class. A Hardcore death closes the
-- book: a chat line with a link to it, and the game's toast (the one of "New
-- Recipe Learned"), the character's portrait in it; a click opens the Hall.
local _, ns = ...

local function hall()
  if type(HearthtaleHall) ~= "table" then HearthtaleHall = {} end
  HearthtaleHall.lives = HearthtaleHall.lives or {}
  return HearthtaleHall.lives
end

-- The fallen, the most recent first.
function ns.fallen()
  local list = {}
  for _, life in pairs(hall()) do table.insert(list, life) end
  table.sort(list, function(a, b)
    local x, y = a.death and a.death.at or 0, b.death and b.death.at or 0
    if x ~= y then return x > y end
    return (a.name or "") < (b.name or "")
  end)
  return list
end
function ns.fallenLife(guid) return hall()[guid] end

-- The book joins the Hall: a copy of the records as they were at the end.
local function enshrine(c)
  local life = ns.copy(c)
  life.pending, life.book = nil, nil -- its book is written at the next logout, with the death
  life.realm = GetRealmName and GetRealmName() or nil
  life.raceName, life.className = UnitRace("player"), UnitClass("player")
  hall()[c.guid] = life
  return life
end

-- ── the toast ────────────────────────────────────────────────────────────────
local TOAST = "NewRecipeLearnedAlertFrameTemplate"
local toasts

local function onToastClick(self, button, down)
  if AlertFrame_OnClick and AlertFrame_OnClick(self, button, down) then return end -- right-click: dismissed
  if self.hearthtaleLife then ns.openHall(self.hearthtaleLife) end
end

local function setUp(frame, guid)
  local life = hall()[guid]
  if not life then return end
  frame.hearthtaleLife = guid
  -- Round, as the window's portrait: a mask texture (Texture:SetMask, the
  -- recipe toast's own way, forbids changing the crop afterwards on Forever).
  if not frame.hearthtaleMask and frame.CreateMaskTexture then
    frame.hearthtaleMask = frame:CreateMaskTexture()
    frame.hearthtaleMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.hearthtaleMask:SetAllPoints(frame.Icon)
    frame.Icon:AddMaskTexture(frame.hearthtaleMask)
  end
  if SetPortraitTexture then SetPortraitTexture(frame.Icon, "player") end
  frame.Title:SetText("The book is closed")
  frame.Name:SetText(life.name or "")
  if AlertFrame_SetDuration then AlertFrame_SetDuration(frame, 20) end
  frame:SetScript("OnClick", onToastClick)
end

local function toast(guid)
  if not toasts then
    if not (AlertFrame and AlertFrame.AddQueuedAlertFrameSubSystem and C_XMLUtil and C_XMLUtil.GetTemplateInfo) then return end
    if not C_XMLUtil.GetTemplateInfo(TOAST) then return end
    toasts = AlertFrame:AddQueuedAlertFrameSubSystem(TOAST, setUp, 2, 6)
  end
  toasts:AddAlert(guid)
end

-- ── a Hardcore death ─────────────────────────────────────────────────────────
local function link(guid, text) return ns.link("hall:" .. guid, text) end

ns.onDeath = function()
  local c = ns.journal()
  if not (c and c.hardcore and c.guid) then return end
  enshrine(c)
  print(ns.PREFIX .. ("The journal of %s is closed. It rests in the %s."):format(c.name or "?", link(c.guid, "Hall of the Fallen")))
  if ns.option("toast") then toast(c.guid) end
  if ns.onHall then ns.onHall() end
end

-- A closed book missing from the Hall (the account's saved data lost, or the
-- death came with the addon off): it joins it at login.
ns.onLogin = function(c)
  if c.closed and c.guid and not hall()[c.guid] then enshrine(c) end
end
