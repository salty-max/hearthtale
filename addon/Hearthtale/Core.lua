-- Hearthtale: the character's own journal, written as it plays. This
-- file holds the character's record (per character, HearthtaleChar):
--   guid                     the character it belongs to (a deleted
--                            character's journal is never inherited by a new
--                            one of the same name)
--   began = { at, level }    when the journal began (a character met
--                            mid-life gets a prologue)
--   chapters[i] = { ... }    the chapters, from rest to rest (Record.lua)
--   closed = true            a Hardcore death closed the book: nothing more
--                            is recorded (only the login, to find it)
--   book = { ... }           the book as written at the last logout (Save.lua)
--   link = { code, at }      a code from hearthtale.app (/ht link CODE), for the
--                            next upload to add this book to that account
--   notes[n] = { title, text }   the player's own: a title given entry n, a
--                            note in its margin (the window, /ht title, /ht note)
-- and the events every file listens to (ns.on, ns.onUnit).
local _, ns = ...
local PREFIX = "|cffc9a227Hearthtale:|r "
ns.PREFIX = PREFIX

-- Forever: a modern client (interface 16xxx), with secret values.
local interface = select(4, GetBuildInfo())
ns.forever = interface >= 16000 and interface < 20000
ns.secret = issecretvalue or function() return false end

local char
function ns.journal() return char end

-- ── events ───────────────────────────────────────────────────────────────────
-- Every file listens through ns.on (an event a client doesn't know is never
-- heard), unit events through ns.onUnit (for one unit only: UNIT_HEALTH fires
-- for every unit in sight). Nothing is heard before the login, nor once a
-- Hardcore death has closed the book.
local frame = CreateFrame("Frame")
local listeners = {}

local function heard(event, ...)
  if not char or char.closed then return end
  for _, fn in ipairs(listeners[event]) do
    fn(...)
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then ns.login() end
  if listeners[event] then heard(event, ...) end
  -- Last of all at logout, closed book or not: the book into the saved file.
  if event == "PLAYER_LOGOUT" and char and ns.writeDown then ns.writeDown(char) end
end)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

function ns.on(event, fn)
  if not listeners[event] then
    listeners[event] = {}
    pcall(frame.RegisterEvent, frame, event)
  end
  table.insert(listeners[event], fn)
end

local units = {} -- unit = its frame, with its own listeners
function ns.onUnit(event, unit, fn)
  local f = units[unit]
  if not f then
    f = CreateFrame("Frame")
    f.listeners = {}
    f:SetScript("OnEvent", function(_, e, ...)
      if not char or char.closed then return end
      for _, listener in ipairs(f.listeners[e]) do
        listener(...)
      end
    end)
    units[unit] = f
  end
  if not f.listeners[event] then
    f.listeners[event] = {}
    f:RegisterUnitEvent(event, unit)
  end
  table.insert(f.listeners[event], fn)
end

-- Does this client have the event? (registering an unknown one throws)
local probe = CreateFrame("Frame")
function ns.knows(event)
  local ok = pcall(probe.RegisterEvent, probe, event)
  if ok then probe:UnregisterEvent(event) end
  return ok
end

-- ── the login ────────────────────────────────────────────────────────────────
-- This character's journal, or a new one (a journal saved by another
-- character of the same name is not theirs).
function ns.login()
  local guid = UnitGUID("player")
  local saved = HearthtaleChar
  if type(saved) == "table" and saved.guid == guid then
    char = saved
  else
    char = { guid = guid, began = { at = time(), level = UnitLevel("player") }, chapters = {} }
    HearthtaleChar = char
  end
  if ns.onLogin then ns.onLogin(char) end
  if ns.createMinimapButton then ns.createMinimapButton() end
  if ns.createSettingsPanel then ns.createSettingsPanel() end
end

