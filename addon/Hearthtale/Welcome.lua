-- The welcome: once per character, a few seconds after its first login (out
-- of combat; /ht welcome shows it again), a page in the books' look (Kit.lua)
-- laid out as the journal's window: on the left the logo and what the journal
-- is; on the right this character's choices (Settings.lua: a line in chat for
-- each entry, the minimap button, the alert when a Hardcore book closes, and
-- its Hardcore where the game can't tell), and how to take another
-- character's: picked from the characters of this game, or from a code
-- (/ht export there). Closing it, however, is enough to have seen it.
local _, ns = ...
local K = ns.kit
local T = K.T

local LOGO = "Interface\\AddOns\\Hearthtale\\Media\\Logo"
local W, H, ROW = 780, 500, 44 -- (H with three choices; ROW: one more)
local LEFT = 300 -- the left column's width
local TEXT = 412 -- the right column's text

local frame, right
local choices = {}
local picker, code -- another character's settings; a code's

local function say(text, colour)
  code.note:SetText(text or "")
  code.note:SetTextColor(unpack(colour or T.soft))
end

local function button(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  return b
end

local function heading(parent, text, anchor, gap)
  local h = K.label(parent, K.TITLE_FONT, 15, T.accent)
  if anchor then
    h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 16))
  else
    h:SetPoint("TOPLEFT", 24, -18)
  end
  h:SetText(text)
  local r = K.rule(parent)
  r:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -5)
  r:SetWidth(TEXT)
  return r
end

-- A choice: its box, its name and a line on what it does; the words tick the
-- box too. get/set: the setting behind it.
local function choice(parent, anchor, text, hint, get, set)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(TEXT, ROW - 6)
  row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  local box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  box:SetSize(26, 26)
  box:SetPoint("TOPLEFT", -4, 2)
  local name = K.label(row, K.BODY_FONT, 13, T.text)
  name:SetPoint("TOPLEFT", 28, -3)
  name:SetText(text)
  local note = K.label(row, K.BODY_FONT, 11, T.soft)
  note:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
  note:SetWidth(TEXT - 30)
  note:SetText(hint)
  box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  row:SetScript("OnClick", function()
    box:SetChecked(not box:GetChecked())
    set(box:GetChecked() and true or false)
  end)
  row.box, row.get = box, get
  table.insert(choices, row)
  return row
end

