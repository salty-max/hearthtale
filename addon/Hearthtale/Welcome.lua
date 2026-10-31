-- The welcome (the kit's, Kit.lua): once per character, a few seconds after
-- its first login (out of combat; /ht welcome shows it again), laid out as
-- the journal's window: on the left the logo and what the journal is; on the
-- right this character's choices (Settings.lua: a line in chat for each
-- entry, the minimap button, the alert when a Hardcore book closes, and its
-- Hardcore where the game can't tell), then another character's to take,
-- chosen among this game's or brought by a code (/ht export there). Closing
-- it, however, is enough to have seen it.
local _, ns = ...
local K = ns.kit
local L = K.L

local W = K.welcome({
  name = "HearthtaleWelcome",
  title = L["Welcome to Hearthtale"],
  art = "Interface\\AddOns\\Hearthtale\\Media\\Logo",
  logo = "Interface\\AddOns\\Hearthtale\\Media\\Logo",
  heading = "Hearthtale",
  tagline = L["Your character's own journal, written as you play."],
  intro = L["Play as you always do: Hearthtale keeps the record. The quests that mattered, the foes worth naming, the lands seen for the first time, the close calls."]
    .. "\n\n"
    .. L["Whenever you rest at an inn, in a city or by a campfire, the road since your last rest becomes an entry in your character's own voice."]
    .. "\n\n"
    .. L["On Hardcore, a death closes the book with an epitaph, and it joins the Hall of the Fallen."],
  profiles = ns.profiles,
  choices = function()
    local choices = {
      {
        text = L["The book by the minimap"],
        hint = L["Click it to open the journal. Drag it around the minimap."],
        get = function() return not ns.option("minimapHidden") end,
        set = function(v) ns.setOption("minimapHidden", not v) end,
      },
      {
        text = L["An alert when a book closes"],
        hint = L["A banner among the game's alerts, when a Hardcore character falls."],
        get = function() return ns.option("toast") end,
        set = function(v) ns.setOption("toast", v) end,
      },
    }
    if not ns.gameKnowsHardcore() then
      table.insert(choices, {
        text = L["This character is Hardcore"],
        hint = L["Its death will close its book. The game can't tell whether it is Hardcore."],
        get = ns.isHardcore,
        set = ns.setHardcore,
      })
    end
    table.insert(choices, K.collectChoice(ns.collect))
    return choices
  end,
  footnote = L["Change them any time: %s, or a right-click on the minimap button."]:format("/ht settings")
    .. " "
    .. L["/ht opens the journal."],
  open = {
    text = L["Open the journal"],
    click = function()
      if ns.toggle then ns.toggle() end
    end,
  },
  exportHint = L["Copy it (Ctrl+C), then on another character: Use a code, or /ht import CODE."],
  importHint = L["Paste the code (/ht export on the other character), then press Enter."],
  refused = L["That isn't a Hearthtale settings code."],
})

-- The welcome; "export": with this character's code ready to copy.
ns.welcome = W -- (its frame, rows, picker and code: for the tests)
function ns.showWelcome(mode) W:Show(mode) end
function ns.showCode() W:ShowCode() end

K.welcomeOnce(W, ns.profiles, function() return ns.journal() ~= nil end)
