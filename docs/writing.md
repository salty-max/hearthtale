# Writing Hearthtale

The writing's files, what an entry holds and how its sentences are written
(moved from CLAUDE.md on 20 October 2026). The races' sources and limits:
`docs/race-voices.md`.

## The writing's files

- `writing/<kind>.md`: the sentences of one kind of moment (front matter
  `kind:`; one `- sentence` per line, optional `[tags]` = the conditions it
  needs). Built by `scripts/build.ts` into `addon/Hearthtale/Data_Classic.lua`
  and `Data_Forever.lua` (one per game; `client:` tags keep a sentence to one).
- `writing/voices/<Race>/<kind>.md`: a race's own sentences (same format,
  `<Race>` as the game names it: `Scourge`, `NightElf`). The writer prefers
  them, lets a used one back after `ownGap` uses of the kind (a fresh shared
  one first), and falls back on the shared ones; two of them an entry at
  most, the ending aside. Flavour comes from outlook and phrasing, never from
  broken grammar or a racial caricature. `docs/race-voices.md` records the
  lore sources, cultural outlooks and limits on expression for all races.
  Skyborne traditions require the recorded faction and the Forever catalog.
- `writing/why/*.md`: what each quest's work was for, the story an entry
  tells: `- <id> <weight> [<subject>] | <phrase>`, a phrase in -ing written
  from the quest's own texts (the giver's words, its objectives, its
  hand-in), weighed 1 (an errand with a reason) to 3 (a story's climax, a
  rescue, a villain's end); a quest with nothing to tell has no line. A
  story weighed 2 or 3 says what it was, for a word on it (the build
  requires it): `villain` (one foe of a name, its wrongs ended), `victim`
  (the corrupted, cursed or maddened put down or laid to rest, a release),
  `rescue` (someone brought out alive), `beast` (a great beast hunted),
  `undead`, `demon`, or `none`; an errand's is guessed. The build turns it into the
  deed itself, read after "I": "killing Hogger, …" is "killed Hogger, …", the
  first verb and those joined to it in the past (a gerund after a
  preposition, a comma or a noun keeps its own "and": "wanted for murdering
  Forsaken and ambushing supplies"; a form the English word list doesn't
  know fails the build: IRREGULAR, or reword). `batch-*.md` are Classic's
  (from the classic-db dump), `forever-*.md` Forever's own (its quest texts
  as published; in Data_Forever only). The build checks every phrase.
- `writing/scenery/<slug>.md`: a place described the first time a life meets
  it (`Book:sceneryOf`): a life's first land, a land, a capital or a dungeon
  an entry tells, the town an entry ends in (front matter `place:`,
  `type:` zone | town | dungeon, `faction:` alliance | horde | neutral,
  optional `home:` races, optional `client:` a place of one game only:
  Zephras Isle is `forever`). Lines tagged by viewpoint: `[home]`, `[ally]`,
  `[foe]`, `[neutral]`, plus `[night]`; 2-3 sentences each.
