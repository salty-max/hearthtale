-- The journal as a book, in a standard game window, as its siblings
-- (Lorekeeper's Codex, Explorer's Field Journal): the character's portrait in
-- the corner, who they are beside it. Two tabs. The Journal: on the left, the
-- prologue (a character met mid-life) and the chapters (one from rest to rest),
-- where each closed and the levels it covers under it, a skull for a close
-- call, a star for a rare; on the right, the open chapter as its diary entry
-- (Diary.lua), the journal as the character writes it (a closed book's last
-- one ends with its epitaph, in the accent). The Hall of the Fallen
-- (Hall.lua): the closed books of the account's Hardcore characters, the open
-- one's epitaph and chapters under its name. The siblings' look, from the
-- shared kit (Kit.lua), in an ember theme: light text and warm titles on dark
-- panels (Forever's Professions cards; on Classic, the game's insets and the
-- quest log's dark book behind the list). The text is written from the
-- records each time it is shown (Diary.lua). /hearthtale opens it.
local _, ns = ...

-- ── look ─────────────────────────────────────────────────────────────────────
-- The kit's (Kit.lua), in Hearthtale's own theme: the embers of a fire at
-- rest, a warm accent over panels a shade warmer.
local K = ns.kit
K.theme({
  accent = { 0.93, 0.62, 0.38 },
  ring = { 0.80, 0.46, 0.26 },
  bar = { 0.90, 0.50, 0.20 },
  tint = { 1.00, 0.90, 0.82 },
  shade = { 0.05, 0.025, 0.015, 0.55 },
  highlight = { 1.00, 0.78, 0.60 },
})
local T = K.T
local label, rule, panel = K.label, K.rule, K.panel
local BODY_FONT, TITLE_FONT = K.BODY_FONT, K.TITLE_FONT
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

-- ── the book ─────────────────────────────────────────────────────────────────
local book, list, page
local build -- made on first opening (below)
local written -- this character's book as last written: { prologue, chapters, epitaph }
local current -- its open chapter: a number, or "prologue"
local hallLife, hallKey -- in the Hall: the open life (its guid) and its page ("epitaph", "prologue", a chapter's number)
local asked -- opened at a page (a link): don't go to the last chapter
local WIDTH = 440
local HEADER_H = 92
local ROW_WIDTH = 204
local EPITAPH = K.hex(T.accent) .. "%s|r" -- the epitaph, in the accent
local NOTE = K.hex(T.accent) .. "Note|r\n|cffbfb08f%s|r" -- the player's own, in the margin

local DOT = "  \194\183  " -- (a middle dot between the parts of a line)

local function day(at)
  if not at then return nil end
  local t = date("*t", at)
  return ("%d %s %d"):format(t.day, date("%b", at), t.year)
end

-- When a chapter was lived, as short as it reads: "5 Oct 2026", "5 to 7 Oct
-- 2026", "30 Sep to 2 Oct 2026", "30 Dec 2026 to 2 Jan 2027".
local function when(ch)
  local c = ch.chapter
  local a, b = c.start and c.start.at, c.ended and c.ended.at
  if not a then return nil end
  if not b or day(a) == day(b) then return day(a) end
  local ta, tb = date("*t", a), date("*t", b)
  if ta.year ~= tb.year then return day(a) .. " to " .. day(b) end
  if ta.month ~= tb.month then return ("%d %s to %s"):format(ta.day, date("%b", a), day(b)) end
  return ("%d to %s"):format(ta.day, day(b))
end

-- The levels a chapter covers: "level 12", "levels 11 to 13".
local function levels(ch)
  if ch.from == ch.to then return ("level %d"):format(ch.from) end
  return ("levels %d to %d"):format(ch.from, ch.to)
end

-- A page's header: a line above its title (what it is, how it stands), the
-- title, and one line under it (where, which levels, when), never wrapped.
local function upper(parts) return table.concat(parts, DOT):upper() end
local function line(parts)
  local s = table.concat(parts, DOT)
  return s:sub(1, 1):upper() .. s:sub(2)
end
local function show(over, title, sub, text)
  page.over:SetText(over or "")
  page.title:SetText(title)
  page.sub:SetText(sub or "")
  page.body:SetTextColor(unpack(text and T.text or T.soft))
  page.body:SetText(text or "Nothing written yet.")
  page.child:SetHeight(HEADER_H + page.body:GetStringHeight() + 24)
  page:ScrollTo(0)
end

-- A page of a book (mine or a fallen one's): the prologue, a chapter (the last
-- one of a closed book ends with its epitaph), or the epitaph alone.
local function showPage(life, w, key)
  if key == "prologue" then
    local p = life.prologue or {}
    return show(
      upper({ "Before this journal" }),
      "Prologue",
      line({ ("taken up at level %d"):format(p.level or 0) }),
      w.prologue
    )
  end
  if key == "epitaph" then
    local d = life.death or {}
    local sub = { ("Level %d %s %s"):format(d.level or 0, life.raceName or "", life.className or "") }
    if life.realm then table.insert(sub, life.realm) end
    table.insert(sub, day(d.at))
    return show(upper({ "Hardcore", "fallen" }), life.name or "", line(sub), w.epitaph and EPITAPH:format(w.epitaph))
  end
  local ch = w.chapters[key]
  if not ch then return end
  local over = {}
  if ch.title then table.insert(over, ("Entry %d"):format(key)) end
  local last = key == #w.chapters
  if life.closed and last then
    table.insert(over, "the end")
  elseif ch.open then
    table.insert(over, "still being written")
  end
  local parts = {}
  if ch.place then table.insert(parts, ch.place) end
  table.insert(parts, levels(ch))
  table.insert(parts, when(ch))
  local text = ch.text
  if ch.note then text = (text and text .. "\n\n" or "") .. NOTE:format(ch.note) end
  if life.closed and last and w.epitaph then text = (text and text .. "\n\n" or "") .. EPITAPH:format(w.epitaph) end
  show(upper(over), ch.title or ("Entry %d"):format(key), line(parts), text)
end

local rows = {}
ns.bookRows = rows -- for the tests
local function row(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, list.child)
  r:SetSize(ROW_WIDTH, 34)
  r.title = label(r, TITLE_FONT, 14, T.gold)
  r.title:SetWordWrap(false) -- (a long title cut short, never over the marks)
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
  r.selected = K.highlight(r)
  rows[i] = r
  return r
end

-- The list: { title, place, close, rare, indent, selected, click } per row.
-- scroll: bring the selected row into view.
local function render(entries, scroll)
  for _, r in ipairs(rows) do
    r:Hide()
  end
  local y, selectedY = 0, nil
  for i, e in ipairs(entries) do
    local r = row(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r.key = e.key
    r.title:ClearAllPoints()
    r.title:SetPoint("TOPLEFT", 8 + (e.indent or 0), -3)
    r.title:SetPoint("RIGHT", r, "RIGHT", -36, 0)
    r.title:SetFont(TITLE_FONT, e.indent and 13 or 14, "")
    r.title:SetTextColor(unpack(e.click and T.gold or T.soft))
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
    r.selected:SetShown(e.selected and true or false)
    if e.selected then selectedY = y end
    r:SetScript("OnClick", e.click)
    if e.click then
      r:Enable()
    else
      r:Disable()
    end
    r:Show()
    y = y + 36
  end
  list.child:SetHeight(y + 8)
  list:UpdateThumb()
  if scroll and selectedY then list:ScrollTo(selectedY) end
end

-- A book's chapters as rows (indent: under a fallen life's name).
local function chapterRows(entries, w, selectedKey, open, indent)
  if w.epitaph and indent then
    table.insert(entries, {
      key = "epitaph",
      title = "Epitaph",
      indent = indent,
      selected = selectedKey == "epitaph",
      click = function() open("epitaph") end,
    })
  end
  if w.prologue then
    table.insert(entries, {
      key = "prologue",
      title = "Prologue",
      place = "Before this journal",
      indent = indent,
      selected = selectedKey == "prologue",
      click = function() open("prologue") end,
    })
  end
  for _, ch in ipairs(w.chapters) do
    -- (its title, its number under it; a title that is the place doesn't say it twice)
    local number = ("Entry %d"):format(ch.number)
    local under = (ch.place and ch.place ~= ch.title) and (ch.place .. ", " .. levels(ch)) or levels(ch)
    under = ch.open and "still being written" or under
    table.insert(entries, {
      key = ch.number,
      title = ch.title or number,
      place = ch.title and (number .. DOT .. under) or under,
      close = ch.close,
      rare = ch.rare,
      indent = indent,
      selected = selectedKey == ch.number,
      click = function() open(ch.number) end,
    })
  end
end

-- (the editor of an entry's own title and note, below: closed when another
-- page is opened)
local editor
local function closeEditor()
  if editor then
    editor.title:ClearFocus()
    editor.note:ClearFocus()
    editor:Hide()
  end
  page:Show()
end

-- The Journal tab: this character's book, rewritten from the records. latest:
-- open the last chapter (opening the book), else keep the open one.
local function refreshJournal(latest)
  local c = ns.journal()
  written = ns.writeBook(c)
  local known = current == "prologue" and written.prologue or written.chapters[current]
  if latest or not known then
    local last = written.chapters[#written.chapters]
    current = last and last.number or (written.prologue and "prologue") or nil
  end
  local entries = {}
  chapterRows(entries, written, current, function(key)
    current = key
    ns.refresh()
  end)
  render(entries, latest)
  if current then
    showPage(c, written, current)
  else
    show("", "", "", nil)
  end
  if editor and editor:IsShown() and editor.n ~= current then closeEditor() end
  page.edit:SetShown(type(current) == "number") -- (an entry of mine: its title, a note)
end

-- The Hall tab: the fallen, the most recent first; the open one's pages under
-- its name.
local function refreshHall(scroll)
  page.edit:Hide()
  if editor and editor:IsShown() then closeEditor() end
  local fallen = ns.fallen()
  local known = false
  for _, life in ipairs(fallen) do
    if life.guid == hallLife then known = true end
  end
  if not known then
    hallLife, hallKey = fallen[1] and fallen[1].guid, "epitaph"
  end
  local entries = {}
  if #fallen == 0 then
    table.insert(entries, { title = "No one has fallen", place = "May it stay so." })
    render(entries)
    return show(
      "",
      "The Hall of the Fallen",
      "",
      "The closed books of Hardcore characters rest here, to be read again."
    )
  end
  local open, w
  for _, life in ipairs(fallen) do
    local d = life.death or {}
    table.insert(entries, {
      key = life.guid,
      title = life.name or "?",
      place = ("Level %d %s %s"):format(d.level or 0, life.raceName or "", life.className or ""),
      selected = life.guid == hallLife and hallKey == "epitaph",
      click = function()
        hallLife, hallKey = life.guid, "epitaph"
        ns.refresh()
      end,
    })
    if life.guid == hallLife then
      open, w = life, ns.writeBook(life)
      chapterRows(entries, w, hallKey, function(key)
        hallKey = key
        ns.refresh()
      end, 14)
    end
  end
  render(entries, scroll)
  showPage(open, w, hallKey)
end

-- ── the player's own: a title, a note ────────────────────────────────────────
-- An entry's own title and a note in its margin, written over its page (or
-- with /ht title, /ht note; Core.lua keeps them): empty, the journal's own.
local function buttonOf(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  return b
end
local function buildEditor(sheet)
  editor = CreateFrame("Frame", nil, sheet)
  editor:SetPoint("TOPLEFT", sheet, "TOPLEFT", 26, -22)
  editor:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -22, 14)
  editor.head = label(editor, TITLE_FONT, 22, T.gold)
  editor.head:SetPoint("TOPLEFT", 0, -10)
  editor.titleLabel = label(editor, BODY_FONT, 12, T.soft)
  editor.titleLabel:SetPoint("TOPLEFT", 0, -50)
  editor.titleLabel:SetWidth(WIDTH)
  editor.title = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
  editor.title:SetPoint("TOPLEFT", 6, -68)
  editor.title:SetSize(WIDTH - 12, 24)
  editor.title:SetAutoFocus(false)
  editor.title:SetMaxLetters(60)
  local noteLabel = label(editor, BODY_FONT, 12, T.soft)
  noteLabel:SetPoint("TOPLEFT", 0, -104)
  noteLabel:SetText("A note in its margin, in your own words")
  local ground = editor:CreateTexture(nil, "BACKGROUND")
  ground:SetColorTexture(0, 0, 0, 0.35)
  ground:SetPoint("TOPLEFT", 0, -122)
  ground:SetPoint("BOTTOMRIGHT", 0, 42)
  editor.note = CreateFrame("EditBox", nil, editor)
  editor.note:SetMultiLine(true)
  editor.note:SetAutoFocus(false)
  editor.note:SetMaxLetters(1000)
  editor.note:SetFontObject(ChatFontNormal)
  editor.note:SetWidth(WIDTH - 16)
  editor.note:SetPoint("TOPLEFT", 8, -130)
  editor.note:SetPoint("BOTTOMRIGHT", -8, 50)
  -- (a click anywhere on its ground writes in it)
  local area = CreateFrame("Button", nil, editor)
  area:SetAllPoints(ground)
  area:SetScript("OnClick", function() editor.note:SetFocus() end)
  editor.note:SetFrameLevel(area:GetFrameLevel() + 1)
  editor.save = buttonOf(editor, "Save", 90)
  editor.save:SetPoint("BOTTOMRIGHT", 0, 8)
  editor.cancel = buttonOf(editor, "Cancel", 90)
  editor.cancel:SetPoint("RIGHT", editor.save, "LEFT", -8, 0)
  editor.save:SetScript("OnClick", function()
    local n = editor.n
    closeEditor()
    ns.setOwn(n, "title", editor.title:GetText())
    ns.setOwn(n, "text", editor.note:GetText())
  end)
  editor.cancel:SetScript("OnClick", closeEditor)
  editor.title:SetScript("OnEnterPressed", function() editor.note:SetFocus() end)
  editor.title:SetScript("OnEscapePressed", closeEditor)
  editor.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ns.bookEditor = editor -- (for the tests)
end
local function openEditor()
  local ch = written and type(current) == "number" and written.chapters[current]
  if not ch then return end
  if not editor then buildEditor(book.sheet) end
  local own = ns.own(current) or {}
  editor.n = current
  editor.head:SetText(("Entry %d"):format(current))
  local journals = own.title and ch.writtenTitle or ch.title -- (the title the journal gave it)
  editor.titleLabel:SetText(journals and ("Its title (the journal's own: %s)"):format(journals) or "Its title")
  editor.title:SetText(own.title or "")
  editor.note:SetText(own.text or "")
  page:Hide()
  editor:Show()
end

-- Rewrite what the open tab shows.
function ns.refresh(latest)
  local c = ns.journal()
  if not book or not c then return end
  book.hardcore:Set(c)
  if book.selectedTab == 2 then
    refreshHall(latest)
  else
    refreshJournal(latest)
  end
end

-- A tab chosen (the kit's, under the window's bottom edge): the Journal (1)
-- or the Hall of the Fallen (2).
function ns.showTab(n)
  if not book then return end
  book.selectedTab = n
  if PanelTemplates_SetTab then PanelTemplates_SetTab(book, n) end
  ns.refresh(true)
end

-- A Hardcore life's mark beside the portrait: the game's skull for a deadly
-- foe and the word, what it means on hover (and who says so: the game, or
-- this character's setting where the game can't tell). Nothing otherwise.
local MARK = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local FALLEN = { 0.85, 0.32, 0.25 }
local function hardcoreMark(parent, x)
  local m = CreateFrame("Frame", nil, parent)
  m:SetPoint("TOPLEFT", x, -30)
  m:SetSize(110, 20)
  m.icon = m:CreateTexture(nil, "ARTWORK")
  m.icon:SetTexture(MARK)
  m.icon:SetSize(16, 16)
  m.icon:SetPoint("LEFT", 0, 0)
  m.label = label(m, TITLE_FONT, 13, T.gold)
  m.label:SetPoint("LEFT", m.icon, "RIGHT", 4, 0)
  m:EnableMouse(true)
  m:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(self.label:GetText() or "", unpack(self.colour or T.gold))
    for _, l in ipairs(self.lines or {}) do
      GameTooltip:AddLine(l, 0.93, 0.88, 0.76, true)
    end
    GameTooltip:Show()
  end)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function m:Set(c)
    if not (c and c.hardcore) then return self:Hide() end
    local source = c.hardcoreChosen and "Marked so in Hearthtale's options (the game doesn't say here)."
      or "As the game reports it."
    if c.closed then
      self.colour = FALLEN
      self.label:SetText("Fallen")
      self.lines = { "This life has ended: its book is closed, with its epitaph, and kept in the Hall of the Fallen." }
    else
      self.colour = T.gold
      self.label:SetText("Hardcore")
      self.lines =
        { "One life, one book: a death closes it with an epitaph, and it joins the Hall of the Fallen.", source }
    end
    self.label:SetTextColor(unpack(self.colour))
    self:Show()
  end
  return m
end

-- The window: the kit's standard game window (a plain dialog where the client
-- has none), its portrait the character's own face.
local TITLE = "Hearthtale"

local function portrait()
  local p = (book.GetPortrait and book:GetPortrait())
    or (type(book.portrait) == "table" and book.portrait)
    or (type(book.PortraitContainer) == "table" and book.PortraitContainer.portrait)
    or nil
  if p and SetPortraitTexture then
    SetPortraitTexture(p, "player")
  elseif book.SetPortraitToAsset then
    book:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_08")
  end
end

function build()
  local window = K.gameWindow("HearthtaleFrame", TITLE)
  book = window or K.dialog("HearthtaleFrame", TITLE)
  K.movable(book, 780, 560)
  local edge = window and 8 or 14

  -- Beside the portrait, a Hardcore life's mark (refresh shows it).
  book.hardcore = hardcoreMark(book, window and 64 or 20)

  -- Left: the chapters.
  local left = panel(book, true)
  book.left = left
  left:SetPoint("TOPLEFT", edge, -58)
  left:SetPoint("BOTTOMLEFT", edge, edge)
  left:SetWidth(244)
  list = K.scrollArea(left, ROW_WIDTH, "HearthtaleList")
  list:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -12)
  list:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -18, 12)

  -- Right: the chapter.
  local sheet = panel(book)
  book.sheet = sheet
  sheet:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 32)
  sheet:SetPoint("BOTTOMRIGHT", -edge, edge)
  page = K.scrollArea(sheet, WIDTH, "HearthtalePage")
  page:SetPoint("TOPLEFT", sheet, "TOPLEFT", 26, -22)
  page:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -22, 14)

  -- The header: what the page is and how it stands, its title, then where,
  -- which levels and when (each on one line, cut short rather than wrapped).
  page.over = label(page.child, BODY_FONT, 10, T.gold)
  page.over:SetPoint("TOPLEFT", 0, -6)
  page.over:SetWidth(WIDTH - 80) -- (clear of the Edit button)
  page.over:SetWordWrap(false)
  page.over:SetAlpha(0.85)
  page.title = label(page.child, TITLE_FONT, 24, T.gold)
  page.title:SetPoint("TOPLEFT", 0, -22)
  page.title:SetWidth(WIDTH)
  page.title:SetWordWrap(false)
  page.sub = label(page.child, BODY_FONT, 12, T.soft)
  page.sub:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -7)
  page.sub:SetWidth(WIDTH)
  page.sub:SetWordWrap(false)
  local headerRule = rule(page.child)
  headerRule:SetPoint("TOPLEFT", 0, -78)
  headerRule:SetPoint("TOPRIGHT", 0, -78)
  page.body = label(page.child, BODY_FONT, 13, T.text)
  page.body:SetPoint("TOPLEFT", 0, -HEADER_H)
  page.body:SetWidth(WIDTH)
  page.body:SetSpacing(4)
  page.edit = buttonOf(sheet, "Edit", 64)
  page.edit:SetHeight(20)
  page.edit:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -22, -20)
  page.edit:SetScript("OnClick", openEditor)
  page.edit:Hide()
  ns.bookEdit = page.edit -- (for the tests)

  book:SetScript("OnShow", function()
    portrait()
    ns.refresh(not asked)
    asked = false
  end)
  K.tabs(book, { "Journal", "Hall of the Fallen" }, function(n) ns.showTab(n) end)
  book.selectedTab = 1
  if PanelTemplates_SetTab then PanelTemplates_SetTab(book, 1) end
