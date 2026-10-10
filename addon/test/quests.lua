-- The game's own quests the test lives play (lives.lua, sim.lua), by their
-- real ids, so that a quest's story (writing/why/) is its own in the game; a
-- quest made up for a test takes an id no quest has (`made()`, 9000000 on).
-- The playthrough checks each against the game's data (.cache/audit/game.lua).
--   local quests = dofile("addon/test/quests.lua")
--   quests.id("The Defias Brotherhood", "Gryan Stoutmantle", "Head of VanCleef")
local quests = {
  -- { id, title, giver = (when the title is several quests), item = (the same) }
  { 170, "A New Threat" },
  { 179, "Dwarven Outfitters" },
  { 182, "The Troll Cave" },
  { 233, "Coldridge Valley Mail Delivery", giver = "Sten Stoutarm" },
  { 234, "Coldridge Valley Mail Delivery", giver = "Talin Keeneye" },
  { 218, "The Stolen Journal" },
  { 384, "Beer Basted Boar Ribs" },
  { 412, "Operation Recombobulation" },
  { 5541, "Ammo for Rumbleshot" },
  { 287, "Frostmane Hold" },
  { 314, "Protecting the Herd" },
  { 313, "The Grizzled Den" },
  { 6064, "Taming the Beast", giver = "Grif Wildheart" },
  { 400, "Tools for Steelgrill" },
  { 57, "The Night Watch", item = "Skeletal Fiend" },
  { 173, "Worgen in the Woods", item = "Nightbane Shadow Weaver" },
  { 165, "The Hermit" },
  { 133, "Ghoulish Effigy" },
  { 788, "Cutting Teeth" },
  { 790, "Sarkoth" },
  { 792, "Vile Familiars", giver = "Zureetha Fargaze" },
  { 5441, "Lazy Peons" },
  { 789, "Sting of the Scorpid" },
  { 4402, "Galgar's Cactus Apple Surprise" },
  { 805, "Report to Sen'jin Village" },
  { 784, "Vanquish the Betrayers" },
  { 5726, "Hidden Enemies" },
  { 456, "The Balance of Nature", item = "Young Nightsaber" },
  { 3120, "Verdant Sigil" },
  { 459, "The Woodland Protector" },
  { 4495, "A Good Friend" },
  { 916, "Webwood Venom" },
  { 488, "Zenn's Bidding" },
  { 2438, "The Emerald Dreamcatcher" },
  { 6001, "Body and Heart", giver = "Mathrengyl Bearwalker" },
  { 363, "Rude Awakening" },
  { 364, "The Mindless Ones" },
  { 380, "Night Web's Hollow" },
  { 3902, "Scavenging Deathknell" },
  { 381, "The Scarlet Crusade" },
  { 365, "Fields of Grief", item = "Tirisfal Pumpkin" },
  { 368, "A New Plague" },
  { 398, "Wanted: Maggot Eye" },
  { 168, "Collecting Memories" },
  { 167, "Oh Brother. . ." },
  { 2040, "Underground Assault" },
  { 142, "The Defias Brotherhood", item = "A Mysterious Message" },
  { 155, "The Defias Brotherhood", giver = "The Defias Traitor" },
  { 166, "The Defias Brotherhood", item = "Head of VanCleef" },
  { 214, "Red Silk Bandanas" },
  { 373, "The Unsent Letter" },
}

local M = { list = quests, titles = {} }
for _, q in ipairs(quests) do
  M.titles[q[1]] = q[2]
end

-- The id of the game's quest of that title (given by, asking for), else nil.
function M.id(title, giver, objective)
  local name = objective and objective.text and (objective.text:match("^(.-) slain:") or objective.text:match("^(.-):"))
  for _, q in ipairs(quests) do
    if q[2] == title and (not q.giver or q.giver == giver) and (not q.item or q.item == name) then return q[1] end
  end
end

-- An id for a quest the game hasn't: out of reach of every real one.
local made = 9000000
function M.made()
  made = made + 1
  return made
end

return M
