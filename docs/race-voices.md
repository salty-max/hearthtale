# Racial voices

The narrator is an individual, not a spokesman for everyone of their race.
Culture shapes attention, turns of phrase and humour; it does not prescribe
class, age, personal war service, beliefs or a particular family history.
Use these as literary interpretations of the lore, not canonical quotations.

| Race | What lies behind the voice | Expression |
| --- | --- | --- |
| Human | Rebuilding after repeated wars; adaptable people who depend on neighbours and institutions that can fail them. | Familiar, direct, socially attentive; errands turn names into people, and danger makes home feel urgent. |
| Dwarf | Ironforge's craftsmanship and loyalty, with renewed curiosity about ancient origins and the wider world. | Concrete comparisons, plain judgements, warm understatement; pride in a job that holds up. |
| Night elf | An ancient, formerly secluded people facing change, with the cost of reckless power in their history. | Measured phrasing, watchfulness and long perspective; beauty and suspicion can share a sentence. |
| Gnome | Ingenuity and curiosity continuing after the loss of Gnomeregan. | Precise, lively, self-correcting; curiosity can outrun the feet, but fear need not become an amusing experiment. |
| Orc | Freedom from demonic domination, a shamanic inheritance, and a place still being built in a hostile world. | Deliberate, forceful, accountable; distinguish earned honour from bloodlust and boasting. |
| Darkspear troll | Displacement, loyalty to the tribe, and an alliance that made survival possible. | Resourceful, rhythmic, wry; trouble earns a watchful eye and sometimes a smile, with warmth for company and no phonetic accent. |
| Tauren | The Earth Mother, balance, communal responsibility, and a debt of friendship to the orcs. | Patient, grounded and hospitable; attention to weight, effort and a shared pace, without turning every stop into a nature proverb. |
| Forsaken | Freedom from the Lich King's control; a hostile living world and a difficult second existence. | Exacting, dry, guarded; ownership of choices, black humour and flashes of feeling beneath it. |
| Blood elf | Quel'Thalas's devastation, the loss of the Sunwell, and a proud culture negotiating dependence and survival. | Composed and particular, with restrained irony; distinguish appearing collected from feeling safe, and allow pleasure and affection beside pride. |
| Draenei | Exile, persecution and the guidance of Velen and the naaru; searching for allies in an unfamiliar world. | Courteous, considered, resilient; curiosity and the wish to belong alongside faith, with patience for the narrator's own uncertainty too. |
| Skyborne (Forever) | Missing elemental mentors and the insecurity their disappearance exposed. Windshapers seek their restoration; the High Order seek recovered arcane knowledge and greater self-reliance. | Attentive to change and perspective; warmer reciprocity for Windshapers, more analytical independence for the High Order. |

## Sources and boundaries

- [Blizzard's Classic introduction](https://news.blizzard.com/en-us/article/23317716/taking-your-first-steps-in-world-of-warcraft-classic)
  supplies the original eight races' cultural starting points.
- [Blizzard's Burning Crusade story overview](https://news.blizzard.com/en-us/article/23679744/burning-crusade-classic-the-story-so-far)
  supplies the blood elves' and draenei's starting circumstances. The voice
  does not assume later Sunwell events have occurred.
- [Blizzard's Forever race introduction](https://news.blizzard.com/en-us/article/24304075/create-the-hero-you-want-to-be-in-world-of-warcraft-forever)
  supplies Skyborne identity and the two faction traditions. Skyborne lines
  belong only to the Forever catalog, and faction-specific thoughts require
  the recorded faction rather than guessing it from class.

The familiar races retain their Classic or early Burning Crusade outlooks.
Avoid later wars, destroyed capitals, changes of leadership and future
character fates. A character can remember their people's history without
claiming to have personally witnessed it.

## Restraint

Keep ordinary actions brief enough to join naturally. Reserve the stronger
cultural thoughts for beginnings, pauses, setbacks and endings. Vary diction
and cadence; do not repeat a catchphrase, deity, historical tragedy or racial
metaphor at every event. No accents spelled out, no automatic weapon, no
assumed profession and no invented reaction from an NPC.

Routine clauses are plain; a race's reactions to them are its remark pools
(`voices/<Race>/r-*.md`), told for roughly a third of routine clauses and
never twice in ten chapters. React to the actual teeth, cloth, lesson,
equipment or company in the record;
do not attach a reusable moral about freedom, craftsmanship or patience to
every errand. Cultural vocabulary can colour a reaction without requiring
a catchphrase. All races retain full sentences and the same allowance for
three related clauses.

Read the comparison (`FOREVER=1 luajit addon/test/voices.lua compare >
.cache/race-comparison.md`) with the names hidden: the same recorded
events should produce recognisably different people while retaining their
facts. Read the full journeys in `docs/sample.md` for the subtler effect of
the voice across a chapter.

## The remaining voices in longer scenes

Human, gnome, Darkspear, tauren, blood elf, draenei and Skyborne now have
their own prose across 28 kinds, including flights, outdoor nights, waking,
death and each means of revival, final dungeon bosses and the journal's
last page. The original four voices are unchanged. Two former race-specific
first-flight lines in the shared pool are replaced by the gnome and tauren
files, and a tauren zone arrival moves into its voice file; the general
fallback remains. Routine facts, remark frequency and the writer's sentence
length allowance stay the same.

The ordinary vocabulary should make these differences felt before a deity
or homeland is named. A human wonders who needs a hand; a gnome revises an
impression; a Darkspear narrator keeps some humour for a safer moment. A
tauren notices how a shared pace feels, a blood elf admits the effort of
composure, and a draenei gradually finds familiar names among unfamiliar
ones. Windshapers look for connection, while the High Order put more trust
in something they have examined themselves. None of these tendencies
requires every sentence to express it.

The `moments` mode (`FOREVER=1 luajit addon/test/voices.lua moments`)
supplements the routine day with identical synthetic records of a first
flight, a night outside, danger, death, a companion's help, a dungeon's end
and the final journal entry. These are separate editorial
scenes across a life, not a canonical levelling route. Read them for repeated
words and adjacent thoughts as well as racial character; a good line alone
can still crowd out the feeling of the line beside it.
