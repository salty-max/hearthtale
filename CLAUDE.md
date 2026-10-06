# Wayfarer's Journal

A World of Warcraft addon: the character's own journal, written as it plays,
in the first person, in scenes (the moments in one place told together), a
chapter from rest to rest (a
logout at an inn, in a city, by a campfire); on Hardcore, an epitaph and the
Hall of the Fallen. Sibling of Lorekeeper's Codex and Explorer's Field Journal
(same games, look and tooling), but standalone: it reads none of their records.
The plan and its decisions: PLAN.md.

## Layout

- `writing/<kind>.md`: the sentences of one kind of moment (front matter
  `kind:`; one `- sentence` per line, optional `[tags]` = the conditions it
  needs). Built by `scripts/build.ts` into `addon/WayfarersJournal/Data_Classic.lua`
  and `Data_Forever.lua` (one per game; `client:` tags keep a sentence to one).
- `addon/WayfarersJournal/`: `Core.lua` (the character's record, events,
  `/wayfarer`), `Record.lua` (the chapters and their moments, as they happen;
  a logout settled at the next login),
  `Writer.lua` (the prose, written from the records when read: never stored),
  `Book.lua` (the window: chapters on the left, the open one on the right; a
  second tab for the Hall of the Fallen), `Hall.lua` (a Hardcore death: the
  book closed and copied to the account-wide Hall, a chat line, the toast),
  `Settings.lua` (account settings, the Options page), `Minimap.lua`.
- `addon/CURSEFORGE.md`: the project page. `assets/logo.svg` and its PNGs (512,
  1024): render with headless Chrome (an `<img>` of the SVG, `--screenshot`;
  ImageMagick's own SVG renderer drops the gradients), then scale with magick.
  The source TOC has an `@INTERFACE@` placeholder: not installable as is;
  `scripts/package.ts` builds `dist/classic` and `dist/forever`.
- `addon/test/game.lua`: the fake game (WoW API, events, a character to play,
  the addon loaded), shared by:
  - `addon/test/sim.lua`: a life replayed, every recording asserted, its book
    written. `FOREVER=1` runs it as Forever.
  - `addon/test/sample.lua`: a Hardcore dwarf hunter's first evenings, played
    through the addon; `luajit addon/test/sample.lua > docs/sample.md`.
- `addon/test/writer.lua`: hundreds of imaginary lives (every race and class,
  Hardcore or not, met mid-life), every chapter checked; every sentence must be
  reachable, none used again within 6 uses of its kind, and a chapter told one
  moment more keeps what it had (but its last sentence).

## Writing the sentences

- Clauses (kinds `c-*`) make the scenes: lower case, no stop, read after "I"
  and joined with others ("took a room at {inn}"); a clause with its own
  punctuation ends its sentence.
- One kind per file; the slots of each kind are listed in `scripts/build.ts`
  (KINDS), plus the voice: {home}, {kin}, {faith} (missing for some, so the
  sentence is skipped), {weapon} (an object only: "fell to {weapon}", never
  "{weapon} was").
- A place is named, then "there" once, then left out: a sentence with {at} must
  read well without it ("I put down {n} {foes} {at}."). Without a verb, use
  {in}, which always names the place ("{foe} {in}.").
- Tags are conditions: night, hc, high (level 40+), low (10 and under: no
  hunter's pet yet, so its lines are [class:HUNTER !low]), first,
  elite, lots, many, slow, quick; for a death: foe, fall, drowning, lava, nature,
  beast, people, player, inside; race:X, class:X, faction:x, client:x;
  "!night" = not at night. A tagged sentence is preferred while fresh, so voice
  lines come early; an epitaph's line that tells the cause always wins.
- The epitaph (epitaph, remembrance, farewell) is in the third person, by the
  name; the rest of the book in the first. A count of one never meets a
  plural ("one tasks"): such slots are left empty for one.
- After changing the writing: `bun run build`, then `bun run check`,
  regenerate `docs/sample.md` and read it again.

## Commands

```bash
bun run build | check | package
scripts/release.sh [--version X.Y.Z] NOTES.md   # tag, push; Actions publish
```

## Conventions

- Plain ASCII in `writing/` (' and plain quotes).
- Conventional Commits, lowercase subjects; ask before pushing or releasing.
- Lore and places true to the original game; the writing is in the first
  person, never the League's voice.
