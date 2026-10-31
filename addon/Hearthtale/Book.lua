-- The journal as a book, the kit's (K.book: the game's window, the list on
-- the left, the page on the right, the search, the tabs), as its siblings
-- (Lorekeeper's Codex, Yonder): the character's portrait in the corner, a
-- Hardcore life's mark beside it. Two tabs. The Journal: on the left, the
-- prologue (a character met mid-life) and the chapters (one from rest to
-- rest), where each closed and the levels it covers under it, a skull for a
-- close call, a star for a rare; on the right, the open chapter as its diary
-- entry (Diary.lua), the journal as the character writes it (the player's
-- note in its margin, the kit's aside; a closed book's last one ends with its
-- epitaph, in the accent), under the kit's header with the life's crest (a
-- fallen one's with a skull on it). The Hall of the Fallen (Hall.lua): at a
-- glance first (its figures, each fallen life as a card), then the closed
-- books of the account's Hardcore characters, the open one's epitaph and
-- chapters under its name. The search finds an entry by its words. The
-- siblings' look, from the shared kit (Kit.lua), in an ember theme. The text
-- is written from the records each time it is shown (Diary.lua). /hearthtale
-- opens it.
local _, ns = ...

-- ── look ─────────────────────────────────────────────────────────────────────
-- The kit's (Kit.lua), its theme set first thing in Core.lua.
local K = ns.kit
local L = K.L
local T = K.T
local label = K.label
local BODY_FONT, TITLE_FONT = K.BODY_FONT, K.TITLE_FONT
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local LOGO = "Interface\\AddOns\\Hearthtale\\Media\\Logo"
local MARK = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local FALLEN = { 0.85, 0.32, 0.25 }
-- A fallen life's medal on its picture: the skull, in a red ring.
ns.FALLEN_SEAL = { SKULL, L["Fallen"], "", FALLEN }

-- ── the book ─────────────────────────────────────────────────────────────────
local book, list, page -- (the window, its list, its page: the kit's)
local written -- this character's book as last written: { prologue, chapters, epitaph }
local current -- its open chapter: a number, or "prologue"
local hallLife, hallKey -- in the Hall: the open life (its guid) and its page ("epitaph", "prologue", a chapter's number)
local asked -- opened at a page (a link): don't go to the last chapter
local opening -- the book opened or a tab shown (else a page drawn again as it changes)
local WIDTH = K.PAGE_WIDTH
local EPITAPH = K.hex(T.accent) .. "%s|r" -- the epitaph, in the accent

local DOT = "  \194\183  " -- (a middle dot between the parts of a line)

-- (the kit's day and month: "5 Oct 2026", each language its own)
local month = K.month
local function day(at) return at and K.day(at) or nil end

-- When a chapter was lived, as short as it reads: "5 Oct 2026", "5 to 7 Oct
-- 2026", "30 Sep to 2 Oct 2026", "30 Dec 2026 to 2 Jan 2027".
local function when(ch)
  local c = ch.chapter
  local a, b = c.start and c.start.at, c.ended and c.ended.at
  if not a then return nil end
  if not b or day(a) == day(b) then return day(a) end
  local ta, tb = date("*t", a), date("*t", b)
  if ta.year ~= tb.year then return L["%s to %s"]:format(day(a), day(b)) end
  if ta.month ~= tb.month then return L["%d %s to %s"]:format(ta.day, month(a), day(b)) end
  return L["%d to %s"]:format(ta.day, day(b))
end

-- The levels a chapter covers: "level 12", "levels 11 to 13".
local function levels(ch)
  if ch.from == ch.to then return L["level %d"]:format(ch.from) end
  return L["levels %d to %d"]:format(ch.from, ch.to)
end

-- A page's header: the kit's, the title and one line under it (what it is,
-- how it stands, where, which levels, when), never wrapped: cut short at its
-- end, the date first to go.
local function line(parts)
  local s = table.concat(parts, DOT)
  return s:sub(1, 1):upper() .. s:sub(2)
end
local editor -- (the editor of an entry's own title and note, below)
local openEditor
-- The life's crest on the page, a fallen one's skull on it.
local function crestOf(life) return K.crest(life and life.class, LOGO) end
-- (paragraphs: the kit's, strings and asides; editable: an entry of mine,
-- its title and note mine to write)
local function show(title, sub, paragraphs, life, editable)
  page:SetShown(not (editor and editor:IsShown())) -- (under the editor: kept hidden)
  -- (the same page drawn again as the record changes: where it was read stays)
  -- (by its title and its line: two entries may share a title, not a line)
  local same = not opening and page.shownTitle == title and page.shownSub == sub
  page.shownTitle, page.shownSub = title, sub
  page:start(title, sub, crestOf(life), life and life.closed and ns.FALLEN_SEAL or nil)
  if paragraphs and #paragraphs > 0 then
    page:text(paragraphs)
  else
    page:paragraph(L["Nothing written yet."], T.soft)
  end
  if editable then page:buttons({ { L["Edit"], function() openEditor() end } }) end
  page:finish(same)
end

-- A page of a book (mine or a fallen one's): the prologue, a chapter (the last
-- one of a closed book ends with its epitaph), or the epitaph alone.
local function showPage(life, w, key, mine)
  if key == "prologue" then
    local p = life.prologue or {}
    return show(
      L["Prologue"],
      line({ L["Before this journal"], L["taken up at level %d"]:format(p.level or 0) }),
      { w.prologue },
      life
    )
  end
  if key == "epitaph" then
    local d = life.death or {}
    local race, class = ns.lifeNames(life)
    local sub = { L["Hardcore"], L["fallen"], L["Level %d %s %s"]:format(d.level or 0, race or "", class or "") }
    if life.realm then table.insert(sub, life.realm) end
    table.insert(sub, day(d.at))
    return show(life.name or "", line(sub), { w.epitaph and EPITAPH:format(w.epitaph) }, life)
  end
  local ch = w.chapters[key]
  if not ch then return end
  local parts = {}
  if ch.title then table.insert(parts, L["Entry %d"]:format(key)) end
  local last = key == #w.chapters
  if life.closed and last then
    table.insert(parts, L["the end"])
  elseif ch.open then
    table.insert(parts, L["still being written"])
  end
  if ch.place then table.insert(parts, ch.place) end
  table.insert(parts, levels(ch))
  table.insert(parts, when(ch))
  -- (the entry, the player's note in its margin, a closed book's epitaph)
  local paragraphs = { ch.text }
  if ch.note then
    -- selene: allow(mixed_table) (the kit's paragraph: its text, and what it is)
    table.insert(paragraphs, { ch.note, aside = true })
  end
  if life.closed and last and w.epitaph then table.insert(paragraphs, EPITAPH:format(w.epitaph)) end
  show(ch.title or L["Entry %d"]:format(key), line(parts), paragraphs, life, mine)
end

-- The list: the kit's, an entry a row of two lines (its title, and where and
-- which levels under it), set in under a fallen life's name ("inner"); its
-- marks on the right, a skull for a close call, a star for a rare.
local rows = {}
ns.bookRows = rows -- for the tests
local function style(row, kind)
  if kind ~= "entry" and kind ~= "inner" then return K.listStyle(row, kind) end
  local height = K.listStyle(row, "entry")
  if kind == "inner" then
    row.text:SetPoint("TOPLEFT", 18, -4)
    row.under:SetPoint("TOPLEFT", 18, -21)
  end
  return height
end
local function marked(r, close, rare)
  if not rawget(r, "marks") then
    r.marks = {}
    for m, file in ipairs({ SKULL, STAR }) do
      local t = r:CreateTexture(nil, "ARTWORK")
      t:SetTexture(file)
      t:SetSize(12, 12)
      r.marks[m] = t
    end
  end
  local x, on = -8, { close, rare }
  for m = 1, 2 do -- not ipairs: it stops at the first chapter without a close call
    local t = r.marks[m]
    t:ClearAllPoints()
    if on[m] then
      t:SetPoint("TOPRIGHT", r, "TOPRIGHT", x, -5)
      x = x - 14
    end
    t:SetShown(on[m] and true or false)
  end
  -- (a long title cut short, never over the marks)
  if x < -8 then r.text:SetPoint("TOPRIGHT", r, "TOPRIGHT", x - 2, -4) end
end

-- The list: { title, place, close, rare, indent, selected, click, words } per
-- row, those the search finds (its words: the entry's own too). scroll: bring
-- the selected row into view.
local function render(entries, scroll)
  local q = K.query(book.search)
  list:begin()
  for _, e in ipairs(entries) do
    if e.always or K.finds(table.concat({ e.title, e.place or "", e.words or "" }, " "), q) then
      local r = list:add(e.indent and "inner" or "entry", e.title, nil, e.place)
      r.key = e.key
      marked(r, e.close, e.rare)
      r:SetScript("OnClick", e.click)
      if e.selected then list:pick(r) end
    end
  end
  list:finish(scroll or false) -- (only on opening: a row clicked is in view already)
end

-- A book's chapters as rows (indent: under a fallen life's name).
local function chapterRows(entries, w, selectedKey, open, indent)
  if w.epitaph and indent then
    table.insert(entries, {
      key = "epitaph",
      title = L["Epitaph"],
      words = w.epitaph,
      indent = indent,
      selected = selectedKey == "epitaph",
      click = function() open("epitaph") end,
    })
  end
  if w.prologue then
    table.insert(entries, {
      key = "prologue",
      title = L["Prologue"],
      place = L["Before this journal"],
      words = w.prologue,
      indent = indent,
      selected = selectedKey == "prologue",
      click = function() open("prologue") end,
    })
  end
  for _, ch in ipairs(w.chapters) do
    -- (its title, its number under it; a title that is the place doesn't say it twice)
    local number = L["Entry %d"]:format(ch.number)
    local under = (ch.place and ch.place ~= ch.title) and (ch.place .. ", " .. levels(ch)) or levels(ch)
    under = ch.open and L["still being written"] or under
    table.insert(entries, {
      key = ch.number,
      title = ch.title or number,
      place = ch.title and (number .. DOT .. under) or under,
      words = table.concat({ ch.text or "", ch.note or "" }, " "),
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
local function refreshJournal(latest, scroll)
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
  render(entries, scroll)
  if editor and editor:IsShown() and editor.n ~= current then closeEditor() end
  if current then
    showPage(c, written, current, true)
  else
    show("", "", nil, c)
  end
end

-- How a life ended, in a few words: "slain by Hogger in Elwynn Forest".
local ENDS = { fall = L["fell"], drowning = L["drowned"], lava = L["burned"], nature = L["fell"] }
local function ending(d)
  local how = d.foe and L["slain by %s"]:format(d.foe) or ENDS[d.cause] or L["fell"]
  return d.zone and L["%s in %s"]:format(how, d.zone) or how
end

-- The Hall at a glance (the kit's page): its figures, each fallen life as a
-- card, the most recent first; a click opens its epitaph.
local function showHall(fallen)
  local sub = #fallen == 0 and L["No one has fallen. May it stay that way."]
    or (#fallen == 1 and L["One life rests here"] or L["%d lives rest here"]:format(#fallen))
  page:start(L["The Hall of the Fallen"], sub, K.icon(MARK))
  if #fallen == 0 then
    page:paragraph(
      L["The closed books of Hardcore characters rest here, to be read again: each life's epitaph, then its entries."],
      T.soft
    )
    return page:finish()
  end
  local highest, entries = 0, 0
  for _, life in ipairs(fallen) do
    highest = math.max(highest, life.death and life.death.level or 0)
    entries = entries + #(life.chapters or {})
  end
  page:stats({
    { tostring(#fallen), K.plural(#fallen, "life closed", "lives closed") },
    { tostring(highest), L["highest level"] },
    { tostring(entries), K.plural(entries, "entry written", "entries written") },
  })
  page:section(L["The fallen"])
  for _, life in ipairs(fallen) do
    local d = life.death or {}
    local race, class = ns.lifeNames(life)
    local facts = L["Level %d %s %s, %s"]:format(d.level or 0, race or "", class or "", ending(d))
    page:card(life.name or "?", facts .. (d.at and (", " .. day(d.at)) or ""), crestOf(life), function()
      hallLife, hallKey = life.guid, "epitaph"
      ns.refresh()
    end, ns.FALLEN_SEAL)
  end
  page:finish()
end

-- The Hall tab: at a glance first, then the fallen, the most recent first;
-- the open one's pages under its name.
local function refreshHall(scroll)
  if editor and editor:IsShown() then closeEditor() end
  local fallen = ns.fallen()
  local known = false
  for _, life in ipairs(fallen) do
    if life.guid == hallLife then known = true end
  end
  if not known then
    hallLife, hallKey = nil, nil
  end
  local entries = {
    {
      key = "hall",
      title = L["The Hall of the Fallen"],
      place = #fallen == 0 and L["May no one fall."] or K.plural(#fallen, "%d life", "%d lives"):format(#fallen),
      always = true,
      selected = hallLife == nil,
      click = function()
        hallLife, hallKey = nil, nil
        ns.refresh()
      end,
    },
  }
  local open, w
  for _, life in ipairs(fallen) do
    local d = life.death or {}
    local race, class = ns.lifeNames(life)
    table.insert(entries, {
      key = life.guid,
      title = life.name or "?",
      place = L["Level %d %s %s"]:format(d.level or 0, race or "", class or ""),
      always = life.guid == hallLife, -- (the open one stays, its pages under it)
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
  if not open then return showHall(fallen) end
  showPage(open, w, hallKey)
end

-- ── the player's own: a title, a note ────────────────────────────────────────
-- An entry's own title and a note in its margin, written over its page (or
-- with /ht title, /ht note; Core.lua keeps them): empty, the journal's own.
local buttonOf = K.button -- (the kit's: wider for a longer word, "Bearbeiten")
local function buildEditor(sheet)
  editor = CreateFrame("Frame", nil, sheet)
  editor.person = false -- (a traveller's note: whose; an entry's: none)
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
  noteLabel:SetText(L["A note in the entry's margin, in your own words"])
  local ground = editor:CreateTexture(nil, "BACKGROUND")
  ground:SetColorTexture(0, 0, 0, 0.35)
  editor.note = CreateFrame("EditBox", nil, editor)
  editor.note:SetMultiLine(true)
  editor.note:SetAutoFocus(false)
  editor.note:SetMaxLetters(1000)
  editor.note:SetFontObject(ChatFontNormal)
  editor.note:SetWidth(WIDTH - 16)
  -- (a click anywhere on its ground writes in it)
  local area = CreateFrame("Button", nil, editor)
  area:SetAllPoints(ground)
  area:SetScript("OnClick", function() editor.note:SetFocus() end)
  editor.note:SetFrameLevel(area:GetFrameLevel() + 1)
  -- (an entry's: its title above its note; a traveller's: the note alone,
  -- moved up into the title's room)
  function editor.layout(solo)
    local up = solo and 54 or 0
    noteLabel:ClearAllPoints()
    noteLabel:SetPoint("TOPLEFT", 0, -104 + up)
    ground:ClearAllPoints()
    ground:SetPoint("TOPLEFT", 0, -122 + up)
    ground:SetPoint("BOTTOMRIGHT", 0, 42)
    editor.note:ClearAllPoints()
    editor.note:SetPoint("TOPLEFT", 8, -130 + up)
    editor.note:SetPoint("BOTTOMRIGHT", -8, 50)
    editor.titleLabel:SetShown(not solo)
    editor.title:SetShown(not solo)
    noteLabel:SetText(
      solo and L["A note on them, in your own words"] or L["A note in the entry's margin, in your own words"]
    )
  end
  editor.save = buttonOf(editor, L["Save"], 90)
  editor.save:SetPoint("BOTTOMRIGHT", 0, 8)
  editor.cancel = buttonOf(editor, L["Cancel"], 90)
  editor.cancel:SetPoint("RIGHT", editor.save, "LEFT", -8, 0)
  editor.save:SetScript("OnClick", function()
    local n, who = editor.n, editor.person
    closeEditor()
    if who then return ns.setTravellerNote(who, editor.note:GetText()) end
    ns.setOwn(n, "title", editor.title:GetText())
    ns.setOwn(n, "text", editor.note:GetText())
  end)
  editor.cancel:SetScript("OnClick", closeEditor)
  editor.title:SetScript("OnEnterPressed", function() editor.note:SetFocus() end)
  editor.title:SetScript("OnEscapePressed", closeEditor)
  editor.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ns.bookEditor = editor -- (for the tests)
end
function openEditor()
  local ch = written and type(current) == "number" and written.chapters[current]
  if not ch then return end
  if not editor then buildEditor(book.sheet) end
  local own = ns.own(current) or {}
  editor.n, editor.person = current, false
  editor.layout(false)
  editor.head:SetText(L["Entry %d"]:format(current))
  local journals = own.title and ch.writtenTitle or ch.title -- (the title the journal gave it)
  editor.titleLabel:SetText(journals and L["Entry title (the journal's own: %s)"]:format(journals) or L["Entry title"])
  editor.title:SetText(own.title or "")
  editor.note:SetText(own.text or "")
  page:Hide()
  editor:Show()
end

-- A traveller's note: the same editor, the note alone.
local personKey -- the open traveller (nil: the overview)
local function openNoteEditor()
  local p = personKey and ns.traveller(personKey)
  if not p then return end
  if not editor then buildEditor(book.sheet) end
  editor.n, editor.person = false, personKey
  editor.layout(true)
  editor.head:SetText(p.name)
  editor.note:SetText(p.note or "")
  page:Hide()
  editor:Show()
end

-- Beside the portrait, a Hardcore life's mark: the game's skull for a deadly
-- foe and the word, what it means on hover (and who says so: the game, or
-- this character's setting where the game can't tell). Nothing otherwise.
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
      GameTooltip:AddLine(l, T.text[1], T.text[2], T.text[3], true)
    end
    GameTooltip:Show()
  end)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function m:Set(c)
    if not (c and c.hardcore) then return self:Hide() end
    local source = c.hardcoreChosen and L["Marked as Hardcore in Hearthtale's options (the game doesn't say)."]
      or L["As the game reports it."]
    if c.closed then
      self.colour = FALLEN
      self.label:SetText(L["Fallen"])
      self.lines =
        { L["This life has ended: its book is closed, with its epitaph, and kept in the Hall of the Fallen."] }
    else
      self.colour = T.gold
      self.label:SetText(L["Hardcore"])
      self.lines =
        { L["One life, one book: a death closes it with an epitaph, and it joins the Hall of the Fallen."], source }
    end
    self.label:SetTextColor(unpack(self.colour))
    self:Show()
  end
  return m
end

-- The window: the kit's book, its portrait the character's own face.
local TAB = { journal = 1, hall = 2, travellers = 3 }
local B = K.book({
  name = "HearthtaleFrame",
  title = "Hearthtale",
  place = function()
    HearthtaleSettings = HearthtaleSettings or {}
    return K.place(HearthtaleSettings, "book")
  end,
  titles = { L["Journal"], L["Hall of the Fallen"], L["Fellow travellers"] },
  first = TAB.journal,
  search = "HearthtaleSearch",
  settle = 1, -- (a fight records many moments at once: one rewriting)
})

local function portrait()
  local p = (book.GetPortrait and book:GetPortrait())
    or (type(book.portrait) == "table" and book.portrait)
    or (type(book.PortraitContainer) == "table" and book.PortraitContainer.portrait)
    or nil
  if p and SetPortraitTexture then
    SetPortraitTexture(p, "player")
  elseif book.SetPortraitToAsset then
    book:SetPortraitToAsset(LOGO)
  end
end

-- The two tabs share the list and the page (made by the first shown).
local function build(f)
  if book then return end
  book = f
  book.hardcore = hardcoreMark(book, 64)
  list = K.list(book.left, style, rows, false, "HearthtaleList")
  page = K.page(book.sheet, "HearthtalePage")
  page.sub:SetWordWrap(false) -- (its line cut short, never on two)
end
-- (scroll: the tab shown, the book opened: the last chapter, unless it was
-- opened at a page)
local function refresh(scroll)
  local c = ns.journal()
  if not c then return end
  book.hardcore:Set(c)
  opening = scroll
  if book.selectedTab == TAB.hall then
    refreshHall(scroll)
  elseif book.selectedTab == TAB.travellers then
    ns.refreshTravellers(scroll)
  else
    refreshJournal(scroll and not asked, scroll)
  end
  asked = false
end
local function shown() portrait() end
B:add(TAB.journal, { build = build, show = shown, refresh = refresh })
B:add(TAB.travellers, {
  build = build,
  show = shown,
  refresh = refresh,
  chosen = function() personKey = nil end,
})
B:add(TAB.hall, {
  build = build,
  show = shown,
  refresh = refresh,
  chosen = function()
    hallLife, hallKey = nil, nil
  end, -- (the Hall at a glance)
})

-- The Fellow travellers tab (Travellers.lua keeps them): the list on the left,
-- everyone grouped with, the latest first; on the right an overview first,
-- then a person's page with the player's own note.
local GROUP = "Interface\\Icons\\INV_Misc_GroupLooking"
local function className(token, sex)
  local names = (sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE) or LOCALIZED_CLASS_NAMES_MALE
  return token and names and names[token] or nil
end
local function daysOf(p)
  local n = ns.countOf(p.days)
  return K.plural(n, "%d day together", "%d days together"):format(n)
end
local function dateAt(at, zone)
  if not at then return nil end
  return zone and L["%s in %s"]:format(day(at), zone) or day(at)
end
local function picture(p) return crestOf({ class = p.class }) end

local function showTravellers(list_)
  local sub = #list_ == 0 and L["No one yet."]
    or K.plural(#list_, "%d fellow traveller", "%d fellow travellers"):format(#list_)
  page:start(L["Fellow travellers"], sub, K.icon(GROUP))
  if #list_ == 0 then
    page:paragraph(
      L["Everyone you group with is kept here, on this computer only. For each, you see when and where you met, the days you travelled together, the dungeons you entered, and a note of your own."],
      T.soft
    )
    return page:finish()
  end
  local days, pairs_, dungeons = 0, 0, {}
  for _, e in ipairs(list_) do
    days = days + ns.countOf(e.p.days)
    if ns.countOf(e.p.duo) > 0 then pairs_ = pairs_ + 1 end
    for d in pairs(e.p.dungeons) do
      dungeons[d] = true
    end
  end
  local dungeonCount = ns.countOf(dungeons)
  page:stats({
    { tostring(#list_), K.plural(#list_, "traveller", "travellers") },
    { tostring(pairs_), K.plural(pairs_, "travelled as a pair", "travelled as a pair") },
    { tostring(dungeonCount), K.plural(dungeonCount, "dungeon together", "dungeons together") },
  })
  page:section(L["Met most recently"])
  for _, e in ipairs(list_) do
    local p = e.p
    local facts = { className(p.class, p.sex), daysOf(p), dateAt(p.lastAt) }
    local parts = {}
    for _, f in ipairs(facts) do
      if f then table.insert(parts, f) end
    end
    page:card(p.name, table.concat(parts, ", "), picture(p), function()
      personKey = e.key
      ns.refresh()
    end)
  end
  page:finish()
end

local function showTraveller(p)
  local sub = {}
  if className(p.class, p.sex) then table.insert(sub, className(p.class, p.sex)) end
  table.insert(sub, daysOf(p))
  local title, line_ = p.name, line(sub)
  local same = not opening and page.shownTitle == title and page.shownSub == line_
  page.shownTitle, page.shownSub = title, line_
  page:start(title, line_, picture(p))
  page:row(L["First met"], dateAt(p.firstAt, p.firstZone))
  page:row(L["Last together"], dateAt(p.lastAt, p.lastZone))
  local pair = ns.countOf(p.duo)
  if pair > 0 then page:row(L["As a pair"], K.plural(pair, "%d day", "%d days"):format(pair)) end
  local places = {}
  for d in pairs(p.dungeons) do
    table.insert(places, d)
  end
  table.sort(places)
  if #places > 0 then page:row(L["Dungeons"], table.concat(places, ", ")) end
  local as = {}
  for _, name in pairs(p.with) do
    table.insert(as, name)
  end
  table.sort(as)
  if #as > 0 then page:row(L["Played as"], table.concat(as, ", ")) end
  if p.note then
    -- selene: allow(mixed_table) (the kit's paragraph: its text, and what it is)
    page:text({ { p.note, aside = true } })
  end
  page:buttons({ { p.note and L["Edit note"] or L["Add a note"], openNoteEditor } })
  page:finish(same)
end

function ns.refreshTravellers(scroll)
  local all = ns.travellers()
  local open
  for _, e in ipairs(all) do
    if e.key == personKey then open = e end
  end
  if not open then personKey = nil end
  if editor and editor:IsShown() and (not editor.person or editor.person ~= personKey) then closeEditor() end
  page:SetShown(not (editor and editor:IsShown()))
  local entries = {
    {
      key = "all",
      title = L["Fellow travellers"],
      place = #all == 0 and L["No one yet."] or K.plural(#all, "%d fellow traveller", "%d fellow travellers")
        :format(#all),
      always = true,
      selected = personKey == nil,
      click = function()
        personKey = nil
        ns.refresh()
      end,
    },
  }
  for _, e in ipairs(all) do
    local p = e.p
    table.insert(entries, {
      key = e.key,
      title = p.name,
      place = daysOf(p),
      words = p.note,
      selected = e.key == personKey,
      click = function()
        personKey = e.key
        ns.refresh()
      end,
    })
  end
  render(entries, scroll)
  if open then
    showTraveller(open.p)
  else
    page.shownTitle, page.shownSub = nil, nil
    showTravellers(all)
  end
end

-- Rewrite what the open tab shows (latest: as on opening it).
function ns.refresh(latest) B:refresh(latest) end

-- A tab chosen: the Journal (1) or the Hall of the Fallen (2).
function ns.showTab(n)
  if B.frame then B:show(n) end
end

function ns.toggle()
  if not ns.journal() then return end
  B:toggle()
end

-- Open the journal at a chapter (a click on its line in chat).
function ns.openChapter(number)
  if not ns.journal() then return end
  current, asked = number, true
  B:open(TAB.journal)
end

-- Open the Hall at a fallen life (a click on the chat line or the toast); with
-- none, at the most recent.
function ns.openHall(guid)
  if not ns.journal() then return end
  hallLife, hallKey = guid, "epitaph"
  B:open(TAB.hall)
end
ns.onHall = function() B:refresh() end

-- A chapter closes: a line in chat with a link to it.
-- (the kit's links: |Hhearthtale:<target>|h, followed below)
local followLink
local link = K.links("hearthtale", function(target) followLink(target) end)
function ns.link(target, text) return link(target, text) end
ns.onChapter = function(number)
  print(ns.PREFIX .. L["Entry %d is written. %s"]:format(number, ns.link("chapter:" .. number, L["Read it"])))
end

-- At a login or a /reload, a line in chat: the entry this login began
-- (after a rest closed the last one), the one going on (a short break, a
-- night in the wild, a /reload), or a fallen life's closed book; and how to
-- open the journal, the only reminder of it (as the Codex's).
-- (each line whole, as a language orders its own)
ns.onResume = function(number, started)
  local button = not ns.option("minimapHidden")
  if not number then
    print(
      ns.PREFIX
        .. (
          button and L["This life's book is closed. Type /ht or click the button by the minimap to read it."]
          or L["This life's book is closed. Type /ht to read it."]
        )
    )
    return
  end
  local said
  if started then
    said = button and L["Starting entry %d. Type /ht or click the button by the minimap to read the journal."]
      or L["Starting entry %d. Type /ht to read the journal."]
  else
    said = button and L["Resuming entry %d. Type /ht or click the button by the minimap to read the journal."]
      or L["Resuming entry %d. Type /ht to read the journal."]
  end
  print(ns.PREFIX .. said:format(number))
end

-- Links in chat (|Hhearthtale:chapter:<number>|h, |Hhearthtale:hall:<guid>|h): the
-- game hands links of an unknown type to the handler registered for it.
function followLink(target)
  local number = tonumber(target:match("^chapter:(%d+)$") or "")
  if number then return ns.openChapter(number) end
  local guid = target:match("^hall:(.+)$")
  if guid then ns.openHall(guid) end
end

-- A new moment while the book is open: rewritten a moment later, once (a fight
-- records many at once).
ns.onRecord = function() B:changed() end