- Plain ASCII in `writing/` (' and plain quotes).
- Lore and places true to the original game; the writing is in the first
  person, never the League's voice.

## The journal

An entry is the stretch looked back on at its rest, by what weighs most:

- the milestones of a life, always: a first demon of its kind (`[known]`
  when a class quest taught its summoning before, merged when the same
  stretch); a form; a companion (`d-tame`, `[first]` or another); a shaman's
  initiation into an element (`d-initiation`, once an element, from the
  quest that gives its totem); a spell that defines the class (`d-calling`,
  `W.callingOf` in Language.lua: a warrior's charge, stances, second weapon
  and whirlwind, a paladin's auras, Lay on Hands, Redemption and shield, a
  rogue's second blade, picks, poisons, vanishing and blinding, a priest's
  own people's prayers and Resurrection, a mage's sheep and first teleport
  and portal, a warlock's summoning circle, a shaman's ghost wolf and second
  life, a hunter's feigned death, a druid's Moonglade and Rebirth; once
  each, learned or a class quest's reward, which it then stands for); a
  class quest's reward; a specialization (`d-spec`, by its name as the game
  gives it: each race's own take on each of its classes' trees, in its voice
  file, `[class:MAGE spec:Fire]`; `[change]` another after it, `{was}`; the
  shared lines only for a name none of those has);
  the highest level the game allows (`summit`);
- the story, always: the deed itself, "I killed Hogger, …" (`d-why`,
  `d-why2`, `d-why-also`; a second story elsewhere says where, "Later, in
  Westfall, I …", unless it names its own place; a second climax, and in a
  stretch full of stories a deed beside a climax, then a third when the
  entry has nothing else of its own (no milestone, land, company, dungeon,
  death, foe of note or trade); two follow-ups never open alike, each by
  what the record shows: `[last]` "before the stretch was out", `[night]`
  fallen since the one before, `[thread]` the same chain); one deed told
  once (two quests that ended the same foe of a name, in one stretch or
  two); done in company, who was with me when it was done leads it ("With
  Oblock, Kyle and Fkn, I killed …": the party at the quest's end, `with`,
  never one who had left; an older record names no one there), the others
  met in the company's sentence; a class's own quest
  is a milestone, never a story; a chain's quest after an entry of the last
  four told one of it by the same people is `[thread]`, its end `[thread
  settled]`, whose business it was by name (`[who]`, `{who}`) unless the
  deed names them, "the old business" (`[old]`) only an entry or more
  later; now and then (`REACT_GAP` entries apart, never the same line
  twice in a book) a word on what it was, `d-react`, by the story's subject
  (writing/why/; an errand's guessed: `[rescue]` of a named person, never
  souls, a thing, a place, one of a kind, nor one freed to be slain;
  `[villain]` one named foe): `[villain]`, `[victim]`, `[rescue]`,
  `[beast]` (only a beast I hunted myself), `[undead]` (a Forsaken's own),
  `[demon]`, and first a race's peoples of note (`[leper]`, `[highborne]`,
  `[cenarion]`); after two deeds in one sentence, only when both were
  alike;
- deaths (`died`, `died-back`, `d-deaths`) or the closest call (its foe told
  there, not again among the foes), a dungeon and its end ("we" when
  grouped), a capital's first sight, a Skyborne's first ground below the
  islands (after the island's work that took them there), players slain, a
  raid, a find (epic and better), a pet lost; a piece of gear worn for the
  first time (`d-gear`: below level 30 a blue one or one I made, an epic one
  at any level; one an entry, made first; with its find when looted in the
  same stretch); a stop by a fire (`d-camp`: one shared with companions, the
  life's first, one of Forever's camps now and then; `[last]` the fire the
  entry ends at, in place of the rest);
- a place seen for the first time in a life, described right after it is
  told (writing/scenery/: a new land, the first of an entry's with a
  description; a capital; a dungeon) and the town an entry ends in, before
  its rest;
- in the room left (`ROOM`, less one for each milestone, two at least),
  by what matters to the one who lived it: company first, a lesson paid for
  in my own health (`DEAR`: Life Tap over Immolate), named foes (`d-foes`; a
  rare by its name; "both" never before a kind), new lands (`d-land`; a city
  is no country: `[!town]`, nor a list holding one), the other lessons' own
  lines (`lesson`, `[spell:Life_Tap]`; marked told only once told) or a new
  way of fighting (`d-powers`, `[used]` only when each was cast before the
  stretch closed, as the record shows), a new
  rank in a trade, a ride, the first flight (`flight`, from where to where),
  the first bag (by its name and room) or gold, the pet named again
  (`d-pet`);
- continuity, sparse and from earlier entries only: one who brought me back
  from death, in the company's sentence when met again (`d-company`
  `[reviver]`, once); a foe of a name that killed me or nearly did, beaten
  later (`d-revenge`, `[died]`, once, not when the story tells it); a pet
  that fell once, named again (`d-pet` `[fell]`); a trade's first new rank,
  where it was taken up (`c-prof` `[since]`);
- the trades of the stretch, one sentence (`c-prof`: `[new]`, `[again]` after
  one was given up, `[rank]`, `[master]` at 300, `[dropped]`; in the order
  they came, one verb for those in a row at the same stage, the trade just
  named as "it" (`[it]`: "took up mining and gave it up"), one given up and
  taken up again straight after a return to it (`[back]`), what my hands made beside
  them, never the piece worn): a trade begun, ended or mastered is always
  told, a rank alone in the room left; a weapon's 300 is no news; what my
  hands made, new to them, when no trade was told (`d-made`, `MADE_GAP`
  entries apart);
- the small work (`d-chores`, never counted; "the rest of it" only `[after]`
  something) only when nothing else was;
- the ending: a thought on a danger (`d-close`: `[hard]`, `[near]` only
  once three sentences were told since the danger's own, which carries its
  feeling; `[delve]`), else the rest, the night outdoors or indoors (a
  journal an older version closed at the highest level ends on `summit`);
  one entry in three that told a story ends on it.

Told in the order it happened (a place always named: no "there"), a lead
story first now and then ("In Loch Modan, I …", where the last entry
rested), its word right after it; two paragraphs from `PARAGRAPH` sentences.
The first ride names its mount and speaks in the race's own words (a dwarf's
ram), whatever came before. An entry's title is its weightiest moment in the
game's own words, never made-up prose: a milestone (a demon's or a pet's
name, a form, the element's quest), a story with a villain or a rescue (its
quest's title, "Wanted:", "Kill" and a poster's quotes taken off), a
defining spell or a specialization, a dungeon, a death ("A Death in Westfall"), any other story,
the first ride, a capital or a new land, another story of the entry or a
foe of a name it ended ("Grawmug"), else the land it was lived in; none
rather than one an earlier entry has. A title the player gives an entry
shows in its place, and a note in its margin under it: both lie over the
written book (`writtenTitle` keeps the writer's), which never changes.
A book's frames never come back while a fresh one is left; a finished entry
never changes, the open one is written again at each moment. Across versions
too: a closed entry keeps the words it was saved with (a keepsake; the
player's `/ht rewrite` writes the journal anew with the current writer). A life met
mid-life opens with its prologue; a Hardcore death closes the book with the
epitaph (`epitaph`, `remembrance`, `farewell`), in the third person, by the
name.

## Writing the sentences

- Write a recollection through the protagonist's eyes. Let an observation
  lead to a reaction, and give danger, loss and a new power room to matter.
  Prefer connected thoughts to short fragments, a checklist or "Place: text".
  Concrete details should carry the feeling; avoid repeating abstract remarks
  about the account, the journey or remembering in every line.
- Scenery is experienced, not announced: what I notice, how it meets me,
  what that makes me think. Keep its landmarks true to the original game and
  its viewpoint appropriate to race, faction and time of day.
- A line reacts to what the record shows (the fight, the find, the road,
  the hour) or to the narrator's own feeling, never a general moral and never
  an invented fact: no lamps, fires, innkeepers, trainers' manners, payments,
  a companion's looks or talk, and no personal history the record can't know
  (the build refuses "all my life", "my father", "my workshop"), nor a
  claim it can't back: a habit ("more than once"), gear "the best yet", a
  spell put to use without `[used]` (the build refuses those too).
- The races must sound apart: reach for what the race notices and how it
  says so, not a feeling word. A racial voice is a way of looking at the
  world, not an obligation to mention ale, honour, trees or the grave in
  every sentence: a race's emblems (`MOTIFS` in Lines.lua: the forge, the
  camps, the drums, and what stands in for them, the hammer, the tally, the
  meal; "$" for a word alone, "iron" not Ironforge) are spaced `MOTIF_GAP`
  lines apart each and `EMBLEM_GAP` lines all together (unless the line is
  the one wanted: a tauren's kodo for a first kodo), and every narrator's
  relief at rest (`RESTFUL`: stillness, shoulders, aches) the same way.
- Connectors need evidence: time passing, nightfall, an arrival, or the
  aftermath of a close call. Emotional interpretation is welcome; an
  unrecorded action, spell cast, trophy, payment or another person's
  reaction is not a fact to invent. A dwarf hunter does not automatically
  wield a hammer.
- Tell a close call as an experience, with its consequences for the
  narrator; keep the health percentage in the record.
- Clauses (kinds `c-*`: `c-loot`, `c-raid`, `c-prof`): lower case, no final
  stop, read after "I" ("found {item}").
- One kind per file; the slots of each kind are listed in `scripts/build.ts`
  (KINDS), plus the voice: {home}, {kin}, {faith} (missing for some, so the
  sentence is skipped), {weapon} (an object only: "fell to {weapon}", never
  "{weapon} was").
- {at} names the place with its preposition ("in Thelsamar", "on Zephras
  Isle"); a sentence with {at} must read well without it ("I rested."). {in}
  names it too, for sentences without a verb. A slot never doubles the word
  before it ("I went on {at}" with "on Zephras Isle" is refused).
- Tags are conditions: night, hc, high (level 40+), low (10 and under: no
  hunter's pet yet), late (a journal begun after the life's first steps: no
  land, city or fire told as seen for the first time, the record can't know
  it; every such line is [!late]), first, elite, one, two, town, home, hosts; for a death:
  foe, fall, drowning, lava, nature, beast, people, player, inside; race:X,
  class:X, faction:x, client:x; "!night" = not at night. A tagged sentence
  is preferred while fresh; a life's first page prefers its class's own
  beginning; an epitaph's line that tells the cause always wins.
- A count of one never meets a plural ("one tasks"): such slots are left
  empty for one.
- After changing the writing: `bun run addon:build`, then `bun run
  addon:check`, regenerate `docs/sample.md` and the site seed (`bun run
  addon:seed`, the landing's samples with it), and read the generated journals again
  (`luajit addon/test/playthrough.lua`, `.cache/audit/books/`): read whole
  entries, not just each template alone; real quests show what the random
  lives don't. Places in flowing sentences, not chains of possessives ("the
  cold of Dun Morogh", not "Dun Morogh's cold"). Regenerate and read the race
  comparison (`voices.lua compare`) when changing racial expression; use the
  restraint and era boundaries in `docs/race-voices.md` (and its few words
  in a people's own tongue, verified, at moments that bear them).
