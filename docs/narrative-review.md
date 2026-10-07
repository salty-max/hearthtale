# Narrative direction

Hearthtale should read as a character recollecting a life: noticing a place,
doing something there, and carrying a little of the experience into what
follows. The recorded events give the story its facts; the prose gives the
narrator attention, feeling and a point of view.

## The same journey, before and after

These excerpts document the first narrative pass, using Brannok's recorded
life in `addon/test/lives.lua`. The current generated prose, including the
later racial voice pass, is in `docs/sample.md`.

Before:

> Anvilmar, by lamplight. I tramped into Coldridge Pass. Kharanos: smoke from
> every chimney, the smell of the Thunderbrew Distillery on the wind, and
> gnome refugees from Gnomeregan huddled among the dwarven houses. Warm,
> loud, and ours. I took a room at Thunderbrew Distillery, took up skinning
> and began to learn leatherworking.

After:

> I turned to a fresh page in Anvilmar, with the night already around me.
> I tramped into Coldridge Pass. I smelled the Thunderbrew Distillery before
> I had properly reached Kharanos. Smoke rose above the houses, where dwarves
> and gnomes crowded together against the cold, and I felt my shoulders ease
> at the sight. I bound my hearthstone at Thunderbrew Distillery, glad to
> have a place to return to. I took up skinning and began to learn
> leatherworking.

A close call in the first chapter previously became "9% in Coldridge
Valley." It now has a consequence for the person telling it:

> A Frostmane Troll Whelp nearly got the better of me, and the thought stayed
> with me after the danger passed. I had been taking my chances too lightly.
> Afterwards, I dealt with fourteen Frostmane Troll Whelps, as Grelin
> Whitebeard had asked; I found Grelin Whitebeard's Journal, right where it
> shouldn't be.

## What changed

- The 25 existing scenery files describe what the protagonist notices and
  how it meets them, including home, allied, hostile and night viewpoints.
- The dwarf, orc, night elf and Forsaken voices use complete thoughts and
  distinct outlooks. The shared fallback received the same treatment for
  openings, endings, close calls and ordinary transitions.
- Arrivals can frame the next action. Related practice and work can share a
  sentence; a comma inside a thought no longer automatically cuts it short.
  Complex clauses receive a grammatical join instead of a chain of "then".
- Time links follow recorded time, and the next action after a close call
  can acknowledge its aftermath. Paragraphs give changes of scene and danger
  more space.
- Health determines the severity of a close call without appearing as a
  percentage. It is no longer an available prose slot.
- Closing fight recaps omit creature names already covered by a narrated
  quest objective, while retaining other fighting from that chapter.
- Hearthstone binding is described as binding a hearthstone. Training,
  equipment and rare encounters no longer need an invented payment, trophy
  or hardcoded dwarf's hammer to give them colour.

## Continuing the writing

Read generated paragraphs, not just individual templates. Vary the length
of thoughts, and keep short sentences where they give an experience weight.
Concrete observation should do more work than repeated remarks about
"the journey", "my account" or "remembering". A racial voice is a way of
looking at the world, not an obligation to mention ale, honour, trees or the
grave in every sentence.

This remains a deterministic writer using authored prose. It cannot infer
an unrecorded quest motive or another character's thoughts. Keep the feeling
in the protagonist's interpretation, and the actions in the recorded life.

The review examples cover Brannok, Grashnak, Aelyndra and Mortis in
`docs/sample.md`; the regenerated site seed also includes Pippa's fallen
Hardcore life and Aldric's journey begun midway through his life.

## Verification

The first narrative pass passed `bun run check`: Classic and Forever simulations, 728 generated books
covering 16,143 chapters, template reachability and repetition checks,
sentence stability as events arrive, sample and seed generation, type
checking, lint, and the API and site tests. Focused writer checks cover
related trades, arrival joins, close-call aftermath, deterministic output
and recaps that distinguish quest fighting from other fighting.

All 133 edited prose files build into both game catalogs. The six site seed
books were regenerated from the addon, and the generated examples were read
for sentence joins, viewpoint, race and class consistency, and endings.

## Racial expression

The subsequent voice pass covers all ten familiar races and Forever's
Skyborne across eighteen recurring kinds of moment. Vocabulary, rhythm,
humour and what the narrator chooses to dwell on distinguish the speakers;
ordinary actions retain enough plain wording to give those differences room.
The original four voices' zone arrivals also received a pass to remove
fragments, assumed hostility and invented reactions from other people.

`docs/race-voices.md` records the lore sources, game-era boundaries and
editorial limits. `docs/race-comparison.md` shows the same synthetic day
through every voice, including both Skyborne traditions. It is a controlled
comparison of expression, not a claim about a canonical quest sequence.

Faction is now recorded at login, including for existing saves. Skyborne
traditions use that faction rather than inferring it from class. The Forever
catalog has its own complete writer run, alongside Classic; focused checks
exercise unknown-race fallback, faction selection, a hundred successive
errands without losing racial identity, factual fidelity and compound joins.

The racial pass passed `bun run check`, including 728 Classic books across
16,319 chapters and 812 Forever books across 18,098 chapters, plus the
focused fallback and faction probes, both recording simulations, type
checking, lint and the API and site tests. Both catalogs, the comparison,
sample journeys and all six site seed books were regenerated and reviewed.

## Remarks

