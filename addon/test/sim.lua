-- Runs the addon against a fake WoW API and replays a character's life.
--   luajit addon/test/sim.lua              (from the repo root): Classic
--   FOREVER=1 luajit addon/test/sim.lua    the same on Forever's client (no
--                                          combat log: kills from corpses fought)
local G = dofile("addon/test/game.lua")
local FOREVER, ns, D, state, fire, printed, panel = G.forever, G.ns, G.D, G.state, G.fire, G.printed, G.panel
local toasted, linkHandlers, login, logout, reload, kill, itemLink = G.toasted, G.linkHandlers, G.login, G.logout, G.reload, G.kill, G.itemLink
local function check(cond, msg) assert(cond, msg); io.write("✓ " .. msg .. "\n") end

-- ── a life ───────────────────────────────────────────────────────────────────
check(D.client == (FOREVER and "forever" or "classic") and D.writing.opening, "each game's data file is its own, with the writing")
check(ns.forever == FOREVER, FOREVER and "Forever is recognised" or "Classic is recognised")
HearthtaleChar = { guid = "Player-6113-0DEAD000", chapters = {} }
login()
local J = HearthtaleChar
local function ch(i) return J.chapters[i or #J.chapters] end
local function moments(k, i)
  local out = {}
  for _, m in ipairs(ch(i).log) do if m.k == k then table.insert(out, m) end end
  return out
end
check(panel.registered and panel.name == "Hearthtale" and panel.settings.HEARTHTALE_CHAT
  and panel.settings.HEARTHTALE_TOAST and panel.settings.HEARTHTALE_MINIMAPHIDDEN.get() == true,
  "the settings page: chat lines, the alert, the minimap button (shown)")
local hcSetting = panel.settings.HEARTHTALE_HARDCORE
if FOREVER then
  check(hcSetting and not J.hardcore, "Forever: the game can't tell Hardcore; the settings ask")
  hcSetting.set(true)
  fire("PLAYER_LOGIN")
  check(J.hardcore and J.hardcoreChosen and hcSetting.get() == true, "Forever: declared Hardcore, and it holds at the next login")
else
  check(not hcSetting, "Classic: the game tells Hardcore; no setting for it")
end
local mm = HearthtaleMinimapButton
check(mm and mm:IsShown(), "the minimap button")
SlashCmdList.HEARTHTALE("minimap")
check(not mm:IsShown() and panel.settings.HEARTHTALE_MINIMAPHIDDEN.get() == false, "/ht minimap hides it")
SlashCmdList.HEARTHTALE("minimap")
check(mm:IsShown(), "and shows it again")
SlashCmdList.HEARTHTALE("settings")
check(panel.opened == 42, "/ht settings opens the page")
SlashCmdList.HEARTHTALE("link k7q2mx")
check(J.link and J.link.code == "K7Q2MX" and J.link.at and printed[#printed]:find("K7Q2MX", 1, true),
  "/ht link CODE keeps the code in the saved file, for the next upload")
SlashCmdList.HEARTHTALE("link K7Q2")
check(J.link.code == "K7Q2MX" and printed[#printed]:find("six letters", 1, true), "… and refuses what isn't a code")
check(J.guid == state.guid and J.began.level == 1 and not J.prologue, "a new character named like a deleted one starts a fresh journal, from level 1: no prologue")
check(J.hardcore and J.race == "Dwarf" and J.class == "PALADIN" and J.name == "Sealinedion", "it knows who it is: a Hardcore dwarf paladin")
check(J.faction == "alliance", "it records the player's faction for cultures shared by both factions")
check(#J.chapters == 1 and ch().start.zone == "Dun Morogh" and ch().start.sub == "Coldridge Valley" and ch().start.level == 1 and not ch().start.night,
  "chapter 1 begins at Coldridge Valley, by day")
check(#moments("place") == 0, "where it starts is named by the opening, not a discovery")
state.sub = "Anvilmar"
fire("ZONE_CHANGED")
fire("ZONE_CHANGED")
check(#moments("place") == 1 and moments("place")[1].sub == "Anvilmar" and not moments("place")[1].new, "a new place, once, as it happens")

-- A quest: accepted from someone (its objectives in the log a moment later),
-- turned in to someone else.
state.npc, state.titles = "Sten Stoutarm", { [179] = "Dwarven Outfitters" }
if FOREVER then fire("QUEST_ACCEPTED", 179) else fire("QUEST_ACCEPTED", 1, 179) end
state.objectives = { [179] = { { text = "Tough Wolf Meat: 0/8", type = "item", numRequired = 8 } } }
fire("QUEST_LOG_UPDATE")
state.npc, state.titles = "Balir Frosthammer", {}
fire("QUEST_COMPLETE")
fire("QUEST_TURNED_IN", 179, 80, 0)
state.npc = nil
local quest = moments("quest")[1]
local o = quest and quest.objectives and quest.objectives[1]
check(quest and quest.title == "Dwarven Outfitters" and quest.giver == "Sten Stoutarm" and quest.ender == "Balir Frosthammer" and ch().quests == 1
  and o and o.type == "item" and o.name == "Tough Wolf Meat" and o.n == 8,
  "a quest turned in: what it asked (eight Tough Wolf Meat), who gave it, who I returned to")
state.npc, state.objectives = "Balir Frosthammer", { [180] = { { text = "Rockjaw Trogg slain: 0/6", type = "monster", numRequired = 6 } } }
if FOREVER then fire("QUEST_ACCEPTED", 180) else fire("QUEST_ACCEPTED", 2, 180) end
fire("QUEST_COMPLETE")
fire("QUEST_TURNED_IN", 180, 80, 0)
state.npc = nil
local q2 = moments("quest")[2].objectives[1]
check(q2.type == "monster" and q2.name == "Rockjaw Trogg" and q2.n == 6, "… a kill quest read through the game's own format (\"%s slain\")")

-- A quest's work done in one place and turned in at another: the work is a
-- moment where it happened, the turn-in a return; a note in hand from the
-- start has nothing done before its delivery.
local function accept(id, title, giver, objective)
  state.npc, state.titles = giver, { [id] = title }
  state.objectives = { [id] = { objective } }
  if FOREVER then fire("QUEST_ACCEPTED", id) else fire("QUEST_ACCEPTED", 1, id) end
  fire("QUEST_LOG_UPDATE")
  state.npc = nil
end
local function turnIn(id, ender)
  state.npc = ender
  fire("QUEST_COMPLETE")
  fire("QUEST_TURNED_IN", id, 80, 0)
  state.npc = nil
end
accept(181, "The Troll Cave", "Grelin Whitebeard", { text = "Frostmane Troll Whelp slain: 0/14", type = "monster", numRequired = 14 })
state.sub = "Frostmane Hold"
state.objectives[181][1].finished = true
fire("QUEST_LOG_UPDATE")
fire("QUEST_LOG_UPDATE")
local done = moments("done")
check(#done == 1 and done[1].sub == "Frostmane Hold" and done[1].giver == "Grelin Whitebeard" and done[1].objectives[1].name == "Frostmane Troll Whelp",
  "a quest's work done: a moment where it happened, once")
state.sub = "Anvilmar"
turnIn(181, "Grelin Whitebeard")
check(moments("quest")[3].told and moments("quest")[3].sub == "Anvilmar", "… its turn-in, elsewhere, a return to who asked")
accept(182, "Coldridge Valley Mail Delivery", "Talin Keeneye",
  { text = "Grelin's Letter: 1/1", type = "item", numRequired = 1, finished = true })
fire("QUEST_LOG_UPDATE")
turnIn(182, "Grelin Whitebeard")
local mail = moments("quest")[4]
check(#moments("done") == 1 and not mail.told and mail.objectives[1].held,
  "a note in hand from the start: nothing done before its delivery")

-- Kills.
kill(1, 1); kill(1, 2); kill(2, 3)
local kills = moments("kill")
check(#kills == 2 and kills[1].name == "Ragged Young Wolf" and kills[1].kind == "Wolf" and kills[1].first and kills[2].first
  and ch().kills["Ragged Young Wolf"] == 2, "a moment for the chapter's first of each creature (the first of its kind marked), every kill counted")
if FOREVER then
  G.corpse(2, 99)
  check(ch().kills["Rockjaw Trogg"] == 1, "Forever: a corpse never fought doesn't count")
end

-- Learning, loot and money.
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:19740|h[Blessing of Might]|h|r.")
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:20271|h[Judgement]|h|r.")
local learned = moments("learned")
check(#learned == 1 and learned[1].spells[1] == "Blessing of Might" and learned[1].spells[2] == "Judgement", "a trainer's visit: one moment, its spells")
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:13819|h[Summon Warhorse]|h|r.")
local power = moments("power")[1]
check(power and power.spell == "Summon Warhorse" and power.kind == "steed" and #moments("learned") == 1,
  "a new power (a steed, a druid's form, a warlock's demon): a moment of its own, by its spell id")
fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Frostmane Leather Vest") .. ".")
check(#moments("loot") == 0, "green loot isn't told (it is, once worn)")
fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink("Pendant of Myzrael", 3) .. ".")
fire("CHAT_MSG_LOOT", "Brannor receives loot: " .. itemLink("Pendant of Myzrael", 3) .. ".")
check(#moments("loot") == 1 and moments("loot")[1].link:find("Pendant of Myzrael", 1, true), "a blue find is (mine only)")

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
check(#gear == 2 and gear[1].link:find("Frostmane Leather Vest", 1, true) and not gear[1].made and gear[2].made,
  "gear worn for the first time, once (put back on, no news); what I made, marked")

-- Professions: known ones noted quietly; a new one, a new rank, riding.
state.skills = { { "Professions", true }, { "Mining", false, 75 }, { "Secondary Skills", true }, { "Cooking", false, 75 } }
fire("SKILL_LINES_CHANGED")
check(#moments("prof") == 0 and J.profs.Mining == 75, "the trades known at first: noted, not told")
fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:2575|h[Mining]|h|r.")
state.skills[3] = { "Leatherworking", false, 75 }
table.insert(state.skills, 4, { "Secondary Skills", true })
state.skills[2][3] = 150
table.insert(state.skills, { "Apprentice Riding", false, 75 })
fire("SKILL_LINES_CHANGED")
local profs = {}
for _, m in ipairs(moments("prof")) do profs[m.name] = m end
check(profs.Leatherworking and profs.Leatherworking.learned and profs.Mining and profs.Mining.rank == "journeyman"
  and #moments("riding") == 1, "a trade taken up, a new rank, riding learned")
check(#moments("learned") == 1 and #moments("learned")[1].spells == 2, "a trade's own spell isn't a trainer's lesson")

-- The first ride.
state.mounted = true
fire("UNIT_AURA", "player")
fire("UNIT_AURA", "player")
state.mounted = false
check(#moments("mount") == 1, "the first ride: once")

-- A hunter's pet (the journal is a paladin's: a hunter for a moment).
J.class = "HUNTER"
state.pet = { name = "Grrr", family = "Bear" }
fire("UNIT_PET", "player")
check(J.pets and J.pets.Grrr and #moments("tame") == 0, "the pet at hand when the journal first looks: noted")
state.pet = { name = "Snapjaw", family = "Crocolisk" }
fire("UNIT_PET", "player")
state.pet.dead = true
fire("UNIT_HEALTH", "pet")
fire("UNIT_HEALTH", "pet")
state.pet.dead = false
fire("UNIT_HEALTH", "pet")
check(#moments("tame") == 1 and moments("tame")[1].family == "Crocolisk" and #moments("petdied") == 1 and moments("petdied")[1].name == "Snapjaw",
  "a pet tamed, and its death, once")
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
check(#close == 1 and close[1].hp == 7 and close[1].foe == "Frostmane Novice" and close[1].night,
  "a close call: under a tenth of my health, the foe, the hour; once a minute")

-- A level is a moment, not a chapter.
state.level = 2
local before = #printed
fire("PLAYER_LEVEL_UP", 2)
check(moments("level")[1] and moments("level")[1].level == 2 and #J.chapters == 1 and #printed == before, "a level up: a moment in the chapter, which goes on")

-- An inn, a flight, a profession, a rare, an elite.
state.bind = "Thunderbrew Distillery"
fire("HEARTHSTONE_BOUND")
TakeTaxiNode(2)
fire("CHAT_MSG_SKILL", "Your skill in Mining has increased to 50.")
fire("CHAT_MSG_SKILL", "Your skill in Mining has increased to 51.")
kill(3, 11)
check(moments("inn")[1].place == "Thunderbrew Distillery" and moments("flight")[1].from == "Ironforge, Dun Morogh" and moments("flight")[1].to == "Thelsamar, Loch Modan", "an inn and a flight")
check(#moments("skill") == 1 and moments("skill")[1].name == "Mining" and moments("skill")[1].rank == 50, "a profession, at its milestones only")
kill(5, 12)
check(moments("rare")[1] and moments("rare")[1].name == "Timber", "a rare slain")
check(moments("kill")[3] and moments("kill")[3].name == "Gibblewilt" and moments("kill")[3].elite, "an elite slain, marked")

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
check(#moments("group") == 1 and moments("group")[1].name == "Brannor" and #moments("dungeon") == 1 and moments("dungeon")[1].name == "The Deadmines"
  and #moments("boss") == 1 and moments("boss")[1].name == "Edwin VanCleef", "who joined me, the dungeon (once), the boss beaten")
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

-- The book of that chapter, written as it happens.
local book = ns.writeBook(J)
local one = book.chapters[1]
check(not book.prologue and one.number == 1 and one.open and one.from == 1 and one.to == 2 and one.close and one.rare
  and one.text:find("Tough Wolf Meat", 1, true) and one.text:find("Rockjaw Troggs", 1, true) and not one.text:find('"Dwarven Outfitters"', 1, true)
  and not one.text:find("{", 1, true), "chapter 1, still being written: its moments in order, the quests told by what was done")
do -- the Troll Cave: its work told in Frostmane Hold, then a return to Grelin in Anvilmar
  local work = one.text:find("Frostmane Troll Whelps", 1, true)
  local back = work and one.text:find("Anvilmar", work, true)
  local returned = back and one.text:find("Grelin Whitebeard", back, true)
  check(work and back and returned, "a quest's work told where it happened, the return where it was turned in")
end
check(not one.text:find("level two", 1, true), "a level reached isn't told (the chapter's levels say it)")
local textBefore = one.text
state.sub = "Kharanos"
fire("ZONE_CHANGED")
local grown = ns.writeBook(J).chapters[1].text
check(grown:sub(1, #textBefore - 1) == textBefore:sub(1, #textBefore - 1) and #grown > #textBefore, "a new moment adds to the chapter; what was written stays")
io.write("    " .. grown:gsub("\n\n", "\n    ") .. "\n")

-- The book, open.
SlashCmdList.HEARTHTALE("")
local B, page, rows = HearthtaleFrame, HearthtalePage, ns.bookRows
check(B:IsShown() and G.portrait() == "player" and B.who:GetText():find("Sealinedion, level 2", 1, true) and B.who:GetText():find("Hardcore", 1, true),
  "/ht opens the book: my portrait, who I am, Hardcore")
check(rows[1]:IsShown() and rows[1].title:GetText() == "Chapter 1" and rows[1].place:GetText() == "still being written"
  and page.title:GetText() == "Chapter 1" and page.sub:GetText():find("levels 1 to 2", 1, true) and page.sub:GetText():find("still being written", 1, true),
  "a row per chapter: Chapter 1, still being written, levels 1 to 2")
check(rows[1].marks[1]:IsShown() and rows[1].marks[2]:IsShown(), "marks: a skull for a close call, a star for a rare")
state.sub = "Brewnall Village"
fire("ZONE_CHANGED")
check(page.body:GetText():find("Brewnall Village", 1, true), "a new moment while the book is open: added at once")
SlashCmdList.HEARTHTALE("")
check(not B:IsShown(), "/ht again closes it")

-- A night in the wild: the chapter goes on; a /reload is no night.
G.played(1800)
local logBeforeNight = #ch().log
logout()
-- The book, written into the saved file at logout (for the site).
local B1 = J.book
check(B1 and B1.version == "0.2.0" and B1.client == (FOREVER and "forever" or "classic") and B1.level == 2 and #B1.chapters == 1
  and B1.chapters[1].open and B1.chapters[1].text and B1.chapters[1].began, "at logout, the book is written into the saved file")
check(J.realm == "Nightslayer" and J.region == 3, "… and where the character lives")
local view = ns.settledView(J)
check(#ch().log == logBeforeNight and view.chapters[1].log[#view.chapters[1].log].k == "night" and view ~= J,
  "a logout in the wild: the book tells the night outdoors (not the waking yet); the journal itself waits for the next login")
check(B1.chapters[1].text == ns.writeBook(view).chapters[1].text, "the saved text is the game's, word for word")
login()
check(#J.chapters == 1 and moments("night")[1] and moments("wake")[1] and moments("wake")[1].after == "night" and #printed == before,
  "a logout in the wild: a night outdoors, then the road again, the same chapter")
local nights = #moments("night")
reload()
check(#moments("night") == nights and #J.chapters == 1, "a /reload is no night")

-- A rest at an inn closes the chapter.
state.resting, state.sub = true, "Thunderbrew Distillery"
local printedBefore = #printed
logout()
local B2 = J.book.chapters[1]
check(not B2.open and B2.ended and B2.text:find("Thunderbrew Distillery", 1, true) and not ch(1).ended and #printed == printedBefore,
  "a logout at an inn: the saved book tells the chapter closed at once (the journal settles it at the next login, with its chat line)")
state.resting = false
login()
local first = ch(1)
check(#J.chapters == 2 and first.ended and first.ended.how == "rest" and first.ended.place == "Thunderbrew Distillery" and first.ended.level == 2
  and first.played >= 1800 and not ch(2).ended and ch(2).start.level == 2, "a logout at an inn closes the chapter; the next begins")
check(printed[#printed]:find("chapter 1 is written", 1, true) and printed[#printed]:find("|Hhearthtale:chapter:1|h", 1, true),
  "a line in chat, with a link to it")
local closed = ns.writeBook(J).chapters[1]
check(not closed.open and closed.place == "Thunderbrew Distillery" and closed.text:find("Thunderbrew Distillery", 1, true), "its last line: the rest, where")

-- Too little written: a rest doesn't close it.
state.resting = true
logout()
state.resting = false
login()
check(#J.chapters == 2 and moments("rested")[1] and moments("wake")[1].after == "rest", "a rest with almost nothing written: a line, and the chapter goes on")

-- A campfire closes one too, with a few moments written.
for i = 1, 3 do
  state.titles = { [200 + i] = "Errand " .. i }
  fire("QUEST_TURNED_IN", 200 + i, 80, 0)
end
state.auras[1229739] = true
logout()
state.auras[1229739] = nil
login()
check(#J.chapters == 3 and ch(2).ended.how == "campfire", "a logout by a campfire closes the chapter")

-- The cap: four hours in a chapter, and any logout closes it.
for i = 1, 3 do state.titles = { [300 + i] = "Chore " .. i }; fire("QUEST_TURNED_IN", 300 + i, 80, 0) end
G.played(4 * 3600 + 60)
logout()
login()
check(#J.chapters == 4 and ch(3).ended.how == "long" and moments("night", 3)[1].last, "past four hours, a night outdoors closes it")

linkHandlers.hearthtale("hearthtale:chapter:1")
check(B:IsShown() and page.title:GetText() == "Chapter 1", "the chapter's link opens the book at it")
check(rows[1].place:GetText() == "Thunderbrew Distillery, levels 1 to 2", "… listed with where it closed and its levels")
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
check(J.death and J.death.level == 2 and J.death.zone == "Dun Morogh" and J.death.cause == (FOREVER and "foe" or "fall") and ch().ended.how == "death",
  FOREVER and "a Hardcore death: where, at what level; it ends the chapter" or "a Hardcore death: where, at what level, how (a fall); it ends the chapter")
state.health = 100

-- A Hardcore death closes the book: nothing more is recorded; it joins the Hall
-- of the Fallen (a copy of its records), with a chat line and the game's toast.
local fallen = HearthtaleHall and HearthtaleHall.lives[state.guid]
check(J.closed and fallen and fallen.name == "Sealinedion" and fallen.raceName == "Dwarf" and fallen.realm == "Nightslayer"
  and #fallen.chapters == 4 and fallen ~= J, "a Hardcore death closes the book; a copy joins the Hall of the Fallen")
check(printed[#printed]:find("closed", 1, true) and printed[#printed]:find("|Hhearthtale:hall:" .. state.guid, 1, true),
  "a chat line says so, with a link to the Hall")
check(#toasted == 1 and toasted[1].Title:GetText() == "The book is closed" and toasted[1].Name:GetText() == "Sealinedion",
  "the game's toast: the book is closed")
local logBefore = #ch().log
state.sub = "Brewnall Village"
fire("ZONE_CHANGED")
login()
check(#ch().log == logBefore and #J.chapters == 4, "a closed book records nothing more, even at the next login")
logout()
local fallenLife = HearthtaleHall.lives[state.guid]
check(J.book and J.book.epitaph and #J.book.chapters == 4 and not J.book.chapters[4].open and fallenLife.book
  and fallenLife.book.epitaph == J.book.epitaph and fallenLife.book.level == 2, "a closed book is still written at logout, and its life in the Hall too")
local hallBook = fallenLife.book
logout()
check(fallenLife.book == hallBook, "… once per version of the addon")
login()
local closedBook = ns.writeBook(J)
check(closedBook.epitaph and closedBook.epitaph:find("Sealinedion", 1, true) and closedBook.epitaph:find("level two", 1, true)
  and not closedBook.epitaph:find("{", 1, true), "its epitaph: who, where, at what level")
io.write("    " .. closedBook.epitaph .. "\n")

-- The link opens the Hall at that life: its epitaph, then its chapters.
linkHandlers.hearthtale("hearthtale:hall:" .. state.guid)
check(B:IsShown() and B.selectedTab == 2 and rows[1].title:GetText() == "Sealinedion" and rows[2].title:GetText() == "Epitaph"
  and rows[3].title:GetText() == "Chapter 1" and page.title:GetText() == "Sealinedion" and page.body:GetText():find(closedBook.epitaph, 1, true)
  and page.sub:GetText():find("Level 2 Dwarf Paladin", 1, true), "the link opens the Hall: the life, its epitaph, its chapters")
rows[6].scripts.OnClick(rows[6])
check(page.title:GetText() == "Chapter 4" and page.sub:GetText():find("the end", 1, true) and page.body:GetText():find(closedBook.epitaph, 1, true),
  "its last chapter ends with the epitaph")
ns.showTab(1)
check(B.who:GetText():find("Fallen", 1, true) and page.title:GetText() == "Chapter 4" and page.body:GetText():find(closedBook.epitaph, 1, true),
  "the Journal tab: my own closed book, the same end")
SlashCmdList.HEARTHTALE("")

-- A character met mid-life: a prologue from what the game knows.
HearthtaleChar = nil
state.guid, state.level, state.questsDone, state.hardcore = "Player-6113-0FFFFFF0", 23, { [1] = true, [2] = true, [3] = true }, false
login()
local P = HearthtaleChar.prologue
fire("TIME_PLAYED_MSG", 86400, 3600)
fire("TIME_PLAYED_MSG", 90000, 7200)
check(P and P.level == 23 and P.quests == 3 and P.inn == "Thunderbrew Distillery" and P.played == 86400 and HearthtaleChar.chapters[1],
  "a character met mid-life gets a prologue: its level, quests done, inn, time played when first heard")
ns.writerUsed = {}
local later = ns.writeBook(HearthtaleChar)
local usedBeginning = false
for kind in pairs(ns.writerUsed) do
  if kind:find("^beginning#") or kind:find("/beginning#", 1, true) then usedBeginning = true end
end
check(later.prologue and later.prologue:find("^%u") and later.chapters[1].from == 23 and not usedBeginning,
  "its book opens with the prologue; its first chapter is no beginning")
io.write("    " .. later.prologue .. "\n")
SlashCmdList.HEARTHTALE("")
check(rows[1].title:GetText() == "Prologue" and rows[2].title:GetText() == "Chapter 1" and not (rows[3] and rows[3]:IsShown())
  and page.title:GetText() == "Chapter 1", "its book lists the prologue, then chapter 1")
rows[1].scripts.OnClick(rows[1])
check(page.title:GetText() == "Prologue" and page.sub:GetText():find("level 23", 1, true) and page.body:GetText() == later.prologue,
  "the prologue reads")
SlashCmdList.HEARTHTALE("")

-- A death on a normal realm: told in its chapter; the book goes on.
state.health, state.target = 0, nil
fire("PLAYER_DEAD")
state.health = 100
local K = HearthtaleChar
state.sub = "Gol'Bolar Quarry"
fire("ZONE_CHANGED")
ns.writerUsed = {}
ns.writeBook(K)
local told = false
for key in pairs(ns.writerUsed) do if key:find("died#", 1, true) then told = true end end -- the shared line or the race's own
ns.writerUsed = nil
local died, last = 0, K.chapters[#K.chapters].log
for _, m in ipairs(last) do if m.k == "died" then died = died + 1 end end
check(not K.closed and died == 1 and last[#last].sub == "Gol'Bolar Quarry" and told and not HearthtaleHall.lives[state.guid],
  "a death on a normal realm: told in its chapter, no Hall, the book goes on")

if FOREVER then
  for i, faction in ipairs({ "Horde", "Alliance" }) do
    HearthtaleChar = nil
    state.guid, state.level, state.race, state.faction = "Player-Skyborne-" .. i, 1, "Skyborne", faction
    login()
    check(HearthtaleChar.race == "Skyborne" and HearthtaleChar.faction == faction:lower(),
      "a Skyborne player's " .. faction .. " tradition follows the faction reported by the game")
    -- Existing saves acquire faction on their next login too.
    HearthtaleChar.faction = nil
    login()
    check(HearthtaleChar.faction == faction:lower(), "an older Skyborne journal acquires its faction at login")
  end
end

io.write(FOREVER and "all good (Forever)\n" or "all good\n")
