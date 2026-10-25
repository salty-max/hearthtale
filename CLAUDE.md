# Hearthtale

A World of Warcraft addon: the character's own journal, written as it plays,
in the first person: each chapter of the record, from rest to rest (a logout
at an inn, in a city, by a campfire), read as the diary entry the character
writes at the rest that ends it ("Entry 3" to a reader: in the window, the
chat line, on the site; the data keeps `chapters`); on Hardcore, an epitaph
and the Hall of the Fallen.
Sibling of Lorekeeper's Codex and Yonder (same games, look
and tooling), but standalone: it reads none of their records. The plan and
its decisions: PLAN.md (the full chapter prose was dropped on 10 October
2026; its writer is on the branch `chapters-archive`). Around it, the site
hearthtale.app (Turborepo and Bun workspaces: `apps/api`, `apps/web`,
`packages/shared`); salty-max/hearthtale. Read the family's CLAUDE.md
(`../CLAUDE.md`) first.

## Where things are

| What | Where |
|---|---|
| The addon file by file: languages, the generated tables (Names, Knowledge, Client, Forever), every Lua file, the tests; the record in English, the saved file in ids | `docs/architecture.md` |
| The writing's files (`writing/`, voices, why, scenery), what an entry holds, how a sentence is written | `docs/writing.md` |
| The races' lore sources, outlooks and limits | `docs/race-voices.md` |
| The site: api, web, shared, hosting, accounts, sharing, Ravenpost, notifications | `docs/site.md` |
| Sample journals (regenerated after a writing change) | `docs/sample.md`, `docs/sample-deadmines.md` |
| The plan, the site's steps | `PLAN.md` ("The site") |
| The store page | `addon/CURSEFORGE.md` |
| Turborepo's own agent notes (managed by turbo) | `AGENTS.md` |

A few local review notes in `docs/` are excluded (`.git/info/exclude`):
absent from git and from a worktree. Everything else there is tracked, the
docs above included.

## Commands

```bash
bun run addon:build | addon:check | addon:package   # the addon
bun run ids                                         # (in addon:check) every table saved-ids.json lists keeps its ids (addon-kit's ids.ts)
bun run addon:golden save [journal…]; bun run addon:golden check [journal…]
                       # a writer refactor: every output before/after, byte for byte
bun scripts/root.ts --run wow-data/bin/latest.ts    # newer game builds than wow-data's pins?
bun run dev | typecheck | lint | test | build       # the site
bun run check                                       # everything (about five minutes)
bun scripts/root.ts --run addon-kit/q.ts check -- bun run check   # the same, quiet, stamping the tree for the push
bun run db | db:generate | db:migrate | db:seed
bun run addon:seed                                  # regenerate the test characters, the landing's samples
bun run audit                                       # the generated tables, the journals read again (.cache/audit/)
bun run kit:sync                                    # after a change to the kit (Kit.lua, Media, scripts/root.ts)
scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md
                       # the addon: check, tag, push; Actions publish it on GitHub, CurseForge, Wago
                       # (--hold: GitHub alone; the stores later: gh workflow run release.yml -f tag=vX.Y.Z)
```

## Hard rules

- The journal is written in English on every client (8 October 2026); the
  interface goes through `L` in every language. The record keeps the
  game's names in English by id; the saved file keeps ids, never a game
  name, turned back at the login.
- First person, the character's own recollection: never the League's
  voice, never an invented fact (lamps, payments, a companion's talk, a
  personal history the record can't know). The build refuses some; the
  rest is `docs/writing.md`. Use full Opus for the writing.
- The races sound apart by outlook and phrasing, never by broken grammar
  or caricature (`docs/race-voices.md`).
- Plain ASCII in `writing/`, no semicolons in what players read.
- After changing the writing: `bun run addon:build`, `addon:check`,
  regenerate `docs/sample.md` and the seed (`addon:seed`), and read whole
  generated journals again (`luajit addon/test/playthrough.lua`). A writer
  refactor keeps every output byte for byte (`addon:golden`).
- A why line naming a new place: run the audit and commit `Names.lua` with
  it. Generated tables are never edited by hand, and a regenerated one
  keeps every id a saved file may hold (`saved-ids.json`, `bun run ids` in
  `addon:check`): an id leaves only with the user's go, under `removed`.
- The game's data comes from wow-data only (scripts/, through
  `scripts/root.ts`). A new generator goes into `game-data.yml` too.
- The site: books are private (a proven owner only), the site never writes
  the book, the shared package mirrors Save.lua. `vercel link` writes
  production tokens to `.env.local`, which Bun loads, and drops vendor
  skills: keep both out. A deploy or a merge to main (which deploys) waits
  for the user's go.
- `bun install` runs husky, which takes `core.hooksPath` back: the
  `prepare` script installs the family's hooks again, outside CI (husky's
  run after ours, chained).
- `Kit.lua`, `Media/`, `scripts/root.ts` (and `root.py`), `scripts/locales-lib.ts`,
  `i18n/kit/` (the kit's words, translated once), `wow.yml` and `stylua.toml`
  are the kit's copies: edit addon-kit, then `bun run kit:sync`. The addon's
  own globals for selene are `hearthtale.yml`.
- Conventional Commits, lowercase subjects, no AI trailers (commitlint and
  the family's hook). Commit locally; ask before any push, release or
  deploy. The pre-push hook wants a check stamp on the tree (q), which
  `release.sh` makes after the version bump.
