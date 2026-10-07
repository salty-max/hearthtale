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
local _, ns = ...
local PREFIX = "|cffc9a227Hearthtale:|r "
ns.PREFIX = PREFIX

-- Forever: a modern client (interface 16xxx), with secret values.
local interface = select(4, GetBuildInfo())
ns.forever = interface >= 16000 and interface < 20000
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
ns.secret = secret

local char
function ns.journal() return char end

local frame = CreateFrame("Frame")
local handlers, listeners = {}, {}

function handlers.PLAYER_LOGIN()
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

frame:SetScript("OnEvent", function(_, event, ...)
  if event ~= "PLAYER_LOGIN" and not char then return end
  if handlers[event] then handlers[event](...) end
  if not char.closed then
    for _, fn in ipairs(listeners[event] or {}) do fn(...) end
  end
  -- Last of all at logout, closed book or not: the book into the saved file.
  if event == "PLAYER_LOGOUT" and ns.writeDown then ns.writeDown(char) end
end)
for event in pairs(handlers) do frame:RegisterEvent(event) end
frame:RegisterEvent("PLAYER_LOGOUT")

-- Other files listen through this frame (ns.on). An event a client doesn't
-- know is simply never heard.
-- Does this client have the event? (registering an unknown one throws)
local probe = CreateFrame("Frame")
function ns.knows(event)
  local ok = pcall(probe.RegisterEvent, probe, event)
  if ok then probe:UnregisterEvent(event) end
  return ok
end

function ns.on(event, fn)
  if not listeners[event] then
    listeners[event] = {}
    if not handlers[event] then pcall(frame.RegisterEvent, frame, event) end
  end
  table.insert(listeners[event], fn)
end

SLASH_HEARTHTALE1 = "/hearthtale"
SLASH_HEARTHTALE2 = "/ht"
SlashCmdList.HEARTHTALE = function(msg)
  msg = strtrim((msg or ""):lower())
  if msg == "minimap" then
    ns.setOption("minimapHidden", not ns.option("minimapHidden"))
    return
  end
  if msg == "settings" or msg == "options" then
    if not ns.openSettings() then print(PREFIX .. "no settings page in this client.") end
    return
  end
  if msg == "hall" then return ns.openHall() end
  -- A code from hearthtale.app, kept in the saved file: the next upload (after a
  -- logout or a /reload) carries it, and the site adds this book to that account.
  local code = msg:match("^link%s+(%w+)$")
  if code then
    if #code ~= 6 then
      print(PREFIX .. "that isn't a link code: it has six letters and digits, from hearthtale.app.")
    elseif char then
      char.link = { code = code:upper(), at = time() }
      print(PREFIX .. "code " .. code:upper() .. " kept. Log out or /reload with Ravenpost running, and this book joins your library on hearthtale.app.")
    end
    return
  end
  if msg ~= "" then
    print(PREFIX .. "/ht opens the journal; /ht hall the Hall of the Fallen; /ht link CODE links this character to hearthtale.app; /ht settings; /ht minimap shows or hides the button.")
    return
  end
  ns.toggle()
end
