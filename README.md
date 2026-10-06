# Hearthtale

A World of Warcraft addon: your character keeps a journal as you play, in the
first person, as it happens, in scenes: where you went, what you did there,
whom you fought and met, what you learned and wore, what nearly killed you. A chapter closes when you
rest: logging out at an inn, in a city or by a campfire. On a Hardcore realm, a death closes the
book with an epitaph, and the life joins the Hall of the Fallen.

For Classic Era (Hardcore, Season of Discovery), TBC Anniversary and World of
Warcraft: Forever. A sibling of Lorekeeper's Codex and Explorer's Field Journal.

## Use

- `/hearthtale` or `/ht` (or the book by the minimap) opens the journal: the
  chapters on the left, the chapter on the right; a second tab for the Hall of
  the Fallen.
- `/ht hall`, `/ht settings` (or right-click the minimap button), `/ht minimap`.
- Settings: a line in chat for each chapter, the alert when a book closes, the
  minimap button; where the game can't tell, whether this character is Hardcore.

The project page: addon/CURSEFORGE.md. The plan and its decisions: PLAN.md.

## Development

The addon (`addon/`, `writing/`):

```bash
bun run addon:build     # writing → Data_Classic.lua, Data_Forever.lua
bun run addon:check     # both up to date, simulation on both games, writer test
bun run addon:package   # dist/classic, dist/forever, zipped
```

The site, hearthtale.app (`apps/`, `packages/`; needs `bun install` once):

```bash
bun run db && bun run db:migrate   # local Postgres on :5435
bun run dev                        # api :3002, web :5175
bun run check                      # the addon's checks, then typecheck, lint, tests
```

## License

MIT. Not affiliated with Blizzard Entertainment.
