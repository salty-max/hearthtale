-- A life played in two languages, as the user's own on 14 October 2026: a
-- Forever dwarf warrior played in English, then on a French client, then in
-- English again. The record keeps the game's names in English (one trade, no
-- path named after the class, English places, spells and creature kinds),
-- and its journal holds no word of French. Then a record kept the old way
-- (0.9: "Minage" beside "Mining", "Guerrier" after "Warrior"), mended at
-- login, its closed entry written again.
--   FOREVER=1 luajit addon/test/languages.lua
local lives = dofile("addon/test/lives.lua")
local G = dofile("addon/test/game.lua")
local m = lives.moves(G)
local state, fire, ns = G.state, G.fire, G.ns
local failures = 0
local function check(ok, what)
  if ok then
    io.write("\226\156\147 ", what, "\n")
  else
    failures = failures + 1
    io.write("\226\156\151 ", what, "\n")
  end
end

-- What the French client says where the English one says the first.
local FR = {
  ["Dun Morogh"] = "Dun Morogh",
  ["Coldridge Valley"] = "Vall\195\169e des Frig\195\168res",
  ["Anvilmar"] = "Courbenclume",
  ["Mining"] = "Minage",
  ["Professions"] = "M\195\169tiers",
  ["Secondary Skills"] = "Comp\195\169tences secondaires",
  ["Weapon Skills"] = "Comp\195\169tences d'armes",
  ["Languages"] = "Langues",
  ["Dwarven"] = "Nain",
  ["Warrior"] = "Guerrier",
  ["Beast"] = "B\195\170te",
  ["Wolf"] = "Loup",
  ["Battle Shout"] = "Cri de guerre",
  -- (creatures, a quest, its giver, an item: told in English by their ids)
  ["Small Crag Boar"] = "Petit sanglier des rochers",
  ["Ragged Timber Wolf"] = "Loup des bois d\195\169charn\195\169",
  ["The Boar Hunter"] = "Le chasseur de sangliers",
  ["Talin Keeneye"] = "Talin Oeil-vif",
  ["Shining Silver Breastplate"] = "Cuirasse en argent brillant",
}
local NPC = { ["Talin Keeneye"] = 714 } -- (the giver's id, in its GUID)
local lang = "enUS"
local function said(name) return lang == "frFR" and name and FR[name] or name end
-- (the client's language: what the game's functions say in it)
local english = {
  GetRealZoneText = GetRealZoneText,
  GetSubZoneText = GetSubZoneText,
  GetBindLocation = GetBindLocation,
  GetSkillLineInfo = GetSkillLineInfo,
  UnitCreatureType = UnitCreatureType,
  UnitCreatureFamily = UnitCreatureFamily,
  UnitName = UnitName,
  UnitGUID = UnitGUID,
  GetQuestObjectives = C_QuestLog.GetQuestObjectives,
  GetTitleForQuestID = C_QuestLog.GetTitleForQuestID,
  QUEST_MONSTERS_KILLED = QUEST_MONSTERS_KILLED,
}
function UnitName(u)
  local name, second = english.UnitName(u)
  return said(name), second
end
function UnitGUID(u)
  if u == "npc" and NPC[state.npc or ""] then return ("Creature-0-4170-0-12-%d-00000001"):format(NPC[state.npc]) end
  return english.UnitGUID(u)
end
C_QuestLog.GetTitleForQuestID = function(id) return said(english.GetTitleForQuestID(id)) end
C_QuestLog.GetQuestObjectives = function(id)
  local list = english.GetQuestObjectives(id)
  for _, o in ipairs(list or {}) do
    if lang == "frFR" and o.text then
      o.text = o.text:gsub(
        "^(%d+/%d+) (.-) slain$",
        function(n, name) return n .. " " .. said(name) .. " tu\195\169" end
      )
    end
  end
  return list
end
function GetLocale() return lang end
function GetRealZoneText() return said(english.GetRealZoneText()) end
function GetSubZoneText() return said(english.GetSubZoneText()) end
function GetBindLocation() return said(english.GetBindLocation()) end
function GetSkillLineInfo(i)
  local name, header, expanded, a, b, c, max = english.GetSkillLineInfo(i)
  return said(name), header, expanded, a, b, c, max
end
function UnitCreatureType(u) return said(english.UnitCreatureType(u)) end
function UnitCreatureFamily(u) return said(english.UnitCreatureFamily(u)) end
C_Map = {
  GetAreaInfo = function(id)
    local en = ns.client.areas[id]
    return en and said(en)
  end,
}
-- Forever's specialization: one a class, named after it, from the first level
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 1491, said("Warrior") end
local function speak(l)
  G.logout()
  G.sleep(20 * 60)
  lang = l
  TRADE_SKILLS, SECONDARY_SKILLS = said("Professions"), said("Secondary Skills")
  QUEST_MONSTERS_KILLED = l == "frFR" and "%2$d/%3$d %1$s tu\195\169" or english.QUEST_MONSTERS_KILLED
  G.login()
end
local function learnSpell(id, name)
  fire("CHAT_MSG_SYSTEM", ("You have learned a new spell: |cff71d5ff|Hspell:%d|h[%s]|h|r."):format(id, said(name)))
  G.wait(60)
end

lives.begin(G, {
  name = "Gurdhil",
  race = "Dwarf",
  class = "WARRIOR",
  guid = "Player-6113-0C0FFEE1",
  level = 1,
  region = 3,
  hour = 10,
  zone = "Dun Morogh",
  sub = "Coldridge Valley",
  bind = "Anvilmar",
  skills = { { "Weapon Skills", true }, { "Languages", true }, { "Dwarven", false, 300 } },
})
-- in English: a trade taken up, a wolf or two, the inn
m.trade("Mining", 75, "Professions")
m.slay("Ragged Young Wolf", 3, "Beast", "Wolf")
m.go("Anvilmar")
-- on a French client
speak("frFR")
m.go("Coldridge Valley")
learnSpell(6673, "Battle Shout")
G.creature("Small Crag Boar", "Beast", "Boar", nil, 708) -- (the game's own ids)
G.creature("Ragged Timber Wolf", "Beast", "Wolf", nil, 704)
m.task(
  "The Boar Hunter",
  "Talin Keeneye",
  m.slain("Small Crag Boar", 12),
  function() m.slay("Small Crag Boar", 12, "Beast", "Boar") end
)
m.slay("Ragged Timber Wolf", 2, "Beast", "Wolf")
fire(
  "CHAT_MSG_LOOT",
  ("You receive loot: |cff0070dd|Hitem:2870::::::::|h[%s]|h|r."):format(said("Shining Silver Breastplate"))
)
m.ding()
-- in English again, and a rest at the inn
speak("enUS")
m.go("Anvilmar")
m.rest(8)

local c = HearthtaleChar
local profs, drops = {}, 0
for name in pairs(c.profs or {}) do
  table.insert(profs, name)
end
table.sort(profs)
local trades, specs, places, spells, kinds = {}, 0, {}, {}, {}
local killed, quest, loot = {}, nil, nil
for _, ch in ipairs(c.chapters) do
  for _, mo in ipairs(ch.log) do
    if mo.k == "prof" then table.insert(trades, (mo.dropped and "-" or "+") .. mo.name) end
    if mo.k == "spec" then specs = specs + 1 end
    if mo.zone then places[mo.zone] = true end
    if mo.sub then places[mo.sub] = true end
    if mo.k == "learned" then
      for _, sp in ipairs(mo.spells) do
        spells[sp] = true
      end
    end
    if mo.k == "kill" and mo.kind then kinds[mo.kind] = true end
    if mo.k == "kill" then killed[mo.name] = true end
    if mo.k == "quest" and mo.id == 183 then quest = mo end
    if mo.k == "loot" then loot = mo.link end
  end
end
for _ in pairs(c.dropped or {}) do
  drops = drops + 1
end
check(
  table.concat(profs, ",") == "Mining" and drops == 0,
  "one trade, Mining, never given up: " .. table.concat(profs, ",")
)
check(
  table.concat(trades, ",") == "+Mining",
  "the trades told: Mining taken up, once (" .. table.concat(trades, ",") .. ")"
)
check(specs == 0 and not c.spec, "no path named after the class, in any language")
check(
  places["Coldridge Valley"] and places.Anvilmar and not places[FR["Coldridge Valley"]] and not places.Courbenclume,
  "places in English"
)
check(spells["Battle Shout"] and not spells["Cri de guerre"], "a lesson learned in French, in English")
check(kinds.Wolf and kinds.Boar and not kinds.Loup, "creature kinds in English")
check(killed["Small Crag Boar"] and killed["Ragged Timber Wolf"], "creatures in English, by their ids")
check(
  quest
    and quest.title == "The Boar Hunter"
    and quest.giver == "Talin Keeneye"
    and quest.objectives
    and quest.objectives[1].name == "Small Crag Boar",
  "a quest in English: its title, its giver, its objective"
)
check(loot and loot:find("[Shining Silver Breastplate]", 1, true), "an item in English, by its id")
local book = ns.writeBook(c)
local all = {}
for _, ch in ipairs(book.chapters) do
  table.insert(all, ch.text or "")
end
local text = table.concat(all, "\n")
if os.getenv("SHOW") then io.write(text, "\n") end
local french
for _, word in ipairs({
  "inage",
  "Guerrier",
  "Vall\195\169e",
  "Courbenclume",
  "Cri de guerre",
  "Loup",
  "B\195\170te",
  "sanglier",
  "chasseur",
  "Oeil",
  "Cuirasse",
}) do
  if text:find(word, 1, true) then french = word end
end
check(not french, "the journal has no word of French" .. (french and (": " .. french) or ""))

-- A record kept the old way, before 0.10: what a French login wrote then.
local ch = c.chapters[1]
local at = ch.log[#ch.log].at - 30
local function old(mo)
  mo.at = at
  table.insert(ch.log, mo)
end
c.profs.Minage = 75
c.dropped = { Mining = true, Minage = true }
c.spec = "Warrior"
old({ k = "prof", name = "Minage", learned = true })
old({ k = "prof", name = "Mining", dropped = true })
old({ k = "spec", name = "Guerrier", was = "Warrior" })
at = at + 10
old({ k = "prof", name = "Mining", learned = true, again = true })
old({ k = "prof", name = "Minage", dropped = true })
old({ k = "spec", name = "Warrior", was = "Guerrier" })
old({ k = "learned", spells = { "Minage" } })
table.sort(ch.log, function(a, b) return a.at < b.at end)
c.book = c.book or {}
c.book.chapters = c.book.chapters or {}
if c.book.chapters[1] then c.book.chapters[1].diary = "I began to learn mining and minage." end
G.logout()
G.sleep(600)
G.login() -- (in English: mended at login)
local told = {}
for _, mo in ipairs(ch.log) do
  if mo.k == "prof" then table.insert(told, (mo.dropped and "-" or "+") .. mo.name) end
  if mo.k == "spec" then table.insert(told, "spec " .. mo.name) end
  if mo.k == "learned" then table.insert(told, "learned " .. table.concat(mo.spells, "/")) end
end
check(c.profs.Minage == nil and c.profs.Mining == 75 and next(c.dropped or {}) == nil, "an old record: one trade again")
check(c.spec == false, "an old record: the path named after the class let go")
check(
  table.concat(told, ",") == "+Mining,learned Battle Shout",
  "an old record: only what happened is told (" .. table.concat(told, ",") .. ")"
)
local saved = c.book.chapters[1]
check(not saved or saved.diary == nil, "an old record: its closed entry written again")
book = ns.writeBook(c)
check(not (book.chapters[1].text or ""):find("inage", 1, true), "an old record: no minage in its journal")

if failures > 0 then
  io.write(failures, " failed\n")
  os.exit(1)
end
io.write("all good (two languages)\n")
