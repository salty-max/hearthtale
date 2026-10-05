-- The journal as a book, in a standard game window, as its siblings
-- (Lorekeeper's Codex, Explorer's Field Journal): the character's portrait in
-- the corner, who they are beside it. On the left, the prologue (a character
-- met mid-life) and a chapter per level, its place under it, a skull for a
-- close call, a star for a rare; on the right, the open chapter. Light text and
-- gold titles on dark panels: Forever's Professions cards; on Classic, the
-- game's insets and the quest log's dark book behind the list. The text is
-- written from the records each time it is shown (Writer.lua). /wayfarer
-- opens it.
local _, ns = ...

-- ── look ─────────────────────────────────────────────────────────────────────
local T = {
  gold = { 0.85, 0.70, 0.42 }, text = { 0.93, 0.88, 0.76 }, soft = { 0.62, 0.57, 0.49 },
  rule = { 0.85, 0.70, 0.42, 0.25 },
}
local LATIN = { enUS = true, enGB = true, frFR = true, deDE = true, esES = true, esMX = true, itIT = true, ptBR = true }
local BODY_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local TITLE_FONT = (not GetLocale or LATIN[GetLocale()]) and "Fonts\\MORPHEUS.TTF" or BODY_FONT
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

local function label(parent, font, size, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(font, size, "")
  fs:SetTextColor(unpack(color))
  fs:SetShadowOffset(1, -1)
  fs:SetJustifyH("LEFT")
  return fs
end

local function rule(parent)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(unpack(T.rule))
  t:SetHeight(1)
  return t
end

-- Forever's Professions card (a dark rounded panel), cut in nine so it
-- stretches to any size without bending its corners.
local CARD_FILE, CARD_W, CARD_H = 8164414, 1024, 512
local CARD = { 1, 665, 1, 143 } -- the generic card, in the texture's pixels
local CORNER = 16
local function card(parent)
  local f = CreateFrame("Frame", nil, parent)
  local xs = { CARD[1], CARD[1] + CORNER, CARD[2] - CORNER, CARD[2] }
  local ys = { CARD[3], CARD[3] + CORNER, CARD[4] - CORNER, CARD[4] }
  for i = 1, 3 do
    for j = 1, 3 do
      local tex = f:CreateTexture(nil, "BACKGROUND")
      tex:SetTexture(CARD_FILE)
      tex:SetTexCoord(xs[j] / CARD_W, xs[j + 1] / CARD_W, ys[i] / CARD_H, ys[i + 1] / CARD_H)
      if j ~= 2 then tex:SetWidth(CORNER) end
      if i ~= 2 then tex:SetHeight(CORNER) end
      -- Corners pinned to the frame's edges; edges and centre between them.
      if j == 1 then tex:SetPoint("LEFT", f, "LEFT", 0, 0) end
      if j == 2 then
        tex:SetPoint("LEFT", f, "LEFT", CORNER, 0)
        tex:SetPoint("RIGHT", f, "RIGHT", -CORNER, 0)
      end
      if j == 3 then tex:SetPoint("RIGHT", f, "RIGHT", 0, 0) end
      if i == 1 then tex:SetPoint("TOP", f, "TOP", 0, 0) end
      if i == 2 then
        tex:SetPoint("TOP", f, "TOP", 0, -CORNER)
        tex:SetPoint("BOTTOM", f, "BOTTOM", 0, CORNER)
      end
      if i == 3 then tex:SetPoint("BOTTOM", f, "BOTTOM", 0, 0) end
    end
  end
  return f
end

-- Classic's panels: the game's inset, darkened a little for the text; behind
-- the list, the quest log's dark book (TBC's two-pane log, where the game has it).
local function inset(parent, book)
  local ok, f = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
  if not (ok and f) then f = CreateFrame("Frame", nil, parent) end
  local shade = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  shade:SetPoint("TOPLEFT", 3, -3)
  shade:SetPoint("BOTTOMRIGHT", -3, 3)
  shade:SetColorTexture(0.03, 0.025, 0.02, 0.55)
  if not book then return f end
  local art = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  art:SetPoint("TOPLEFT", 3, -3)
  art:SetPoint("BOTTOMRIGHT", -3, 3)
  if art:SetTexture("Interface\\QuestFrame\\UI-QuestLogDualPane-Left") == false then
    art:Hide()
  else
    art:SetTexCoord(20 / 512, 318 / 512, 74 / 512, 406 / 512)
  end
  return f
end

local function panel(parent, book)
  if ns.forever then return card(parent) end
  return inset(parent, book)
end