-- The choices as they are now (after a copy, an import).
local function refresh()
  for _, row in ipairs(choices) do
    row.box:SetChecked(row.get() and true or false)
  end
  local others = ns.otherProfiles()
  picker.others = others
  if picker.at > #others then picker.at = 1 end
  picker.name:SetText(others[picker.at] or "No other character yet")
  picker.name:SetTextColor(unpack(others[1] and T.text or T.soft))
  for _, b in ipairs({ picker.prev, picker.next }) do
    b:SetEnabled(#others > 1)
  end
  picker.copy:SetEnabled(#others > 0)
end
ns.refreshSettings = function()
  if frame and frame:IsShown() then refresh() end
end

-- Another character of this game: its name between arrows, and Copy.
local function arrow(parent, dir)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(24, 24)
  local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. dir .. "Page-"
  b:SetNormalTexture(base .. "Up")
  b:SetPushedTexture(base .. "Down")
  b:SetDisabledTexture(base .. "Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  return b
end
local function buildPicker(parent, anchor)
  picker = CreateFrame("Frame", nil, parent)
  picker:SetSize(TEXT, 26)
  picker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  picker.at = 1
  picker.prev = arrow(picker, "Prev")
  picker.prev:SetPoint("LEFT", 0, 0)
  picker.copy = button(picker, "Copy their choices", 150)
  picker.copy:SetPoint("RIGHT", 0, 0)
  picker.next = arrow(picker, "Next")
  picker.next:SetPoint("RIGHT", picker.copy, "LEFT", -8, 0)
  picker.name = K.label(picker, K.BODY_FONT, 13, T.text)
  picker.name:SetPoint("LEFT", picker.prev, "RIGHT", 4, 0)
  picker.name:SetPoint("RIGHT", picker.next, "LEFT", -4, 0)
  picker.name:SetJustifyH("CENTER")
  picker.name:SetWordWrap(false)
  local function step(d)
    local n = #picker.others
    if n == 0 then return end
    picker.at = (picker.at - 1 + d) % n + 1
    refresh()
  end
  picker.prev:SetScript("OnClick", function() step(-1) end)
  picker.next:SetScript("OnClick", function() step(1) end)
  picker.copy:SetScript("OnClick", function()
    local other = picker.others[picker.at]
    if other and ns.copyProfile(other) then
      refresh()
      say(("%s's choices are this character's now."):format(other), T.accent)
    end
  end)
  return picker
end

-- A code: this character's to copy (export), or one to paste (import).
local function buildCode(parent, anchor)
  code = CreateFrame("Frame", nil, parent)
  code:SetSize(TEXT, 54)
  code:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  code.export = button(code, "Give a code", 120)
  code.export:SetPoint("TOPLEFT", 0, 0)
  code.import = button(code, "Use a code", 120)
  code.import:SetPoint("LEFT", code.export, "RIGHT", 8, 0)
  code.box = CreateFrame("EditBox", nil, code, "InputBoxTemplate")
  code.box:SetSize(TEXT - 268, 22)
  code.box:SetPoint("LEFT", code.import, "RIGHT", 14, 0)
  code.box:SetAutoFocus(false)
  code.box:SetMaxLetters(64)
  code.note = K.label(code, K.BODY_FONT, 11, T.soft)
  code.note:SetPoint("TOPLEFT", code.export, "BOTTOMLEFT", 0, -8)
  code.note:SetWidth(TEXT)
  code.export:SetScript("OnClick", function() ns.showCode() end)
  code.import:SetScript("OnClick", function()
    code.mode = "import"
    code.box:SetText("")
    code.box:SetFocus()
    say("Paste the code (/ht export on the other character), then press Enter.")
  end)
  code.box:SetScript("OnEnterPressed", function(self)
    if code.mode ~= "import" then return self:ClearFocus() end
    if ns.importCode(self:GetText()) then
      self:ClearFocus()
      refresh()
      say("The code's choices are this character's now.", T.accent)
    else
      say("That isn't a Hearthtale settings code.", { 0.85, 0.32, 0.25 })
    end
  end)
  code.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return code
end

local function build()
  frame = K.gameWindow("HearthtaleWelcome", "Welcome to Hearthtale", "Interface\\Icons\\INV_Misc_Book_08")
    or K.dialog("HearthtaleWelcome", "Welcome to Hearthtale")
  local hardcoreAsked = not ns.gameKnowsHardcore()
  K.movable(frame, W, H + (hardcoreAsked and ROW or 0))
  frame:SetFrameStrata("DIALOG")
  local edge = 8

  -- Left: the logo and what the journal is.
  local left = K.panel(frame, true)
  left:SetPoint("TOPLEFT", edge, -58)
  left:SetPoint("BOTTOMLEFT", edge, edge)
  left:SetWidth(LEFT)
  local logo = left:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(LOGO)
  logo:SetSize(112, 112)
  logo:SetPoint("TOP", 0, -16)
  local title = K.label(left, K.TITLE_FONT, 30, T.accent)
  title:SetPoint("TOP", logo, "BOTTOM", 0, -8)
  title:SetJustifyH("CENTER")
  title:SetText("Hearthtale")
  local tagline = K.label(left, K.BODY_FONT, 12, T.soft)
  tagline:SetPoint("TOP", title, "BOTTOM", 0, -4)
  tagline:SetWidth(LEFT - 40)
  tagline:SetJustifyH("CENTER")
  tagline:SetText("Your character's own journal, written as you play.")
  local line = K.rule(left)
  line:SetPoint("TOP", tagline, "BOTTOM", 0, -12)
  line:SetWidth(LEFT - 40)
  local intro = K.label(left, K.BODY_FONT, 12, T.text)
  intro:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -12)
  intro:SetWidth(LEFT - 40)
  intro:SetSpacing(3)
  intro:SetText(
    "Play as you always do: Hearthtale keeps the record. The quests that mattered, the foes worth naming, "
      .. "the lands seen for the first time, the close calls.\n\n"
      .. "Each time you rest, at an inn, in a city or by a campfire, the road since the last rest becomes an "
      .. "entry in your character's own voice.\n\n"
      .. "On Hardcore, a death closes the book with an epitaph, and it joins the Hall of the Fallen."
  )

  -- Right: this character's choices, and another's.
  right = K.panel(frame)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 32)
  right:SetPoint("BOTTOMRIGHT", -edge, edge)
  local who = ns.profileKey and ns.profileKey()
  local last = heading(right, who and ("Choices for %s"):format(who:match("^(.-) %- ") or who) or "Your choices")
  last = choice(
    right,
    last,
    "A line in chat for each entry",
    "When you rest and an entry is written, with a link that opens it.",
    function() return ns.option("chat") end,
    function(v) ns.setOption("chat", v) end
  )
  last = choice(
    right,
    last,
    "The book by the minimap",
    "Click it to open the journal; drag it around the minimap.",
    function() return not ns.option("minimapHidden") end,
    function(v) ns.setOption("minimapHidden", not v) end
  )
  last = choice(
    right,
    last,
    "An alert when a book closes",
    "The game's own alert, when a Hardcore character falls.",
    function() return ns.option("toast") end,
    function(v) ns.setOption("toast", v) end
  )
  if hardcoreAsked then
    last = choice(
      right,
      last,
      "This character is Hardcore",
      "Its death will close its book. The game can't say so here.",
      ns.isHardcore,
      ns.setHardcore
    )
  end

  last = heading(right, "From another character", last, 14)
  last = buildPicker(right, last)
  last = buildCode(right, last)
  local footnote = K.label(right, K.BODY_FONT, 11, T.soft)
  footnote:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
  footnote:SetWidth(TEXT)
  footnote:SetText("Change them any time: /ht settings, or a right-click on the minimap button. /ht opens the journal.")

  local begin = button(right, "Begin", 110)
  begin:SetHeight(24)
  begin:SetPoint("BOTTOMRIGHT", -22, 16)
  begin:SetScript("OnClick", function() frame:Hide() end)
  local open = button(right, "Open the journal", 150)
  open:SetHeight(24)
  open:SetPoint("RIGHT", begin, "LEFT", -8, 0)
  open:SetScript("OnClick", function()
    frame:Hide()
    if ns.toggle then ns.toggle() end
  end)

  frame:SetScript("OnShow", function()
    say("")
    code.mode = nil
    code.box:SetText("")
    refresh()
  end)
  frame:SetScript("OnHide", function() ns.setOption("welcomed", true) end)
  ns.welcomeFrame, ns.welcomeChoices, ns.welcomePicker, ns.welcomeCode = frame, choices, picker, code -- (for the tests)
end

-- The welcome; "export": with this character's code ready to copy.
function ns.showWelcome(mode)
  if not frame then build() end
  frame:Show()
  if mode == "export" then ns.showCode() end
end
function ns.showCode()
  if not frame then return ns.showWelcome("export") end
  code.mode = "export"
  code.box:SetText(ns.exportCode())
  code.box:SetFocus()
  code.box:HighlightText()
  say("Copy it (Ctrl+C), then on another character: Use a code, or /ht import CODE.")
end

-- On each character's first login with the addon: a few seconds after the
-- world appears, once out of combat.
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
