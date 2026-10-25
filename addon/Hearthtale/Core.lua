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
local L = ns.kit.L
local PREFIX = "|cffc9a227Hearthtale:|r "
ns.PREFIX = PREFIX

-- Forever (ns.forever, the kit's: a modern client, interface 16xxx), with
-- secret values.
ns.secret = ns.kit.secret
-- The player's buff at index i: its name and spell id (nil past the last).
-- Forever's client has no UnitBuff: its aura data by index instead.
function ns.buff(i)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not aura then return nil end
    return aura.name, aura.spellId
  end
  local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
  return name, spellId
end

local char
function ns.journal() return char end

-- ── events ───────────────────────────────────────────────────────────────────
-- Every file listens through ns.on (the kit's events: each listener on its
-- own, the login too, an event a client doesn't know never heard), unit
-- events through ns.onUnit (for one unit only: UNIT_HEALTH fires for every
-- unit in sight), ns.knows whether the client has one. Nothing is heard
-- before the login, nor once a Hardcore death has closed the book.
local events = ns.kit.events({
  login = function() ns.login() end,
  ready = function() return char ~= nil and not char.closed end,
})
ns.on, ns.onUnit, ns.knows = events.on, events.onUnit, events.knows

-- A closed book hears nothing, but its login or /reload still says so (Book.lua)
events.always("PLAYER_ENTERING_WORLD", function(initial, reloading)
  if char and char.closed and ns.onResume and (initial or reloading) then ns.onResume(nil) end
end)
-- Last of all at logout, closed book or not: the book into the saved file,
-- then the records' names into the game's ids (Ids.lua).
events.always("PLAYER_LOGOUT", function()
  if char and ns.writeDown then ns.writeDown(char) end
  if char and ns.toIds then
    for _, c in ipairs(ns.savedRecords(char)) do
      ns.toIds(c)
    end
  end
end)

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
  -- (the saved files keep the game's ids: its names again, Ids.lua)
  if ns.namesAtLogin then ns.namesAtLogin(char) end
  if ns.loadProfile then ns.loadProfile(char) end
  if ns.collect then ns.collect:start() end
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
local USAGE =
  L["/ht opens the journal, /ht hall the Hall of the Fallen. /ht title [N] TEXT names an entry, /ht note [N] TEXT writes in its margin (the last entry without N, no TEXT to remove it). /ht link CODE links this character to hearthtale.app. /ht settings opens the options, /ht minimap shows or hides the button, /ht welcome shows the welcome page again. /ht export gives this character's settings as a code, /ht import CODE takes them. /ht rewrite writes the journal anew with this version (a closed entry keeps its words otherwise)."]

-- A code from hearthtale.app, kept in the saved file: the next upload (after a
-- logout or a /reload) carries it, and the site adds this book to that account.
local function link(code)
  if #code ~= 6 then
    print(PREFIX .. L["That isn't a link code: it has six letters and digits, from hearthtale.app."])
  elseif char then
    code = code:upper()
    char.link = { code = code, at = time() }
    print(
      PREFIX
        .. L["Code %s kept. Log out or /reload with Ravenpost running, and this book joins your library on hearthtale.app."]:format(
          code
        )
    )
  end
end

-- /ht rewrite: the whole journal written anew by this version of the addon. A
-- closed entry otherwise keeps the words it was first saved with (Diary.lua);
-- the player's titles and notes stay. Its life in the Hall too, if fallen.
local function rewrite()
  if not char then return end
  char.book = nil
  ns.forgetWritten(char)
  local life = char.guid and ns.fallenLife and ns.fallenLife(char.guid)
  if life then
    life.book = nil
    ns.forgetWritten(life)
  end
  if ns.refresh then ns.refresh() end
  print(
    PREFIX
      .. L["The journal is written anew. hearthtale.app shows it after your next logout or /reload with Ravenpost running."]
  )
end
StaticPopupDialogs.HEARTHTALE_REWRITE = {
  text = L["Write this journal anew with this version of Hearthtale? Its entries' words may change. Your own titles and notes stay."],
  button1 = YES,
  button2 = NO,
  OnAccept = rewrite,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- "/ht note 3 Text": entry 3; "/ht note Text": the last one (the case of the words kept)
local function setOwn(field, rest)
  if not char then return end
  local first, text = rest:match("^(%d+)%s*(.*)$")
  local n = tonumber(first)
  if not (n and char.chapters and char.chapters[n]) then
    n, text = char.chapters and #char.chapters or 0, rest
  end
  local title = field == "title"
  if not ns.setOwn(n, field, text) then
    print(PREFIX .. (title and L["No entry to give a title to yet."] or L["No entry to give a note to yet."]))
  elseif text == "" then
    print(PREFIX .. (title and L["Entry %d's title removed."] or L["Entry %d's note removed."]):format(n))
  else
    print(PREFIX .. (title and L["Entry %d's title kept."] or L["Entry %d's note kept."]):format(n))
  end
end

-- The kit's command (K.commands): alone it opens the journal, an unknown word
-- prints the usage.
ns.kit.commands({
  names = { "/hearthtale", "/ht" },
  key = "HEARTHTALE",
  name = "Hearthtale",
  prefix = PREFIX,
  profiles = function() return ns.profiles end,
  open = function() ns.toggle() end,
  usage = USAGE,
  settings = function() return ns.openSettings() end,
  welcome = function(mode) ns.showWelcome(mode) end,
  minimap = { get = function(k) return ns.option(k) end, set = function(k, v) ns.setOption(k, v) end },
  commands = {
    hall = function() ns.openHall() end,
    rewrite = function() StaticPopup_Show("HEARTHTALE_REWRITE") end,
  },
  -- (/ht title and /ht note, the case of the words kept; /ht link CODE)
  match = function(msg, raw)
    local word, rest = raw:match("^(%a+)%s*(.*)$")
    word = word and word:lower()
    if word == "title" or word == "note" then
      setOwn(word == "title" and "title" or "text", rest)
      return true
    end
    local code = msg:match("^link%s+(%w+)$")
    if not code then return false end
    link(code)
    return true
  end,
})
