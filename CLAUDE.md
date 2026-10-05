# Wayfarer's Journal

A World of Warcraft addon: the character's own journal, written as it plays,
in the first person, one chapter per level; on Hardcore, an epitaph and the
Hall of the Fallen. Sibling of Lorekeeper's Codex and Explorer's Field Journal
(same games, look and tooling), but standalone: it reads none of their records.
The plan and its decisions: PLAN.md.

## Layout

- `writing/<kind>.md`: the sentences of one kind of moment (front matter
  `kind:`; one `- sentence` per line, optional `[tags]` = the conditions it
  needs). Built by `scripts/build.ts` into `addon/WayfarersJournal/Data_Classic.lua`
  and `Data_Forever.lua` (one per game; `client:` tags keep a sentence to one).
- `addon/WayfarersJournal/`: `Core.lua` (the character's record, events,
  `/wayfarer`). The source TOC has an `@INTERFACE@` placeholder: not installable
  as is; `scripts/package.ts` builds `dist/classic` and `dist/forever`.
- `addon/test/sim.lua`: fake WoW API, a life replayed, every recording
  asserted. `FOREVER=1` runs it as Forever.

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
