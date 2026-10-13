# Hearthtale

Hearthtale keeps a diary for your World of Warcraft character as you play.
Quests, close calls, new places and the people you travel with become entries
written in your character's voice. Each race has its own way of telling the
story. On Hardcore, a death closes the journal with an epitaph and saves it
in the Hall of the Fallen.

You can read the books in game or on **[hearthtale.app](https://hearthtale.app)**.
The optional [Ravenpost](https://github.com/salty-max/ravenpost) companion
uploads them after you log out or reload.

For Classic Era, Hardcore, Season of Discovery and World of Warcraft:
Forever. One download covers both games.

## In game

Type `/hearthtale` or `/ht`, or click the minimap button to open the journal.
Each login says in chat whether you're resuming an entry or starting a new
one.
Choose an entry from the list to read it. The second tab holds the Hall of
the Fallen, which you can also open with `/ht hall`.

An entry follows the time between rests. Logging out at an inn, in a city
or by a campfire closes it. Logging out in the wild records a night outdoors
and keeps it going. After four hours of play, the next logout closes the entry
wherever you are. A character you already play starts with a prologue, then
builds a journal from that point on.

Use an entry's **Edit** button to give it your own title or add a note. You
can also use `/ht title [N] TEXT` and `/ht note [N] TEXT`. Leave out N to
change the latest entry. Your words are kept separately from the journal's
text.

A finished entry keeps its words, even after an update improves the
writing. `/ht rewrite` writes the whole journal again with the current
version, after asking; your titles and notes stay.

## Read on hearthtale.app

Install Ravenpost, click **Link with Battle.net** on its Hearthtale card and
sign in. For Forever characters, or any character Battle.net cannot find, get
a code from **Link a character** on the site and enter `/ht link CODE` in
game. Your book arrives after your next logout or `/reload`.

The website is optional, and books are private unless you choose to share
them. Your notes stay out of a shared book and the Hall. Setup instructions
are at [hearthtale.app/start](https://hearthtale.app/start).

The addon is written for English game clients. On other clients, game names
appear in their own language within English sentences, and some events that
depend on English names are missing. In Forever dungeons, the journal can
only tell kills that a quest also counts.

## Settings

The welcome page appears once per character. Open it again with
`/ht welcome`. Settings are under **Options > AddOns > Hearthtale**, through
`/ht settings` or by right-clicking the minimap button.

Choose chat announcements, the alert when a book closes and the minimap
button's visibility and position. You can mark a character as Hardcore when
the game cannot identify it. Settings are saved per character and can be
transferred with `/ht export` and `/ht import CODE`. Use `/ht minimap` to
show or hide the button.

Hearthtale shares its book style with Lorekeeper's Codex, Explorer's Field
Journal and Second Wind. Each addon works independently.

The full store description is in [addon/CURSEFORGE.md](addon/CURSEFORGE.md).
[PLAN.md](PLAN.md) records the design decisions, and [CLAUDE.md](CLAUDE.md)
describes how the journal is written and the rules its sentences follow.

## Development

The addon lives in `addon/`, with its writing in `writing/`.

```bash
bun run addon:build     # Build Data_Classic.lua and Data_Forever.lua
bun run addon:check     # Check generated files, simulations, writing and samples
bun run addon:package   # Create dist/Hearthtale-<version>.zip
bun run addon:seed      # Generate test characters and website samples
bun run addon:golden save    # Save journal output before a writer refactor
bun run addon:golden check   # Compare output after the refactor
bun run audit           # Check game data and play through each race's quests
```

The website lives in `apps/` and `packages/`. Run `bun install` once before
starting it.

```bash
bun run db             # Start local Postgres on port 5435
bun run db:migrate
bun run db:seed         # Load the test characters
bun run dev            # API on port 3002, web on port 5175
bun run check          # Run addon checks, typechecking, lint and tests
```

The local site has a **Use the test account** button. The API uses Hono on
Bun with Postgres and Drizzle. The web app uses React, Vite and Tailwind, and
can be installed as a PWA. Shared data types live in `packages/shared`.
The site is hosted on Vercel with Neon.

To release the addon, run
`scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md`. The script tags and
pushes the release, and GitHub Actions publishes it on GitHub, CurseForge
and Wago.

## License

[GPL-3.0-or-later](LICENSE). The writer's names in
`addon/Hearthtale/Names.lua` and its audit use
[cmangos classic-db](https://github.com/cmangos/classic-db) (GPL-3.0) and
[pfQuest](https://github.com/shagu/pfQuest) place names (MIT). The names
themselves belong to Blizzard.

Forever data in `addon/Hearthtale/Forever.lua` comes from the beta client's
tables on [wago.tools](https://wago.tools),
[AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) (MIT) and
[QuestieDB](https://github.com/Questie/QuestieDB)'s beta records. Not affiliated
with Blizzard Entertainment.