-- ── the player's own words ───────────────────────────────────────────────────
-- A title given an entry, a note in its margin: char.notes[n] = { title, text },
-- beside the record (Diary.lua lays them over the written book). Plain text: a
-- link keeps its name, the game's codes go; cut at a letter, not mid-way.
local OWN_LIMIT = { title = 60, text = 1000 }
local function plain(s)
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
  s = s:gsub("|n", "\n"):gsub("|", "")
  return strtrim(s)
end
local function cut(s, limit)
  if #s <= limit then return s end
  local n = limit
  while n > 0 and s:byte(n + 1) and s:byte(n + 1) >= 0x80 and s:byte(n + 1) < 0xC0 do
    n = n - 1
  end
  return strtrim(s:sub(1, n))
end
-- (field: "title" or "text"; nothing: removed. False when there is no such entry)
function ns.setOwn(n, field, value)
  if not (char and char.chapters and char.chapters[n] and OWN_LIMIT[field]) then return false end
  value = cut(plain(value or ""), OWN_LIMIT[field])
  char.notes = char.notes or {}
  local own = char.notes[n] or {}
  own[field] = value ~= "" and value or nil
  char.notes[n] = next(own) and own or nil
  if ns.refresh then ns.refresh() end
  return true
end
function ns.own(n) return char and char.notes and char.notes[n] or nil end

-- ── /hearthtale ──────────────────────────────────────────────────────────────
local USAGE = "/ht opens the journal; /ht hall the Hall of the Fallen; /ht title [N] TEXT names an entry, "
  .. "/ht note [N] TEXT writes in its margin (the last entry without N, no TEXT to remove it); /ht link CODE "
  .. "links this character to hearthtale.app; /ht settings; /ht minimap shows or hides the button; /ht welcome "
  .. "shows the welcome page again."

-- A code from hearthtale.app, kept in the saved file: the next upload (after a
-- logout or a /reload) carries it, and the site adds this book to that account.
local function link(code)
  if #code ~= 6 then
    print(PREFIX .. "that isn't a link code: it has six letters and digits, from hearthtale.app.")
  elseif char then
    code = code:upper()
    char.link = { code = code, at = time() }
    print(
      PREFIX
        .. "code "
        .. code
        .. " kept. Log out or /reload with Ravenpost running, and this book joins your "
        .. "library on hearthtale.app."
    )
  end
end

SLASH_HEARTHTALE1 = "/hearthtale"
SLASH_HEARTHTALE2 = "/ht"
-- "/ht note 3 Text": entry 3; "/ht note Text": the last one (the case of the words kept)
local function setOwn(field, rest)
  if not char then return end
  local first, text = rest:match("^(%d+)%s*(.*)$")
  local n = tonumber(first)
  if not (n and char.chapters and char.chapters[n]) then
    n, text = char.chapters and #char.chapters or 0, rest
  end
  local what = field == "title" and "title" or "note"
  if not ns.setOwn(n, field, text) then
    print(PREFIX .. "no entry to give a " .. what .. " to yet.")
  elseif text == "" then
    print(PREFIX .. ("entry %d's %s removed."):format(n, what))
  else
    print(PREFIX .. ("entry %d's %s kept."):format(n, what))
  end
end

SlashCmdList.HEARTHTALE = function(raw)
  raw = strtrim(raw or "")
  local msg = raw:lower()
  local code = msg:match("^link%s+(%w+)$")
  local word, rest = raw:match("^(%a+)%s*(.*)$")
  word = word and word:lower()
  if word == "title" or word == "note" then
    setOwn(word == "title" and "title" or "text", rest)
  elseif msg == "" then
    ns.toggle()
  elseif msg == "minimap" then
    ns.setOption("minimapHidden", not ns.option("minimapHidden"))
  elseif msg == "settings" or msg == "options" then
    if not ns.openSettings() then print(PREFIX .. "no settings page in this client.") end
  elseif msg == "hall" then
    ns.openHall()
  elseif msg == "welcome" then
    ns.showWelcome()
  elseif code then
    link(code)
  else
    print(PREFIX .. USAGE)
  end
end
