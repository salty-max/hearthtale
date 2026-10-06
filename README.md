# Wayfarer's Journal

A World of Warcraft addon: your character keeps a journal as you play, in the
first person, a sentence for each thing as it happens: where you went, what you
did, whom you fought and met, what nearly killed you. A chapter closes when you
rest: logging out at an inn, in a city or by a campfire. On a Hardcore realm, a death closes the
book with an epitaph, and the life joins the Hall of the Fallen.

For Classic Era (Hardcore, Season of Discovery), TBC Anniversary and World of
Warcraft: Forever. A sibling of Lorekeeper's Codex and Explorer's Field Journal.

## Use

- `/wayfarer` or `/wj` (or the book by the minimap) opens the journal: the
  chapters on the left, the chapter on the right; a second tab for the Hall of
  the Fallen.
- `/wj hall`, `/wj settings` (or right-click the minimap button), `/wj minimap`.
- Settings: a line in chat for each chapter, the alert when a book closes, the
  minimap button; where the game can't tell, whether this character is Hardcore.

The project page: addon/CURSEFORGE.md. The plan and its decisions: PLAN.md.

## Development

```bash
bun run build      # writing → Data_Classic.lua, Data_Forever.lua
bun run check      # both up to date, simulation on both games, writer test
bun run package    # dist/classic, dist/forever, zipped
```

## License

MIT. Not affiliated with Blizzard Entertainment.
