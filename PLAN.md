# Hearthtale

A World of Warcraft addon: the character's own journal, written as it plays,
in the first person, one chapter from rest to rest. On Hardcore, a death closes the
book with an epitaph, and the life joins the Hall of the Fallen.

Games: Classic Era (Hardcore, Season of Discovery), World of
Warcraft: Forever. One source, one package for every game (a TOC per game, since
10 October 2026), as Lorekeeper's Codex and Explorer's Field Journal (same
release tooling: the BigWigs packager, GitHub, CurseForge and Wago).

## Postcards (proposed 10 October 2026)

A picture of the world at the moments that matter, without the interface,
kept with its entry and shown with it on hearthtale.app. The idea is the
user's; the research below is from Blizzard's own code for Classic Era 1.15.9
and Forever 1.60.1 (Gethe/wow-ui-source), the clients' function lists
(Ketho/BlizzardInterfaceResources), warcraft.wiki.gg, Multishot (the long-lived
auto-screenshot addon, updated April 2026) and Musician (which drives the
in-world layer).

### What the game allows

- `Screenshot()` exists in Classic Era, Forever and TBC Anniversary; neither
  the wiki nor Blizzard's documentation marks it protected. It fires
  `SCREENSHOT_STARTED`, then `SCREENSHOT_SUCCEEDED` or `SCREENSHOT_FAILED`. The
  file is `Screenshots/WoWScrnShot_MMDDYY_HHMMSS.jpg` in the client's folder
  (local time; `screenshotFormat`: jpeg by default, png or tga).
- Hiding the interface is not an option. Alt+Z (TOGGLEUI) runs `CloseMenus`,
  `CloseAllWindows`, then `SetUIVisibility(false)`, which hides `UIParent`: a
  hidden window runs its OnHide, and the vendor's ends the trade
  (`MerchantFrame_OnHide`: `CloseMerchant`, `CloseAllBags`). The bank, mail
  and trade windows close the same way. pfUI (built for the 2006 client) hides
  `UIParent`; Multishot does not.
- Making it invisible is: `UIParent:SetAlpha(0)`, the shot, the opacity put
  back at `SCREENSHOT_SUCCEEDED`/`FAILED` (Multishot's way). Nothing closes or
  moves, opacity is no restricted action on a protected frame, and Multishot
  avoids `Minimap:Hide()` because it taints in combat.
- What `UIParent` doesn't hold stays in the picture: the in-world layer
  (nameplates, raid target icons; names above heads and chat bubbles to
  confirm) and the 3D marks (the selection circle). `SetInWorldUIVisibility`
  switches that layer: Blizzard's commentator mode uses it to keep nameplates
  while the interface is hidden, and Musician calls it after Alt+Z for the
  same reason. Nobody calls it with `false` while the interface is shown:
  whether that hides the layer, and whether nameplate addons (Plater, Kui)
  rebuild their plates when it does, only the game can say (the test below).
  Touching nameplates one by one is out: Musician gives up on Plater for it.

### The test (the user, in game)

Typed in chat, out of combat; each puts everything back after 3 seconds.

1. `/run UIParent:SetAlpha(0) C_Timer.After(3,function() UIParent:SetAlpha(1) end)`:
   what stays visible (nameplates, names above heads, chat bubbles, damage
   numbers); at a vendor, the window must still be open after.
2. `/run local f,n=CreateFrame("Frame"),0 f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")f:SetScript("OnEvent",function()n=n+1 end)SetInWorldUIVisibility(false)C_Timer.After(3,function()SetInWorldUIVisibility(true)f:UnregisterAllEvents()print("removed",n)end)`:
   whether nameplates and names vanish while the interface stays, any
   flicker, and the count printed (0: the plates were only hidden; more: torn
   down and rebuilt, heavier with a nameplate addon).
3. `/run local a=UIParent:GetAlpha() UIParent:SetAlpha(0) SetInWorldUIVisibility(false) C_Timer.After(0.1,function() Screenshot() C_Timer.After(1,function() UIParent:SetAlpha(a) SetInWorldUIVisibility(true) end) end)`:
   a whole postcard; the file in Screenshots/ shows what a postcard looks like.
4. Commands 1 and 2 once in a fight: a red "Interface action failed because
   of an AddOn" means blocked in combat (the plan never shoots in combat
   anyway; it tells how careful the restore must be).

