-- The welcome: on the account's first login with Hearthtale (and with /ht
-- welcome), a page in the books' look (Kit.lua) with the logo: what the
-- journal is, in a few lines, and the choices the Options page holds (a line
-- in chat for each entry, the minimap button, the alert when a Hardcore book
-- closes; this character's Hardcore where the game can't tell). Seen once:
-- closing it, however, is enough.
local _, ns = ...
local K = ns.kit
local T = K.T

local LOGO = "Interface\\AddOns\\Hearthtale\\Media\\Logo"
local W, H, ROW = 470, 650, 46 -- (H with three choices; ROW: one more)
local INNER = W - 76 -- the text's width, inside the panel

local frame
local checks = {}

-- A choice: its box, its name and a line on what it does; the words tick the
-- box too. get/set: the setting behind it.
local function choice(parent, anchor, text, hint, get, set)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(INNER, ROW - 6)
  row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  local box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  box:SetSize(26, 26)
  box:SetPoint("TOPLEFT", -4, 2)
  local name = K.label(row, K.BODY_FONT, 13, T.text)
  name:SetPoint("TOPLEFT", 28, -3)
  name:SetText(text)
  local note = K.label(row, K.BODY_FONT, 11, T.soft)
  note:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
  note:SetWidth(INNER - 30)
  note:SetText(hint)
  box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  row:SetScript("OnClick", function()
    box:SetChecked(not box:GetChecked())
    set(box:GetChecked() and true or false)
  end)
  row.box, row.get = box, get
  table.insert(checks, row)
  return row
end

local function button(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 24)
  b:SetText(text)
  return b
end

local function build()
  frame = K.gameWindow("HearthtaleWelcome", "Hearthtale", "Interface\\Icons\\INV_Misc_Book_08")
    or K.dialog("HearthtaleWelcome", "Hearthtale")
  K.movable(frame, W, H + (ns.gameKnowsHardcore() and 0 or ROW))
  frame:SetFrameStrata("DIALOG")
  local card = K.panel(frame)
  card:SetPoint("TOPLEFT", 8, -26)
  card:SetPoint("BOTTOMRIGHT", -8, 8)

  local logo = card:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(LOGO)
  logo:SetSize(96, 96)
  logo:SetPoint("TOP", 0, -20)
  local title = K.label(card, K.TITLE_FONT, 28, T.accent)
  title:SetPoint("TOP", logo, "BOTTOM", 0, -12)
  title:SetJustifyH("CENTER")
  title:SetText("Hearthtale")
  local tagline = K.label(card, K.BODY_FONT, 13, T.soft)
  tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
  tagline:SetJustifyH("CENTER")
  tagline:SetText("Your character's own journal, written as you play.")
  local line = K.rule(card)
  line:SetPoint("TOP", tagline, "BOTTOM", 0, -14)
  line:SetWidth(INNER)

  local intro = K.label(card, K.BODY_FONT, 13, T.text)
  intro:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -14)
  intro:SetWidth(INNER)
  intro:SetSpacing(3)
  intro:SetText(
    "Play as you always do: Hearthtale keeps the record. The quests that mattered, the foes worth naming, "
      .. "the lands seen for the first time, the close calls. Each time you rest, at an inn, in a city or by a "
      .. "campfire, the road since the last rest becomes an entry in your character's own voice.\n\n"
      .. "On Hardcore, a death closes the book with an epitaph, and it joins the Hall of the Fallen."
  )

  local heading = K.label(card, K.TITLE_FONT, 15, T.accent)
  heading:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -18)
  heading:SetText("A few choices")
  local under = K.rule(card)
  under:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
  under:SetWidth(INNER)

  local last = choice(
    card,
    under,
    "A line in chat for each entry",
    "When you rest and an entry is written, with a link that opens it.",
    function() return ns.option("chat") end,
    function(v) ns.setOption("chat", v) end
  )
  last = choice(
    card,
    last,
    "The book by the minimap",
    "Click it to open the journal; drag it around the minimap.",
    function() return not ns.option("minimapHidden") end,
    function(v) ns.setOption("minimapHidden", not v) end
  )
  last = choice(
    card,
    last,
    "An alert when a book closes",
    "The game's own alert, when a Hardcore character falls.",
    function() return ns.option("toast") end,
    function(v) ns.setOption("toast", v) end
  )
  if not ns.gameKnowsHardcore() then
    last = choice(
      card,
      last,
      "This character is Hardcore",
      "Its death will close its book. For this character only: the game can't say.",
      ns.isHardcore,
      ns.setHardcore
    )
  end

  local footnote = K.label(card, K.BODY_FONT, 11, T.soft)
  footnote:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
  footnote:SetWidth(INNER)
  footnote:SetSpacing(2)
  footnote:SetText(
    "Change them any time: /ht settings, or a right-click on the minimap button. /ht opens the journal. "
      .. "To read it on your phone too: hearthtale.app."
  )

  local begin = button(card, "Begin", 110)
  begin:SetPoint("BOTTOMRIGHT", -22, 18)
  begin:SetScript("OnClick", function() frame:Hide() end)
  local open = button(card, "Open the journal", 150)
  open:SetPoint("RIGHT", begin, "LEFT", -8, 0)
  open:SetScript("OnClick", function()
    frame:Hide()
    if ns.toggle then ns.toggle() end
  end)

  frame:SetScript("OnShow", function()
    for _, row in ipairs(checks) do
      row.box:SetChecked(row.get() and true or false)
    end
  end)
  frame:SetScript("OnHide", function() ns.setOption("welcomed", true) end)
  ns.welcomeFrame, ns.welcomeChoices = frame, checks -- (for the tests)
end

function ns.showWelcome()
  if not frame then build() end
  frame:Show()
end

-- On the account's first login with the addon: a few seconds after the world
-- appears, once out of combat.
local events = CreateFrame("Frame")
local function welcome()
  if ns.option("welcomed") or not ns.journal() then return end
  if InCombatLockdown() then return events:RegisterEvent("PLAYER_REGEN_ENABLED") end
  ns.showWelcome()
end
events:SetScript("OnEvent", function(self, event, initial)
  if event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    welcome()
  elseif initial then
    C_Timer.After(4, welcome)
  end
end)
events:RegisterEvent("PLAYER_ENTERING_WORLD")
