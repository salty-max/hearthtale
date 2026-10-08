-- The quests: who asked, what they asked (read from the quest log in the
-- game's own words), the work done where it happened, the turn-in to whom.
-- (Record.lua keeps the chapters; this file adds their quest moments.)
local _, ns = ...
local R, secret = ns.record, ns.secret
local char, moment, chapter, changed, match = R.char, R.moment, R.chapter, R.changed, R.match
-- Who gave a quest (the one I was talking to when I accepted it) and its
-- title, kept until it is turned in (the title may be out of the game's cache
-- by then). Classic passes (index, id), Forever (id).
local function titleOf(id)
  return (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id))
    or (GetTitleForQuestID and GetTitleForQuestID(id))
    or nil
end

-- What a quest asks, from the quest log: its objectives' lines ("Kobold
-- Vermin slain: 0/10", "Tough Wolf Meat: 0/8"), read through the game's own
-- formats; the rest ("Find the missing diplomat") kept as it is.
local function rawObjectives(id)
  local raw = {}
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
    for _, o in ipairs(ok and list or {}) do
      table.insert(raw, { text = o.text, type = o.type, n = o.numRequired, finished = o.finished })
    end
  elseif GetQuestLogIndexByID and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    local index = GetQuestLogIndexByID(id)
    if index and index > 0 then
      for i = 1, GetNumQuestLeaderBoards(index) or 0 do
        local text, type, finished = GetQuestLogLeaderBoard(i, index)
        table.insert(raw, { text = text, type = type, finished = finished })
      end
    end
  end
  return raw
end
-- Every objective met. A quest with none (an escort, a word to carry) is
-- done when the game says so: complete from the start, it was only to carry.
local function finishedAll(id)
  local raw = rawObjectives(id)
  if #raw == 0 then
    local api = (C_QuestLog and C_QuestLog.IsComplete) or IsQuestComplete
    if not api then return false end
    local ok, done = pcall(api, id)
    return ok and not secret(done) and (done == true or done == 1)
  end
  for _, o in ipairs(raw) do
    if not o.finished then return false end
  end
  return true
