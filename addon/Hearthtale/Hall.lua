-- The Hall of the Fallen (account-wide, HearthtaleHall.lives[guid]):
-- the closed books of Hardcore characters, kept whole. What is kept is their
-- records (the text is written when read, as any journal's, and saved at
-- logout for the site: Save.lua), with their realm
-- and the game's names of their race and class. A Hardcore death closes the
-- book: a chat line with a link to it, and a banner (the kit's, among the
-- game's alerts), the character's portrait in it, a skull on it; a click
-- opens the Hall at that life.
local _, ns = ...

local function hall()
  if type(HearthtaleHall) ~= "table" then HearthtaleHall = {} end
  HearthtaleHall.lives = HearthtaleHall.lives or {}
  return HearthtaleHall.lives
end

-- The fallen, the most recent first.
function ns.fallen()
  local list = {}
  for _, life in pairs(hall()) do
    table.insert(list, life)
  end
  table.sort(list, function(a, b)
    local x, y = a.death and a.death.at or 0, b.death and b.death.at or 0
    if x ~= y then return x > y end
    return (a.name or "") < (b.name or "")
  end)
  return list
end
function ns.fallenLife(guid) return hall()[guid] end

-- The book joins the Hall: a copy of the records as they were at the end.
local function enshrine(c)
  local life = ns.copy(c)
  -- its book is written at the next logout, with the death, in the words its
  -- closed entries were saved with (the copy of the saved book, no version:
  -- written once more, Save.lua)
  life.pending = nil
  if life.book then life.book.version = nil end
  life.realm = GetRealmName and GetRealmName() or nil
  life.raceName, life.className = UnitRace("player"), UnitClass("player")
  hall()[c.guid] = life
  return life
end

-- ── the banner ───────────────────────────────────────────────────────────────
local LOGO = "Interface\\AddOns\\Hearthtale\\Media\\Logo"
local banners

local function toast(guid)
  local life = hall()[guid]
  if not life then return end
  banners = banners or ns.kit.banners({ name = "HearthtaleBanner", art = LOGO, seconds = 20 })
  banners:show({
    picture = ns.kit.unitPortrait("player", LOGO),
    medal = ns.FALLEN_SEAL,
    kicker = "The book is closed",
    title = life.name or "",
    tip = "Click to read it in the Hall of the Fallen",
    click = function() ns.openHall(guid) end,
    guid = guid,
  })
end

-- ── a Hardcore death ─────────────────────────────────────────────────────────
local function link(guid, text) return ns.link("hall:" .. guid, text) end

ns.onDeath = function()
  local c = ns.journal()
  if not (c and c.hardcore and c.guid) then return end
  enshrine(c)
  print(
    ns.PREFIX
      .. ("The journal of %s is closed. It rests in the %s."):format(c.name or "?", link(c.guid, "Hall of the Fallen"))
  )
  if ns.option("toast") then toast(c.guid) end
  if ns.onHall then ns.onHall() end
end

-- A closed book missing from the Hall (the account's saved data lost, or the
-- death came with the addon off): it joins it at login.
ns.onLogin = function(c)
  if c.closed and c.guid and not hall()[c.guid] then enshrine(c) end
end
