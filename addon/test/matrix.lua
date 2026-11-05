-- Hearthtale played through its characters, games and windows, on one game (FOREVER=1 for Forever). Each case
-- gives a character a short life (a place, a quest, kills, a spell, a group, levels, a rest that closes a chapter,
-- on Hardcore a death), opens the book on each tab, the welcome and the settings, hovers and clicks everything
-- shown, and must end with: no Lua error, no call the strict game refuses, no frame bigger than the screen or a
-- window anchored off it, no semicolon, exclamation mark or non-ASCII character in a word shown, no read of the
-- game that raised. A failure names the case. The kit's battery does the walking (addon-kit/docs/battery.md).
--   luajit addon/test/matrix.lua              the matrix
--   FOREVER=1 luajit addon/test/matrix.lua secrets   Forever's secret values: each call of the game the addon can
--                                             make answers with secret values, whole and field by field, while a
--                                             life is played and the windows opened: nothing may raise
local MODE = arg and arg[1] or "matrix"
local X = dofile("addon/test/secrets.lua")
if MODE == "secrets" then
  -- (a secret value keeps its type for type() and refuses everything else, as the client's do)
  HEARTHTALE_BEFORE_LOAD = function() X.patchType() end
end
local G = dofile("addon/test/game.lua")
local FOREVER, ns, state, fire = G.forever, G.ns, G.state, G.fire
local started = os.clock()

local B = dofile("addon/test/battery.lua")
local b = B.new({
  G = { strict = G.strict, advance = G.wait, state = { printed = G.printed } },
  name = "Hearthtale",
  screen = { w = 1920, h = 1080 },
  printed = G.printed,
  roots = function()
    local out = {}
    for _, name in ipairs({ "HearthtaleFrame", "HearthtaleWelcome", "HearthtaleBanner1", "HearthtaleBanner2" }) do
      if rawget(_G, name) then out[#out + 1] = _G[name] end
    end
    return out
  end,
  -- (the tabs of the book and the welcome's own close and tab buttons are the window's, not the page's)
  skip = function(f) return f.name and (tostring(f.name):find("Tab%d") or tostring(f.name):find("CloseButton")) end,
  rules = { allow = { "\194\183" } }, -- (the middle dot between an entry's title and its line is the interface's)
  -- (a banner is placed by the game's alert stack, not by the addon)
  -- (a secrets run groups by the call and the message, not the case: the call is the cause)
  kindOf = MODE == "secrets" and function(f)
    return (f:match("^(.-): ") or "") .. " | " .. f:gsub("^.-: .-: ", ""):gsub("%d+", "#"):sub(1, 70)
  end or nil,
  unanchored = function(window) return tostring(window.name):find("Banner") ~= nil end,
})
local failures, fail, try = b.failures, b.fail, b.try

-- ── a life
local guids = 0

local function life(spec)
  guids = guids + 1
  state.guid = ("Player-6113-0%07X"):format(0xA000 + guids)
  state.level, state.race, state.class, state.faction = 1, spec.race, spec.class, nil
  state.hardcore, state.sub, state.zone, state.health, state.resting, state.npc =
    spec.hardcore, "Coldridge Valley", "Dun Morogh", 100, false, nil
  state.party, state.instance, state.combat = {}, nil, false
  -- (a journal from another life, with the `began` every saved one has: a game that hides who the player is
  -- gives the character this one, and the secrets run plays that, ns.login in Core.lua)
  HearthtaleChar = { guid = ("Player-6113-0DEAD%03X"):format(guids), began = { at = 1, level = 1 }, chapters = {} }
  G.login()
  -- (Forever's client cannot say whether a character is Hardcore: the player declares it, in the settings)
  if FOREVER and spec.hardcore then ns.setHardcore(true) end
  -- a place, a quest, kills, a spell
  state.sub = "Anvilmar"
  fire("ZONE_CHANGED")
  state.npc, state.titles = "Sten Stoutarm", { [179] = "Dwarven Outfitters" }
  fire("QUEST_ACCEPTED", unpack(FOREVER and { 179 } or { 1, 179 }))
  state.objectives = { [179] = { { text = "Tough Wolf Meat: 0/8", type = "item", numRequired = 8 } } }
  fire("QUEST_LOG_UPDATE")
  state.npc, state.titles = "Balir Frosthammer", {}
  fire("QUEST_COMPLETE")
  fire("QUEST_TURNED_IN", 179, 80, 0)
  state.npc = nil
  G.kill(1, 1)
  G.kill(1, 2)
  G.kill(3, 3)
  G.cast("Holy Light")
  -- a group
  state.party = { party1 = { name = "Eldrin", class = "MAGE", guid = "Player-1-00AA" } }
  state.instance = "The Deadmines"
  fire("GROUP_ROSTER_UPDATE")
  state.instance = nil
  -- levels, then a rest that closes the chapter, and a second chapter
  for level = 2, spec.level do
    state.level = level
    fire("PLAYER_LEVEL_UP", level)
  end
  state.resting = true
  G.logout()
  state.resting = false
  G.login()
  state.sub = "Kharanos"
  fire("ZONE_CHANGED")
  G.kill(2, 4)
  state.resting = true
  G.logout()
  state.resting = false
  G.login()
  if spec.hardcore and spec.die then
    state.sub = "Kharanos"
    state.health = 0
    fire("PLAYER_DEAD")
    state.health = 100
  end
end

local function describe(spec)
  return ("%s %s, level %d%s%s"):format(
    spec.race,
    spec.class,
    spec.level,
    spec.hardcore and ", Hardcore" or "",
    spec.die and ", dead" or ""
  )
end

local cases, draws = 0, 0
local function windows(case)
  -- the book on each tab, the welcome, the settings
  if not HearthtaleFrame or not HearthtaleFrame:IsShown() then try(case, "open the book", ns.toggle) end
  for tab = 1, 3 do
    local label = case .. ", tab " .. tab
    if try(label, "show the tab", ns.showTab, tab) then
      draws = draws + 1
      G.wait(0.5)
      b.audit(label)
      b.touch(label)
      b.audit(label .. " (after clicks)")
    end
  end
  -- (an addon that could not tell who this is has no journal this session: it opens nothing)
  try(case, "open the last chapter", function() ns.openChapter(ns.journal() and #ns.journal().chapters or 1) end)
  b.audit(case .. ", a chapter")
  b.touch(case .. ", a chapter")
  if ns.openHall then
    try(case, "open the Hall", ns.openHall)
    b.audit(case .. ", the Hall")
    b.touch(case .. ", the Hall")
  end
  for _, slash in ipairs({ "welcome", "settings", "minimap", "minimap" }) do
    local label = case .. ", /ht " .. slash
    try(label, "the command", SlashCmdList.HEARTHTALE, slash)
    b.audit(label)
    b.touch(label)
  end
  try(case, "close the book", function()
    if HearthtaleFrame and HearthtaleFrame:IsShown() then SlashCmdList.HEARTHTALE("") end
  end)
end

local function play(spec)
  local case = describe(spec)
  cases = cases + 1
  if try(case, "a life", life, spec) then windows(case) end
end

local LEVELS = { 1, 2, 10, 30, 60 }
local CHARACTERS = {
  { race = "Dwarf", class = "PALADIN" },
  { race = "Orc", class = "WARRIOR" },
  { race = "Human", class = "MAGE" },
  { race = "Scourge", class = "ROGUE" },
}
if FOREVER then table.insert(CHARACTERS, { race = "Skyborne", class = "HUNTER" }) end

local function matrix()
  for _, character in ipairs(CHARACTERS) do
    for _, level in ipairs(LEVELS) do
      for _, hardcore in ipairs({ false, true }) do
        play({ race = character.race, class = character.class, level = level, hardcore = hardcore })
        if hardcore then
          play({ race = character.race, class = character.class, level = level, hardcore = true, die = true })
        end
      end
    end
  end
end

-- ── secret values (Forever): each call of the game, one at a time, answers with secrets
-- (the calls Blizzard's documentation flags as secret, the ones the client really hides: the run goes no further,
-- as a call the documentation does not flag is not a promise. SECRETS=all plays every call of the game, to see what
-- a guess would cost. luajit ... secrets <part of a call's name> plays one. addon-kit/docs/battery.md)
local ONLY = arg and arg[2]
local secretsRan, secretsTargets, secretsFlagged
local function secrets()
  if not FOREVER then
    io.write("✓ secrets: Classic Era has no secret values, nothing to run\n")
    return
  end
  local ran = 0
  local done = X.drive({ FOREVER = true }, {
    strict = G.strict,
    flaggedOnly = os.getenv("SECRETS") ~= "all", -- (SECRETS=all: every call of the game, as Primer's does)
    each = function(label, name)
      if ONLY and not name:find(ONLY, 1, true) then return end
      local before = #failures
      local spec = { race = "Dwarf", class = "PALADIN", level = 12, hardcore = true, die = true }
      play(spec)
      for i = before + 1, #failures do
        failures[i] = label .. ": " .. failures[i]
      end
      ran = ran + 1
    end,
  })
  secretsRan, secretsTargets, secretsFlagged = ran, done.targets, done.flagged
end

G.login()
if MODE == "secrets" then
  secrets()
else
  matrix()
end

if MODE == "secrets" then
  b.finish(
    ("✓ secrets: %d functions answered with secret values, whole and field by field, %d lives played, %d of them flagged by the documentation (%.1fs)"):format(
      secretsTargets or 0,
      secretsRan or 0,
      secretsFlagged or 0,
      os.clock() - started
    ),
    "matrix"
  )
end
b.finish(
  ("✓ matrix: %d cases, %d tab draws, %d hovers, %d clicks, %d words, %s, %.1fs (%s)"):format(
    cases,
    draws,
    b.hovers,
    b.clicks,
    b.texts,
    G.strict and G.strict.report():match("^%d+ calls") or "lenient",
    os.clock() - started,
    FOREVER and "Forever" or "Classic Era"
  )
)