### Proposal

| Question | Proposal |
|---|---|
| Moments | Few, by weight: a capital first seen, a dungeon's last boss, the first ride, the highest level, a Hardcore death; at most two automatic postcards an entry. Plus the player's own: a key binding ("Take a postcard") and `/ht postcard`, the way to frame one's own, kept with the entry being written. |
| The shot | Never in combat: a moment from a fight waits for `PLAYER_REGEN_ENABLED` plus a second, and is dropped after 20 seconds or a change of zone. Never over a loading screen, a cinematic or a movie; when the interface is already hidden (Alt+Z), the shot alone. The in-world layer off for it only if the test shows it clean. |
| Restore | The opacity as it was (another addon may have faded it), never forced to 1 (Multishot's bug); a 2-second timer puts it back if the game never answers. |
| Quiet | The centre "Screen captured" silenced for our shots (ActionStatus's three events off around it, then back); a short chat line instead, as an option. Hearthtale adds no sound and no window of its own. |
| Settings | Postcards: automatic and mine / mine only / off, on the welcome page and the Options page, per character like the others. Nothing of the game's settings touched (screenshot format, names above heads): a crash mid-shot would leave them changed in Config.wtf. |
| Record | Each postcard in its chapter: `postcards = { { at, stamp, k } }` (`at` the time, `stamp` the file's `MMDDYY_HHMMSS` at `SCREENSHOT_SUCCEEDED`, `k` the moment or `mine`); Save.lua writes them into the saved book. The in-game book can't show them (an addon can't read the Screenshots folder): a small mark beside the entry says it has pictures. |
| Ravenpost | For a linked character, finds each postcard's file in `<client>/Screenshots/` by its stamp (a second either side, as Multishot does), jpeg or png (tga skipped); never moves or deletes the player's screenshots. Resizes to 1600 px wide JPEG (under Vercel's 4.5 MB) and uploads one a request (`POST /api/companion/postcard`: the character, the chapter, the stamp, the image), remembering what it sent. A "Send postcards" switch in its settings. |
| Site | The images in Vercel Blob (the team is on Pro; its included storage to check) under unguessable names, served only through the API to whoever may read that entry (its owner, a share link covering it, the Hall for a fallen book). A `postcards` table (character, chapter, stamp, moment, blob key, size). The reader shows an entry's postcards under its title, larger on a click; the owner can delete one; removing a book removes its postcards. A share card may use the entry's postcard. |
| Privacy | With the interface invisible, chat, whispers and names in windows can't reach a picture. Names above other players' heads may (the test tells): the in-world layer off, if clean, takes them out too. Postcards are as private as the book. |

### Steps

1. The test above (the user); its answers settle the in-world layer.
2. The addon: Postcards.lua (the queue, the rules, the shot, the stamp), the
   moments that call for one, the record and Save.lua, the settings and the
   welcome page's choice, the key binding and `/ht postcard`; the test game
   learns `Screenshot`, `SetInWorldUIVisibility` and the screenshot events.
3. The site: the shared type (`BookChapter.postcards`), the table and its
   migration, Blob storage, the upload endpoint, the reader, sharing and the
   Hall, deletion.
4. Ravenpost: the Screenshots folder of each client, matching, resizing,
   uploading, the switch, its tests.
5. Release order: the site, then Ravenpost, then the addon (which records
   postcards on its own until they can travel).

## The journal is the diary (10 October 2026)

| Question | Decision |
|---|---|
| Reading | Each chapter reads as its diary entry, in the game and on the site (diary first on 9 October, diary only on 10 October). The full chapter prose is no longer written. |
| Code | The chapter writer (Scene.lua, Writer.lua's tellings, the clause and remark pools, their tests) is removed; the last of it is on the branch `chapters-archive` (tag `chapters-last`, 8877939). The book is Diary.lua's: the prologue, the entries, the epitaph. |
| Saved book | Each chapter's entry in `diary`; `text` is no longer written (a book saved before keeps its prose there, and the site reads it in its place). |
| Data | Knowledge.lua keeps the class quests and the chains; the drops of quest items went with the hunts that told them; the quest givers' people and callings serve the playthrough only (`.cache/audit/npcs.lua`). |
| Scenery | A place is described the first time a life meets it: a new land, a capital or a dungeon an entry tells, right after it is told, and the town an entry ends in, before its rest (decided 10 October 2026). |
| Moments | Told again (10 October 2026): gear first worn below level 30, blue or made by me (an epic piece at any level); a class's defining spells for every class (a warrior's stances, a paladin's Redemption, a rogue's poisons, a priest's own people's prayers, a mage's first way home, a druid's way to Moonglade), beside the demons, companions, forms and totems; the fires: the life's first, one shared (the recorder notes the party at it), one of Forever's camps, the one an entry ends at. |
| Titles | Each entry is titled by its weightiest moment in the game's own words (a quest's title, a name, a place), never made-up prose, and never one an earlier entry has (10 October 2026). Shown in the window, the saved book, the site and share cards. |
| Naming | A reader sees entries: "Entry 3" in the window, the chat line, the settings and on the site. The data keeps its chapters (the saved file, the stored books, the site's routes): no migration for a word. |

## Voices and scenery (6 October 2026)

| Question | Decision |
|---|---|
| Voice | Each race writes a fluent first-person recollection, with its own outlook, phrasing, and way of opening and closing a day. Connected thoughts and concrete observations carry the character; broken sentences and racial caricatures do not. Shared writing remains the fallback. |
| Dialect | Flavour, no caricature: turns of phrase and outlook, a few words of their own used sparingly; no phonetic accents. |
| Scenery | The first time in a life that the character enters a zone, a town or a dungeon: 2-3 hand-written sentences experienced through the narrator: what I notice and how it meets me, with landmarks true to the original game. |
| Viewpoint | Each place reads differently for who arrives: home (a dwarf in Dun Morogh), an ally's land, enemy ground (an orc in Elwynn), neutral; by night or day. |
| Order | The first scenery pass covers starting lands, capitals, first towns and nearby dungeons. Core racial voices now cover all ten familiar races and Forever's Skyborne; extend scenery across the rest of the world next. |

## The name (6 October 2026)

Wayfarer's Journal becomes **Hearthtale**: the hearth (the inn, the hearthstone,
where its chapters close) and the tale. Short enough for the site's domain
(hearthtale.app registered by the user on 6 October 2026: hearthtale.app cost
$130 a year) and not taken on CurseForge. Renamed everywhere before
anyone but the author had installed it: the folder, the saved variables (a
journal of the old name starts over), the GitHub repo; `/hearthtale` and `/ht`.

## The site (6 October 2026)

The journal readable outside the game too, as Talekeeper does on Forever (whose
book is written by its site, needs an account and a Windows tray app, Forever
only). The in-game book stays complete and needs nothing. Built before the
CurseForge launch (the user tests the addon meanwhile; the launch comes with the
site).

| Question | Decision |
|---|---|
| Home | A site of its own at hearthtale.app, in this repo (a monorepo, as WoWLocker: addon/, apps/api, apps/web, packages/shared). Vercel Pro (team jellycat, project hearthtale, functions in fra1) + **Neon** through the Vercel integration (free plan, Frankfurt; chosen over Supabase by the user: with no poller, its scale-to-zero suits a site that only wakes for uploads and readers). |
| Accounts | Battle.net sign-in: the characters the Battle.net API knows (Classic Era, Hardcore, SoD) are found and attached on their own. A code typed in the game (`/ht link CODE`) attaches any other (Forever has no Battle.net namespace). |
| Upload | **Ravenpost**, one companion for WoWLocker and Hearthtale: its own repo (salty-max/ravenpost), moved out of wow-locker and renamed; each site linked separately from its settings page (its own sign-in, its own upload key). |
| Prose | Links follow recorded changes: arrival, time passing, nightfall, the aftermath of a close call. No arbitrary "then" between errands, no "Place: text" headings, and no health percentages in the narrative. Emotion and interpretation belong to the protagonist; specific actions and outcomes come from the record. A quip (an [aside]) is at most once a paragraph, except for moments that matter. |
| Sharing | Private by default; a share link per book, chapter or epitaph, with a preview card for Discord and Reddit. Fallen Hardcore books may be offered to a public Hall. |

### Steps

1. **Scaffold** (done, 6 October 2026): the monorepo around the addon
   (Turborepo + Bun, from WoWLocker: lint, typecheck, commitlint, CI), the
   addon's checks kept as they are; a first page in English and French.
2. **The book in the saved file** (done, 6 October 2026): HearthtaleChar.book
   and each fallen life's book in the Hall, written at logout.
3. **Records in** (done, 6 October 2026): pairing a companion with an
   account, and the upload of each character's saved record (its book as
   written at logout), kept only for a proven owner; link codes claimed there.
   The Hall's copies (HearthtaleHall) aren't uploaded: each fallen character's
   own file carries its closed book.
4. **Accounts** (done, 6 October 2026): Battle.net sign-in (WoWLocker's code),
   the characters found through the API; link codes for the rest (the addon
   keeps the code in its saved file until it is uploaded); books private to
   their owner. The code is claimed by the upload (step 3/6).
5. **The reader**: your characters, each book (prologue, chapters, the Hall),
   the page in the in-game book's look; phone first. Started 6 October 2026:
   the library, a book's contents, its chapters and epitaph, on test characters
   played through the addon (addon/test/seed.lua).
6. **Ravenpost** (done, 6 October 2026; released, 0.2.3 on 7 October): the companion moved
   to its own repo (salty-max/ravenpost, history kept) and renamed; it uploads
   each addon's file to its site (WowLocker.lua to WoWLocker, Hearthtale.lua to
   Hearthtale, one character per request, only the fields the site reads),
   Forever's game folder too; its config carried over from the WoWLocker
   companion; WoWLocker's download page points to it. The site's "Get started"
   page (/start) has the downloads.
7. **Sharing** (done, 6 October 2026): share links to a part or the whole
   book (revocable), preview cards for Discord and Reddit, the public Hall of
   the Fallen (opt-in per fallen book).
8. **Launch**: hearthtale.app live, then CurseForge and Wago, the project page.

### What the user does

- Register the domain: **hearthtale.app**, done 6 October 2026.
- A **Battle.net API client** for Hearthtale (develop.battle.net), with the
  site's sign-in redirect: done 6 October 2026 (its keys in
  apps/api/.env.local and Vercel's production settings); the redirect URL
  is to add once the address is known.
- The database: Neon through Vercel, done 6 October 2026.

## Chapters from rest to rest (6 October 2026, after testing 0.1.0)

These replace the chapter per level below.

| Question | Decision |
|---|---|
| A chapter | From rest to rest: it closes when the character logs out resting, at an inn, in a city (the game's resting state) or by a campfire (its warmth on you: Cozy Fire on both games, Forever's camps), once it holds a few moments (3). Titled "Chapter N", with where it closed and the levels it covers. |
| In the wild | A logout elsewhere is a night outdoors: a line, and the chapter goes on (the next session wakes in it). A /reload is no night (the logout is settled at the next login, which says whether it was one). |
| The cap | After four hours of play in one chapter, any logout closes it (a night outdoors that ends it). |
| Writing | In scenes: an arrival frames one action ("When I reached Kharanos, I bound my hearthstone at Thunderbrew Distillery."). Related work shares a thought; unrelated work can start another. Close calls, rares, losses and powers have room of their own. Earlier sentences remain stable as the current scene grows. A new paragraph marks a change of scene, morning or danger. The close considers the work, time and rest; its kill recap omits creatures already told through quest objectives. |
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
  the killing blow, mine or my pet's, from `PARTY_KILL` (Forever, Classic
  since 1.15.9), else the combat log's line), the first of each kind, rares and
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
  linking words grounded in arrival, time or aftermath; related moments merged
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

Status (7 October 2026): all seven done; the addon released through 0.5.2 on
GitHub (not yet on CurseForge), tested live on Forever's beta. Next: an
example book on the homepage, a simpler way in for a first visit, a Hardcore
beta, a voice setting (the race's or a neutral narrator), and a journal for a
character already at the highest level (it never levels, so never ends).

1. The repository, from the Field Journal's skeleton.
2. The recording, with the simulation.
3. The writer: the engine, then the sentences, kind by kind, with the writer
   test.
4. The book (Journal tab).
5. Death, epitaphs and the Hall of the Fallen.
6. Settings, minimap button, CurseForge page and logo.
7. Review of the sentences; release 0.1.0.
