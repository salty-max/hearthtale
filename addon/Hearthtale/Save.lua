-- The book, written into the saved file at each logout, word for word what the
-- game shows: HearthtaleChar.book, and each fallen life's in the Hall
-- (HearthtaleHall.lives[guid].book). Ravenpost carries the saved files to
-- hearthtale.app after a logout or a /reload, so the site shows the text as is
-- and never writes its own. The chapter a rest has just closed is told closed
-- (the logout settled in advance: ns.settledView); a /reload is put right by
-- the next logout.
--   book = { version, client, at, level, prologue, epitaph,
--            chapters = { { number, text, place, from, to, open, rare, close,
--                           began, ended } } }
local _, ns = ...

local function addonVersion()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get("Hearthtale", "Version") or nil
end

local function written(c, level)
  local b = ns.writeBook(c)
  local out = { version = addonVersion(), client = ns.data.client, at = time(), level = level,
    prologue = b.prologue, epitaph = b.epitaph, chapters = {} }
  for _, ch in ipairs(b.chapters) do
    local raw = ch.chapter or {}
    table.insert(out.chapters, { number = ch.number, text = ch.text, place = ch.place, from = ch.from, to = ch.to,
      open = ch.open, rare = ch.rare, close = ch.close,
      began = raw.start and raw.start.at, ended = raw.ended and raw.ended.at })
  end
  return out
end

function ns.writeDown(c)
  local version = addonVersion()
  c.book = written(ns.settledView(c), UnitLevel("player"))
  -- the fallen: written once per version of the addon (their records no longer change)
  for _, life in ipairs(ns.fallen()) do
    if not (life.book and life.book.version == version) then
      life.book = written(life, life.death and life.death.level)
    end
  end
end