end
local function objectivesOf(id)
  local raw = rawObjectives(id)
  local out = {}
  for _, o in ipairs(raw) do
    if o.text and not secret(o.text) then
      local name, n, have, own
      for _, g in ipairs({ "QUEST_MONSTERS_KILLED", "QUEST_OBJECTS_FOUND" }) do
        local a, b, c = match(g, o.text)
        if a then
          name, have, n = a, tonumber(b), tonumber(c)
          own = g ~= "QUEST_MONSTERS_KILLED"
          break
        end
      end
      -- a name the game hasn't filled in yet (an item not loaded: "0/8 "): the
      -- objectives aren't known yet, and are read again at the next update
      if name then
        name = name:match("^%s*(.-)%s*$")
        if name == "" or name:match("^%d+$") then return nil end
      end
      -- a kill told in the quest's own words ("Peons Awoken: 0/5"): its text,
      -- not a creature's name
      if o.type == "monster" and own then
        o.text, name = name, nil
      end
      -- an item already in hand when the quest is taken: a thing to deliver
      local held = o.type == "item" and (o.finished or (have and n and have >= n)) or nil
      -- (an event's count, before or after it: "0/1 Find the camp", "Find the camp: 0/1")
      local event = not name and (o.text:gsub(":%s*%d+/%d+$", ""):gsub("^%d+/%d+%s*", "")) or nil
      if event and not event:find("%S") then return nil end -- nothing but a count yet
      table.insert(out, { type = o.type, name = name, n = n or o.n, text = event, held = held })
    end
  end
  return #out > 0 and out or nil
end

-- How many of each creature a quest has counted so far ("Rockjaw Trogg
-- slain: 3/6"): name = count.
local function killCounts(id)
  local counts = {}
  for _, o in ipairs(rawObjectives(id)) do
    if o.type == "monster" and o.text and not secret(o.text) then
      local name, have = match("QUEST_MONSTERS_KILLED", o.text)
      name = name and name:match("^%s*(.-)%s*$")
      if name and name ~= "" and tonumber(have) then counts[name] = tonumber(have) end
    end
  end
  return counts
end

-- The pet at my side, if one is out: its name and family ("Zigfik", "Imp"),
-- for the work done with it.
local function companion()
  if not UnitExists("pet") then return nil end
  local name, family = UnitName("pet"), UnitCreatureFamily("pet")
  if not name or secret(name) then return nil end
  return name, (family and not secret(family)) and family or nil
end

-- A quest's count gone up: those kills credited to me (Combat.lua tells the
-- ones it hasn't heard of: another's killing blow on a creature I fought,
-- which the game credits me with).
local function creditKills(id, p)
  local counts = killCounts(id)
  for name, have in pairs(counts) do
    local before = (p.counted or {})[name]
    if before and have > before then R.credited(name, have - before) end
  end
  p.counted = counts
end

ns.on("QUEST_ACCEPTED", function(a, b)
  local id, c = b or a, char()
  if not id then return end
  c.pending = c.pending or {}
  -- (a quest from an item: no npc; the target then only if a living friend,
  -- not the corpse the item came from)
  -- (nor a player: a quest shared by a companion is mine, its giver unknown)
  local friendly = UnitExists
    and UnitExists("target")
    and not (UnitIsDead and UnitIsDead("target"))
    and not (UnitCanAttack and UnitCanAttack("player", "target"))
    and not (UnitIsPlayer and UnitIsPlayer("target"))
  local giver = UnitName("npc") or (friendly and UnitName("target")) or nil
  local objectives = objectivesOf(id)
  c.pending[id] = {
    giver = (giver and not secret(giver)) and giver or nil,
    title = titleOf(id),
    objectives = objectives,
    held = finishedAll(id) or nil,
    counted = killCounts(id),
  } -- done from the start: nothing to tell before the turn-in
end)
-- The quest log fills in after the acceptance (the objectives, once known),
-- and tells when a quest's work is done: told then and there, where it
-- happened; the turn-in, later, is the return to who asked.
-- (a name kept before the game had filled it in: "0" by 0.5.0, " " by 0.5.1;
-- read again while the quest is still in the log)
local function misread(objectives)
  for _, o in ipairs(objectives or {}) do
    if o.name and (o.name:match("^%d+$") or not o.name:find("%S")) then return true end
  end
  return false
end
ns.on("QUEST_LOG_UPDATE", function()
  for id, p in pairs(char().pending or {}) do
    if not p.objectives then
      p.objectives = objectivesOf(id)
      if p.objectives and finishedAll(id) then p.held = true end
    elseif misread(p.objectives) then
      p.objectives = objectivesOf(id) or p.objectives -- (its work, if done, still told below)
    end
    creditKills(id, p)
    if not p.done and not p.held and finishedAll(id) then
      p.done = true
      local pet, family = companion()
      moment(
        "done",
        { id = id, title = p.title, giver = p.giver, objectives = p.objectives, pet = pet, petFamily = family }
      )
    end
  end
end)
-- Who I returned to: the one I talk to when the quest is completed.
local ender
-- Objectives still without their names (the item not loaded yet): read
-- again, while the quest is still in the log (the turn-in window too).
local function named(id, p)
  if p and (not p.objectives or misread(p.objectives)) then p.objectives = objectivesOf(id) or p.objectives end
end
ns.on("QUEST_COMPLETE", function()
  local name = UnitName("npc")
  ender = (name and not secret(name)) and name or nil
  local id = GetQuestID()
  if id and id ~= 0 then named(id, (char().pending or {})[id]) end
end)
ns.on("QUEST_TURNED_IN", function(id)
  local c = char()
  local p = c.pending and c.pending[id] or {}
  named(id, c.pending and c.pending[id])
  local ch = chapter()
  ch.quests = ch.quests + 1
  moment("quest", {
    id = id,
    title = titleOf(id) or p.title,
    giver = p.giver,
    ender = ender,
    objectives = p.objectives,
    told = p.done or nil,
  }) -- told: its work was told when done
  ender = nil
  if c.pending then c.pending[id] = nil end
end)

-- A quest gone from the log without a turn-in (abandoned, failed): its work,
-- if it was told in the chapter still being written, is taken back. (A closed
-- chapter never changes.) A moment later: a turn-in may be on its way.
ns.on("QUEST_REMOVED", function(id)
  local function check()
    local c = char()
    if not (c.pending and c.pending[id]) then return end
    c.pending[id] = nil
    local ch = c.chapters and c.chapters[#c.chapters]
    if not ch or ch.ended then return end
    for _, m in ipairs(ch.log) do
      if m.k == "done" and m.id == id then m.abandoned = true end
    end
    changed()
  end
  C_Timer.After(1, check)
end)
