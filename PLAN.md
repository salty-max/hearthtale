# Hearthtale

A World of Warcraft addon: the character's own journal, written as it plays,
in the first person, one chapter per level. On Hardcore, a death closes the
book with an epitaph, and the life joins the Hall of the Fallen.

Games: Classic Era (Hardcore, Season of Discovery), TBC Anniversary, World of
Warcraft: Forever. One source, one package per game, as Lorekeeper's Codex and
Explorer's Field Journal (same release, CI and CurseForge tooling).

## The name (6 October 2026)

Wayfarer's Journal becomes **Hearthtale**: the hearth (the inn, the hearthstone,
where its chapters close) and the tale. Short enough for the site's domain
(hearthtale.gg was free) and not taken on CurseForge. Renamed everywhere before
anyone but the author had installed it: the folder, the saved variables (a
journal of the old name starts over), the GitHub repo; `/hearthtale` and `/ht`.

## A web reader (6 October 2026, planned after the CurseForge launch)

The journal readable outside the game too, as Talekeeper does on Forever (whose
book is written by its site, needs an account and a Windows tray app, Forever
only). The in-game book stays complete and needs nothing.

| Question | Decision |
|---|---|
| Home | A site of its own (not inside WoWLocker): its own domain, sign-in, companion and hosting. WoWLocker's code (monorepo, companion, pairing) is the model to copy from. |
| Ownership | Not through the Battle.net API (no Forever namespace): a code typed in the game links a character to the account, as Talekeeper does. |
| Prose | The site runs the addon's own Writer.lua and writing data on the uploaded records: the web and the game read the same, and better writing reaches old chapters on both. |
| Sharing | Private by default; a share link per book or per epitaph, with a preview card for Discord and Reddit. Fallen Hardcore books may be offered to a public Hall. |
| Timing | After the CurseForge launch: first CurseForge and Wago, a share-as-text button in game, a project page that shows the prose. |

## Chapters from rest to rest (6 October 2026, after testing 0.1.0)

These replace the chapter per level below.