end

function ns.toggle()
  if not ns.journal() then return end
  if not book then build() end
  book:SetShown(not book:IsShown())
end

-- Open the journal at a chapter (a click on its line in chat).
function ns.openChapter(number)
  if not ns.journal() then return end
  if not book then build() end
  current = number
  book.selectedTab = 1
  if PanelTemplates_SetTab then PanelTemplates_SetTab(book, 1) end
  if book:IsShown() then
    ns.refresh()
  else
    asked = true -- (its OnShow opens it there, not at the last chapter)
    book:Show()
  end
end

-- Open the Hall at a fallen life (a click on the chat line or the toast); with
-- none, at the most recent.
function ns.openHall(guid)
  if not ns.journal() then return end
  if not book then build() end
  hallLife, hallKey = guid, "epitaph"
  book.selectedTab = 2
  if PanelTemplates_SetTab then PanelTemplates_SetTab(book, 2) end
  if book:IsShown() then
    ns.refresh(true)
  else
    book:Show()
  end
end
ns.onHall = function()
  if book and book:IsShown() then ns.refresh() end
end

-- A chapter closes: a line in chat with a link to it (a setting).
function ns.link(target, text) return ("|cffc9a227|Hhearthtale:%s|h[%s]|h|r"):format(target, text) end
ns.onChapter = function(number)
  if not ns.option("chat") then return end
  print(ns.PREFIX .. ("entry %d is written. %s"):format(number, ns.link("chapter:" .. number, "Read it")))
end

-- Links in chat (|Hhearthtale:chapter:<number>|h, |Hhearthtale:hall:<guid>|h): the
-- game hands links of an unknown type to the handler registered for it.
local function followLink(link)
  local number = tonumber(link:match("^hearthtale:chapter:(%d+)$") or "")
  if number then return ns.openChapter(number) end
  local guid = link:match("^hearthtale:hall:(.+)$")
  if guid then ns.openHall(guid) end
end
if LinkUtil and LinkUtil.RegisterLinkHandler then
  LinkUtil.RegisterLinkHandler("hearthtale", function(link)
    followLink(link)
    return LinkProcessorResponse and LinkProcessorResponse.Handled
  end)
elseif hooksecurefunc and SetItemRef then
  -- Clients without the link registry still pass every click to SetItemRef.
  hooksecurefunc("SetItemRef", function(link) followLink(link) end)
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
  if C_Timer then
    C_Timer.After(1, later)
  else
    later()
  end
end
