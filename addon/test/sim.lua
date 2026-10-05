-- Runs the addon against a fake WoW API and replays a character's life.
--   luajit addon/test/sim.lua              (from the repo root): Classic
--   FOREVER=1 luajit addon/test/sim.lua    the same on Forever's client
local DIR = "addon/WayfarersJournal/"
local FOREVER = os.getenv("FOREVER") == "1"
function GetBuildInfo() return "1.15.8", "60000", "Oct 1 2026", FOREVER and 16001 or 11509 end
local secrets = {}
if FOREVER then issecretvalue = function(v) return secrets[v] == true end end

-- ── a fake game ──────────────────────────────────────────────────────────────
local clock = 1790900000
function time() return clock end
date = os.date
local state = { level = 1, guid = "Player-6113-0ABCDEF0" }
local printed = {}
function print(msg) table.insert(printed, msg) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function UnitGUID(u) return u == "player" and state.guid or nil end
function UnitLevel(u) return u == "player" and state.level or 0 end
SlashCmdList = {}

local frames = {}
local function frame()
  local f = { registered = {}, scripts = {} }
  function f:RegisterEvent(e) self.registered[e] = true end
  function f:SetScript(name, fn) self.scripts[name] = fn end
  return f
end
function CreateFrame() local f = frame(); table.insert(frames, f); return f end
local function fire(e, ...)
  local heard = false
  for _, f in ipairs(frames) do
    if f.registered[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...); heard = true end
  end
  assert(heard, "nobody listens to " .. e)
end

-- ── load the addon ───────────────────────────────────────────────────────────
local ns = {}
assert(loadfile(DIR .. (FOREVER and "Data_Forever.lua" or "Data_Classic.lua")))("WayfarersJournal", ns)
for _, f in ipairs({ "Core.lua" }) do assert(loadfile(DIR .. f))("WayfarersJournal", ns) end
local D = ns.data
local function check(cond, msg) assert(cond, msg); io.write("✓ " .. msg .. "\n") end

-- ── a life ───────────────────────────────────────────────────────────────────
check(D.client == (FOREVER and "forever" or "classic") and D.writing.opening, "each game's data file is its own, with the writing")
WayfarersJournalChar = { guid = "Player-6113-0DEAD000", levels = { [1] = {} } }
fire("PLAYER_LOGIN")
check(WayfarersJournalChar.guid == state.guid and next(WayfarersJournalChar.levels) == nil and WayfarersJournalChar.began.level == 1,
  "a new character named like a deleted one starts a fresh journal")
check(ns.forever == FOREVER, FOREVER and "Forever is recognised" or "Classic is recognised")
io.write(FOREVER and "all good (Forever)\n" or "all good\n")
