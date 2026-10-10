-- Runs the addon against a fake WoW API and replays a character's life.
--   luajit addon/test/sim.lua              (from the repo root): Classic
--   FOREVER=1 luajit addon/test/sim.lua    the same on Forever's client (no
--                                          combat log: kills from corpses fought)
local G = dofile("addon/test/game.lua")
local FOREVER, ns, D, state, fire, printed, panel = G.forever, G.ns, G.D, G.state, G.fire, G.printed, G.panel
local toasted, linkHandlers, login, logout, reload, kill, itemLink =
  G.toasted, G.linkHandlers, G.login, G.logout, G.reload, G.kill, G.itemLink
local function check(cond, msg)
  assert(cond, msg)
  io.write("✓ " .. msg .. "\n")
end

-- A quest's story is its own: the game's quests by their real ids
-- (addon/test/quests.lua), a made-up quest by an id no quest has.
local truth = dofile("addon/test/truth.lua")(ns, dofile("addon/test/quests.lua").titles)
local function trueStories(where)
  local wrong = {}
  truth(HearthtaleChar or {}, where, function(at, msg) table.insert(wrong, at .. ": " .. msg) end)
  check(#wrong == 0, "every quest told by its own story (" .. where .. ")" .. (wrong[1] and ": " .. wrong[1] or ""))
end

-- ── a life ───────────────────────────────────────────────────────────────────
check(
  D.client == (FOREVER and "forever" or "classic") and D.writing.opening,
  "each game's data file is its own, with the writing"
)
check(ns.forever == FOREVER, FOREVER and "Forever is recognised" or "Classic is recognised")

-- A game message's blanks, in argument order: today's numbered format and an
-- older client's plain one read alike.
do
  local today, older = QUEST_OBJECTS_FOUND, "%s: %d/%d"
  local name, have, need = ns.match("QUEST_OBJECTS_FOUND", "0/8 Tough Wolf Meat")
  QUEST_OBJECTS_FOUND = older
  local name2, have2, need2 = ns.match("QUEST_OBJECTS_FOUND", "Tough Wolf Meat: 0/8")
  QUEST_OBJECTS_FOUND = today
  check(
    name == "Tough Wolf Meat" and have == "0" and need == "8" and name2 == name and have2 == have and need2 == need,
    'an objective read in argument order, numbered ("0/8 Tough Wolf Meat") or not'
  )
end
HearthtaleChar = { guid = "Player-6113-0DEAD000", chapters = {} }
login()
local J = HearthtaleChar
local function ch(i) return J.chapters[i or #J.chapters] end
local function moments(k, i)
  local out = {}
  for _, m in ipairs(ch(i).log) do
    if m.k == k then table.insert(out, m) end
  end
  return out
end
check(
  panel.registered
    and panel.name == "Hearthtale"
    and panel.settings.HEARTHTALE_CHAT
    and panel.settings.HEARTHTALE_TOAST
    and panel.settings.HEARTHTALE_MINIMAPHIDDEN.get() == true,
  "the settings page: chat lines, the alert, the minimap button (shown)"
)
local hcSetting = panel.settings.HEARTHTALE_HARDCORE
if FOREVER then
  check(hcSetting and not J.hardcore, "Forever: the game can't tell Hardcore; the settings ask")
  hcSetting.set(true)
  fire("PLAYER_LOGIN")
  check(
    J.hardcore and J.hardcoreChosen and hcSetting.get() == true,
    "Forever: declared Hardcore, and it holds at the next login"
  )
else
  check(not hcSetting, "Classic: the game tells Hardcore; no setting for it")
end

-- The welcome: on the account's first login, once; its choices are the
-- settings (and this character's Hardcore where the game can't tell).
local welcome, choices = ns.welcome.frame, ns.welcome.rows
check(
  welcome and welcome:IsShown() and #choices == (FOREVER and 4 or 3),
  "the first login: the welcome page and its choices"
)
check(choices[1].box:GetChecked() and choices[2].box:GetChecked(), "… which show the settings as they are")
choices[1].scripts.OnClick(choices[1])
check(ns.option("chat") == false and not choices[1].box:GetChecked(), "… a click on a choice's words changes it")
choices[1].scripts.OnClick(choices[1])
check(ns.option("chat") == true, "… and back")
if FOREVER then
  ns.showWelcome() -- (shown again: as the settings are now)
  check(choices[4].box:GetChecked() and J.hardcore, "… Forever: this character's Hardcore, as declared")
  choices[4].scripts.OnClick(choices[4])
  check(not J.hardcore and not J.hardcoreChosen, "… which the welcome changes too")
  choices[4].scripts.OnClick(choices[4])
end
welcome:Hide()
fire("PLAYER_ENTERING_WORLD", true, false)
check(ns.option("welcomed") and not welcome:IsShown(), "… seen once: closed, it stays closed at the next login")
SlashCmdList.HEARTHTALE("welcome")
check(welcome:IsShown(), "… /ht welcome shows it again")
welcome:Hide()

-- Settings are each character's own ("Name - Realm"), kept for the game
-- installation: another character's can be taken, picked or by a code.
local profiles = HearthtaleSettings.profiles
check(
  ns.profileKey() == "Sealinedion - Nightslayer" and profiles[ns.profileKey()].welcomed,
  "settings: this character's own profile"
)
profiles["Brannok - Nightslayer"] = { chat = false, toast = false, minimapHidden = true, minimapAngle = 90 }
SlashCmdList.HEARTHTALE("welcome")
local picker = ns.welcome.picker
local select = picker.select
check(
  select.text:GetText() == "Choose a character"
    and select.rows[1].text:GetText() == "Brannok - Nightslayer"
    and not (select.rows[2] and select.rows[2]:IsShown()),
  "… the welcome offers the other characters of this game, in a select"
)
select.scripts.OnClick(select)
check(select.list:IsShown(), "… a click opens its list")
select.rows[1].scripts.OnClick(select.rows[1])
check(
  select:GetValue() == "Brannok - Nightslayer"
    and select.text:GetText() == "Brannok - Nightslayer"
    and not select.list:IsShown(),
  "… a choice closes it and shows the one chosen"
)
picker.copy.scripts.OnClick(picker.copy)
check(
  ns.option("chat") == false
    and ns.option("toast") == false
    and ns.option("minimapHidden") == true
    and ns.option("minimapAngle") == 90
    and not choices[1].box:GetChecked()
    and ns.option("welcomed"),
  "… its choices copied (never whether it saw the welcome), the boxes with them"
)
local code = ns.exportCode()
check(code == "HT1:c0:t0:h1:a90", "… a code for them: " .. code)
check(ns.importCode("HT1:c1:t1:h0:a200") and ns.option("chat") and ns.option("toast"), "… a code taken")
check(
  not ns.importCode("hello") and not ns.importCode("HT1:x9") and ns.option("chat"),
  "… a wrong code refused, nothing changed"
)
check(ns.importCode("HT1:c0:z7") and ns.option("chat") == false, "… a later version's part left out")
SlashCmdList.HEARTHTALE("import " .. code)
check(ns.option("minimapAngle") == 90, "… /ht import CODE")
ns.importCode("HT1:c1:t1:h0:a200")
local copyFrom = panel.settings.HEARTHTALE_COPYFROM
local offered = copyFrom and copyFrom.options()
check(
  offered and offered[2] and offered[2].value == "Brannok - Nightslayer",
  "… the Options page offers the other characters too"
)
copyFrom.set("Brannok - Nightslayer")
check(ns.option("chat") == false, "… and copies one")
ns.importCode("HT1:c1:t1:h0:a200")
welcome:Hide()
-- Another character's first login: its own profile and welcome; the account's
-- settings of before (0.6.0) for one who kept a journal, the defaults for one
-- who didn't.
HearthtaleSettings.chat = false
state.name = "Newcomer"
ns.loadProfile({ chapters = {} })
fire("PLAYER_ENTERING_WORLD", true, false)
check(welcome:IsShown() and ns.option("chat") == true, "… a new character: the defaults, and its own welcome")
welcome:Hide()
state.name = "Oldtimer"
ns.loadProfile({ chapters = { {} } })
check(ns.option("chat") == false and not ns.option("welcomed"), "… one with a journal from before: its old settings")
HearthtaleSettings.chat, profiles.Newcomer, profiles["Newcomer - Nightslayer"], profiles["Oldtimer - Nightslayer"] =
  nil, nil, nil, nil
profiles["Brannok - Nightslayer"] = nil
state.name = nil
ns.loadProfile(J)

local mm = HearthtaleMinimapButton
check(mm and mm:IsShown(), "the minimap button")
SlashCmdList.HEARTHTALE("minimap")
check(not mm:IsShown() and panel.settings.HEARTHTALE_MINIMAPHIDDEN.get() == false, "/ht minimap hides it")
SlashCmdList.HEARTHTALE("minimap")
check(mm:IsShown(), "and shows it again")
SlashCmdList.HEARTHTALE("settings")
check(panel.opened == 42, "/ht settings opens the page")
SlashCmdList.HEARTHTALE("link k7q2mx")
check(
  J.link and J.link.code == "K7Q2MX" and J.link.at and printed[#printed]:find("K7Q2MX", 1, true),
  "/ht link CODE keeps the code in the saved file, for the next upload"
)
SlashCmdList.HEARTHTALE("link K7Q2")
check(J.link.code == "K7Q2MX" and printed[#printed]:find("six letters", 1, true), "… and refuses what isn't a code")
check(
  J.guid == state.guid and J.began.level == 1 and not J.prologue,
  "a new character named like a deleted one starts a fresh journal, from level 1: no prologue"
)
check(
  J.hardcore and J.race == "Dwarf" and J.class == "PALADIN" and J.name == "Sealinedion",
  "it knows who it is: a Hardcore dwarf paladin"
)
check(J.faction == "alliance", "it records the player's faction for cultures shared by both factions")
check(
  #J.chapters == 1
    and ch().start.zone == "Dun Morogh"
    and ch().start.sub == "Coldridge Valley"
    and ch().start.level == 1
    and not ch().start.night,
  "chapter 1 begins at Coldridge Valley, by day"
)
check(#moments("place") == 0, "where it starts is named by the opening, not a discovery")
state.sub = "Anvilmar"
fire("ZONE_CHANGED")
fire("ZONE_CHANGED")
check(
  #moments("place") == 1 and moments("place")[1].sub == "Anvilmar" and not moments("place")[1].new,
  "a new place, once, as it happens"
)

-- A quest: accepted from someone (its objectives in the log a moment later),
-- turned in to someone else.
state.npc, state.titles = "Sten Stoutarm", { [179] = "Dwarven Outfitters" }
if FOREVER then
  fire("QUEST_ACCEPTED", 179)
else
  fire("QUEST_ACCEPTED", 1, 179)
end
state.objectives = { [179] = { { text = "Tough Wolf Meat: 0/8", type = "item", numRequired = 8 } } }
fire("QUEST_LOG_UPDATE")
state.npc, state.titles = "Balir Frosthammer", {}
fire("QUEST_COMPLETE")
fire("QUEST_TURNED_IN", 179, 80, 0)
state.npc = nil
local quest = moments("quest")[1]
local o = quest and quest.objectives and quest.objectives[1]
check(
  quest
    and quest.title == "Dwarven Outfitters"
    and quest.giver == "Sten Stoutarm"
    and quest.ender == "Balir Frosthammer"
    and ch().quests == 1
    and o
    and o.type == "item"
    and o.name == "Tough Wolf Meat"
    and o.n == 8,
  "a quest turned in: what it asked (eight Tough Wolf Meat), who gave it, who I returned to"
)
check(
  quest and quest.giverSex == "female" and quest.enderSex == "female" and not quest.enderBeast,
  "… and what the game said of them: their sex (the writer's pronoun), no beast"
)
state.npc, state.objectives =
  "Balir Frosthammer", { [9000180] = { { text = "Rockjaw Trogg slain: 0/6", type = "monster", numRequired = 6 } } }
if FOREVER then
  fire("QUEST_ACCEPTED", 9000180)
else
  fire("QUEST_ACCEPTED", 2, 9000180)
end
fire("QUEST_COMPLETE")
fire("QUEST_TURNED_IN", 9000180, 80, 0)
state.npc = nil
local q2 = moments("quest")[2].objectives[1]
check(
  q2.type == "monster" and q2.name == "Rockjaw Trogg" and q2.n == 6,
  '… a kill quest read through the game\'s own format ("%s slain")'
)

-- A quest's work done in one place and turned in at another: the work is a
-- moment where it happened, the turn-in a return; a note in hand from the
-- start has nothing done before its delivery.
local function accept(id, title, giver, objective)
  state.npc, state.titles = giver, { [id] = title }
  state.objectives = { [id] = { objective } }
  if FOREVER then
    fire("QUEST_ACCEPTED", id)
  else
    fire("QUEST_ACCEPTED", 1, id)
  end
  fire("QUEST_LOG_UPDATE")
  state.npc = nil
end
local function turnIn(id, ender)
  state.npc, state.questShown = ender, id
  fire("QUEST_COMPLETE")
  fire("QUEST_TURNED_IN", id, 80, 0)
  state.npc, state.questShown = nil, nil
end
accept(
  182,
  "The Troll Cave",
  "Grelin Whitebeard",
  { text = "Frostmane Troll Whelp slain: 0/14", type = "monster", numRequired = 14 }
)
state.sub = "Frostmane Hold"
state.objectives[182][1].finished = true
fire("QUEST_LOG_UPDATE")
fire("QUEST_LOG_UPDATE")
local done = moments("done")
check(
  #done == 1
    and done[1].sub == "Frostmane Hold"
    and done[1].giver == "Grelin Whitebeard"
    and done[1].objectives[1].name == "Frostmane Troll Whelp",
  "a quest's work done: a moment where it happened, once"
)
state.sub = "Anvilmar"
turnIn(182, "Grelin Whitebeard")
check(
  moments("quest")[3].told and moments("quest")[3].sub == "Anvilmar",
  "… its turn-in, elsewhere, a return to who asked"
)
accept(
  234,
  "Coldridge Valley Mail Delivery",
  "Talin Keeneye",
  { text = "Grelin's Letter: 1/1", type = "item", numRequired = 1, finished = true }
)
fire("QUEST_LOG_UPDATE")
turnIn(234, "Grelin Whitebeard")
local mail = moments("quest")[4]
check(
  #moments("done") == 1 and not mail.told and mail.objectives[1].held,
  "a note in hand from the start: nothing done before its delivery"
)

-- Kills.
kill(1, 1)
kill(1, 2)
kill(2, 3)
local kills = moments("kill")
check(
  #kills == 2
    and kills[1].name == "Ragged Young Wolf"
    and kills[1].kind == "Wolf"
    and kills[1].first
    and kills[2].first
    and ch().kills["Ragged Young Wolf"] == 2,
  "a moment for the chapter's first of each creature (the first of its kind marked), every kill counted"
)
if FOREVER then
  G.corpse(2, 99)
  check(ch().kills["Rockjaw Trogg"] == 1, "Forever: a corpse never fought doesn't count")
end

-- Learning, loot and money.
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:19740|h[Blessing of Might]|h|r.")
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:20271|h[Judgement]|h|r.")
local learned = moments("learned")
check(
  #learned == 1 and learned[1].spells[1] == "Blessing of Might" and learned[1].spells[2] == "Judgement",
  "a trainer's visit: one moment, its spells"
)
G.cast("Judgement")
G.cast("Judgement")
G.cast("Holy Light") -- (known before the journal: no lesson of its)
check(
  learned[1].used and #learned[1].used == 1 and learned[1].used[1] == "Judgement",
  "a lesson put to use: its first cast, on its moment, once"
)
reload()
G.cast("Blessing of Might")
check(#learned[1].used == 2 and learned[1].used[2] == "Blessing of Might", "a lesson put to use after a reload")
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:13819|h[Summon Warhorse]|h|r.")
local power = moments("power")[1]
check(
  power and power.spell == "Summon Warhorse" and power.kind == "steed" and #moments("learned") == 1,
  "a class's own steed: a moment of its own, by its spell id"
)
fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Frostmane Leather Vest") .. ".")
check(#moments("loot") == 0, "green loot isn't told (it is, once worn)")
fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Pendant of Myzrael", 3) .. ".")
fire("CHAT_MSG_LOOT", "Brannor receives loot: " .. itemLink("Pendant of Myzrael", 3) .. ".")
check(
  #moments("loot") == 1 and moments("loot")[1].link:find("Pendant of Myzrael", 1, true),
  "a blue find is (mine only)"
)
fire("CHAT_MSG_LOOT", "You receive item: " .. itemLink("Chausses of Westfall", 3) .. ".")
check(#moments("loot") == 1, "a blue quest reward received is no find (told when worn, if it is)")

-- Gear: what is worn when the journal first looks is noted quietly; then each
-- item worn for the first time (green or better), crafted ones marked.
state.gear = { [5] = "Ragged Leather Gloves" }
fire("PLAYER_EQUIPMENT_CHANGED", 5)
check(#moments("gear") == 0 and J.worn, "the gear worn at first: noted, not told")
state.gear[10] = "Ragged Leather Gloves"
state.gear[5] = "Frostmane Leather Vest"
fire("PLAYER_EQUIPMENT_CHANGED", 5)
fire("CHAT_MSG_LOOT", "You create: " .. itemLink("Handstitched Leather Belt") .. ".")
state.gear[6] = "Handstitched Leather Belt"
fire("PLAYER_EQUIPMENT_CHANGED", 6)
state.gear[5] = "Ragged Leather Gloves"
fire("PLAYER_EQUIPMENT_CHANGED", 5)
state.gear[5] = "Frostmane Leather Vest"
fire("PLAYER_EQUIPMENT_CHANGED", 5)
local gear = moments("gear")
check(
  #gear == 2 and gear[1].link:find("Frostmane Leather Vest", 1, true) and not gear[1].made and gear[2].made,
  "gear worn for the first time, once (put back on, no news); what I made, marked"
)

-- Professions: known ones noted quietly; a new one, a new rank, riding.
state.skills =
  { { "Professions", true }, { "Mining", false, 75 }, { "Secondary Skills", true }, { "Cooking", false, 75 } }
fire("SKILL_LINES_CHANGED")
check(#moments("prof") == 0 and J.profs.Mining == 75, "the trades known at first: noted, not told")
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:2575|h[Mining]|h|r.")
state.skills[3] = { "Leatherworking", false, 75 }
table.insert(state.skills, 4, { "Secondary Skills", true })
state.skills[2][3] = 150
table.insert(state.skills, { "Apprentice Riding", false, 75 })
fire("SKILL_LINES_CHANGED")
local profs = {}
for _, m in ipairs(moments("prof")) do
  profs[m.name] = m
end
check(
  profs.Leatherworking
    and profs.Leatherworking.learned
    and profs.Mining
    and profs.Mining.rank == "journeyman"
    and #moments("riding") == 1,
  "a trade taken up, a new rank, riding learned"
)
check(#moments("learned") == 1 and #moments("learned")[1].spells == 2, "a trade's own spell isn't a trainer's lesson")
-- A trade given up, and taken up again; a folded header hides trades, and
-- nothing is given up for it.
local skills = state.skills
state.skills = {}
for _, s in ipairs(skills) do
  if s[1] ~= "Leatherworking" then table.insert(state.skills, s) end
end
fire("SKILL_LINES_CHANGED")
local dropped = moments("prof")[#moments("prof")]
check(
  dropped.name == "Leatherworking" and dropped.dropped and J.profs.Leatherworking == nil,
  "a trade given up: once, and no longer known"
)
state.skills[1] = { "Professions", true, nil, true }
fire("SKILL_LINES_CHANGED")
check(#moments("prof") == 3 and J.profs.Mining == 150, "a folded header in the skills pane: nothing given up")
state.skills = skills
fire("SKILL_LINES_CHANGED")
local again = moments("prof")[#moments("prof")]
check(again.name == "Leatherworking" and again.learned and again.again, "a trade taken up again, after it was given up")

-- The first ride: on what.
state.mounted, state.buffs = true, { { name = "Brown Ram", id = 6899 } }
fire("UNIT_AURA", "player")
fire("UNIT_AURA", "player")
state.mounted, state.buffs = false, nil
check(
  #moments("mount") == 1 and moments("mount")[1].name == "Brown Ram" and moments("mount")[1].kind == "ram",
  "the first ride: once, and on what"
)

-- A hunter's pet (the journal is a paladin's: a hunter for a moment).
J.class = "HUNTER"
state.pet = { name = "Grrr", family = "Bear" }
fire("UNIT_PET", "player")
check(J.pets and J.pets.Grrr and #moments("tame") == 0, "the pet at hand when the journal first looks: noted")
state.pet = { name = "Old Bessie", family = "Boar" }
fire("UNIT_PET", "player")
check(
  J.pets["Old Bessie"] and #moments("tame") == 0,
  "a pet new to the journal, no taming before it: from the stable, noted"
)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-4170-0-1-1515-0001", 1515)
state.pet = { name = "Saltwater Snapjaw", family = "Crocolisk" }
fire("UNIT_PET", "player")
state.pet = { name = "Snapjaw", family = "Crocolisk" }
fire("UNIT_PET", "player")
check(
  #moments("tame") == 1 and moments("tame")[1].name == "Snapjaw",
  "a pet tamed after a Tame Beast: once, by the name given it soon after"
)
state.pet.dead = true
fire("UNIT_HEALTH", "pet")
fire("UNIT_HEALTH", "pet")
state.pet.dead = false
fire("UNIT_HEALTH", "pet")
check(
  #moments("tame") == 1
    and moments("tame")[1].family == "Crocolisk"
    and #moments("petdied") == 1
    and moments("petdied")[1].name == "Snapjaw",
  "a pet tamed, and its death, once"
)
J.class, state.pet = "PALADIN", nil

state.money = 150
fire("PLAYER_MONEY")
state.money = 100
fire("PLAYER_MONEY")
state.money = 400
fire("PLAYER_MONEY")
check(ch().gold == 450, "money gained (gains only)")

-- A close call, at night.
state.target = { id = 4, n = 7 }
fire("PLAYER_TARGET_CHANGED")
state.hour, state.health = 22, 7
fire("UNIT_HEALTH", "player")
fire("UNIT_HEALTH", "player")
state.health = 100
local close = moments("close")
check(
  #close == 1 and close[1].hp == 7 and close[1].foe == "Frostmane Novice" and close[1].night,
  "a close call: under a tenth of my health, the foe, the hour; once a minute"
)

-- A level is a moment, not a chapter.
state.level = 2
local before = #printed
fire("PLAYER_LEVEL_UP", 2)
check(
  moments("level")[1] and moments("level")[1].level == 2 and #J.chapters == 1 and #printed == before,
  "a level up: a moment in the chapter, which goes on"
)

-- An inn, a flight, a profession, a rare, an elite.
state.bind = "Thunderbrew Distillery"
fire("HEARTHSTONE_BOUND")
TakeTaxiNode(2)
fire("CHAT_MSG_SKILL", "Your skill in Mining has increased to 50.")
fire("CHAT_MSG_SKILL", "Your skill in Mining has increased to 51.")
kill(3, 11)
check(
  moments("inn")[1].place == "Thunderbrew Distillery"
    and moments("flight")[1].from == "Ironforge, Dun Morogh"
    and moments("flight")[1].to == "Thelsamar, Loch Modan",
  "an inn and a flight"
)
check(
  #moments("skill") == 1 and moments("skill")[1].name == "Mining" and moments("skill")[1].rank == 50,
  "a profession, at its milestones only"
)
kill(5, 12)
check(moments("rare")[1] and moments("rare")[1].name == "Timber", "a rare slain")
check(
  moments("kill")[3] and moments("kill")[3].name == "Gibblewilt" and moments("kill")[3].elite,
  "an elite slain, marked"
)

-- Company and a dungeon, with its boss.
state.party.party1 = { name = "Brannor", class = "WARRIOR" }
fire("GROUP_ROSTER_UPDATE")
fire("GROUP_ROSTER_UPDATE")
state.instance = "The Deadmines"
fire("PLAYER_ENTERING_WORLD")
fire("PLAYER_ENTERING_WORLD")
fire("ENCOUNTER_END", 1, "Edwin VanCleef", 1, 5, 1)
fire("ENCOUNTER_END", 2, "Cookie", 1, 5, 0)
kill(6, 14)
check(not moments("kill")[4].elite, "an elite inside a dungeon is not an open-world feat")
check(
  #moments("group") == 1
    and moments("group")[1].name == "Brannor"
    and #moments("dungeon") == 1
    and moments("dungeon")[1].name == "The Deadmines"
    and #moments("boss") == 1
    and moments("boss")[1].name == "Edwin VanCleef",
  "who joined me, the dungeon (once), the boss beaten"
)
state.instance = nil

-- A campfire: a moment per stop.
state.auras[7353] = true
fire("UNIT_AURA", "player")
fire("UNIT_AURA", "player")
state.auras[7353] = nil
fire("UNIT_AURA", "player")
state.auras[7353] = true
fire("UNIT_AURA", "player")
check(#moments("campfire") == 1, "a campfire's warmth: one moment per stop")
state.auras[7353] = nil
fire("UNIT_AURA", "player")
-- One of Forever's camps, with company: who sat at it with me.
do
  local party, sub = state.party, state.sub
  state.party, state.sub =
    { party1 = { name = "Thessaly", class = "PRIEST", guid = "Player-1-00CC" } }, "Gol'Bolar Quarry"
  state.auras[1229739] = true
  fire("UNIT_AURA", "player")
  local stop = moments("campfire")[2]
  check(
    stop and stop.camp and stop.with and stop.with[1] == "Thessaly" and not moments("campfire")[1].camp,
    "a stop at one of Forever's camps: a camp, and who sat at it with me"
  )
  state.auras[1229739] = nil
  fire("UNIT_AURA", "player")
  state.party, state.sub = party, sub
end

-- The book of that chapter, its diary entry, written as it happens.
local book = ns.writeBook(J)
local one = book.chapters[1]
check(
  not book.prologue
    and one.number == 1
    and one.open
    and one.from == 1
    and one.to == 2
    and one.close
    and one.rare
    and one.text ~= ""
    and not one.text:find("{", 1, true),
  "chapter 1, still being written: its entry, its levels and its marks (a close call, a rare)"
)
check(not one.text:find("level two", 1, true), "a level reached isn't told (the chapter's levels say it)")
io.write("    " .. one.text:gsub("\n\n", "\n    ") .. "\n")

-- The book, open. (an entry's title: its weightiest moment, else "Entry N")
local function titled(c, n) return ns.writeBook(c).chapters[n].title or ("Entry %d"):format(n) end
SlashCmdList.HEARTHTALE("")
local B, page, rows = HearthtaleFrame, HearthtalePage, ns.bookRows
check(
  B:IsShown()
    and G.portrait() == "player"
    and B.hardcore:IsShown()
    and B.hardcore.label:GetText() == "Hardcore"
    and #B.hardcore.lines == 2,
  "/ht opens the book: my portrait, and Hardcore's mark beside it (what it means, who says so)"
)
check(
  rows[1]:IsShown()
    and rows[1].title:GetText() == titled(ns.journal(), 1)
    and rows[1].place:GetText():find("still being written", 1, true)
    and page.title:GetText() == titled(ns.journal(), 1)
    and page.over:GetText():find("STILL BEING WRITTEN", 1, true)
    and page.sub:GetText():lower():find("levels 1 to 2", 1, true)
    and not page.sub:GetText():find("still being written", 1, true),
  "a row per entry: its title, still being written; the page's header says so above its title, its levels under it"
)
check(rows[1].marks[1]:IsShown() and rows[1].marks[2]:IsShown(), "marks: a skull for a close call, a star for a rare")
state.sub = "Brewnall Village"
fire("ZONE_CHANGED")
local bind = state.bind
state.bind = "Brewnall Village"
fire("HEARTHSTONE_BOUND") -- (a place is told with what is done there)
state.bind = bind
-- The chapter as its diary entry, the journal as the character writes it,
-- written again from the record at each new moment.
check(
  page.body:GetText() == ns.writeBook(ns.journal()).chapters[1].text and page.body:GetText() ~= "",
  "a chapter reads as its diary entry, written again at each new moment"
)
SlashCmdList.HEARTHTALE("")
check(not B:IsShown(), "/ht again closes it")

-- A night in the wild: the chapter goes on; a /reload is no night.
G.played(1800)
local logBeforeNight = #ch().log
logout()
-- The book, written into the saved file at logout (for the site).
local B1 = J.book
check(
  B1
    and B1.version == "0.2.0"
    and B1.client == (FOREVER and "forever" or "classic")
    and B1.level == 2
    and #B1.chapters == 1
    and B1.chapters[1].open
    and B1.chapters[1].diary
    and not B1.chapters[1].text
    and B1.chapters[1].began,
  "at logout, the book is written into the saved file: each chapter as its diary entry"
)
check(J.realm == "Nightslayer" and J.region == 3, "… and where the character lives")
local view = ns.settledView(J)
check(
  #ch().log == logBeforeNight and view.chapters[1].log[#view.chapters[1].log].k == "night" and view ~= J,
  "a logout in the wild: the book tells the night outdoors (not the waking yet); the journal itself waits for the next login"
)
check(B1.chapters[1].diary == ns.writeBook(view).chapters[1].text, "the saved text is the game's, word for word")
G.wait(3600) -- (away an hour: a real break)
login()
check(
  #J.chapters == 1
    and moments("night")[1]
    and moments("wake")[1]
    and moments("wake")[1].after == "night"
    and #printed == before,
  "a logout in the wild: a night outdoors, then the road again, the same chapter"
)
local nights = #moments("night")
-- A relog (away two minutes): no break, nothing told.
local logBeforeRelog = #ch().log
logout()
G.wait(120)
login()
check(#ch().log == logBeforeRelog and #moments("night") == nights, "a relog of two minutes: no night, nothing told")
reload()
check(#moments("night") == nights and #J.chapters == 1, "a /reload is no night")

-- A rest at an inn closes the chapter.
state.resting, state.sub = true, "Thunderbrew Distillery"
local printedBefore = #printed
logout()
G.wait(3600)
local B2 = J.book.chapters[1]
check(
  not B2.open and B2.ended and B2.place == "Thunderbrew Distillery" and not ch(1).ended and #printed == printedBefore,
  "a logout at an inn: the saved book tells the chapter closed at once (the journal settles it at the next login, with its chat line)"
)
state.resting = false
login()
local first = ch(1)
check(
  #J.chapters == 2
    and first.ended
    and first.ended.how == "rest"
    and first.ended.place == "Thunderbrew Distillery"
    and first.ended.level == 2
    and first.played >= 1800
    and not ch(2).ended
    and ch(2).start.level == 2,
  "a logout at an inn closes the chapter; the next begins"
)
check(
  printed[#printed]:find("entry 1 is written", 1, true) and printed[#printed]:find("|Hhearthtale:chapter:1|h", 1, true),
  "a line in chat, with a link to it"
)
local closed = ns.writeBook(J).chapters[1]
check(not closed.open and closed.place == "Thunderbrew Distillery", "closed where I rested")

-- Too little written: a rest doesn't close it.
state.resting = true
logout()
G.wait(3600)
state.resting = false
login()
check(
  #J.chapters == 2 and moments("rested")[1] and moments("wake")[1].after == "rest",
  "a rest with almost nothing written: a line, and the chapter goes on"
)

-- A campfire closes one too, with a few moments written.
for i = 1, 3 do
  state.titles = { [9000200 + i] = "Errand " .. i }
  fire("QUEST_TURNED_IN", 9000200 + i, 80, 0)
end
state.auras[1229739] = true
logout()
G.wait(3600)
state.auras[1229739] = nil
login()
check(#J.chapters == 3 and ch(2).ended.how == "campfire", "a logout by a campfire closes the chapter")

-- The cap: four hours in a chapter, and any logout closes it.
for i = 1, 3 do
  state.titles = { [9000300 + i] = "Chore " .. i }
  fire("QUEST_TURNED_IN", 9000300 + i, 80, 0)
end
G.played(4 * 3600 + 60)
logout()
G.wait(3600)
login()
check(
  #J.chapters == 4 and ch(3).ended.how == "long" and moments("night", 3)[1].last,
  "past four hours, a night outdoors closes it"
)

linkHandlers.hearthtale("hearthtale:chapter:1")
check(B:IsShown() and page.title:GetText() == titled(ns.journal(), 1), "the chapter's link opens the book at it")
check(
  rows[1].place:GetText():find("Thunderbrew Distillery, levels 1 to 2", 1, true),
  "… listed with where it closed and its levels"
)
SlashCmdList.HEARTHTALE("")
panel.settings.HEARTHTALE_CHAT.set(false)
local lines = #printed
ns.onChapter(1)
check(#printed == lines, "chat lines can be turned off")
panel.settings.HEARTHTALE_CHAT.set(true)

-- Death.
state.sub = "Kharanos"
if not FOREVER then
  G.fall()
  fire("COMBAT_LOG_EVENT_UNFILTERED")
end
state.health = 0
fire("PLAYER_DEAD")
check(
  J.death
    and J.death.level == 2
    and J.death.zone == "Dun Morogh"
    and J.death.cause == (FOREVER and "foe" or "fall")
    and ch().ended.how == "death",
  FOREVER and "a Hardcore death: where, at what level; it ends the chapter"
    or "a Hardcore death: where, at what level, how (a fall); it ends the chapter"
)
state.health = 100

-- A Hardcore death closes the book: nothing more is recorded; it joins the Hall
-- of the Fallen (a copy of its records), with a chat line and the game's toast.
local fallen = HearthtaleHall and HearthtaleHall.lives[state.guid]
check(
  J.closed
    and fallen
    and fallen.name == "Sealinedion"
    and fallen.raceName == "Dwarf"
    and fallen.realm == "Nightslayer"
    and #fallen.chapters == 4
    and fallen ~= J,
  "a Hardcore death closes the book; a copy joins the Hall of the Fallen"
)
check(
  printed[#printed]:find("closed", 1, true) and printed[#printed]:find("|Hhearthtale:hall:" .. state.guid, 1, true),
  "a chat line says so, with a link to the Hall"
)
check(
  #toasted == 1 and toasted[1].Title:GetText() == "The book is closed" and toasted[1].Name:GetText() == "Sealinedion",
  "the game's toast: the book is closed"
)
local logBefore = #ch().log
state.sub = "Brewnall Village"
fire("ZONE_CHANGED")
login()
check(#ch().log == logBefore and #J.chapters == 4, "a closed book records nothing more, even at the next login")
logout()
local fallenLife = HearthtaleHall.lives[state.guid]
check(
  J.book
    and J.book.epitaph
    and #J.book.chapters == 4
    and not J.book.chapters[4].open
    and fallenLife.book
    and fallenLife.book.epitaph == J.book.epitaph
    and fallenLife.book.level == 2,
  "a closed book is still written at logout, and its life in the Hall too"
)
local hallBook = fallenLife.book
logout()
check(fallenLife.book == hallBook, "… once per version of the addon")
login()
local closedBook = ns.writeBook(J)
check(
  closedBook.epitaph
    and closedBook.epitaph:find("Sealinedion", 1, true)
    and closedBook.epitaph:find("level two", 1, true)
    and not closedBook.epitaph:find("{", 1, true),
  "its epitaph: who, where, at what level"
)
io.write("    " .. closedBook.epitaph .. "\n")

-- The link opens the Hall at that life: its epitaph, then its chapters.
linkHandlers.hearthtale("hearthtale:hall:" .. state.guid)
check(
  B:IsShown()
    and B.selectedTab == 2
    and rows[1].title:GetText() == "Sealinedion"
    and rows[2].title:GetText() == "Epitaph"
    and rows[3].title:GetText() == titled(fallenLife, 1)
    and page.title:GetText() == "Sealinedion"
    and page.body:GetText():find(closedBook.epitaph, 1, true)
    and page.sub:GetText():find("Level 2 Dwarf Paladin", 1, true)
    and page.over:GetText() == "HARDCORE  \194\183  FALLEN",
  "the link opens the Hall: the life, its epitaph, its chapters"
)
rows[6].scripts.OnClick(rows[6])
check(
  page.title:GetText() == titled(fallenLife, 4)
    and page.over:GetText():find("THE END", 1, true)
    and page.body:GetText():find(closedBook.epitaph, 1, true),
  "its last chapter ends with the epitaph"
)
ns.showTab(1)
check(
  B.hardcore:IsShown()
    and B.hardcore.label:GetText() == "Fallen"
    and page.title:GetText() == titled(ns.journal(), 4)
    and page.body:GetText():find(closedBook.epitaph, 1, true),
  "the Journal tab: my own closed book, the same end, the mark now Fallen"
)
SlashCmdList.HEARTHTALE("")

-- A character met mid-life: a prologue from what the game knows.
trueStories("life 1")
HearthtaleChar = nil
state.guid, state.level, state.questsDone, state.hardcore =
  "Player-6113-0FFFFFF0", 23, { [1] = true, [2] = true, [3] = true }, false
login()
local P = HearthtaleChar.prologue
check(HearthtaleChar.rode == true, "a journal begun with riding known: ridden before, no first ride to tell")
fire("TIME_PLAYED_MSG", 86400, 3600)
fire("TIME_PLAYED_MSG", 90000, 7200)
check(
  P
    and P.level == 23
    and P.quests == 3
    and P.inn == "Thunderbrew Distillery"
    and P.played == 86400
    and HearthtaleChar.chapters[1],
  "a character met mid-life gets a prologue: its level, quests done, inn, time played when first heard"
)
ns.writerUsed = {}
local later = ns.writeBook(HearthtaleChar)
local usedBeginning = false
for kind in pairs(ns.writerUsed) do
  if kind:find("^beginning#") or kind:find("/beginning#", 1, true) then usedBeginning = true end
end
check(
  later.prologue and later.prologue:find("^%u") and later.chapters[1].from == 23 and not usedBeginning,
  "its book opens with the prologue; its first chapter is no beginning"
)
io.write("    " .. later.prologue .. "\n")
SlashCmdList.HEARTHTALE("")
check(
  rows[1].title:GetText() == "Prologue"
    and rows[2].title:GetText() == titled(HearthtaleChar, 1)
    and not (rows[3] and rows[3]:IsShown())
    and page.title:GetText() == titled(HearthtaleChar, 1),
  "its book lists the prologue, then chapter 1"
)
rows[1].scripts.OnClick(rows[1])
check(
  page.title:GetText() == "Prologue"
    and page.sub:GetText():find("level 23", 1, true)
    and page.body:GetText() == later.prologue,
  "the prologue reads"
)
SlashCmdList.HEARTHTALE("")

-- A death on a normal realm: told in its chapter, with its way back once it
-- comes; the book goes on.
state.health, state.target = 0, nil
fire("PLAYER_DEAD")
state.health = 100
local K = HearthtaleChar
state.sub = "Gol'Bolar Quarry"
fire("ZONE_CHANGED")
-- (which kinds the book told: the shared lines or the race's own)
local function toldKinds()
  ns.writerUsed = {}
  ns.writeBook(K)
  local kinds = {}
  for key in pairs(ns.writerUsed) do
    local kind = key:match("^[%a]+/(.-)#") or key:match("^(.-)#")
    if kind then kinds[kind] = true end
  end
  ns.writerUsed = nil
  return kinds
end
local waiting = toldKinds()
local died, last = 0, K.chapters[#K.chapters].log
for _, m in ipairs(last) do
  if m.k == "died" then died = died + 1 end
end
check(
  not K.closed
    and died == 1
    and last[#last].sub == "Gol'Bolar Quarry"
    and waiting.died
    and not HearthtaleHall.lives[state.guid],
  "a death on a normal realm: in its chapter's entry, no Hall, the book goes on"
)

-- How I came back from death: a ghost's run to my body, the spirit healer's
-- bargain, a companion's resurrection; each a moment of its own.
local function revived()
  local r = {}
  for _, m in ipairs(K.chapters[#K.chapters].log) do
    if m.k == "revived" then table.insert(r, m) end
  end
  return r
end
state.ghost, state.sub = true, "Kharanos"
fire("PLAYER_ALIVE")
G.wait(300)
state.ghost, state.sub = false, "Gol'Bolar Quarry"
fire("PLAYER_UNGHOST")
local back = revived()[1]
check(
  back and back.how == "corpse" and back.graveyard == "Kharanos" and back.took == 300,
  "a ghost's run back to my body: from which graveyard, how long"
)
local kinds = toldKinds()
check(kinds["died-back"] and not kinds.revived, "… told with the death, in one sentence")
G.wait(60)
state.health = 0
fire("PLAYER_DEAD")
state.health = 100
state.ghost = true
fire("PLAYER_ALIVE")
state.ghost, state.auras[15007] = false, true
fire("PLAYER_UNGHOST")
state.auras[15007] = nil
check(revived()[2] and revived()[2].how == "healer", "the spirit healer's bargain (its sickness tells it)")
G.wait(60)
state.health = 0
fire("PLAYER_DEAD")
fire("PLAYER_DEAD") -- (the game may tell one death twice)
state.health = 100
fire("RESURRECT_REQUEST", "Thessaly")
fire("PLAYER_ALIVE")
check(
  revived()[3] and revived()[3].how == "ally" and revived()[3].by == "Thessaly",
  "raised where I fell by a companion"
)
local deaths = 0
for _, m in ipairs(K.chapters[#K.chapters].log) do
  if m.k == "died" then deaths = deaths + 1 end
end
check(deaths == 3, "a death the game tells twice is told once")

-- The other side met in the open world: who, of what race and class; in a
-- battleground, nothing at all.
G.vanquish("Player-1-00AA", "Leofric", "Human", "PALADIN")
local function told(k)
  local r = {}
  for _, m in ipairs(K.chapters[#K.chapters].log) do
    if m.k == k then table.insert(r, m) end
  end
  return r
end
local pvp = told("pvp")[1]
check(
  pvp and pvp.name == "Leofric" and pvp.race == "Human" and pvp.class == "PALADIN",
  "a player of the other side killed: name, race and class"
)
state.instance, state.instanceKind = "Warsong Gulch", "pvp"
local before, killsBefore = #K.chapters[#K.chapters].log, K.chapters[#K.chapters].kills["Ragged Young Wolf"]
G.vanquish("Player-1-00AB", "Aldwin", "Human", "WARRIOR")
kill(1, 77)
check(
  #K.chapters[#K.chapters].log == before and K.chapters[#K.chapters].kills["Ragged Young Wolf"] == killsBefore,
  "a battleground is no part of the tale: no moment, no kill counted"
)
state.instance, state.instanceKind = nil, nil

-- A raid: one moment, its number, not every name.
state.raid, state.party =
  true, {
    party1 = { name = "A", class = "MAGE" },
    party2 = { name = "B", class = "PRIEST" },
    party3 = { name = "C", class = "ROGUE" },
  }
fire("GROUP_ROSTER_UPDATE")
fire("GROUP_ROSTER_UPDATE")
local raids = told("group")
check(#raids == 1 and raids[1].raid == 4, "a raid joined: one moment, how many")
state.raid, state.party = nil, {}
fire("GROUP_ROSTER_UPDATE")

-- A stretch at a craft: one moment while the same thing keeps coming.
for _ = 1, 3 do
  fire("CHAT_MSG_LOOT", "You create: " .. itemLink("Linen Bandage") .. ".")
end
fire("CHAT_MSG_LOOT", "You create: " .. itemLink("Heavy Linen Bandage") .. "x2.")
local made = told("made")
check(#made == 2 and made[1].n == 3 and made[2].n == 2, "what was made: one moment per thing, counted")

-- A quest given up after its work was done: the work taken back.
accept(9000190, "Bring Back the Mug", "Brewmaster", { text = "Lost Mug: 0/1", type = "item", numRequired = 1 })
state.objectives[9000190][1].finished = true
fire("QUEST_LOG_UPDATE")
fire("QUEST_REMOVED", 9000190)
local gone = told("done")
check(gone[#gone] and gone[#gone].id == 9000190 and gone[#gone].abandoned, "a quest abandoned: its work is taken back")

-- A quest shared by a companion: mine, its giver unknown (not the companion).
state.target = { player = true, guid = "Player-1-00CC", name = "Thessaly" }
accept(9000191, "Shared Errand", nil, { text = "Wolf Pelt: 0/3", type = "item", numRequired = 3 })
state.target = nil
check(
  HearthtaleChar.pending[9000191] and HearthtaleChar.pending[9000191].giver == nil,
  "a shared quest: mine, its giver not the companion who shared it"
)

local text = ns.writeBook(K).chapters[#K.chapters].text
check(
  text:find("died three times", 1, true) and text:find("Leofric", 1, true) and not text:find("Mug", 1, true),
  "its entry tells them: the deaths together, the duel won; not the abandoned quest"
)

-- A quest given up after the chapter that told its work closed: that chapter
-- stays as it was written.
accept(9000192, "Lost Ledger", "Clerk", { text = "Old Ledger: 0/1", type = "item", numRequired = 1 })
state.objectives[9000192][1].finished = true
fire("QUEST_LOG_UPDATE")
local closed = K.chapters[#K.chapters]
closed.ended = { at = time(), level = 10, how = "rest" }
ns.chapter()
fire("QUEST_REMOVED", 9000192)
local ledger
for _, m in ipairs(closed.log) do
  if m.k == "done" and m.id == 9000192 then ledger = m end
end
check(
  ledger and not ledger.abandoned and HearthtaleChar.pending[9000192] == nil,
  "a quest given up after its chapter closed: the closed chapter isn't rewritten"
)

-- Kills credited to me: my group's killing blows, and a quest's count gone up
-- for a creature no kill told (another's blow on one I fought: the game
-- credits whoever tagged it); a kill both told and counted counts once.
local function killsOf(name) return K.chapters[#K.chapters].kills[name] or 0 end
local leopard = G.creature("Snow Leopard Prowler", "Beast", "Cat")
local before = killsOf("Snow Leopard Prowler")
accept(
  9000193,
  "Grund and Gozwin",
  "Grund Drokda",
  { text = "Snow Leopard Prowler slain: 0/2", type = "monster", numRequired = 2 }
)
kill(leopard, 501, true) -- (another's killing blow)
state.objectives[9000193][1] = { text = "Snow Leopard Prowler slain: 1/2", type = "monster", numRequired = 2 }
fire("QUEST_LOG_UPDATE")
check(killsOf("Snow Leopard Prowler") == before + 1, "a kill the quest credits me with, another's blow, is counted")
kill(leopard, 502)
state.objectives[9000193][1] =
  { text = "Snow Leopard Prowler slain: 2/2", type = "monster", numRequired = 2, finished = true }
fire("QUEST_LOG_UPDATE")
check(killsOf("Snow Leopard Prowler") == before + 2, "… and one told and counted, once")
state.party = { party1 = { name = "Thessaly", class = "PRIEST", guid = "Player-1-00TH" } }
G.killedBy("Player-1-00TH", leopard, 503)
check(killsOf("Snow Leopard Prowler") == before + 3, "a groupmate's killing blow is a kill of ours")
G.killedBy("Player-1-00ZZ", leopard, 504)
check(killsOf("Snow Leopard Prowler") == before + 3, "… a stranger's isn't")
state.party = {}

local learnedBefore = #told("learned")
-- Firsts of a life: the first bag on my back (looted: they are rare at
-- first), the first gold piece, a warlock's first demon of a kind and a
-- druid's first form (both learned while the journal was kept).
fire("CHAT_MSG_LOOT", "You receive loot: " .. G.itemLink("Small Brown Pouch", 1) .. ".")
state.bags = { [1] = { name = "Small Brown Pouch", slots = 6 } }
fire("BAG_UPDATE_DELAYED")
state.bags[2] = { name = "Linen Bag", slots = 6 }
fire("BAG_UPDATE_DELAYED")
local bags = told("bag")
check(
  #bags == 1 and bags[1].looted and bags[1].slots == 6 and bags[1].link:find("Small Brown Pouch", 1, true),
  "the first bag on my back, once: looted, its slots"
)
local richBefore = #told("gold")
state.money = 9990
fire("PLAYER_MONEY")
state.money = 10020
fire("PLAYER_MONEY")
state.money = 25000
fire("PLAYER_MONEY")
check(#told("gold") == richBefore + 1, "the first gold piece, once")
HearthtaleChar.class = "WARLOCK"
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: Summon Imp.")
state.pet = { name = "Zigfik", family = "Imp", guid = "Pet-0-1-1-1-416-0001" }
fire("UNIT_PET", "player")
fire("UNIT_PET", "player")
local demon = told("demon")
check(
  #demon == 1 and demon[1].name == "Zigfik" and demon[1].family == "Imp" and #told("learned") == learnedBefore,
  "a warlock's first imp, by its name, once (not told as a lesson)"
)
accept(9000196, "Pet Work", "Grelin Whitebeard", { text = "Wolf Pelt: 0/1", type = "item", numRequired = 1 })
state.objectives[9000196][1].finished = true
fire("QUEST_LOG_UPDATE")
local withPet = told("done")
withPet = withPet[#withPet]
check(
  withPet and withPet.id == 9000196 and withPet.pet == "Zigfik" and withPet.petFamily == "Imp",
  "a quest's work done with my pet out: which one"
)
turnIn(9000196, "Grelin Whitebeard")
state.pet = { name = "Ganrul", family = "Voidwalker", guid = "Pet-0-1-1-1-1860-0002" }
fire("UNIT_PET", "player")
check(#told("demon") == 1, "… and no demon whose summoning the journal didn't see learned")
state.pet = nil
HearthtaleChar.class = "DRUID"
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: Bear Form.")
state.form = 5
fire("UPDATE_SHAPESHIFT_FORM")
fire("UPDATE_SHAPESHIFT_FORM")
state.form = 1
fire("UPDATE_SHAPESHIFT_FORM")
local shifts = told("shift")
check(#shifts == 1 and shifts[1].form == "bear", "a druid's first shift into a form learned, once")
state.form = nil
HearthtaleChar.class = state.class

-- The player's own: a title given an entry, a note in its margin (/ht title,
-- /ht note, the window), laid over the written book, which never changes.
local last = #K.chapters
local before = ns.writeBook(K).chapters[last]
SlashCmdList.HEARTHTALE("title The Long Walk")
SlashCmdList.HEARTHTALE("note Grik'nir was |cff1eff00|Hitem:2589|h[Linen Cloth]|h|r easier than I feared.")
local mine = ns.writeBook(K).chapters[last]
check(
  mine.title == "The Long Walk" and mine.writtenTitle == before.title and mine.text == before.text,
  "a title given an entry, over the journal's own, its entry the same"
)
check(
  mine.note == "Grik'nir was [Linen Cloth] easier than I feared.",
  "a note in its margin: plain text, its case kept"
)
SlashCmdList.HEARTHTALE("title")
check(ns.writeBook(K).chapters[last].title == before.title, "an entry's own title removed: the journal's again")
SlashCmdList.HEARTHTALE("note 1 " .. ("word "):rep(300))
check(#K.notes[1].text <= 1000, "a note kept to a thousand letters")
SlashCmdList.HEARTHTALE("note 1")
check(K.notes[1] == nil, "a note removed, nothing left of it")
ns.openChapter(last)
ns.bookEdit.scripts.OnClick()
local editor = ns.bookEditor
check(
  editor and editor.shown and editor.note:GetText() == mine.note,
  "the window's editor opens on the entry's own words"
)
editor.title:SetText("Cold Hands")
editor.note:SetText("")
editor.save.scripts.OnClick()
check(
  K.notes[last].title == "Cold Hands" and K.notes[last].text == nil and not editor.shown,
  "the editor keeps a title; a note emptied is removed"
)
ns.writeDown(K)
check(K.book.chapters[last].title == "Cold Hands", "the title given saved for the site")
SlashCmdList.HEARTHTALE("note Cold, all of it.")
ns.writeDown(K)
check(K.book.chapters[last].note == "Cold, all of it.", "the note saved for the site")

-- A specialization: the way a life took, never its talents. On Classic, the
-- tree holding most of the points, ten at least; on Forever, the one chosen.
-- One held when the journal first looked was noted quietly.
local specsBefore = #told("spec")
if FOREVER then
  state.specs = { "Arcane", "Fire", "Frost" }
  state.spec = 2
  fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
  fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
  state.spec = 3
  fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
else
  state.talents = { { "Arcane", 3 }, { "Fire", 9 }, { "Frost", 0 } }
  fire("CHARACTER_POINTS_CHANGED")
  check(#told("spec") == specsBefore, "talents spread thin: no specialization yet")
  state.talents[2][2] = 10
  fire("CHARACTER_POINTS_CHANGED")
  fire("CHARACTER_POINTS_CHANGED")
  state.talents = { { "Arcane", 0 }, { "Fire", 0 }, { "Frost", 0 } }
  fire("CHARACTER_POINTS_CHANGED")
  check(#told("spec") == specsBefore + 1, "talents unlearned: no change while none is held")
  state.talents[3][2] = 12
  fire("CHARACTER_POINTS_CHANGED")
end
local specs = told("spec")
check(
  #specs == specsBefore + 2
    and specs[#specs - 1].name == "Fire"
    and specs[#specs - 1].was == nil
    and specs[#specs].name == "Frost"
    and specs[#specs].was == "Fire",
  "a specialization taken, then another, by its name (the one before kept)"
)
check(ns.writeBook(K).chapters[#K.chapters].text:find("Frost", 1, true), "a specialization told in its entry")

-- The highest level the game allows: a moment of the life, and the journal
-- goes on after it.
state.maxLevel = state.level + 1
state.level = state.level + 1
fire("PLAYER_LEVEL_UP", state.level)
local endCh = K.chapters[#K.chapters]
local top = endCh.log[#endCh.log]
local count = #endCh.log
kill(1, 78)
check(
  top.k == "level" and top.top and not endCh.ended and not K.finished and #endCh.log > count,
  "the highest level: a moment of its own, and the journal goes on"
)
local summit = ns.writeBook(K).chapters[#K.chapters].text
io.write("    " .. summit:gsub("\n", " ") .. "\n")
check(summit:find("level twenty%-four"), "the highest level, told in its entry")
-- (a journal an older version closed there opens again at the next login)
K.finished = true
reload()
check(K.finished == nil, "a journal closed at the highest level by an older version goes on")
state.maxLevel = nil

if FOREVER then
  for i, faction in ipairs({ "Horde", "Alliance" }) do
    trueStories("life 2")
    HearthtaleChar = nil
    state.guid, state.level, state.race, state.faction = "Player-Skyborne-" .. i, 1, "Skyborne", faction
    login()
    check(
      HearthtaleChar.race == "Skyborne" and HearthtaleChar.faction == faction:lower(),
      "a Skyborne player's " .. faction .. " tradition follows the faction reported by the game"
    )
    -- Existing saves acquire faction on their next login too.
    HearthtaleChar.faction = nil
    login()
    check(HearthtaleChar.faction == faction:lower(), "an older Skyborne journal acquires its faction at login")
  end
end

-- A first login before the game says where (Forever, at times): the place
-- it tells a moment later is where the chapter began, not an arrival.
trueStories("life 3")
HearthtaleChar = nil
state.guid, state.level, state.race, state.faction, state.class = "Player-4619-015E0F3F", 1, "Dwarf", nil, "PRIEST"
state.zone, state.sub = nil, nil
login()
state.zone, state.sub = "Dun Morogh", "Coldridge Valley"
fire("ZONE_CHANGED")
local A = HearthtaleChar
check(
  A.chapters[1].start.zone == "Dun Morogh" and A.chapters[1].start.sub == "Coldridge Valley" and #A.chapters[1].log == 0,
  "a place told after the login: where the chapter began"
)
-- A quest kept from 0.5.0 with "0" for its objectives' names: read again
-- from the log, its work told by name when done.
A.pending = {
  [170] = {
    title = "A New Threat",
    giver = "Balir Frosthammer",
    objectives = { { type = "monster", name = "0", n = 6 }, { type = "monster", name = "0", n = 6 } },
  },
}
state.objectives = {
  [170] = {
    { text = "Rockjaw Trogg slain: 6/6", type = "monster", numRequired = 6, finished = true },
    { text = "Burly Rockjaw Trogg slain: 6/6", type = "monster", numRequired = 6, finished = true },
  },
}
fire("QUEST_LOG_UPDATE")
local repaired = A.chapters[1].log[#A.chapters[1].log]
check(
  repaired
    and repaired.k == "done"
    and repaired.objectives[1].name == "Rockjaw Trogg"
    and repaired.objectives[2].name == "Burly Rockjaw Trogg",
  "a quest misread by 0.5.0, read again: its work told by name"
)

-- An item the game hasn't loaded yet: its objective says "0/8 " with no
-- name. Not kept so: read again until the name is there.
A.pending = {}
state.npc, state.titles = "Sten Stoutarm", { [179] = "Dwarven Outfitters" }
state.objectives = { [179] = { { text = ": 0/8", type = "item", numRequired = 8 } } }
if FOREVER then
  fire("QUEST_ACCEPTED", 179)
else
  fire("QUEST_ACCEPTED", 1, 179)
end
fire("QUEST_LOG_UPDATE")
check(A.pending[179] and A.pending[179].objectives == nil, "an objective without its name yet: not kept")
state.objectives = { [179] = { { text = "Tough Wolf Meat: 0/8", type = "item", numRequired = 8 } } }
fire("QUEST_LOG_UPDATE")
check(
  A.pending[179].objectives and A.pending[179].objectives[1].name == "Tough Wolf Meat",
  "… read again once the game has it"
)
-- one kept blank by 0.5.1: read again too
A.pending[179].objectives[1].name = " "
fire("QUEST_LOG_UPDATE")
check(A.pending[179].objectives[1].name == "Tough Wolf Meat", "a name 0.5.1 kept blank, read again")

-- A writer's error at logout: the last book is kept, the error reported.
local before = A.book
local reported
geterrorhandler = function()
  return function(err) reported = err end
end
local realWrite = ns.writeBook
ns.writeBook = function() error("writer broke") end
logout()
ns.writeBook = realWrite
geterrorhandler = nil
check(
  A.book == before and reported and tostring(reported):find("writer broke"),
  "a writer's error at logout: the last book kept, the error shown"
)

-- Forever's names: a first name and a surname (UnitName's second value,
-- a realm elsewhere). The character's full name kept; a companion's too,
-- with the first name the journal calls them by.
trueStories("life 4")
HearthtaleChar = nil
state.guid, state.name, state.surname = "Player-4619-015E4047", "Hellefie", "Namzar"
state.party = { party1 = { name = "Harrysaun", surname = "Brightwood", class = "PALADIN" } }
login()

fire("GROUP_ROSTER_UPDATE")
local H = HearthtaleChar
local joined = H.chapters[#H.chapters].log[#H.chapters[#H.chapters].log]
if FOREVER then
  check(
    H.name == "Hellefie Namzar"
      and joined
      and joined.k == "group"
      and joined.name == "Harrysaun Brightwood"
      and joined.first == "Harrysaun",
    "Forever: full names kept, the first name for the journal"
  )
else
  check(
    H.name == "Hellefie" and joined and joined.name == "Harrysaun" and not joined.first,
    "elsewhere the second name is a realm: left out"
  )
end
state.name, state.surname, state.party = nil, nil, {}

-- Forever: a creature someone else hit first isn't mine; one I fought, chosen
-- before the fight and dying still chosen, is.
do
  local C = HearthtaleChar
  local function wolves()
    local cur = C.chapters[#C.chapters]
    return cur.kills["Ragged Young Wolf"] or 0
  end
  local before = wolves()
  kill(1, 990)
  kill(1, 991, true)
  if FOREVER then
    check(wolves() == before + 1, "Forever: a creature fought and seen dying is a kill; one another claimed isn't")
  end
  -- Forever's PARTY_KILL: my killing blow however dealt (a DoT on a creature
  -- no longer targeted), my pet's, not a groupmate's.
  if FOREVER then
    local cur = C.chapters[#C.chapters]
    local trogg = ("Creature-0-4170-0-12-%d-%08X"):format(2, 7001)
    state.target = { id = 2, n = 7001 }
    fire("PLAYER_TARGET_CHANGED") -- (seen once: its name known)
    state.target = { id = 1, n = 7002 }
    fire("PLAYER_TARGET_CHANGED") -- (another targeted now)
    local troggs = cur.kills["Rockjaw Trogg"] or 0
    fire("PARTY_KILL", state.guid, trogg)
    check(
      (cur.kills["Rockjaw Trogg"] or 0) == troggs + 1,
      "Forever: a DoT's kill, the creature no longer targeted, counts"
    )
    state.pet = { guid = "Pet-0-4170-0-12-416-0000ABCD", name = "Zalnok" }
    local before = cur.kills["Ragged Young Wolf"] or 0
    fire("PARTY_KILL", state.pet.guid, ("Creature-0-4170-0-12-%d-%08X"):format(1, 7002))
    check((cur.kills["Ragged Young Wolf"] or 0) == before + 1, "… my pet's kill too")
    local wolves = cur.kills["Ragged Young Wolf"]
    state.target = { id = 1, n = 7004 }
    fire("PLAYER_TARGET_CHANGED") -- (seen: only whose kill it is decides)
    fire("PARTY_KILL", "Player-4619-0BADBEEF", ("Creature-0-4170-0-12-%d-%08X"):format(1, 7004))
    check(cur.kills["Ragged Young Wolf"] == wolves, "… not a groupmate's")
    state.pet, state.target = nil, nil
  end
  -- A night indoors without an inn (a hall, a barracks): told as such.
  state.indoors = true
  logout()
  G.wait(3600)
  login()
  state.indoors = nil
  local log = C.chapters[#C.chapters].log
  local night, wake = log[#log - 1], log[#log]
  check(
    night and night.k == "night" and night.inside and wake and wake.k == "wake" and wake.inside,
    "a night indoors without an inn: kept as such, for the writer"
  )
end

trueStories("the last life")
io.write(FOREVER and "all good (Forever)\n" or "all good\n")