A remark is the narrator's reaction at the end of a routine clause: the
voice of the everyday. They live apart from the clauses, in pools by subject
(`writing/r-*.md`, and each race's own in `writing/voices/<Race>/`), so one
remark can follow any verb, and the same one never comes back under another
verb. Each race has eight to thirteen per pool, the shared pools twelve or
more. The race's own come first; once used, one comes back only after ten
chapters, the shared ones filling every other gap, otherwise the clause goes
plain. About a third of routine clauses carry one, never two in a sentence
or in successive sentences, and none is told twice in a book's first ten
chapters (`addon/test/writer.lua` checks it over every generated life).

Remarks react to their subject with a range of feeling: curiosity, pride,
humour, unease, respect, appetite. They read after one foe or several, one
item or a plural one. The routine clauses themselves are plain and shared;
a race keeps only the verbs that are its own (a dwarf "did for", a Forsaken
"disposed of", a dwarf "tramped", an orc "marched"), and two clauses running
never begin with the same verb.

The chapter's recap (tasks done, fighting, time) holds one reflection; the
others are told plainly, and the rest that closes the chapter keeps its own.

**Brannok:**

> I recovered eight Tough Wolf Meat, with rather more appetite for a cooked
> supper. … I did for a Burly Rockjaw Trogg, the sort of fight that tells
> better than it fights; I killed six Rockjaw Troggs.

**Grashnak:**

> I saw Gornek's business through with Master Gadrin, no glory in it, only use.
> … I got the better of ten Kul Tiras Sailors, a fair fight, and I took no more
> from it than that.

**Aelyndra:**

> I found ten Webwood Venom Sacs, the moonlight showing what the day had
> hidden. … I fetched an Emerald Dreamcatcher, with an eye to what the land
> could spare.

**Mortis:**

> I disposed of a Wretched Zombie, with no more fuss than the matter required.
> … I tracked down five Vile Fin Scales, the smell bothering everyone but me.

Places are described in flowing sentences rather than chains of possessives
("the cold of Dun Morogh", not "Dun Morogh's cold … Ironforge's mountain").

## The remaining voices

This pass follows the later quest-work, naming, death, crafting and dungeon
changes. It deepens human, gnome, Darkspear, tauren, blood elf, draenei and
both Skyborne traditions. Each now has its own writing across 28 kinds of
moment, with full sentences and room for feelings other than weariness.
The original four voices and the writer's rules stay intact. Two shared
first-flight lines specific to gnomes and tauren give way to their fuller
voice files, and a tauren zone arrival moves into its own file, so no
superseded line remains unreachable.

The before excerpts below come from the previous generated comparison;
the after excerpts come from the regenerated comparison. They show the
change from a judgement about ordinary work to a reaction from the person
doing it. The larger scenes in `docs/voice-moments.md` also let each voice
carry through flights, a night outside, death and help, a dungeon's end and
the journal's final page.

**Human** notices people and familiar places, with the plain warmth of
someone who wants to get home. Before:

> I set out to recover the missing cargo and did so, the kind of work nobody
> writes songs about.

After:

> A Southsea Brigand left me within a breath of the end. The same road
> looked quite different when I could bear to look along it again.

**Gnome** is curious and willing to revise an impression, without turning
fear into a lesson in ingenuity. Before:

> A mistake was something to learn from only if I remained available for
> the lesson.

After:

> A Southsea Brigand left me barely alive. My hands were shaking too much
> for cleverness to feel like much of an achievement.

**Darkspear** keeps a wary humour and an interest in good company. The
speaker can set that humour aside when frightened. Before:

> People learned what a stranger was worth through such things.

After:

> I opened a fresh page in Ratchet, interested in the next good chance and
> watchful for its neighbours.

**Tauren** brings physical presence and care for a shared pace, with the
Earth Mother reserved for moments that warrant the reference. Before:

> I took up tailoring, the lesson settling slowly, like rain into soil.

After:

> I took up tailoring, curious how the next attempt would feel.

The close call has more room:

> A Southsea Brigand left me barely alive. I wanted to feel the ground
> beneath my hooves for many days yet.

**Blood elf** distinguishes composure from confidence, allowing fear and
affection without giving every errand a sneer. Before:

> Doing ordinary work well remained preferable to making excuses for its
> ordinariness.

After:

> By the end, three tasks were done. I found myself remembering the people
> who had asked for them.

**Draenei** has courtesy, curiosity and a wish to belong, alongside the
ordinary fear that faith does not erase. Before:

> Care could take an ordinary shape and remain care.

After:

> I escaped a Southsea Brigand, shaken by how little had stood between a
> mistake and the end of everything I still wanted to do.

**Skyborne** keeps two traditions without assigning one from class. Their
previous close-call reflection was the same:

> The future I wanted for my people still needed living hands to make it.

Windshaper after:

> A Southsea Brigand nearly killed me. For a while I wanted nothing more
> than to feel that I still belonged among the living things around me.

High Order after:

> I barely survived a Southsea Brigand. I could see where I had misjudged
> the danger, but understanding it did very little to quiet my fear.

Read the surrounding paragraphs in `docs/race-comparison.md`, not only
these excerpts. The everyday remarks remain occasional; cultural names
and metaphors should not pile up in neighbouring passages. The review of
the larger scenes removed repeated references to homeland or faith around
the same death, and varied the draenei's repeated unfamiliarity so it did
not become their only feeling.

The pass passed `bun run check`, including both recording simulations,
832 Classic books across 19,852 chapters and 928 Forever books across
22,166 chapters, all prose and scenery reachability, repetition and sentence
stability checks, type checking, lint and the API and site tests. Routine
remarks remained at 34% in both catalogs, with none repeated within a book's
first ten chapters. The separate real-quest playthrough passed 1,792 quests
across 146 chapters and eight books; early, middle and late chapters of the
four revised Classic voices were read alongside the controlled comparisons.

Both catalogs, the sample journeys, the two voice comparisons and all seven
site seed books were regenerated. The larger-moment comparison was also
checked for filled slots, sentence joins and its recorded destinations,
companion, final boss and final level. No recording or assembly rule changed.
