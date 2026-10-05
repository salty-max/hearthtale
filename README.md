# Wayfarer's Journal

A World of Warcraft addon: your character keeps a journal as you play, in the
first person, one chapter per level: where you went, what you did, whom you
fought and met, what nearly killed you. On a Hardcore realm, a death closes the
book with an epitaph, and the life joins the Hall of the Fallen.

For Classic Era (Hardcore, Season of Discovery), TBC Anniversary and World of
Warcraft: Forever. A sibling of Lorekeeper's Codex and Explorer's Field Journal.

Work in progress: see PLAN.md.

## Development

```bash
bun run build      # writing → Data_Classic.lua, Data_Forever.lua
bun run check      # both up to date + simulation on both games
bun run package    # dist/classic, dist/forever, zipped
```

## License

MIT. Not affiliated with Blizzard Entertainment.