-- A scroll area moved by the mouse wheel, with a thin gold thumb.
local function scrollArea(name, parent, width)
  local s = CreateFrame("ScrollFrame", name, parent)
  local c = CreateFrame("Frame", nil, s)
  c:SetSize(width, 1)
  s:SetScrollChild(c)
  s.child = c
  s.thumb = s:CreateTexture(nil, "OVERLAY")
  s.thumb:SetColorTexture(0.85, 0.70, 0.42, 0.45)
  s.thumb:SetWidth(3)
  function s:Range() return math.max(0, self.child:GetHeight() - self:GetHeight()) end
  function s:UpdateThumb()
    local range, height = self:Range(), self:GetHeight()
    if range <= 0 then
      self.thumb:Hide()
      return
    end
    local size = math.max(24, height * height / (height + range))
    self.thumb:SetHeight(size)
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 8, -(height - size) * math.min(1, self:GetVerticalScroll() / range))
    self.thumb:Show()
  end
  function s:ScrollTo(y)
    self:SetVerticalScroll(math.max(0, math.min(y, self:Range())))
    self:UpdateThumb()
  end
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, delta) self:ScrollTo(self:GetVerticalScroll() - delta * 40) end)
  return s
end

-- ── the book ─────────────────────────────────────────────────────────────────
local book, list, page
local build -- made on first opening (below)
local written -- the book as last written: { prologue, chapters }
local current -- the open chapter: a level, or "prologue"
local WIDTH = 440
local HEADER_H = 76
local ROW_WIDTH = 204

local function day(at) return at and date("%d %b %Y", at) end

-- When a chapter was lived: "5 Oct 2026", "5 Oct 2026 to 7 Oct 2026".
local function when(ch)
  local l = ns.journal().levels[ch.level] or {}
  local from, to = day(l.start and l.start.at), day(l.ended)
  if not from then return nil end
  if not to or to == from then return from end
  return from .. " to " .. to
end

local function showChapter(key)
  current = key
  local title, sub, text
  if key == "prologue" then
    local p = ns.journal().prologue or {}
    title, sub = "Prologue", ("Before this journal, at level %d"):format(p.level or 0)
    text = written.prologue
  else
    local ch
    for _, c in ipairs(written.chapters) do if c.level == key then ch = c end end
    if not ch then return end
    local l = ns.journal().levels[ch.level] or {}
    title = ("Level %d"):format(ch.level)
    local parts = {}
    if ch.place then table.insert(parts, ch.place) end
    table.insert(parts, when(ch))
    if not l.ended then table.insert(parts, "still being written") end
    sub = table.concat(parts, "  -  ")
    text = ch.text
  end
  page.title:SetText(title)
  page.sub:SetText(sub)
  page.body:SetTextColor(unpack(text and T.text or T.soft))
  page.body:SetText(text or "Nothing written yet.")
  page.child:SetHeight(HEADER_H + page.body:GetStringHeight() + 24)
  page:ScrollTo(0)
end

local rows = {}
ns.bookRows = rows -- for the tests
local function row(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, list.child)
  r:SetSize(ROW_WIDTH, 34)
  r.title = label(r, TITLE_FONT, 14, T.gold)
  r.title:SetPoint("TOPLEFT", 8, -3)
  r.place = label(r, BODY_FONT, 11, T.soft)
  r.place:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -2)
  r.place:SetPoint("RIGHT", -8, 0)
  r.place:SetWordWrap(false)
  -- Marks: a skull for a close call, a star for a rare.
  r.marks = {}
  for m, file in ipairs({ SKULL, STAR }) do
    local t = r:CreateTexture(nil, "ARTWORK")
    t:SetTexture(file)
    t:SetSize(12, 12)
    r.marks[m] = t
  end
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  r.selected = r:CreateTexture(nil, "BACKGROUND")
  r.selected:SetAllPoints()
  r.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  r.selected:SetBlendMode("ADD")
  r.selected:SetAlpha(0.7)
  rows[i] = r
  return r
end