| Question | Decision |
|---|---|
| A chapter | From rest to rest: it closes when the character logs out resting, at an inn, in a city (the game's resting state) or by a campfire (its warmth on you: Cozy Fire on both games, Forever's camps), once it holds a few moments (3). Titled "Chapter N", with where it closed and the levels it covers. |
| In the wild | A logout elsewhere is a night outdoors: a line, and the chapter goes on (the next session wakes in it). A /reload is no night (the logout is settled at the next login, which says whether it was one). |
| The cap | After four hours of play in one chapter, any logout closes it (a night outdoors that ends it). |
| Writing | In scenes: the moments in one place make one or two sentences of clauses ("I reached Kharanos, took a room at Thunderbrew Distillery and found the Crag Boar Ribs Ragnar Thunderbrew wanted, six in all."), the journey or the time between scenes as their link ("I went back to Anvilmar", "Later that day,"); a sentence of its own for what matters more (a close call, a rare, a new zone, a night, a death, a new power, a pet fallen). Only the scene being played grows; what is before it never changes. A new paragraph at a new zone or a morning; once closed, a recap (the quests, the most fought), the time and gold, and the rest that closed it. |
| Numbering | Chapters count from 1; a character met mid-life has its prologue first. |
| Old data | The 0.1.0 test build's journals (chapters per level) start over. |
| Quests | Told by what was done, from the objectives the quest log gives at acceptance (kill so many, bring so many, a task) and who it was returned to (a message carried); the title only when there is nothing else to tell. |
| Levels | Recorded (a chapter's levels), not told; the trainer's new spells are. |
| Captured | Also (after testing): gear worn for the first time (green and better; an item put back on is no news), said to be my own work when crafted; professions taken up and their ranks, riding, the first ride; a druid's forms, a warlock's demons, a class steed (by spell id); a hunter's new pets and their deaths; blue finds only. Talents are not told. |
| Sample | docs/sample.md is a life played through the addon in the test's fake game (addon/test/sample.lua), not written by hand. |
| Prose | Linking words between scenes by what happened in between (later that day, that night, at first light), "then" within a scene; a quip (an [aside] in writing/) at most once a paragraph, but for the moments that matter; race and class lines in about one chapter in three, twice at most (a first, once in a life, always may). |

## Decisions (5 October 2026)

| Question | Decision |
|---|---|
| Shape | A new addon, standalone: it reads none of the Codex's or the Field Journal's records. |
| Who | Every character; the tone grows graver on Hardcore, with the level. |
| Voice | First person, the character's own; words and turns of phrase by race and class (a dwarf paladin's hammer and Light, a Forsaken mage's cold and arcane). |
| Chapters | One per level, titled by the level; the level is not repeated in the text. |
| Detail | Each chapter gathers what the level held (below), as linked prose, not a log. |
| Mid-life | A character met halfway: a prologue from what the game knows, then a chapter per level from there. |
| Death (Hardcore) | The last chapter ends with an epitaph; a chat line and the game's toast say the book is closed; the life joins the Hall of the Fallen (account-wide), to reread. |
| Sample | Approved: first person, a chapter per level, this much detail (scratchpad sample2). |

## What a level records (SavedVariablesPerCharacter)

Per level, as it happens:

- **Where**: the hour and place the level began; places discovered, towns
  reached (zone and subzone changes); the inn bound; flights (taxi), boats.
- **Quests**: turned in, by title, and who gave them (`QUEST_TURNED_IN`, the
  quest giver targeted at acceptance); the notable ones (elite, dungeon, chain
  ends, class quests).
- **Fights**: kills by kind (creature type and family, from the unit when met;
  Classic: the combat log's kills; Forever: corpses targeted dead
  after a fight, as the Field Journal), the first of each kind, rares and
  elites, bosses; close calls (under a tenth of health, alive five seconds
  later), with the foe and the place.
- **Company**: groups (members' names, classes), dungeons entered and their
  last boss, a party member's death.
- **Learning**: spells learned at a trainer, professions and their milestones
  (skill 50, 75, 150...), riding.
- **Spoils**: the best item of the level (green and above, by quality and
  level), gold earned.
- **Time**: time played at the level (`TIME_PLAYED_MSG`), real days it took.
- **Death**: where, how (the last damage taken; falling, drowning), against
  what, at what level.

The prologue, for a character met mid-life: level, time played, the zones it
has explored (the map's fog), quests done (`GetQuestsCompleted`), its inn, its
professions, written as a summing up ("I have been on the road for eleven days
of my life...").

## The writing

The heart of the addon, and most of the work.

- **Templates per kind of moment** (about 20 kinds: opening, place, town, inn,
  quests few/many/notable, kills one/two/many, first of a kind, rare, elite,
  boss, close call light/deep, group, dungeon, trainer, profession, loot,
  flight, death of a companion, closing), 15 to 20 sentences each: 300 to 400
  sentences, plus linking words and epitaphs.
- **Chosen by context, not at random**: the hour, the weather, the first time
  or the tenth, how close the call, the foe's level against ours, alone or in a
  group, Hardcore and the level (graver as it climbs).
- **Filled from the events**: place, foe, quest titles, givers, companions,
  counts (in words), the item, the time.
- **Voice tokens by race and class**: {weapon} (hammer, axe, staff...), {faith}
  (the Light, the Earth Mother, the spirits, nothing), {home} (Ironforge,
  Orgrimmar...), {kin}; some sentences only for some races or classes.
- **Prose, not a log**: moments ordered by when they happened, joined by
  linking words (then, later, by evening, and when); related moments merged
  into one sentence (a quest and the kills it needed); a place just named
  becomes "there"; a sentence never used twice in a book; counts in words;
  every sentence capitalised.
- **Stable**: each choice seeded by the event, so the book reads the same each
  time it is opened; the text is written from the records when read, never
  stored (smaller saved data, and better sentences in later versions reach old
  books too).
- **Epitaphs**: 30 to 40, by cause (beast, people, fall, drowning, an elite, a
  boss, a player), level and place, quoting the life's best moments.
- **Content in Markdown**, built to Lua (as the Codex): `writing/<kind>.md`,
  one sentence per line with its conditions; checked for slots and ASCII.

## The book

Same look as its siblings (standard game window; dark panels, gold titles;
Forever's Professions cards). Two tabs:

- **Journal**: chapters on the left (level, the main place, a mark for a
  chapter with a close call or a rare), the chapter's text on the right; the
  prologue first.
- **Hall of the Fallen**: the account's closed books (name, race, class, level,
  where and how they fell, the date), each with its epitaph and the whole
  journal to reread.

## Engineering

- Hardcore from the game (`C_GameRules`, where the client has it), else a
  setting.
- The simulation (`luajit addon/test/sim.lua`, both games) replays whole
  lives, and a writer test generates hundreds of chapters to catch repeated
  sentences, broken slots and bad grammar.
- Forever: no combat log (kills from loot and dead targets), secret values
  checked.

## Steps

Status (6 October 2026): 1 to 6 done; 7 reviewed (516 sentences read, fixes
in), release 0.1.0 next.

1. The repository, from the Field Journal's skeleton.
2. The recording, with the simulation.
3. The writer: the engine, then the sentences, kind by kind, with the writer
   test.
4. The book (Journal tab).
5. Death, epitaphs and the Hall of the Fallen.
6. Settings, minimap button, CurseForge page and logo.
7. Review of the sentences; release 0.1.0.
