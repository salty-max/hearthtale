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
