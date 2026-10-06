# Hearthtale

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
  needs). Built by `scripts/build.ts` into `addon/Hearthtale/Data_Classic.lua`
  and `Data_Forever.lua` (one per game; `client:` tags keep a sentence to one).
- `addon/Hearthtale/`: `Core.lua` (the character's record, events,
  `/hearthtale`), `Record.lua` (the chapters and their moments, as they happen;
  a logout settled at the next login),
  `Writer.lua` (the prose, written from the records when read),
  `Save.lua` (the book written into the saved file at each logout, for the
  site: it never writes its own),
  `Book.lua` (the window: chapters on the left, the open one on the right; a
  second tab for the Hall of the Fallen), `Hall.lua` (a Hardcore death: the
  book closed and copied to the account-wide Hall, a chat line, the toast),
  `Settings.lua` (account settings, the Options page), `Minimap.lua`.
- `addon/CURSEFORGE.md`: the project page. `assets/logo-master.png` is the
  painted logo master; `assets/logo.png` and `assets/logo-1024.png` are its
  512px and 1024px exports (resize the master with magick). The previous SVG
  and exports are kept in `assets/previous/`; prompts are in `assets/logo-prompts.json`.
  The source TOC has an `@INTERFACE@` placeholder: not installable as is;
  `scripts/package.ts` builds `dist/classic` and `dist/forever`.
- `addon/test/game.lua`: the fake game (WoW API, events, a character to play,
  the addon loaded), shared by:
  - `addon/test/sim.lua`: a life replayed, every recording asserted, its book
    written. `FOREVER=1` runs it as Forever.
  - `addon/test/lives.lua`: lives played through the addon, as the game would
    send them (Brannok, a Hardcore dwarf hunter; Pippa, a Hardcore gnome mage
    who falls; Aldric, a human paladin met mid-life), shared by:
  - `addon/test/sample.lua`: Brannok's book, `luajit addon/test/sample.lua > docs/sample.md`;
  - `addon/test/seed.lua`: the three, logged out so the addon saves their
    books, as the site's test data (`bun run addon:seed` writes
    `apps/api/src/db/seed/characters.json`; `bun run db:seed` loads it).
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
- After changing the writing: `bun run addon:build`, then `bun run addon:check`,
  regenerate `docs/sample.md` and read it again.

## The site (hearthtale.app)

A monorepo around the addon (Turborepo + Bun workspaces, as WoWLocker): the
site shows the book the addon saves at logout (Save.lua), never writing its own.
Plan and steps: PLAN.md, "The site".

- `apps/api`: Hono on Bun (`src/app.ts`), Postgres through drizzle
  (`src/db/schema.ts`, migrations in `drizzle/`), `src/vercel.ts` the Vercel
  function (bundled by `scripts/vercel-build.sh`).
- `apps/web`: React 19 + Vite + Tailwind v4 + TanStack Router/Query, an
  installable PWA laid out as a native app: the window never scrolls (only
  `main`, and in the reader only the book's text), a top bar that never wraps,
  a bottom tab bar on phones (Library, Get started, Settings). Reading options
  (size, typeface, paper, line spacing) and the language code in `lib/settings.ts`
  (per device), set on `/settings`. Routes in `src/router.tsx`; every visible string in
  `src/lib/i18n.ts` (English only for now, the books being English: another
  language is one more catalog typed on `en` in CATALOGS, with its locale for
  dates; the language setting shows once there are two); the look (the in-game book: leather,
  parchment, the addon's gold) in `src/index.css`.
- `packages/shared` (`@hearthtale/shared`): the wire contract, the saved book's
  shape (mirrors Save.lua). Source of truth.
- Hosting: Vercel (team jellycat, project `hearthtale`, linked: `.vercel/`),
  Neon through the Vercel integration (DATABASE_URL pooled, DATABASE_URL_UNPOOLED
  for migrations, applied on production deploys). Battle.net keys in
  `apps/api/.env.local` (gitignored) and Vercel. `vercel link` and the Neon
  integration append `.env*` to .gitignore and drop vendor skills
  (`.agents/`, `.claude/skills`, `skills-lock.json`): keep them out.
- Local: `bun run db` (Postgres on :5435), `bun run db:migrate`,
  `bun run db:seed` (the test characters), `bun run dev` (api :3002, web :5175).
  The library (`/library`) and the reader (`/book/:id/:part`: one part per
  page, the contents in a drawer; `/book/:id` opens the part to read).
- Accounts (`lib/accounts.ts`, `lib/login.ts`): "Sign in with Battle.net" in a
  region (`/api/auth/login?region=eu`, back on `/api/auth/callback`: both
  APP_ORIGIN's, registered on develop.battle.net); the session is a cookie
  (`ht_session`, only its SHA-256 kept). Books are private: a character is its
  owner's (`characters.owner_id`), proved by the login (its Battle.net character
  ids: the GUID's hex part, `lib/guid.ts`) or by a link code (`lib/link.ts`:
  `/ht link CODE` in the game, kept in the saved file, claimed by the upload).
  Locally, "Use the test account" (`/api/auth/test`, never on Vercel) owns the
  test characters.
- Sharing (`lib/sharing.ts`, `lib/og.ts`): an owner's share links (`shares`:
  a token, the whole book or one part, deleted to revoke) read on `/s/:token`
  without an account, cut to what they cover (`cutBook`) with nothing private
  of the character (`PublicCharacter`); a fallen book its owner shows in the
  Hall (`characters.in_hall`) reads on `/hall` and `/hall/:id`. Link-preview
  crawlers on those pages get an OpenGraph card from the function
  (scripts/vercel-build.sh routes them by user agent; `/api/og/…` by hand).
  The web reader is one component (`components/Reader.tsx`, parts by address)
  for my books, share links and the Hall.
- The companion, Ravenpost (`lib/companion.ts`, `lib/upload.ts`): pairing
  device-code style (`/api/companion/pair/start` → the user confirms on
  `/pair?code=…` → `/pair/poll` hands the token over once; only its hash is
  kept), then `POST /api/companion/upload` (Bearer token) with
  `{ characters: [HearthtaleChar] }`, one character per request (Vercel takes
  4.5 MB). A book is kept only for a proven owner (Battle.net, already the
  account's, or a link code in the record); otherwise "unlinked", unstored.

## Commands

```bash
bun run addon:build | addon:check | addon:package   # the addon
bun run dev | typecheck | lint | test | build       # the site
bun run check                                       # everything
bun run db | db:generate | db:migrate | db:seed
bun run addon:seed                                  # regenerate the test characters
scripts/release.sh [--version X.Y.Z] NOTES.md       # the addon: tag, push; Actions publish
```

## Conventions

- Plain ASCII in `writing/` (' and plain quotes).
- Conventional Commits, lowercase subjects; ask before pushing or releasing.
- Lore and places true to the original game; the writing is in the first
  person, never the League's voice.