-- Rewrite the book from the records and show it. latest: open the last chapter
-- (opening the book), else keep the open one.
function ns.refresh(latest)
  if not book then return end
  local c = ns.journal()
  if not c then return end
  written = ns.writeBook(c)
  -- Who I am, beside the portrait.
  local race, class = UnitRace("player"), UnitClass("player")
  book.who:SetText(("%s, level %d %s %s%s"):format(UnitName("player") or "", UnitLevel("player") or 0, race or "", class or "",
    c.hardcore and "  -  Hardcore" or ""))

  local entries = {}
  if written.prologue then table.insert(entries, { key = "prologue", title = "Prologue", place = "Before this journal" }) end
  for _, ch in ipairs(written.chapters) do
    table.insert(entries, { key = ch.level, title = ("Level %d"):format(ch.level), place = ch.place, close = ch.close, rare = ch.rare })
  end
  local known = false
  for _, e in ipairs(entries) do if e.key == current then known = true end end
  if latest or not known then current = entries[#entries] and entries[#entries].key end

  for _, r in ipairs(rows) do r:Hide() end
  local y, currentY = 0, 0
  for i, e in ipairs(entries) do
    local r = row(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r.key = e.key
    r.title:SetText(e.title)
    r.place:SetText(e.place or "")
    local x = -8
    local marks = { e.close, e.rare }
    for m = 1, 2 do -- not ipairs: it stops at the first chapter without a close call
      local on, t = marks[m], r.marks[m]
      t:ClearAllPoints()
      if on then
        t:SetPoint("TOPRIGHT", r, "TOPRIGHT", x, -5)
        x = x - 14
      end
      t:SetShown(on and true or false)
    end
    r.selected:SetShown(e.key == current)
    if e.key == current then currentY = y end
    r:SetScript("OnClick", function() showChapter(e.key); ns.refresh() end)
    r:Show()
    y = y + 36
  end
  list.child:SetHeight(y + 8)
  list:UpdateThumb()
  -- Opening the book: the last chapter in view.
  if latest then list:ScrollTo(currentY) end
  if current then showChapter(current) end
end

-- The standard game window (portrait, title bar), its inset removed; the
-- portrait is the character's own face.
local TITLE = "Wayfarer's Journal"
local function gameWindow()
  local ok, frame = pcall(CreateFrame, "Frame", "WayfarersJournalFrame", UIParent, "ButtonFrameTemplate")
  if not ok or not frame then return nil end
  if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(frame) end
  if type(frame.Inset) == "table" then frame.Inset:Hide() end
  if frame.SetTitle then frame:SetTitle(TITLE)
  elseif type(frame.TitleText) == "table" then frame.TitleText:SetText(TITLE) end
  return frame
end

local function portrait()
  local p = (book.GetPortrait and book:GetPortrait()) or (type(book.portrait) == "table" and book.portrait)
    or (type(book.PortraitContainer) == "table" and book.PortraitContainer.portrait) or nil
  if p and SetPortraitTexture then SetPortraitTexture(p, "player")
  elseif book.SetPortraitToAsset then book:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_08") end
end

function build()
  local window = gameWindow()
  book = window or CreateFrame("Frame", "WayfarersJournalFrame", UIParent, "BackdropTemplate")
  book:SetSize(780, 560)
  book:SetPoint("CENTER")
  book:SetFrameStrata("HIGH")
  book:SetToplevel(true)
  book:SetMovable(true)
  book:EnableMouse(true)
  book:SetClampedToScreen(true)
  book:RegisterForDrag("LeftButton")
  book:SetScript("OnDragStart", book.StartMoving)
  book:SetScript("OnDragStop", book.StopMovingOrSizing)
  table.insert(UISpecialFrames, "WayfarersJournalFrame") -- Escape closes it
  if not window then
    -- No standard window on this client: a plain dialog frame.
    book:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    local title = label(book, TITLE_FONT, 16, T.gold)
    title:SetPoint("TOP", 0, -16)
    title:SetText(TITLE)
    local close = CreateFrame("Button", nil, book, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
  end
  local edge = window and 8 or 14

  -- Who I am, beside the portrait.
  book.who = label(book, BODY_FONT, 11, T.gold)
  book.who:SetPoint("TOPLEFT", 64, -36)

  -- Left: the chapters.
  local left = panel(book, true)
  book.left = left
  left:SetPoint("TOPLEFT", edge, -58)
  left:SetPoint("BOTTOMLEFT", edge, edge)
  left:SetWidth(244)
  list = scrollArea("WayfarersJournalList", left, ROW_WIDTH)
  list:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -12)
  list:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -18, 12)

  -- Right: the chapter.
  local sheet = panel(book)
  book.sheet = sheet
  sheet:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 32)
  sheet:SetPoint("BOTTOMRIGHT", -edge, edge)
  page = scrollArea("WayfarersJournalPage", sheet, WIDTH)
  page:SetPoint("TOPLEFT", sheet, "TOPLEFT", 26, -22)
  page:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -22, 14)

  page.title = label(page.child, TITLE_FONT, 24, T.gold)
  page.title:SetPoint("TOPLEFT", 0, -10)
  page.title:SetWidth(WIDTH)
  page.title:SetWordWrap(false)
  page.sub = label(page.child, BODY_FONT, 12, T.soft)
  page.sub:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -7)
  page.sub:SetWidth(WIDTH)
  local headerRule = rule(page.child)
  headerRule:SetPoint("TOPLEFT", 0, -62)
  headerRule:SetPoint("TOPRIGHT", 0, -62)
  page.body = label(page.child, BODY_FONT, 13, T.text)
  page.body:SetPoint("TOPLEFT", 0, -HEADER_H)
  page.body:SetWidth(WIDTH)
  page.body:SetSpacing(4)

  book:SetScript("OnShow", function()
    portrait()
    ns.refresh(true)
  end)
end

function ns.toggle()
  if not ns.journal() then return end
  if not book then build() end
  book:SetShown(not book:IsShown())
end

-- A new moment while the book is open: rewritten a moment later, once (a fight
-- records many at once).
local pending = false
ns.onRecord = function()
  if not (book and book:IsShown()) or pending then return end
  pending = true
  local function later()
    pending = false
    if book:IsShown() then ns.refresh() end
  end
  if C_Timer then C_Timer.After(1, later) else later() end
end
