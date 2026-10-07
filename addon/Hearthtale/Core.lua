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
  for _, fn in ipairs(listeners[event]) do fn(...) end
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
      for _, listener in ipairs(f.listeners[e]) do listener(...) end
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

-- ── /hearthtale ──────────────────────────────────────────────────────────────
local USAGE = "/ht opens the journal; /ht hall the Hall of the Fallen; /ht link CODE links this character to "
  .. "hearthtale.app; /ht settings; /ht minimap shows or hides the button."

-- A code from hearthtale.app, kept in the saved file: the next upload (after a
-- logout or a /reload) carries it, and the site adds this book to that account.
local function link(code)
  if #code ~= 6 then
    print(PREFIX .. "that isn't a link code: it has six letters and digits, from hearthtale.app.")
  elseif char then
    code = code:upper()
    char.link = { code = code, at = time() }
    print(PREFIX .. "code " .. code .. " kept. Log out or /reload with Ravenpost running, and this book joins your "
      .. "library on hearthtale.app.")
  end
end

SLASH_HEARTHTALE1 = "/hearthtale"
SLASH_HEARTHTALE2 = "/ht"
SlashCmdList.HEARTHTALE = function(msg)
  msg = strtrim((msg or ""):lower())
  local code = msg:match("^link%s+(%w+)$")
  if msg == "" then
    ns.toggle()
  elseif msg == "minimap" then
    ns.setOption("minimapHidden", not ns.option("minimapHidden"))
  elseif msg == "settings" or msg == "options" then
    if not ns.openSettings() then print(PREFIX .. "no settings page in this client.") end
  elseif msg == "hall" then
    ns.openHall()
  elseif code then
    link(code)
  else
    print(PREFIX .. USAGE)
  end
end
