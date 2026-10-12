# Hearthtale

A World of Warcraft addon: **your character's own journal, written as you
play.** The addon records the life as it happens (quests, foes, places, close
calls), and each rest (a logout at an inn, in a city or by a campfire) turns
the stretch into a diary entry in your character's own voice: what mattered,
and what it meant to them. On a Hardcore realm, a death closes the book with
an epitaph, and the life joins the Hall of the Fallen. The books can be read
on **[hearthtale.app](https://hearthtale.app)** too, carried there by the
[Ravenpost](https://github.com/salty-max/ravenpost) companion app.

For Classic Era (Hardcore, Season of Discovery) and World of Warcraft:
Forever. A sibling of Lorekeeper's Codex, Explorer's Field Journal and Second
Wind, in the same look (the shared kit, `addon/Hearthtale/Kit.lua`).

## Use

- `/hearthtale` or `/ht` (or the book by the minimap) opens the journal: the
  entries on the left, the open one on the right under its title; a second
  tab for the Hall of the Fallen (`/ht hall`).
- Your own words beside the journal's: an entry's Edit button, or
  `/ht title [N] TEXT` and `/ht note [N] TEXT` (the last entry without N).
- `/ht link CODE`: links a character Battle.net can't find (Forever's) to your
  account on hearthtale.app (the code from its library).
- A welcome page at each character's first login (`/ht welcome`); settings in
  Options -> AddOns -> Hearthtale (`/ht settings`, or right-click the minimap
  button): a line in chat for each entry, the alert when a book closes, the
  minimap button, and where the game can't tell, whether this character is
  Hardcore. Each character keeps its own; `/ht export` gives them as a code,
  `/ht import CODE` takes another's. `/ht minimap` shows or hides the button.

The project page: addon/CURSEFORGE.md. The plan and its decisions: PLAN.md.
How the journal is written, and the rules its sentences follow: CLAUDE.md.

## Development

The addon (`addon/`, `writing/`):

```bash
bun run addon:build     # writing → Data_Classic.lua, Data_Forever.lua
bun run addon:check     # both up to date, simulation and writer test on both games, samples
bun run addon:package   # dist/Hearthtale-<version>.zip: one package for every game
bun run addon:seed      # the test characters and the landing's samples, from the writer
bun run addon:golden save | check   # a writer refactor: every output before/after
bun run audit           # the game's own names and quests, every place and a playthrough per race
```

The site, hearthtale.app (`apps/`, `packages/`; needs `bun install` once):

```bash
bun run db && bun run db:migrate   # local Postgres on :5435
bun run db:seed                    # the test characters
bun run dev                        # api :3002, web :5175 ("Use the test account" locally)
bun run check                      # the addon's checks, then typecheck, lint, tests
```

`apps/api` (Hono on Bun, Postgres through drizzle), `apps/web` (React, Vite,
Tailwind: an installable PWA), `packages/shared` (the saved book's shape, the
wire contract). Hosted on Vercel with Neon.

A release: `scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md` tags and
pushes; GitHub Actions publish it on GitHub, CurseForge and Wago.

## License

GPL-3.0-or-later (see LICENSE). The writer's names (`addon/Hearthtale/Names.lua`) and its audit draw on
[cmangos classic-db](https://github.com/cmangos/classic-db) (GPL-3.0) and [pfQuest](https://github.com/shagu/pfQuest)'s
place names (MIT); the names themselves are Blizzard's. Forever's own content (`addon/Hearthtale/Forever.lua`:
Zephras Isle, Forever's new quests and creatures) draws on the beta client's tables ([wago.tools](https://wago.tools)),
[AllTheThings](https://github.com/ATTWoWAddon/AllTheThings)' Forever database (MIT) and
[QuestieDB](https://github.com/Questie/QuestieDB)'s traces of the beta. Not affiliated with Blizzard Entertainment.
